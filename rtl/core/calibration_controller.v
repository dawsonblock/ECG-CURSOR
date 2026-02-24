/*
 * calibration_controller.v
 *
 * Implements a timed calibration sequence.
 * States: IDLE -> LEFT -> RIGHT -> UP -> DOWN -> RUN
 * Captures feature offsets per direction to normalize control.
 */
module calibration_controller(
    input  wire clk,
    input  wire rst,
    input  wire start_cal,
    input  wire valid,             // Strobed when a new frame is ready
    input  wire signed [15:0] feat_x,
    input  wire signed [15:0] feat_y,

    output reg [2:0] state,
    output reg signed [15:0] offset_x,
    output reg signed [15:0] offset_y,
    output reg calibrated
);

    parameter IDLE  = 3'd0;
    parameter LEFT  = 3'd1;
    parameter RIGHT = 3'd2;
    parameter UP    = 3'd3;
    parameter DOWN  = 3'd4;
    parameter RUN   = 3'd5;

    parameter CAL_SAMPLES = 64; // Number of frames to average per direction

    reg [7:0]  sample_cnt;
    reg signed [31:0] acc_x;
    reg signed [31:0] acc_y;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            sample_cnt <= 0;
            acc_x <= 0;
            acc_y <= 0;
            offset_x <= 0;
            offset_y <= 0;
            calibrated <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start_cal) begin
                        state <= LEFT;
                        sample_cnt <= 0;
                        acc_x <= 0;
                        acc_y <= 0;
                        calibrated <= 0;
                    end
                end

                LEFT, RIGHT, UP, DOWN: begin
                    if (valid) begin
                        acc_x <= acc_x + feat_x;
                        acc_y <= acc_y + feat_y;
                        sample_cnt <= sample_cnt + 1;

                        if (sample_cnt == CAL_SAMPLES - 1) begin
                            state <= state + 1; // Transitions L->R->U->D->RUN
                            sample_cnt <= 0;
                            // Note: For a real BCI, we would store direction-specific vectors.
                            // Here we use the cumulative average as a global baseline offset.
                            offset_x <= acc_x >>> 6; // Simple average
                            offset_y <= acc_y >>> 6;
                        end
                    end
                end

                RUN: begin
                    calibrated <= 1;
                    if (start_cal) state <= IDLE; // Re-calibrate
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
