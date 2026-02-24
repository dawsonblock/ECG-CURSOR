/*
 * boreal_csp_filter.v
 *
 * Common Spatial Pattern (CSP) Filter for Boreal Neuro-Core.
 * 
 * Applies statistically optimized spatial weights (pre-computed offline via 
 * eigen-decomposition) to the 8-channel EEG input to maximize the variance 
 * difference between two cognitive states (e.g., Left vs Right Motor Imagery).
 *
 * Equation: v_csp = W * x
 * Where x is the 8x1 channel vector, W is the 2x8 spatial weight matrix.
 */
module boreal_csp_filter (
    input  wire        clk,
    input  wire        rst,
    
    // Core Pipeline
    input  wire        valid,
    input  wire signed [15:0] ch0,
    input  wire signed [15:0] ch1,
    input  wire signed [15:0] ch2,
    input  wire signed [15:0] ch3,
    input  wire signed [15:0] ch4,
    input  wire signed [15:0] ch5,
    input  wire signed [15:0] ch6,
    input  wire signed [15:0] ch7,
    
    // Host Configurable Weights (via MMIO)
    input  wire        host_we,
    input  wire [3:0]  host_addr,  // 0-7 = row0, 8-15 = row1
    input  wire signed [15:0] host_weight,
    
    // CSP Projected Outputs
    output reg         out_valid,
    output reg  signed [23:0] csp_v0, // Optimal axis for State A
    output reg  signed [23:0] csp_v1  // Optimal axis for State B
);

    // Dual-Port BRAM for CSP Matrix
    // W is 2x8 matrix -> 16 words total
    reg signed [15:0] W [0:15];

    // Initialize with identity-ish defaults for safety if no host config
    integer i;
    initial begin
        for (i=0; i<16; i=i+1) W[i] = 0;
        W[1] = 16'h1000; // C3
        W[10] = 16'h1000; // C4
    end

    // Host Write Port
    always @(posedge clk) begin
        if (host_we) begin
            W[host_addr] <= host_weight;
        end
    end

    // DSP MAC Pipeline
    reg signed [31:0] mac_v0, mac_v1;
    reg processing;
    reg [2:0] p_state;
    
    reg signed [15:0] x_latched [0:7];

    always @(posedge clk) begin
        if (rst) begin
            out_valid <= 0;
            processing <= 0;
            p_state <= 0;
            csp_v0 <= 0;
            csp_v1 <= 0;
            mac_v0 <= 0;
            mac_v1 <= 0;
        end else begin
            out_valid <= 0; // Default off

            if (valid && !processing) begin
                // Latch incoming 8-channel frame
                x_latched[0] <= ch0; x_latched[1] <= ch1;
                x_latched[2] <= ch2; x_latched[3] <= ch3;
                x_latched[4] <= ch4; x_latched[5] <= ch5;
                x_latched[6] <= ch6; x_latched[7] <= ch7;
                
                processing <= 1;
                p_state <= 0;
                mac_v0 <= 0;
                mac_v1 <= 0;
            end 
            else if (processing) begin
                case (p_state)
                    // Pipeline Multiplies (2 pairs per cycle to meet timing)
                    0: begin
                        mac_v0 <= mac_v0 + (x_latched[0] * W[0]) + (x_latched[1] * W[1]);
                        mac_v1 <= mac_v1 + (x_latched[0] * W[8]) + (x_latched[1] * W[9]);
                        p_state <= 1;
                    end
                    1: begin
                        mac_v0 <= mac_v0 + (x_latched[2] * W[2]) + (x_latched[3] * W[3]);
                        mac_v1 <= mac_v1 + (x_latched[2] * W[10]) + (x_latched[3] * W[11]);
                        p_state <= 2;
                    end
                    2: begin
                        mac_v0 <= mac_v0 + (x_latched[4] * W[4]) + (x_latched[5] * W[5]);
                        mac_v1 <= mac_v1 + (x_latched[4] * W[12]) + (x_latched[5] * W[13]);
                        p_state <= 3;
                    end
                    3: begin
                        mac_v0 <= mac_v0 + (x_latched[6] * W[6]) + (x_latched[7] * W[7]);
                        mac_v1 <= mac_v1 + (x_latched[6] * W[14]) + (x_latched[7] * W[15]);
                        p_state <= 4;
                    end
                    4: begin
                        // Shift back down from 32-bit Q15 multiply to 24-bit output
                        csp_v0 <= mac_v0[31:8];
                        csp_v1 <= mac_v1[31:8];
                        out_valid <= 1;
                        processing <= 0;
                    end
                endcase
            end
        end
    end

endmodule
