import dsp_pkg::*;

module window_generator (
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Incoming pixel stream (with AXI markers)
    input  logic                                s_valid,
    input  logic [DATA_WIDTH-1:0]               s_data,
    input  logic                                s_tlast,  
    input  logic                                s_tuser,  
    
    // Outgoing 3x3 window stream
    output logic                                m_valid,
    output logic [8:0][DATA_WIDTH-1:0]          m_window,
    output logic                                m_tlast,  
    output logic                                m_tuser   
);

// Internal wires for Buffer 1
logic [DATA_WIDTH-1:0] buffer1_o;
logic buffer1_valid;
logic buffer1_tlast;
logic buffer1_tuser;

// Internal wires for Buffer 2
logic [DATA_WIDTH-1:0] buffer2_o;
logic buffer2_valid;
logic buffer2_tlast;
logic buffer2_tuser;

// ==========================================
// 1. Line Buffer Cascade (Two 1-Row Buffers)
// ==========================================
line_buffer buffer1 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(s_valid),
    .s_data(s_data),
    .s_last(s_tlast), 
    .s_user(s_tuser),
    .m_valid(buffer1_valid),
    .m_data(buffer1_o),
    .m_last(buffer1_tlast), 
    .m_user(buffer1_tuser)
);

line_buffer buffer2 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(buffer1_valid),
    .s_data(buffer1_o),
    .s_last(buffer1_tlast), 
    .s_user(buffer1_tuser),
    .m_valid(buffer2_valid),
    .m_data(buffer2_o),
    .m_last(buffer2_tlast), 
    .m_user(buffer2_tuser)
);

// ==========================================
// 2. 3x3 Shift Register
// ==========================================
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        m_window <= '0;
        m_valid  <= 1'b0;
        m_tlast  <= 1'b0;
        m_tuser  <= 1'b0;
    end
    else begin
        m_tlast <= s_tlast;
        m_tuser <= s_tuser;
        
        if(s_valid) begin
            m_window <= {m_window[5:0], buffer2_o, buffer1_o, s_data};
            m_valid  <= 1'b1;
        end
        else begin
            m_valid  <= 1'b0;
        end
    end    
end

endmodule