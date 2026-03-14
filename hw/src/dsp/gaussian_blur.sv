import dsp_pkg::*;

module gaussian_blur (
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Incoming 3x3 window
    input  logic                                s_valid,
    input  logic [8:0][DATA_WIDTH-1:0]          s_window,
    
    // Outgoing blurred pixel
    output logic                                m_valid,
    output logic [DATA_WIDTH-1:0]               m_data
);

logic [11:0] sum;

always_comb begin
    sum =  s_window[0]       + // *1
          (s_window[1] << 1) + // *2
           s_window[2]       + // *1
          (s_window[3] << 1) + // *2
          (s_window[4] << 2) + // *4
          (s_window[5] << 1) + // *2 
           s_window[6]       + // *1
          (s_window[7] << 1) + // *2
           s_window[8];        // *1
end

always_ff @( posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        m_data <= '0;
        m_valid <= 1'b0;
    end
    else begin
        if(s_valid) begin 
            m_data <= sum[11:4];
            m_valid <= 1'b1;
        end
        else m_valid <= 1'b0;
    end
end

endmodule