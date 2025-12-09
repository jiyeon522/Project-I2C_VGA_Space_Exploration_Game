`timescale 1ns / 1ps

module UART_Tx (
    input  logic       clk,      // System Clock (100MHz for Basys3)
    input  logic       reset,
    input  logic       start,    // 전송 시작 신호
    input  logic [7:0] data,     // 보낼 데이터 (1바이트)
    output logic       tx,       // UART TX Pin
    output logic       busy,     // 전송 중임
    output logic       done      // 전송 완료
);
    // 115200 Baud Rate @ 100MHz Clock
    // CLK_DIV = 100,000,000 / 115200 ≈ 868
    localparam CLK_DIV = 868;

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [12:0] clk_cnt;
    logic [2:0]  bit_idx;
    logic [7:0]  tx_data;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= IDLE;
            tx      <= 1'b1; // Idle state is High
            busy    <= 0;
            done    <= 0;
            clk_cnt <= 0;
            bit_idx <= 0;
        end else begin
            done <= 0; // Pulse done signal
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (start) begin
                        state   <= START;
                        tx_data <= data;
                        busy    <= 1;
                        clk_cnt <= 0;
                    end else begin
                        busy <= 0;
                    end
                end
                START: begin // Start Bit (Low)
                    tx <= 1'b0;
                    if (clk_cnt == CLK_DIV - 1) begin
                        state   <= DATA;
                        clk_cnt <= 0;
                        bit_idx <= 0;
                    end else clk_cnt <= clk_cnt + 1;
                end
                DATA: begin // 8 Data Bits
                    tx <= tx_data[bit_idx];
                    if (clk_cnt == CLK_DIV - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 7) state <= STOP;
                        else bit_idx <= bit_idx + 1;
                    end else clk_cnt <= clk_cnt + 1;
                end
                STOP: begin // Stop Bit (High)
                    tx <= 1'b1;
                    if (clk_cnt == CLK_DIV - 1) begin
                        state <= IDLE;
                        done  <= 1;
                        busy  <= 0;
                    end else clk_cnt <= clk_cnt + 1;
                end
            endcase
        end
    end
endmodule