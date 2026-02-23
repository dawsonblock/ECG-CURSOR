// boreal_feature_extract.v
// 8-channel weighted feature extractor → true X/Y features
// FIX: includes last channel contribution (no dropped sample)

module boreal_feature_extract #(
    parameter N_CH = 8
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              valid,
    input  wire signed [15:0] sample_in,
    output reg  signed [15:0] feature_x,
    output reg  signed [15:0] feature_y
);

    // Example static spatial weights (replace with calibrated values)
    reg signed [7:0] wx [0:N_CH-1];
    reg signed [7:0] wy [0:N_CH-1];

    integer i;

    initial begin
        // high-spec orthogonal pattern
        wx[0]= 32; wx[1]= 24; wx[2]= 16; wx[3]=  8;
        wx[4]=-08; wx[5]=-16; wx[6]=-24; wx[7]=-32;

        wy[0]= -8; wy[1]=-16; wy[2]=-24; wy[3]=-32;
        wy[4]= 32; wy[5]= 24; wy[6]= 16; wy[7]=  8;
    end

    reg [2:0] ch;
    reg signed [31:0] acc_x;
    reg signed [31:0] acc_y;

    always @(posedge clk) begin
        if (rst) begin
            ch <= 0;
            acc_x <= 0;
            acc_y <= 0;
            feature_x <= 0;
            feature_y <= 0;
        end else if (valid) begin
            // accumulate
            acc_x <= acc_x + sample_in * wx[ch];
            acc_y <= acc_y + sample_in * wy[ch];

            if (ch == N_CH-1) begin
                // include LAST channel properly
                feature_x <= (acc_x + sample_in * wx[ch]) >>> 8;
                feature_y <= (acc_y + sample_in * wy[ch]) >>> 8;

                acc_x <= 0;
                acc_y <= 0;
                ch <= 0;
            end else begin
                ch <= ch + 1;
            end
        end
    end

endmodule
