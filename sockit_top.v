module sockit_top (
    input  OSC_50_B8A,

    inout  AUD_ADCLRCK,
    input  AUD_ADCDAT,
    inout  AUD_DACLRCK,
    output AUD_DACDAT,
    output AUD_XCK,
    inout  AUD_BCLK,
    output AUD_I2C_SCLK,
    inout  AUD_I2C_SDAT,
    output AUD_MUTE,

    input  [3:0] KEY,
    input  [9:0] SW,
    output [3:0] LED
);

wire reset = !KEY[0];
wire main_clk;
wire audio_clk;

wire [1:0] sample_end;
wire [1:0] sample_req;
reg [15:0] audio_output;
wire [15:0] audio_input;

wire [15:0] adjusted_audio_output;  // Tín hiệu sau khi điều chỉnh biên độ

// Thêm tín hiệu chọn tần số
wire [1:0] freq_sel = SW[5:4]; // Sử dụng SW[5:4] để chọn tần số

wire [15:0] square_wave_out; // Tín hiệu output từ module sóng vuông
wire [15:0] sine_wave_out; // Tín hiệu output từ module sóng sine
wire [15:0] triangle_wave_out; // Tín hiệu output từ module sóng tam giac
wire [15:0] sawtooth_wave_out; // Tín hiệu output từ module sóng rang cua
wire [15:0] ecg_wave_out; // Tín hiệu output từ module sóng nhip tim

wire [15:0] noise_output;

wire noise_enable = SW[9]; // Use SW[9] to enable/disable noise

wire [15:0] mixed_audio; // Tín hiệu kết hợp giữa sóng và nhiễu
wire [15:0] final_audio_output; // Tín hiệu cuối cùng sau khi điều chỉnh biên độ

clock_pll pll (
    .refclk (OSC_50_B8A),
    .rst (reset),
    .freq_sel (freq_sel),
    .outclk_0 (audio_clk),
    .outclk_1 (main_clk)
);

i2c_av_config av_config (
    .clk (main_clk),
    .reset (reset),
    .i2c_sclk (AUD_I2C_SCLK),
    .i2c_sdat (AUD_I2C_SDAT),
    .status (LED)
);

assign AUD_XCK = audio_clk;
assign AUD_MUTE = 1'b0; // Fixed: always enable audio output

noise_generator noise_gen (
    .clk (audio_clk),
    .reset (reset),
    .noise_output (noise_output)
);

// Kết hợp nhiễu với sóng được chọn
assign mixed_audio = noise_enable ? (audio_output + (noise_output >> 4)) : audio_output;

// Module điều chỉnh biên độ - SỬA CHỮA CHÍNH TẠI ĐÂY
amplitude_adjust amp_adj (
    .clk (audio_clk),
    .audio_input (mixed_audio),     // Input: tín hiệu đã trộn nhiễu
    .control (SW[8:6]),             // Control: SW[8:6] để điều chỉnh biên độ
    .audio_output (adjusted_audio_output) // Output: tín hiệu đã điều chỉnh biên độ
);

// Chọn tín hiệu cuối cùng: nếu SW[8:6] != 000 thì dùng tín hiệu đã điều chỉnh biên độ
assign final_audio_output = (SW[8:6] != 3'b000) ? adjusted_audio_output : mixed_audio;

audio_codec ac (
    .clk (audio_clk),
    .reset (reset),
    .sample_end (sample_end),
    .sample_req (sample_req),
    .audio_output (final_audio_output), // SỬA: Sử dụng tín hiệu cuối cùng đã điều chỉnh biên độ
    .audio_input (audio_input),
    .channel_sel (2'b10),

    .AUD_ADCLRCK (AUD_ADCLRCK),
    .AUD_ADCDAT (AUD_ADCDAT),
    .AUD_DACLRCK (AUD_DACLRCK),
    .AUD_DACDAT (AUD_DACDAT),
    .AUD_BCLK (AUD_BCLK)
);

audio_effects ae (
    .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
    .audio_output (sine_wave_out),
    .audio_input  (audio_input),
    .control (SW[0])
);

square_wave sw(
    .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
    .audio_output (square_wave_out),
    .audio_input  (audio_input),
    .control (SW[0])
);

triangle_wave tw(
    .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
    .audio_output (triangle_wave_out),
    .audio_input  (audio_input),
    .control (SW[0])
);

sawtooth_wave saw(
    .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
    .audio_output (sawtooth_wave_out),
    .audio_input  (audio_input),
    .control (SW[0])
);

ecg_wave ew(
    .clk (audio_clk),
    .sample_end (sample_end[1]),
    .sample_req (sample_req[1]),
    .audio_output (ecg_wave_out),
    .audio_input  (audio_input),
    .control (SW[0])
);

// Chọn loại sóng dựa trên SW[3:1]
always @(posedge audio_clk) begin
    case (SW[3:1])
        3'b000: audio_output <= sine_wave_out;
        3'b001: audio_output <= square_wave_out;
        3'b011: audio_output <= triangle_wave_out;
        3'b110: audio_output <= sawtooth_wave_out;
        3'b010: audio_output <= ecg_wave_out;
        default: audio_output <= sine_wave_out;
    endcase
end

endmodule