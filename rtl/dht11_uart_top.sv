module dht11_uart_top (
        input      clk,
        inout  io_dht11,
        output o_txp
    );

    parameter INIT_DELAY_CNT=3_000_000;


    logic rst_n=0;

    always_ff @( posedge clk ) begin
        if (!rst_n) begin
            rst_n<=1'b1;
        end
    end

    logic [7:0] i_tx_data;
    logic i_tx_en;
    logic [2:0] need_send;



    wire [31:0]	dht11_data;
    wire 	dht11_data_valid;

    dht11 #(
              .INIT_DELAY_CNT 		( INIT_DELAY_CNT 		))
          u_dht11(
              //ports
              .clk25M           		( clk           		),
              .io_dht11         	,
              .dht11_data       		( dht11_data       		),
              .dht11_data_valid 		( dht11_data_valid 		)
          );


    wire 	o_tx_done;

    uart_tx #(
                .baud_cycles 		( 25_000_000/115200 		))
            u_uart_tx(
                //ports
                .clk       		( clk       		),
                .rst_n     		( rst_n     		),
                .i_tx_data 		( i_tx_data 		),
                .i_tx_en   		( i_tx_en   		),
                .o_txp     		( o_txp     		),
                .o_tx_done 		( o_tx_done 		)
            );


    localparam  ST_IDLE = 4'b0001;
    localparam  ST_SEND = 4'b0010;
    localparam  ST_WAIT_SEND = 4'b0100;
    localparam  ST_WAIT_REF = 4'b1000;

    logic [3:0] state, next_state;

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
            ST_IDLE:  begin
                next_state=dht11_data_valid?ST_SEND:ST_IDLE;
            end
            ST_SEND:  begin
                next_state=(need_send>1)?ST_WAIT_SEND:ST_WAIT_REF;
            end
            ST_WAIT_SEND:  begin
                next_state=o_tx_done?ST_SEND:ST_WAIT_SEND;
            end
            ST_WAIT_REF:  begin
                next_state=(~dht11_data_valid)?ST_IDLE:ST_WAIT_REF;
            end
        endcase
    end

    //need_send
    always_ff @( posedge clk) begin
        if (!rst_n) begin
            need_send<='h0;
        end
        else begin
            if (state==ST_IDLE) begin
                need_send<='d4;
            end
            else if (i_tx_en) begin
                need_send<=need_send-1'b1;      //每次发送，减一
            end
        end
    end

    //    logic [7:0] i_tx_data;
    always_ff @( posedge clk) begin
        if (!rst_n) begin
            i_tx_data<='h0;
        end
        else begin
            if (need_send>0) begin
                i_tx_data<=dht11_data[8*need_send-1-:8];
            end
            else begin
                i_tx_data<='h0;
            end
        end
    end


    //logic i_tx_en;
    always_ff @( posedge clk) begin
        if (!rst_n) begin
            i_tx_en<='b0;
        end
        else begin
            if (state==ST_SEND) begin
                i_tx_en<=1'b1;
            end
            else begin
                i_tx_en<=1'b0;
            end
        end
    end


endmodule //dht11_uart_top
