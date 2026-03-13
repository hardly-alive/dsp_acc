module line_buffer 
    import dsp_pkg::*;
(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Incoming pixel from the current row
    input  logic                    s_valid,
    input  logic [DATA_WIDTH-1:0]   s_data,
    
    // Outgoing pixel from the previous row
    output logic                    m_valid,
    output logic [DATA_WIDTH-1:0]   m_data
);

logic [DATA_WIDTH-1:0] line_mem [0:MAX_COLS-1];
logic [10:0] ptr;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ptr <= 11'b0;
        m_data <= '0;
        m_valid <= 1'b0;
    end
    else begin
        if(s_valid) begin
            m_data <= line_mem[ptr];
            line_mem[ptr] <= s_data;

            if (ptr == MAX_COLS - 1)
                ptr <= 11'b0;
            else
                ptr <= ptr + 1'b1;

            m_valid <= 1'b1;
        end
        else 
            m_valid <= 1'b0;

    end
end

endmodule