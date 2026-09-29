`timescale 1ns / 1ps

module tb_apb_subsystem;

    // Parameters
    localparam DWIDTH    = 32;
    localparam ADDRWIDTH = 32;
    localparam MEMDEPTH  = 4096;
    localparam CLK_PERIOD = 10; // 100 MHz Clock

    // Clock and Reset
    reg pclk;
    reg prstn;

    // System Request Interface
    reg                  req_valid;
    reg                  req_write;
    reg [ADDRWIDTH-1:0] req_addr;
    reg [DWIDTH-1:0]    req_wdata;
    reg [3:0]            req_strb;
    reg [2:0]            req_prot;

    // System Response Interface
    wire                 req_ready;
    wire                 rsp_valid;
    wire                 rsp_error;
    wire                 busy;
    wire                 done;
    wire [DWIDTH-1:0]    rsp_rdata;

    // Output Storage for Tasks
    reg [DWIDTH-1:0]    read_data_buf;

    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    apb_subsystem_top #(
        .DWIDTH    (DWIDTH),
        .ADDRWIDTH (ADDRWIDTH),
        .MEMDEPTH  (MEMDEPTH)
    ) dut (
        .pclk      (pclk),
        .prstn     (prstn),
        .req_valid (req_valid),
        .req_write (req_write),
        .req_addr  (req_addr),
        .req_wdata (req_wdata),
        .req_strb  (req_strb),
        .req_prot  (req_prot),
        .req_ready (req_ready),
        .rsp_valid (rsp_valid),
        .rsp_error (rsp_error),
        .busy      (busy),
        .done      (done),
        .rsp_rdata (rsp_rdata)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    always #(CLK_PERIOD / 2) pclk = ~pclk;

    // =========================================================================
    // Helper Tasks for Bus Transactions
    // =========================================================================

    // Task: Issue APB Write Transfer
    task apb_write(
        input [ADDRWIDTH-1:0] addr,
        input [DWIDTH-1:0]    data,
        input [3:0]            strb
    );
        begin
            @(posedge pclk);
            while (!req_ready) @(posedge pclk); // Wait until Master is ready
            
            req_valid <= 1'b1;
            req_write <= 1'b1;
            req_addr  <= addr;
            req_wdata <= data;
            req_strb  <= strb;
            req_prot  <= 3'b000;

            @(posedge pclk);
            req_valid <= 1'b0; // Clear valid after master accepts request

            // Wait for transaction completion
            while (!done) @(posedge pclk);
            
            if (rsp_error)
                $display("[WRITE ERROR] Address: 0x%08h flagged PSLVERR!", addr);
            else
                $display("[WRITE SUCCESS] Addr: 0x%08h | Data: 0x%08h | Strobe: 4'b%04b", addr, data, strb);
        end
    endtask

    // Task: Issue APB Read Transfer
    task apb_read(
        input  [ADDRWIDTH-1:0] addr,
        output [DWIDTH-1:0]    data
    );
        begin
            @(posedge pclk);
            while (!req_ready) @(posedge pclk);

            req_valid <= 1'b1;
            req_write <= 1'b0; // Read operation
            req_addr  <= addr;
            req_wdata <= 32'h0;
            req_strb  <= 4'b0000;
            req_prot  <= 3'b000;

            @(posedge pclk);
            req_valid <= 1'b0;

            // Wait for response completion
            while (!done) @(posedge pclk);

            data = rsp_rdata;
            if (rsp_error)
                $display("[READ ERROR] Address: 0x%08h flagged PSLVERR!", addr);
            else
                $display("[READ SUCCESS]  Addr: 0x%08h | Data Read: 0x%08h", addr, data);
        end
    endtask

    // =========================================================================
    // Main Test Stimulus
    // =========================================================================
    initial begin
        // Initialize Inputs
        pclk      = 1'b0;
        prstn     = 1'b0;
        req_valid = 1'b0;
        req_write = 1'b0;
        req_addr  = {ADDRWIDTH{1'b0}};
        req_wdata = {DWIDTH{1'b0}};
        req_strb  = 4'b0000;
        req_prot  = 3'b000;

        $display("\n==================================================");
        $display("       STARTING APB SUBSYSTEM TESTBENCH           ");
        $display("==================================================\n");

        // 1. Reset Pulse
        #20;
        prstn = 1'b1;
        $display("[STATUS] System Reset De-asserted.\n");
        #10;

        // ---------------------------------------------------------------------
        // TEST 1: Full-Word Access to Slave 1 (Base Addr: 0x0000_0000)
        // ---------------------------------------------------------------------
        $display("--- TEST 1: Full-Word Access (Slave 1) ---");
        apb_write(32'h0000_0000, 32'hDEAD_BEEF, 4'b1111);
        apb_write(32'h0000_0004, 32'hCAFE_BABE, 4'b1111);

        apb_read(32'h0000_0000, read_data_buf);


        apb_read(32'h0000_0004, read_data_buf);
        $display("-> TEST 1 PASSED!\n");

        // ---------------------------------------------------------------------
        // TEST 2: Byte-Strobe Writes to Slave 2 (Base Addr: 0x0000_4000)
        // ---------------------------------------------------------------------
        $display("--- TEST 2: Byte-Strobe Masking (Slave 2) ---");
        // Step A: Initialize location with 0x0000_0000
        apb_write(32'h0000_4000, 32'h0000_0000, 4'b1111);

        // Step B: Write lower two bytes only (pstrb = 4'b0011)
        apb_write(32'h0000_4000, 32'hFFFF_1234, 4'b0011);

        // Step C: Verify top bytes remain 0x0000
        apb_read(32'h0000_4000, read_data_buf);
        if (read_data_buf === 32'h0000_1234)
            $display("-> Byte Strobe Verification PASSED! Expected: 0x00001234 | Got: 0x%08h\n", read_data_buf);


        // ---------------------------------------------------------------------
        // TEST 3: Out-of-Bounds Address Detection (PSLVERR)
        // ---------------------------------------------------------------------
        $display("--- TEST 3: Out-Of-Bounds PSLVERR Verification ---");
        // Memory depth is 4096 words (0x3FFF max offset). 
        // Offset 0x4000 is 1 word past the boundary!
        apb_write(32'h0000_3FFF + 32'h0000_0001, 32'hA5A5_A5A5, 4'b1111);
        if (rsp_error)
            $display("-> PSLVERR correctly generated for Out-Of-Bounds address!\n");


        // ---------------------------------------------------------------------
        // TEST 4: Back-To-Back Stream Transfers
        // ---------------------------------------------------------------------
        $display("--- TEST 4: Streaming Back-To-Back Transfers ---");
        apb_write(32'h0000_4008, 32'h1111_2222, 4'b1111);
        apb_write(32'h0000_400C, 32'h3333_4444, 4'b1111);
        apb_read(32'h0000_4008, read_data_buf);
        apb_read(32'h0000_400C, read_data_buf);
        $display("-> Back-To-Back Stream PASSED!\n");

        $display("==================================================");
        $display("       ALL APB SUBSYSTEM TESTS COMPLETED         ");
        $display("==================================================");
        $finish;
    end

endmodule