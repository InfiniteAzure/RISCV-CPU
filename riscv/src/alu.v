`ifndef ALU
`define ALU
module ALU (
    input wire clk,
    input wire rst,
    input wire rdy,
    input wire rollback,

    //from rs
    input wire alu_en,
    input wire [3:0] rob_pos,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire funct7,
    input wire [31:0] val1,
    input wire [31:0] val2,
    input wire [31:0] imm,
    input wire [31:0] pc,

    //broadcast
    output reg result,
    output reg [3:0] result_rob_pos,
    output reg [31:0] result_val,
    output reg result_jump,
    output reg [31:0] result_pc
);

    wire [31:0] number1 = val1;
    wire [31:0] number2 = opcode == 7'b0110011 ? val2 : imm;
    reg [31:0] ans;
    
    always @(*) begin
        case (funct3)
        3'h0:
            if (opcode == 7'b0110011 && funct7) ans = number1 - number2;
            else ans = number1 + number2;
        3'h7: ans = number1 & number2;
        3'h6: ans = number1 | number2;
        3'h4: ans = number1 ^ number2;
        3'h2: ans = ($signed(number1) < $signed(number2));
        3'h3: ans = (number1 < number2);
        3'h1: ans = number1 << number2;
        3'h5:
            if (funct7) ans = $signed(number1) >> number2[5:0];
            else ans = number1 >> number2[5:0];
        endcase
    end

    reg jump;
    always @(*) begin
        case (funct3)
        3'h0: jump = (val1 == val2);
        3'h1: jump = (val1 != val2);
        3'h4: jump = ($signed(val1) < $signed(val2));
        3'h6: jump = (val1 < val2);
        3'h5: jump = ($signed(val1) >= $signed(val2));
        3'h7: jump = (val1 >= val2);
        default: jump = 0;
        endcase
    end

    always @(posedge clk) begin
        if (rst || rollback) begin
            result <= 0;
            result_rob_pos <= 0;
            result_val <= 0;
            result_jump <= 0;
            result_pc <= 0;
        end
        else if (rdy)begin
            result <= 0;
            if (alu_en) begin
                result <= 1;
                result_rob_pos <= rob_pos;
                result_jump <= 0;
                case (opcode)
                7'b0110011: result_val <= ans;
                7'b0010011: result_val <= ans;
                7'b0110111: result_val <= imm;
                7'b0010111: result_val <= pc + imm;
                7'b1100011:
                    if (jump) begin
                        result_jump <= 1;
                        result_pc <= pc + imm;
                    end else begin
                        result_pc <= pc + 4;
                    end
                7'b1101111: begin
                    result_jump <= 1;
                    result_val <= pc + 4;
                    result_pc <= pc + imm;
                end
                7'b1100111: begin
                    result_jump <= 1;
                    result_val <= pc + 4;
                    result_pc <= val1 + imm;
                end
                endcase
            end
        end
    end
endmodule
`endif