module boreal_feature_extract #(
    parameter CHANNELS = 8
)(
    input  wire clk,
    input  wire rst_n,
    
    // Raw inputs from filtering
    input  wire signed [15:0] filtered_sample,
    input  wire [2:0] channel_sel,
    input  wire       sample_valid,
    
    // Extracted features tuned for cursor
    output reg  signed [15:0] feature_x,
    output reg  signed [15:0] feature_y,
    output reg        feature_valid
);

    // Hardcoded spatial weights for 8 channels
    // Example: Channels 0-3 map more to X axis (e.g. lateral sensors)
    // Channels 4-7 map more to Y axis (e.g. anterior/posterior sensors)
    wire signed [15:0] w_x [0:7];
    wire signed [15:0] w_y [0:7];
    
    assign w_x[0] =  16'sd300; assign w_y[0] =  16'sd50;
    assign w_x[1] =  16'sd200; assign w_y[1] =  16'sd50;
    assign w_x[2] = -16'sd200; assign w_y[2] = -16'sd40;
    assign w_x[3] = -16'sd300; assign w_y[3] = -16'sd40;
    
    assign w_x[4] =  16'sd50;  assign w_y[4] =  16'sd300;
    assign w_x[5] =  16'sd40;  assign w_y[5] =  16'sd200;
    assign w_x[6] = -16'sd40;  assign w_y[6] = -16'sd200;
    assign w_x[7] = -16'sd50;  assign w_y[7] = -16'sd300;

    reg signed [31:0] acc_x;
    reg signed [31:0] acc_y;
    reg [3:0] samples_processed;

    reg signed [31:0] mul_x, mul_y;
    reg               mul_valid;
    reg [2:0]         mul_chan;

    always @(posedge clk) begin
        if (!rst_n) begin
            mul_x <= 0;
            mul_y <= 0;
            mul_valid <= 0;
            mul_chan <= 0;
        end else begin
            mul_valid <= sample_valid;
            mul_chan <= channel_sel;
            mul_x <= filtered_sample * w_x[channel_sel];
            mul_y <= filtered_sample * w_y[channel_sel];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            feature_valid <= 0;
            acc_x <= 0;
            acc_y <= 0;
            samples_processed <= 0;
        end else begin
            feature_valid <= 0;
            if (mul_valid) begin
                acc_x <= acc_x + mul_x;
                acc_y <= acc_y + mul_y;
                
                if (samples_processed == CHANNELS - 1) begin
                    feature_x <= acc_x[31:16]; // scale back
                    feature_y <= acc_y[31:16];
                    feature_valid <= 1;
                    acc_x <= 0;
                    acc_y <= 0;
                    samples_processed <= 0;
                end else begin
                    samples_processed <= samples_processed + 1;
                end
            end
        end
    end

endmodule
