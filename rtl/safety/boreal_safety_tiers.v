/*
 * boreal_safety_tiers.v
 *
 * Formalized safety tiering for Boreal Neuro-Core.
 * Tiers: 0=Normal, 1=Attenuated, 2=Freeze, 3=Latching Halt
 */
module boreal_safety_tiers (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  artifact_flags,
    input  wire        clear_latch,
    output reg  [1:0]  tier
);

    always @(posedge clk) begin
        if (rst) begin
            tier <= 0;
        end else begin
            // Priority encoding for tiers
            if (artifact_flags[0]) // Saturation -> Latching Halt
                tier <= 2'd3;
            else if (artifact_flags[1]) // Variance spike -> Freeze
                tier <= (tier < 2'd2) ? 2'd2 : tier;
            else if (artifact_flags[2]) // Flatline -> Attenuated
                tier <= (tier < 2'd1) ? 2'd1 : tier;

            // Clearance logic
            if (clear_latch && tier != 2'd3) begin
                tier <= 2'd0;
            end else if (clear_latch && tier == 2'd3 && !artifact_flags[0]) begin
                tier <= 2'd0;
            end
        end
    end

endmodule
