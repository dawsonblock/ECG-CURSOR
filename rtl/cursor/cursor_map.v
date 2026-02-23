module cursor_map #(
    parameter signed [15:0] DEAD = 16'sd200,
    parameter signed [15:0] GAIN = 16'sd2,
    parameter signed [7:0]  VMAX = 8'sd20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [15:0] mx,
    input  wire signed [15:0] my,
    input  wire [1:0] tier,
    output reg  signed [7:0] dx,
    output reg  signed [7:0] dy
);

    function signed [7:0] clamp8(input signed [15:0] v);
        if (v >  VMAX) clamp8 =  VMAX;
        else if (v < -VMAX) clamp8 = -VMAX;
        else clamp8 = v[7:0];
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dx <= 0;
            dy <= 0;
        end else if (tier >= 2) begin 
            dx <= 0; 
            dy <= 0; 
        end else begin
            dx <= ( (mx > DEAD || mx < -DEAD) ? clamp8((mx >>> 4) * GAIN) : 8'sd0 );
            dy <= ( (my > DEAD || my < -DEAD) ? clamp8((my >>> 4) * GAIN) : 8'sd0 );
        end
    end
endmodule
