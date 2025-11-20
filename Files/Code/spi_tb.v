`timescale 1ns/1ps
module spi_tb;
    reg clk;
    reg rst_n;

    // Master control
    reg start;
    reg [7:0] master_tx;
    wire [7:0] master_rx;
    wire busy;
    wire done;

    // SPI wires
    wire sclk;
    wire mosi;
    wire miso;
    wire cs_n;

    // Slave wires
    reg [7:0] slave_tx;
    wire [7:0] slave_rx;
    wire slave_rx_ready;

    // Instantiate master: small CLK_DIV for simulation
    spi_master #(.WIDTH(8), .CLK_DIV(2)) master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(master_tx),
        .data_out(master_rx),
        .busy(busy),
        .done(done),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .miso(miso)
    );

    // Instantiate slave
    spi_slave #(.WIDTH(8)) slave_inst (
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .miso(miso),
        .tx_data(slave_tx),
        .rx_data(slave_rx),
        .rx_ready(slave_rx_ready)
    );

    // System clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    initial begin
        // dump for GTKWave
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_tb);

        // initialize
        rst_n = 0;
        start = 0;
        master_tx = 8'hA5;
        slave_tx = 8'h3C;
        #25;
        rst_n = 1;
        #20;

        // First transfer
        $display("[%0t] Starting transfer 1: Master->%02h Slave->%02h", $time, master_tx, slave_tx);
        #10 start = 1;
        #10 start = 0;

        // wait for done
        wait (done == 1);
        #20;
        $display("[%0t] Transfer 1 done: Master received %02h Slave received %02h", $time, master_rx, slave_rx);

        // small pause & clear slave rx_ready
        #40;

        // Second transfer with different data
        master_tx = 8'h5A;
        slave_tx  = 8'hC3;
        #20;
        $display("[%0t] Starting transfer 2: Master->%02h Slave->%02h", $time, master_tx, slave_tx);
        #10 start = 1;
        #10 start = 0;

        wait (done == 1);
        #20;
        $display("[%0t] Transfer 2 done: Master received %02h Slave received %02h", $time, master_rx, slave_rx);

        #100;
        $finish;
    end
endmodule
