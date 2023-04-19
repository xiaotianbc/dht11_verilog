module uart_tx (
        input               clk,
        input               rst_n,
        input       [7:0]   i_tx_data,
        input               i_tx_en,
        output    reg       o_txp,
        output    reg       o_tx_done
    );

    parameter baud_cycles = 25_000_000/5_000_000;

    //------------<状态机参数定义>------------------------------------------
    localparam ST_IDLE  = 4'b0001;
    localparam ST_START  = 4'b0010;
    localparam ST_DATA  = 4'b0100;
    localparam ST_STOP  = 4'b1000;


    //------------<reg定义>-------------------------------------------------
    reg    [3:0]    state;                            //定义现态寄存器
    reg    [3:0]    next_state;                    //定义次态寄存器

    reg  [7:0]   i_tx_data_r;
    reg [$clog2(baud_cycles+1)-1:0] baud_cnt;
    reg [2:0]   bits_cnt;               // 当前发送位数计数

    wire baud_cnt_willoverflow=(baud_cnt==baud_cycles-1);

    always @(posedge clk) begin
        if(!rst_n) begin
            i_tx_data_r <= 0;
        end
        else begin
            if (state==ST_IDLE && i_tx_en) begin
                i_tx_data_r<=i_tx_data;
            end
            else begin
                i_tx_data_r<=i_tx_data_r;
            end
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            baud_cnt<= 0;
        end
        else begin
            if (state!=ST_IDLE) begin
                baud_cnt<=baud_cnt+1'b1;
                if (baud_cnt_willoverflow) begin
                    baud_cnt<='h0;
                end
            end
        end
    end

    //当前发送位数计数
    always @(posedge clk) begin
        if(!rst_n) begin
            bits_cnt<= 0;
        end
        else begin
            if (state==ST_DATA && baud_cnt_willoverflow) begin
                bits_cnt<=bits_cnt+1'b1;
            end
        end
    end


    //-----------------------------------------------------------------------
    //--状态机第一段：同步时序描述状态转移
    //-----------------------------------------------------------------------
    always@(posedge clk ) begin
        if(!rst_n)
            state <= ST_IDLE;                //复位初始状态
        else
            state <= next_state;        //次态转移到现态
    end

    //-----------------------------------------------------------------------
    //--状态机第二段：组合逻辑判断状态转移条件，描述状态转移规律以及输出
    //-----------------------------------------------------------------------
    always@(*) begin
        case(state)                        //组合逻辑
            //根据当前状态、输入进行状态转换判断
            ST_IDLE: begin
                if (i_tx_en) begin
                    next_state=ST_START;
                end
                else begin
                    next_state=ST_IDLE;
                end
            end
            ST_START: begin
                if (baud_cnt_willoverflow) begin
                    next_state=ST_DATA;
                end
                else begin
                    next_state=ST_START;
                end
            end
            ST_DATA: begin
                if (baud_cnt_willoverflow && bits_cnt=='h7) begin       //发送完最高位
                    next_state=ST_STOP;
                end
                else begin
                    next_state=ST_DATA;
                end
            end
            ST_STOP: begin
                if (baud_cnt_willoverflow ) begin
                    next_state=ST_IDLE;
                end
                else begin
                    next_state=ST_STOP;
                end
            end
            default: begin                    //默认状态同IDLE
                if (i_tx_en) begin
                    next_state=ST_START;
                end
                else begin
                    next_state=ST_IDLE;
                end
            end
        endcase
    end
    //-----------------------------------------------------------------------
    //--状态机第三段：时序逻辑描述输出
    //-----------------------------------------------------------------------
    always@(posedge clk ) begin
        if(!rst_n) begin
            o_txp<=1'b1;
        end
        //复位、初始状态
        else
        case(state)                    //根据当前状态进行输出
            ST_IDLE: begin
                o_txp<=1'b1;
            end
            ST_START: begin
                o_txp<=1'b0;
            end
            ST_DATA: begin
                o_txp<=i_tx_data_r[bits_cnt];
            end
            ST_STOP: begin
                o_txp<=1'b1;
            end
            default: begin
                o_txp<=1'b1;
            end
        endcase
    end

    always@(posedge clk ) begin
        if(!rst_n) begin
            o_tx_done<=1'b0;
        end
        //复位、初始状态
        else
        case(state)                    //根据当前状态进行输出
            ST_STOP: begin
                if (baud_cnt_willoverflow) begin
                    o_tx_done<=1'b1;
                end
            end
            default: begin
                o_tx_done<=1'b0;
            end
        endcase
    end

endmodule
