`timescale 1ns/1ps

module dptb;

reg Clk, Rst;
wire [31:0] DataOut;

DataPath uut (.Clk(Clk),.Rst(Rst),.DataOut(DataOut));

initial begin
Clk = 1;
Rst = 1; 
end

always #5 Clk = ~Clk;

task reset_PC_RB;
begin
    @(negedge Clk) begin
        Rst = 1;
        end
    repeat (2) @(negedge Clk);
end
endtask

task write_program;
reg [31:0] prog [0:63];
integer i;
begin
    $readmemh("program.mem",prog);
    for (i = 0; i < 64; i = i + 1) begin
        uut.IM.RAM0.mem[i] = prog[i][7:0];
        uut.IM.RAM1.mem[i] = prog[i][15:8];
        uut.IM.RAM2.mem[i] = prog[i][23:16];
        uut.IM.RAM3.mem[i] = prog[i][31:24];
    end
end
endtask

task write_data;
reg [31:0] data [0:63];
integer i;
begin
    $readmemh("data.mem",data);
    for (i = 0; i < 64; i = i + 1) begin
        uut.DM.RAM0.mem[i] = data[i][7:0];
        uut.DM.RAM1.mem[i] = data[i][15:8];
        uut.DM.RAM2.mem[i] = data[i][23:16];
        uut.DM.RAM3.mem[i] = data[i][31:24];
    end
end
endtask

task drop_reset_PC_RB;
begin
    @(negedge Clk) begin
        Rst = 0;
        end
end
endtask 

task check_RB;
reg [31:0] target [0:31];
integer i;
integer pass, fail;
begin
pass = 0;
fail = 0;
    $readmemh("target.mem",target);

    for (i=0;i<32;i=i+1) begin
        if (uut.RB.mem[i] == target[i]) begin
                $display("PASS x%0d = %0h       |       Expected = %0h",i,uut.RB.mem[i],target[i]);
                pass = pass + 1;
            end
        else begin
                $display("FAIL x%0d = %0h       |       Expected = %0h",i,uut.RB.mem[i],target[i]);
                fail = fail + 1;
            end
    end
    $display("==============================================");
    $display("PASS = %0d        |       FAIL = %0d",pass,fail);
    $display("==============================================");

end
endtask 

integer k;

initial begin
    write_data();
    write_program();   // LIGHTS!
    reset_PC_RB();        // CAMERA!!
    drop_reset_PC_RB();   // ACTION!!!
    #100;
    check_RB();
    $finish;
    end
endmodule