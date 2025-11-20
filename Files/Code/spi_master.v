`timescale 1ns/1ps
`include "./spi_slave.v"
module spi_master #(
    parameter WIDTH = 8,
    parameter CLK_DIV = 4
)(
    input  wire                 clk,       // system clock
    input  wire                 rst_n,     // active-low reset
    input  wire                 start,     // start pulse (1 cycle)
    input  wire [WIDTH-1:0]     data_in,   // data to send (MSB first)
    output reg  [WIDTH-1:0]     data_out,  // data received
    output reg                  busy,
    output reg                  done,      // one-cycle pulse on completion
    // SPI lines (master driven)
    output reg                  sclk,      // serial clock (CPOL=0 idle low)
    output reg                  mosi,      // master out
    output reg                  cs_n,      // chip select active low
    input  wire                 miso       // master in
);

    localparam IDLE = 2'b00, TRANSFER = 2'b01, DONE = 2'b10;
    reg [1:0] state, next_state;

    // internal registers
    reg [WIDTH-1:0] data_reg;       // holds original data_in
    reg [WIDTH-1:0] shift_rx;       // receiver assembly
    reg [$clog2(WIDTH):0] bit_cnt;  // counts 0..WIDTH-1, needs enough bits
    integer clk_cnt;
    reg done_flag;

    // state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // next state combinational
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = TRANSFER;
            TRANSFER: if (done_flag) next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset all
            sclk <= 1'b0;
            mosi <= 1'b0;
            cs_n <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            data_out <= {WIDTH{1'b0}};
            data_reg <= {WIDTH{1'b0}};
            shift_rx <= {WIDTH{1'b0}};
            bit_cnt <= 0;
            clk_cnt <= 0;
            done_flag <= 1'b0;
        end else begin
            done <= 1'b0; // default done pulse low

            case (state)
                IDLE: begin
                    // idle values
                    sclk <= 1'b0; // CPOL = 0
                    clk_cnt <= 0;
                    bit_cnt <= 0;
                    busy <= 1'b0;
                    cs_n <= 1'b1;
                    done_flag <= 1'b0;
                    shift_rx <= {WIDTH{1'b0}};

                    if (start) begin
                        // prepare transfer
                        data_reg <= data_in;
                        cs_n <= 1'b0;             // assert CS
                        busy <= 1'b1;
                        // present first MOSI bit (MSB) immediately so it's stable before first rising edge
                        mosi <= data_in[WIDTH-1];
                        bit_cnt <= 0;
                        clk_cnt <= 0;
                    end
                end

                TRANSFER: begin
                    // clock divider: toggle sclk every CLK_DIV cycles
                    if (clk_cnt >= (CLK_DIV - 1)) begin
                        clk_cnt <= 0;
                        sclk <= ~sclk;
                        // after toggling sclk, take action depending on new sclk value
                        if (sclk == 1'b0) begin
                            // we just made it 1 (rising edge occurred)
                            // sample MISO for current bit index
                            shift_rx[WIDTH-1 - bit_cnt] <= miso;
                            // if this was the last bit sampled, set done_flag
                            if (bit_cnt == (WIDTH - 1)) begin
                                done_flag <= 1'b1;
                            end
                        end else begin
                            // sclk was 1 and is now 0 -> falling edge
                            // prepare next MOSI bit if any remain
                            if (bit_cnt < (WIDTH - 1)) begin
                                bit_cnt <= bit_cnt + 1;
                                mosi <= data_reg[WIDTH-1 - (bit_cnt + 1)];
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                DONE: begin
                    cs_n <= 1'b1;        // deassert CS
                    busy <= 1'b0;
                    done <= 1'b1;        // one-cycle pulse
                    data_out <= shift_rx; // latch received assembled word
                    // reset sclk to idle low
                    sclk <= 1'b0;
                    // clear done_flag for next transfer
                    done_flag <= 1'b0;
                    // ensure MOSI reset (not required)
                    mosi <= 1'b0;
                end

                default: begin end
            endcase
        end
    end
endmodule
