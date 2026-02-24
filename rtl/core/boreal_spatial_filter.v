/*
 * boreal_spatial_filter.v
 *
 * Implements a 2x8 spatial projection matrix: u = M * z
 * where z is the input feature vector (8 channels) and M is a 2x8 matrix.
 * Used for whitening and dimensionality reduction in BCI control.
 *
 * Matrix coefficients are stored in a small BRAM-style reg array for runtime updates.
 */
module boreal_spatial_filter (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire [127:0] features, // 8 x 16-bit normalized features (z-scores)
    
    output reg  signed [23:0] ux,
    output reg  signed [23:0] uy,
    output reg         out_valid,

    // Runtime Matrix Loading
    input  wire [3:0]  reg_addr, // 0-7: Row 0 (ux), 8-15: Row 1 (uy)
    input  wire [15:0] reg_din,
    input  wire        reg_we
);

    reg signed [15:0] matrix [0:15];
    wire signed [15:0] z [0:7];

    // Unpack features
    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin : unpack
            assign z[i] = features[i*16 +: 16];
        end
    endgenerate

    // Matrix Loading
    always @(posedge clk) begin
        if (rst) begin
            // Default to Identity-like or simple mapping
            integer j;
            for (j=0; j<16; j=j+1) matrix[j] <= 0;
            matrix[0] <= 16'h4000; // 0.5 default gain
            matrix[9] <= 16'h4000;
        end else if (reg_we) begin
            matrix[reg_addr] <= reg_din;
        end
    end

    // Pipeline logic
    reg signed [31:0] acc_x, acc_y;
    reg [3:0]         count;
    reg               busy;

    always @(posedge clk) begin
        if (rst) begin
            ux <= 0; uy <= 0;
            out_valid <= 0;
            busy <= 0;
            count <= 0;
            acc_x <= 0; acc_y <= 0;
        end else begin
            out_valid <= 0; // Default

            if (valid && !busy) begin
                busy <= 1;
                count <= 0;
                acc_x <= 0;
                acc_y <= 0;
            end else if (busy) begin
                acc_x <= acc_x + matrix[count] * z[count];
                acc_y <= acc_y + matrix[count+8] * z[count];
                
                if (count == 7) begin
                    busy <= 0;
                    ux <= acc_x[31:8]; // Q correction (example)
                    uy <= acc_y[31:8];
                    out_valid <= 1;
                end else begin
                    count <= count + 1;
                end
            end
        end
    end

endmodule
