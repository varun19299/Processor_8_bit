`timescale 1ns / 1ps

/*
Controls entire data flow.
See READ_ME for details.
Harvard Architecture.
*/

`include "Parameter.v"
`include "DMEM.v"
`include "ALU.v"
`include "ALU_control.v"
`include "IMEM.v"
`include "Register.v"
`include "Datapath.v"

module CU(
 input clk,
 output[15:0] pc_out,
 output [7:0] alu_result);

wire jump,bne,beq,mem_read,mem_write,alu_src,reg_dst,mem_to_reg,reg_write;
wire[1:0] alu_op;
wire [3:0] opcode;

 reg  [15:0] pc_current;            //Current PC
 wire [15:0] pc_next,pc2;           //Next two PC
 wire [15:0] instr;                 // instruction Opcode
 wire [2:0] reg_write_dest;         //Which reg to write
 wire [15:0] reg_write_data;        //Data to write
 wire [2:0] reg_read_addr_1;        //Which reg to read 1
 wire [15:0] reg_read_data_1;       //Data to read 1
 wire [2:0] reg_read_addr_2;        //Which reg to read 2
 wire [15:0] reg_read_data_2;       //Data to read 2
 wire [15:0] ext_im,read_data2;     //External instruction offset, Is Data to read (ALU vs immediate)
 wire [2:0] ALU_Control;            //ALU OPS
 wire [15:0] ALU_out;               //Result of ALU
 wire zero_flag;                    //zero flag
 wire [15:0] PC_j, PC_beq, PC_2beq,PC_2bne,PC_bne;    //Wires for JUMP, BNE, BEQ
 wire beq_control;
 wire [12:0] jump_shift;
 wire [15:0] mem_read_data;

 // Initilialise PC
 initial begin
  pc_current <= 16'd0;
 end

// Read Instruction
 always @(posedge clk)
 begin
   pc_current <= pc_next;
 end

 assign pc2 = pc_current + 16'd2;
 // instruction memory
 Instruction_Memory im(.pc(pc_current),.instruction(instr));
 // jump shift left 2
 assign jump_shift = {instr[11:0],1'b0};

 Data_Path data(opcode,
 alu_op,
jump,beq,bne,mem_read,mem_write,alu_src,reg_dst,mem_to_reg,reg_write
);
 // multiplexer regdest
 assign reg_write_dest = (reg_dst==1'b1) ? instr[5:3] :instr[8:6];
 // register file
 assign reg_read_addr_1 = instr[11:9];
 assign reg_read_addr_2 = instr[8:6];

///////////////////////////////

 // GENERAL PURPOSE REGISTERs
 GPRs reg_file
 (
  .clk(clk),
  .reg_write_en(reg_write),
  .reg_write_dest(reg_write_dest),
  .reg_write_data(reg_write_data),
  .reg_read_addr_1(reg_read_addr_1),
  .reg_read_data_1(reg_read_data_1),
  .reg_read_addr_2(reg_read_addr_2),
  .reg_read_data_2(reg_read_data_2)
 );

 // immediate extend
 assign ext_im = {{10{instr[5]}},instr[5:0]};   //record offset for load and store. The
 // ALU control unit
 alu_control ALU_Control_unit(.ALUOp(alu_op),.Opcode(instr[15:12]),.ALU_Cnt(ALU_Control));
 // multiplexer alu_src
 assign read_data2 = (alu_src==1'b1) ? ext_im : reg_read_data_2;
 // ALU
 ALU alu_unit(.a(reg_read_data_1),.b(read_data2),.alu_control(ALU_Control),.result(ALU_out),.zero(zero_flag));
 // PC beq add
 assign PC_beq = pc2 + {ext_im[14:0],1'b0};
 assign PC_bne = pc2 + {ext_im[14:0],1'b0};
 // beq control
 assign beq_control = beq & zero_flag;
 assign bne_control = bne & (~zero_flag);
 // PC_beq
 assign PC_2beq = (beq_control==1'b1) ? PC_beq : pc2;
 // PC_bne
 assign PC_2bne = (bne_control==1'b1) ? PC_bne : PC_2beq;
 // PC_j
 assign PC_j = {pc2[15:13],jump_shift};
 // PC_next
 assign pc_next = (jump == 1'b1) ? PC_j :  PC_2bne;

 /// Data memory
  Data_Memory dm
   (
    .clk(clk),
    .mem_access_addr(ALU_out),
    .mem_write_data(reg_read_data_2),
    .mem_write_en(mem_write),
    .mem_read(mem_read),
    .mem_read_data(mem_read_data)
   );

 // write back
 assign reg_write_data = (mem_to_reg == 1'b1)?  mem_read_data: ALU_out;
 // output to control unit
 assign opcode = instr[15:12];
 assign pc_out = pc_current;
 assign alu_result = ALU_out;  
endmodule
