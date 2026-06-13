module DataPath #(
    parameter DATA_WIDTH=32,
    parameter PC_DATA_WIDTH=8,
    parameter BYTE = 2'b00,
    parameter HALF_WORD = 2'b01,
    parameter WORD = 2'b10,
    parameter FUNC_WIDTH = 17
    )(
    input Clk, Rst,
    output [DATA_WIDTH-1:0] DataOut
    );
    
    wire [PC_DATA_WIDTH-1:0] PC_RAddr;
    wire [DATA_WIDTH-1:0] IM_Instr; // the entire instruction
    wire [FUNC_WIDTH-1:0] ID_ControlKey;
    
    wire CTRL_SelAdderPC;
    wire CTRL_SelDataInPC;
    wire CTRL_RegBankWEn;
    wire [3:0] CTRL_ALUSelFunc;
    
    wire [DATA_WIDTH-1:0] ALU_DataOut;
    
    wire [DATA_WIDTH-1:0] RB_DataOut1;
    wire [DATA_WIDTH-1:0] RB_DataOut2;
    
    PCBlock PC (.SelAdderPC(CTRL_SelAdderPC),
                .SelDataInPC(CTRL_SelDataInPC),
                .Clk(Clk),
                .Rst(Rst), 
                .Immediate(0),   // don't need these two as of now 
                .MainALUData(0),
                .AddrOutPC(PC_RAddr));
    
    ByteAdrRAM IM (.DataIn(),  // loading from a .mem file so no need
                    .Clk(Clk),
                    .WEn(),
                    .WDataType(),
                    .RDataType(WORD),
                    .WAddr(),
                    .RAddr(PC_RAddr),
                    .DataOut(IM_Instr));
                    
     InstrDecoder ID (.InstrCodes({IM_Instr[31:25], //F7|F3|OP
                                   IM_Instr[14:12],
                                   IM_Instr[6:0]}),
                      .ControlKey(ID_ControlKey));   
                      
     Controller CTRL (.ControlKey(ID_ControlKey),
                      .SelAdderPC(CTRL_SelAdderPC),
                      .SelDataInPC(CTRL_SelDataInPC),
                      .RegBankWEn(CTRL_RegBankWEn),
                      .ALUSelFunc(CTRL_ALUSelFunc));         
                      
     ALU ALU_UUT (.DataIn1(RB_DataOut1),
                  .DataIn2(RB_DataOut2),
                  .SelFunc(CTRL_ALUSelFunc),
                  .DataOut(ALU_DataOut));
                      

     RegBank32 RB (.DataIn(ALU_DataOut),
                   .Clk(Clk),
                   .Rst(1'b0), // i will preload data using .mem file so don't need this
                   .WEn(CTRL_RegBankWEn),
                   .RAddr1(IM_Instr[19:15]),
                   .RAddr2(IM_Instr[24:20]),
                   .WAddr(IM_Instr[11:7]),
                   .DataOut1(RB_DataOut1),
                   .DataOut2(RB_DataOut2));
    
    assign DataOut = ALU_DataOut; // to generate RTL schematic
    
endmodule


