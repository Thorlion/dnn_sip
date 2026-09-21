module Linear_Inter #(
    parameter DATA_W = 16,
    parameter DECIMAL_BIT = 8   // Number of decimal bits
)(
    input  logic signed [DATA_W-1:0] x, // input signed 
    input  logic signed [DATA_W-1:0] x1,      // Known point X1 from LUT
    input  logic signed [DATA_W-1:0] y1,      // Known point Y1 from LUT
    input  logic signed [DATA_W-1:0] x2,      // Known point X2 from LUT
    input  logic signed [DATA_W-1:0] y2,      // Known point Y2 from LUT
    
    output logic signed [DATA_W-1:0] y
);
    logic signed [DATA_W-1:0] slope;
    logic signed [2*DATA_W-1:0] intercept;
    logic signed [2*DATA_W-1:0] y_intermediate; // Q8.16 format for intermediate y calculation
    logic signed [2*DATA_W-1:0] dy;
    logic signed [DATA_W-1:0] dx;

    // always_comb begin
	// 	    slope = '0;
	// 		intercept = '0;
	// 		y_intermediate = '0;
	// 		dx = '0;
	// 		dy = '0;
	// 		y = '0;
    //     if (x2 != x1) begin
    //         dy = y2 - y1;
    //         dx = x2 - x1;
    //         slope = (dy << DECIMAL_BIT) / dx;                   // He so goc
    //         intercept = (y1 << DECIMAL_BIT) - (slope * x1);     // Tung do goc
    //         y_intermediate = slope * x + intercept;             // Ket qua phuong trinh
    //         y = y_intermediate[DATA_W + DECIMAL_BIT - 1:DECIMAL_BIT];   // [23:8]
    //         // else Latch
    //     end
    // end
    always_comb begin
        if (x2 != x1) begin
            dy = y2 - y1;
            dx = x2 - x1;
            slope = (dy << DECIMAL_BIT) / dx;            
            intercept = (y1 << DECIMAL_BIT) - (slope * x1);
            y_intermediate = slope * x + intercept;
            y = y_intermediate[DATA_W + DECIMAL_BIT - 1:DECIMAL_BIT];
        end 
    end

endmodule