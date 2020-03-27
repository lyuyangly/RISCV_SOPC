module riscv_sopc (
    input               clk             ,
    input               rst_n           ,
    output              uart_txd        ,
    input               uart_rxd        ,
    input   [3:0]       key             ,
    output  [3:0]       led
);

wire                rst_sync;

wire                iwb_ack_i;
wire                iwb_cyc_o;
wire                iwb_stb_o;
wire    [31:0]      iwb_dat_i;
wire    [31:0]      iwb_dat_o;
wire    [31:0]      iwb_adr_o;
wire    [3:0]       iwb_sel_o;
wire                iwb_we_o;
wire                iwb_err_i;
wire                iwb_rty_i;

wire                dwb_ack_i;
wire                dwb_cyc_o;
wire                dwb_stb_o;
wire    [31:0]      dwb_dat_i;
wire    [31:0]      dwb_dat_o;
wire    [31:0]      dwb_adr_o;
wire                dwb_we_o;
wire    [3:0]       dwb_sel_o;
wire                dwb_err_i;
wire                dwb_rty_i;

wire                ram_ack_o;
wire                ram_cyc_i;
wire                ram_stb_i;
wire    [31:0]      ram_dat_i;
wire    [31:0]      ram_dat_o;
wire    [31:0]      ram_adr_i;
wire                ram_we_i;
wire    [3:0]       ram_sel_i;

wire                uart_cyc_i;
wire                uart_we_i;
wire    [3:0]       uart_sel_i;
wire                uart_stb_i;
wire    [31:0]      uart_adr_i;
wire    [31:0]      uart_dat_i;
wire    [31:0]      uart_dat_o;
wire                uart_ack_o;
wire                uart_irq;

wire                gpio_ack_o;
wire                gpio_cyc_i;
wire                gpio_stb_i;
wire    [31:0]      gpio_dat_i;
wire    [31:0]      gpio_dat_o;
wire    [31:0]      gpio_adr_i;
wire    [3:0]       gpio_sel_i;
wire                gpio_we_i;
wire                gpio_err_o;
wire                gpio_irq;
wire    [31:0]      gpio_pad_w;

rst_sync U_RST_SYNC (
    .clk                (clk                ),
    .arst_i             (rst_n              ),
    .srst_o             (rst_sync           )
);

riscv_wb_top    U_RISCV (
    .clk_i              (clk                ),
    .rst_i              (rst_sync           ),
    .intr_i             (1'b0               ),
    .iwb_cyc_o          (iwb_cyc_o          ),
    .iwb_stb_o          (iwb_stb_o          ),
    .iwb_adr_o          (iwb_adr_o          ),
    .iwb_dat_i          (iwb_dat_i          ),
    .iwb_ack_i          (iwb_ack_i          ),
    .iwb_err_i          (1'b0               ),
    .dwb_cyc_o          (dwb_cyc_o          ),
    .dwb_stb_o          (dwb_stb_o          ),
    .dwb_we_o           (dwb_we_o           ),
    .dwb_sel_o          (dwb_sel_o          ),
    .dwb_adr_o          (dwb_adr_o          ),
    .dwb_dat_i          (dwb_dat_i          ),
    .dwb_dat_o          (dwb_dat_o          ),
    .dwb_ack_i          (dwb_ack_i          ),
    .dwb_err_i          (1'b0               )
);

/*
picorv32_wb U_PICORV32 (
    .wb_clk_i           (clk                ),
    .wb_rst_i           (rst_sync           ),
    .wbm_cyc_o          (dwb_cyc_o          ),
    .wbm_stb_o          (dwb_stb_o          ),
    .wbm_we_o           (dwb_we_o           ),
    .wbm_sel_o          (dwb_sel_o          ),
    .wbm_adr_o          (dwb_adr_o          ),
    .wbm_dat_i          (dwb_dat_i          ),
    .wbm_dat_o          (dwb_dat_o          ),
    .wbm_ack_i          (dwb_ack_i          ),
    .pcpi_wr            (1'b0               ),
    .pcpi_rd            (32'h0              ),
    .pcpi_wait          (1'b0               ),
    .pcpi_ready         (1'b0               ),
    .pcpi_valid         (                   ),
    .pcpi_insn          (                   ),
    .pcpi_rs1           (                   ),
    .pcpi_rs2           (                   ),
    .irq                (32'h0              ),
    .eoi                (                   ),
    .trace_data         (                   ),
    .trace_valid        (                   ),
    .trap               (                   ),
    .mem_instr          (                   )
);
*/

wb_conmax_top U_WB_CONMAX (
    .clk_i              (clk                ),
    .rst_i              (rst_sync           ),

    // Master 0 Interface
    .m0_data_i          (32'd0              ),
    .m0_data_o          (iwb_dat_i          ),
    .m0_addr_i          (iwb_adr_o          ),
    .m0_sel_i           (4'hf               ),
    .m0_we_i            (1'b0               ),
    .m0_cyc_i           (iwb_cyc_o          ),
    .m0_stb_i           (iwb_stb_o          ),
    .m0_ack_o           (iwb_ack_i          ),
    .m0_err_o           (                   ),
    .m0_rty_o           (                   ),

    // Master 1 Interface
    .m1_data_i          (dwb_dat_o          ),
    .m1_data_o          (dwb_dat_i          ),
    .m1_addr_i          (dwb_adr_o          ),
    .m1_sel_i           (dwb_sel_o          ),
    .m1_we_i            (dwb_we_o           ),
    .m1_cyc_i           (dwb_cyc_o          ),
    .m1_stb_i           (dwb_stb_o          ),
    .m1_ack_o           (dwb_ack_i          ),
    .m1_err_o           (                   ),
    .m1_rty_o           (                   ),

    // Slave 0 Interface
    .s0_data_i          (ram_dat_o          ),
    .s0_data_o          (ram_dat_i          ),
    .s0_addr_o          (ram_adr_i          ),
    .s0_sel_o           (ram_sel_i          ),
    .s0_we_o            (ram_we_i           ),
    .s0_cyc_o           (ram_cyc_i          ),
    .s0_stb_o           (ram_stb_i          ),
    .s0_ack_i           (ram_ack_o          ),
    .s0_err_i           (1'b0               ),
    .s0_rty_i           (1'b0               ),

    // Slave 1 Interface
    .s1_data_i          (32'h0              ),
    .s1_data_o          (),
    .s1_addr_o          (),
    .s1_sel_o           (),
    .s1_we_o            (),
    .s1_cyc_o           (),
    .s1_stb_o           (),
    .s1_ack_i           (1'b0               ),
    .s1_err_i           (1'b0               ),
    .s1_rty_i           (1'b0               ),

    // Slave 2 Interface
    .s2_data_i          (uart_dat_o         ),
    .s2_data_o          (uart_dat_i         ),
    .s2_addr_o          (uart_adr_i         ),
    .s2_sel_o           (uart_sel_i         ),
    .s2_we_o            (uart_we_i          ),
    .s2_cyc_o           (uart_cyc_i         ),
    .s2_stb_o           (uart_stb_i         ),
    .s2_ack_i           (uart_ack_o         ),
    .s2_err_i           (1'b0               ),
    .s2_rty_i           (1'b0               ),

    // Slave 3 Interface
    .s3_data_i          (gpio_dat_o         ),
    .s3_data_o          (gpio_dat_i         ),
    .s3_addr_o          (gpio_adr_i         ),
    .s3_sel_o           (gpio_sel_i         ),
    .s3_we_o            (gpio_we_i          ),
    .s3_cyc_o           (gpio_cyc_i         ),
    .s3_stb_o           (gpio_stb_i         ),
    .s3_ack_i           (gpio_ack_o         ),
    .s3_err_i           (gpio_err_o         ),
    .s3_rty_i           (1'b0               )
);

wb_ram U_WB_RAM (
    .wb_clk_i           (clk                ),
    .wb_rst_i           (rst_sync           ),
    .wb_cyc_i           (ram_cyc_i          ),
    .wb_stb_i           (ram_stb_i          ),
    .wb_we_i            (ram_we_i           ),
    .wb_sel_i           (ram_sel_i          ),
    .wb_adr_i           (ram_adr_i          ),
    .wb_dat_i           (ram_dat_i          ),
    .wb_dat_o           (ram_dat_o          ),
    .wb_ack_o           (ram_ack_o          )
);

uart_top U_UART (
    .wb_clk_i           (clk                    ),
    .wb_rst_i           (rst_sync               ),
    .wb_stb_i           (uart_stb_i             ),
    .wb_cyc_i           (uart_cyc_i             ),
    .wb_ack_o           (uart_ack_o             ),
    .wb_adr_i           (uart_adr_i[4:2]        ),
    .wb_we_i            (uart_we_i              ),
    .wb_sel_i           (uart_sel_i             ),
    .wb_dat_i           (uart_dat_i[7:0]        ),
    .wb_dat_o           (uart_dat_o[7:0]        ),
    .int_o              (uart_irq               ),
    .stx_pad_o          (uart_txd               ),
    .srx_pad_i          (uart_rxd               ),
    .rts_pad_o          (                       ),
    .cts_pad_i          (1'b0                   ),
    .dtr_pad_o          (                       ),
    .dsr_pad_i          (1'b0                   ),
    .ri_pad_i           (1'b0                   ),
    .dcd_pad_i          (1'b0                   )
);

gpio_top U_WB_GPIO (
    .wb_clk_i           (clk                    ),
    .wb_rst_i           (rst_sync               ),
    .wb_cyc_i           (gpio_cyc_i             ),
    .wb_adr_i           (gpio_adr_i[7:0]        ),
    .wb_dat_i           (gpio_dat_i             ),
    .wb_sel_i           (gpio_sel_i             ),
    .wb_we_i            (gpio_we_i              ),
    .wb_stb_i           (gpio_stb_i             ),
    .wb_dat_o           (gpio_dat_o             ),
    .wb_ack_o           (gpio_ack_o             ),
    .wb_err_o           (gpio_err_o             ),
    .wb_inta_o          (gpio_irq               ),
    .ext_pad_i          ({28'h0, key}           ),
    .ext_pad_o          (gpio_pad_w             ),
    .ext_padoe_o        (                       )
);

assign led = gpio_pad_w[3:0];

endmodule
