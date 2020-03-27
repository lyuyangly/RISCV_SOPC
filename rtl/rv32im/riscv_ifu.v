module riscv_ifu (
    input               clk_i                   ,
    input               rst_i                   ,
    output              icache_rd_o             ,
    output  [31:0]      icache_pc_o             ,
    input   [31:0]      icache_inst_i           ,
    input               icache_valid_i          ,
    input               icache_error_i          ,
    output              icache_flush_o          ,
    input               icache_accept_i         ,
    input               fetch_branch_i          ,
    input   [31:0]      fetch_branch_pc_i       ,
    input               fetch_accept_i          ,
    input               fetch_invalidate_i      ,
    output              fetch_valid_o           ,
    output  [31:0]      fetch_instr_o           ,
    output  [31:0]      fetch_pc_o
);

`include "riscv_def.v"

// Registers and Wires
reg             active_q;
reg     [31:0]  fetch_pc_q;
reg     [31:0]  branch_pc_q;
reg             branch_valid_q;
reg             icache_fetch_q;
reg     [63:0]  skid_buffer_q;
reg             skid_valid_q;
reg     [31:0]  pc_d_q;

wire            icache_busy_w =  icache_fetch_q && !icache_valid_i;
wire            stall_w       = !fetch_accept_i || icache_busy_w || !icache_accept_i;
wire            branch_w      = branch_valid_q || fetch_branch_i;
wire    [31:0]  branch_pc_w   = (branch_valid_q & !fetch_branch_i) ? branch_pc_q : fetch_branch_pc_i;

always @(posedge clk_i or posedge rst_i)
    if (rst_i)
    begin
        fetch_pc_q     <= 32'b0;
        branch_pc_q    <= 32'b0;
        branch_valid_q <= 1'b0;
        icache_fetch_q <= 1'b0;
        skid_buffer_q  <= 64'b0;
        skid_valid_q   <= 1'b0;
        active_q       <= 1'b0;
    end
    else begin
        // Branch request skid buffer
        if (stall_w || !active_q)
        begin
            branch_valid_q <= branch_w;
            branch_pc_q    <= branch_pc_w;
        end
        else
        begin
            branch_valid_q <= 1'b0;
            branch_pc_q    <= 32'b0;
        end

        if (branch_w)
            active_q <= 1'b1;

        // NPC
        if (!stall_w)
            fetch_pc_q <= icache_pc_o + 32'd4;

        // Instruction output back-pressured - hold in skid buffer
        if (fetch_valid_o && !fetch_accept_i)
        begin
            skid_valid_q  <= 1'b1;
            skid_buffer_q <= {fetch_pc_o, fetch_instr_o};
        end
        else
        begin
            skid_valid_q  <= 1'b0;
            skid_buffer_q <= 64'b0;
        end

        // ICACHE fetch tracking
        if (icache_rd_o && icache_accept_i)
            icache_fetch_q <= 1'b1;
        else if (icache_valid_i)
            icache_fetch_q <= 1'b0;
    end

always @(posedge clk_i or posedge rst_i)
    if (rst_i)
        pc_d_q <= 32'b0;
    else if (icache_rd_o && icache_accept_i)
        pc_d_q <= icache_pc_o;

//-------------------------------------------------------------
// Outputs
//-------------------------------------------------------------
assign icache_rd_o         = active_q & fetch_accept_i & !icache_busy_w;
assign icache_pc_o         = branch_w ? branch_pc_w : fetch_pc_q;
assign icache_flush_o      = fetch_invalidate_i;

// On fault, insert known invalid opcode into the pipeline
wire [31:0] instruction_w  = icache_error_i ? `INST_FAULT : icache_inst_i;

assign fetch_valid_o = (icache_valid_i || skid_valid_q) & !branch_w;
assign fetch_pc_o    = skid_valid_q ? skid_buffer_q[63:32] : pc_d_q;
assign fetch_instr_o = skid_valid_q ? skid_buffer_q[31:0]  : instruction_w;

endmodule
