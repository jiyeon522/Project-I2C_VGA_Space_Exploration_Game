`timescale 1ns / 1ps

module OV7670_Mem_Controller (
    input  logic        pclk,
    input  logic        reset,
    // OV7670 side
    input  logic        href,
    input  logic        vsync,
    input  logic [ 7:0] data,
    // Memory side
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);

    logic [15:0] pixel_buffer;
    logic        byte_toggle; 
    
    // 0: 초기 동기 대기
    // 1: VSYNC low 기다리면서 주소/토글 리셋
    // 2: 실제 픽셀 저장
    logic [1:0] state;

    assign wData = pixel_buffer;

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            wAddr        <= 0;
            byte_toggle  <= 0;
            we           <= 0;
            pixel_buffer <= 0;
            state        <= 0;
        end else begin
            case (state)
                // 초기: 첫 VSYNC를 기다림
                2'd0: begin
                    we <= 0;
                    if (vsync == 1'b1)
                        state <= 2'd1;
                end

                // VSYNC high 동안: 다음 프레임 준비
                2'd1: begin
                    we          <= 0;
                    wAddr       <= 0;
                    byte_toggle <= 0;
                    if (vsync == 1'b0)
                        state <= 2'd2;
                end

                // 실제 픽셀 수집/저장
                2'd2: begin
                    // 새 프레임 시작
                    if (vsync == 1'b1) begin
                        state <= 2'd1;
                        we    <= 0;
                    end
                    // 라인 유효일 때만 저장
                    else if (href == 1'b1) begin
                        if (byte_toggle == 1'b0) begin
                            pixel_buffer[15:8] <= data;
                            we                 <= 0;
                            byte_toggle        <= 1'b1;
                        end else begin
                            pixel_buffer[7:0] <= data;
                            we                <= 1'b1;
                            byte_toggle       <= 1'b0;

                            if (wAddr < 17'd76799)
                                wAddr <= wAddr + 1;
                        end
                    end else begin
                        we          <= 0;
                        byte_toggle <= 0; // 줄 바뀔 때 상/하위 바이트 순서 초기화
                    end
                end

                default: state <= 2'd0;
            endcase
        end
    end
endmodule
