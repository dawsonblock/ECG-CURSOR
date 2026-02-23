/*
 * Boreal Cursor Top — Base Pipeline (Refined 2D)
 *
 * Includes: Feature Extract -> 2D Core -> Smoothing -> Map -> Click -> UART
 */
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

    wire rst = !rst_n;
    wire halt = !emergency_halt_n;

    // Feature Extract
    wire signed [15:0] feat_x, feat_y;
    boreal_feature_extract u_feat (
        .clk(clk),
        .rst(rst),
        .valid(adc_data_ready),
        .sample_in(raw_adc_in[23:8]),
        .feature_x(feat_x),
        .feature_y(feat_y)
    );

    reg [2:0] last_ch;
    always @(posedge clk) last_ch <= u_feat.ch;
    wire feat_ready = (u_feat.ch == 0 && last_ch == 7);

    // 2D Core
    wire signed [15:0] mu_x, mu_y;
    boreal_apex_core_2d u_core (
        .clk(clk),
        .rst(rst),
        .valid(feat_ready),
        .x_in(feat_x),
        .y_in(feat_y),
        .emergency_halt(halt),
        .mu_x(mu_x),
        .mu_y(mu_y)
    );

    // Smoothing
    wire signed [15:0] mu_x_f, mu_y_f;
    cursor_smoothing u_smooth (
        .clk(clk),
        .rst_n(rst_n),
        .mu_x(mu_x),
        .mu_y(mu_y),
        .mu_x_f(mu_x_f),
        .mu_y_f(mu_y_f)
    );

    // Map
    wire signed [7:0] dx, dy;
    cursor_map u_map (
        .clk(clk),
        .mx(mu_x_f),
        .my(mu_y_f),
        .tier(safety_tier),
        .dx(dx),
        .dy(dy)
    );

    // Click & Button Latch
    wire l_click_p, r_click_p;
    reg left_btn, right_btn;
    dwell_click u_click (
        .clk(clk),
        .rst(rst),
        .dx(dx),
        .dy(dy),
        .left_click_pulse(l_click_p),
        .right_click_pulse(r_click_p)
    );

    always @(posedge clk) begin
        if (rst) begin
            left_btn <= 0;
            right_btn <= 0;
        end else begin
            if (l_click_p)  left_btn  <= ~left_btn;
            if (r_click_p) right_btn <= ~right_btn;
        end
    end

    // UART
    cursor_uart_tx u_uart (
        .clk(clk),
        .rst(rst),
        .send(send_packet_strobe),
        .buttons({right_btn, left_btn}),
        .dx(dx),
        .dy(dy),
        .tx(uart_tx)
    );

endmodule
