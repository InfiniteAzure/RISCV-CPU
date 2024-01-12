`ifndef ROB
`define ROB
module ROB (
    input wire clk,
    input wire rst,
    input wire rdy,
    output reg rollback,

    output wire rob_nxt_full,

    //broadcast
    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,
    input wire alu_result_jump,
    input wire [31:0] alu_result_pc,

    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val,

    //issue from other modules
    input wire issue,
    input wire [4:0] issue_rd,
    input wire [6:0] issue_opcode,
    input wire [31:0] issue_pc,
    input wire issue_pred_jump,
    input wire issue_is_ready,

    //for IO
    output wire [3:0] head_rob_pos,

    //to regfile
    output reg reg_write,
    output reg [4:0] reg_rd,
    output reg [31:0] reg_val,
    //to lsb
    output reg lsb_store,

    //commit
    output reg [3:0] commit_rob_pos,

    //set pc to ifetch
    output reg if_set_pc_en,
    output reg [31:0] if_set_pc,
    // update predictor
    output reg commit_br,
    output reg commit_br_jump,
    output reg [31:0] commit_br_pc,

    //query from decoder
    input  wire [3:0] rs1_pos,
    output wire rs1_ready,
    output wire [31:0] rs1_val,
    input  wire [3:0] rs2_pos,
    output wire rs2_ready,
    output wire [31:0] rs2_val,
    output wire [3:0] nxt_rob_pos
);

    reg [3:0] head, tail;
    reg empty;
    reg ready [15:0];
    reg [4:0] rd [15:0];
    reg [31:0] val [15:0];
    reg [31:0] pc [15:0];
    reg [6:0] opcode [15:0];
    reg pred_jump [15:0];
    reg res_jump [15:0];
    reg [31:0] res_pc [15:0];

    wire commit = !empty && ready[head];
    wire [3:0] nxt_head = head + commit;
    assign nxt_rob_pos = tail;
    wire nxt_empty = (nxt_head == tail + issue && (empty || commit && !issue));
    assign rob_nxt_full = (nxt_head == tail + issue && !nxt_empty);

    assign head_rob_pos = head;

    assign rs1_ready = ready[rs1_pos];
    assign rs1_val = val[rs1_pos];
    assign rs2_ready = ready[rs2_pos];
    assign rs2_val = val[rs2_pos];

    integer i;
    always @(posedge clk) begin
        if (rst || rollback) begin
            head <= 0;
            tail <= 0;
            rollback <= 0;
            empty <= 1;
            if_set_pc_en <= 0;
            if_set_pc <= 0;
            reg_write <= 0;
            lsb_store <= 0;
            commit_br <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                ready[i] <= 0;
                rd[i] <= 0;
                val[i] <= 0;
                pc[i] <= 0;
                opcode[i] <= 0;
                pred_jump[i] <= 0;
                res_jump[i] <= 0;
                res_pc[i] <= 0;
            end
        end else if (rdy) begin
            empty <= nxt_empty;
            //update
            if (alu_result) begin
                val[alu_result_rob_pos] <= alu_result_val;
                ready[alu_result_rob_pos] <= 1;
                res_jump[alu_result_rob_pos] <= alu_result_jump;
                res_pc[alu_result_rob_pos] <= alu_result_pc;
            end
            if (lsb_result) begin
                val[lsb_result_rob_pos] <= lsb_result_val;
                ready[lsb_result_rob_pos] <= 1;
            end

            if (issue) begin
                rd[tail] <= issue_rd;
                opcode[tail] <= issue_opcode;
                pc[tail] <= issue_pc;
                pred_jump[tail] <= issue_pred_jump;
                ready[tail] <= issue_is_ready;
                tail <= tail + 1'b1;
            end
            
            reg_write <= 0;
            lsb_store <= 0;
            commit_br <= 0;
            reg_write <= 0;
            if (commit) begin //commit
                commit_rob_pos <= head;
                if (opcode[head] == 7'b0100011) begin
                    lsb_store <= 1;
                end
                else if (opcode[head] != 7'b1100011) begin
                    reg_write <= 1;
                    reg_rd <= rd[head];
                    reg_val <= val[head];
                end
                if (opcode[head] == 7'b1100011) begin
                    commit_br <= 1;
                    commit_br_jump <= res_jump[head];
                    commit_br_pc <= pc[head];
                    if (pred_jump[head] != res_jump[head]) begin
                        rollback <= 1;
                        if_set_pc_en <= 1;
                        if_set_pc <= res_pc[head];
                    end
                end
                if (opcode[head] == 7'b1100111) begin
                    if (pred_jump[head] != res_jump[head]) begin
                        rollback <= 1;
                        if_set_pc_en <= 1;
                        if_set_pc <= res_pc[head];
                    end
                end
                head <= head + 1'b1;
            end
        end
    end
endmodule
`endif