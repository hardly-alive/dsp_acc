import dsp_pkg::*;

module uav_accelerator_top (
    // AXI Clock and Reset
    input  logic        aclk,
    input  logic        aresetn,

    // ---------------------------------------------------
    // AXI4-Stream Slave Interface
    // ---------------------------------------------------
    input  logic        s_axis_tvalid,
    input  logic [23:0] s_axis_tdata,
    input  logic        s_axis_tlast, 
    input  logic        s_axis_tuser,
    output logic        s_axis_tready, 

    // ---------------------------------------------------
    // AXI4-Stream Master Interface
    // ---------------------------------------------------
    input  logic        m_axis_tready,
    output logic        m_axis_tvalid,
    output logic [7:0]  m_axis_tdata,
    output logic        m_axis_tlast,
    output logic        m_axis_tuser,

    // Sideband Output
    output logic        hazard_detected
);

// We never stall the camera, so we always assert ready
assign s_axis_tready = 1'b1; 

// Internal wires for the delayed DSP output
logic       dsp_valid;
logic [7:0] dsp_data;
logic       dsp_tlast;
logic       dsp_tuser;

logic [10:0] x_pos; // 0 to 2047 (Flexible resolution)
logic [9:0]  y_pos; // 0 to 1023 (Flexible resolution)
logic        ai_valid;

// ==========================================
// 1. DSP Pipeline (Now AXI Aware)
// ==========================================
// Note: You will need to update dsp_top to accept and delay tlast/tuser
dsp_top u_dsp (
    .clk(aclk),
    .rst_n(aresetn),
    .s_valid(s_axis_tvalid),
    .s_data(s_axis_tdata),
    .s_tlast(s_axis_tlast), // Route AXI signals in
    .s_tuser(s_axis_tuser),
    .m_valid(dsp_valid),
    .m_data(dsp_data),
    .m_tlast(dsp_tlast),    // Route delayed AXI signals out
    .m_tuser(dsp_tuser)
);

// Directly map the DSP outputs to the AXI Master bus
assign m_axis_tvalid = dsp_valid;
assign m_axis_tdata  = dsp_data;
assign m_axis_tlast  = dsp_tlast;
assign m_axis_tuser  = dsp_tuser;

// ==========================================
// 2. Dynamic X/Y Counters & Bounding Box
// ==========================================
always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        x_pos <= '0;
        y_pos <= '0;
    end 
    else if (dsp_tuser) begin
        // TUSER = Start of a new frame. Hard reset the coordinates.
        x_pos <= '0;
        y_pos <= '0;
    end 
    else if (dsp_valid) begin
        if (dsp_tlast) begin
            // TLAST = End of a row. Wrap X to 0, increment Y.
            x_pos <= '0;
            y_pos <= y_pos + 1'b1;
        end 
        else begin
            // Normal pixel, just move right
            x_pos <= x_pos + 1'b1;
        end
    end
end

// The bounding box logic 
assign ai_valid = dsp_valid &&
                  (x_pos >= 11'd608) && (x_pos <= 11'd671) &&
                  (y_pos >= 10'd328) && (y_pos <= 10'd391);

// ==========================================
// 3. AI Classifier 
// ==========================================
ai_classifier u_ai(
    .clk(aclk),
    .rst_n(aresetn),
    .s_valid(ai_valid),
    .s_pixel(dsp_data),
    .s_tuser(dsp_tuser), 
    .hazard_detected(hazard_detected)
);

endmodule