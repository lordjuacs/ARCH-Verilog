// Single-cycle MIPS processor
//--------------------------------------------
module mips(input          clk, reset,
            output  [31:0] pc,
            input   [31:0] instr,
            output         memwrite,
            output  [31:0] aluout, writedata,
            input   [31:0] readdata);

  wire        memtoreg, branch,
               pcsrc, zero,
               alusrc, regdst, regwrite, jump, bne;
  wire  [2:0]  alucontrol;

  controller c(instr[31:26], instr[5:0], zero,
               memtoreg, memwrite, pcsrc,
               alusrc, regdst, regwrite, jump, bne,
               alucontrol);
  datapath dp(clk, reset, memtoreg, pcsrc,
              alusrc, regdst, regwrite, jump, bne,
              alucontrol,
              zero, pc, instr,
              aluout, writedata, readdata);
endmodule

module controller(input   [5:0] op, funct,
                  input         zero,
                  output        memtoreg, memwrite,
                  output        pcsrc, alusrc,
                  output        regdst, regwrite,
                  output        jump, bne,
                  output  [2:0] alucontrol);

  wire [1:0] aluop;
  wire       branch;

  maindec md(op, memtoreg, memwrite, branch,
             alusrc, regdst, regwrite, jump, bne,
             aluop);
  aludec  ad(funct, aluop, alucontrol);
  //Modificacion: se cambia el "pcsrc = zero & branch",
  //para que permita la instruccion de bne

  assign  pcsrc =  (~zero & bne) | (zero & branch);
endmodule

module maindec(input   [5:0] op,
               output        memtoreg, memwrite,
               output        branch, alusrc,
               output        regdst, regwrite,
               output        jump, bne,
               output  [1:0] aluop);
  //Se amplia un bit a controls, para la
  //senal de BNE
  reg [9:0] controls;

  assign {regwrite, regdst, alusrc,
          branch, memwrite,
          memtoreg, jump, aluop, bne} = controls;

  always @(*)
    case(op)
      6'b000000: controls <= 10'b1100000100; //Rtype
      6'b100011: controls <= 10'b1010010000; //LW
      6'b101011: controls <= 10'b0010100000; //SW
      6'b000100: controls <= 10'b0001000010; //BEQ
      6'b001000: controls <= 10'b1010000000; //ADDI
      6'b000010: controls <= 10'b0000001000; //J 
      6'b001101: controls <= 10'b1010000110; //ORI Controls determinados para ORI 
      6'b000101: controls <= 10'b0000000011; //BNE Controls determinados para BNE
      default:   controls <= 10'bxxxxxxxxxx; //???
    endcase
  
endmodule

module aludec(input   [5:0] funct,
              input   [1:0] aluop,
              output reg  [2:0] alucontrol);

  always @(*)
    case(aluop)
      2'b00: alucontrol <= 3'b010;  // add
      2'b01: alucontrol <= 3'b110;  // sub
      2'b11: alucontrol <= 3'b001;  // or ALUOP nuevo para instruccion OR
      default: case(funct)          // RTYPE
          6'b100000: alucontrol <= 3'b010; // ADD
          6'b100010: alucontrol <= 3'b110; // SUB
          6'b100100: alucontrol <= 3'b000; // AND
          6'b100101: alucontrol <= 3'b001; // OR
          6'b101010: alucontrol <= 3'b111; // SLT
          default:   alucontrol <= 3'bxxx; // ???
        endcase
    endcase
endmodule

module datapath(input          clk, reset,
                input          memtoreg, pcsrc,
                input          alusrc, regdst,
                input          regwrite, jump, bne,
                input   [2:0]  alucontrol,
                output         zero,
                output  [31:0] pc,
                input   [31:0] instr,
                output  [31:0] aluout, writedata,
                input   [31:0] readdata);

  wire [4:0]  writereg;
  wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  wire [31:0] signimm, signimmsh;
  wire [31:0] srca, srcb;
  wire [31:0] result;

  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(signimm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc,
                      pcnextbr);
  mux2 #(32)  pcmux(pcnextbr, {pcplus4[31:28], 
                    instr[25:0], 2'b00}, 
                    jump, pcnext);
  // register file logic
  regfile     rf(clk, regwrite, instr[25:21],
                 instr[20:16], writereg,
                 result, srca, writedata);
  mux2 #(5)   wrmux(instr[20:16], instr[15:11],
                    regdst, writereg);
  mux2 #(32)  resmux(aluout, readdata,
                     memtoreg, result);
    signext     se(instr[15:0], alucontrol, signimm);
  // ALU logic
  mux2 #(32)  srcbmux(writedata, signimm, alusrc,
                      srcb);
  //Modificación de los puertos para que coincidan
  //con nuestro ALU
  alu     alu(.a(srca), .b(srcb), .op(alucontrol),
                  .result(aluout), .cero(zero));
endmodule

