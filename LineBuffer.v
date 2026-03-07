`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 04:09:25
// Design Name: 
// Module Name: LineBuffer
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


module LineBuffer(
    input i_clk,
    input i_rst,
    input [7:0] i_data, //data stream, taking each pixel to be grayscale, thus 8 bits
    input i_data_valid,
    input i_rd_data,
    output [23:0] o_data 
    //since we are using 3x3 kernel, at once, we read 3 pixels from a line

    );
    
    //a line buffer is nothing but a memory, so 8 bit pixels and 512 such pixels
    reg [7:0] line [511:0];
    reg [8:0] wrPntr;
    reg [8:0] rdPntr; //points to which pixel we want to read or write
    
    always @(posedge i_clk)
    begin
        if(i_data_valid)
            line[wrPntr]<=i_data;
    end
    
    
    always @(posedge i_clk)
    begin
        if(i_rst)
            wrPntr<=1'd0;
        else if(i_data_valid)
            wrPntr<=wrPntr+'d1;
    end
    
    always @(posedge i_clk)
    begin
        if(i_rst)
            rdPntr<='d0;
        else if(i_rd_data)
            rdPntr<=rdPntr+'d1;
    end
    
    assign o_data={line[rdPntr],line[rdPntr+1],line[rdPntr+2]};
    //using combination, we are prefetching . 
endmodule
