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
        // simple orthogonal pattern (placeholder)
        wx[0]= 10; wx[1]=  8; wx[2]=  6; wx[3]=  4;
        wx[4]= -4; wx[5]= -6; wx[6]= -8; wx[7]=-10;

        wy[0]= -4; wy[1]= -2; wy[2]=  2; wy[3]=  4;
        wy[4]= 10; wy[5]=  8; wy[6]= -8; wy[7]=-10;
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
