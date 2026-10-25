module comparator_search #(parameter W = 64, parameter DIR = 1, parameter IDXW = $clog2(W)) (
input  wire            clk, rst_n, start,
input  wire [W-1:0]    bitmap,
output reg             busy, done, found,
output reg [IDXW-1:0]  idx,
output reg [15:0]      cycles
);
reg [IDXW-1:0] pos;

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin busy<=0; done<=0; found<=0; idx<=0; cycles<=0; pos<=0; end
else begin
done <= 1'b0;  

if (!busy) begin
if (start) begin busy<=1; found<=0; cycles<=0; pos <= DIR ? (W-1) : 0; end
end else begin
cycles <= cycles + 1'b1;   

if (bitmap[pos]) begin busy<=0; done<=1; found<=1; idx<=pos; end   

else if ((DIR && pos==0) || (!DIR && pos==W-1)) begin busy<=0; done<=1; found<=0; end
else pos <= DIR ? pos - 1'b1 : pos + 1'b1; 
end
end
end
endmodule
