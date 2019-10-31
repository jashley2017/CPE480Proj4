// Single Cycle Pipelined AXA

`define WORD       [15:0]
`define IMMSIZE    [15]
`define REVERSE    [14]
`define OP_6       [15:10]
`define OP_4       [15:12]
`define SRCTYPE    [9:8]
`define DEST       [3:0]
`define SRC        [7:4]
`define SRC_8      [11:4]
`define STATE      [5:0]
`define REGSIZE    [15:0]
`define MEMSIZE    [65535:0]
`define BUFDADDR   [3:0]
`define BUFSRCTYPE [1:0]
`define BUFSRC     [3:0]
`define BUFOP      [5:0]
`define BUF16   [15:0]

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
`define INPIPE6'b111110
`define STxhi   6'b100000
`define STxlo   6'b101000
`define STlhi   6'b110000
`define STllo   6'b111000
`define OPex2   6'b111100

// src_types
`define SRC_I4   2'b01
`define SRC_REG  2'b00
`define SRC_ADDR 2'b10
`define SRC_UNDO 2'b11

// branch and jump
`define BR_TARGET [3:0]
`define J_TARGET  [15:0]

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
  

  //undo stack trickery
  wire pushpop;
  wire enable;
  reg `WORD to_pop;
  reg `WORD to_push;
  undo_stack undofile(enable,pushpop,to_push,to_pop);

  //BUFFER FIELDS FOR LOAD/DECODE OUTPUT, REGISTER READ INPUT
  reg `BUFOP op1;
  reg `BUFSRC src1;
  reg `BUFSRCTYPE srcType1;
  reg `BUFDADDR daddr1;

  //BUFFER FIELDS FOR REGISTER READ OUTPUT, MEMORY READ/WRITE INPUT
  reg `BUFOP op2;
  reg `BUFDADDR daddr2;
  reg `BUF16 srcFull2;
  reg `BUFSRCTYPE srcType2;
  reg `BUF16 destFull2;

  reg `BUFOP op3;

  //BUFFER FIELDS FOR ALU OUTPUT, REG WRITE INPUT 
  reg `BUFOP op4;
  reg `BUF16 result4;
  reg `BUFDADDR daddr4;
  reg is_zero;
  reg is_neg;
  
  //BUFFER FIELDS FOR REG WRITE OUTPUT, LOAD/DECODE INPUT
  reg branchTaken;
  reg `BR_TARGET branchTarget;
  reg jumpTaken;
  reg `J_TARGET jumpTarget;

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

  //REGISTER READ
  always @(posedge clk) begin
    destFull2 <= regfile[daddr1];
    daddr2 <= daddr1;
    srcType2 <= srcType1;
    op2 <= op1;
    case (srcType1)
      `SRC_UNDO: begin srcType2 <= undofile[src1];end
      `SRC_REG: begin srcType2 <= regfile[src1];end
      `SRC_ADDR: begin srcType2 <= regfile[src1];end
      // this is the 2's compliment conversion, I am sure it does not need to be at the bit level but I really dont like bugs.
      `SRC_I4: begin srcType2 <= src1[3] ? {12'b111111111111, (src1 ^ 4'b1111) + 4'b0001} : {12'b000000000000, src1};end
    endcase
  end

  //ALU 
  always @(posedge clk) begin
    // needed to store undobuff before write
    case (op3)
      OPadd , OPsub , OPxor , OPex  , OProl , OPshr , OPor  , OPand , OPdup : begin
        while (enable == 1)
          begin
            #1;
          end
        to_push <= destFull3;
        enable <= 1;
      end
    endcase
  end
  

  //REGISTER WRITE
  always @(posedge clk) begin
    case (op4)
      OPadd , OPsub , OPxor , OPex  , OProl , OPshr , OPor  , OPand , OPdup : begin
        daddr4 <= result4;
      end 
      // where are we pushing the pc for these?
      OPbjz: begin  bjTaken<=is_zero; end
      OPbjnz: begin bjTaken<=~is_zero;end
      OPbjn:  begin bjTaken<=is_neg;end
      OPbjnn:  begin bjTaken<=~is_neg;end
    endcase
  end


  always @(posedge clk) begin
    enable <= 0;
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


// credit to gambhirprateek on https://stackoverflow.com/questions/37916758/trying-to-implement-a-stack-in-verilog-whats-wrong-with-the-code
module undo_stack(enable,R_W,PUSH,POP);

  input enable;
  input [15:0] PUSH;
  input  R_W;
  output [15:0] POP;

  wire [15:0] PUSH;
  reg [15:0] POP;
  wire R_W;

  reg [15:0] temp[0:15];
  integer tos = 15;

  always @(posedge enable)
  if(R_W == 1 && tos != 3) begin
    POP = temp[tos];
    tos = tos + 1;
  end
  else if(R_W == 0 && tos != 0) begin
    temp[tos] = PUSH; 
    tos = tos - 1;
  end
endmodule
