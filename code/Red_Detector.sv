`timescale 1ns / 1ps

module RedDetector (
    input  logic        clk,
    input  logic        reset,
    input  logic        vsync,
    input  logic        DE,
    input  logic [15:0] frame_data,
    output logic [16:0] frame_addr,
    output logic        scanning,
    output logic [ 8:0] player_x,
    output logic [ 8:0] player_y,
    output logic        player_detected
);

    logic [16:0] scan_addr;
    logic [24:0] sum_x, sum_y;
    logic [16:0] pixel_count;
    logic        vsync_prev;
    logic [ 8:0] curr_x;
    logic [ 8:0] curr_y;
    logic [3:0] r_check, g_check, b_check;
    logic is_target_color;

    assign r_check = frame_data[15:12];
    assign g_check = frame_data[10:7];
    assign b_check = frame_data[4:1];

    assign is_target_color =
        (r_check > 4'd4) &&
        (g_check < 4'd7) && (b_check < 4'd7) &&
        (r_check >= (g_check + 4'd2)) && (r_check >= (b_check + 4'd2));

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            scan_addr       <= 0;
            sum_x           <= 0;
            sum_y           <= 0;
            pixel_count     <= 0;
            scanning        <= 0;
            vsync_prev      <= 0;
            player_x        <= 160;
            player_y        <= 200;
            player_detected <= 0;
            frame_addr      <= 0;
            curr_x          <= 0;
            curr_y          <= 0;
        end else begin
            vsync_prev <= vsync;

            if (!vsync_prev && vsync) begin
                scanning    <= 1;
                scan_addr   <= 0;
                sum_x       <= 0;
                sum_y       <= 0;
                pixel_count <= 0;
                curr_x      <= 0;
                curr_y      <= 0;
            end

            if (scanning) begin
                if (!DE) begin
                    if (scan_addr < 76800) begin
                        frame_addr <= scan_addr;

                        if (is_target_color) begin
                            sum_x       <= sum_x + curr_x;
                            sum_y       <= sum_y + curr_y;
                            pixel_count <= pixel_count + 1;
                        end

                        if (curr_x == 319) begin
                            curr_x <= 0;
                            curr_y <= curr_y + 1;
                        end else begin
                            curr_x <= curr_x + 1;
                        end

                        scan_addr <= scan_addr + 1;
                    end else begin
                        scanning <= 0;

                        if (pixel_count > 50) begin
                            logic [24:0] raw_x, raw_y;
                            logic [24:0] target_x;

                            raw_x = sum_x / pixel_count;
                            raw_y = sum_y / pixel_count;

                            if (raw_x > 320) target_x = 0;
                            else target_x = 320 - raw_x;

                            player_x        <= (player_x * 31 + target_x) / 32;
                            player_y        <= (player_y * 31 + raw_y) / 32;
                            player_detected <= 1;
                        end else begin
                            player_detected <= 0;
                        end
                    end
                end
            end
        end
    end
endmodule