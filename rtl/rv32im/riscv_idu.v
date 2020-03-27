module riscv_idu (
    input               clk_i                       ,
    input               rst_i                       ,
    input               fetch_valid_i               ,
    input   [31:0]      fetch_instr_i               ,
    input   [31:0]      fetch_pc_i                  ,
    input               branch_request_i            ,
    input   [31:0]      branch_pc_i                 ,
    input               branch_csr_request_i        ,
    input   [31:0]      branch_csr_pc_i             ,
    input   [4:0]       writeback_exec_idx_i        ,
    input               writeback_exec_squash_i     ,
    input   [31:0]      writeback_exec_value_i      ,
    input   [4:0]       writeback_mem_idx_i         ,
    input               writeback_mem_squash_i      ,
    input   [31:0]      writeback_mem_value_i       ,
    input   [4:0]       writeback_csr_idx_i         ,
    input               writeback_csr_squash_i      ,
    input   [31:0]      writeback_csr_value_i       ,
    input   [4:0]       writeback_muldiv_idx_i      ,
    input               writeback_muldiv_squash_i   ,
    input   [31:0]      writeback_muldiv_value_i    ,
    input               exec_stall_i                ,
    input               lsu_stall_i                 ,
    input               csr_stall_i                 ,
    input               muldiv_stall_i              ,
    output              fetch_branch_o              ,
    output  [31:0]      fetch_branch_pc_o           ,
    output              fetch_accept_o              ,
    output              exec_opcode_valid_o         ,
    output              lsu_opcode_valid_o          ,
    output              csr_opcode_valid_o          ,
    output              muldiv_opcode_valid_o       ,
    output  [57:0]      opcode_instr_o              ,
    output  [31:0]      opcode_opcode_o             ,
    output  [31:0]      opcode_pc_o                 ,
    output  [4:0]       opcode_rd_idx_o             ,
    output  [4:0]       opcode_ra_idx_o             ,
    output  [4:0]       opcode_rb_idx_o             ,
    output  [31:0]      opcode_ra_operand_o         ,
    output  [31:0]      opcode_rb_operand_o         ,
    output              fetch_invalidate_o
);

`include "riscv_def.v"

// Registers and Wires
reg             valid_q;
reg     [31:0]  pc_q;
reg     [31:0]  inst_q;
reg             fault_fetch_q;

reg     [31:0]  scoreboard_q;
reg             stall_scoreboard_r;

reg     [4:0]   wb_rd_r;
reg     [31:0]  wb_res_r;

wire    [31:0]  ra_value_w;
wire    [31:0]  rb_value_w;

wire            stall_input_w = stall_scoreboard_r || exec_stall_i || lsu_stall_i || csr_stall_i || muldiv_stall_i;

// Instances
wire [4:0] wb_exec_rd_w   = writeback_exec_idx_i   & {5{~writeback_exec_squash_i}};
wire [4:0] wb_mem_rd_w    = writeback_mem_idx_i    & {5{~writeback_mem_squash_i}};
wire [4:0] wb_csr_rd_w    = writeback_csr_idx_i    & {5{~writeback_csr_squash_i}};
wire [4:0] wb_muldiv_rd_w = writeback_muldiv_idx_i & {5{~writeback_muldiv_squash_i}};

always @(*)
begin
    wb_rd_r  = wb_exec_rd_w;
    wb_res_r = writeback_exec_value_i;
end

riscv_regfile u_regfile (
    .clk_i          (clk_i                      ),
    .rst_i          (rst_i                      ),
    .rd0_i          (wb_rd_r                    ),
    .rd0_value_i    (wb_res_r                   ),
    .rd1_i          (wb_mem_rd_w                ),
    .rd1_value_i    (writeback_mem_value_i      ),
    .rd2_i          (wb_csr_rd_w                ),
    .rd2_value_i    (writeback_csr_value_i      ),
    .rd3_i          (wb_muldiv_rd_w             ),
    .rd3_value_i    (writeback_muldiv_value_i   ),
    .ra_i           (opcode_ra_idx_o            ),
    .rb_i           (opcode_rb_idx_o            ),
    .ra_value_o     (ra_value_w                 ),
    .rb_value_o     (rb_value_w                 )
);

//-------------------------------------------------------------
// fence.i
//-------------------------------------------------------------
reg ifence_q;

always @(posedge clk_i or posedge rst_i)
    if (rst_i)
        ifence_q <= 1'b0;
    else
        ifence_q <= fetch_valid_i && fetch_accept_o &&
                    ((fetch_instr_i & `INST_IFENCE_MASK) == `INST_IFENCE);

assign fetch_invalidate_o = ifence_q;

//-------------------------------------------------------------
// Instruction Register
//-------------------------------------------------------------
always @(posedge clk_i or posedge rst_i)
    if (rst_i)
    begin
        valid_q       <= 1'b0;
        pc_q          <= 32'b0;
        inst_q        <= 32'b0;
    end
    // Branch request
    else if (branch_request_i || branch_csr_request_i)
    begin
        valid_q       <= 1'b0;
    
        if (branch_csr_request_i)
            pc_q      <= branch_csr_pc_i;
        else /*if (branch_request_i)*/
            pc_q      <= branch_pc_i;
    
        inst_q        <= 32'b0;
    end
    // Normal operation - decode not stalled
    else if (!stall_input_w)
    begin
        valid_q       <= fetch_valid_i;
    
        if (fetch_valid_i)
            pc_q      <= fetch_pc_i;
        // Current instruction accepted, increment PC to unexecuted instruction
        else if (valid_q)
            pc_q      <= pc_q + 32'd4;
    
        inst_q        <= fetch_instr_i;
    end

//-------------------------------------------------------------
// Scoreboard Register
//-------------------------------------------------------------
reg [31:0] scoreboard_r;

wire sb_alloc_w = (opcode_instr_o[`ENUM_INST_LB]     ||
                   opcode_instr_o[`ENUM_INST_LH]     ||
                   opcode_instr_o[`ENUM_INST_LW]     ||
                   opcode_instr_o[`ENUM_INST_LBU]    ||
                   opcode_instr_o[`ENUM_INST_LHU]    ||
                   opcode_instr_o[`ENUM_INST_LWU]    ||
                   opcode_instr_o[`ENUM_INST_CSRRW]  ||
                   opcode_instr_o[`ENUM_INST_CSRRS]  ||
                   opcode_instr_o[`ENUM_INST_CSRRC]  ||
                   opcode_instr_o[`ENUM_INST_CSRRWI] ||
                   opcode_instr_o[`ENUM_INST_CSRRSI] ||
                   opcode_instr_o[`ENUM_INST_CSRRCI] ||
                   opcode_instr_o[`ENUM_INST_MUL]    ||
                   opcode_instr_o[`ENUM_INST_MULH]   ||
                   opcode_instr_o[`ENUM_INST_MULHSU] ||
                   opcode_instr_o[`ENUM_INST_MULHU]  ||
                   opcode_instr_o[`ENUM_INST_DIV]    ||
                   opcode_instr_o[`ENUM_INST_DIVU]   ||
                   opcode_instr_o[`ENUM_INST_REM]    ||
                   opcode_instr_o[`ENUM_INST_REMU] );

always @(*)
begin
    scoreboard_r = scoreboard_q;

    scoreboard_r[writeback_mem_idx_i]    = 1'b0;

    // Allocate register in scoreboard
    if (sb_alloc_w && exec_opcode_valid_o && lsu_opcode_valid_o && csr_opcode_valid_o && muldiv_opcode_valid_o)
    begin
        scoreboard_r[opcode_rd_idx_o] = 1'b1;
    end

    // Release register on Load / CSR completion
    scoreboard_r[writeback_csr_idx_i]    = 1'b0;
    scoreboard_r[writeback_muldiv_idx_i] = 1'b0;
end

always @(posedge clk_i or posedge rst_i)
    if (rst_i)
        scoreboard_q <= 32'b0;
    else
        scoreboard_q <= {scoreboard_r[31:1], 1'b0};

//-------------------------------------------------------------
// Instruction Decode
//-------------------------------------------------------------
wire [`ENUM_INST_MAX-1:0] opcode_instr_w;

assign opcode_instr_w[`ENUM_INST_ANDI]   = ((fetch_instr_i & `INST_ANDI_MASK) == `INST_ANDI);   // andi
assign opcode_instr_w[`ENUM_INST_ADDI]   = ((fetch_instr_i & `INST_ADDI_MASK) == `INST_ADDI);   // addi
assign opcode_instr_w[`ENUM_INST_SLTI]   = ((fetch_instr_i & `INST_SLTI_MASK) == `INST_SLTI);   // slti
assign opcode_instr_w[`ENUM_INST_SLTIU]  = ((fetch_instr_i & `INST_SLTIU_MASK) == `INST_SLTIU); // sltiu
assign opcode_instr_w[`ENUM_INST_ORI]    = ((fetch_instr_i & `INST_ORI_MASK) == `INST_ORI);     // ori
assign opcode_instr_w[`ENUM_INST_XORI]   = ((fetch_instr_i & `INST_XORI_MASK) == `INST_XORI);   // xori
assign opcode_instr_w[`ENUM_INST_SLLI]   = ((fetch_instr_i & `INST_SLLI_MASK) == `INST_SLLI);   // slli
assign opcode_instr_w[`ENUM_INST_SRLI]   = ((fetch_instr_i & `INST_SRLI_MASK) == `INST_SRLI);   // srli
assign opcode_instr_w[`ENUM_INST_SRAI]   = ((fetch_instr_i & `INST_SRAI_MASK) == `INST_SRAI);   // srai
assign opcode_instr_w[`ENUM_INST_LUI]    = ((fetch_instr_i & `INST_LUI_MASK) == `INST_LUI);     // lui
assign opcode_instr_w[`ENUM_INST_AUIPC]  = ((fetch_instr_i & `INST_AUIPC_MASK) == `INST_AUIPC); // auipc
assign opcode_instr_w[`ENUM_INST_ADD]    = ((fetch_instr_i & `INST_ADD_MASK) == `INST_ADD);     // add
assign opcode_instr_w[`ENUM_INST_SUB]    = ((fetch_instr_i & `INST_SUB_MASK) == `INST_SUB);     // sub
assign opcode_instr_w[`ENUM_INST_SLT]    = ((fetch_instr_i & `INST_SLT_MASK) == `INST_SLT);     // slt
assign opcode_instr_w[`ENUM_INST_SLTU]   = ((fetch_instr_i & `INST_SLTU_MASK) == `INST_SLTU);   // sltu
assign opcode_instr_w[`ENUM_INST_XOR]    = ((fetch_instr_i & `INST_XOR_MASK) == `INST_XOR);     // xor
assign opcode_instr_w[`ENUM_INST_OR]     = ((fetch_instr_i & `INST_OR_MASK) == `INST_OR);       // or
assign opcode_instr_w[`ENUM_INST_AND]    = ((fetch_instr_i & `INST_AND_MASK) == `INST_AND);     // and
assign opcode_instr_w[`ENUM_INST_SLL]    = ((fetch_instr_i & `INST_SLL_MASK) == `INST_SLL);     // sll
assign opcode_instr_w[`ENUM_INST_SRL]    = ((fetch_instr_i & `INST_SRL_MASK) == `INST_SRL);     // srl
assign opcode_instr_w[`ENUM_INST_SRA]    = ((fetch_instr_i & `INST_SRA_MASK) == `INST_SRA);     // sra
assign opcode_instr_w[`ENUM_INST_JAL]    = ((fetch_instr_i & `INST_JAL_MASK) == `INST_JAL);     // jal
assign opcode_instr_w[`ENUM_INST_JALR]   = ((fetch_instr_i & `INST_JALR_MASK) == `INST_JALR);   // jalr
assign opcode_instr_w[`ENUM_INST_BEQ]    = ((fetch_instr_i & `INST_BEQ_MASK) == `INST_BEQ);     // beq
assign opcode_instr_w[`ENUM_INST_BNE]    = ((fetch_instr_i & `INST_BNE_MASK) == `INST_BNE);     // bne
assign opcode_instr_w[`ENUM_INST_BLT]    = ((fetch_instr_i & `INST_BLT_MASK) == `INST_BLT);     // blt
assign opcode_instr_w[`ENUM_INST_BGE]    = ((fetch_instr_i & `INST_BGE_MASK) == `INST_BGE);     // bge
assign opcode_instr_w[`ENUM_INST_BLTU]   = ((fetch_instr_i & `INST_BLTU_MASK) == `INST_BLTU);   // bltu
assign opcode_instr_w[`ENUM_INST_BGEU]   = ((fetch_instr_i & `INST_BGEU_MASK) == `INST_BGEU);   // bgeu
assign opcode_instr_w[`ENUM_INST_LB]     = ((fetch_instr_i & `INST_LB_MASK) == `INST_LB);       // lb
assign opcode_instr_w[`ENUM_INST_LH]     = ((fetch_instr_i & `INST_LH_MASK) == `INST_LH);       // lh
assign opcode_instr_w[`ENUM_INST_LW]     = ((fetch_instr_i & `INST_LW_MASK) == `INST_LW);       // lw
assign opcode_instr_w[`ENUM_INST_LBU]    = ((fetch_instr_i & `INST_LBU_MASK) == `INST_LBU);     // lbu
assign opcode_instr_w[`ENUM_INST_LHU]    = ((fetch_instr_i & `INST_LHU_MASK) == `INST_LHU);     // lhu
assign opcode_instr_w[`ENUM_INST_LWU]    = ((fetch_instr_i & `INST_LWU_MASK) == `INST_LWU);     // lwu
assign opcode_instr_w[`ENUM_INST_SB]     = ((fetch_instr_i & `INST_SB_MASK) == `INST_SB);       // sb
assign opcode_instr_w[`ENUM_INST_SH]     = ((fetch_instr_i & `INST_SH_MASK) == `INST_SH);       // sh
assign opcode_instr_w[`ENUM_INST_SW]     = ((fetch_instr_i & `INST_SW_MASK) == `INST_SW);       // sw
assign opcode_instr_w[`ENUM_INST_ECALL]  = ((fetch_instr_i & `INST_ECALL_MASK) == `INST_ECALL); // ecall
assign opcode_instr_w[`ENUM_INST_EBREAK] = ((fetch_instr_i & `INST_EBREAK_MASK) == `INST_EBREAK); // ebreak
assign opcode_instr_w[`ENUM_INST_ERET]   = ((fetch_instr_i & `INST_MRET_MASK) == `INST_MRET);   // mret / sret
assign opcode_instr_w[`ENUM_INST_CSRRW]  = ((fetch_instr_i & `INST_CSRRW_MASK) == `INST_CSRRW); // csrrw
assign opcode_instr_w[`ENUM_INST_CSRRS]  = ((fetch_instr_i & `INST_CSRRS_MASK) == `INST_CSRRS); // csrrs
assign opcode_instr_w[`ENUM_INST_CSRRC]  = ((fetch_instr_i & `INST_CSRRC_MASK) == `INST_CSRRC); // csrrc
assign opcode_instr_w[`ENUM_INST_CSRRWI] = ((fetch_instr_i & `INST_CSRRWI_MASK) == `INST_CSRRWI); // csrrwi
assign opcode_instr_w[`ENUM_INST_CSRRSI] = ((fetch_instr_i & `INST_CSRRSI_MASK) == `INST_CSRRSI); // csrrsi
assign opcode_instr_w[`ENUM_INST_CSRRCI] = ((fetch_instr_i & `INST_CSRRCI_MASK) == `INST_CSRRCI); // csrrci
assign opcode_instr_w[`ENUM_INST_MUL]    = ((fetch_instr_i & `INST_MUL_MASK) == `INST_MUL);       // mul
assign opcode_instr_w[`ENUM_INST_MULH]   = ((fetch_instr_i & `INST_MULH_MASK) == `INST_MULH);     // mulh
assign opcode_instr_w[`ENUM_INST_MULHSU] = ((fetch_instr_i & `INST_MULHSU_MASK) == `INST_MULHSU); // mulhsu
assign opcode_instr_w[`ENUM_INST_MULHU]  = ((fetch_instr_i & `INST_MULHU_MASK) == `INST_MULHU);   // mulhu
assign opcode_instr_w[`ENUM_INST_DIV]    = ((fetch_instr_i & `INST_DIV_MASK) == `INST_DIV);       // div
assign opcode_instr_w[`ENUM_INST_DIVU]   = ((fetch_instr_i & `INST_DIVU_MASK) == `INST_DIVU);     // divu
assign opcode_instr_w[`ENUM_INST_REM]    = ((fetch_instr_i & `INST_REM_MASK) == `INST_REM);       // rem
assign opcode_instr_w[`ENUM_INST_REMU]   = ((fetch_instr_i & `INST_REMU_MASK) == `INST_REMU);     // remu
assign opcode_instr_w[`ENUM_INST_FAULT]  = ((fetch_instr_i & `INST_FAULT_MASK) == `INST_FAULT);
assign opcode_instr_w[`ENUM_INST_PAGE_FAULT] = ((fetch_instr_i & `INST_PAGE_FAULT_MASK) == `INST_PAGE_FAULT);
assign opcode_instr_w[`ENUM_INST_INVALID]= 1'b0;

wire nop_instr_w                         = ((fetch_instr_i & `INST_WFI_MASK) == `INST_WFI) |
                                           ((fetch_instr_i & `INST_FENCE_MASK) == `INST_FENCE) |
                                           ((fetch_instr_i & `INST_SFENCE_MASK) == `INST_SFENCE) |
                                           ((fetch_instr_i & `INST_IFENCE_MASK) == `INST_IFENCE);

wire invalid_inst_w = ~(|opcode_instr_w[`ENUM_INST_PAGE_FAULT:0]) & ~nop_instr_w;

reg [`ENUM_INST_MAX-1:0] opcode_instr_q;

always @ (posedge clk_i or posedge rst_i)
    if (rst_i)
        opcode_instr_q <= `ENUM_INST_MAX'b0;
    else if (branch_request_i || branch_csr_request_i)
        opcode_instr_q <= `ENUM_INST_MAX'b0;
    else if (!stall_input_w)
        opcode_instr_q <= {invalid_inst_w, opcode_instr_w[`ENUM_INST_PAGE_FAULT:0]};

assign opcode_instr_o = opcode_instr_q;

// Decode operands
assign opcode_pc_o     = pc_q;
assign opcode_opcode_o = inst_q;
assign opcode_ra_idx_o = inst_q[19:15];
assign opcode_rb_idx_o = inst_q[24:20];
assign opcode_rd_idx_o = inst_q[11:7];

//-------------------------------------------------------------
// Bypass / Forwarding
//-------------------------------------------------------------
reg [31:0] opcode_ra_operand_r;
reg [31:0] opcode_rb_operand_r;

always @(*)
begin
    // Bypass: Exec
    if (!writeback_exec_squash_i && writeback_exec_idx_i != 5'd0 && writeback_exec_idx_i == opcode_ra_idx_o)
        opcode_ra_operand_r = writeback_exec_value_i;
    // Bypass: Mem
    else if (!writeback_mem_squash_i && writeback_mem_idx_i != 5'd0 && writeback_mem_idx_i == opcode_ra_idx_o)
        opcode_ra_operand_r = writeback_mem_value_i;
    else
        opcode_ra_operand_r = ra_value_w;

    // Bypass: Exec
    if (!writeback_exec_squash_i && writeback_exec_idx_i != 5'd0 && writeback_exec_idx_i == opcode_rb_idx_o)
        opcode_rb_operand_r = writeback_exec_value_i;
    // Bypass: Mem
    else if (!writeback_mem_squash_i && writeback_mem_idx_i != 5'd0 && writeback_mem_idx_i == opcode_rb_idx_o)
        opcode_rb_operand_r = writeback_mem_value_i;
    else
        opcode_rb_operand_r = rb_value_w;
end

assign opcode_ra_operand_o = opcode_ra_operand_r;
assign opcode_rb_operand_o = opcode_rb_operand_r;

//-------------------------------------------------------------
// Stall logic
//-------------------------------------------------------------
reg        opcode_valid_r;
reg [31:0] current_scoreboard_r;

always @(*)
begin
    opcode_valid_r       = valid_q & ~branch_csr_request_i;
    stall_scoreboard_r   = 1'b0;
    current_scoreboard_r = scoreboard_q;

    // Mem writeback bypass
    current_scoreboard_r[writeback_mem_idx_i] = 1'b0;

    // Detect dependancy on the LSU/CSR scoreboard
    if (current_scoreboard_r[opcode_ra_idx_o] ||
        current_scoreboard_r[opcode_rb_idx_o] ||
        current_scoreboard_r[opcode_rd_idx_o])
    begin
        stall_scoreboard_r = 1'b1;
        opcode_valid_r     = 1'b0;
    end

end

// Opcode valid flags to the various execution units
assign exec_opcode_valid_o    = opcode_valid_r && !lsu_stall_i  && !csr_stall_i && !muldiv_stall_i;
assign lsu_opcode_valid_o     = opcode_valid_r && !exec_stall_i && !csr_stall_i && !muldiv_stall_i;
assign csr_opcode_valid_o     = opcode_valid_r && !exec_stall_i && !lsu_stall_i && !muldiv_stall_i;
assign muldiv_opcode_valid_o  = opcode_valid_r && !exec_stall_i && !lsu_stall_i && !csr_stall_i;

//-------------------------------------------------------------
// Fetch output
//-------------------------------------------------------------
assign fetch_branch_o    = branch_request_i | branch_csr_request_i;
assign fetch_branch_pc_o = branch_csr_request_i ? branch_csr_pc_i : branch_pc_i;
assign fetch_accept_o    = branch_csr_request_i || (!exec_stall_i && !stall_scoreboard_r && !lsu_stall_i && !csr_stall_i && !muldiv_stall_i);

endmodule
