module sobel 
    import dsp_pkg::*;
(
    input  logic                                clk,
    input  logic                                rst_n,
    
    // Incoming 3x3 window (from the second window generator)
    input  logic                                s_valid,
    input  logic [8:0][DATA_WIDTH-1:0]          s_window,
    
    // Outgoing binary edge pixel (0x00 or 0xFF)
    output logic                                m_valid,
    output logic [DATA_WIDTH-1:0]               m_data
);

// gx -> [-1 0 +1], gy -> [-1 -2 -1] 
//       [-2 0 +2]        [ 0  0  0] 
//       [-1 0 +1]        [+1 +2 +1] 

logic signed [10:0] gx, gy;
logic [10:0] abs_gx, abs_gy;
logic [11:0] magnitude;

always_comb begin
    gx = $signed({1'b0, s_window[2] + (s_window[5] << 1) + s_window[8]}) 
       - $signed({1'b0, s_window[0] + (s_window[3] << 1) + s_window[6]});
        
    gy = $signed({1'b0, s_window[6] + (s_window[7] << 1) + s_window[8]}) 
       - $signed({1'b0, s_window[0] + (s_window[1] << 1) + s_window[2]});

    // Absolute values
    abs_gx = gx[10] ? -gx : gx;
    abs_gy = gy[10] ? -gy : gy;

    // Total magnitude
    magnitude = abs_gx + abs_gy;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m_data  <= '0;
        m_valid <= 1'b0;
    end
    else begin
        m_valid <= s_valid;

        if (s_valid) begin
            if (magnitude > SOBEL_THRESH) begin
                m_data <= 8'hFF; // Stark white edge
            end
            else begin
                m_data <= 8'h00; // Pitch black background          
            end
        end
    end
end

endmodule