module apb_slave_controller #(
    parameter DWIDTH = 32,
    parameter ADDRWIDTH = 32,
    parameter BASEADD = 32'h0000_0000,
    parameter MEMDEPTH = 4096
)(
    // clock and reset 
    input pclk, prstn,

    // APB Bus Interface (Inputs from master)
    input [ADDRWIDTH - 1 : 0] paddr,
    input [2:0] pprot,
    input psel, penable, pwrite, 
    input [DWIDTH - 1 : 0] pwdata,
    input [3:0] pstrb,

    //APB Bus Interface (Outputs to Master)
    output pready, pslverr, 
    output reg [DWIDTH - 1 : 0] prdata
);

    // Built-in 4096x32-bit SRAM array inside the slave wrapper
    reg [DWIDTH - 1 : 0] mem [0 : MEMDEPTH - 1]; 

    // Local address offset (removes the base address)
    wire [31:0] local_addr = paddr - BASEADD;
    
    // Shift right by 2 to map 4-byte aligned addresses 
    wire [ADDRWIDTH-1:0] word_index = local_addr >> 2;

    // Generate error if master attempts an out-of-bounds address access
    assign pslverr = (psel && penable) ? (word_index >= MEMDEPTH) : 1'b0;

    // 0 wait cycles 
    assign pready = 1'b1;

    always @(posedge pclk) begin
        if (psel && penable) begin
            if (pwrite) begin
                if (pstrb[0]) mem[word_index[11:0]][ 7: 0] <= pwdata[ 7: 0];
                if (pstrb[1]) mem[word_index[11:0]][15: 8] <= pwdata[15: 8];
                if (pstrb[2]) mem[word_index[11:0]][23:16] <= pwdata[23:16];
                if (pstrb[3]) mem[word_index[11:0]][31:24] <= pwdata[31:24];
            end else begin
                prdata <= mem[word_index[11:0]];
            end
        end
    end

    
endmodule