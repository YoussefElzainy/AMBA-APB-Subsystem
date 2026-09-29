`timescale 1ns/1ps
//=============================================================================
// Self-checking testbench for apb_master_controller
// Updated to match single-psel master controller architecture.
//=============================================================================

module tb_apb_master_controller;

    localparam DWIDTH    = 32;
    localparam ADDRWIDTH = 32;

    // ---------------------------------------------------------------
    // DUT I/O
    // ---------------------------------------------------------------
    reg  pclk, prstn;

    reg  req_valid, req_write;
    reg  [ADDRWIDTH-1:0] req_addr;
    reg  [DWIDTH-1:0]    req_wdata;
    reg  [3:0]  req_strb;
    reg  [2:0]  req_prot;

    reg  pready, pslverr;
    reg  [DWIDTH-1:0] prdata;

    wire req_ready, rsp_valid, rsp_error, busy, done;
    wire [DWIDTH-1:0] rsp_rdata;

    wire [ADDRWIDTH-1:0] paddr;
    wire [2:0]  pprot;
    wire psel, penable, pwrite;
    wire [DWIDTH-1:0] pwdata;
    wire [3:0]  pstrb;

    // DUT Instantiation
    apb_master_controller #(
        .DWIDTH(DWIDTH), 
        .ADDRWIDTH(ADDRWIDTH)
    ) dut (
        .pclk(pclk),
        .prstn(prstn),
        .req_valid(req_valid),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_strb(req_strb),
        .req_prot(req_prot),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata),
        .req_ready(req_ready),
        .rsp_valid(rsp_valid),
        .rsp_error(rsp_error),
        .busy(busy),
        .done(done),
        .rsp_rdata(rsp_rdata),
        .paddr(paddr),
        .pprot(pprot),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pstrb(pstrb)
    );

    // ---------------------------------------------------------------
    // Clock / Reset Generation
    // ---------------------------------------------------------------
    initial pclk = 0;
    always #5 pclk = ~pclk;

    initial begin
        prstn = 0;
        repeat (4) @(posedge pclk);
        prstn = 1;
    end

    // ---------------------------------------------------------------
    // Scoreboard / Pass-Fail Bookkeeping
    // ---------------------------------------------------------------
    integer checks_total  = 0;
    integer checks_passed = 0;
    integer checks_failed = 0;

    task check(input cond, input [8*80-1:0] msg);
        begin
            checks_total = checks_total + 1;
            if (cond) begin
                checks_passed = checks_passed + 1;
                $display("[%0t] PASS: %0s", $time, msg);
            end else begin
                checks_failed = checks_failed + 1;
                $display("[%0t] **** FAIL: %0s", $time, msg);
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Behavioral APB Slave Model (Memory-mapped)
    // ---------------------------------------------------------------
    reg [31:0] mem [0:127];

    // Test control knobs
    integer wait_cfg          = 0;  // Extra wait cycles inserted by slave
    reg     err_inject        = 0;  // Slave asserts PSLVERR on completion
    reg     invalid_addr_mode = 0;  // Simulates unmapped target response

    integer access_cnt;

    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            pready     <= 1'b0;
            pslverr    <= 1'b0;
            prdata     <= {DWIDTH{1'b0}};
            access_cnt <= 0;
        end else begin
            if (invalid_addr_mode && psel && penable) begin
                if (access_cnt < 1) begin
                    pready     <= 1'b0;
                    pslverr    <= 1'b0;
                    access_cnt <= access_cnt + 1;
                end else begin
                    pready     <= 1'b1;
                    pslverr    <= 1'b1; // Unmapped access -> error response
                    prdata     <= {DWIDTH{1'b0}};
                    access_cnt <= 0;
                end
            end else if (psel && penable) begin
                if (access_cnt < wait_cfg) begin
                    pready     <= 1'b0;
                    pslverr    <= 1'b0;
                    access_cnt <= access_cnt + 1;
                end else begin
                    pready     <= 1'b1;
                    pslverr    <= err_inject;
                    access_cnt <= 0;
                    if (pwrite) begin
                        if (pstrb[0]) mem[paddr[8:2]][7:0]   <= pwdata[7:0];
                        if (pstrb[1]) mem[paddr[8:2]][15:8]  <= pwdata[15:8];
                        if (pstrb[2]) mem[paddr[8:2]][23:16] <= pwdata[23:16];
                        if (pstrb[3]) mem[paddr[8:2]][31:24] <= pwdata[31:24];
                    end else begin
                        prdata <= mem[paddr[8:2]];
                    end
                end
            end else begin
                pready     <= 1'b0;
                pslverr    <= 1'b0;
                access_cnt <= 0;
            end
        end
    end

    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) begin
            mem[i] = 32'h0;
        end
    end

    // ---------------------------------------------------------------
    // Black-Box Protocol Checkers
    // ---------------------------------------------------------------
    reg psel_d, penable_d, pready_d, pwrite_d;
    reg [ADDRWIDTH-1:0] paddr_d;
    reg [DWIDTH-1:0]    pwdata_d;
    reg [3:0]           pstrb_d;
    reg [2:0]           pprot_d;
    reg setup_started_d;

    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            psel_d          <= 0; 
            penable_d       <= 0; 
            pready_d        <= 0; 
            pwrite_d        <= 0;
            paddr_d         <= 0; 
            pwdata_d        <= 0; 
            pstrb_d         <= 0; 
            pprot_d         <= 0;
            setup_started_d <= 0;
        end else begin
            psel_d          <= psel;
            penable_d       <= penable;
            pready_d        <= pready;
            pwrite_d        <= pwrite;
            paddr_d         <= paddr;
            pwdata_d        <= pwdata;
            pstrb_d         <= pstrb;
            pprot_d         <= pprot;
            setup_started_d <= (psel && !psel_d); // Rising edge = SETUP
        end
    end

    // C1: Reset State
    initial begin
        @(negedge prstn);
        #1;
        check(psel == 0 && penable == 0, "C1a: PSEL/PENABLE are 0 during reset");
    end

    always @(posedge prstn) begin
        #1;
        check(req_ready == 1'b1, "C1b: req_ready is HIGH immediately after reset deasserts");
        check(busy == 1'b0 && done == 1'b0 && rsp_valid == 1'b0, "C1c: busy/done/rsp_valid are 0 after reset");
    end

    // C2: PSTRB must be 0 on Reads
    always @(posedge pclk) if (prstn) begin
        if (psel && !pwrite)
            check(pstrb == 4'b0000, "C2: PSTRB is 4'b0000 during a read transfer");
    end

    // C3: Stability of Control/Address/Data During Wait States
    always @(posedge pclk) if (prstn) begin
        if (psel_d && penable_d && !pready_d) begin
            check(paddr  == paddr_d,  "C3a: PADDR stable during wait state");
            check(pwrite == pwrite_d, "C3b: PWRITE stable during wait state");
            check(pwdata == pwdata_d, "C3c: PWDATA stable during wait state");
            check(pstrb  == pstrb_d,  "C3d: PSTRB stable during wait state");
            check(pprot  == pprot_d,  "C3e: PPROT stable during wait state");
            check(psel   == psel_d,   "C3f: PSEL stable during wait state");
        end
    end

    // C4: SETUP to ACCESS Timing Sequence
    always @(posedge pclk) if (prstn) begin
        if (setup_started_d)
            check(penable == 1'b1, "C4: PENABLE is HIGH exactly one cycle after PSEL first asserts");
    end

    // C5: Pulsed Signals Integrity
    reg done_d, rspvalid_d;
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            done_d <= 0; rspvalid_d <= 0;
        end else begin
            done_d <= done; rspvalid_d <= rsp_valid;
        end
    end

    always @(posedge pclk) if (prstn) begin
        if (done && done_d)
            check(1'b0, "C5a: DONE deasserts after exactly one cycle");
        if (rsp_valid && rspvalid_d)
            check(1'b0, "C5b: RSP_VALID deasserts after exactly one cycle");
    end

    // ---------------------------------------------------------------
    // Driver Task
    // ---------------------------------------------------------------
    reg [DWIDTH-1:0] last_rdata;
    reg              last_error;
    integer          cycles_to_done;

    task do_request(
        input wr,
        input [ADDRWIDTH-1:0] addr,
        input [DWIDTH-1:0] wdata,
        input [3:0] strb,
        input [2:0] prot
    );
        begin
            while (!req_ready) @(posedge pclk);
            @(negedge pclk);
            req_write = wr;
            req_addr  = addr;
            req_wdata = wdata;
            req_strb  = strb;
            req_prot  = prot;
            req_valid = 1'b1;
            @(posedge pclk);
            @(negedge pclk);
            req_valid = 1'b0;

            cycles_to_done = 0;
            while (!done) begin
                @(posedge pclk);
                cycles_to_done = cycles_to_done + 1;
                if (cycles_to_done > 1000) begin
                    $display("[%0t] **** FAIL: Request timed out waiting for done", $time);
                    checks_failed = checks_failed + 1;
                    checks_total  = checks_total + 1;
                    disable do_request;
                end
            end
            last_rdata = rsp_rdata;
            last_error = rsp_error;
            @(negedge pclk);
        end
    endtask

    // ---------------------------------------------------------------
    // Directed Test Sequence
    // ---------------------------------------------------------------
    reg [31:0] expected;
    integer k;
    reg [6:0]  raddr;
    reg [31:0] rdata;
    reg [3:0]  rstrb;
    reg [31:0] before_val, exp_val;
    integer    rlat;

    initial begin
        req_valid = 0; req_write = 0; req_addr = 0; 
        req_wdata = 0; req_strb = 4'b0000; req_prot = 3'b000;
        wait_cfg = 0; err_inject = 0; invalid_addr_mode = 0;

        @(posedge prstn);
        repeat (2) @(posedge pclk);

        $display("\n===== TEST 1: Basic Write, Zero Wait States =====");
        wait_cfg = 0; err_inject = 0;
        do_request(1, 32'h0000_0020, 32'hDEAD_BEEF, 4'b1111, 3'b000);
        check(last_error == 1'b0, "T1: Write completes without error");
        check(mem[32'h20>>2] == 32'hDEAD_BEEF, "T1: Memory updated with written data");

        $display("\n===== TEST 2: Basic Read, Zero Wait States =====");
        do_request(0, 32'h0000_0020, 32'h0, 4'b0000, 3'b000);
        check(last_error == 1'b0, "T2: Read completes without error");
        check(last_rdata == 32'hDEAD_BEEF, "T2: Read data matches written value");

        $display("\n===== TEST 3: Write with Wait States (Latency=3) =====");
        wait_cfg = 3;
        do_request(1, 32'h0000_0024, 32'h1234_5678, 4'b1111, 3'b000);
        check(last_error == 1'b0, "T3: Wait-state write completes without error");
        check(mem[32'h24>>2] == 32'h1234_5678, "T3: Memory updated after wait states");
        wait_cfg = 0;

        $display("\n===== TEST 4: Read with Wait States (Latency=2) =====");
        wait_cfg = 2;
        do_request(0, 32'h0000_0024, 32'h0, 4'b0000, 3'b000);
        check(last_error == 1'b0, "T4: Wait-state read completes without error");
        check(last_rdata == 32'h1234_5678, "T4: Wait-state read data correct");
        wait_cfg = 0;

        $display("\n===== TEST 5: PSTRB Partial Byte Writes =====");
        do_request(1, 32'h0000_0028, 32'h1122_3344, 4'b1111, 3'b000);
        do_request(1, 32'h0000_0028, 32'hAABB_CCDD, 4'b0011, 3'b000);
        expected = 32'h1122_CCDD;
        check(mem[32'h28>>2] == expected, "T5: PSTRB=0011 updates only low byte lanes");

        $display("\n===== TEST 6: PSLVERR Injected on Write =====");
        err_inject = 1;
        do_request(1, 32'h0000_0030, 32'h0000_0001, 4'b1111, 3'b000);
        check(last_error == 1'b1, "T6: rsp_error reflects PSLVERR injected by slave");
        err_inject = 0;

        $display("\n===== TEST 7: PSLVERR Injected on Read =====");
        err_inject = 1;
        do_request(0, 32'h0000_0030, 32'h0, 4'b0000, 3'b000);
        check(last_error == 1'b1, "T7: rsp_error reflects PSLVERR on read");
        err_inject = 0;

        $display("\n===== TEST 8: Unmapped Address Handling =====");
        invalid_addr_mode = 1;
        do_request(1, 32'hFFFF_FFF0, 32'hDEAD_0000, 4'b1111, 3'b000);
        check(last_error == 1'b1, "T8: Unmapped access reports error response");
        invalid_addr_mode = 0;

        $display("\n===== TEST 9: Back-to-Back Transfers =====");
        wait_cfg = 1;
        while (!req_ready) @(posedge pclk);
        @(negedge pclk);
        req_write = 1; req_addr = 32'h0000_0034; req_wdata = 32'hA5A5_A5A5;
        req_strb = 4'b1111; req_prot = 0; req_valid = 1;

        @(posedge pclk);
        @(negedge pclk);
        req_addr  = 32'h0000_0038;
        req_wdata = 32'h5A5A_5A5A;
        req_strb  = 4'b1111;
        req_write = 1;

        cycles_to_done = 0;
        while (!done) begin
            @(posedge pclk);
            cycles_to_done = cycles_to_done + 1;
            if (cycles_to_done > 1000) begin
                $display("[%0t] **** FAIL: Back-to-back first transfer timeout", $time);
                checks_failed = checks_failed + 1; checks_total = checks_total + 1;
                disable do_request;
            end
        end
        @(negedge pclk);
        req_valid = 0;

        cycles_to_done = 0;
        while (!done) begin
            @(posedge pclk);
            cycles_to_done = cycles_to_done + 1;
            if (cycles_to_done > 1000) begin
                $display("[%0t] **** FAIL: Back-to-back second transfer timeout", $time);
                checks_failed = checks_failed + 1; checks_total = checks_total + 1;
                disable do_request;
            end
        end
        check(mem[32'h34>>2] == 32'hA5A5_A5A5, "T9a: First back-to-back write completed");
        check(mem[32'h38>>2] == 32'h5A5A_5A5A, "T9b: Second back-to-back write completed");
        wait_cfg = 0;

        $display("\n===== TEST 10: Randomized Regression =====");
        for (k = 0; k < 30; k = k + 1) begin
            raddr = $random % 120;
            rdata = $random;
            rstrb = $random;
            if (rstrb == 4'b0000) rstrb = 4'b1111;
            rlat  = $random % 4;
            wait_cfg = rlat;

            before_val = mem[raddr];
            do_request(1, {23'h0, raddr, 2'b00}, rdata, rstrb, 3'b000);
            exp_val = before_val;
            if (rstrb[0]) exp_val[7:0]   = rdata[7:0];
            if (rstrb[1]) exp_val[15:8]  = rdata[15:8];
            if (rstrb[2]) exp_val[23:16] = rdata[23:16];
            if (rstrb[3]) exp_val[31:24] = rdata[31:24];

            check(mem[raddr] == exp_val, "T10w: Randomized write data correct");

            do_request(0, {23'h0, raddr, 2'b00}, 32'h0, 4'b0000, 3'b000);
            check(last_rdata == exp_val, "T10r: Randomized readback data matches");
        end
        wait_cfg = 0;

        repeat (5) @(posedge pclk);
        $display("\n=====================================================");
        $display(" TOTAL CHECKS : %0d", checks_total);
        $display(" PASSED       : %0d", checks_passed);
        $display(" FAILED       : %0d", checks_failed);
        $display("=====================================================\n");
        if (checks_failed != 0) begin
            $display("RESULT: FAIL (%0d of %0d checks failed)", checks_failed, checks_total);
            $finish;
        end else begin
            $display("RESULT: ALL CHECKS PASSED");
            $finish;
        end
    end

    // ---------------------------------------------------------------
    // PPROT Monitor
    // ---------------------------------------------------------------
    reg [2:0] expected_prot;
    always @(posedge pclk) if (prstn) begin
        if (setup_started_d) begin
            check(pprot == expected_prot, "PPROT: PPROT output matches requested value");
        end
    end
    always @(posedge pclk) if (prstn) begin
        if (req_valid && req_ready)
            expected_prot <= req_prot;
    end

    // Waveform Dump
    initial begin
        $dumpfile("apb_tb.vcd");
        $dumpvars(0, tb_apb_master_controller);
    end

endmodule