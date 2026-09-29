module apb_address_decoder #(
    parameter ADDRWIDTH = 32
)(
    input wire [ADDRWIDTH-1:0] paddr,
    output reg psel1, // Select for Slave 1 (0x0000_0000 - 0x0000_3FFF)
    output reg psel2  // Select for Slave 2 (0x0000_4000 - 0x0000_7FFF)
);

    always @(*) begin
        psel1 = 1'b0;
        psel2 = 1'b0;

        if (paddr >= 32'h0000_0000 && paddr <= 32'h0000_3FFF) begin
            psel1 = 1'b1;
        end else if (paddr >= 32'h0000_4000 && paddr <= 32'h0000_7FFF) begin
            psel2 = 1'b1;
        end
    end

endmodule