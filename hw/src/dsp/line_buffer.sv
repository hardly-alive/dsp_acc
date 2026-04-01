import dsp_pkg::*;

module line_buffer (
    input  logic                    clk,
    input  logic                    rst_n,
    
    // Incoming pixel stream
    input  logic                    s_valid,
    input  logic [DATA_WIDTH-1:0]   s_data,
    input  logic                    s_last, 
    input  logic                    s_user, 

    // Outgoing pixel from the previous row 
    output logic                    m_valid,
    output logic [DATA_WIDTH-1:0]   m_data,
    output logic                    m_last, 
    output logic                    m_user  
);

// Force Vivado to map this array to BRAM
(* ram_style = "block" *) logic [DATA_WIDTH-1:0] line_mem [0:MAX_COLS-1];

// Internal pointers
logic [10:0] ptr;
logic [10:0] current_addr;

// If it's the start of a frame, force the read/write address to 0. 
// Otherwise, use the tracking pointer.
assign current_addr = s_user ? 11'd0 : ptr;

// ========================================================
// Block 1: Pure BRAM Inference (NO RESETS ALLOWED)
// ========================================================
// Both READ and WRITE must be inside this clean block
always_ff @(posedge clk) begin
    if (s_valid) begin
        // 1. Read the previous row's pixel out of the BRAM
        m_data <= line_mem[current_addr];
        
        // 2. Write the current row's pixel into the BRAM
        line_mem[current_addr] <= s_data;
    end
end

// ========================================================
// Block 2: Control Logic (Async Reset is safe here)
// ========================================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ptr     <= '0;
        m_valid <= 1'b0;
        m_last  <= 1'b0;
        m_user  <= 1'b0;
    end 
    else begin
        if (s_valid) begin
            // Calculate the pointer for the NEXT clock cycle
            if (s_user) 
                ptr <= 11'd1; 
            else if (s_last) 
                ptr <= 11'd0; 
            else 
                ptr <= ptr + 1'b1;

            // Pass the AXI markers down the pipeline
            m_valid <= 1'b1;
            m_last  <= s_last;
            m_user  <= s_user;
        end 
        else begin
            // Stall the pipeline if valid drops
            m_valid <= 1'b0;
            m_last  <= 1'b0;
            m_user  <= 1'b0;
        end
    end
end

endmodule