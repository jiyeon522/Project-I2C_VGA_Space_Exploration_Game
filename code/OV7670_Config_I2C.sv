`timescale 1ns / 1ps

module OV7670_Config_I2C (
    input logic clk,
    input logic reset,
    inout logic scl,
    inout logic sda
);

    localparam int CLK_FREQ = 25_000_000;
    localparam int SCCB_FREQ = 100_000;
    localparam int QTR_DIV = CLK_FREQ / (SCCB_FREQ * 4);
    localparam logic [7:0] DEV_ADDR_WR = 8'h42;

    localparam int DELAY_1MS = CLK_FREQ / 1000;
    localparam int DELAY_10MS = (CLK_FREQ / 1000) * 10;
    localparam int DELAY_30MS = (CLK_FREQ / 1000) * 30;

    logic scl_oe, sda_oe;
    assign scl = scl_oe ? 1'b0 : 1'bz;
    assign sda = sda_oe ? 1'b0 : 1'bz;

    typedef struct packed {
        logic [7:0] addr;
        logic [7:0] data;
    } reg_pair_t;

    localparam int NUM_REGS = 60;
    localparam int IDX_DEFAULTS_END = 42;

    reg_pair_t init_table[0:NUM_REGS-1];

    initial begin
        init_table[0]  = '{8'h12, 8'h80};

        init_table[1]  = '{8'h3A, 8'h04};
        init_table[2]  = '{8'h12, 8'h00};
        init_table[3]  = '{8'h13, 8'hE7};
        init_table[4]  = '{8'h6F, 8'h9F};
        init_table[5]  = '{8'hB0, 8'h84};

        init_table[6]  = '{8'h70, 8'h3A};
        init_table[7]  = '{8'h71, 8'h35};
        init_table[8]  = '{8'h72, 8'h11};
        init_table[9]  = '{8'h73, 8'hF0};

        init_table[10] = '{8'h7A, 8'h20};
        init_table[11] = '{8'h7B, 8'h10};
        init_table[12] = '{8'h7C, 8'h1E};
        init_table[13] = '{8'h7D, 8'h35};
        init_table[14] = '{8'h7E, 8'h5A};
        init_table[15] = '{8'h7F, 8'h69};
        init_table[16] = '{8'h80, 8'h76};
        init_table[17] = '{8'h81, 8'h80};
        init_table[18] = '{8'h82, 8'h88};
        init_table[19] = '{8'h83, 8'h8F};
        init_table[20] = '{8'h84, 8'h96};
        init_table[21] = '{8'h85, 8'hA3};
        init_table[22] = '{8'h86, 8'hAF};
        init_table[23] = '{8'h87, 8'hC4};
        init_table[24] = '{8'h88, 8'hD7};
        init_table[25] = '{8'h89, 8'hE8};

        init_table[26] = '{8'h00, 8'h00};
        init_table[27] = '{8'h10, 8'h00};
        init_table[28] = '{8'h0D, 8'h40};
        init_table[29] = '{8'h14, 8'h18};
        init_table[30] = '{8'hA5, 8'h05};
        init_table[31] = '{8'hAB, 8'h07};
        init_table[32] = '{8'h24, 8'h95};
        init_table[33] = '{8'h25, 8'h33};
        init_table[34] = '{8'h26, 8'hE3};
        init_table[35] = '{8'h9F, 8'h78};
        init_table[36] = '{8'hA0, 8'h68};
        init_table[37] = '{8'hA1, 8'h03};
        init_table[38] = '{8'hA6, 8'hD8};
        init_table[39] = '{8'hA7, 8'hD8};
        init_table[40] = '{8'hA8, 8'hF0};
        init_table[41] = '{8'hA9, 8'h90};
        init_table[42] = '{8'hAA, 8'h94};

        init_table[43] = '{8'h12, 8'h11};
        init_table[44] = '{8'h0C, 8'h04};
        init_table[45] = '{8'h3E, 8'h19};
        init_table[46] = '{8'h70, 8'h3A};
        init_table[47] = '{8'h71, 8'h35};
        init_table[48] = '{8'h72, 8'h11};
        init_table[49] = '{8'h73, 8'hF1};
        init_table[50] = '{8'hA2, 8'h02};

        init_table[51] = '{8'h17, 8'h15};
        init_table[52] = '{8'h18, 8'h03};
        init_table[53] = '{8'h32, 8'h00};
        init_table[54] = '{8'h19, 8'h03};
        init_table[55] = '{8'h1A, 8'h7B};
        init_table[56] = '{8'h03, 8'h00};

        init_table[57] = '{8'h12, 8'h14};
        init_table[58] = '{8'h40, 8'h10};
        init_table[59] = '{8'h55, 8'h87};
    end

    typedef enum logic [4:0] {
        ST_RESET_WAIT,
        ST_IDLE,
        ST_START_A,
        ST_START_B,
        ST_LOAD_BYTE,
        ST_BIT_SETUP,
        ST_SCL_HIGH,
        ST_SCL_LOW,
        ST_ACK_SETUP,
        ST_ACK_HIGH,
        ST_ACK_LOW,
        ST_STOP_A,
        ST_STOP_B,
        ST_DELAY,
        ST_NEXT,
        ST_DONE
    } state_t;

    state_t state, state_next;

    logic [$clog2(QTR_DIV):0] qtr_cnt, qtr_cnt_next;
    logic qtr_tick;
    logic scl_oe_next, sda_oe_next;

    logic [7:0] cur_byte, cur_byte_next;
    logic [2:0] bit_idx, bit_idx_next;
    logic [1:0] byte_sel, byte_sel_next;
    logic [$clog2(NUM_REGS)-1:0] reg_idx, reg_idx_next;

    logic [31:0] delay_cnt, delay_cnt_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state     <= ST_RESET_WAIT;
            qtr_cnt   <= 0;
            cur_byte  <= 0;
            bit_idx   <= 3'd7;
            byte_sel  <= 0;
            reg_idx   <= 0;
            scl_oe    <= 0;
            sda_oe    <= 0;
            delay_cnt <= DELAY_10MS;
        end else begin
            state     <= state_next;
            qtr_cnt   <= qtr_cnt_next;
            cur_byte  <= cur_byte_next;
            bit_idx   <= bit_idx_next;
            byte_sel  <= byte_sel_next;
            reg_idx   <= reg_idx_next;
            scl_oe    <= scl_oe_next;
            sda_oe    <= sda_oe_next;
            delay_cnt <= delay_cnt_next;
        end
    end

    always_comb begin
        qtr_cnt_next = qtr_cnt;
        if (qtr_cnt == QTR_DIV - 1) qtr_cnt_next = 0;
        else qtr_cnt_next = qtr_cnt + 1;
        qtr_tick       = (qtr_cnt == QTR_DIV - 1);

        state_next     = state;
        cur_byte_next  = cur_byte;
        bit_idx_next   = bit_idx;
        byte_sel_next  = byte_sel;
        reg_idx_next   = reg_idx;
        delay_cnt_next = delay_cnt;

        scl_oe_next    = scl_oe;
        sda_oe_next    = sda_oe;

        case (state)
            ST_RESET_WAIT: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                if (qtr_tick) begin
                    if (delay_cnt == 0) begin
                        state_next = ST_IDLE;
                    end else begin
                        delay_cnt_next = delay_cnt - 1;
                    end
                end
            end

            ST_IDLE: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                byte_sel_next = 0;
                bit_idx_next = 3'd7;
                state_next = ST_START_A;
            end

            ST_START_A: begin
                scl_oe_next = 0;
                sda_oe_next = 1;
                if (qtr_tick) state_next = ST_START_B;
            end

            ST_START_B: begin
                scl_oe_next = 1;
                sda_oe_next = 1;
                if (qtr_tick) state_next = ST_LOAD_BYTE;
            end

            ST_LOAD_BYTE: begin
                bit_idx_next = 3'd7;
                unique case (byte_sel)
                    2'd0: cur_byte_next = DEV_ADDR_WR;
                    2'd1: cur_byte_next = init_table[reg_idx].addr;
                    2'd2: cur_byte_next = init_table[reg_idx].data;
                    default: cur_byte_next = 8'h00;
                endcase
                state_next = ST_BIT_SETUP;
            end

            ST_BIT_SETUP: begin
                scl_oe_next = 1;
                sda_oe_next = ~cur_byte[bit_idx];
                if (qtr_tick) state_next = ST_SCL_HIGH;
            end

            ST_SCL_HIGH: begin
                scl_oe_next = 0;
                sda_oe_next = ~cur_byte[bit_idx];
                if (qtr_tick) state_next = ST_SCL_LOW;
            end

            ST_SCL_LOW: begin
                scl_oe_next = 1;
                sda_oe_next = ~cur_byte[bit_idx];
                if (qtr_tick) begin
                    if (bit_idx == 0) begin
                        state_next = ST_ACK_SETUP;
                    end else begin
                        bit_idx_next = bit_idx - 1;
                        state_next   = ST_BIT_SETUP;
                    end
                end
            end

            ST_ACK_SETUP: begin
                scl_oe_next = 1;
                sda_oe_next = 0;
                if (qtr_tick) state_next = ST_ACK_HIGH;
            end

            ST_ACK_HIGH: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                if (qtr_tick) state_next = ST_ACK_LOW;
            end

            ST_ACK_LOW: begin
                scl_oe_next = 1;
                sda_oe_next = 0;
                if (qtr_tick) begin
                    if (byte_sel == 2'd2) begin
                        state_next = ST_STOP_A;
                    end else begin
                        byte_sel_next = byte_sel + 1;
                        state_next = ST_LOAD_BYTE;
                    end
                end
            end

            ST_STOP_A: begin
                scl_oe_next = 0;
                sda_oe_next = 1;
                if (qtr_tick) state_next = ST_STOP_B;
            end

            ST_STOP_B: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                if (qtr_tick) begin
                    state_next = ST_DELAY;
                    if (reg_idx == 0) delay_cnt_next = DELAY_30MS;
                    else if (reg_idx == IDX_DEFAULTS_END)
                        delay_cnt_next = DELAY_10MS;
                    else delay_cnt_next = DELAY_1MS;
                end
            end

            ST_DELAY: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                if (qtr_tick) begin
                    if (delay_cnt == 0) state_next = ST_NEXT;
                    else delay_cnt_next = delay_cnt - 1;
                end
            end

            ST_NEXT: begin
                scl_oe_next   = 0;
                sda_oe_next   = 0;
                byte_sel_next = 0;
                if (reg_idx == NUM_REGS - 1) begin
                    state_next = ST_DONE;
                end else begin
                    reg_idx_next = reg_idx + 1;
                    state_next   = ST_START_A;
                end
            end

            ST_DONE: begin
                scl_oe_next = 0;
                sda_oe_next = 0;
                state_next  = ST_DONE;
            end

            default: state_next = ST_IDLE;
        endcase
    end
endmodule
