`ifndef REGFILE
`define REGFILE
module RegFile (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //decoder issue instruction
    input wire issue,
    input wire [4:0] issue_rd,
    input wire [3:0] issue_rob_pos,

    //query from decoder
    input  wire [4:0] rs1,
    output reg [31:0] val1,
    output reg [4:0] rob_id1,
    input  wire [4:0] rs2,
    output reg [31:0] val2,
    output reg [4:0] rob_id2,

    //ROB commit
    input wire commit,
    input wire [4:0] commit_rd,
    input wire [31:0] commit_val,
    input wire [3:0] commit_rob_pos
);
    integer i;
    reg [31:0] val[31:0];
    reg [4:0] rob_id[31:0];

    wire commit_not_zero = commit_rd != 0;
    wire issue_not_zero = issue_rd != 0;
    wire latest_commit = rob_id[commit_rd] == {1'b1, commit_rob_pos};
    
    always @(*) begin
        if (commit && commit_not_zero && rs1 == commit_rd && latest_commit) begin
            rob_id1 = 5'b0;
            val1 = commit_val;
        end
        else begin
            rob_id1 = rob_id[rs1];
            val1 = val[rs1];
        end
        if (commit && commit_not_zero && rs2 == commit_rd && latest_commit) begin
            rob_id2 = 5'b0;
            val2 = commit_val;
        end
        else begin
            rob_id2 = rob_id[rs2];
            val2 = val[rs2];
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                val[i] <= 32'b0;
                rob_id[i] <= 5'b0;
            end
        end
        else if (rdy) begin
            if (rollback) begin
                for (i = 0; i < 32; i = i + 1) rob_id[i] <= 5'b0;
            end
            //issue after commit
            if (commit && commit_not_zero) begin
                val[commit_rd] <= commit_val;
                if (latest_commit) rob_id[commit_rd] <= 5'b0;
            end
            if (issue && issue_not_zero) begin
                rob_id[issue_rd] <= {1'b1, issue_rob_pos};
            end
        end
    end
endmodule
`endif