`timescale 1ns / 1ps


module tb_dht11;
    reg clk;


    wire   io_dht11;

    logic tb_o_dht11;

    pullup(io_dht11);       //相当于这个导线外部接了上拉电阻

    assign io_dht11=tb_o_dht11;


    wire [31:0]	dht11_data;
    wire 	dht11_data_valid;

    dht11 #(
              .INIT_DELAY_CNT 		( 25_000 		))
          u_dht11(
              //ports
              .clk25M           		( clk           		),
              .io_dht11         		( io_dht11         		),
              .dht11_data       		( dht11_data       		),
              .dht11_data_valid 		( dht11_data_valid 		)
          );





    localparam CLK_PERIOD = 40;     //CLK=25MHz
    always #(CLK_PERIOD/2) clk=~clk;


    task  ack();
        tb_o_dht11<=1'b0;               //拉低后等80us
        repeat(80*25) @(posedge clk);
        tb_o_dht11<=1'b1;
        repeat(85*25) @(posedge clk);    //拉高等85us

    endtask



    task  dht11_send_bits;
        input x;
        tb_o_dht11<=1'b0;               //拉低后等50us
        repeat(50*25) @(posedge clk);
        tb_o_dht11<=1'b1;
        if (x==1'b1) begin
            repeat(72*25) @(posedge clk);    //拉高等72us
        end
        else begin
            repeat(24*25) @(posedge clk);    //拉高等24us
        end
    endtask

    task dht11_send_byte;
        input [7:0] b;
        dht11_send_bits(b[7]);      //高位在前
        dht11_send_bits(b[6]);
        dht11_send_bits(b[5]);
        dht11_send_bits(b[4]);
        dht11_send_bits(b[3]);
        dht11_send_bits(b[2]);
        dht11_send_bits(b[1]);
        dht11_send_bits(b[0]);
    endtask

    localparam SHIDU_H = 8'h35;
    localparam SHIDU_L = 8'h00;
    logic [7:0] TEMP_H = 8'h18+$random%3;       //18-3 ~ 18+3
    logic [7:0] TEMP_H1 = 8'h18+$random%3;       //18-3 ~ 18+3
    logic [7:0] TEMP_L = {$random}%100;         
    logic [7:0] TEMP_L1 = {$random}%100;         
    logic [7:0] ADD_END = (SHIDU_H+SHIDU_L+TEMP_H+TEMP_L);
    logic [7:0] ADD_END1 = (SHIDU_H+SHIDU_L+TEMP_H1+TEMP_L1);



    initial begin

        clk<=0;
        tb_o_dht11=1'bz;
        @(posedge clk);
        repeat(2) @(posedge clk);


        @(negedge io_dht11);        //等待主机把io拉低的下降沿

        while(io_dht11==1'b0)
            @(posedge clk);         ////拉低的时候一直等

        tb_o_dht11<=1'b1;           //模拟外部上拉情况
        repeat(25*5) @(posedge clk);    //等5us

        ack();                  //响应

        dht11_send_byte(SHIDU_H);
        dht11_send_byte(SHIDU_L);
        dht11_send_byte(TEMP_H);
        dht11_send_byte(TEMP_L);
        dht11_send_byte(ADD_END);

        tb_o_dht11<=1'b0;               //发送完成后，拉低后等56us
        repeat(56*25) @(posedge clk);
        tb_o_dht11=1'bz;            //发送完成后，切换成高阻态，模拟外部上拉



        @(negedge io_dht11);        //等待主机把io拉低的下降沿

        while(io_dht11==1'b0)
            @(posedge clk);         ////拉低的时候一直等

        tb_o_dht11<=1'b1;           //模拟外部上拉情况
        repeat(25*5) @(posedge clk);    //等5us

        ack();                  //响应

        dht11_send_byte(SHIDU_H);
        dht11_send_byte(SHIDU_L);
        dht11_send_byte(TEMP_H1);
        dht11_send_byte(TEMP_L1);
        dht11_send_byte(ADD_END1);

        tb_o_dht11<=1'b0;               //发送完成后，拉低后等56us
        repeat(56*25) @(posedge clk);
        tb_o_dht11=1'bz;            //发送完成后，切换成高阻态，模拟外部上拉

        $display("1:TEMP:%h, %h",TEMP_H,TEMP_L);
        $display("2:TEMP:%h, %h",TEMP_H1,TEMP_L1);



    end

endmodule
`default_nettype wire
