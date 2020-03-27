`timescale 1ns / 1ns
module riscv_sopc_tb;

reg             clk;
reg             rst_n;
wire    [3:0]   led;

riscv_sopc  U_DUT (
    .clk                (clk            ),
    .rst_n              (rst_n          ),
    .uart_txd           (),
    .uart_rxd           (1'b1           ),
    .key                (4'ha           ),
    .led                (led            )
);

initial forever #10.0 clk = ~clk;

initial begin
    clk  = 1'b0;
    rst_n = 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    rst_n =1'b1;
    #500000;
    $finish;
end

initial begin
    $vcdplusfile("riscv_sopc_tb.vpd");
    $vcdpluson(0);
end

endmodule
