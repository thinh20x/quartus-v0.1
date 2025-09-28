module square_wave (
    input  clk,
    input  sample_end,
    input  sample_req,
    output [15:0] audio_output,
    input  [15:0] audio_input,
    input  [3:0]  control
);

reg [15:0] last_sample;
reg [15:0] dat;

assign audio_output = dat;

parameter SINE     = 0;
parameter FEEDBACK = 1;

// Biến đếm để tạo sóng vuông
reg [15:0] square_wave_counter = 16'd0;
reg square_wave_state = 1'b0; // Trạng thái sóng vuông (0: thấp, 1: cao)

always @(posedge clk) begin
    if (sample_end) begin
        last_sample <= audio_input;
    end

    if (sample_req) begin
        if (control[FEEDBACK]) begin
            // Hiệu ứng phản hồi
            dat <= last_sample;
        end else if (control[SINE]) begin
            // Tạo sóng vuông
            if (square_wave_counter == 16'd4999) begin // Điều chỉnh giá trị này để thay đổi tần số
                square_wave_counter <= 16'd0;
                square_wave_state <= ~square_wave_state; // Đảo trạng thái
            end else begin
                square_wave_counter <= square_wave_counter + 16'd1;
            end

            // Gán giá trị sóng vuông
            if (square_wave_state) begin
                dat <= 16'h7FFF; // Mức cao
            end else begin
                dat <= 16'h8000; // Mức thấp
            end
        end else begin
            dat <= 16'd0; // Tắt âm thanh
        end
    end
end

endmodule