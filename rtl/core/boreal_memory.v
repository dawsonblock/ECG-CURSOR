/*
 * boreal_memory.v
 *
 * Dual-port weight/LUT storage for Boreal Neuro-Core.
 * Port A: Inference Read (Fixed Latency)
 * Port B: Learning Write / Host Update
 */
module boreal_memory #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    
    // Port A: Read Only (Inference)
    input  wire [ADDR_WIDTH-1:0]  addr_a,
    output reg  [DATA_WIDTH-1:0]  dout_a,
    
    // Port B: Read/Write (Learning / UART)
    input  wire                   we_b,
    input  wire [ADDR_WIDTH-1:0]  addr_b,
    input  wire [DATA_WIDTH-1:0]  din_b,
    output reg  [DATA_WIDTH-1:0]  dout_b
);

    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];

    initial begin
        integer i;
        for (i=0; i<(1<<ADDR_WIDTH); i=i+1) begin
            memory[i] = 0;
        end
    end

    // Port A
    always @(posedge clk) begin
        dout_a <= memory[addr_a];
    end

    // Port B
    always @(posedge clk) begin
        if (we_b)
            memory[addr_b] <= din_b;
        dout_b <= memory[addr_b];
    end

endmodule
