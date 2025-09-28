// Module điều chỉnh biên độ tín hiệu âm thanh
// Cách sử dụng SW[8:6]:
// 000: Tắt âm (0x)
// 001: 1/8 biên độ (0.125x)  
// 010: 1/4 biên độ (0.25x)
// 011: 1/2 biên độ (0.5x)
// 100: ~0.707x biên độ (1/√2)
// 101: 3/4 biên độ (0.75x)
// 110: 7/8 biên độ (0.875x)
// 111: Gần như biên độ gốc (0.999x)

module amplitude_adjust (
    input                  clk,
    input  signed [15:0]   audio_input,   // 16-bit PCM, signed
    input         [2:0]    control,       // SW[8:6]
    output reg signed [15:0] audio_output
);

parameter BITS = 16;
parameter GQ   = 14;
    
    // Đồng bộ control vào domain clk (2FF) để tránh metastability
    reg [2:0] control_s1, control_s2;
    always @(posedge clk) begin
        control_s1 <= control;
        control_s2 <= control_s1;
    end

    // LUT hệ số Q2.14 (scale từ 0 đến 1 để tránh overflow)
    reg signed [15:0] gain_q;
    always @* begin
        case (control_s2)
            3'b000: gain_q = 16'sh0000; // 0.0000x (tắt âm)
            3'b001: gain_q = 16'sh0800; // 0.1250x (1/8 biên độ)
            3'b010: gain_q = 16'sh1000; // 0.2500x (1/4 biên độ) 
            3'b011: gain_q = 16'sh2000; // 0.5000x (1/2 biên độ)
            3'b100: gain_q = 16'sh2D41; // 0.7071x (~1/√2 biên độ)
            3'b101: gain_q = 16'sh3000; // 0.7500x (3/4 biên độ)
            3'b110: gain_q = 16'sh3800; // 0.8750x (7/8 biên độ)
            3'b111: gain_q = 16'sh3FFF; // 0.9999x (gần như biên độ gốc)
            default: gain_q = 16'sh2D41; // Mặc định ~0.707x
        endcase
    end

    // Nhân, chia và bão hòa với xử lý tốt hơn
    reg signed [31:0] mul_result;
    reg signed [31:0] scaled_result;

    always @(posedge clk) begin
        // Nhân với ép kiểu rõ ràng
        mul_result <= $signed(audio_input) * $signed(gain_q);
        
        // Dịch phải số học để lấy phần nguyên Q2.14 -> Q16.0
        scaled_result <= mul_result >>> GQ;

        // Saturation với logic rõ ràng để tránh overflow
        if (scaled_result > $signed(32'h00007FFF)) begin
            audio_output <= 16'h7FFF;  // Maximum positive value
        end else if (scaled_result < $signed(32'hFFFF8000)) begin
            audio_output <= 16'h8000;  // Maximum negative value  
        end else begin
            audio_output <= scaled_result[15:0];
        end
    end

endmodule