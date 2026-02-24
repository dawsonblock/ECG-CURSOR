/*
 * boreal_apex_core_v3.v
 *
 * 8-Channel Systolic Adaptive Inference Engine.
 * Implements online gradient descent for weight adaptation.
 *
 * ENGINEERING REFINEMENT: Formal state_t FSM and MMIO Register Bank.
 */
module boreal_apex_core_v3 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         bite_n,        // Hardware activation gate
    input  wire [191:0] raw8,          // 8x24-bit input samples
    input  wire         adc_valid,
    input  wire [2:0]   ch,
    input  wire         phase_lock,    // From PLL
    output reg  signed [15:0] mu0,     // Primary channel output
    output wire         low_conf,      // Confidence flag
    
    // MMIO Interface (0x4000 series)
    input  wire [9:0]   reg_addr,
    input  wire [31:0]  reg_din,
    input  wire         reg_we,
    output reg  [31:0]  reg_dout
);

    // ---------- Formal FSM Definitions ----------
    typedef enum logic [3:0] {
        S_IDLE,
        S_WAIT_ADC,
        S_DCBLOCK,
        S_FETCH,
        S_ACT,
        S_ERR,
        S_UPDATE_MU,
        S_UPDATE_W,
        S_OUT
    } state_t;

    state_t state;

    // ---------- DC-block per channel ----------
    reg signed [23:0] x1 [0:7];
    reg signed [31:0] y1 [0:7];
    localparam signed [15:0] ALPHA_DC = 16'h7EB8; // ~0.99

    wire signed [23:0] xin = raw8[ch*24 +: 24];
    wire signed [15:0] samp;

    // ---------- MMIO Registers (0x4000 series) ----------
    reg [31:0] noise_limit = 32'd200000000;
    reg [2:0]  ext_lr_shift = 3'd0; // Overrides if non-zero
    reg [2:0]  decay_shift = 3'd4;
    reg        freeze_learn = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            noise_limit <= 32'd200000000;
            ext_lr_shift <= 0;
            decay_shift <= 3'd4;
            freeze_learn <= 0;
        end else if (reg_we) begin
            case (reg_addr)
                10'h002: noise_limit <= reg_din;
                10'h003: ext_lr_shift <= reg_din[2:0];
                10'h004: decay_shift <= reg_din[2:0];
                10'h000: freeze_learn <= reg_din[1];
            endcase
        end
    end

    // ---------- Memory Interface ----------
    wire [31:0] mem_dout;
    reg  [9:0]  addr_a, addr_b;
    reg  [31:0] din_b;
    reg         we_b;

    boreal_memory #(10, 32) mem (
        .clk(clk),
        .addr_a(addr_a),
        .dout_a(mem_dout),
        .we_b(we_b),
        .addr_b(addr_b),
        .din_b(din_b),
        .dout_b()
    );

    // Addressing: Channel-segmented weight storage
    wire [9:0] w_base = {ch, 7'b0};
    always @(*) addr_a = w_base;

    wire signed [15:0] weight = mem_dout[15:0];
    wire signed [15:0] act    = mem_dout[15:0];   
    wire signed [15:0] deriv  = mem_dout[31:16]; 

    // ---------- State Variables ----------
    reg signed [15:0] mu [0:7];
    reg signed [15:0] eps [0:7];
    wire [2:0] lr_shift = (ext_lr_shift != 0) ? ext_lr_shift : (phase_lock ? 3'd5 : 3'd7);

    // ---------- Saturation Utility ----------
    function signed [15:0] sat16;
        input signed [31:0] x;
        begin
            if (x > 32767) sat16 = 32767;
            else if (x < -32768) sat16 = -32768;
            else sat16 = x[15:0];
        end
    endfunction

    // ---------- Confidence Estimation ----------
    reg [31:0] pwr;
    assign low_conf = (pwr > noise_limit);
    assign samp = y1[ch][31:16];

    // ---------- Formal Deterministic FSM Execution ----------
    wire signed [31:0] g_mu = eps[ch] * deriv;
    wire signed [31:0] g_w  = eps[ch] * mu[ch];

    // Hard Clamp Artifact Rejection
    wire artifact = (xin > 24'd7000000 || xin < -24'd7000000);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i=0; i<8; i=i+1) begin
                x1[i] <= 0; y1[i] <= 0; mu[i] <= 0; eps[i] <= 0;
            end
            state <= S_IDLE;
            pwr <= 0;
            we_b <= 0;
        end else begin
            case (state)
                S_IDLE: state <= S_WAIT_ADC;
                
                S_WAIT_ADC: if (adc_valid) state <= S_DCBLOCK;
                
                S_DCBLOCK: begin
                    y1[ch] <= (xin - x1[ch]) + ((y1[ch] * ALPHA_DC) >>> 15);
                    x1[ch] <= xin;
                    pwr <= pwr - (pwr >> 4) + ((samp * samp) >> 4);
                    state <= S_FETCH;
                end
                
                S_FETCH: state <= S_ACT; // Wait for memory Port A read latency
                
                S_ACT: begin
                    eps[ch] <= samp - act;
                    state <= S_ERR;
                end
                
                S_ERR: state <= S_UPDATE_MU;
                
                S_UPDATE_MU: begin
                    mu[ch] <= sat16(
                        mu[ch] + (g_mu >>> lr_shift) - (mu[ch] >>> decay_shift)
                    );
                    state <= S_UPDATE_W;
                end
                
                S_UPDATE_W: begin
                    if (bite_n && !freeze_learn && !low_conf && !artifact) begin
                        addr_b <= w_base;
                        din_b  <= {mem_dout[31:16], sat16(weight + (g_w >>> lr_shift))};
                        we_b   <= 1;
                    end
                    state <= S_OUT;
                end
                
                S_OUT: begin
                    we_b <= 0;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

    always @(posedge clk) mu0 <= mu[0];

    // MMIO Read Logic
    always @(*) begin
        case (reg_addr)
            10'h000: reg_dout = {30'b0, freeze_learn, 1'b1};
            10'h001: reg_dout = {29'b0, artifact, low_conf, phase_lock};
            10'h002: reg_dout = noise_limit;
            10'h010: reg_dout = {16'b0, mu[0]};
            default: reg_dout = 32'b0;
        endcase
    end

endmodule
