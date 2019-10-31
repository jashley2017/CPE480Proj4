// basic sizes of things
`define WORD    [15:0]
`define IMMSIZE  [15]
`define REVERSE [14]
`define OP_6 [15:10]
`define OP_4 [15:12]
`define SRCTYPE  [9:8]
`define DEST    [3:0]
`define SRC     [7:4]
`define SRC_8   [11:4]
`define STATE   [5:0]
`define REGSIZE [15:0]
`define MEMSIZE [65535:0]
`define BUFDADDR [3:0]
`define BUFSRCTYPE [1:0]
`define BUFSRC   [3:0]
`define BUFOP    [5:0]

//opcode values, also state numbers
`define OPadd   6'b000010
`define OPsub   6'b000011
`define OPxor   6'b000100
`define OPex    6'b000101
`define OProl   6'b000110
`define OPbjz   6'b001000
`define OPbjnz  6'b001001
`define OPbjn   6'b001010
`define OPbjnn  6'b001011
`define OPjerr  6'b001110
`define OPshr   6'b010001
`define OPor    6'b010010
`define OPand   6'b010011
`define OPdup   6'b010100
`define OPland  6'b010000
`define OPsys   6'b000000
`define OPcom   6'b000001
`define fail    6'b001111

//8-bit immediate instruction opcodes
`define OPxhi   4'b1000
`define OPxlo   4'b1010
`define OPlhi   4'b1100
`define OPllo   4'b1110

// state numbers only
`define Start   6'b111111
`define INPIPE	6'b111110
`define STxhi   6'b100000
`define STxlo   6'b101000
`define STlhi   6'b110000
`define STllo   6'b111000
`define OPex2   6'b111100

module processor(halt, reset, clk);
output reg halt;
input reset, clk;
reg `WORD regfile `REGSIZE;
reg `WORD datamem `MEMSIZE;
reg `WORD instmem `MEMSIZE;
reg `WORD temp;
reg `WORD pc = 0;
reg `WORD ir;
reg `STATE s;
integer i = 0;

//BUFFER FIELDS FOR STAGE 1
reg `BUFOP op1;
reg `BUFSRC src1;
reg `BUFSRCTYPE srcType1;
reg `BUFDADDR daddr1;

//RESET PROCEDURE
always @(reset) begin
  halt = 0;
  pc = 0;
  $readmemh0(regfile);
  $readmemh1(datamem);
  $readmemh2(instmem);
  for(i = 0; i < 16; i = i + 1) begin
   $dumpvars(0, regfile[i]);
  end
end

//LOAD AND DECODE STAGE
  always @(posedge clk) begin
    case (instmem[pc] `IMMSIZE)
      1: op1 <= {instmem[pc] `OP_4, 2'b00};
      default:  op1 <= instmem[pc] `OP_4;
    endcase
    src1 <= instmem[pc] `SRC;
    srcType1 <= instmem[pc] `SRCTYPE;
    daddr1 <= instmem[pc] `DEST;
    if(instmem[pc] `OP_6 == `OPsys) begin halt <= 1; end
    pc <= pc+1;
  end
endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
