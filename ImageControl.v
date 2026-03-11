`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2020 10:53:27 AM
// Design Name: 
// Module Name: imageControl
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

module imageControl(
input                    i_clk,
input                    i_rst,
input [7:0]              i_pixel_data, //input pixel stream
input                    i_pixel_data_valid,
output reg [71:0]        o_pixel_data, //the data which goes to the multiply accumulate (convolution)
output                   o_pixel_data_valid,
output reg               o_intr
);

reg [8:0] pixelCounter;
//MAKING IT EXACTLY 9 BITS SO THAT WHEN IT OVERFLOWS, IT GOES BACK TO ZERO

reg [1:0] currentWrLineBuffer;
//SO AFTER THE FOURTH LINE BUFFER IS USED, IT GOES BACK TO THE FIRST

reg [3:0] lineBuffDataValid;
//WHICH EVER IS THE CURRENT LINE BUFFER, IT SHOULD HAVE DATA VALID 1 AND THE REST SHOULD BE 0

reg [3:0] lineBuffRdData;
//Basically control signal to inform the instantiated line buffers to start reading the values 

reg [1:0] currentRdLineBuffer;
//FROM WHICH LINE BUFFER WE ARE CURRENTLY READING FROM

//data in each line buffer (taking 3 pixels from 3 line buffers to be sent to the output)
wire [23:0] lb0data;
wire [23:0] lb1data;
wire [23:0] lb2data;
wire [23:0] lb3data;

reg [8:0] rdCounter; //how many pixels we have read

reg rd_line_buffer; //When we are reading the data. 

reg [11:0] totalPixelCounter;
reg rdState;

//-----------------------------------------------------------------------------------------------------------------------

localparam IDLE = 'b0,
           RD_BUFFER = 'b1;

//-----------------------------------------------------------------------------------------------------------------------

assign o_pixel_data_valid = rd_line_buffer;

//-----------------------------------------------------------------------------------------------------------------------

always @(posedge i_clk)
begin
    if(i_rst)
        totalPixelCounter <= 0;
    else
    begin
        if(i_pixel_data_valid & !rd_line_buffer)
            totalPixelCounter <= totalPixelCounter + 1;
        else if(!i_pixel_data_valid & rd_line_buffer)
            totalPixelCounter <= totalPixelCounter - 1;
    end
end

//-----------------------------------------------------------------------------------------------------------------------


//we read from line buffers if at least three line buffers are full. 
//need counters to check total amount of data in the line buffers
always @(posedge i_clk)
begin
    if(i_rst)
    begin
        rdState <= IDLE;
        rd_line_buffer <= 1'b0;
        o_intr <= 1'b0;
    end
    else
    begin
        case(rdState)
            IDLE:begin
                o_intr <= 1'b0;
                if(totalPixelCounter >= 1536)
                begin
                    rd_line_buffer <= 1'b1;
                    rdState <= RD_BUFFER;
                end
            end
            RD_BUFFER:begin
                if(rdCounter == 511)
                begin
                    rdState <= IDLE;
                    rd_line_buffer <= 1'b0;
                    o_intr <= 1'b1;
                end
            end
        endcase
    end
end
    
  //-----------------------------------------------------------------------------------------------------------------------
  
    
//WE ARE COUNTING THE PIXEL DATA, SO THAT WHENEVER IT OVERFLOWS, WE CAN SWITCH THE LINE BUFFER    
always @(posedge i_clk)
begin
    if(i_rst)
        pixelCounter <= 0;
    else 
    begin
        if(i_pixel_data_valid)
            pixelCounter <= pixelCounter + 1;
    end
end

//-----------------------------------------------------------------------------------------------------------------------


always @(posedge i_clk)
begin
    if(i_rst)
        currentWrLineBuffer <= 0;
    else
    begin
        if(pixelCounter == 511 & i_pixel_data_valid)
        //ANY VALID INPUT AFTER THE 512th PIXEL GOES TO THE NEXT LINE BUFFER
            currentWrLineBuffer <= currentWrLineBuffer+1;
    end
end

//-----------------------------------------------------------------------------------------------------------------------

//DECIDING THE DATA_VALID OF THE CURRENT LINE BUFFER
always @(*)
begin
    lineBuffDataValid = 4'h0;
    lineBuffDataValid[currentWrLineBuffer] = i_pixel_data_valid;
end

//-----------------------------------------------------------------------------------------------------------------------

//counting how many pixels we have read, so that we can apply the combination of line buffer switch logic
always @(posedge i_clk)
begin
    if(i_rst)
        rdCounter <= 0;
    else 
    begin
        if(rd_line_buffer)
            rdCounter <= rdCounter + 1;
    end
end

//-----------------------------------------------------------------------------------------------------------------------

//Each time we finish reading 512 pixels, we switch the combination of line buffers
always @(posedge i_clk)
begin
    if(i_rst)
    begin
        currentRdLineBuffer <= 0;
    end
    else
    begin
        if(rdCounter == 511 & rd_line_buffer)
            currentRdLineBuffer <= currentRdLineBuffer + 1;
    end
end

//-----------------------------------------------------------------------------------------------------------------------

//Logic for switching line buffers, like 123, 234, 341
always @(*)
begin
    case(currentRdLineBuffer)
        0:begin
            o_pixel_data = {lb2data,lb1data,lb0data};
        end
        1:begin
            o_pixel_data = {lb3data,lb2data,lb1data};
        end
        2:begin
            o_pixel_data = {lb0data,lb3data,lb2data};
        end
        3:begin
            o_pixel_data = {lb1data,lb0data,lb3data};
        end
    endcase
end

//-----------------------------------------------------------------------------------------------------------------------

always @(*)
begin
    case(currentRdLineBuffer)
        0:begin
            lineBuffRdData[0] = rd_line_buffer;
            lineBuffRdData[1] = rd_line_buffer;
            lineBuffRdData[2] = rd_line_buffer;
            lineBuffRdData[3] = 1'b0;
        end
       1:begin
            lineBuffRdData[0] = 1'b0;
            lineBuffRdData[1] = rd_line_buffer;
            lineBuffRdData[2] = rd_line_buffer;
            lineBuffRdData[3] = rd_line_buffer;
        end
       2:begin
             lineBuffRdData[0] = rd_line_buffer;
             lineBuffRdData[1] = 1'b0;
             lineBuffRdData[2] = rd_line_buffer;
             lineBuffRdData[3] = rd_line_buffer;
       end  
      3:begin
             lineBuffRdData[0] = rd_line_buffer;
             lineBuffRdData[1] = rd_line_buffer;
             lineBuffRdData[2] = 1'b0;
             lineBuffRdData[3] = rd_line_buffer;
       end        
    endcase
end
    
    
//-----------------------------------------------------------------------------------------------------------------------    
//THE FOUR LINE BUFFERS ARE INSTANTTIATED. 
lineBuffer lB0(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBuffDataValid[0]),
    .o_data(lb0data),
    .i_rd_data(lineBuffRdData[0])
 ); 
 
 lineBuffer lB1(
     .i_clk(i_clk),
     .i_rst(i_rst),
     .i_data(i_pixel_data),
     .i_data_valid(lineBuffDataValid[1]),
     .o_data(lb1data),
     .i_rd_data(lineBuffRdData[1])
  ); 
  
  lineBuffer lB2(
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_data(i_pixel_data),
      .i_data_valid(lineBuffDataValid[2]),
      .o_data(lb2data),
      .i_rd_data(lineBuffRdData[2])
   ); 
   
   lineBuffer lB3(
       .i_clk(i_clk),
       .i_rst(i_rst),
       .i_data(i_pixel_data),
       .i_data_valid(lineBuffDataValid[3]),
       .o_data(lb3data),
       .i_rd_data(lineBuffRdData[3])
    );    
    
endmodule