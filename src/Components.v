module PCAdder#(
    parameter DATA_WIDTH = 8 
    )(input [DATA_WIDTH-1:0] DataIn0,
      input [DATA_WIDTH-1:0] DataIn1,
      output [DATA_WIDTH-1:0] AddrOutPC
      );
      
    assign AddrOutPC = DataIn0 + DataIn1;
     
endmodule


module ProgCounter#(
    parameter DATA_WIDTH = 8
    )(input [DATA_WIDTH-1:0] DataInPC,
      input Clk,Rst,
      output [DATA_WIDTH-1:0] AddrOutPC
      );
      
      reg [DATA_WIDTH-1:0] mem;
      
      always @ (posedge Clk)
        if (Rst) begin
            mem <= 8'b0;
        end
        else begin
            mem <= DataInPC;
        end
     
     assign AddrOutPC = mem;
     
endmodule

module mux2to1 #(
    parameter DATA_WIDTH = 8
    )(input [DATA_WIDTH-1:0] DataIn0,
      input [DATA_WIDTH-1:0] DataIn1,
      input Sel,
      output reg [DATA_WIDTH-1:0] DataOut
      );
      
      always @ (*)begin
      if (Sel)
        DataOut = DataIn1;
      else 
        DataOut = DataIn0;
      end
endmodule

module mux4to1 #(
    parameter DATA_WIDTH = 8
    )(input [DATA_WIDTH-1:0] DataIn0,
      input [DATA_WIDTH-1:0] DataIn1,
      input [DATA_WIDTH-1:0] DataIn2,
      input [DATA_WIDTH-1:0] DataIn3,
      input [1:0] Sel,
      output reg [DATA_WIDTH-1:0] DataOut
      );
      
      always @ (*)begin
        case(Sel)
            2'b00 :DataOut = DataIn0;
            2'b01 :DataOut = DataIn1;
            2'b10 :DataOut = DataIn2;
            2'b11 :DataOut = DataIn3;
        endcase
        end
endmodule
    
    


module WDataRouter #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter BYTE = 2'b00,
    parameter HALF_WORD = 2'b01,
    parameter WORD = 2'b10
    )(
    input [DATA_WIDTH-1:0] DataIn,
    input [1:0] WDataType,
    input WEn,
    input [ADDR_WIDTH-1:0] WAddr,
    output reg [DATA_WIDTH-1:0] DataOut,
    output reg [3:0] CellWEn,
    output reg [5:0] WAddr0,WAddr1,WAddr2,WAddr3
    );
          
    // DATAOUT --> [CELL3,CELL2,CELL1,CELL0]      
     
          
    always @ (*) begin
    WAddr0 = WAddr[7:2];WAddr1 = WAddr[7:2];
    WAddr2 = WAddr[7:2];WAddr3 = WAddr[7:2];

    if (WEn) begin
        case (WDataType)
            BYTE : case (WAddr[1:0])  //  DataIn = 32'h0000_00XX
                            2'b00 : begin DataOut = {8'b0,8'b0,8'b0,DataIn[0+:8]}; CellWEn = 4'b0001; end
                            2'b01 : begin DataOut = {8'b0,8'b0,DataIn[0+:8],8'b0}; CellWEn = 4'b0010; end
                            2'b10 : begin DataOut = {8'b0,DataIn[0+:8],8'b0,8'b0}; CellWEn = 4'b0100; end
                            2'b11 : begin DataOut = {DataIn[0+:8],8'b0,8'b0,8'b0}; CellWEn = 4'b1000; end
                            default : begin DataOut = 32'b0; CellWEn = 4'b0000; end
                   endcase
        HALF_WORD : case (WAddr[1:0]) //  DataIn = 32'h0000_XXXX
                            2'b00 : begin DataOut = {8'b0,8'b0,DataIn[8+:8],DataIn[0+:8]}; CellWEn = 4'b0011; end
                            2'b01 : begin DataOut = {8'b0,DataIn[8+:8],DataIn[0+:8],8'b0}; CellWEn = 4'b0110; end
                            2'b10 : begin DataOut = {DataIn[8+:8],DataIn[0+:8],8'b0,8'b0}; CellWEn = 4'b1100; end
                            // Below is for wrap around in cell crossing case
                            2'b11 : begin DataOut = {DataIn[0+:8],8'b0,8'b0,DataIn[8+:8]}; 
                                                     WAddr0 = WAddr0 + 1;   CellWEn = 4'b1001; end
                                                     
                            default : begin DataOut = 32'b0; CellWEn = 4'b0000; end
                   endcase
            WORD : case (WAddr[1:0])
                            2'b00 : begin DataOut = {DataIn[24+:8],DataIn[16+:8],
                                                     DataIn[8+:8],DataIn[0+:8]}; CellWEn = 4'b1111; end
                                                      
                            2'b01 : begin DataOut = {DataIn[16+:8],DataIn[8+:8],
                                                     DataIn[0+:8],DataIn[24+:8]}; 
                                                     WAddr0 = WAddr0 + 1; CellWEn = 4'b1111; end
                                                     
                            2'b10 : begin DataOut = {DataIn[8+:8],DataIn[0+:8],
                                                     DataIn[24+:8],DataIn[16+:8]}; 
                                                     WAddr0 = WAddr0 + 1;
                                                     WAddr1 = WAddr1 + 1;CellWEn = 4'b1111; end
                                                     
                            2'b11 : begin DataOut = {DataIn[0+:8],DataIn[24+:8],
                                                     DataIn[16+:8],DataIn[8+:8]}; 
                                                     WAddr0 = WAddr0 + 1;
                                                     WAddr1 = WAddr1 + 1;
                                                     WAddr2 = WAddr2 + 1;CellWEn = 4'b1111; end
                            default : begin DataOut = 32'b0; CellWEn = 4'b0000; end
                   endcase
            default : begin DataOut = 32'b0; CellWEn = 4'b0000; end
       endcase
       end
       
       else begin
             DataOut = 32'b0; CellWEn = 4'b0000; 
            end
   end
   
endmodule

module RDataRouter #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter BYTE = 2'b00,
    parameter HALF_WORD = 2'b01,
    parameter WORD = 2'b10
    )(
    input [ADDR_WIDTH-1:0] DataIn0,
    input [ADDR_WIDTH-1:0] DataIn1,
    input [ADDR_WIDTH-1:0] DataIn2,
    input [ADDR_WIDTH-1:0] DataIn3,
    input [1:0] RDataType,
    input [ADDR_WIDTH-1:0] RAddr,
    output reg [DATA_WIDTH-1:0] DataOut,
    output reg [5:0] RAddr0,RAddr1,RAddr2,RAddr3
    );
    

    always @ (*) begin
    RAddr0 = RAddr[7:2];RAddr1 = RAddr[7:2];
    RAddr2 = RAddr[7:2];RAddr3 = RAddr[7:2];
        case (RDataType)
            BYTE : case (RAddr[1:0])
                            2'b00 : DataOut = {8'b0,8'b0,8'b0,DataIn0};
                            2'b01 : DataOut = {8'b0,8'b0,8'b0,DataIn1};
                            2'b10 : DataOut = {8'b0,8'b0,8'b0,DataIn2};
                            2'b11 : DataOut = {8'b0,8'b0,8'b0,DataIn3};
                            default : DataOut = 32'b0;
                   endcase
        HALF_WORD : case (RAddr[1:0])
                            2'b00 : DataOut = {8'b0,8'b0,DataIn1,DataIn0};
                            2'b01 : DataOut = {8'b0,8'b0,DataIn2,DataIn1};
                            2'b10 : DataOut = {8'b0,8'b0,DataIn3,DataIn2};
                            2'b11 : begin DataOut = {8'b0,8'b0,DataIn0,DataIn3}; 
                                          RAddr0 = RAddr0 + 1; end
                                            
                            default : DataOut = 32'b0;
                   endcase
            WORD : case (RAddr[1:0])
                            2'b00 : DataOut ={DataIn3,DataIn2,DataIn1,DataIn0};
                            2'b01 : begin DataOut ={DataIn0,DataIn3,DataIn2,DataIn1};
                                    RAddr0 = RAddr0 + 1; end
                                    
                            2'b10 : begin DataOut ={DataIn1,DataIn0,DataIn3,DataIn2};
                                    RAddr0 = RAddr0 + 1;
                                    RAddr1 = RAddr1 + 1; end
                            2'b11 : begin DataOut ={DataIn2,DataIn1,DataIn0,DataIn3};
                                    RAddr0 = RAddr0 + 1;
                                    RAddr1 = RAddr1 + 1;
                                    RAddr2 = RAddr2 + 1; end
                            default : DataOut = 32'b0;
                   endcase
            default : DataOut = 32'b0;
       endcase
   end
   
endmodule

module ByteRAM #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
    )(
    input [DATA_WIDTH-1:0] DataIn,
    input Clk, WEn, 
    input [ADDR_WIDTH-1:0] WAddr, RAddr,
    output [DATA_WIDTH-1:0] DataOut
    );
    
    reg [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];
    always @ (posedge Clk)
        begin
            if (WEn) begin
                mem[WAddr] <= DataIn;
                end
        end
    
    assign DataOut = mem[RAddr];     
       
            
endmodule
