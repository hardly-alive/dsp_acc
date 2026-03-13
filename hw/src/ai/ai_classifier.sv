module ai_classifier 
    import dsp_pkg::*;
(
    input  logic                    clk,
    input  logic                    rst_n,

    // Incoming Pixel Stream
    input  logic                    s_valid,
    input  logic [DATA_WIDTH-1:0]   s_pixel,

    // Outgoing Hardware Reflex Trigger
    output logic                    hazard_detected
);

logic signed [DATA_WIDTH-1:0] rom_weight;
logic signed [31:0]           mac_result;
logic                         mac_clear;
logic [11:0]                  pixel_count;

// Pipeline Delay Registers (To match ROM 1-cycle latency)
logic                         s_valid_d1;
logic signed [DATA_WIDTH-1:0] s_pixel_d1;


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_valid_d1  <= 1'b0;
        s_pixel_d1  <= '0;
    end
    else begin
        s_valid_d1  <= s_valid;
        s_pixel_d1  <= $signed(s_pixel);
    end
end

weight_rom u_rom(
    .clk(clk),
    .addr(pixel_count),
    .weight_out(rom_weight)
);

// Clear the MAC when we hit the last pixel of the 64x64 window
assign mac_clear = (pixel_count == 4095);

mac_unit u_mac(
    .clk(clk),
    .rst_n(rst_n),
    .clear(mac_clear),     
    .valid_in(s_valid_d1),     
    .pixel_in(s_pixel_d1),     
    .weight_in(rom_weight),
    .accumulator_out(mac_result)
);


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_count     <= '0;
        hazard_detected <= 1'b0;
    end
    else begin
        if (s_valid) begin
            if (pixel_count == 4095) begin
                pixel_count <= '0;
            end
            else begin
                pixel_count <= pixel_count + 1'b1;
            end
        end


        if (s_valid_d1 && (pixel_count == 0)) begin 
            if (mac_result > AI_HAZARD_THRESH)
                hazard_detected <= 1'b1;
            else
                hazard_detected <= 1'b0;
        end
    end
end

endmodule