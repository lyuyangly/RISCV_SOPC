module riscv_exu (
    input           clk_i                   ,
    input           rst_i                   ,
    input           opcode_valid_i          ,
    input   [57:0]  opcode_instr_i          ,
    input   [31:0]  opcode_opcode_i         ,
    input   [31:0]  opcode_pc_i             ,
    input   [4:0]   opcode_rd_idx_i         ,
    input   [4:0]   opcode_ra_idx_i         ,
    input   [4:0]   opcode_rb_idx_i         ,
    input   [31:0]  opcode_ra_operand_i     ,
    input   [31:0]  opcode_rb_operand_i     ,
    output          branch_request_o        ,
    output  [31:0]  branch_pc_o             ,
    output  [4:0]   writeback_idx_o         ,
    output          writeback_squash_o      ,
    output  [31:0]  writeback_value_o       ,
    output          stall_o
);

`include "riscv_def.v"

// Opcode decode
reg     [4:0]   rd_x_q;
reg     [31:0]  imm20_r;
reg     [31:0]  imm12_r;
reg     [31:0]  bimm_r;
reg     [31:0]  jimm20_r;
reg     [4:0]   shamt_r;
reg     [31:0]  storeimm_r;
reg     [3:0]   alu_func_r;
reg     [31:0]  alu_input_a_r;
reg     [31:0]  alu_input_b_r;
reg             write_rd_r;

always @(*)
begin
    imm20_r     = {opcode_opcode_i[31:12], 12'b0};
    imm12_r     = {{20{opcode_opcode_i[31]}}, opcode_opcode_i[31:20]};
    bimm_r      = {{19{opcode_opcode_i[31]}}, opcode_opcode_i[31], opcode_opcode_i[7], opcode_opcode_i[30:25], opcode_opcode_i[11:8], 1'b0};
    jimm20_r    = {{12{opcode_opcode_i[31]}}, opcode_opcode_i[19:12], opcode_opcode_i[20], opcode_opcode_i[30:25], opcode_opcode_i[24:21], 1'b0};
    storeimm_r  = {{20{opcode_opcode_i[31]}}, opcode_opcode_i[31:25], opcode_opcode_i[11:7]};
    shamt_r     = opcode_opcode_i[24:20];
end

//-------------------------------------------------------------
// Execute - ALU operations
//-------------------------------------------------------------
always @(*)
begin
    alu_func_r     = `ALU_NONE;
    alu_input_a_r  = 32'b0;
    alu_input_b_r  = 32'b0;
    write_rd_r     = 1'b0;

    if (opcode_instr_i[`ENUM_INST_ADD]) // add
    begin
        alu_func_r     = `ALU_ADD;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_AND]) // and
    begin
        alu_func_r     = `ALU_AND;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_OR]) // or
    begin
        alu_func_r     = `ALU_OR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLL]) // sll
    begin
        alu_func_r     = `ALU_SHIFTL;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SRA]) // sra
    begin
        alu_func_r     = `ALU_SHIFTR_ARITH;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SRL]) // srl
    begin
        alu_func_r     = `ALU_SHIFTR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SUB]) // sub
    begin
        alu_func_r     = `ALU_SUB;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_XOR]) // xor
    begin
        alu_func_r     = `ALU_XOR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLT]) // slt
    begin
        alu_func_r     = `ALU_LESS_THAN_SIGNED;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLTU]) // sltu
    begin
        alu_func_r     = `ALU_LESS_THAN;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = opcode_rb_operand_i;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_ADDI]) // addi
    begin
        alu_func_r     = `ALU_ADD;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_ANDI]) // andi
    begin
        alu_func_r     = `ALU_AND;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLTI]) // slti
    begin
        alu_func_r     = `ALU_LESS_THAN_SIGNED;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLTIU]) // sltiu
    begin
        alu_func_r     = `ALU_LESS_THAN;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_ORI]) // ori
    begin
        alu_func_r     = `ALU_OR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_XORI]) // xori
    begin
        alu_func_r     = `ALU_XOR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = imm12_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SLLI]) // slli
    begin
        alu_func_r     = `ALU_SHIFTL;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = {27'b0, shamt_r};
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SRLI]) // srli
    begin
        alu_func_r     = `ALU_SHIFTR;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = {27'b0, shamt_r};
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_SRAI]) // srai
    begin
        alu_func_r     = `ALU_SHIFTR_ARITH;
        alu_input_a_r  = opcode_ra_operand_i;
        alu_input_b_r  = {27'b0, shamt_r};
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_LUI]) // lui
    begin
        alu_input_a_r  = imm20_r;
        write_rd_r     = 1'b1;
    end
    else if (opcode_instr_i[`ENUM_INST_AUIPC]) // auipc
    begin
        alu_func_r     = `ALU_ADD;
        alu_input_a_r  = opcode_pc_i;
        alu_input_b_r  = imm20_r;
        write_rd_r     = 1'b1;
    end     
    else if (opcode_instr_i[`ENUM_INST_JAL] || opcode_instr_i[`ENUM_INST_JALR]) // jal, jalr
    begin
        alu_func_r     = `ALU_ADD;
        alu_input_a_r  = opcode_pc_i;
        alu_input_b_r  = 32'd4;
        write_rd_r     = 1'b1;
    end
end

//-----------------------------------------------------------------
// less_than_signed: Less than operator (signed)
// Inputs: x = left operand, y = right operand
// Return: (int)x < (int)y
//-----------------------------------------------------------------
function [0:0] less_than_signed;
    input  [31:0] x;
    input  [31:0] y;
    reg [31:0] v;
begin
    v = (x - y);
    if (x[31] != y[31])
        less_than_signed = x[31];
    else
        less_than_signed = v[31];
end
endfunction

//-----------------------------------------------------------------
// greater_than_signed: Greater than operator (signed)
// Inputs: x = left operand, y = right operand
// Return: (int)x > (int)y
//-----------------------------------------------------------------
function [0:0] greater_than_signed;
    input  [31:0] x;
    input  [31:0] y;
    reg [31:0] v;
begin
    v = (y - x);
    if (x[31] != y[31])
        greater_than_signed = y[31];
    else
        greater_than_signed = v[31];
end
endfunction

//-------------------------------------------------------------
// Execute - Branch operations
//-------------------------------------------------------------
reg        branch_r;
reg [31:0] branch_target_r;

always @(*)
begin
    branch_r        = 1'b0;

    // Default branch_r target is relative to current PC
    branch_target_r = opcode_pc_i + bimm_r;

    if (opcode_instr_i[`ENUM_INST_JAL]) // jal
    begin
        branch_r        = 1'b1;
        branch_target_r = opcode_pc_i + jimm20_r;
    end
    else if (opcode_instr_i[`ENUM_INST_JALR]) // jalr
    begin
        branch_r            = 1'b1;
        branch_target_r     = opcode_ra_operand_i + imm12_r;
        branch_target_r[0]  = 1'b0;
    end
    else if (opcode_instr_i[`ENUM_INST_BEQ]) // beq
        branch_r      = (opcode_ra_operand_i == opcode_rb_operand_i);
    else if (opcode_instr_i[`ENUM_INST_BNE]) // bne
        branch_r      = (opcode_ra_operand_i != opcode_rb_operand_i);
    else if (opcode_instr_i[`ENUM_INST_BLT]) // blt
        branch_r      = less_than_signed(opcode_ra_operand_i, opcode_rb_operand_i);
    else if (opcode_instr_i[`ENUM_INST_BGE]) // bge
        branch_r      = greater_than_signed(opcode_ra_operand_i,opcode_rb_operand_i) | (opcode_ra_operand_i == opcode_rb_operand_i);
    else if (opcode_instr_i[`ENUM_INST_BLTU]) // bltu
        branch_r      = (opcode_ra_operand_i < opcode_rb_operand_i);
    else if (opcode_instr_i[`ENUM_INST_BGEU]) // bgeu
        branch_r      = (opcode_ra_operand_i >= opcode_rb_operand_i);
end

assign branch_request_o = branch_r && opcode_valid_i;
assign branch_pc_o      = branch_target_r;

//-------------------------------------------------------------
// Sequential
//-------------------------------------------------------------
always @(posedge clk_i or posedge rst_i)
    if (rst_i)
        rd_x_q       <= 5'b0;
    else
    begin
        if (opcode_valid_i && write_rd_r)
            rd_x_q   <= opcode_rd_idx_i;
        else
            rd_x_q   <= 5'b0;
    end

//-------------------------------------------------------------
// ALU
//-------------------------------------------------------------
wire [31:0]  alu_p_w;
riscv_alu u_alu (
    .alu_op_i   (alu_func_r     ),
    .alu_a_i    (alu_input_a_r  ),
    .alu_b_i    (alu_input_b_r  ),
    .alu_p_o    (alu_p_w        )
);

//-------------------------------------------------------------
// Flop ALU output
//-------------------------------------------------------------
reg     [31:0]  result_q;
always @(posedge clk_i or posedge rst_i)
    if (rst_i)
        result_q  <= 32'b0;
    else
        result_q <= alu_p_w;

assign writeback_value_o  = result_q;

//-------------------------------------------------------------
// Outputs
//-------------------------------------------------------------
assign writeback_idx_o    = rd_x_q;
assign writeback_squash_o = 1'b0;
assign stall_o            = 1'b0;

endmodule
