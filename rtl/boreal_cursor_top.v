module boreal_cursor_top (
    input  wire clk,
    input  wire rst_n,
    input  wire emergency_halt_n,
    
    // ADC IN
    input  wire [23:0] raw_adc_in,
    input  wire [2:0]  adc_channel_sel,
    input  wire        adc_data_ready,
    input  wire [1:0]  safety_tier,
    input  wire        send_packet_strobe,

    // UART OUT
    output wire        uart_tx
);

    wire signed [15:0] mu_x, mu_y;
    boreal_apex_core_2d u_core (
        .clk(clk),
        .rst_n(rst_n),
        .emergency_halt_n(emergency_halt_n),
        .raw_adc_in(raw_adc_in),
        .adc_channel_sel(adc_channel_sel),
        .adc_data_ready(adc_data_ready),
        .mu_x(mu_x),
        .mu_y(mu_y)
    );

    wire signed [15:0] mu_x_f, mu_y_f;
    cursor_smoothing u_smooth (
        .clk(clk),
        .rst_n(rst_n),
        .mu_x(mu_x),
        .mu_y(mu_y),
        .mu_x_f(mu_x_f),
        .mu_y_f(mu_y_f)
    );

    wire signed [7:0] dx, dy;
    cursor_map u_map (
        .clk(clk),
        .mx(mu_x_f),
        .my(mu_y_f),
        .tier(safety_tier),
        .dx(dx),
        .dy(dy)
    );

    wire left_click, right_click;
    dwell_click u_click (
        .clk(clk),
        .rst_n(rst_n),
        .dx(dx),
        .dy(dy),
        .tier(safety_tier),
        .left_click(left_click),
        .right_click(right_click)
    );

    cursor_uart_tx u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .send_strobe(send_packet_strobe),
        .right_click(right_click),
        .left_click(left_click),
        .dx(dx),
        .dy(dy),
        .tx(uart_tx)
    );

endmodule
