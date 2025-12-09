`timescale 1ns / 1ps

module MiniFontRom (
    input  logic [5:0] char_idx,
    input  logic [2:0] row_addr,
    output logic [7:0] row_data
);
    (* ram_style = "distributed" *)
    always_comb begin
        case (char_idx)
            6'd0:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h42;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase
            6'd1:
            case (row_addr)
                3'd0: row_data = 8'h18;
                3'd1: row_data = 8'h28;
                3'd2: row_data = 8'h08;
                3'd3: row_data = 8'h08;
                3'd4: row_data = 8'h08;
                3'd5: row_data = 8'h08;
                3'd6: row_data = 8'h08;
                3'd7: row_data = 8'h3E;
            endcase
            6'd2:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h02;
                3'd3: row_data = 8'h0C;
                3'd4: row_data = 8'h30;
                3'd5: row_data = 8'h40;
                3'd6: row_data = 8'h40;
                3'd7: row_data = 8'h7E;
            endcase
            6'd3:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h02;
                3'd3: row_data = 8'h1C;
                3'd4: row_data = 8'h02;
                3'd5: row_data = 8'h02;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase
            6'd4:
            case (row_addr)
                3'd0: row_data = 8'h0C;
                3'd1: row_data = 8'h14;
                3'd2: row_data = 8'h24;
                3'd3: row_data = 8'h44;
                3'd4: row_data = 8'h7E;
                3'd5: row_data = 8'h04;
                3'd6: row_data = 8'h04;
                3'd7: row_data = 8'h04;
            endcase
            6'd5:
            case (row_addr)
                3'd0: row_data = 8'h7E;
                3'd1: row_data = 8'h40;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h02;
                3'd5: row_data = 8'h02;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase
            6'd6:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h40;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase
            6'd7:
            case (row_addr)
                3'd0: row_data = 8'h7E;
                3'd1: row_data = 8'h02;
                3'd2: row_data = 8'h04;
                3'd3: row_data = 8'h08;
                3'd4: row_data = 8'h10;
                3'd5: row_data = 8'h20;
                3'd6: row_data = 8'h20;
                3'd7: row_data = 8'h20;
            endcase
            6'd8:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h3C;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase
            6'd9:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h3E;
                3'd4: row_data = 8'h02;
                3'd5: row_data = 8'h02;
                3'd6: row_data = 8'h02;
                3'd7: row_data = 8'h3C;
            endcase

            6'd10:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h7E;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h00;
            endcase  // A
            6'd11:
            case (row_addr)
                3'd0: row_data = 8'h7E;
                3'd1: row_data = 8'h40;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h40;
                3'd5: row_data = 8'h40;
                3'd6: row_data = 8'h40;
                3'd7: row_data = 8'h7E;
            endcase  // E
            6'd12:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h40;
                3'd4: row_data = 8'h4E;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase  // G
            6'd13:
            case (row_addr)
                3'd0: row_data = 8'h81;
                3'd1: row_data = 8'hC3;
                3'd2: row_data = 8'hA5;
                3'd3: row_data = 8'h99;
                3'd4: row_data = 8'h81;
                3'd5: row_data = 8'h81;
                3'd6: row_data = 8'h81;
                3'd7: row_data = 8'h81;
            endcase  // M
            6'd14:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h42;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase  // O
            6'd15:
            case (row_addr)
                3'd0: row_data = 8'h7C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h40;
                3'd5: row_data = 8'h40;
                3'd6: row_data = 8'h40;
                3'd7: row_data = 8'h40;
            endcase  // P
            6'd16:
            case (row_addr)
                3'd0: row_data = 8'h7C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h7C;
                3'd4: row_data = 8'h44;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h42;
            endcase  // R
            6'd17:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h3C;
                3'd4: row_data = 8'h02;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h3C;
            endcase  // S
            6'd18:
            case (row_addr)
                3'd0: row_data = 8'h7E;
                3'd1: row_data = 8'h18;
                3'd2: row_data = 8'h18;
                3'd3: row_data = 8'h18;
                3'd4: row_data = 8'h18;
                3'd5: row_data = 8'h18;
                3'd6: row_data = 8'h18;
                3'd7: row_data = 8'h18;
            endcase  // T
            6'd19:
            case (row_addr)
                3'd0: row_data = 8'h81;
                3'd1: row_data = 8'h81;
                3'd2: row_data = 8'h81;
                3'd3: row_data = 8'h42;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h24;
                3'd6: row_data = 8'h24;
                3'd7: row_data = 8'h18;
            endcase  // V

            6'd20:
            case (row_addr)
                3'd0: row_data = 8'h3C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h40;
                3'd4: row_data = 8'h40;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h3C;
                3'd7: row_data = 8'h00;
            endcase  // C
            6'd21:
            case (row_addr)
                3'd0: row_data = 8'h7E;
                3'd1: row_data = 8'h40;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h78;
                3'd4: row_data = 8'h40;
                3'd5: row_data = 8'h40;
                3'd6: row_data = 8'h40;
                3'd7: row_data = 8'h40;
            endcase  // F
            6'd22:
            case (row_addr)
                3'd0: row_data = 8'h81;
                3'd1: row_data = 8'h81;
                3'd2: row_data = 8'h81;
                3'd3: row_data = 8'h99;
                3'd4: row_data = 8'h99;
                3'd5: row_data = 8'hA5;
                3'd6: row_data = 8'hC3;
                3'd7: row_data = 8'h81;
            endcase  // W
            6'd23:
            case (row_addr)
                3'd0: row_data = 8'h40;
                3'd1: row_data = 8'h40;
                3'd2: row_data = 8'h40;
                3'd3: row_data = 8'h40;
                3'd4: row_data = 8'h40;
                3'd5: row_data = 8'h40;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h7E;
            endcase  // L
            6'd24:
            case (row_addr)
                3'd0: row_data = 8'h81;
                3'd1: row_data = 8'hC1;
                3'd2: row_data = 8'hA1;
                3'd3: row_data = 8'h91;
                3'd4: row_data = 8'h89;
                3'd5: row_data = 8'h85;
                3'd6: row_data = 8'h83;
                3'd7: row_data = 8'h81;
            endcase  // N

            6'd25:
            case (row_addr)
                3'd0: row_data = 8'h7C;
                3'd1: row_data = 8'h42;
                3'd2: row_data = 8'h42;
                3'd3: row_data = 8'h42;
                3'd4: row_data = 8'h42;
                3'd5: row_data = 8'h42;
                3'd6: row_data = 8'h42;
                3'd7: row_data = 8'h7C;
            endcase  // D




            default: row_data = 8'h00;
        endcase
    end
endmodule