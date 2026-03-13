module weight_rom 
    import dsp_pkg::*;
(
    input  logic                    clk,
    input  logic [ROM_ADDR_WIDTH-1:0]   addr,
    
    output logic signed [DATA_WIDTH-1:0] weight_out
);

logic signed [DATA_WIDTH-1:0] rom_memory [0:(1 << ROM_ADDR_WIDTH)-1];

initial begin
    $readmemh(WEIGHT_FILE, rom_memory);
end

always_ff @( posedge clk ) begin
    weight_out <= rom_memory[addr];
end

endmodule