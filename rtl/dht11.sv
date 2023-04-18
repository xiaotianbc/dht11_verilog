`timescale 1ns / 1ps


module clk_1us_gen (
        input      clk,
        output        clk_out_1us
    );
    parameter CLK_IN = 25;

    reg [$clog2(CLK_IN+1)-1:0] cnt;
    initial begin
        cnt=0;
    end

    always @(posedge clk ) begin
        if (cnt==CLK_IN-1) begin
            cnt<=0;
        end
        else begin
            cnt<=cnt+1'b1;
        end
    end
    assign clk_out_1us = (cnt<CLK_IN/2)?1'b1:1'b0;
endmodule //clk_1us_gen




module dht11(
        input clk25M,
        inout  io_dht11,
        output [31:0]   dht11_data,
        output logic dht11_data_valid
    );


    logic o_dht11;
    logic dht11_o_en;
    assign io_dht11=dht11_o_en?o_dht11:1'bz;

    wire 	clk;            //1us / 1MHz

    clk_1us_gen #(
                    .CLK_IN 		( 25 		))
                u_clk_1us_gen(
                    //ports
                    .clk         		( clk25M         		),
                    .clk_out_1us 		( clk 		)
                );


    logic rst_n=0;

    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            rst_n<=1'b1;
        end
    end

    parameter INIT_DELAY_CNT = 3_000_000;

    logic [$clog2(INIT_DELAY_CNT+1)-1:0] cnt_3s;
    logic [$clog2(20_000+1)-1:0] cnt;       //最大20ms,同时可以用于后面的接收数据


    logic  io_dht11_r;
    logic  io_dht11_rr;     //打两拍
    logic  io_dht11_rrr;     //打三拍，用于边沿检测

    always_ff @( posedge clk) begin
        io_dht11_r<=io_dht11;
        io_dht11_rr<=io_dht11_r;
        io_dht11_rrr<=io_dht11_rr;
    end

    wire dht11_pos=(~io_dht11_rrr) && io_dht11_rr;     //上升沿检测
    wire dht11_neg=io_dht11_rrr && (~io_dht11_rr);      //下降沿检测

    localparam  ST_IDLE=5'b00001;
    localparam  ST_CALL=5'b00010;
    localparam  ST_WAIT_NEG=5'b00100;        //释放总线后，等个下降沿
    localparam  ST_WAIT=5'b01000;
    localparam  ST_READ_DATA=5'b10000;

    logic [4:0]  state, next_state;

    logic [$clog2(64)-1:0] bits_cnt;

    logic start_cnt_data;           //接收数据计数器


    logic [39:0]    recv_data;
    logic   recv_data_valid;

    assign  dht11_data[31:0]    =recv_data[39:8];       //recv data的 7:0是校验位
    assign recv_data_valid=(recv_data[7:0] == (recv_data[39:32]+recv_data[31:24]+recv_data[23:16]+recv_data[15:8]));

    always_ff @( posedge clk) begin
        if (!rst_n) begin
            dht11_data_valid<=1'b0;
        end
        else begin
            if (state==ST_IDLE) begin
                if (recv_data_valid) begin
                    dht11_data_valid<=1'b1;
                end
                else begin
                    dht11_data_valid<=1'b0;
                end
            end
            else begin
                dht11_data_valid<=1'b0;
            end
        end
    end

    always_ff @( posedge clk) begin
        if (!rst_n) begin
            state<=ST_IDLE;
        end
        else begin
            state<=next_state;
        end
    end

    always_comb begin
        case (state)
            ST_IDLE: begin
                if (cnt_3s==INIT_DELAY_CNT-1) begin
                    next_state=ST_CALL;
                end
                else begin
                    next_state=ST_IDLE;
                end
            end
            ST_CALL: begin
                if (cnt=='d20_000-1) begin
                    next_state=ST_WAIT_NEG;
                end
                else begin
                    next_state=ST_CALL;
                end
            end
            ST_WAIT_NEG: begin
                if (dht11_neg) begin
                    next_state=ST_WAIT;
                end
                else begin
                    next_state=ST_WAIT_NEG;
                end
            end
            ST_WAIT: begin
                if (dht11_pos ) begin
                    next_state=ST_READ_DATA;
                end
                else begin
                    next_state=ST_WAIT;
                end
            end
            ST_READ_DATA: begin
                if (dht11_pos && bits_cnt==40) begin
                    next_state=ST_IDLE;
                end
                else begin
                    next_state=ST_READ_DATA;
                end
            end
        endcase
    end


    //cnt_3s

    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            cnt_3s<=0;
        end
        else begin
            if (state==ST_IDLE) begin
                if ( cnt_3s==INIT_DELAY_CNT-1) begin
                    cnt_3s<=0;
                end
                else begin
                    cnt_3s<=cnt_3s+1'b1;
                end
            end
            else begin
                cnt_3s<=0;
            end
        end
    end

    //cnt
    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            cnt<=0;
        end
        else begin
            if (state==ST_CALL) begin       //CALL 记到20ms
                if ( cnt=='d20_000-1) begin
                    cnt<=0;
                end
                else begin
                    cnt<=cnt+1'b1;
                end
            end
            else if (state==ST_READ_DATA) begin
                if (dht11_neg) begin
                    cnt<=0;
                end
                else if (start_cnt_data) begin
                    cnt<=cnt+1'b1;
                end
                else begin
                    cnt<=0;
                end
            end
            else begin
                cnt<=0;
            end
        end
    end

    //start_cnt_data
    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            start_cnt_data<=1'b0;
        end
        else begin
            if (state==ST_READ_DATA) begin
                //出现上升沿，开始计数
                if (dht11_pos) begin
                    start_cnt_data<=1'b1;
                end
                //出现下降沿，停止计数
                else if (dht11_neg) begin
                    start_cnt_data<=1'b0;
                end
            end
            else begin      //其他状态下，都不计数，复位寄存器
                 start_cnt_data<=1'b0;
            end
        end
    end


    //bits_cnt
    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            bits_cnt<=1'b0;
        end
        else begin
            if (state==ST_READ_DATA) begin
                //出现上升沿，开始计数
                if (dht11_neg && (cnt>0)) begin
                    bits_cnt<=bits_cnt+1'b1;
                end
            end
            else begin
                bits_cnt<=0;
            end
        end
    end

    //recv_data
    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            recv_data<=40'h0;
        end
        else begin
            if (state==ST_READ_DATA && (dht11_neg && (cnt>0))) begin
                if (cnt>50) begin       //收到的是1
                    recv_data<={recv_data[38:0],1'b1};  //高位在前
                end
                else begin
                    recv_data<={recv_data[38:0],1'b0};  //高位在前
                end
            end
        end
    end



    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            o_dht11<=1'b1;
            dht11_o_en<=1'b1;
        end
        else
        case (state)
            ST_IDLE: begin
                o_dht11<=1'b1;
                dht11_o_en<=1'b0;       //空闲状态，高阻输入
            end
            ST_CALL: begin
                o_dht11<=1'b0;
                dht11_o_en<=1'b1;
            end
            ST_WAIT_NEG: begin
                o_dht11<=1'b1;
                dht11_o_en<=1'b0;
            end
            ST_WAIT: begin
                o_dht11<=1'b1;
                dht11_o_en<=1'b0;
            end
            ST_READ_DATA: begin
                o_dht11<=1'b1;
                dht11_o_en<=1'b0;
            end

        endcase
    end


endmodule
