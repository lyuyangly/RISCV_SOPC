module riscv_regfile (
    input               clk_i           ,
    input               rst_i           ,
    input   [4:0]       rd0_i           ,
    input   [4:0]       rd1_i           ,
    input   [4:0]       rd2_i           ,
    input   [4:0]       rd3_i           ,
    input   [31:0]      rd0_value_i     ,
    input   [31:0]      rd1_value_i     ,
    input   [31:0]      rd2_value_i     ,
    input   [31:0]      rd3_value_i     ,
    input   [4:0]       ra_i            ,
    input   [4:0]       rb_i            ,
    output  [31:0]      ra_value_o      ,
    output  [31:0]      rb_value_o
);

// Register file
reg     [31:0]      cpureg_q[31:1];

generate
    genvar k;
    for(k = 1; k < 32; k = k + 1)
    begin : G_REG
        always @(posedge clk_i or posedge rst_i)
            if(rst_i)
                cpureg_q[k] <= 32'h0000_0000;
            else if (rd0_i == k[4:0]) cpureg_q[k] <= rd0_value_i;
            else if (rd1_i == k[4:0]) cpureg_q[k] <= rd1_value_i;
            else if (rd2_i == k[4:0]) cpureg_q[k] <= rd2_value_i;
            else if (rd3_i == k[4:0]) cpureg_q[k] <= rd3_value_i;
            else ;
    end
endgenerate

// Asynchronous read
assign ra_value_o = (ra_i == 5'h0) ? 32'h0 : cpureg_q[ra_i];
assign rb_value_o = (rb_i == 5'h0) ? 32'h0 : cpureg_q[rb_i];

endmodule
