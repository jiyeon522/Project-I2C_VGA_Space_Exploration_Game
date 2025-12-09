`timescale 1ns / 1ps

module OV7670_CCTV_Game (
    input logic       clk,        // 100MHz System Clock
    input logic       reset,
    input logic       start_btn,  // 물리 버튼 (노이즈가 포함될 수 있음)
    input logic [2:0] sw,         // 필터 스위치

    // OV7670 Camera Interface
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,

    // VGA Interface
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,

    // I2C Interface
    inout logic sda,
    inout logic scl,

    // UART Interface
    output logic RsTx
);
    logic        sys_clk;  // 25MHz (VGA & Game Logic Clock)
    logic        DE;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;

    // Frame buffer signals
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic        cam_we;
    logic        buffer_we;
    logic [16:0] wAddr;
    logic [15:0] wData;
    
    // Game signals
    logic [ 8:0] player_x;
    
    // Address MUX signals
    logic [16:0] rAddr_display;
    logic [16:0] rAddr_detector;
    logic [16:0] rAddr_uart;
    
    logic        detector_scanning;
    logic [ 8:0] cam_x;
    logic [ 8:0] cam_y;

    logic        player_detected;
    logic [ 9:0] score;
    logic [ 5:0] timer_sec;
    logic [ 2:0] game_state;
    
    // Data from Game Controller for UART
    logic [ 8:0] enemy_x      [0:7];
    logic [ 8:0] enemy_y      [0:7];
    logic        enemy_active [0:7];
    
    logic [ 8:0] item_x       [0:1];
    logic [ 8:0] item_y       [0:1];
    logic        item_active  [0:1];
    logic        item_type    [0:1];
    
    logic        double_score_active;
    logic [11:0] bg_data;

    // [중요] Controller와 Sender를 연결하는 무적 신호 와이어
    logic        w_invincible;

    // 디바운싱된 버튼 신호
    logic        start_btn_debounced;

    // -----------------------------------------------------------
    // Logic Assigns
    // -----------------------------------------------------------
    assign xclk = sys_clk;

    // CAPTURE(3), SEND(4) 상태에서 메모리 write 중단 (화면 정지 효과)
    assign buffer_we = (game_state >= 3'd3) ? 1'b0 : cam_we;

    // HDMI/VGA 출력 주소 계산 (좌우 반전 Mirroring)
    assign cam_x = x_pixel[9:1];
    assign cam_y = y_pixel[9:1];
    assign rAddr_display = cam_y * 9'd320 + (9'd319 - cam_x);

    // VGA / Detector / UART 주소 MUX
    // 우선순위: UART 전송 > Detector 스캐닝 > VGA 디스플레이
    always_comb begin
        if (game_state == 3'd4) begin
            rAddr = rAddr_uart;
        end else if (detector_scanning && !DE) begin
            rAddr = rAddr_detector;
        end else begin
            rAddr = rAddr_display;
        end
    end

    // 배경 데이터 준비 (Overlay Controller로 전달)
    always_comb begin
        bg_data = {rData[15:12], rData[10:7], rData[4:1]};
    end

    // -----------------------------------------------------------
    // Module Instantiations
    // -----------------------------------------------------------

    // 1. 버튼 디바운서
    // sys_clk(25MHz)를 사용하여 게임 로직과 동기화
    btn_debounce U_Start_Btn_Debounce (
        .clk  (sys_clk),            // 게임 로직 클럭 사용
        .rst  (reset),
        .i_btn(start_btn),          // 물리 버튼 입력
        .o_btn(start_btn_debounced) // 깨끗한 출력 신호
    );

    // 2. Game Data Sender (UART)
    Game_Data_Sender U_GameSender (
        .clk                (clk),
        .reset              (reset),
        .vsync              (vsync),
        .player_x           (player_x),
        .enemy_x_all        (enemy_x),
        .enemy_y_all        (enemy_y),
        .item_x             (item_x),
        .item_y             (item_y),
        .item_active        (item_active),
        .item_type          (item_type),
        .double_score_active(double_score_active),
        .invincible         (w_invincible),       // [연결] 무적 상태 입력
        .score              (score),
        .timer_sec          (timer_sec),
        .game_state         (game_state),
        .btn_pressed        (start_btn_debounced), // 디바운싱된 신호 사용
        .sw                 (sw),
        .frame_data         (rData),
        .frame_addr         (rAddr_uart),
        .uart_tx            (RsTx)
    );

    // 3. 카메라 설정 (I2C)
    OV7670_Config_I2C U_CFG (
        .clk  (sys_clk),
        .reset(reset),
        .scl  (scl),
        .sda  (sda)
    );

    // 4. 픽셀 클럭 생성 (25MHz)
    pclk_gen U_PXL_CLK (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );

    // 5. VGA 동기 신호 생성
    VGA_Syncher U_VGA_Syncher (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    // 6. 프레임 버퍼 (Block RAM)
    frame_buffer U_FrameBuffer (
        .wclk (pclk),
        .we   (buffer_we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (clk),
        .oe   (1'b1),
        .rAddr(rAddr),
        .rData(rData)
    );

    // 7. OV7670 메모리 컨트롤러 (카메라 데이터 수신)
    OV7670_Mem_Controller U_OV7670_Mem_Controller (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (cam_we),
        .wAddr(wAddr),
        .wData(wData)
    );

    // 8. 플레이어 검출기 (Red Detection)
    RedDetector U_RedDetector (
        .clk            (sys_clk),
        .reset          (reset),
        .vsync          (vsync),
        .DE             (DE),
        .frame_data     (rData),
        .frame_addr     (rAddr_detector),
        .scanning       (detector_scanning),
        .player_x       (player_x),
        .player_y       (), // y좌표는 컨트롤러 내부 상수 사용하므로 연결 안 함
        .player_detected(player_detected)
    );

    // 9. Game Controller Top (게임 로직 + 오버레이)
    Game_Controller_Top U_Game_Controller_Top (
        .clk                (sys_clk),
        .reset              (reset),
        .start_btn          (start_btn_debounced), // 디바운싱된 신호 사용
        
        // VGA & Camera Info (Overlay Input)
        .DE                 (DE),
        .x_pixel            (x_pixel),
        .y_pixel            (y_pixel),
        .bg_data            (bg_data),
        .sw                 (sw),

        // Player Info
        .player_x           (player_x),
        .player_detected    (player_detected),
        
        // VGA Output
        .r_port             (r_port),
        .g_port             (g_port),
        .b_port             (b_port),

        // UART Data Outputs
        .game_state         (game_state),
        .score              (score),
        .timer_sec          (timer_sec),
        .invincible         (w_invincible),        // [연결] 무적 상태 출력
        .double_score_active(double_score_active),
        .enemy_x            (enemy_x),
        .enemy_y            (enemy_y),
        .enemy_active       (enemy_active),
        .item_x             (item_x),
        .item_y             (item_y),
        .item_active        (item_active),
        .item_type          (item_type)
    );

endmodule

module btn_debounce_GOOD (
    input clk,      // 25MHz 시스템 클럭 (유일한 클럭)
    input rst,
    input i_btn,    // 외부 비동기 입력
    output o_btn
);
    // 1. 입력 동기화 (CDC 해결)
    // 외부 신호를 내부 클럭에 줄세우기 (Metastability 방지)
    reg btn_sync_0, btn_sync_1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_sync_0 <= 0;
            btn_sync_1 <= 0;
        end else begin
            btn_sync_0 <= i_btn;
            btn_sync_1 <= btn_sync_0; // ✅ 안전하게 동기화된 신호
        end
    end

    // 2. 동기식 카운터 (Enable 신호 사용)
    // 클럭을 나누지 않고, 카운터를 이용해 '시간'만 잰다.
    reg [17:0] counter;
    reg btn_stable;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            btn_stable <= 0;
        end else begin
            // 입력이 변하면 카운터 리셋, 유지되면 카운트 증가
            if (btn_sync_1 == btn_stable) begin
                counter <= 0;
            end else begin
                counter <= counter + 1;
                if (counter == 250_000) begin // 10ms 경과
                    btn_stable <= btn_sync_1; // 상태 업데이트
                    counter <= 0;
                end
            end
        end
    end

    // 3. 엣지 검출 (Rising Edge)
    reg btn_prev;
    always @(posedge clk) btn_prev <= btn_stable;
    
    assign o_btn = btn_stable & ~btn_prev;

endmodule