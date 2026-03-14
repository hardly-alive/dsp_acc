import dsp_pkg::*;

module dsp_top (
    input  logic        clk,
    input  logic        rst_n,

    // Incoming 24-bit RGB Stream {R[7:0], G[7:0], B[7:0]}
    input  logic        s_valid,
    input  logic [23:0] s_data, 

    // Outgoing 1-bit Edge Map (scaled to 8-bit 0x00 or 0xFF)
    output logic        m_valid,
    output logic [7:0]  m_data
);

// ==========================================
// 1. Internal Wire Declarations
// ==========================================
logic        gray_valid;
logic [7:0]  gray_data;

logic        win1_valid;
logic [8:0][7:0] win1_data;

logic        blur_valid;
logic [7:0]  blur_data;

logic        win2_valid;
logic [8:0][7:0] win2_data;

// ==========================================
// 2. RGB to Grayscale Converter
// ==========================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray_valid <= 1'b0;
        gray_data  <= '0;
    end 
    else begin
        gray_valid <= s_valid;
        if (s_valid) begin
            // R>>2 + G>>1 + B>>2
            gray_data <= (s_data[23:16] >> 2) + (s_data[15:8] >> 1) + (s_data[7:0] >> 2);
        end
    end
end

// ==========================================
// 3. Module Instantiations (Your Turn)
// ==========================================

// Window Generator 1
window_generator win1 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(gray_valid),
    .s_data(gray_data),
    .m_valid(win1_valid),
    .m_window(win1_data)
);

// Gaussian Blur
gaussian_blur blur (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(win1_valid),
    .s_window(win1_data),
    .m_valid(blur_valid),
    .m_data(blur_data)
);

// Window Generator 2
window_generator win2 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(blur_valid),
    .s_data(blur_data),
    .m_valid(win2_valid),
    .m_window(win2_data)
);

// Sobel Edge Detector
sobel u_sobel (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(win2_valid),
    .s_window(win2_data),
    .m_valid(m_valid),
    .m_data(m_data)
);

endmodule