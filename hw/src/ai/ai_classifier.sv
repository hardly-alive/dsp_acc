import dsp_pkg::*;

module ai_classifier (
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
logic [11:0]                  pixel_count;
logic [15:0] hazard_timer;

// Pipeline Delay Registers (To match ROM 1-cycle latency)
logic                         s_valid_d1;
logic signed [DATA_WIDTH-1:0] s_pixel_d1;

// End-Of-Window Delay Line
logic                         eow_d1;
logic                         eow_d2;


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_valid_d1  <= 1'b0;
        s_pixel_d1  <= '0;
        eow_d1      <= 1'b0;
        eow_d2      <= 1'b0;
    end
    else begin
        s_valid_d1  <= s_valid;

        if (s_pixel > 8'd150)
            s_pixel_d1 <= 8'd1;
        else
            s_pixel_d1 <= 8'd0;

        eow_d1 <= (s_valid && (pixel_count == 4095));
        eow_d2 <= eow_d1;
    end
end

weight_rom u_rom(
    .clk(clk),
    .addr(pixel_count),
    .weight_out(rom_weight)
);

mac_unit u_mac(
    .clk(clk),
    .rst_n(rst_n),
    .clear(eow_d2),     
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


        if (eow_d2 && (mac_result > AI_HAZARD_THRESH)) begin
            hazard_detected <= 1'b1;
            hazard_timer    <= 16'd5000; // Signal stays HIGH for 5000 cycles
            $display(">>> [HAZARD] Score: %0d | Time: %0t", mac_result, $time);
        end 
        else if (hazard_timer > 0) begin
            hazard_timer    <= hazard_timer - 1'b1;
            hazard_detected <= 1'b1;
        end 
        else begin
            // Reset signal when timer is finished
            hazard_detected <= 1'b0;
        end
    end
end

endmodule