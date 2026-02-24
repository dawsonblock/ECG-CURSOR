/*
 * boreal_intent_classifier.v
 *
 * Logistic classifier for BCI "click" detection.
 * p(click) = sigmoid(W * f + b)
 * Features f: [ux, uy, power, velocity]
 */
module boreal_intent_classifier #(
    parameter DEBOUNCE_THR = 8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        valid,
    input  wire signed [23:0] ux,
    input  wire signed [23:0] uy,
    
    output reg         click,
    
    // Weight interface
    input  wire [2:0]  reg_addr,
    input  wire [15:0] reg_din,
    input  wire        reg_we
);

    reg signed [15:0] w [0:3];
    reg signed [15:0] bias;
    
    // Feature extraction
    wire signed [15:0] f0 = (ux < 0) ? -ux[23:8] : ux[23:8]; // |ux|
    wire signed [15:0] f1 = (uy < 0) ? -uy[23:8] : uy[23:8]; // |uy|
    
    // Weighted sum
    reg signed [31:0] sum;
    reg [4:0]         debounce_cnt;

    // LUT-based Sigmoid (Small 4-bit indices)
    function [15:0] sigmoid;
        input signed [31:0] x;
        begin
            // Simplified threshold-based sigmoid for FPGA
            if (x > 32'sd65536)  sigmoid = 16'hFFFF; // 1.0
            else if (x < -32'sd65536) sigmoid = 16'h0000; // 0.0
            else sigmoid = 16'h8000 + x[15:0]; // Linear approx near 0
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            w[0] <= 0; w[1] <= 0; w[2] <= 0; w[3] <= 0;
            bias <= -16'h4000; // negative bias
            click <= 0;
            debounce_cnt <= 0;
        end else if (reg_we) begin
            if (reg_addr < 4) w[reg_addr] <= reg_din;
            else if (reg_addr == 4) bias <= reg_din;
        end else if (valid) begin
            sum <= (w[0] * f0 + w[1] * f1) + (bias << 15);
            
            // Logit check
            if (sigmoid(sum) > 16'hC000) begin // 0.75 threshold
                if (debounce_cnt < DEBOUNCE_THR) debounce_cnt <= debounce_cnt + 1;
                else click <= 1;
            end else begin
                debounce_cnt <= 0;
                click <= 0;
            end
        end
    end

endmodule
