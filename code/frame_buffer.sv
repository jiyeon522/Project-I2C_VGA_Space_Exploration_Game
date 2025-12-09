module frame_buffer (
    input  logic        wclk,
    input  logic        we,
    input  logic [16:0] wAddr,
    input  logic [15:0] wData, // 입력은 16비트 (RGB565)
    input  logic        rclk,
    input  logic        oe,
    input  logic [16:0] rAddr,
    output logic [15:0] rData  // 출력은 16비트 포맷 유지 (하위비트 0 채움)
);
    // [최적화] 16비트가 아닌 12비트만 저장 (RGB444) -> BRAM 25% 절약
    (* ram_style = "block" *) // 얘는 용량이 커서 BRAM을 써야 함
    logic [11:0] mem [0:76799]; // 320 * 240

    // Write Side (16bit -> 12bit Truncation)
    always_ff @(posedge wclk) begin
        if (we) begin
            // RGB565 (R:5, G:6, B:5) -> RGB444 (R:4, G:4, B:4)로 변환하여 저장
            // R[15:12], G[10:7], B[4:1]
            mem[wAddr] <= {wData[15:12], wData[10:7], wData[4:1]};
        end
    end

    // Read Side (12bit -> 16bit Padding)
    logic [11:0] data_out;
    always_ff @(posedge rclk) begin
        if (oe) begin
            data_out <= mem[rAddr];
        end
    end

    // 읽어낸 12비트를 다시 16비트 그릇에 담아 내보냄 (나머지 비트는 0)
    // R: [11:8], G: [7:4], B: [3:0]
    assign rData = {data_out[11:8], 1'b0, data_out[7:4], 2'b00, data_out[3:0], 1'b0};

endmodule