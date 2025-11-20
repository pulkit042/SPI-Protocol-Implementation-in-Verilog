`timescale 1ns/1ps
 module spi_slave #(
  parameter WIDTH = 8
)(
    input  wire                 sclk,    // external serial clock from master
    input  wire                 cs_n,    // chip select (active low)
    input  wire                 mosi,    // master out
    output reg                  miso,    // master in (driven by slave)
    input  wire [WIDTH-1:0]     tx_data, // data slave will send (MSB first)
    output reg [WIDTH-1:0]     rx_data, // data slave received (MSB first)
    output reg                  rx_ready // 1-cycle pulse after cs_n deassert (transfer complete)
);

    reg [WIDTH-1:0] shift_rx;
    reg [WIDTH-1:0] send_data;
    integer bit_cnt;
    reg active;

    // asynchronous block: detect CS edges and prepare
    always @(negedge cs_n or posedge cs_n) begin
        if (cs_n == 1'b0) begin
            // falling edge / active: start transfer
            send_data <= tx_data;
            // present MSB immediately so master can sample on first rising edge
            miso <= tx_data[WIDTH-1];
            bit_cnt <= 0;
            shift_rx <= {WIDTH{1'b0}};
            active <= 1'b1;
            rx_ready <= 1'b0;
        end else begin
            // cs_n asserted high -> end of transfer
            active <= 1'b0;
            rx_data <= shift_rx;
            rx_ready <= 1'b1; // one cycle pulse (in simulation it will be seen for one delta)
            miso <= 1'b0;
        end
    end

    always @(posedge sclk) begin
        if (!cs_n) begin
            shift_rx[WIDTH-1 - bit_cnt] <= mosi;
        end
    end

    always @(negedge sclk) begin
        if (!cs_n) begin
            if (bit_cnt < WIDTH-1) begin
                bit_cnt <= bit_cnt + 1;
                miso <= send_data[WIDTH-1 - (bit_cnt + 1)];
            end else begin
                miso <= 1'b0;
            end
        end
    end

endmodule
