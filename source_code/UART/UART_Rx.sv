`timescale 1ns / 1ps

module UART_Rx (
    input  logic       clk,      // 100MHz System Clock
    input  logic       reset,
    input  logic       rx,       // USB-UART RX 핀 (B18)
    output logic [7:0] data_out, // 받은 데이터 (예: 'S' 아스키코드)
    output logic       rx_done   // 데이터 수신 완료 신호 (1 tick)
);
    // 115200 Baud Rate @ 100MHz
    localparam CLK_DIV = 868;

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [12:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  rx_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            data_out <= 0;
            rx_done  <= 0;
            rx_data  <= 0;
        end else begin
            rx_done <= 0; // 평소엔 0

            case (state)
                IDLE: begin
                    if (rx == 0) begin // Start Bit(0) 감지
                        state   <= START;
                        clk_cnt <= 0;
                    end
                end
                START: begin
                    // 비트의 정중앙을 찍기 위해 절반만큼 기다림
                    if (clk_cnt == (CLK_DIV / 2)) begin
                        if (rx == 0) begin
                            state   <= DATA;
                            clk_cnt <= 0;
                            bit_idx <= 0;
                        end else begin
                            state <= IDLE; // 노이즈였다면 취소
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= 0;
                        rx_data[bit_idx] <= rx; // 데이터 한 비트씩 저장
                        if (bit_idx == 7) state <= STOP;
                        else bit_idx <= bit_idx + 1;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                STOP: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        state    <= IDLE;
                        data_out <= rx_data; // 완성된 1바이트 출력
                        rx_done  <= 1;       // "나 다 받았어!" 신호
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule