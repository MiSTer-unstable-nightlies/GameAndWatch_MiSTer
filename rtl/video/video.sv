module video #(
    parameter CLOCK_RATIO = 3
) (
    input wire clk_sys_99_287,
    input wire clk_vid_33_095,

    input wire reset,

    input wire [3:0] cpu_id,

    // Data in
    input wire mask_data_wr,
    input wire [15:0] mask_data,

    input wire divider_1khz,

    // Segments
    input wire [15:0] current_segment_a,
    input wire [15:0] current_segment_b,
    input wire [15:0] current_segment_c,
    input wire [15:0] current_segment_bs,

    input wire [3:0] current_w_prime[9],
    input wire [3:0] current_w_main [9],

    input wire [1:0] output_lcd_h_index,

    // Settings
    input wire [7:0] lcd_off_alpha,

    // Debug
    input wire debug_video,
    input wire [1:0] debug_view,
    input wire [63:0] debug_events,
    input wire [63:0] debug_cpu_state,
    input wire [63:0] debug_melody_state,
    input wire [63:0] debug_core_state,

    // Video
    output reg hsync,
    output reg vsync,
    output reg hblank,
    output reg vblank,

    output reg de,
    output wire ce_pix,
    output reg [23:0] rgb,

    // SDRAM
    input wire sd_data_available,
    input wire [15:0] sd_out,
    output wire sd_end_burst,
    output wire sd_rd,
    output wire [24:0] sd_rd_addr
);
  wire [9:0] video_x;
  wire [9:0] video_y;

  wire hsync_int;
  wire vsync_int;
  wire hblank_int;
  wire vblank_int;

  wire de_int;
  assign ce_pix = 1'b1;

  ////////////////////////////////////////////////////////////////////////////////////////
  // LCD

  wire segment_en;

  lcd #(
      .CLOCK_RATIO(CLOCK_RATIO)
  ) lcd (
      .clk(clk_sys_99_287),

      .reset(reset),

      .cpu_id(cpu_id),

      .mask_data_wr(mask_data_wr),
      .mask_data(mask_data),

      // Segments
      .current_segment_a (current_segment_a),
      .current_segment_b (current_segment_b),
      .current_segment_c (current_segment_c),
      .current_segment_bs(current_segment_bs),

      .current_w_prime(current_w_prime),
      .current_w_main (current_w_main),

      .output_lcd_h_index(output_lcd_h_index),

      .divider_1khz(divider_1khz),

      // Video counters
      .vblank_int(vblank_int),
      .hblank_int(hblank_int),
      .video_x(video_x),
      .video_y(video_y),

      .segment_en(segment_en)
  );

  ////////////////////////////////////////////////////////////////////////////////////////
  // SDRAM and RGB

  wire [23:0] background_rgb;
  wire [23:0] mask_rgb;
  wire [23:0] processed_rgb;

  wire [7:0] alpha = reset ? 8'h00 : segment_en ? 8'hFF : lcd_off_alpha;

  alpha_blend alpha_blend (
      .background_pixel(background_rgb),
      .foreground_pixel({mask_rgb, alpha}),

      .output_pixel(processed_rgb)
  );

  wire [2:0] debug_col = video_x[8:6];
  wire [2:0] debug_row = video_y[8:6];
  wire [5:0] debug_idx = {debug_row, debug_col};
  wire debug_panel = video_x < 10'd512 && video_y < 10'd512;
  wire debug_grid = (video_x[5:0] == 6'd0) || (video_y[5:0] == 6'd0);

  reg [63:0] debug_bits;
  always_comb begin
    case (debug_view)
      2'd1: debug_bits = debug_cpu_state;
      2'd2: debug_bits = debug_melody_state;
      2'd3: debug_bits = debug_core_state;
      default: debug_bits = debug_events;
    endcase
  end

  reg [23:0] debug_row_rgb;
  always_comb begin
    case (debug_row)
      3'd0: debug_row_rgb = 24'hffffff;
      3'd1: debug_row_rgb = 24'h00ff00;
      3'd2: debug_row_rgb = 24'hffff00;
      3'd3: debug_row_rgb = 24'h00ffff;
      3'd4: debug_row_rgb = 24'hff80ff;
      3'd5: debug_row_rgb = 24'hff8000;
      3'd6: debug_row_rgb = 24'h80a0ff;
      default: debug_row_rgb = 24'hff4040;
    endcase
  end

  wire debug_cell_on = debug_panel && debug_bits[debug_idx];
  wire [23:0] debug_rgb =
      !de_int        ? 24'h000000 :
      !debug_panel   ? 24'h000010 :
      debug_grid     ? 24'h202020 :
      debug_cell_on  ? debug_row_rgb :
                       24'h080008;

  wire [23:0] final_rgb = debug_video ? debug_rgb : processed_rgb;

  always @(posedge clk_sys_99_287) begin
    // We have two cycles to do work. One is spent on segment_en, one is spent here 
    rgb <= final_rgb;
  end

  rgb_controller rgb_controller (
      .clk_sys_99_287(clk_sys_99_287),
      .clk_vid_33_095(clk_vid_33_095),

      .reset(reset),

      // Video
      .hblank_int(hblank_int),
      .video_y(video_y),
      .de_int(de_int),

      // RGB
      .background_rgb(background_rgb),
      .mask_rgb(mask_rgb),

      // SDRAM
      .sd_data_available(sd_data_available),
      .sd_out(sd_out),
      .sd_end_burst(sd_end_burst),
      .sd_rd(sd_rd),
      .sd_rd_addr(sd_rd_addr)
  );

  ////////////////////////////////////////////////////////////////////////////////////////
  // Sync counts

  // Delay all signals by 1 cycle so that RGB is caught up
  always @(posedge clk_vid_33_095) begin
    hsync <= hsync_int;
    vsync <= vsync_int;
    hblank <= hblank_int;
    vblank <= vblank_int;

    de <= de_int;
  end

  counts counts (
      .clk(clk_vid_33_095),
      .ce_pix(ce_pix),

      .x(video_x),
      .y(video_y),

      .hsync (hsync_int),
      .vsync (vsync_int),
      .hblank(hblank_int),
      .vblank(vblank_int),

      .de(de_int)
  );

endmodule
