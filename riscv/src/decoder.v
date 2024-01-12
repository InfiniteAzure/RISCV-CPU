`ifndef DECODER
`define DECODER

module Decoder (
    input wire rst,
    input wire rdy,

    input wire rollback,

    //issue
    output reg issue,
    output reg [3:0] rob_pos,
    output reg [6:0] opcode,
    output reg is_store,
    output reg [2:0] funct3,
    output reg funct7,
    output reg [31:0] rs1_val,
    output reg [31:0] rs2_val,
    output reg [4:0] rs1_rob_id,
    output reg [4:0] rs2_rob_id,
    output reg [31:0] imm,
    output reg [4:0] rd,
    output reg [31:0] pc,
    output reg pred_jump,
    output reg is_ready,

    //ifetch
    input wire inst_rdy,
    input wire [31:0] inst,
    input wire [31:0] inst_pc,
    input wire inst_pred_jump,

    //regfile
    output wire [4:0] reg_rs1,
    output wire [4:0] reg_rs2,
    input  wire [31:0] reg_rs1_val,
    input  wire [31:0] reg_rs2_val,
    input  wire [4:0] reg_rs1_rob_id,
    input  wire [4:0] reg_rs2_rob_id,

    //from rob
    output wire [3:0] rob_rs1_pos,
    output wire [3:0] rob_rs2_pos,
    input  wire rob_rs1_ready,
    input  wire rob_rs2_ready,
    input  wire [31:0] rob_rs1_val,
    input  wire [31:0] rob_rs2_val,

    output reg rs_en,
    output reg lsb_en,

    input wire [3:0] nxt_rob_pos,

    //broadcast
    //from rs
    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,
    //from lsb
    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val
);

    assign reg_rs1 = inst[19:15];
    assign reg_rs2 = inst[24:20];
    assign rob_rs1_pos = reg_rs1_rob_id[3:0];
    assign rob_rs2_pos = reg_rs2_rob_id[3:0];

    always @(*) begin
        opcode = inst[6:0];
        funct3 = inst[14:12];
        funct7 = inst[30];
        rd = inst[11:7];
        imm = 0;
        pc = inst_pc;
        pred_jump = inst_pred_jump;
        rob_pos = nxt_rob_pos;
        issue = 0;
        lsb_en = 0;
        rs_en = 0;
        is_ready = 0;
        rs1_val = 0;
        rs2_val = 0;
        rs1_rob_id = 0;
        rs2_rob_id = 0;

        if (!rst && !rollback && rdy && inst_rdy) begin
            issue = 1;

            rs1_rob_id = 0;
            if (reg_rs1_rob_id[4] == 0) rs1_val = reg_rs1_val;
            else if (rob_rs1_ready) rs1_val = rob_rs1_val;
            else if (alu_result && rob_rs1_pos == alu_result_rob_pos) rs1_val = alu_result_val;
            else if (lsb_result && rob_rs1_pos == lsb_result_rob_pos) rs1_val = lsb_result_val;
            else begin
                rs1_val = 0;
                rs1_rob_id = reg_rs1_rob_id;
            end
            rs2_rob_id = 0;
            if (reg_rs2_rob_id[4] == 0)rs2_val = reg_rs2_val;
            else if (rob_rs2_ready)rs2_val = rob_rs2_val;
            else if (alu_result && rob_rs2_pos == alu_result_rob_pos)rs2_val = alu_result_val;
            else if (lsb_result && rob_rs2_pos == lsb_result_rob_pos)rs2_val = lsb_result_val;
            else begin
                rs2_val = 0;
                rs2_rob_id = reg_rs2_rob_id;
            end

            is_store = 0;
            //if set zero, then it is unused.
            case (inst[6:0])
                7'b0000011: begin
                    lsb_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                7'b0100011: begin
                    lsb_en = 1;
                    is_ready = 1;//If store,then set ready so that it can be committed directly.
                    rd = 0;
                    imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                    is_store = 1;
                end
                7'b0110011: rs_en = 1;
                7'b0010011: begin
                    rs_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                7'b1101111: begin
                    rs_en = 1;
                    rs1_rob_id = 0;
                    rs1_val = 0;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                end
                7'b1100111: begin
                    rs_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                7'b1100011: begin
                    rs_en = 1;
                    rd = 0;
                    imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                end
                7'b0110111, 7'b0010111: begin
                    rs_en = 1;
                    rs1_rob_id = 0;
                    rs1_val = 0;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {inst[31:12], 12'b0};
                end
            endcase
        end
    end

endmodule
`endif
