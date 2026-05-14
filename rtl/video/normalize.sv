module normalize #(
    parameter MAX_X_SEGMENT = 9,
    parameter MAX_Y_SEGMENT = 16,
    parameter MAX_Z_SEGMENT = 4
) (
    input wire clk,

    input wire [3:0] cpu_id,

    input wire [15:0] current_segment_a,
    input wire [15:0] current_segment_b,
    input wire [15:0] current_segment_c,
    input wire [15:0] current_segment_bs,

    input wire [3:0] current_w_prime[9],
    input wire [3:0] current_w_main [9],

    input wire [1:0] output_lcd_h_index,

    // Z is used for one hot bit selection, hence the width
    output reg [MAX_Z_SEGMENT-1:0] segments[MAX_X_SEGMENT][MAX_Y_SEGMENT]
);
  initial begin
    int x, y;

    for (x = 0; x < MAX_X_SEGMENT; x += 1) begin
      for (y = 0; y < MAX_Y_SEGMENT; y += 1) begin
        segments[x][y] = '0;
      end
    end
  end

  always @(posedge clk) begin
    int x, y, z;

    case (cpu_id)
      4: begin
        // SM5a
        for (x = 0; x < MAX_X_SEGMENT; x += 1) begin
          // Only 4 Y segments
          for (y = 0; y < 4; y += 1) begin
            if (output_lcd_h_index[0]) begin
              segments[x][y][0] <= current_w_main[x][y];
            end else begin
              segments[x][y][1] <= current_w_prime[x][y];
            end
          end
        end
      end
      default: begin
        // SM510/SM510 Tiger
        for (y = 0; y < MAX_Y_SEGMENT; y += 1) begin
          segments[0][y][output_lcd_h_index] <= current_segment_a[y];
          segments[1][y][output_lcd_h_index] <= current_segment_b[y];
          segments[3][y][output_lcd_h_index] <= current_segment_c[y];

          // SM510 presents this as one line mirrored across mask columns; SM511/SM512
          // use BS column 0 for L/Y blinking and column 1 for X.
          segments[2][y][output_lcd_h_index] <= current_segment_bs[y];
        end
      end
    endcase
  end

endmodule
