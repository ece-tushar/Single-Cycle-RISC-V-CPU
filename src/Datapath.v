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
    wire [PC_DATA_WIDTH-1:0] PC_PCnext;
    
    wire [DATA_WIDTH-1:0] IM_Instr; // the entire instruction
    
    wire [FUNC_WIDTH-1:0] ID_ControlKey;

    wire CTRL_SelAdderPC;
    wire CTRL_SelDataInPC;
    wire CTRL_RegBankWEn;   
    wire CTRL_DataMemWEn;   
    wire CTRL_SelMuxALU;
    wire CTRL_SelMuxALU0;
    wire CTRL_SignExtd;
    wire CTRL_SelPCnextRB;
    wire [6:0] CTRL_ImmInstrType;
    wire [3:0] CTRL_ALUSelFunc;
    wire [1:0] CTRL_DataMemRDataType;
    wire [1:0] CTRL_DataMemWDataType;
    wire [1:0] CTRL_SelRegBankDataIn;


    wire [DATA_WIDTH-1:0] ALU_DataOut;

    wire [DATA_WIDTH-1:0] RB_DataOut1;
    wire [DATA_WIDTH-1:0] RB_DataOut2;

    wire [DATA_WIDTH-1:0] IG_ImmOut;

    wire [DATA_WIDTH-1:0] MUX_ALU_DataOut;
    wire [DATA_WIDTH-1:0] MUX_ALU_DataOut0;

    wire [DATA_WIDTH-1:0] DM_DataOut;

    wire [DATA_WIDTH-1:0] SE_DataOut;

    wire [DATA_WIDTH-1:0] MUX_RB_DataOut;
    
    
    
     PCBlock PC (.SelAdderPC(CTRL_SelAdderPC),
                 .SelDataInPC(CTRL_SelDataInPC),
                 .Clk(Clk),
                 .Rst(Rst), 
                 .Immediate(IG_ImmOut[7:0]),   
                 .PCnext(PC_PCnext),
                 .MainALUData(ALU_DataOut[7:0]),
                 .AddrOutPC(PC_RAddr));
    
     ByteAdrRAM IM (.DataIn(),  // loading from a .mem file so no need
                    .Clk(Clk),
                    .WEn(0),
                    .WDataType(),
                    .RDataType(WORD),
                    .WAddr(),
                    .RAddr(PC_RAddr),
                    .DataOut(IM_Instr));
                    
     ByteAdrRAM DM (.DataIn(RB_DataOut2),  
               .Clk(Clk),
               .WEn(CTRL_DataMemWEn),
               .WDataType(CTRL_DataMemWDataType),
               .RDataType(CTRL_DataMemRDataType),
               .WAddr(ALU_DataOut[7:0]),
               .RAddr(ALU_DataOut[7:0]),
               .DataOut(DM_DataOut));
 
     SignExtender SE (.DataIn(DM_DataOut),
                   .DataType(CTRL_DataMemRDataType),
                   .SignExtd(CTRL_SignExtd),
                   .DataOut(SE_DataOut)); 

     ImmGen       IG (.ImmIn(IM_Instr[31:7]),
                 .ImmInstrType(CTRL_ImmInstrType),
                 .ImmOut(IG_ImmOut)
                 );
 
     InstrDecoder ID (.InstrCodes({IM_Instr[31:25], //F7|F3|OP
                              IM_Instr[14:12],
                              IM_Instr[6:0]}),
                 .ControlKey(ID_ControlKey));   
     

     Controller CTRL (.ControlKey(ID_ControlKey),
                 .ALUOutLSB(ALU_DataOut[0]),
                 .SelAdderPC(CTRL_SelAdderPC),
                 .SelDataInPC(CTRL_SelDataInPC),
                 .RegBankWEn(CTRL_RegBankWEn),
                 .SelMuxALU(CTRL_SelMuxALU),
                 .SelMuxALU0(CTRL_SelMuxALU0),
                 .SignExtd(CTRL_SignExtd), 
                 .SelRegBankDataIn(CTRL_SelRegBankDataIn),
                 .DataMemWEn(CTRL_DataMemWEn),
                 .DataMemRDataType(CTRL_DataMemRDataType),
                 .DataMemWDataType(CTRL_DataMemWDataType),
                 .ImmInstrType(CTRL_ImmInstrType),
                 .ALUSelFunc(CTRL_ALUSelFunc));         

     mux2to1 # (.DATA_WIDTH(32)) 
    MUX_ALU0 (.DataIn0(RB_DataOut1),
           .DataIn1({{(DATA_WIDTH-PC_DATA_WIDTH){1'b0}},PC_RAddr}),
           .Sel(CTRL_SelMuxALU0),
           .DataOut(MUX_ALU_DataOut0));
           
     mux2to1 # (.DATA_WIDTH(32)) 
    MUX_ALU (.DataIn0(RB_DataOut2),
           .DataIn1(IG_ImmOut),
           .Sel(CTRL_SelMuxALU),
           .DataOut(MUX_ALU_DataOut));
                      
     ALU ALU_UUT (.DataIn1(MUX_ALU_DataOut0),
                  .DataIn2(MUX_ALU_DataOut),
                  .SelFunc(CTRL_ALUSelFunc),
                  .DataOut(ALU_DataOut));
      
                 
    mux4to1 #(.DATA_WIDTH(32))         // write back n/w
            MUX_RB (.DataIn0(ALU_DataOut),
                     .DataIn1(SE_DataOut),
                     .DataIn2({{(DATA_WIDTH-PC_DATA_WIDTH){1'b0}}, PC_PCnext}),
                     .DataIn3(IG_ImmOut),
                     .Sel(CTRL_SelRegBankDataIn),
                     .DataOut(MUX_RB_DataOut));
                
     RegBank32 RB (.DataIn(MUX_RB_DataOut),
                   .Clk(Clk),
                   .Rst(Rst), 
                   .WEn(CTRL_RegBankWEn),
                   .RAddr1(IM_Instr[19:15]),
                   .RAddr2(IM_Instr[24:20]),
                   .WAddr(IM_Instr[11:7]),
                   .DataOut1(RB_DataOut1),
                   .DataOut2(RB_DataOut2));
                
      assign DataOut = ALU_DataOut; // to generate RTL schematic
    
endmodule



