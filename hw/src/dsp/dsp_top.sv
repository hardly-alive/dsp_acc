import dsp_pkg::*;

module dsp_top (
    input  logic        clk,
    input  logic        rst_n,

    // Incoming AXI-Stream Video
    input  logic        s_valid,
    input  logic [23:0] s_data, 
    input  logic        s_tlast,
    input  logic        s_tuser,

    // Outgoing AXI-Stream Edge Map
    output logic        m_valid,
    output logic [7:0]  m_data,
    output logic        m_tlast, 
    output logic        m_tuser  
);

// ==========================================
// Internal Wire Declarations
// ==========================================
logic        gray_valid;
logic [7:0]  gray_data;
logic        gray_tlast;
logic        gray_tuser;

logic        win1_valid;
logic [8:0][7:0] win1_data;
logic        win1_tlast;
logic        win1_tuser;

logic        blur_valid;
logic [7:0]  blur_data;
logic        blur_tlast;
logic        blur_tuser;

logic        win2_valid;
logic [8:0][7:0] win2_data;
logic        win2_tlast;
logic        win2_tuser;

// ==========================================
// RGB to Grayscale Converter 
// ==========================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray_valid <= 1'b0;
        gray_data  <= '0;
        gray_tlast <= 1'b0;
        gray_tuser <= 1'b0;
    end 
    else begin
        gray_valid <= s_valid;
        gray_tlast <= s_tlast;
        gray_tuser <= s_tuser;

        if (s_valid) begin
            // R>>2 + G>>1 + B>>2
            gray_data <= (s_data[23:16] >> 2) + (s_data[15:8] >> 1) + (s_data[7:0] >> 2);
        end
    end
end

// ==========================================
// Parallel AXI Delay Lines for Pure Math Blocks
// ==========================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blur_tlast <= 1'b0;
        blur_tuser <= 1'b0;
        m_tlast    <= 1'b0;
        m_tuser    <= 1'b0;
    end else begin
        blur_tlast <= win1_tlast; // 1 cycle delay for Gaussian Blur
        blur_tuser <= win1_tuser; 
        
        m_tlast    <= win2_tlast; // 1 cycle delay for Sobel
        m_tuser    <= win2_tuser;
    end
end

// ==========================================
// Module Instantiations
// ==========================================

// Window Generator 1 
window_generator win1 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(gray_valid),
    .s_data(gray_data),
    .s_tlast(gray_tlast), 
    .s_tuser(gray_tuser),
    .m_valid(win1_valid),
    .m_window(win1_data),
    .m_tlast(win1_tlast), 
    .m_tuser(win1_tuser)
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
    .s_tlast(blur_tlast), 
    .s_tuser(blur_tuser),
    .m_valid(win2_valid),
    .m_window(win2_data),
    .m_tlast(win2_tlast), 
    .m_tuser(win2_tuser)
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