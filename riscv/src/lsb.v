`ifndef LSB
`define LSB
module LSB (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //issue
    input wire issue,
    input wire [3:0] issue_rob_pos,
    input wire issue_is_store,
    input wire [2:0] issue_funct3,
    input wire [31:0] issue_rs1_val,
    input wire [4:0] issue_rs1_rob_id,
    input wire [31:0] issue_rs2_val,
    input wire [4:0] issue_rs2_rob_id,
    input wire [31:0] issue_imm,

    //mem_ctrl
    output reg mc_en,
    output reg mc_wr,
    output reg [31:0] mc_addr,
    output reg [2:0] mc_len,
    output reg [31:0] mc_w_data,
    input  wire mc_done,
    input  wire [31:0] mc_r_data,
    
    //from rs
    input wire alu_result,
    input wire [3:0] alu_result_rob_pos,
    input wire [31:0] alu_result_val,

    // from lsb
    input wire lsb_result,
    input wire [3:0] lsb_result_rob_pos,
    input wire [31:0] lsb_result_val,

    //from rob, commit store
    input wire commit_store,
    input wire [3:0] commit_rob_pos,

    //broadcast
    output reg result,
    output reg [3:0] result_rob_pos,
    output reg [31:0] result_val,

    //for IO
    input wire [3:0] head_rob_pos,

    output wire lsb_nxt_full
);
    integer i;

    reg [3:0] head, tail;
    reg [4:0] final_store_pos;
    reg busy [15:0];
    reg empty;
    reg waiting;

    reg is_store [15:0];
    reg [2:0] funct3 [15:0];
    reg [4:0] rs1_rob_id [15:0];
    reg [31:0] rs1_val [15:0];
    reg [4:0] rs2_rob_id [15:0];
    reg [31:0] rs2_val [15:0];
    reg [31:0] imm [15:0];
    reg [3:0] rob_pos [15:0];
    reg committed [15:0];

    wire [31:0] head_addr = rs1_val[head] + imm[head];
    wire head_is_io = head_addr[17:16] == 2'b11;
    wire OK = !empty && rs1_rob_id[head][4] == 0 && rs2_rob_id[head][4] == 0;
    wire r_ready = !is_store[head] && !rollback && (!head_is_io || rob_pos[head] == head_rob_pos);
    wire w_ready = committed[head];
    wire head_ready = OK && (r_ready || w_ready);

    wire ready = waiting == 1 && mc_done;
    wire [3:0] nxt_head = head + ready;
    wire [3:0] nxt_tail = tail + issue;
    wire nxt_empty = (nxt_head == nxt_tail && (empty || ready && !issue));
    assign lsb_nxt_full = (nxt_head == nxt_tail && !nxt_empty);

    always @(posedge clk) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
            waiting <= 0;
            mc_en <= 0;
            empty <= 1;
            final_store_pos <= 5'd16;
            for (i = 0; i < 16; i = i + 1) begin
                committed[i] <= 0;
                busy[i] <= 0;
                is_store[i] <= 0;
                rs1_val[i] <= 0;
                rs1_rob_id[i] <= 0;
                rs2_val[i] <= 0;
                rs2_rob_id[i] <= 0;
                funct3[i] <= 0;
                imm[i] <= 0;
                rob_pos[i] <= 0;
            end
        end else if (rdy && !rollback) begin
            //receive
            if (alu_result) begin
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
            if (lsb_result) begin
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

            result <= 0;
            if(waiting == 0) begin
                mc_en <= 0;
                mc_wr <= 0;
                if (head_ready) begin
                    mc_en <= 1;
                    mc_addr <= head_addr;
                    case (funct3[head])
                        3'h0, 3'h4: mc_len <= 3'd1;
                        3'h1, 3'h5: mc_len <= 3'd2;
                        3'h2: mc_len <= 3'd4;
                    endcase
                    if (is_store[head]) begin
                        mc_w_data <= rs2_val[head];
                        mc_wr <= 1;
                    end
                    waiting <= 1;
                end
            end
            else if (waiting == 1 && mc_done) begin
                busy[head] <= 0;
                committed[head] <= 0;
                if (!is_store[head]) begin
                    result <= 1;
                    case (funct3[head])
                    3'h0: result_val <= {{24{mc_r_data[7]}}, mc_r_data[7:0]};
                    3'h4: result_val <= {24'b0, mc_r_data[7:0]};
                    3'h1: result_val <= {{16{mc_r_data[15]}}, mc_r_data[15:0]};
                    3'h5: result_val <= {16'b0, mc_r_data[15:0]};
                    3'h2: result_val <= mc_r_data;
                    endcase
                    result_rob_pos <= rob_pos[head];
                end
                if (final_store_pos[3:0] == head) final_store_pos <= 5'd16;
                waiting <= 0;
                mc_en  <= 0;
            end 

            

            if (issue) begin
                busy[tail] <= 1;
                is_store[tail] <= issue_is_store;
                funct3[tail] <= issue_funct3;
                rs1_rob_id[tail] <= issue_rs1_rob_id;
                rs1_val[tail] <= issue_rs1_val;
                rs2_rob_id[tail] <= issue_rs2_rob_id;
                rs2_val[tail] <= issue_rs2_val;
                imm[tail] <= issue_imm;
                rob_pos[tail] <= issue_rob_pos;
                tail <= tail + 1'b1;
            end

            //commit
            if (commit_store) begin
                for (i = 0; i < 16; i = i + 1)begin
                    if (busy[i] && rob_pos[i] == commit_rob_pos && !committed[i]) begin
                        committed[i] <= 1;
                        final_store_pos <= {1'b0, i[3:0]};
                    end
                end
            end

            empty <= nxt_empty;
            head <= nxt_head;
        end else if (rollback) begin
            if(final_store_pos == 5'd16)begin
                head <= 0;
                tail <= 0;
                waiting <= 0;
                mc_en <= 0;
                empty <= 1;
                final_store_pos <= 5'd16;
                for (i = 0; i < 16; i = i + 1) begin
                    committed[i] <= 0;
                    busy[i] <= 0;
                    is_store[i] <= 0;
                    rs1_val[i] <= 0;
                    rs1_rob_id[i] <= 0;
                    rs2_val[i] <= 0;
                    rs2_rob_id[i] <= 0;
                    funct3[i] <= 0;
                    imm[i] <= 0;
                    rob_pos[i] <= 0;
                end
            end
            else begin
                tail <= final_store_pos + 1;
                for (i = 0; i < 16; i = i + 1) begin
                    if (!committed[i]) begin
                        busy[i] <= 0;
                    end
                end
                if (waiting == 1 && mc_done) begin
                    busy[head] <= 0;
                    committed[head] <= 0;
                    waiting <= 0;
                    mc_en <= 0;
                    head <= head + 1'b1;
                    //add if for head == last commit
                    if (final_store_pos[3:0] == head) begin
                        final_store_pos <= 5'd16;
                        empty <= 1;
                    end
                end
            end
        end
    end
endmodule
`endif