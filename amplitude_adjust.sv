module amplitude_adjust #(
    parameter BITS = 16,
    parameter GQ   = 14
)(
    input                         clk,
    input      signed [BITS-1:0]  audio_input,   // 16-bit PCM, signed
    input              [2:0]      control,       // SW[8:6]
    output reg signed [BITS-1:0]  audio_output
);
    // ---- Đồng bộ control vào domain clk (2FF) ----
    reg [2:0] control_s1, control_s2;
    always @(posedge clk) begin
        control_s1 <= control;
        control_s2 <= control_s1;
    end

    // ---- LUT hệ số Q2.14 ----
    reg signed [15:0] gain_q;
    always @* begin
        case (control_s2)
            3'b000: gain_q = 16'sh0000; // 0.0000x
            3'b001: gain_q = 16'sh1000; // 0.1250x
            3'b010: gain_q = 16'sh2000; // 0.2500x
            3'b011: gain_q = 16'sh4000; // 0.5000x
            3'b100: gain_q = 16'sh2D41; // ~0.7071x
            3'b101: gain_q = 16'sh4000; // 1.0000x
            3'b110: gain_q = 16'sh5A82; // ~1.4142x
            3'b111: gain_q = 16'sh7FFF; // ~1.9999x
        endcase
    end

    // ---- Nhân & scale & bão hòa ----
    reg signed [31:0] mul_p;
    reg signed [31:0] scaled;

    always @(posedge clk) begin
        // ÉP KIỂU SIGNED rõ ràng để tránh suy luận sai
        mul_p  <= $signed(audio_input) * $signed(gain_q); // 16x16 -> 32
        scaled <= mul_p >>> GQ;                           // dịch số học

        // Saturation về [-32768, +32767]
        if (scaled >  32'sd32767)
            audio_output <= 16'sd32767;
        else if (scaled < -32'sd32768)
            audio_output <= -16'sd32768;
        else
            audio_output <= scaled[15:0];
    end
endmodule