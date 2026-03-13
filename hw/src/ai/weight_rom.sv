module weight_rom #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8,
    parameter WEIGHT_FILE = "weights.hex" // Path to the hex file
)(
    input  logic                    clk,
    input  logic [ADDR_WIDTH-1:0]   addr,
    
    output logic signed [DATA_WIDTH-1:0] weight_out
);

logic signed [DATA_WIDTH-1:0] rom_memory [0:(2**ADDR_WIDTH)-1];

initial begin
    $readmemh(WEIGHT_FILE, rom_memory);
end

always_ff @( posedge clk ) begin
    weight_out <= rom_memory[addr];
end

endmodule