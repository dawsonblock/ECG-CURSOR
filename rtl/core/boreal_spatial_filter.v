/*
 * boreal_spatial_filter.v
 *
 * Implements a research-grade BRAM-based 2x8 spatial filter.
 * u = M * (z - offset)
 *
 * This version uses a real Dual-Port BRAM for matrix storage, 
 * allowing high-speed MAC execution and host weight injection.
 */
module boreal_spatial_filter (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire [127:0] features, // 8 x 16-bit normalized features
    
    output reg  signed [23:0] ux,
    output reg  signed [23:0] uy,
    output reg         out_valid,

    // Dual-Port BRAM Interface for Host
    input  wire [4:0]  host_addr,
    input  wire [15:0] host_din,
    input  wire        host_we
);

    // Matrix Storage (16x16-bit: 8 for UX row, 8 for UY row)
    reg signed [15:0] matrix_ram [0:31]; 
    reg [4:0]  read_addr;
    reg signed [15:0] matrix_out;

    always @(posedge clk) begin
        if (host_we) matrix_ram[host_addr] <= host_din;
        matrix_out <= matrix_ram[read_addr];
    end

    // Input Unpack
    wire signed [15:0] z [0:7];
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : unpack
            assign z[i] = features[i*16 +: 16];
        end
    endgenerate

    // Sequential MAC Pipeline
    reg signed [31:0] acc_x, acc_y;
    reg [3:0]  state;
    reg [2:0]  idx;

    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            idx <= 0;
            read_addr <= 0;
            ux <= 0; uy <= 0;
            out_valid <= 0;
        end else begin
            out_valid <= 0;
            case (state)
                0: begin // Idle
                    if (valid) begin
                        state <= 1;
                        idx <= 0;
                        acc_x <= 0;
                        acc_y <= 0;
                        read_addr <= 0;
                    end
                end
                
                1: begin // Fetch & Accumulate
                    read_addr <= idx;         // Row 0
                    state <= 2;
                end
                
                2: begin
                    read_addr <= idx + 8;     // Row 1
                    acc_x <= acc_x + matrix_out * z[idx];
                    state <= 3;
                end
                
                3: begin
                    acc_y <= acc_y + matrix_out * z[idx];
                    if (idx == 7) state <= 4;
                    else begin
                        idx <= idx + 1;
                        read_addr <= idx + 1;
                        state <= 2;
                    end
                end
                
                4: begin
                    ux <= acc_x[31:8];
                    uy <= acc_y[31:8];
                    out_valid <= 1;
                    state <= 0;
                end
            endcase
        end
    end

endmodule
