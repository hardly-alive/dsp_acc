module 
    import dsp_pkg::*;
(
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Incoming pixel stream
    input  logic                                s_valid,
    input  logic [DATA_WIDTH-1:0]               s_data,
    
    // Outgoing 3x3 window stream
    output logic                                m_valid,
    // Indexing: 012:oldest column, 678=newest column
    output logic [8:0][DATA_WIDTH-1:0]          m_window
);

logic [DATA_WIDTH-1:0] buffer1_o, buffer2_o;
logic buffer1_valid, buffer2_valid;

line_buffer buffer1 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(s_valid),
    .s_data(s_data),
    .m_valid(buffer1_valid),
    .m_data(buffer1_o)
);

line_buffer buffer2 (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(buffer1_valid),
    .s_data(buffer1_o),
    .m_valid(buffer2_valid),
    .m_data(buffer2_o)
);

always_ff @( posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        m_window <= '0;
        m_valid  <= 1'b0;
    end
    else begin
        if(s_valid) begin
            m_window <= {m_window[5:0], buffer2_o, buffer1_o, s_data};
            m_valid <= 1'b1;
        end
        else
            m_valid <= 1'b0;
    end    
end

endmodule