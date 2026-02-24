/*
 * boreal_symbolic_decoder.v
 *
 * Maps continuous decoded neural signals into discrete, symbolic states.
 * This acts as the bridge between the lower-level continuous BCI and a
 * high-level Action/Decision VM.
 *
 * States:
 *   0: IDLE
 *   1: MOVE_X (Intent on X-axis exceeds threshold)
 *   2: MOVE_Y (Intent on Y-axis exceeds threshold)
 *   3: SELECT (A sudden, high-energy spike on both axes, or a dedicated confirmation feature)
 */
module boreal_symbolic_decoder (
    input  wire        clk,
    input  wire        rst,
    
    // Continuous Input (from LMS or Kalman)
    input  wire        valid_in,
    input  wire signed [23:0] intent_x,
    input  wire signed [23:0] intent_y,
    
    // MMIO Thresholds
    input  wire signed [23:0] thresh_move,
    input  wire signed [23:0] thresh_select,
    
    // Discrete Symbolic Output
    output reg         valid_out,
    output reg  [2:0]  state_id
);

    // State Enums
    localparam STATE_IDLE   = 3'd0;
    localparam STATE_MOVE_X = 3'd1;
    localparam STATE_MOVE_Y = 3'd2;
    localparam STATE_SELECT = 3'd3;

    // Absolute value logic for signed comparison
    wire signed [24:0] abs_x = (intent_x < 0) ? -intent_x : intent_x;
    wire signed [24:0] abs_y = (intent_y < 0) ? -intent_y : intent_y;
    
    // Feature for "Select" (e.g., strong simultaneous intent, or high frequency burst)
    // Here we use a simple linear combination of absolute intents
    wire signed [25:0] energy_sum = abs_x + abs_y;

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
            state_id <= STATE_IDLE;
        end else begin
            valid_out <= 0;
            if (valid_in) begin
                // Priority Encoding for States
                if (energy_sum > thresh_select) begin
                    state_id <= STATE_SELECT;
                end else if (abs_x > thresh_move && abs_x > abs_y) begin
                    state_id <= STATE_MOVE_X;
                end else if (abs_y > thresh_move && abs_y > abs_x) begin
                    state_id <= STATE_MOVE_Y;
                end else begin
                    state_id <= STATE_IDLE;
                end
                
                valid_out <= 1;
            end
        end
    end

endmodule
