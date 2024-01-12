`ifndef RS
`define RS
module RS (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output reg rs_nxt_full,

    //issue
    input wire issue,
    input wire [3:0] issue_rob_pos,
    input wire [6:0] issue_opcode,
    input wire [2:0] issue_funct3,
    input wire issue_funct7,
    input wire [31:0] issue_rs1_val,
    input wire [4:0] issue_rs1_rob_id,
    input wire [31:0] issue_rs2_val,
    input wire [4:0] issue_rs2_rob_id,
    input wire [31:0] issue_imm,
    input wire [31:0] issue_pc,

    //to ALU
    output reg alu_en,
    output reg [6:0] alu_opcode,
    output reg [2:0] alu_funct3,
    output reg alu_funct7,
    output reg [31:0] alu_val1,
    output reg [31:0] alu_val2,
    output reg [31:0] alu_imm,
    output reg [31:0] alu_pc,
    output reg [3:0] alu_rob_pos,

    //broadcast
    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,

    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val
);
    integer i;
    reg busy [15:0];
    reg [3:0] rob_pos [15:0];
    reg [6:0] opcode [15:0];
    reg [2:0] funct3 [15:0];
    reg funct7 [15:0];
    reg [4:0] rs1_rob_id [15:0];
    reg [31:0] rs1_val [15:0];
    reg [4:0] rs2_rob_id [15:0];
    reg [31:0] rs2_val [15:0];
    reg [31:0] pc [15:0];
    reg [31:0] imm [15:0];

    reg ready [15:0];
    reg [4:0] ready_pos, free_pos;
    reg [4:0] empty_count;
    //find free_pos and ready_pos
    always @(*) begin
        free_pos = 5'd16;
        ready_pos = 5'd16;
        empty_count = 0;
        rs_nxt_full = 1;
        for (i = 0; i < 16; i = i + 1) begin
            ready[i] = 0;
            if (!busy[i]) begin
                free_pos = i;
                empty_count = empty_count + 1;
            end
            if (busy[i] && rs1_rob_id[i][4] == 0 && rs2_rob_id[i][4] == 0) begin
                ready[i]  = 1;
                ready_pos = i;
            end
        end
        if(!(issue && empty_count - 1 == 0)) rs_nxt_full = 0;
    end
    always @(posedge clk) begin
        if (rst || rollback) begin
            for (i = 0; i < 16; i = i + 1) busy[i] <= 0;
            alu_en <= 0;
        end
        else if (rdy) begin
            //update
            if (alu_result)begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (rs1_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
                        rs1_rob_id[i] <= 0;
                        rs1_val[i] <= alu_result_val;
                    end
                    if (rs2_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
                        rs2_rob_id[i] <= 0;
                        rs2_val[i] <= alu_result_val;
                    end
                end
            end
            if (lsb_result)begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (rs1_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
                        rs1_rob_id[i] <= 0;
                        rs1_val[i] <= lsb_result_val;
                    end
                    if (rs2_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
                        rs2_rob_id[i] <= 0;
                        rs2_val[i] <= lsb_result_val;
                        
                    end
                end
            end
            //decoder issues to rs
            if (issue) begin
                busy[free_pos] <= 1;
                opcode[free_pos] <= issue_opcode;
                funct3[free_pos] <= issue_funct3;
                funct7[free_pos] <= issue_funct7;
                rs1_rob_id[free_pos] <= issue_rs1_rob_id;
                rs1_val[free_pos] <= issue_rs1_val;
                rs2_rob_id[free_pos] <= issue_rs2_rob_id;
                rs2_val[free_pos] <= issue_rs2_val;
                pc[free_pos] <= issue_pc;
                imm[free_pos] <= issue_imm;
                rob_pos[free_pos] <= issue_rob_pos;
            end
            //rs issues to alu
            alu_en <= 0;
            if (ready_pos != 5'd16) begin
                alu_en <= 1;
                alu_opcode <= opcode[ready_pos];
                alu_funct3 <= funct3[ready_pos];
                alu_funct7 <= funct7[ready_pos];
                alu_val1 <= rs1_val[ready_pos];
                alu_val2 <= rs2_val[ready_pos];
                alu_imm <= imm[ready_pos];
                alu_pc <= pc[ready_pos];
                alu_rob_pos <= rob_pos[ready_pos];
                busy[ready_pos] <= 0;
            end
        end
    end

endmodule
`endif