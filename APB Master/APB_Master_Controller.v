module apb_master_controller #(
    parameter DWIDTH = 32,
    parameter ADDRWIDTH = 32
)(
    // clock and reset
    input pclk, prstn,

    // system request interface 
    input req_valid, req_write, 
    input [ADDRWIDTH - 1 : 0] req_addr,
    input [DWIDTH - 1 : 0] req_wdata,
    input [3:0] req_strb,
    input [2:0] req_prot,

    // APB Bus Interface (inputs from slaves)
    input pready, pslverr,
    input [DWIDTH - 1 : 0] prdata,

    // system response interface 
    output reg req_ready, rsp_valid, rsp_error, busy, done,
    output reg [DWIDTH - 1 : 0] rsp_rdata,

    // APB Bus Interface (outputs to slaves)
    output reg [ADDRWIDTH - 1 : 0] paddr,
    output reg [2:0] pprot,
    output reg psel, 
    output wire penable,
    output reg pwrite, 
    output reg [DWIDTH - 1 : 0] pwdata, 
    output reg [3:0] pstrb 
);
    // FSM State Encoding 
    localparam IDLE = 2'b00,
               SETUP = 2'b01,
               ACCESS = 2'b10;

    reg [1:0] current_state, next_state;

    // Asserts continuously during the ACCESS state 
    assign penable = (current_state == ACCESS);

    // current state logic
    always @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // next state logic 
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (!req_valid) 
                    next_state = IDLE;
                else 
                    next_state = SETUP;
            end 

            SETUP: begin
                next_state = ACCESS;
            end

            ACCESS: begin
                if (!pready)
                    next_state = ACCESS;
                else begin
                    if (req_valid)
                        next_state = SETUP;
                    else 
                        next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // output logic 
    always @(posedge pclk or negedge prstn) begin

        if (!prstn) begin
            // default systen response signals
            req_ready <= 1;
            rsp_valid <= 0;
            rsp_error <= 0;
            busy <= 0;
            done <= 0;
            rsp_rdata <= 0;
            
            // default APB bus signals
            paddr <= 0;
            pprot <= 0;
            psel <= 0;
            pwrite <= 0;
            pwdata <= 0;
            pstrb <= 0;

        end else begin
            done <= 0;
            rsp_valid <= 0;

            case (current_state)

                IDLE: begin
                    psel <= 0;

                    if (req_valid && req_ready) begin
                        paddr <= req_addr;
                        pwdata <= req_wdata;
                        pwrite <= req_write;
                        pstrb <= req_write ? req_strb : 4'b0000;
                        pprot <= req_prot;
                        psel <= 1;
                        req_ready <= 0;
                        busy <= 1;
                    end else begin
                        req_ready <= 1;
                        busy <= 0;
                    end
                end 

                ACCESS: begin
                   if (pready) begin
                        // capture slave response 
                        rsp_rdata <= prdata;
                        rsp_error <= pslverr;
                        done <= 1;
                        rsp_valid <= 1;

                        if (req_valid) begin
                            paddr <= req_addr;
                            pwdata <= req_wdata;
                            pwrite <= req_write;
                            pstrb <= req_write ? req_strb : 4'b0000;
                            pprot <= req_prot;
                            psel <= 1;
                            busy <= 1;
                            req_ready <= 0;
                        end else begin
                            // Return to IDLE
                            busy      <= 1'b0;
                            req_ready <= 1'b1;
                            psel     <= 1'b0;
                        end
                    end
                end

            endcase
        end
    end

    
endmodule