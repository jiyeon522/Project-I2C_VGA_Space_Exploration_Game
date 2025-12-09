`timescale 1ns / 1ps

module Game_Data_Sender (
    input logic clk,
    input logic reset,
    input logic vsync,

    input logic [8:0] player_x,
    input logic [8:0] enemy_x_all[0:7],
    input logic [8:0] enemy_y_all[0:7],

    input logic [8:0] item_x             [0:1],
    input logic [8:0] item_y             [0:1],
    input logic       item_active        [0:1],
    input logic       item_type          [0:1],
    input logic       double_score_active,
    input logic [9:0] score,
    input logic       invincible, // [추가] 무적 상태 입력 포트 추가

    input logic [5:0] timer_sec,
    input logic [2:0] game_state,
    input logic       btn_pressed,

    input  logic [2:0]  sw,
    input  logic [15:0] frame_data,
    output logic [16:0] frame_addr,

    output logic uart_tx
);

    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy;
    logic       tx_done;

    UART_Tx U_UART (
        .clk  (clk),
        .reset(reset),
        .start(tx_start),
        .data (tx_data),
        .tx   (uart_tx),
        .busy (tx_busy),
        .done (tx_done)
    );

    typedef enum logic [4:0] {
        S_WAIT, S_HEADER, S_PX, S_ENEMY,
        S_ITEM0_X, S_ITEM0_Y, S_ITEM0_STATE,
        S_ITEM1_X, S_ITEM1_Y, S_ITEM1_STATE,
        S_DOUBLE, S_SCORE_L, S_SCORE_H, S_TIMER,
        S_STATE, S_BTN, S_MAGIC1, S_MAGIC2,
        IMG_INIT, IMG_SEND_HI, IMG_SEND_LO, IMG_DONE
    } send_state_t;

    send_state_t state;

    logic vsync_prev;
    logic [2:0] enemy_idx;
    logic       enemy_xy_sel;
    logic [4:0] pre_send_cnt;

    logic [16:0] pixel_idx;
    
    assign frame_addr = pixel_idx;

    logic [8:0] sx, sy;
    logic [3:0] r_fc, g_fc, b_fc;
    logic [11:0] final_color;

    // 1. 배경 이미지용 필터 컨트롤러
    Filter_Controller U_FilterSend (
        .clk     (clk),
        .reset   (reset),
        .sw      (sw),
        .x_pixel ({1'b0, sx}),
        .raw_data(frame_data),
        .r_final (r_fc),
        .g_final (g_fc),
        .b_final (b_fc)
    );

    // 2. 폰트 ROM 및 오버레이 변수
    logic [5:0] char_idx;
    logic [2:0] row_addr;
    logic [7:0] row_data;
    logic       font_bit;
    logic       draw_text;
    logic       draw_frame;
    logic [2:0] col_addr;

    MiniFontRom U_FontSender (
        .char_idx(char_idx),
        .row_addr(row_addr),
        .row_data(row_data)
    );
    
    assign font_bit = row_data[7 - col_addr];

    // 3. 최종 색상 결정 (오버레이 합성)
    always_comb begin
        // 기본값: 필터링된 카메라 영상
        final_color = {r_fc, g_fc, b_fc};
        
        draw_frame = 0;
        draw_text  = 0;
        char_idx   = 6'd30; 
        row_addr   = 0;
        col_addr   = 0;

        // 프레임 영역 체크
        if (sx < 20 || sx >= 300 || sy < 20 || sy >= 220) begin
            draw_frame = 1;
        end

        // 텍스트 1: 제목 (SPACE WAR)
        if (sy >= 30 && sy < 38 && sx >= 124 && sx < 196) begin
            row_addr = sy - 30;
            col_addr = sx - 124;
            case ((sx - 124) >> 3)
                0: char_idx = 6'd17; // S
                1: char_idx = 6'd15; // P
                2: char_idx = 6'd10; // A
                3: char_idx = 6'd20; // C
                4: char_idx = 6'd11; // E
                5: char_idx = 6'd30;
                6: char_idx = 6'd22; // W
                7: char_idx = 6'd10; // A
                8: char_idx = 6'd16; // R
                default: char_idx = 6'd30;
            endcase
            if (font_bit) draw_text = 1;
        end

        // 텍스트 2: 점수 (SCORE XXX)
        if (sy >= 45 && sy < 53 && sx >= 124 && sx < 196) begin
            row_addr = sy - 45;
            col_addr = sx - 124;
            case ((sx - 124) >> 3)
                0: char_idx = 6'd17; // S
                1: char_idx = 6'd20; // C
                2: char_idx = 6'd14; // O
                3: char_idx = 6'd16; // R
                4: char_idx = 6'd11; // E
                5: char_idx = 6'd30;
                6: char_idx = (score / 100);
                7: char_idx = (score / 10) % 10;
                8: char_idx = (score % 10);
                default: char_idx = 6'd30;
            endcase
            if (font_bit) draw_text = 1;
        end

        // 우선순위 적용
        if (draw_text) begin
            final_color = 12'hFF0; // 텍스트: 노란색
        end else if (draw_frame) begin
            if ((sx[2] ^ sy[3]) && (sx[4] & sy[2])) final_color = 12'hFFF;
            else final_color = 12'h113;
        end
    end

    // FSM (전송 로직)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= S_WAIT;
            vsync_prev   <= 1'b0;
            tx_start     <= 1'b0;
            enemy_idx    <= 3'd0;
            enemy_xy_sel <= 1'b0;
            pre_send_cnt <= 5'd0;

            pixel_idx    <= 17'd0;
            tx_data      <= 8'd0;
            sx           <= 9'd0;
            sy           <= 9'd0;
        end else begin
            vsync_prev <= vsync;
            tx_start   <= 1'b0;

            if (game_state != 3'd4) pre_send_cnt <= 5'd0;

            case (state)
                S_WAIT: begin
                    if (!vsync_prev && vsync) begin
                        if (game_state == 3'd4) begin
                            if (pre_send_cnt < 5'd20) begin
                                pre_send_cnt <= pre_send_cnt + 1;
                                state    <= S_HEADER;
                                tx_data  <= 8'hFF;
                                tx_start <= 1'b1;
                            end else begin
                                state     <= S_MAGIC1;
                                tx_data   <= 8'hAA;
                                tx_start  <= 1'b1;
                                pixel_idx <= 17'd0;
                                sx        <= 9'd0;
                                sy        <= 9'd0;
                            end
                        end else begin
                            state    <= S_HEADER;
                            tx_data  <= 8'hFF;
                            tx_start <= 1'b1;
                        end
                    end
                end

                S_HEADER: if (tx_done) begin
                    state    <= S_PX;
                    tx_data  <= player_x[8:1];
                    tx_start <= 1'b1;
                end

                S_PX: if (tx_done) begin
                    state        <= S_ENEMY;
                    enemy_idx    <= 3'd0;
                    enemy_xy_sel <= 1'b0;
                    tx_data      <= enemy_x_all[0][8:1];
                    tx_start     <= 1'b1;
                end

                S_ENEMY: if (tx_done) begin
                    if (!enemy_xy_sel) begin
                        tx_data      <= enemy_y_all[enemy_idx][8:1];
                        enemy_xy_sel <= 1'b1;
                        tx_start     <= 1'b1;
                    end else begin
                        if (enemy_idx == 3'd7) begin
                            state    <= S_ITEM0_X;
                            tx_data  <= item_x[0][8:1];
                            tx_start <= 1'b1;
                        end else begin
                            enemy_idx    <= enemy_idx + 1;
                            enemy_xy_sel <= 1'b0;
                            tx_data      <= enemy_x_all[enemy_idx+1][8:1];
                            tx_start     <= 1'b1;
                        end
                    end
                end

                S_ITEM0_X: if (tx_done) begin
                    state    <= S_ITEM0_Y;
                    tx_data  <= item_y[0][8:1];
                    tx_start <= 1'b1;
                end

                S_ITEM0_Y: if (tx_done) begin
                    state    <= S_ITEM0_STATE;
                    tx_data  <= {6'b0, item_type[0], item_active[0]};
                    tx_start <= 1'b1;
                end

                S_ITEM0_STATE: if (tx_done) begin
                    state    <= S_ITEM1_X;
                    tx_data  <= item_x[1][8:1];
                    tx_start <= 1'b1;
                end

                S_ITEM1_X: if (tx_done) begin
                    state    <= S_ITEM1_Y;
                    tx_data  <= item_y[1][8:1];
                    tx_start <= 1'b1;
                end

                S_ITEM1_Y: if (tx_done) begin
                    state    <= S_ITEM1_STATE;
                    tx_data  <= {6'b0, item_type[1], item_active[1]};
                    tx_start <= 1'b1;
                end

                S_ITEM1_STATE: if (tx_done) begin
                    state    <= S_DOUBLE;
                    tx_data  <= {7'b0, double_score_active};
                    tx_start <= 1'b1;
                end

                S_DOUBLE: if (tx_done) begin
                    state    <= S_SCORE_L;
                    tx_data  <= score[7:0];
                    tx_start <= 1'b1;
                end

                S_SCORE_L: if (tx_done) begin
                    state    <= S_SCORE_H;
                    tx_data  <= {6'b0, score[9:8]};
                    tx_start <= 1'b1;
                end

                S_SCORE_H: if (tx_done) begin
                    state    <= S_TIMER;
                    tx_data  <= {2'b0, timer_sec};
                    tx_start <= 1'b1;
                end

                S_TIMER: if (tx_done) begin
                    state    <= S_STATE;
                    tx_data  <= {4'b0, invincible, game_state}; 
                    tx_start <= 1'b1;
                end

                S_STATE: if (tx_done) begin
                    state    <= S_BTN;
                    tx_data  <= {7'b0, btn_pressed};
                    tx_start <= 1'b1;
                end

                S_BTN: if (tx_done) begin
                    state <= S_WAIT;
                end

                S_MAGIC1: if (tx_done) begin
                    state    <= S_MAGIC2;
                    tx_data  <= 8'h55;
                    tx_start <= 1'b1;
                end

                S_MAGIC2: if (tx_done) begin
                    state     <= IMG_INIT;
                    pixel_idx <= 17'd0;
                    sx        <= 9'd0;
                    sy        <= 9'd0;
                end

                IMG_INIT: begin
                    state <= IMG_SEND_HI;
                end

                IMG_SEND_HI: begin
                    if (!tx_busy) begin
                        tx_data  <= {4'b0000, final_color[11:8]};
                        tx_start <= 1'b1;
                        state    <= IMG_SEND_LO;
                    end
                end

                IMG_SEND_LO: begin
                    if (tx_done) begin
                        tx_data  <= final_color[7:0];
                        tx_start <= 1'b1;

                        if (pixel_idx == 17'd76799) begin
                            state <= IMG_DONE;
                        end else begin
                            pixel_idx <= pixel_idx + 1;
                            if (sx == 9'd319) begin
                                sx <= 9'd0;
                                sy <= sy + 1;
                            end else begin
                                sx <= sx + 1;
                            end
                            state <= IMG_INIT;
                        end
                    end
                end

                IMG_DONE: begin
                    if (game_state != 3'd4) begin
                        state        <= S_WAIT;
                        pre_send_cnt <= 5'd0;
                    end
                end

                default: state <= S_WAIT;
            endcase
        end
    end
endmodule