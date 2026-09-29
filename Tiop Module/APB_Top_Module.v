module apb_subsystem_top #(
    parameter DWIDTH    = 32,
    parameter ADDRWIDTH = 32,
    parameter MEMDEPTH  = 4096
)(
    // Clock and Reset
    input pclk,
    input prstn,

    // System Request Interface (to APB Master)
    input req_valid,
    input req_write,
    input [ADDRWIDTH-1:0] req_addr,
    input [DWIDTH-1:0] req_wdata,
    input [3:0] req_strb,
    input [2:0] req_prot,

    // System Response Interface (from APB Master)
    output req_ready,
    output rsp_valid,
    output rsp_error,
    output busy,
    output done,
    output [DWIDTH-1:0] rsp_rdata
);


    // Internal Interconnect Wires

    // Master Output / APB Bus Signals
    wire [ADDRWIDTH-1:0] paddr;
    wire [2:0] pprot;
    wire psel_master; // Base psel output from Master
    wire penable;
    wire pwrite;
    wire [DWIDTH-1:0] pwdata;
    wire [3:0] pstrb;

    // Decoder Output Signals
    wire psel1_raw;
    wire psel2_raw;

    // Qualified Slave Selects (Gated with Master's psel)
    wire psel1 = psel_master & psel1_raw;
    wire psel2 = psel_master & psel2_raw;

    // Slave Outputs to Mux
    wire pready_s1, pready_s2;
    wire pslverr_s1, pslverr_s2;
    wire [DWIDTH-1:0] prdata_s1, prdata_s2;

    // Multiplexed Bus Feedback Signals (Selected based on which Slave is active)
    wire pready_bus;
    wire pslverr_bus;
    wire [DWIDTH-1:0] prdata_bus;

    
    // APB Master Controller Instantiation
    apb_master_controller #(
        .DWIDTH(DWIDTH),
        .ADDRWIDTH(ADDRWIDTH)
    ) u_apb_master (
        .pclk      (pclk),
        .prstn     (prstn),

        // System Request Interface
        .req_valid (req_valid),
        .req_write (req_write),
        .req_addr  (req_addr),
        .req_wdata (req_wdata),
        .req_strb  (req_strb),
        .req_prot  (req_prot),

        // System Response Interface
        .req_ready (req_ready),
        .rsp_valid (rsp_valid),
        .rsp_error (rsp_error),
        .busy      (busy),
        .done      (done),
        .rsp_rdata (rsp_rdata),

        // APB Bus Signals
        .pready    (pready_bus),
        .pslverr   (pslverr_bus),
        .prdata    (prdata_bus),
        .paddr     (paddr),
        .pprot     (pprot),
        .psel      (psel_master),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .pstrb     (pstrb)
    );


    // APB Address Decoder Instantiation
    apb_address_decoder #(
        .ADDRWIDTH(ADDRWIDTH)
    ) u_apb_decoder (
        .paddr     (paddr),
        .psel1     (psel1_raw),
        .psel2     (psel2_raw)
    );


    // APB Slave Controller 1 (Base Address: 0x0000_0000)
    apb_slave_controller #(
        .DWIDTH    (DWIDTH),
        .ADDRWIDTH (ADDRWIDTH),
        .BASEADD   (32'h0000_0000),
        .MEMDEPTH  (MEMDEPTH)
    ) u_slave_1 (
        .pclk      (pclk),
        .prstn     (prstn),
        .paddr     (paddr),
        .pprot     (pprot),
        .psel      (psel1),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .pstrb     (pstrb),
        .pready    (pready_s1),
        .pslverr   (pslverr_s1),
        .prdata    (prdata_s1)
    );

    
    // APB Slave Controller 2 (Base Address: 0x0000_4000)
    apb_slave_controller #(
        .DWIDTH    (DWIDTH),
        .ADDRWIDTH (ADDRWIDTH),
        .BASEADD   (32'h0000_4000),
        .MEMDEPTH  (MEMDEPTH)
    ) u_slave_2 (
        .pclk      (pclk),
        .prstn     (prstn),
        .paddr     (paddr),
        .pprot     (pprot),
        .psel      (psel2),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .pstrb     (pstrb),
        .pready    (pready_s2),
        .pslverr   (pslverr_s2),
        .prdata    (prdata_s2)
    );

    // APB Response Multiplexer
    // Route slave outputs back to the master based on active select signals
    assign pready_bus  = psel1 ? pready_s1  : (psel2 ? pready_s2  : 1'b1);
    assign pslverr_bus = psel1 ? pslverr_s1 : (psel2 ? pslverr_s2 : 1'b0);
    assign prdata_bus  = psel1 ? prdata_s1  : (psel2 ? prdata_s2  : {DWIDTH{1'b0}});

endmodule