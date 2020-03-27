module wb_ram (
    input   wire            wb_clk_i    ,
    input   wire            wb_rst_i    ,
    input   wire            wb_cyc_i    ,
    input   wire            wb_stb_i    ,
    input   wire            wb_we_i     ,
    input   wire    [3:0]   wb_sel_i    ,
    input   wire    [31:0]  wb_adr_i    ,
    input   wire    [31:0]  wb_dat_i    ,
    output  reg     [31:0]  wb_dat_o    ,
    output  reg             wb_ack_o
);

localparam MEM_DEPTH = 4096;

reg [31: 0] ram[MEM_DEPTH-1:0];

initial $readmemh("../frm/bootloader/bootloader.txt", ram);

// genarate ack signal
always @(posedge wb_clk_i or posedge wb_rst_i)
    if(wb_rst_i)
        wb_ack_o <= 1'b0;
    else if(wb_ack_o)
        wb_ack_o <= 1'b0;
    else if(wb_cyc_i & wb_stb_i & !wb_ack_o)
        wb_ack_o <= 1'b1;
    else wb_ack_o <= 1'b0;


always @(posedge wb_clk_i)
begin
    wb_dat_o <= ram[wb_adr_i[31:2]];
    if(wb_cyc_i & wb_stb_i & wb_we_i & wb_ack_o)
    begin
        if(wb_sel_i[0]) ram[wb_adr_i[31:2]][ 7: 0] <= wb_dat_i[ 7: 0];
        if(wb_sel_i[1]) ram[wb_adr_i[31:2]][15: 8] <= wb_dat_i[15: 8];
        if(wb_sel_i[2]) ram[wb_adr_i[31:2]][23:16] <= wb_dat_i[23:16];
        if(wb_sel_i[3]) ram[wb_adr_i[31:2]][31:24] <= wb_dat_i[31:24];
    end
end

endmodule
