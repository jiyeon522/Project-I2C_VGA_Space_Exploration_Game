`timescale 1ns / 1ps

module Game_Controller_Top (
    input  logic        clk,
    input  logic        reset,
    input  logic        start_btn,
    
    // VGA & Camera Info (Overlay용)
    input  logic        DE,
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,
    input  logic [11:0] bg_data, // 카메라 배경 픽셀 데이터
    input  logic [2:0]  sw,      // 필터 스위치

    // Player Info (from Detector)
    input  logic [8:0]  player_x,
    // input logic [8:0] player_y,  <-- 삭제됨 (내부 상수로 변경)
    input  logic        player_detected,

    // VGA Output (To Top Module)
    output logic [3:0]  r_port,
    output logic [3:0]  g_port,
    output logic [3:0]  b_port,

    // Game Data Outputs (To UART Sender)
    output logic [2:0]  game_state,
    output logic [9:0]  score,
    output logic [5:0]  timer_sec,
    output logic        double_score_active,
    output logic        invincible,
    
    output logic [8:0]  enemy_x      [0:7],
    output logic [8:0]  enemy_y      [0:7],
    output logic        enemy_active [0:7],

    output logic [8:0]  item_x       [0:1],
    output logic [8:0]  item_y       [0:1],
    output logic        item_active  [0:1],
    output logic        item_type    [0:1]
);

    // [추가] Player Y 좌표는 210으로 고정 (상수 취급)
    logic [8:0] player_y;
    assign player_y = 9'd210;

    // Internal Signals
    logic score_up_event;
    logic collision_event;
    logic bomb_trigger;
    logic double_score_trigger;
    logic item_collected [0:1];
    logic [3:0] enemies_killed_count;

    // 1. Game Controller (FSM)
    GameController U_GameController (
        .clk       (clk),
        .reset     (reset),
        .start_btn (start_btn),
        .timer_sec (timer_sec),
        .game_state(game_state)
    );

    // 2. Enemy Manager
    EnemyManager U_EnemyManager (
        .clk                 (clk),
        .reset               (reset),
        .game_state          (game_state[1:0]), 
        .player_y            (player_y),         // 내부 상수 연결
        .timer_sec           (timer_sec),
        .enemy_x             (enemy_x),
        .enemy_y             (enemy_y),
        .enemy_active        (enemy_active),
        .bomb_trigger        (bomb_trigger),
        .score_up            (score_up_event),
        .enemies_killed_count(enemies_killed_count)
    );

    // 3. Collision Detector
    CollisionDetector U_CollisionDetector (
        .clk                 (clk),
        .reset               (reset),
        .game_state          (game_state[1:0]),
        .player_x            (player_x),
        .player_y            (player_y),         // 내부 상수 연결
        .player_detected     (player_detected),
        .enemy_x             (enemy_x),
        .enemy_y             (enemy_y),
        .enemy_active        (enemy_active),
        .item_x              (item_x),
        .item_y              (item_y),
        .item_active         (item_active),
        .item_type           (item_type),
        .item_collected      (item_collected),
        .double_score_trigger(double_score_trigger),
        .bomb_trigger        (bomb_trigger),
        .collision_event     (collision_event),
        .invincible          (invincible)
    );

    // 4. Score Manager
    ScoreManager U_ScoreManager (
        .clk                 (clk),
        .reset               (reset),
        .game_state          (game_state), 
        .score_up            (score_up_event),
        .collision_event     (collision_event),
        .double_score_active (double_score_active),
        .bomb_trigger        (bomb_trigger),
        .enemies_killed_count(enemies_killed_count),
        .score               (score)
    );

    // 5. Timer
    ScoreTimer U_ScoreTimer (
        .clk       (clk),
        .reset     (reset),
        .game_state(game_state[1:0]),
        .timer_sec (timer_sec)
    );

    // 6. Item Manager
    ItemManager U_ItemManager (
        .clk             (clk),
        .reset           (reset),
        .game_state      (game_state[1:0]),
        .enemy_x     (enemy_x),
        .enemy_y     (enemy_y),
        .enemy_active_all(enemy_active),
        .item_x          (item_x),
        .item_y          (item_y),
        .item_active     (item_active),
        .item_type       (item_type),
        .item_collected  (item_collected)
    );

    // 7. Buff Controller
    BuffController U_BuffController (
        .clk                (clk),
        .reset              (reset),
        .game_state_play    (game_state == 3'd1),
        .item_collected     (double_score_trigger),
        .double_score_active(double_score_active)
    );

    // 8. Game Overlay
    GameOverlay U_GameOverlay (
        .clk                (clk),
        .DE                 (DE),
        .x_pixel            (x_pixel),
        .y_pixel            (y_pixel),
        .bg_data            (bg_data),
        .game_state         (game_state[1:0]), 
        .player_x           (player_x),
        .player_y           (player_y),         // 내부 상수 연결
        .player_detected    (player_detected),
        .enemy_x            (enemy_x),
        .enemy_y            (enemy_y),
        .enemy_active       (enemy_active),
        .item_x             (item_x),
        .item_y             (item_y),
        .item_active        (item_active),
        .item_type          (item_type),
        .double_score_active(double_score_active),
        .score              (score),
        .timer_sec          (timer_sec),
        .invincible         (invincible),
        .send_mode          (game_state == 3'd4),
        .sw                 (sw),
        .r_port             (r_port),
        .g_port             (g_port),
        .b_port             (b_port)
    );

endmodule

module GameController (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_btn,
    input  logic [5:0] timer_sec,
    output logic [2:0] game_state
);
    logic start_btn_prev;
    logic start_edge;

    // 버튼 ?��?��?���? �?�?
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            start_btn_prev <= 1'b0;
        end else begin
            start_btn_prev <= start_btn;
        end
    end

    assign start_edge = start_btn & ~start_btn_prev;

    // 0: WAIT
    // 1: PLAY
    // 2: FILTER_SELECT
    // 3: CAPTURE
    // 4: SEND
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            game_state <= 3'd0;
        end else begin
            case (game_state)
                3'd0: begin  // WAIT
                    if (start_edge) game_state <= 3'd1;
                end

                3'd1: begin  // PLAY
                    if (timer_sec == 0) game_state <= 3'd2;
                end

                3'd2: begin  // FILTER_SELECT
                    if (start_edge) game_state <= 3'd3;
                end

                3'd3: begin  // CAPTURE (?���? ?���?)
                    if (start_edge) game_state <= 3'd4;
                end

                3'd4: begin  // SEND (?��미�? ?��?�� �?)
                    // ?��?�� ?��?���? 버튼 ?�� �? ?�� ?��르면 ??기화면으�? 복�?
                    if (start_edge) game_state <= 3'd0;
                end

                default: game_state <= 3'd0;
            endcase
        end
    end

endmodule




// ================= EnemyManager (8 enemies + ?��?��?�� 증�?) =================

module EnemyManager (
    input logic       clk,
    input logic       reset,
    input logic [1:0] game_state,
    input logic [8:0] player_y,
    input logic [5:0] timer_sec,
    input logic       bomb_trigger,

    output logic [8:0] enemy_x             [0:7],
    output logic [8:0] enemy_y             [0:7],
    output logic       enemy_active        [0:7],
    output logic       score_up,
    output logic [3:0] enemies_killed_count
);
    localparam MOVE_RATE = 25_000_000 / 30;

    logic [31:0] move_counter;
    logic [31:0] spawn_counter;
    logic [31:0] spawn_threshold;
    logic [15:0] lfsr;
    logic [ 2:0] spawn_idx;
    logic [ 8:0] enemy_passed_y  [0:7];

    logic [ 3:0] active_count;
    logic [ 3:0] max_active;

    always_comb begin
        active_count = 0;
        for (int i = 0; i < 8; i++) begin
            if (enemy_active[i]) active_count = active_count + 1;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            move_counter         <= 0;
            spawn_counter        <= 0;
            lfsr                 <= 16'hACE1;
            spawn_idx            <= 0;
            score_up             <= 0;
            spawn_threshold      <= 25_000_000;
            max_active           <= 3;
            enemies_killed_count <= 0;

            for (int i = 0; i < 8; i++) begin
                enemy_x[i]        <= 0;
                enemy_y[i]        <= 0;
                enemy_active[i]   <= 0;
                enemy_passed_y[i] <= 0;
            end
        end else begin
            score_up             <= 0;
            enemies_killed_count <= 0;

            if (game_state == 2'd1) begin

                // [?��?��?�� 로직] ?��?��?�� ?��?? ?��?�� ?���? else�? 명확?�� 구분
                if (bomb_trigger) begin
                    enemies_killed_count <= active_count;
                    for (int i = 0; i < 8; i++) begin
                        enemy_active[i]   <= 0;
                        enemy_y[i]        <= 0;
                        enemy_passed_y[i] <= 0;
                    end
                    // ?��?�� ?���?�? 즉시 리셋 (?��?�� ?��?�� 빨리 ?��?��?���?)
                    spawn_counter <= spawn_threshold; // 바로 ?��?���? ?��?���? threshold �? ???��, 천천?��?�� 0
                    move_counter <= 0;
                end else begin
                    // ?��?��?�� ?��?�� ?���? 카운?�� 증�? �? ?��?��/?��?�� 로직 ?��?��
                    move_counter  <= move_counter + 1;
                    spawn_counter <= spawn_counter + 1;

                    // ?��?��?�� 조절
                    if (timer_sec > 20) begin
                        spawn_threshold <= 25_000_000;
                        max_active      <= 3;
                    end else if (timer_sec > 10) begin
                        spawn_threshold <= 25_000_000 / 2;
                        max_active      <= 5;
                    end else begin
                        spawn_threshold <= 25_000_000 / 3;
                        max_active      <= 8;
                    end

                    // ?��?�� 로직
                    if (move_counter >= MOVE_RATE) begin
                        move_counter <= 0;
                        for (int i = 0; i < 8; i++) begin
                            if (enemy_active[i]) begin
                                enemy_y[i] <= enemy_y[i] + 2;
                                if (enemy_y[i] > player_y && enemy_passed_y[i] <= player_y)
                                    score_up <= 1;
                                enemy_passed_y[i] <= enemy_y[i];
                                if (enemy_y[i] > 240) enemy_active[i] <= 0;
                            end
                        end
                    end

                    // ?��?�� 로직
                    if (spawn_counter >= spawn_threshold && active_count < max_active) begin
                        spawn_counter <= 0;
                        lfsr <= {
                            lfsr[14:0],
                            lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]
                        };
                        if (!enemy_active[spawn_idx]) begin
                            enemy_active[spawn_idx]   <= 1;
                            enemy_x[spawn_idx]        <= lfsr[8:0] % 9'd305;
                            enemy_y[spawn_idx]        <= 0;
                            enemy_passed_y[spawn_idx] <= 0;
                        end
                        spawn_idx <= spawn_idx + 1;
                    end
                end  // end else (bomb_trigger)

            end else if (game_state == 2'd0) begin
                move_counter    <= 0;
                spawn_counter   <= 0;
                spawn_threshold <= 25_000_000;
                max_active      <= 3;
                for (int i = 0; i < 8; i++) begin
                    enemy_active[i]   <= 0;
                    enemy_y[i]        <= 0;
                    enemy_passed_y[i] <= 0;
                end
            end
        end
    end
endmodule


// ================= CollisionDetector =================

module CollisionDetector (
    input logic       clk,
    input logic       reset,
    input logic [1:0] game_state,
    input logic [8:0] player_x,
    input logic [8:0] player_y,
    input logic       player_detected,
    input logic [8:0] enemy_x        [0:7],
    input logic [8:0] enemy_y        [0:7],
    input logic       enemy_active   [0:7],

    // [?��?��] ?��?��?�� 배열 ?��?��
    input logic [8:0] item_x     [0:1],
    input logic [8:0] item_y     [0:1],
    input logic       item_active[0:1],
    input logic       item_type  [0:1],

    output logic       item_collected [0:1], // ?��?�� ?��?��?��?�� 먹었?���? 배열�? 출력
    output logic double_score_trigger,
    output logic bomb_trigger,
    output logic collision_event,
    output logic invincible
);
    localparam PLANE_SIZE = 16;
    localparam ITEM_SIZE = 12;
    localparam INVINCIBLE_CYCLES = 25_000_000 * 1;

    logic [31:0] invincible_counter;
    logic        enemy_collision;
    logic        item_hit           [0:1];  // ?���? 충돌 ?��?���?

    assign invincible = (invincible_counter > 0);

    always_comb begin
        enemy_collision = 0;
        item_hit[0] = 0;
        item_hit[1] = 0;

        if (player_detected && game_state == 2'd1) begin
            // 1. ?�� 충돌
            for (int i = 0; i < 8; i++) begin
                if (enemy_active[i]) begin
                    if ( (player_x + PLANE_SIZE > enemy_x[i]) &&
                         (player_x < enemy_x[i] + PLANE_SIZE) &&
                         (player_y + PLANE_SIZE > enemy_y[i]) &&
                         (player_y < enemy_y[i] + PLANE_SIZE) ) begin
                        enemy_collision = 1;
                    end
                end
            end

            // 2. ?��?��?�� 충돌 (2�? 루프)
            for (int k = 0; k < 2; k++) begin
                if (item_active[k]) begin
                    if ( (player_x + PLANE_SIZE > item_x[k]) &&
                         (player_x < item_x[k] + ITEM_SIZE) &&
                         (player_y + PLANE_SIZE > item_y[k]) &&
                         (player_y < item_y[k] + ITEM_SIZE) ) begin
                        item_hit[k] = 1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            invincible_counter   <= 0;
            collision_event      <= 0;
            item_collected[0]    <= 0;
            item_collected[1]    <= 0;
            double_score_trigger <= 0;
            bomb_trigger         <= 0;
        end else begin
            // Pulse 초기?��
            collision_event      <= 0;
            item_collected[0]    <= 0;
            item_collected[1]    <= 0;
            double_score_trigger <= 0;
            bomb_trigger         <= 0;

            if (game_state == 2'd1) begin
                // 무적 처리
                if (invincible_counter > 0)
                    invincible_counter <= invincible_counter - 1;

                if (enemy_collision && invincible_counter == 0) begin
                    collision_event    <= 1;
                    invincible_counter <= INVINCIBLE_CYCLES;
                end

                // ?��?��?�� 처리 (루프 ???�� ???��?�� ?��?��)
                // Item 0
                if (item_hit[0]) begin
                    item_collected[0] <= 1;
                    if (item_type[0] == 0) double_score_trigger <= 1;
                    else bomb_trigger <= 1;
                end

                // Item 1
                if (item_hit[1]) begin
                    item_collected[1] <= 1;
                    if (item_type[1] == 0) double_score_trigger <= 1;
                    else bomb_trigger <= 1;
                end
            end else begin
                invincible_counter <= 0;
            end
        end
    end
endmodule

// ================= ScoreTimer =================

module ScoreTimer (
    input  logic       clk,
    input  logic       reset,
    input  logic [1:0] game_state,
    output logic [5:0] timer_sec
);
    localparam ONE_SEC = 25_000_000;

    logic [31:0] counter;
    logic [ 5:0] timer_internal;

    assign timer_sec = timer_internal;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter        <= 0;
            timer_internal <= 5;
        end else begin
            if (game_state == 2'd1) begin
                counter <= counter + 1;
                if (counter >= ONE_SEC) begin
                    counter <= 0;
                    if (timer_internal > 0) begin
                        timer_internal <= timer_internal - 1;
                    end
                end
            end else if (game_state == 2'd0) begin
                counter        <= 0;
                timer_internal <= 30;
            end
        end
    end
endmodule

// ================= GameOverlay (?��?�� + ?��?��?�� + UI + 2�? ?��?��?��) =================

module GameOverlay (
    input logic        clk,
    input logic        DE,
    input logic [ 9:0] x_pixel,
    input logic [ 9:0] y_pixel,
    input logic [11:0] bg_data,
    input logic [ 2:0] game_state,
    input logic [ 8:0] player_x,
    input logic [ 8:0] player_y,
    input logic        player_detected,
    input logic [ 8:0] enemy_x        [0:7],
    input logic [ 8:0] enemy_y        [0:7],
    input logic        enemy_active   [0:7],
    input logic [ 9:0] score,
    input logic [ 5:0] timer_sec,
    input logic        invincible,

    input logic [2:0] sw,

    // ?��?��?�� �??�� ?��?��
    input logic [8:0] item_x             [0:1],
    input logic [8:0] item_y             [0:1],
    input logic       item_active        [0:1],
    input logic       item_type          [0:1],
    input logic       double_score_active,

    input logic send_mode,

    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port
);
    logic [11:0] final_color;
    logic draw_player, draw_enemy, draw_text, draw_frame, draw_item;
    logic [24:0] flash_counter;

    // ???���? (깜빡?�� ?��과용)
    always_ff @(posedge clk) flash_counter <= flash_counter + 1;

    logic [8:0] sx, sy;
    assign sx = x_pixel[9:1];
    assign sy = y_pixel[9:1];

    // ?���? 카메?�� ?��
    logic [3:0] r_cam, g_cam, b_cam;
    assign r_cam = bg_data[11:8];
    assign g_cam = bg_data[7:4];
    assign b_cam = bg_data[3:0];

    // Filter_Controller?�� ?��?�� raw16 복원 (rData?? 같�? 비트 ?���? ?��?��)
    logic [15:0] raw16;
    assign raw16 = {
        r_cam,  // [15:12]
        1'b0,  // [11]
        g_cam,  // [10:7]
        2'b00,  // [6:5]
        b_cam,  // [4:1]
        1'b0  // [0]
    };

    // Filter_Controller 출력
    logic [3:0] r_filt_sw, g_filt_sw, b_filt_sw;
    logic [3:0] r_filt, g_filt, b_filt;

    // 3x3 ?��?�� 컨트롤러 ?��?��?��?��
    Filter_Controller U_FilterCtrl (
        .clk     (clk),
        .reset   (1'b0),
        .sw      (sw),
        .x_pixel ({1'b0, sx}),  // 0~319 ?��?��
        .raw_data(raw16),
        .r_final (r_filt_sw),
        .g_final (g_filt_sw),
        .b_final (b_filt_sw)
    );

    // ?��?���? ?��?��?�� ?��?�� ?�� ?��?��
    always_comb begin
        if (send_mode) begin
            // SEND 중에?�� ?��?? ?��?�� 0, 최종 ?�� 결정?��?�� ?��?��?���? ?���? 칠함
            {r_filt, g_filt, b_filt} = 12'h000;
        end else if (game_state == 3'd2 || game_state == 3'd3) begin
            // FILTER_SELECT / CAPTURE ?��?��?��?��?�� Filter_Controller 결과 ?��?��
            {r_filt, g_filt, b_filt} = {r_filt_sw, g_filt_sw, b_filt_sw};
        end else begin
            // ?��머�? ?��?��?�� ?���? 카메?�� ?��
            {r_filt, g_filt, b_filt} = {r_cam, g_cam, b_cam};
        end
    end

    // ?��?��?�� 그리�? ?��?�� ?��?��
    always_comb begin
        draw_item = 0;
        if (game_state == 3'd1) begin
            for (int i = 0; i < 2; i++) begin
                if (item_active[i]) begin
                    if (sx >= item_x[i] && sx < item_x[i] + 12 &&
                        sy >= item_y[i] && sy < item_y[i] + 12) begin
                        draw_item = 1;
                    end
                end
            end
        end
    end

    // Font
    logic [5:0] char_index;
    logic [2:0] row_addr;
    logic [2:0] col_addr;
    logic [7:0] row_data;
    logic       text_pixel_on;

    MiniFontRom U_Font (
        .char_idx(char_index),
        .row_addr(row_addr),
        .row_data(row_data)
    );

    assign text_pixel_on = row_data[7-col_addr];

    // Frame (?���? ?��?��)
    always_comb begin
        draw_frame = 0;
        if (game_state == 3'd2 || game_state == 3'd3) begin
            if (sx < 20 || sx >= 300 || sy < 20 || sy >= 220) draw_frame = 1;
        end
    end

    // Text Draw Logic
    always_comb begin
        draw_text  = 0;
        char_index = 6'd30;
        row_addr   = 0;
        col_addr   = 0;

        if (send_mode) begin
            // SEND ?���?: 중앙?�� SEND
            if (sy >= 100 && sy < 108 && sx >= 132 && sx < 164) begin
                row_addr = sy - 100;
                col_addr = sx - 132;
                case ((sx - 132) >> 3)
                    0: char_index = 6'd17;  // S
                    1: char_index = 6'd11;  // E
                    2: char_index = 6'd24;  // N
                    3: char_index = 6'd25;  // D
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end
        end else if (game_state == 3'd0) begin
            // WAIT
            if (sy >= 100 && sy < 108 && sx >= 120 && sx < 200) begin
                row_addr = sy - 100;
                col_addr = sx - 120;
                case ((sx - 120) >> 3)
                    0: char_index = 6'd12;  // G
                    1: char_index = 6'd10;  // A
                    2: char_index = 6'd13;  // M
                    3: char_index = 6'd11;  // E
                    4: char_index = 6'd30;
                    5: char_index = 6'd17;  // S
                    6: char_index = 6'd18;  // T
                    7: char_index = 6'd10;  // A
                    8: char_index = 6'd16;  // R
                    9: char_index = 6'd18;  // T
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end
        end else if (game_state == 3'd1) begin
            // PLAY: SCORE, TIMER
            if (sy >= 4 && sy < 12) begin
                if (sx >= 4 && sx < 52) begin
                    row_addr = sy - 4;
                    col_addr = sx - 4;
                    case ((sx - 4) >> 3)
                        0: char_index = 6'd17;  // S
                        3: char_index = (score / 100);
                        4: char_index = (score / 10) % 10;
                        5: char_index = (score % 10);
                        default: char_index = 6'd30;
                    endcase
                    if (text_pixel_on) draw_text = 1;
                end
            end

            if (sy >= 4 && sy < 12 && sx >= 280 && sx < 312) begin
                row_addr = sy - 4;
                col_addr = sx - 280;
                case ((sx - 280) >> 3)
                    0: char_index = 6'd18;  // T
                    2: char_index = (timer_sec / 10);
                    3: char_index = (timer_sec % 10);
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end
        end else if (game_state == 3'd2 || game_state == 3'd3) begin

            // 1. ?���? (SPACE WAR)
            // if ?��?���?(124)�? 뺄셈�?(124)?�� ?��?��
            if (sy >= 30 && sy < 38 && sx >= 124 && sx < 196) begin
                row_addr = sy - 30;
                col_addr = sx - 124;  // [?��?��] 120 -> 124
                case ((sx - 124) >> 3)  // [?��?��] 120 -> 124
                    0: char_index = 6'd17;  // S
                    1: char_index = 6'd15;  // P
                    2: char_index = 6'd10;  // A
                    3: char_index = 6'd20;  // C
                    4: char_index = 6'd11;  // E
                    5: char_index = 6'd30;
                    6: char_index = 6'd22;  // W
                    7: char_index = 6'd10;  // A
                    8: char_index = 6'd16;  // R
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end

            // 2. ?��?�� (SCORE 000)
            // if ?��?���?(124)�? 뺄셈�?(124)?�� ?��?��
            if (sy >= 45 && sy < 53 && sx >= 124 && sx < 196) begin
                row_addr = sy - 45;
                col_addr = sx - 124;    // [?��?��] 130 -> 124 (?��?�� 코드?�� ?��?���? ?��???�� 깨졌?�� 것임)
                case ((sx - 124) >> 3)  // [?��?��] 130 -> 124
                    0: char_index = 6'd17;  // S
                    1: char_index = 6'd20;  // C
                    2: char_index = 6'd14;  // O
                    3: char_index = 6'd16;  // R
                    4: char_index = 6'd11;  // E
                    5: char_index = 6'd30;
                    6: char_index = (score / 100);
                    7: char_index = (score / 10) % 10;
                    8: char_index = (score % 10);  
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end

            // 3. 메뉴 (SELECT FRAME) -> 질문?��?�� �?�?
            // if ?��?���?(112)�? 뺄셈�?(112)?�� ?��?��
            if (sy >= 60 && sy < 68 && sx >= 112 && sx < 208) begin
                row_addr = sy - 60;
                col_addr = sx - 112;  // [?��?��] 110 -> 112
                case ((sx - 112) >> 3)  // [?��?��] 110 -> 112
                    0: char_index = 6'd17;  // S (?��?�� ?�� ?���?)
                    1: char_index = 6'd11;  // E
                    2: char_index = 6'd23;  // L
                    3: char_index = 6'd11;  // E
                    4: char_index = 6'd20;  // C
                    5: char_index = 6'd18;  // T
                    6: char_index = 6'd30;
                    7: char_index = 6'd21;  // F
                    8: char_index = 6'd16;  // R
                    9: char_index = 6'd10;  // A
                    10: char_index = 6'd13;  // M
                    11: char_index = 6'd11;  // E
                    default: char_index = 6'd30;
                endcase
                if (text_pixel_on) draw_text = 1;
            end
        end
    end
    // Player draw
    always_comb begin
        draw_player = 0;
        if (!send_mode &&
            player_detected && game_state == 3'd1 &&
            sx >= player_x && sx < player_x + 16 &&
            sy >= player_y && sy < player_y + 16) begin
            draw_player = 1;
        end
    end

    // Enemy draw
    always_comb begin
        draw_enemy = 0;
        if (!send_mode) begin
            for (int i = 0; i < 8; i++) begin
                if (enemy_active[i] &&
                    sx >= enemy_x[i] && sx < enemy_x[i] + 16 &&
                    sy >= enemy_y[i] && sy < enemy_y[i] + 16) begin
                    draw_enemy = 1;
                end
            end
        end
    end

    // 최종 ?�� 결정
    always_comb begin
        if (send_mode) begin
            // SEND �?: �??? 배경 + ?��?��?���? ?��???��
            final_color = 12'h000;
            if (draw_text) final_color = 12'hFF0;
        end else begin
            final_color = {r_filt, g_filt, b_filt};

            if (draw_frame) begin
                if ((sx[2] ^ sy[3]) && (sx[4] & sy[2])) final_color = 12'hFFF;
                else final_color = 12'h113;
            end

            if (game_state == 3'd1) begin
                if (draw_player) final_color = invincible ? 12'hF0F : 12'h0F0;
                if (draw_enemy) final_color = 12'hF00;

                if (draw_item) begin
                    for (int i = 0; i < 2; i++) begin
                        if (item_active[i] &&
                            sx >= item_x[i] && sx < item_x[i] + 12 &&
                            sy >= item_y[i] && sy < item_y[i] + 12) begin
                            if (item_type[i] == 0) begin
                                final_color = 12'hFF0;  // ?���? ?��코어 ?��?��?��
                            end else begin
                                // ?��?�� ?��?��?�� 깜빡?��
                                if (flash_counter[24]) final_color = 12'hF00;
                                else final_color = 12'h000;
                            end
                        end
                    end
                end
            end

            if (draw_text) begin
                if (game_state == 3'd1) begin
                    final_color = double_score_active ? 12'hFF0 : 12'hFFF;
                end else begin
                    final_color = 12'hFF0;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (DE) {r_port, g_port, b_port} <= final_color;
        else {r_port, g_port, b_port} <= 12'h000;
    end
endmodule


module ScoreManager (
    input  logic        clk,
    input  logic        reset,
    input  logic [2:0]  game_state,  // [수정] 3비트 입력
    input  logic        score_up,
    input  logic        collision_event,
    input  logic        double_score_active,
    input  logic        bomb_trigger,
    input  logic [3:0]  enemies_killed_count,
    output logic [9:0]  score
);
    logic [4:0] points_to_add;

    always_comb begin
        if (bomb_trigger) begin
            if (double_score_active)
                points_to_add = {1'b0, enemies_killed_count} * 2;
            else points_to_add = {1'b0, enemies_killed_count};
        end else begin
            points_to_add = 0;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            score <= 0;
        end else begin
            // [수정] 상태 0(WAIT)에서만 점수 초기화
            if (game_state == 3'd0) begin
                score <= 0;
            end else if (game_state == 3'd1) begin // 게임 진행 중
                if (collision_event) begin
                    if (score > 0) score <= score - 1;
                end 
                else if (bomb_trigger) begin
                    if (score + points_to_add <= 999)
                        score <= score + points_to_add;
                    else score <= 999;
                end 
                else if (score_up) begin
                    if (score < 999) begin
                        if (double_score_active) begin
                            if (score + 2 <= 999) score <= score + 2;
                            else score <= 999;
                        end else begin
                            score <= score + 1;
                        end
                    end
                end
            end
            // State 2, 3, 4에서는 현재 점수를 그대로 유지
        end
    end
endmodule

module ItemManager (
    input logic       clk,
    input logic       reset,
    input logic [1:0] game_state,

    input logic [8:0] enemy_x     [0:7],
    input logic [8:0] enemy_y     [0:7],
    input logic       enemy_active_all[0:7],

    // [?��?��] 배열�? �?�? (2�?)
    output logic [8:0] item_x        [0:1],
    output logic [8:0] item_y        [0:1],
    output logic       item_active   [0:1],
    output logic       item_type     [0:1],
    input  logic       item_collected[0:1]
);
    // 2초마?�� ?��?�� ?��?��
    localparam MOVE_RATE = 25_000_000 / 30;
    localparam SPAWN_THRESHOLD = 25_000_000 * 2;
    localparam SAFE_DIST = 9'd32;

    logic [31:0] move_counter;
    logic [31:0] spawn_counter;
    logic [15:0] lfsr;
    logic        next_type_toggle;  // 번갈?�� ?��?��기용

    logic [ 8:0] candidate_x;
    logic        spawn_safe_from_enemies;
    logic        spawn_safe_from_items;

    assign candidate_x = (lfsr[8:0] % 300) + 10;

    // 1. ?��?��과의 거리 �??��
    always_comb begin
        spawn_safe_from_enemies = 1;
        for (int i = 0; i < 8; i++) begin
            if (enemy_active_all[i] && enemy_y[i] < 50) begin
                if (candidate_x > enemy_x[i]) begin
                    if ((candidate_x - enemy_x[i]) < SAFE_DIST)
                        spawn_safe_from_enemies = 0;
                end else begin
                    if ((enemy_x[i] - candidate_x) < SAFE_DIST)
                        spawn_safe_from_enemies = 0;
                end
            end
        end
    end

    // 2. ?���? ?��?��?��과의 거리 �??�� (?��?��?��?���? 겹치�? ?���?)
    always_comb begin
        spawn_safe_from_items = 1;
        for (int i = 0; i < 2; i++) begin
            if (item_active[i] && item_y[i] < 50) begin
                if (candidate_x > item_x[i]) begin
                    if ((candidate_x - item_x[i]) < SAFE_DIST)
                        spawn_safe_from_items = 0;
                end else begin
                    if ((item_x[i] - candidate_x) < SAFE_DIST)
                        spawn_safe_from_items = 0;
                end
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            move_counter <= 0;
            spawn_counter <= 0;
            lfsr <= 16'hFEED;
            next_type_toggle <= 0;
            for (int i = 0; i < 2; i++) begin
                item_x[i] <= 0;
                item_y[i] <= 0;
                item_active[i] <= 0;
                item_type[i] <= 0;
            end
        end else begin
            if (game_state == 2'd1) begin
                // ?��?�� 로직
                move_counter <= move_counter + 1;
                if (move_counter >= MOVE_RATE) begin
                    move_counter <= 0;
                    for (int i = 0; i < 2; i++) begin
                        if (item_active[i]) begin
                            item_y[i] <= item_y[i] + 2;
                            if (item_y[i] > 240) item_active[i] <= 0;
                        end
                    end
                end

                // ?���? 처리
                for (int i = 0; i < 2; i++) begin
                    if (item_collected[i]) item_active[i] <= 0;
                end

                // ?��?�� 로직
                spawn_counter <= spawn_counter + 1;
                if (spawn_counter >= SPAWN_THRESHOLD) begin
                    spawn_counter <= 0;
                    lfsr <= {
                        lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]
                    };

                    // ?��?��?�� ?���? ?��?�� ?��?��
                    if (spawn_safe_from_enemies && spawn_safe_from_items) begin
                        // �? ?���? 찾기 (0번이 비었?���? 0�?, ?��?���? 1�? ?��?��)
                        if (!item_active[0]) begin
                            item_active[0]   <= 1;
                            item_x[0]        <= candidate_x;
                            item_y[0]        <= 0;
                            item_type[0]     <= next_type_toggle;
                            next_type_toggle <= ~next_type_toggle;
                        end else if (!item_active[1]) begin
                            item_active[1]   <= 1;
                            item_x[1]        <= candidate_x;
                            item_y[1]        <= 0;
                            item_type[1]     <= next_type_toggle;
                            next_type_toggle <= ~next_type_toggle;
                        end
                    end
                end
            end else begin
                // 게임 �? ?��?�� ?�� 초기?��
                for (int i = 0; i < 2; i++) item_active[i] <= 0;
                spawn_counter <= 0;
            end
        end
    end
endmodule

// ?��?��?��?�� 먹었?�� ?�� 4초간 ?��?���? ?���?

module BuffController (
    input logic clk,
    input logic reset,
    input logic game_state_play,  // game_state == 1
    input logic item_collected,  // ?��?��?�� 먹음 ?��벤트
    output logic double_score_active  // ?��?�� 2�? ?��?��?�� ?��?��
);
    // 4�? * 25MHz
    localparam DURATION = 25_000_000 * 4;
    logic [31:0] timer;

    assign double_score_active = (timer > 0);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            timer <= 0;
        end else begin
            if (game_state_play) begin
                if (item_collected) begin
                    timer <= DURATION;  // ???���? 리필 (4�?)
                end else if (timer > 0) begin
                    timer <= timer - 1;
                end
            end else begin
                timer <= 0;
            end
        end
    end
endmodule