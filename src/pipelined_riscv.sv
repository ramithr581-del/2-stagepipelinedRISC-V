`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.11.2026 18:11:50
// Design Name: 
// Module Name: pipelined_riscv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pipelined_riscv (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] instruction,
    input  logic [31:0] mem_out,
    output logic [31:0] address,
    output logic [31:0] alu_out,
    output logic [31:0] rs2_data,
    output logic        mem_write,
    output logic        mem_read,
    output logic [2:0]  fn3
);

    // ---------------------------------------------------------------------
    // Architectural state and the two pipeline stages
    // Stage 1: fetch + decode + register read
    // Stage 2: execute + memory interface + writeback
    // ---------------------------------------------------------------------

    logic [31:0] pc;
    logic [31:0] registers [0:31];

    logic        s2_valid;
    logic [31:0] s2_pc;
    logic [31:0] s2_pc4;
    logic [31:0] s2_rs1_value;
    logic [31:0] s2_rs2_value;
    logic [31:0] s2_imm;
    logic [4:0]  s2_rd;
    logic [2:0]  s2_funct3;
    logic [6:0]  s2_funct7;
    logic [6:0]  s2_opcode;

    logic [4:0]  s1_rs1;
    logic [4:0]  s1_rs2;
    logic [4:0]  s1_rd;
    logic [2:0]  s1_funct3;
    logic [6:0]  s1_funct7;
    logic [6:0]  s1_opcode;
    logic [31:0] s1_imm;
    logic [31:0] s1_rs1_value;
    logic [31:0] s1_rs2_value;

    logic        s2_reg_write;
    logic [31:0] s2_alu_result;
    logic [31:0] s2_wb_data;
    logic        s2_redirect;
    logic [31:0] s2_redirect_target;
    logic        s2_branch_taken;

    integer i;

    assign address = pc;

    // ---------------------------------------------------------------------
    // Stage 1: decode the instruction currently presented by instruction
    // memory. Instruction memory is combinational and is external to this
    // module, as required by the assignment.
    // ---------------------------------------------------------------------

    always_comb begin
        s1_opcode = instruction[6:0];
        s1_rd     = instruction[11:7];
        s1_funct3 = instruction[14:12];
        s1_rs1    = instruction[19:15];
        s1_rs2    = instruction[24:20];
        s1_funct7 = instruction[31:25];
        s1_imm    = 32'b0;

        case (s1_opcode)
            7'b0010011, // OP-IMM
            7'b0000011, // LOAD
            7'b1100111: // JALR
                s1_imm = {{20{instruction[31]}}, instruction[31:20]};

            7'b0100011: // STORE
                s1_imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            7'b1100011: // BRANCH
                s1_imm = {{19{instruction[31]}}, instruction[31], instruction[7],
                          instruction[30:25], instruction[11:8], 1'b0};

            7'b0110111, // LUI
            7'b0010111: // AUIPC
                s1_imm = {instruction[31:12], 12'b0};

            7'b1101111: // JAL
                s1_imm = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                          instruction[20], instruction[30:21], 1'b0};

            default: s1_imm = 32'b0;
        endcase
    end

    // Register-file read with same-cycle forwarding from stage 2.
    // This resolves ALU, load, branch, JALR, and store-data dependencies
    // without inserting data-hazard stalls.
    always_comb begin
        s1_rs1_value = (s1_rs1 == 5'd0) ? 32'b0 : registers[s1_rs1];
        s1_rs2_value = (s1_rs2 == 5'd0) ? 32'b0 : registers[s1_rs2];

        if (s2_valid && s2_reg_write && (s2_rd != 5'd0) && (s2_rd == s1_rs1))
            s1_rs1_value = s2_wb_data;

        if (s2_valid && s2_reg_write && (s2_rd != 5'd0) && (s2_rd == s1_rs2))
            s1_rs2_value = s2_wb_data;

        if (s1_rs1 == 5'd0)
            s1_rs1_value = 32'b0;
        if (s1_rs2 == 5'd0)
            s1_rs2_value = 32'b0;
    end

    // ---------------------------------------------------------------------
    // Stage 2: execute the instruction held in the pipeline registers.
    // ---------------------------------------------------------------------

    always_comb begin
        s2_alu_result     = 32'b0;
        s2_branch_taken   = 1'b0;
        s2_redirect       = 1'b0;
        s2_redirect_target = s2_pc4;
        s2_reg_write      = 1'b0;
        s2_wb_data        = s2_alu_result;

        alu_out = 32'b0;
        rs2_data = s2_rs2_value;
        mem_write = 1'b0;
        mem_read  = 1'b0;
        fn3       = s2_funct3;

        if (s2_valid) begin
            case (s2_opcode)
                // Register-register ALU operations
                7'b0110011: begin
                    s2_reg_write = 1'b1;
                    case (s2_funct3)
                       3'b000: begin
    if (s2_funct7 == 7'b0100000)
        s2_alu_result = s2_rs1_value - s2_rs2_value;
    else
        s2_alu_result = s2_rs1_value + s2_rs2_value;
end
                        3'b001: s2_alu_result = s2_rs1_value << s2_rs2_value[4:0];
                        3'b010: s2_alu_result = ($signed(s2_rs1_value) < $signed(s2_rs2_value)) ? 32'd1 : 32'd0;
                        3'b011: s2_alu_result = (s2_rs1_value < s2_rs2_value) ? 32'd1 : 32'd0;
                        3'b100: s2_alu_result = s2_rs1_value ^ s2_rs2_value;
                        3'b101: s2_alu_result = (s2_funct7[5]) ? ($signed(s2_rs1_value) >>> s2_rs2_value[4:0]) : (s2_rs1_value >> s2_rs2_value[4:0]);
                        3'b110: s2_alu_result = s2_rs1_value | s2_rs2_value;
                        3'b111: s2_alu_result = s2_rs1_value & s2_rs2_value;
                        default: s2_alu_result = 32'b0;
                    endcase
                end

                // Register-immediate ALU operations
                7'b0010011: begin
                    s2_reg_write = 1'b1;
                    case (s2_funct3)
                        3'b000: s2_alu_result = s2_rs1_value + s2_imm;
                        3'b010: s2_alu_result = ($signed(s2_rs1_value) < $signed(s2_imm)) ? 32'd1 : 32'd0;
                        3'b011: s2_alu_result = (s2_rs1_value < s2_imm) ? 32'd1 : 32'd0;
                        3'b100: s2_alu_result = s2_rs1_value ^ s2_imm;
                        3'b110: s2_alu_result = s2_rs1_value | s2_imm;
                        3'b111: s2_alu_result = s2_rs1_value & s2_imm;
                        3'b001: s2_alu_result = s2_rs1_value << s2_imm[4:0];
                        3'b101: begin
    if (s2_funct7 == 7'b0100000)
        s2_alu_result = $signed(s2_rs1_value) >>> s2_rs2_value[4:0];
    else
        s2_alu_result = s2_rs1_value >> s2_rs2_value[4:0];
end
                        default: s2_alu_result = 32'b0;
                    endcase
                end

                // Loads and stores: byte address is the ALU result.
                7'b0000011: begin
                    s2_alu_result = s2_rs1_value + s2_imm;
                    s2_reg_write  = 1'b1;
                    mem_read      = 1'b1;
                end

                7'b0100011: begin
                    s2_alu_result = s2_rs1_value + s2_imm;
                    mem_write     = 1'b1;
                end

                // Conditional branches
                7'b1100011: begin
                    case (s2_funct3)
                        3'b000: s2_branch_taken = (s2_rs1_value == s2_rs2_value); // BEQ
                        3'b001: s2_branch_taken = (s2_rs1_value != s2_rs2_value); // BNE
                        3'b100: s2_branch_taken = ($signed(s2_rs1_value) < $signed(s2_rs2_value)); // BLT
                        3'b101: s2_branch_taken = ($signed(s2_rs1_value) >= $signed(s2_rs2_value)); // BGE
                        3'b110: s2_branch_taken = (s2_rs1_value < s2_rs2_value); // BLTU
                        3'b111: s2_branch_taken = (s2_rs1_value >= s2_rs2_value); // BGEU
                        default: s2_branch_taken = 1'b0;
                    endcase
                    if (s2_branch_taken) begin
                        s2_redirect = 1'b1;
                        s2_redirect_target = s2_pc + s2_imm;
                    end
                end

                // JAL
                7'b1101111: begin
                    s2_reg_write       = 1'b1;
                    s2_alu_result      = s2_pc + s2_imm;
                    s2_redirect        = 1'b1;
                    s2_redirect_target = s2_pc + s2_imm;
                    s2_wb_data         = s2_pc4;
                end

                // JALR
                7'b1100111: begin
                    s2_reg_write       = 1'b1;
                    s2_alu_result      = (s2_rs1_value + s2_imm) & 32'hffff_fffe;
                    s2_redirect        = 1'b1;
                    s2_redirect_target = (s2_rs1_value + s2_imm) & 32'hffff_fffe;
                    s2_wb_data         = s2_pc4;
                end

                // LUI
                7'b0110111: begin
                    s2_reg_write  = 1'b1;
                    s2_alu_result = s2_imm;
                end

                // AUIPC
                7'b0010111: begin
                    s2_reg_write  = 1'b1;
                    s2_alu_result = s2_pc + s2_imm;
                end

                // FENCE and unsupported/system encodings have no effect.
                default: begin
                    s2_reg_write = 1'b0;
                    s2_alu_result = 32'b0;
                end
            endcase

            // Select the architectural writeback value.
            case (s2_opcode)
                7'b0000011: s2_wb_data = mem_out; // load
                7'b1101111,
                7'b1100111: s2_wb_data = s2_pc4;  // jump/link
                7'b0110111: s2_wb_data = s2_imm;  // LUI
                7'b0010111: s2_wb_data = s2_pc + s2_imm; // AUIPC
                default:    s2_wb_data = s2_alu_result;
            endcase

            alu_out = s2_alu_result;
        end
    end

    // ---------------------------------------------------------------------
    // State updates. A redirect flushes the instruction currently being
    // fetched by not allowing it into stage 2. This prevents wrong-path
    // register writes and stores.
    // ---------------------------------------------------------------------

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc       <= 32'h8000_0000;
            s2_valid <= 1'b0;

            s2_pc         <= 32'b0;
            s2_pc4        <= 32'b0;
            s2_rs1_value  <= 32'b0;
            s2_rs2_value  <= 32'b0;
            s2_imm        <= 32'b0;
            s2_rd         <= 5'b0;
            s2_funct3     <= 3'b0;
            s2_funct7     <= 7'b0;
            s2_opcode     <= 7'b0;

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end else begin
            // Commit stage-2 register write. x0 is immutable.
            if (s2_valid && s2_reg_write && (s2_rd != 5'd0))
                registers[s2_rd] <= s2_wb_data;
            registers[0] <= 32'b0;

            if (s2_valid && s2_redirect) begin
                pc       <= s2_redirect_target;
                s2_valid <= 1'b0; // squash the sequentially fetched instruction
            end else begin
                pc       <= pc + 32'd4;
                s2_valid <= 1'b1;

                s2_pc        <= pc;
                s2_pc4       <= pc + 32'd4;
                s2_rs1_value <= s1_rs1_value;
                s2_rs2_value <= s1_rs2_value;
                s2_imm       <= s1_imm;
                s2_rd        <= s1_rd;
                s2_funct3    <= s1_funct3;
                s2_funct7    <= s1_funct7;
                s2_opcode    <= s1_opcode;
            end
        end
    end

endmodule
