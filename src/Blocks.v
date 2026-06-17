module SignExtender # (
    parameter DATA_WIDTH = 32,
    parameter BYTE = 2'b00,
    parameter HALF_WORD = 2'b01,
    parameter WORD = 2'b10
    )( input [DATA_WIDTH-1:0] DataIn,
       input [1:0] DataType,
       input SignExtd,
       output reg [DATA_WIDTH-1:0] DataOut
       );
     
     always @ (*) begin
        DataOut = 0;
        case (DataType)
            BYTE      : DataOut = SignExtd ? {{(DATA_WIDTH-8){DataIn[7]}},{DataIn[7:0]}}:
                                             {{(DATA_WIDTH-8){1'b0}},{DataIn[7:0]}};
            HALF_WORD : DataOut = SignExtd ? {{(DATA_WIDTH-16){DataIn[15]}}, DataIn[15:0]} :
                                             {{(DATA_WIDTH-16){1'b0}}, DataIn[15:0]};
            WORD      : DataOut = DataIn;
        endcase    
     end

endmodule


module ImmGen #(
    parameter DATA_WIDTH = 32,
    
    parameter [6:0]
             Rtype      = 7'b0110011,
             R_Itype    = 7'b0010011,
             Load_Itype = 7'b0000011,
             Stype      = 7'b0100011,
             Btype      = 7'b1100011,
             LUI        = 7'b0110111,
             AUIPC      = 7'b0010111,
             JAL_Jtype  = 7'b1101111,
             JALR_Itype = 7'b1100111,
             Envi_Itype = 7'b1110011
    )(
    input [24:0] ImmIn, // [24:0]ImmIn
    input [6:0] ImmInstrType,
    output reg [DATA_WIDTH-1:0] ImmOut
    );
    
    always @ (*) begin
        ImmOut = 0;
        case (ImmInstrType)
            R_Itype     : ImmOut = {{20{ImmIn[24]}},ImmIn[24:13]};
            Stype       : ImmOut = {{20{ImmIn[24]}},ImmIn[24:18],ImmIn[4:0]};
            Btype       : ImmOut = {{19{ImmIn[24]}},ImmIn[24],ImmIn[0],ImmIn[23:18],ImmIn[4:1],1'b0};
            JAL_Jtype   : ImmOut = {{11{ImmIn[24]}},ImmIn[24],ImmIn[12:5],ImmIn[13],ImmIn[23:14],1'b0};
            LUI         : ImmOut = {ImmIn[24:5],12'b0};
        endcase
        end
endmodule


module Controller(
//input structure : funct7[16:10]|funct3[9:7]|opcode[6:0]
    input [16:0] ControlKey,
    input ALUOutLSB,
    output reg SelAdderPC, SelDataInPC, RegBankWEn, 
               SelMuxALU, SelMuxALU0, SignExtd,DataMemWEn,
    output reg [1:0] DataMemWDataType, SelRegBankDataIn,
    output reg [1:0] DataMemRDataType,
    output reg [6:0] ImmInstrType,
    output reg [3:0] ALUSelFunc
    );
    // ALU Parameters
    parameter ADD = 4'b0000, SUB = 4'b0001;     // Arithmetic 
    parameter XOR = 4'b0010, OR = 4'b0011, AND = 4'b0100;  // Logical
    parameter SLL = 4'b0101, SRL = 4'b0110, SRA = 4'b0111; // Shifts
    parameter S_LT = 4'b1000, U_LT = 4'b1001;   // Signed/Unsigned Less than
    parameter B_EQ = 4'b1010, B_NEQ = 4'b1011,  B_GEQU = 4'b1100,B_GEQ = 4'b1101;  // Boolean == | != | >= 
 
    //Data Length parameters
    parameter BYTE = 2'b00;
    parameter HALF_WORD = 2'b01;
    parameter WORD = 2'b10;

    // OPCODE parameters
    parameter [6:0]
             Rtype      = 7'b0110011,
             R_Itype    = 7'b0010011,
             Load_Itype = 7'b0000011,
             Stype      = 7'b0100011,
             Btype      = 7'b1100011,
             LUI        = 7'b0110111,
             AUIPC      = 7'b0010111,
             JAL_Jtype  = 7'b1101111,
             JALR_Itype = 7'b1100111,
             Envi_Itype = 7'b1110011;
            
    parameter [6:0]                     
             SUB_SRA = 7'b0100000,    //funct7 parameters R type    
             
             R_I_SRL = 7'b0000000,  // funct7 parameters for R_I type
             R_I_SRA = 7'b0100000,
             
             ZERO = 7'b0;               
             
    // funct 3 code below R-type and R_I type   //These are for Load_Itype      // These are for Stype
    parameter [2:0] 
             F3_ADD_SUB = 3'b000,               F3_LB  = 3'b000,                F3_SB  = 3'b000,               
             F3_XOR     = 3'b100, /*logical*/   F3_LH  = 3'b001,                F3_SH  = 3'b001,
             F3_OR      = 3'b110,               F3_LW  = 3'b010,                F3_SW  = 3'b010,
             F3_AND     = 3'b111,               F3_LBU = 3'b100,
             F3_SLL     = 3'b001, /*shifts*/    F3_LHU = 3'b101,
             F3_SRL_SRA = 3'b101, 
             F3_SLT     = 3'b010, // comparison
             F3_SLTU    = 3'b011,
             // funct 3 codes for branch
             F3_BEQ = 3'b000, F3_BNE = 3'b001, F3_BLT = 3'b100,  
             F3_BGE = 3'b101, F3_BLTU = 3'b110, F3_BGEU = 3'b111;  
    wire [6:0] funct7;
    wire [2:0] funct3;
    wire [6:0] opcode;
    
    assign {funct7,funct3,opcode} = ControlKey;
 
    always @ (*) begin
        SelAdderPC  = 1'b0; 
        SelDataInPC = 1'b0; 
        RegBankWEn  = 1'b0;
        SelMuxALU   = 1'b0;
        SelMuxALU0  = 1'b0;
        SignExtd    = 1'b0;
        SelRegBankDataIn = 2'b0;
        DataMemWEn = 1'b0;
        DataMemRDataType = 2'b0;
        DataMemWDataType = 2'b0;
        ALUSelFunc  = 4'b0000;
        ImmInstrType = 7'b0;
        case (opcode)
           Rtype : begin RegBankWEn = 1'b1;
                    case(funct7)
                          SUB_SRA : case (funct3)
                                        F3_SRL_SRA : ALUSelFunc = SRA;
                                        F3_ADD_SUB : ALUSelFunc = SUB;
                                        default    : ALUSelFunc = 4'b1111;
                                    endcase
                          ZERO    : case (funct3)
                                         F3_ADD_SUB : ALUSelFunc = ADD; 
                                         F3_XOR     : ALUSelFunc = XOR;
                                         F3_OR      : ALUSelFunc = OR;
                                         F3_AND     : ALUSelFunc = AND;
                                         F3_SLL     : ALUSelFunc = SLL;
                                         F3_SRL_SRA : ALUSelFunc = SRL;
                                         F3_SLT     : ALUSelFunc = S_LT;
                                         F3_SLTU    : ALUSelFunc = U_LT;
                                        default    : ALUSelFunc = 4'b1111;
                                    endcase
                          default : ALUSelFunc = 4'b1111; // illegal funct7
                    endcase 
                    end

           R_Itype : begin RegBankWEn = 1'b1; SelMuxALU = 1'b1; ImmInstrType = R_Itype;
                    case(funct3)
                       F3_ADD_SUB : ALUSelFunc = ADD; 
                       F3_XOR     : ALUSelFunc = XOR;
                       F3_OR      : ALUSelFunc = OR;
                       F3_AND     : ALUSelFunc = AND;
                       F3_SLL     : ALUSelFunc = SLL;
                       F3_SRL_SRA : case (funct7)
                                        R_I_SRL : ALUSelFunc = SRL;
                                        R_I_SRA : ALUSelFunc = SRA;
                                        default : ALUSelFunc = 4'b1111;
                                    endcase    
                       F3_SLT     : ALUSelFunc = S_LT;
                       F3_SLTU    : ALUSelFunc = U_LT;
                       default    : ALUSelFunc = 4'b1111;
                     endcase
                     end
        Load_Itype : begin RegBankWEn = 1'b1; SelMuxALU = 1'b1; 
                     ImmInstrType = R_Itype; SelRegBankDataIn=2'b01;
                     ALUSelFunc = ADD;
                    case(funct3)
                           F3_LB  :begin SignExtd = 1'b1 ; DataMemRDataType = BYTE; end
                           F3_LH  :begin SignExtd = 1'b1 ; DataMemRDataType = HALF_WORD; end
                           F3_LW  :begin SignExtd = 1'b1 ; DataMemRDataType = WORD; end
                           F3_LBU :begin SignExtd = 1'b0 ; DataMemRDataType = BYTE; end
                           F3_LHU :begin SignExtd = 1'b0 ; DataMemRDataType = HALF_WORD; end
                     endcase
                    end
        Stype : begin SelMuxALU = 1'b1; DataMemWEn = 1'b1;
                     ImmInstrType = Stype; 
                     ALUSelFunc = ADD;
                    case(funct3)
                           F3_SB  :begin DataMemWDataType = BYTE; end
                           F3_SH  :begin DataMemWDataType = HALF_WORD; end
                           F3_SW  :begin DataMemWDataType = WORD; end
                     endcase
                    end
        Btype : begin ImmInstrType = Btype;
                    case(funct3)
                           F3_BEQ   :begin ALUSelFunc = B_EQ; end
                           F3_BNE   :begin ALUSelFunc = B_NEQ; end
                           F3_BLT   :begin ALUSelFunc = S_LT; end
                           F3_BGE   :begin ALUSelFunc = B_GEQ; end
                           F3_BLTU  :begin ALUSelFunc = U_LT; end
                           F3_BGEU   :begin ALUSelFunc = B_GEQU; end
                     endcase
                    SelAdderPC = (ALUOutLSB == 1)? 1'b1 : 1'b0; 
                    end
        JAL_Jtype : begin RegBankWEn = 1'b1; ImmInstrType = JAL_Jtype;
                          SelRegBankDataIn = 2'b10; SelAdderPC = 1'b1;
                    end
        JALR_Itype : begin RegBankWEn = 1'b1; ImmInstrType = R_Itype;    //JALR target alignment masking and exception handling have not been implemented.
                          SelRegBankDataIn = 2'b10; SelDataInPC = 1'b1;  //The processor assumes software generates aligned jump targets.
                          ALUSelFunc = ADD; SelMuxALU = 1'b1;
                    end
        LUI : begin RegBankWEn = 1'b1; ImmInstrType = LUI;    
                          SelRegBankDataIn = 2'b11;
                    end
        AUIPC : begin ImmInstrType = LUI;  SelMuxALU0=1'b1;
                      RegBankWEn = 1'b1; SelRegBankDataIn = 2'b00; 
                      ALUSelFunc = ADD; SelMuxALU = 1'b1;
                    end
       endcase
    end
                                    
endmodule

module InstrDecoder #(
    parameter FUNC_WIDTH = 17,
    // Opcode parameters
    parameter [6:0]
            Rtype = 7'b0110011,
          R_Itype = 7'b0010011,
       Load_Itype = 7'b0000011,
            Stype = 7'b0100011,
            Btype = 7'b1100011,
            LUI   = 7'b0110111,
            AUIPC = 7'b0010111,
      JAL_Jtype   = 7'b1101111,
      JALR_Itype  = 7'b1100111,
      Envi_Itype  = 7'b1110011, 
    // funct 3 code below R-type+R_Itype
    parameter [2:0] 
            ADD_SUB = 3'b000,
            XOR     = 3'b100, // logical
             OR     = 3'b110,
            AND     = 3'b111,
            SLL     = 3'b001, // shifts
            SRL_SRA = 3'b101,
            SLT     = 3'b010, // comparison
            SLTU    = 3'b011,
     // funct 7 codes below R-type 
     parameter [6:0]
            SUB_SRA = 7'b0100000,
            ZERO = 7'b0
    )(input [FUNC_WIDTH-1:0] InstrCodes,
      // funct7[16:10|7]|funct3[9:7|3]|opcode[6:0|7]
      output reg [FUNC_WIDTH-1:0] ControlKey
      );
       
    always @ (*) begin
        ControlKey = 17'b0;
        case(InstrCodes[6:0])
            Rtype       : ControlKey = InstrCodes;
            R_Itype     : ControlKey = InstrCodes;
            Load_Itype  : ControlKey = {7'b0,InstrCodes[9:0]};
            Stype       : ControlKey = {7'b0,InstrCodes[9:0]};
            Btype       : ControlKey = {7'b0,InstrCodes[9:0]};
            JAL_Jtype   : ControlKey = {10'b0,InstrCodes[6:0]};
            JALR_Itype  : ControlKey = {10'b0,InstrCodes[6:0]};
            LUI         : ControlKey = {10'b0,InstrCodes[6:0]};
            AUIPC       : ControlKey = {10'b0,InstrCodes[6:0]};
        endcase
    end    
endmodule    
      
      
module ALU #(
    parameter DATA_WIDTH = 32,
    parameter FN_COUNT = 4, // 13 operations in ALU
                            // 4 bits can fit upto 16.  
    
    parameter ADD = 4'b0000, SUB = 4'b0001,     // Arithmetic 
    parameter XOR = 4'b0010, OR = 4'b0011, AND = 4'b0100,  // Logical
    parameter SLL = 4'b0101, SRL = 4'b0110, SRA = 4'b0111, // Shifts
    parameter S_LT = 4'b1000, U_LT = 4'b1001,   // Signed/Unsigned Less than
    parameter B_EQ = 4'b1010, B_NEQ = 4'b1011,  B_GEQU = 4'b1100,B_GEQ = 4'b1101 // Boolean == | != | >= 
                                          
    )( input [DATA_WIDTH-1:0] DataIn1, DataIn2,
       input [FN_COUNT-1:0] SelFunc,
       output reg [DATA_WIDTH-1:0] DataOut
       );
       
    always @ (*) begin
        DataOut = 0;
        case(SelFunc)  
            ADD      :  DataOut = DataIn1 + DataIn2;
            SUB      :  DataOut = DataIn1 - DataIn2;
            
            XOR      :  DataOut = DataIn1 ^ DataIn2;
            OR       :  DataOut = DataIn1 | DataIn2;
            AND      :  DataOut = DataIn1 & DataIn2;
            
            SLL      :  DataOut = DataIn1 << DataIn2[4:0];    // RV32I spec: shift amount is only lower 5 bits
            SRL      :  DataOut = DataIn1 >> DataIn2[4:0];
            SRA      :  DataOut = $signed(DataIn1) >>> DataIn2[4:0]; // $signed ensures MSB is copied. 
            
            S_LT     :  DataOut = {31'b0,$signed(DataIn1) < $signed(DataIn2)};
            U_LT     :  DataOut = {31'b0,DataIn1 < DataIn2};
            
            B_EQ     :  DataOut = {31'b0,(DataIn1 == DataIn2)}; // i think these o/p would act as control signals
            B_NEQ    :  DataOut = {31'b0,(DataIn1 != DataIn2)}; // in the PC = PC + imm mux select in PC Block
            B_GEQU   :  DataOut = {31'b0,(DataIn1 >= DataIn2)}; //
            B_GEQ    :  DataOut = {31'b0,($signed(DataIn1) >= $signed(DataIn2))}; //
            

        endcase
        end      
endmodule


module RegBank32 #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 5
    )(input [DATA_WIDTH-1:0] DataIn,
      input Clk, Rst, WEn,
      input [REG_ADDR_WIDTH-1:0]RAddr1, RAddr2, WAddr,
      output [DATA_WIDTH-1:0] DataOut1 , DataOut2
      );
      
    reg [DATA_WIDTH-1:0] mem [0:2**(REG_ADDR_WIDTH)-1];
    
    integer i;
    
    always @ (posedge Clk) begin
        if (Rst) begin
            for (i = 0; i < 2**REG_ADDR_WIDTH; i = i + 1) begin
                mem[i] <= 32'b0;
                end
        end
        else if (WEn && (WAddr != 5'b0)) begin
            mem[WAddr] <= DataIn;
            end
    end
    
//    initial begin
//        $readmemh("regdata.mem",mem);
//        end
    
    assign DataOut1 = mem[RAddr1];
    assign DataOut2 = mem[RAddr2];
    
endmodule
            

module PCBlock#(
   parameter DATA_WIDTH = 8
    )(
    input SelAdderPC,SelDataInPC,
    input Clk,Rst,
    input [DATA_WIDTH-1:0] Immediate,
    input [DATA_WIDTH-1:0] MainALUData,
    output [DATA_WIDTH-1:0] PCnext,
    output [DATA_WIDTH-1:0] AddrOutPC
    );
    
    wire [DATA_WIDTH-1:0] temp_adder_0,temp_adder_1;
    wire [DATA_WIDTH-1:0] temp_mux1_mux2;
    wire [DATA_WIDTH-1:0] temp_mux2_pc;
    
    mux2to1 #(.DATA_WIDTH(DATA_WIDTH)) M0
             (.DataIn0(temp_adder_0),.DataIn1(temp_adder_1),
              .Sel(SelAdderPC),.DataOut(temp_mux1_mux2));
                 
    PCAdder  #(.DATA_WIDTH(DATA_WIDTH)) ADDImm
              (.DataIn0(Immediate),.DataIn1(AddrOutPC),
               .AddrOutPC(temp_adder_1));
    
    PCAdder  #(.DATA_WIDTH(DATA_WIDTH)) ADD4
              (.DataIn0(8'b0000_0100),.DataIn1(AddrOutPC),
               .AddrOutPC(temp_adder_0));
    
    assign PCnext = temp_adder_0;
    
    mux2to1 #(.DATA_WIDTH(DATA_WIDTH)) M1
             (.DataIn0(temp_mux1_mux2),.DataIn1(MainALUData),
              .Sel(SelDataInPC),.DataOut(temp_mux2_pc));
     
    ProgCounter #(.DATA_WIDTH(DATA_WIDTH)) PC
                  (.DataInPC(temp_mux2_pc),
                    .Clk(Clk),.Rst(Rst),
                    .AddrOutPC(AddrOutPC));         
    
endmodule

module ByteAdrRAM #(
 

    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter BYTE = 2'b00,
    parameter HALF_WORD = 2'b01,
    parameter WORD = 2'b10
    )(
    input [DATA_WIDTH-1:0] DataIn,
    input Clk, WEn,
    input [1:0] WDataType,RDataType,
    input [ADDR_WIDTH-1:0] WAddr, RAddr,
    output [DATA_WIDTH-1:0] DataOut
    );
    // 000000_00   000000_01   000000_10   000000_11
    // 000001_00   000001_01   000001_10   000001_11
    // 000010_00   000010_01   000010_10   000010_11
    // 000011_00   000011_01   000011_10   000011_11
    // 000100_00   000100_01   000100_10   000100_11
    // 0  0  0  1  0  0  1  0 
    // 7  6  5  4  3  2  1  0
    
    // WHAT HAPPENS IF HALF_WORD AND WORD DEMAND END ADDRESS? i.e. 
    // WHAT DO TO IF WORD TYPE DEMANDS CONTENTS AT ADDR 1111_1111? 
    // - As of now I leave this responsibility to the programmer.
    
    // Haven't included sign-extension in the memory itself.
    wire [DATA_WIDTH-1:0] temp_route_cell; // Wires b/w write router and RAM cells
    wire [DATA_WIDTH-1:0] temp_cell_out;   // Wires b/w RAM cells and read router
    wire [3:0] temp_cell_wen;              // WEn signal from input port goes to write router
    wire [5:0] temp_waddr [0:3];           // Addresses passed by Write router to RAM cells
    wire [5:0] temp_raddr [0:3];           // Addresses passed by Read router to RAM cells
    
    WDataRouter WDR (.DataIn(DataIn),.WDataType(WDataType),
                     .WEn(WEn),.WAddr(WAddr),.DataOut(temp_route_cell),.CellWEn(temp_cell_wen),
                     .WAddr0(temp_waddr[0]),.WAddr1(temp_waddr[1]),
                     .WAddr2(temp_waddr[2]),.WAddr3(temp_waddr[3]));
    
    ByteRAM RAM0  (.DataIn(temp_route_cell[7:0]),.Clk(Clk),.WEn(temp_cell_wen[0]),
                   .WAddr(temp_waddr[0]),.RAddr(temp_raddr[0]),.DataOut(temp_cell_out[7:0]));
                   
    ByteRAM RAM1  (.DataIn(temp_route_cell[15:8]),.Clk(Clk),.WEn(temp_cell_wen[1]),
                   .WAddr(temp_waddr[1]),.RAddr(temp_raddr[1]),.DataOut(temp_cell_out[15:8]));
                   
    ByteRAM RAM2  (.DataIn(temp_route_cell[23:16]),.Clk(Clk),.WEn(temp_cell_wen[2]),
                   .WAddr(temp_waddr[2]),.RAddr(temp_raddr[2]),.DataOut(temp_cell_out[23:16]));
                   
    ByteRAM RAM3  (.DataIn(temp_route_cell[31:24]),.Clk(Clk),.WEn(temp_cell_wen[3]),
                   .WAddr(temp_waddr[3]),.RAddr(temp_raddr[3]),.DataOut(temp_cell_out[31:24]));
                   
    RDataRouter RDR (.DataIn0(temp_cell_out[7:0]),.DataIn1(temp_cell_out[15:8]),
                     .DataIn2(temp_cell_out[23:16]),.DataIn3(temp_cell_out[31:24]),
                     .RDataType(RDataType),.RAddr(RAddr),.DataOut(DataOut),
                     .RAddr0(temp_raddr[0]),.RAddr1(temp_raddr[1]),
                     .RAddr2(temp_raddr[2]),.RAddr3(temp_raddr[3]));

endmodule

