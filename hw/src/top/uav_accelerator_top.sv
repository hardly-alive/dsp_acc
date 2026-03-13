import dsp_pkg::*;

module uav_accelerator_top (
    input  logic        clk,
    input  logic        rst_n,

    // Incoming Video Stream (from camera/testbench)
    input  logic        s_valid,
    input  logic [23:0] s_data,

    // Outgoing AI Trigger
    output logic        hazard_detected,
    
    // Optional Debug Outputs (To see the edge map on a monitor)
    output logic        m_dsp_valid,
    output logic [7:0]  m_dsp_data
);

logic       dsp_valid;
logic [7:0] dsp_data;

logic [10:0] x_pos; // 0 to 1279
logic [9:0]  y_pos; // 0 to 719

logic       ai_valid;

// ==========================================
// 1. DSP Pipeline 
// ==========================================
dsp_top u_dsp (
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(s_valid),
    .s_data(s_data),
    .m_valid(dsp_valid),
    .m_data(dsp_data)
);

// Route DSP output to the debug ports
assign m_dsp_valid = dsp_valid;
assign m_dsp_data  = dsp_data;

// ==========================================
// X/Y Counters & Bounding Box
// ==========================================
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_pos <= '0;
        y_pos <= '0;
    end
    else if (dsp_valid) begin
        if (x_pos == MAX_COLS-1) begin
            x_pos <= '0;

            if (y_pos == MAX_ROWS-1)
                y_pos <= '0;
            else
                y_pos <= y_pos + 1'b1;

        end
        else begin
            x_pos <= x_pos + 1'b1;
        end
    end
end

assign ai_valid = dsp_valid &&
                  (x_pos >= 11'd608) && (x_pos <= 11'd671) &&
                  (y_pos >= 10'd328) && (y_pos <= 10'd391);

// ==========================================
// 3. AI Classifier 
// ==========================================
ai_classifier u_ai(
    .clk(clk),
    .rst_n(rst_n),
    .s_valid(ai_valid),
    .s_pixel(dsp_data),
    .hazard_detected(hazard_detected)
);

endmodule