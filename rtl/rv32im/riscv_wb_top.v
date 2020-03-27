module riscv_wb_top (
    input                   clk_i           ,
    input                   rst_i           ,
    input                   intr_i          ,
    output  reg             iwb_cyc_o       ,
    output  reg             iwb_stb_o       ,
    output  reg [31:0]      iwb_adr_o       ,
    input       [31:0]      iwb_dat_i       ,
    input                   iwb_ack_i       ,
    input                   iwb_err_i       ,
    output  reg             dwb_cyc_o       ,
    output  reg             dwb_stb_o       ,
    output  reg             dwb_we_o        ,
    output  reg [3:0]       dwb_sel_o       ,
    output  reg [31:0]      dwb_adr_o       ,
    input       [31:0]      dwb_dat_i       ,
    output  reg [31:0]      dwb_dat_o       ,
    input                   dwb_ack_i       ,
    input                   dwb_err_i
);

wire            mem_i_rd_w;
wire            mem_i_accept_w;
wire    [31:0]  mem_i_addr_w;
wire            mem_d_rd_w;
wire    [3:0]   mem_d_wr_w;
wire            mem_d_accept_w;
wire    [31:0]  mem_d_addr_w;
wire    [31:0]  mem_d_data_wr_w;
reg     [10:0]  mem_d_tag;
wire    [10:0]  mem_d_tag_w;

reg             iop_phase;
reg             ins_pop;
wire    [31:0]  ins_adr;
wire            ins_valid;
reg             dop_phase;
reg             dat_pop;
wire    [68:0]  dat_cmd;
wire            dat_valid;

// RISC-V CORE
riscv_core U_RISCV_CORE (
    .clk_i                  (clk_i                              ),
    .rst_i                  (rst_i                              ),
    .intr_i                 (intr_i                             ),
    .mem_i_rd_o             (mem_i_rd_w                         ),
    .mem_i_pc_o             (mem_i_addr_w                       ),
    .mem_i_inst_i           (iwb_dat_i                          ),
    .mem_i_error_i          (iwb_err_i                          ),
    .mem_i_flush_o          (                                   ),
    .mem_i_accept_i         (mem_i_accept_w                     ),
    .mem_i_valid_i          (iwb_ack_i                          ),
    .mem_d_accept_i         (mem_d_accept_w                     ),
    .mem_d_rd_o             (mem_d_rd_w                         ),
    .mem_d_wr_o             (mem_d_wr_w                         ),
    .mem_d_addr_o           (mem_d_addr_w                       ),
    .mem_d_data_rd_i        (dwb_dat_i                          ),
    .mem_d_data_wr_o        (mem_d_data_wr_w                    ),
    .mem_d_ack_i            (dwb_ack_i                          ),
    .mem_d_error_i          (dwb_err_i                          ),
    .mem_d_req_tag_o        (mem_d_tag_w                        ),
    .mem_d_resp_tag_i       (mem_d_tag                          ),
    .mem_d_cacheable_o      (                                   ),
    .mem_d_flush_o          (                                   ),
    .mem_d_invalidate_o     (                                   )
);

// Tag Process
always @(posedge clk_i or posedge rst_i)
    if(rst_i)
        mem_d_tag <= 'd0;
    else if(mem_d_rd_w || (|mem_d_wr_w))
        mem_d_tag <= mem_d_tag_w;

// Instruction Command FIFO
mem_fifo_wb #(.WIDTH(32)) U_WB_BIU_IFIFO (
    .clk_i      (clk_i                                                  ),
    .rst_i      (rst_i                                                  ),
    .data_in_i  (mem_i_addr_w                                           ),
    .push_i     (mem_i_rd_w                                             ),
    .pop_i      (ins_pop                                                ),
    .data_out_o (ins_adr                                                ),
    .accept_o   (mem_i_accept_w                                         ),
    .valid_o    (ins_valid                                              )
);

always @(posedge clk_i or posedge rst_i)
    if(rst_i)
    begin
        iwb_cyc_o   <= 1'b0;
        iwb_stb_o   <= 1'b0;
        iwb_adr_o   <= 32'h0;
        ins_pop     <= 1'b0;
        iop_phase   <= 1'b0;
    end
    else begin
        case(iop_phase)
            1'b0: begin
                if(ins_valid)
                begin
                    iwb_cyc_o   <= 1'b1;
                    iwb_stb_o   <= 1'b1;
                    iwb_adr_o   <= ins_adr;
                    ins_pop     <= 1'b1;
                    iop_phase   <= 1'b1;
                end
                else begin
                    iwb_cyc_o   <= 1'b0;
                    iwb_stb_o   <= 1'b0;
                    iwb_adr_o   <= 32'h0;
                    ins_pop     <= 1'b0;
                    iop_phase   <= 1'b0;
                end
            end
            1'b1: begin
                ins_pop         <= 1'b0;
                if(iwb_ack_i & iwb_stb_o & iwb_cyc_o)
                begin
                    iwb_cyc_o   <= 1'b0;
                    iwb_stb_o   <= 1'b0;
                    iwb_adr_o   <= 32'h0;
                    iop_phase   <= 1'b0;
                end
            end
        endcase
   end

// Data Command FIFO
mem_fifo_wb #(.WIDTH(69)) U_WB_BIU_DFIFO (
    .clk_i      (clk_i                                                  ),
    .rst_i      (rst_i                                                  ),
    .data_in_i  ({mem_d_rd_w, mem_d_wr_w, mem_d_addr_w, mem_d_data_wr_w}),
    .push_i     (mem_d_rd_w || (|mem_d_wr_w)                            ),
    .pop_i      (dat_pop                                                ),
    .data_out_o (dat_cmd                                                ),
    .accept_o   (mem_d_accept_w                                         ),
    .valid_o    (dat_valid                                              )
);

always @(posedge clk_i or posedge rst_i)
    if(rst_i)
    begin
        dwb_cyc_o   <= 1'b0;
        dwb_stb_o   <= 1'b0;
        dwb_we_o    <= 1'b0;
        dwb_sel_o   <= 4'h0;
        dwb_adr_o   <= 32'h0;
        dat_pop     <= 1'b0;
        dop_phase   <= 1'b0;
    end
    else begin
        case(dop_phase)
            1'b0: begin
                if(dat_valid)
                begin
                    dwb_cyc_o   <= 1'b1;
                    dwb_stb_o   <= 1'b1;
                    dwb_we_o    <= |dat_cmd[67:64];
                    dwb_sel_o   <= dat_cmd[68] ? 4'hf : dat_cmd[67:64];
                    dwb_adr_o   <= dat_cmd[63:32];
                    dwb_dat_o   <= dat_cmd[31:0];
                    dat_pop     <= 1'b1;
                    dop_phase   <= 1'b1;
                end
                else begin
                    dwb_cyc_o   <= 1'b0;
                    dwb_stb_o   <= 1'b0;
                    dwb_we_o    <= 1'b0;
                    dwb_sel_o   <= 4'h0;
                    dwb_adr_o   <= 32'h0;
                    dwb_dat_o   <= 32'h0;
                    dat_pop     <= 1'b0;
                    dop_phase   <= 1'b0;
                end
            end
            1'b1: begin
                dat_pop         <= 1'b0;
                if(dwb_ack_i & dwb_stb_o & dwb_cyc_o)
                begin
                    dwb_cyc_o   <= 1'b0;
                    dwb_stb_o   <= 1'b0;
                    dwb_we_o    <= 1'b0;
                    dwb_sel_o   <= 4'h0;
                    dwb_adr_o   <= 32'h0;
                    dwb_dat_o   <= 32'h0;
                    dop_phase   <= 1'b0;
                end
            end
        endcase
   end

endmodule
