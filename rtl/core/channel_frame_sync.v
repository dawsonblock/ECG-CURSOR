/*
 * channel_frame_sync.v
 *
 * Implements a bitmask barrier to ensure the serial feature extractor
 * only triggers when all 8 parallel channels have successfully
 * computed their energy results in the current frame.
 */
module channel_frame_sync #(
    parameter NUM_CHANNELS = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire [NUM_CHANNELS-1:0] chan_done, // pulse per channel when bandpower completes
    output reg  frame_ready
);

    reg [NUM_CHANNELS-1:0] ready_mask;

    always @(posedge clk) begin
        if (rst) begin
            ready_mask <= {NUM_CHANNELS{1'b0}};
            frame_ready <= 1'b0;
        end else begin
            // Accumulate arriving readiness pulses
            ready_mask <= ready_mask | chan_done;
            
            // Check if all channels are ready
            // We emit frame_ready for exactly one cycle when the mask is full
            if (ready_mask == {NUM_CHANNELS{1'b1}} && !frame_ready) begin
                frame_ready <= 1'b1;
                ready_mask <= {NUM_CHANNELS{1'b0}}; // Reset for next frame
            end else begin
                frame_ready <= 1'b0;
            end
        end
    end

endmodule
