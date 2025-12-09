`timescale 1ns / 1ps

module Filter_Controller (
    input logic        clk,
    input logic        reset,
    input logic [ 2:0] sw,       // 0~7 ?��?�� ?��?��
    input logic [ 9:0] x_pixel,  // ?��?�� x 좌표 (0~319)
    input logic [15:0] raw_data, // ?���? ?��?��?�� (RGB565)

    output logic [3:0] r_final,
    output logic [3:0] g_final,
    output logic [3:0] b_final
);

    // 1. Line Buffers (3x3 ?��?��?�� ?��?��)
    localparam LINE_WIDTH = 320;

    logic [15:0] line_buf_0[0:LINE_WIDTH-1];
    logic [15:0] line_buf_1[0:LINE_WIDTH-1];
    logic [15:0] window[0:8];
    logic [8:0] ptr;

    assign ptr = x_pixel[8:0];

    always_ff @(posedge clk) begin
        if (x_pixel < LINE_WIDTH) begin
            window[0] <= window[1];
            window[1] <= window[2];
            window[3] <= window[4];
            window[4] <= window[5];
            window[6] <= window[7];
            window[7] <= window[8];

            window[2] <= line_buf_1[ptr];
            window[5] <= line_buf_0[ptr];
            line_buf_1[ptr] <= line_buf_0[ptr];

            window[8] <= raw_data;
            line_buf_0[ptr] <= raw_data;
        end
    end

    // 2. ?��?�� 모듈 ?���?
    logic [3:0] r_raw, g_raw, b_raw;
    logic [3:0] r_inv, g_inv, b_inv;
    logic [3:0] r_gau, g_gau, b_gau;
    logic [3:0] r_sob, g_sob, b_sob;
    logic [3:0] r_sep, g_sep, b_sep;
    logic [3:0] r_emb, g_emb, b_emb;
    logic [3:0] r_shp, g_shp, b_shp;
    logic [3:0] r_sol, g_sol, b_sol;

    // ?���? (중앙 ?��??)
    assign r_raw = window[4][15:12];
    assign g_raw = window[4][10:7];
    assign b_raw = window[4][4:1];

    filter_invert U_Invert (
        .imgData(window[4]),
        .r_out  (r_inv),
        .g_out  (g_inv),
        .b_out  (b_inv)
    );
    filter_gaussian U_Gaussian (
        .pixel_3x3(window),
        .r_out(r_gau),
        .g_out(g_gau),
        .b_out(b_gau)
    );
    filter_sobel U_Sobel (
        .pixel_3x3(window),
        .r_out(r_sob),
        .g_out(g_sob),
        .b_out(b_sob)
    );
    filter_sepia U_Sepia (
        .imgData(window[4]),
        .r_out  (r_sep),
        .g_out  (g_sep),
        .b_out  (b_sep)
    );
    filter_emboss U_Emboss (
        .pixel_3x3(window),
        .r_out(r_emb),
        .g_out(g_emb),
        .b_out(b_emb)
    );
    filter_sharpen U_Sharpen (
        .pixel_3x3(window),
        .r_out(r_shp),
        .g_out(g_shp),
        .b_out(b_shp)
    );
    filter_solarize U_Solarize (
        .imgData(window[4]),
        .r_out  (r_sol),
        .g_out  (g_sol),
        .b_out  (b_sol)
    );

    // 3. 결과 ?��?��
    always_comb begin
        case (sw)
            3'b000:
            {r_final, g_final, b_final} = {r_raw, g_raw, b_raw};  // ?���?
            3'b001:
            {r_final, g_final, b_final} = {r_inv, g_inv, b_inv};  // 반전
            3'b010:
            {r_final, g_final, b_final} = {
                r_gau, g_gau, b_gau
            };  // �??��?��?��
            3'b011:
            {r_final, g_final, b_final} = {r_sob, g_sob, b_sob};  // ?���?
            3'b100:
            {r_final, g_final, b_final} = {r_sep, g_sep, b_sep};  // ?��?��?��
            3'b101:
            {r_final, g_final, b_final} = {r_emb, g_emb, b_emb};  // ?��보싱
            3'b110:
            {r_final, g_final, b_final} = {r_shp, g_shp, b_shp};  // ?��?��
            3'b111:
            {r_final, g_final, b_final} = {
                r_sol, g_sol, b_sol
            };  // ?��?��?��?���?
            default: {r_final, g_final, b_final} = {r_raw, g_raw, b_raw};
        endcase
    end
endmodule

// --- Sub Modules ---
module filter_invert (
    input  logic [15:0] imgData,
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    assign {r_out, g_out, b_out} = {
        ~imgData[15:12], ~imgData[10:7], ~imgData[4:1]
    };
endmodule

module filter_gaussian (
    input  logic [15:0] pixel_3x3[0:8],
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic [11:0] sum_r, sum_g, sum_b;
    logic [3:0] pr[0:8];
    logic [3:0] pg[0:8];
    logic [3:0] pb[0:8];
    integer i;
    always_comb begin
        for (i = 0; i < 9; i = i + 1) begin
            pr[i] = pixel_3x3[i][15:12];
            pg[i] = pixel_3x3[i][10:7];
            pb[i] = pixel_3x3[i][4:1];
        end
        sum_r = pr[0]+(pr[1]<<1)+pr[2]+(pr[3]<<1)+(pr[4]<<2)+(pr[5]<<1)+pr[6]+(pr[7]<<1)+pr[8];
        sum_g = pg[0]+(pg[1]<<1)+pg[2]+(pg[3]<<1)+(pg[4]<<2)+(pg[5]<<1)+pg[6]+(pg[7]<<1)+pg[8];
        sum_b = pb[0]+(pb[1]<<1)+pb[2]+(pb[3]<<1)+(pb[4]<<2)+(pb[5]<<1)+pb[6]+(pb[7]<<1)+pb[8];
    end
    assign {r_out, g_out, b_out} = {sum_r[7:4], sum_g[7:4], sum_b[7:4]};
endmodule

module filter_sobel (
    input  logic [15:0] pixel_3x3[0:8],
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic signed [8:0] gx_r, gy_r, gx_g, gy_g, gx_b, gy_b;
    logic [8:0] sum_r, sum_g, sum_b;
    logic [3:0] pr[0:8];
    logic [3:0] pg[0:8];
    logic [3:0] pb[0:8];
    integer i;
    always_comb begin
        for (i = 0; i < 9; i = i + 1) begin
            pr[i] = pixel_3x3[i][15:12];
            pg[i] = pixel_3x3[i][10:7];
            pb[i] = pixel_3x3[i][4:1];
        end
        gx_r  = (pr[2] + (pr[5] << 1) + pr[8]) - (pr[0] + (pr[3] << 1) + pr[6]);
        gy_r  = (pr[0] + (pr[1] << 1) + pr[2]) - (pr[6] + (pr[7] << 1) + pr[8]);
        gx_g  = (pg[2] + (pg[5] << 1) + pg[8]) - (pg[0] + (pg[3] << 1) + pg[6]);
        gy_g  = (pg[0] + (pg[1] << 1) + pg[2]) - (pg[6] + (pg[7] << 1) + pg[8]);
        gx_b  = (pb[2] + (pb[5] << 1) + pb[8]) - (pb[0] + (pb[3] << 1) + pb[6]);
        gy_b  = (pb[0] + (pb[1] << 1) + pb[2]) - (pb[6] + (pb[7] << 1) + pb[8]);
        sum_r = (gx_r < 0 ? -gx_r : gx_r) + (gy_r < 0 ? -gy_r : gy_r);
        sum_g = (gx_g < 0 ? -gx_g : gx_g) + (gy_g < 0 ? -gy_g : gy_g);
        sum_b = (gx_b < 0 ? -gx_b : gx_b) + (gy_b < 0 ? -gy_b : gy_b);
    end
    assign r_out = (sum_r[8:1] > 15) ? 4'hF : sum_r[4:1];
    assign g_out = (sum_g[8:1] > 15) ? 4'hF : sum_g[4:1];
    assign b_out = (sum_b[8:1] > 15) ? 4'hF : sum_b[4:1];
endmodule

module filter_sepia (
    input  logic [15:0] imgData,
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic [5:0] gray;
    assign gray  = (imgData[15:12] + imgData[10:7] + imgData[4:1]) / 3;
    assign r_out = (gray > 12) ? 4'hF : (gray + 3);
    assign g_out = (gray > 13) ? 4'hF : (gray + 2);
    assign b_out = (gray < 2) ? 4'h0 : (gray - 1);
endmodule

module filter_emboss (
    input  logic [15:0] pixel_3x3[0:8],
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic signed [7:0] res_r, res_g, res_b;
    logic [3:0] pr[0:8];
    logic [3:0] pg[0:8];
    logic [3:0] pb[0:8];
    integer i;
    always_comb begin
        for (i = 0; i < 9; i = i + 1) begin
            pr[i] = pixel_3x3[i][15:12];
            pg[i] = pixel_3x3[i][10:7];
            pb[i] = pixel_3x3[i][4:1];
        end
        res_r = ($signed({1'b0, pr[8]}) - $signed({1'b0, pr[0]})) + 8;
        res_g = ($signed({1'b0, pg[8]}) - $signed({1'b0, pg[0]})) + 8;
        res_b = ($signed({1'b0, pb[8]}) - $signed({1'b0, pb[0]})) + 8;
    end
    assign r_out = (res_r < 0) ? 4'h0 : (res_r > 15) ? 4'hF : res_r[3:0];
    assign g_out = (res_g < 0) ? 4'h0 : (res_g > 15) ? 4'hF : res_g[3:0];
    assign b_out = (res_b < 0) ? 4'h0 : (res_b > 15) ? 4'hF : res_b[3:0];
endmodule

module filter_sharpen (
    input  logic [15:0] pixel_3x3[0:8],
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic signed [8:0] val_r, val_g, val_b;
    logic [3:0] pr[0:8];
    logic [3:0] pg[0:8];
    logic [3:0] pb[0:8];
    integer i;
    always_comb begin
        for (i = 0; i < 9; i = i + 1) begin
            pr[i] = pixel_3x3[i][15:12];
            pg[i] = pixel_3x3[i][10:7];
            pb[i] = pixel_3x3[i][4:1];
        end
        val_r = (pr[4] * 5) - (pr[1] + pr[3] + pr[5] + pr[7]);
        val_g = (pg[4] * 5) - (pg[1] + pg[3] + pg[5] + pg[7]);
        val_b = (pb[4] * 5) - (pb[1] + pb[3] + pb[5] + pb[7]);
    end
    assign r_out = (val_r < 0) ? 4'h0 : (val_r > 15) ? 4'hF : val_r[3:0];
    assign g_out = (val_g < 0) ? 4'h0 : (val_g > 15) ? 4'hF : val_g[3:0];
    assign b_out = (val_b < 0) ? 4'h0 : (val_b > 15) ? 4'hF : val_b[3:0];
endmodule

module filter_solarize (
    input  logic [15:0] imgData,
    output logic [ 3:0] r_out,
    g_out,
    b_out
);
    logic [3:0] r, g, b;
    assign {r, g, b} = {imgData[15:12], imgData[10:7], imgData[4:1]};
    assign r_out = (r > 7) ? ~r : r;
    assign g_out = (g > 7) ? ~g : g;
    assign b_out = (b > 7) ? ~b : b;
endmodule
