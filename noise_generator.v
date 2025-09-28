module noise_generator (
    input  clk,
    input  reset,
    output [15:0] noise_output // Thay đổi từ reg sang wire
);

reg [15:0] lfsr; // Linear Feedback Shift Register for pseudo-random noise
reg [15:0] noise_reg; // Biến tạm để lưu giá trị nhiễu

always @(posedge clk or posedge reset) begin
    if (reset) begin
        lfsr <= 16'hACE1; // Seed value for LFSR
    end else begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
    noise_reg <= lfsr; // Gán giá trị nhiễu vào biến tạm
end

assign noise_output = noise_reg; // Gán giá trị nhiễu ra output

endmodule