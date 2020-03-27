module mem_fifo_wb #(
    parameter WIDTH = 64
)(
    input               clk_i       ,
    input               rst_i       ,
    input  [WIDTH-1:0]  data_in_i   ,
    input               push_i      ,
    input               pop_i       ,
    output [WIDTH-1:0]  data_out_o  ,
    output              accept_o    ,
    output              valid_o
);

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [WIDTH-1:0]  ram_q[1:0];
reg [0:0]        rd_ptr_q;
reg [0:0]        wr_ptr_q;
reg [1:0]        count_q;

//-----------------------------------------------------------------
// Sequential
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
begin
    if (rst_i == 1'b1)
    begin
        count_q   <= 2'b0;
        rd_ptr_q  <= 1'b0;
        wr_ptr_q  <= 1'b0;
    end
    else
    begin
        // Push
        if (push_i & accept_o)
        begin
            ram_q[wr_ptr_q] <= data_in_i;
            wr_ptr_q        <= wr_ptr_q + 1'd1;
        end

        // Pop
        if (pop_i & valid_o)
        begin
            rd_ptr_q      <= rd_ptr_q + 1'd1;
        end

        // Count up
        if ((push_i & accept_o) & ~(pop_i & valid_o))
        begin
            count_q <= count_q + 2'd1;
        end
        // Count down
        else if (~(push_i & accept_o) & (pop_i & valid_o))
        begin
            count_q <= count_q - 2'd1;
        end
    end
end

//-------------------------------------------------------------------
// Combinatorial
//-------------------------------------------------------------------
assign valid_o       = (count_q != 2'd0);
assign accept_o      = (count_q != 2'd2);
assign data_out_o    = ram_q[rd_ptr_q];

endmodule
