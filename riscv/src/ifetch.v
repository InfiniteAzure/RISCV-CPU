`ifndef IFETCH
`define IFETCH
module IFetch (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rob_nxt_full,
    input wire rs_nxt_full,
    input wire lsb_nxt_full,

    //rob set pc
    input wire rob_set_pc_en,
    input wire [31:0] rob_set_pc,

    //cache miss
    output reg mc_en,
    output reg [31:0] mc_pc,
    input  wire mc_done,
    input  wire [31:0] mc_data,

    //to decoder
    output reg inst_rdy,
    output reg [31:0] inst,
    output reg [31:0] inst_pc,
    output reg inst_pred_jump,

    //rob update bht
    input wire rob_br,
    input wire rob_br_jump,
    input wire [31:0] rob_br_pc
);
    integer i;
    reg [31:0] pc;
    reg status;

    //ICache
    reg free[511:0];
    reg [20:0] tag[511:0];
    reg [31:0] data[511:0];

    reg [31:0] pred_pc;
    reg pred_jump;

    wire [8:0] pc_index = pc[10:2];
    wire [20:0] pc_tag = pc[31:11];
    wire is_free = free[pc_index] && (tag[pc_index] == pc_tag);

    wire [8:0] mc_pc_index = mc_pc[10:2];
    wire [20:0] mc_pc_tag = mc_pc[31:11];
    wire [31:0] get_inst = data[pc_index];

    //bht
    reg [1:0] bht[511:0];
    wire [8:0] bht_idx = rob_br_pc[10:2];
    wire [8:0] pc_bht_idx = pc[10:2];

    //predictor
    always @(*) begin
        pred_pc = pc + 4;
        pred_jump = 0;
        case (get_inst[6:0])
        7'b1101111: begin
            pred_pc = pc + {{12{get_inst[31]}}, get_inst[19:12], get_inst[20], get_inst[30:21], 1'b0};
            pred_jump = 1;
        end
        7'b1100011: begin
            if (bht[pc_bht_idx] >= 2'b10) begin
                pred_pc = pc + {{20{get_inst[31]}}, get_inst[7], get_inst[30:25], get_inst[11:8], 1'b0};
                pred_jump = 1;
            end
        end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
            mc_pc <= 32'b0;
            mc_en <= 0;
            inst_rdy <= 0;
            status <= 1'b0;
            for (i = 0; i < 512; i = i + 1) begin 
                free[i] <= 0;
            end
            for (i = 0; i < 512; i = i + 1) begin 
                bht[i] <= 0;
            end

        end
        else if (rdy) begin
            if (rob_set_pc_en) begin
                pc <= rob_set_pc;
                inst_rdy <= 0;
            end else begin
                if (is_free && !rs_nxt_full && !lsb_nxt_full && !rob_nxt_full) begin
                    inst_rdy <= 1;
                    inst <= get_inst;
                    inst_pc <= pc;
                    pc <= pred_pc;
                    inst_pred_jump <= pred_jump;
                end
                else inst_rdy <= 0;
            end
            if (status == 1'b0) begin
                if (!is_free) begin
                    mc_en <= 1;
                    mc_pc <= {pc[31:11], pc[10:2], 2'b0};
                    status <= 1'b1;
                end
            end else begin
                if (mc_done) begin
                    free[mc_pc_index] <= 1;
                    tag[mc_pc_index] <= mc_pc_tag;
                    data[mc_pc_index] <= mc_data;
                    mc_en <= 0;
                    status <= 1'b0;
                end
            end
            if (rob_br) begin
                if (rob_br_jump) begin
                    if (bht[bht_idx] < 2'b11) bht[bht_idx] <= bht[bht_idx] + 1;
                end else begin
                    if (bht[bht_idx] > 2'b0) bht[bht_idx] <= bht[bht_idx] - 1;
                end
            end
        end
    end
endmodule
`endif