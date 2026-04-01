import dsp_pkg::*;

module mac_unit (
    input  logic               clk,
    input  logic               rst_n,

    // Control signals
    input  logic               clear,      // Resets the accumulator to 0
    input  logic               valid_in,   // High when inputs are valid

    // Data inputs (Signed 8-bit integers)
    input  logic signed [7:0]  pixel_in,
    input  logic signed [7:0]  weight_in,

    // Data output
    output logic signed [31:0] accumulator_out
);

// Force Vivado to use a DSP48 slice for this math
(* use_dsp = "yes" *) logic signed [15:0] product;
assign product = pixel_in * weight_in;

always_ff @(posedge clk) begin
    // SYNCHRONOUS reset.
    if (!rst_n) begin
        accumulator_out <= '0;
    end
    else begin
        if (clear) begin
            accumulator_out <= '0;
        end
        else if (valid_in) begin
            accumulator_out <= accumulator_out + product;
        end
    end
end

endmodule