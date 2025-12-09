`timescale 1ns / 1ps

module btn_debounce(
    input clk,
    input rst,
    input i_btn,
    output o_btn
    );

    // 1. 입력 신호 동기화 (Metastability 방지)
    // 외부 입력(i_btn)을 내부 클럭(clk)에 동기화하여 글리치 및 타이밍 에러 방지
    reg btn_sync_0, btn_sync_1;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= i_btn;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // 2. 디바운싱 로직 (카운터 기반)
    // 버튼 상태가 변경되었을 때, 일정 시간(10ms) 동안 안정적으로 유지되는지 확인
    // 25MHz 클럭 기준: 10ms = 250,000 사이클
    localparam CNT_MAX = 250_000;
    reg [17:0] counter;
    reg btn_stable;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= 0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_sync_1 == btn_stable) begin
                counter <= 0; // 입력이 현재 상태와 같으면 카운터 리셋
            end else begin
                counter <= counter + 1;
                if (counter == CNT_MAX) begin
                    btn_stable <= btn_sync_1; // 카운터가 차면 상태 업데이트
                    counter <= 0;
                end
            end
        end
    end

    // 3. 엣지 검출 (Rising Edge Detection)
    // 안정된 신호(btn_stable)의 상승 엣지에서 1클럭 주기 펄스 생성
    reg btn_prev;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            btn_prev <= 1'b0;
        end else begin
            btn_prev <= btn_stable;
        end
    end

    assign o_btn = btn_stable & ~btn_prev;

endmodule