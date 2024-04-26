/* verilator lint_off DECLFILENAME */
/* verilator lint_off UNUSEDSIGNAL */

module FP_sqrt (
    input i_clk,
    input [26:0] i_a,
    output [26:0] o_sqrt
);
    // 10 cycles to complete
    wire [26:0] inv_sqrt;
    FpInvSqrt inv_sq (
        .iCLK(i_clk),
        .iA(i_a),
        .oInvSqrt(inv_sqrt)
    );
    FpMul recip (
        .iA(inv_sqrt),
        .iB(i_a),
        .oProd(o_sqrt)
    );
endmodule

module VEC_dot (
    input i_clk,
    input [26:0] i_a_x,
    input [26:0] i_a_y,
    input [26:0] i_a_z,
    input [26:0] i_b_x,
    input [26:0] i_b_y,
    input [26:0] i_b_z,
    output [26:0] o_dot
);
    // 2 + 2 = 4 cycles to complete
    wire [26:0] x_prod, y_prod, z_prod, xy_sum;
    FpMul x_prod_mul (
        .iA(i_a_x),
        .iB(i_b_x),
        .oProd(x_prod)
    );
    FpMul y_prod_mul (
        .iA(i_a_y),
        .iB(i_b_y),
        .oProd(y_prod)
    );
    FpMul z_prod_mul (
        .iA(i_a_z),
        .iB(i_b_z),
        .oProd(z_prod)
    );
    FpAdd xy_sum_add (
        .iCLK(i_clk),
        .iA  (x_prod),
        .iB  (y_prod),
        .oSum(xy_sum)
    );
    FpAdd xyz_sum (
        .iCLK(i_clk),
        .iA  (xy_sum),
        .iB  (z_prod),
        .oSum(o_dot)
    );

endmodule

module VEC_dot_4 (
    input i_clk,
    input [26:0] i_a_x,
    input [26:0] i_a_y,
    input [26:0] i_a_z,
    input [26:0] i_a_w,
    input [26:0] i_b_x,
    input [26:0] i_b_y,
    input [26:0] i_b_z,
    input [26:0] i_b_w,
    output [26:0] o_dot
);
    // 4 + 2 = 6 cycles to complete
    wire [26:0] w_prod, dot;
    FpMul w_prod_mul (
        .iA(i_a_w),
        .iB(i_b_w),
        .oProd(w_prod)
    );
    VEC_dot xyz_dot (
        .i_clk(i_clk),
        .i_a_x(i_a_x),
        .i_a_y(i_a_y),
        .i_a_z(i_a_z),
        .i_b_x(i_b_x),
        .i_b_y(i_b_y),
        .i_b_z(i_b_z),
        .o_dot(dot)
    );
    FpAdd xy_sum_add (
        .iCLK(i_clk),
        .iA  (dot),
        .iB  (w_prod),
        .oSum(o_dot)
    );
endmodule

module VEC_norm (
    input i_clk,
    input [26:0] i_x,
    input [26:0] i_y,
    input [26:0] i_z,
    output [26:0] o_mag
);
    // 4 + 5 = 9 cycles to complete
    wire [26:0] x_squared, y_squared, z_squared, dot;
    VEC_dot sqr_dot (
        .i_clk(i_clk),
        .i_a_x(i_x),
        .i_a_y(i_y),
        .i_a_z(i_z),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .o_dot(dot)
    );
    FP_sqrt sqrt (
        .i_clk(i_clk),
        .i_a(dot),
        .o_sqrt(o_mag)
    );
endmodule


module VEC_normalize (
    input i_clk,
    input [26:0] i_x,
    input [26:0] i_y,
    input [26:0] i_z,
    output [26:0] o_norm_x,
    output [26:0] o_norm_y,
    output [26:0] o_norm_z
);
    // 4 + 5 = 9 cycles to complete
    wire [26:0] dot, inv_sqrt;
    VEC_dot sqr_dot (
        .i_clk(i_clk),
        .i_a_x(i_x),
        .i_a_y(i_y),
        .i_a_z(i_z),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .o_dot(dot)
    );
    FpInvSqrt inv_sq (
        .iCLK(i_clk),
        .iA(dot),
        .oInvSqrt(inv_sqrt)
    );
    FpMul x_scale_mul (
        .iA(i_x),
        .iB(inv_sqrt),
        .oProd(o_norm_x)
    );
    FpMul y_scale_mul (
        .iA(i_y),
        .iB(inv_sqrt),
        .oProd(o_norm_y)
    );
    FpMul z_scale_mul (
        .iA(i_z),
        .iB(inv_sqrt),
        .oProd(o_norm_z)
    );
endmodule

module VEC_3x3_mult (
    input i_clk,
    input [26:0] i_m_1_1,
    input [26:0] i_m_1_2,
    input [26:0] i_m_1_3,
    input [26:0] i_m_2_1,
    input [26:0] i_m_2_2,
    input [26:0] i_m_2_3,
    input [26:0] i_m_3_1,
    input [26:0] i_m_3_2,
    input [26:0] i_m_3_3,
    input [26:0] i_x,
    input [26:0] i_y,
    input [26:0] i_z,
    output [26:0] o_x,
    output [26:0] o_y,
    output [26:0] o_z
);
    VEC_dot x (
        .i_clk(i_clk),
        .i_a_x(i_m_1_1),
        .i_a_y(i_m_1_2),
        .i_a_z(i_m_1_3),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .o_dot(o_x)
    );
    VEC_dot y (
        .i_clk(i_clk),
        .i_a_x(i_m_2_1),
        .i_a_y(i_m_2_2),
        .i_a_z(i_m_2_3),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .o_dot(o_y)
    );
    VEC_dot z (
        .i_clk(i_clk),
        .i_a_x(i_m_3_1),
        .i_a_y(i_m_3_2),
        .i_a_z(i_m_3_3),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .o_dot(o_z)
    );
endmodule

// uh oh
module VEC_4x4_mult (
    input i_clk,
    input [26:0] i_m_1_1,
    input [26:0] i_m_1_2,
    input [26:0] i_m_1_3,
    input [26:0] i_m_1_4,
    input [26:0] i_m_2_1,
    input [26:0] i_m_2_2,
    input [26:0] i_m_2_3,
    input [26:0] i_m_2_4,
    input [26:0] i_m_3_1,
    input [26:0] i_m_3_2,
    input [26:0] i_m_3_3,
    input [26:0] i_m_3_4,
    input [26:0] i_m_4_1,
    input [26:0] i_m_4_2,
    input [26:0] i_m_4_3,
    input [26:0] i_m_4_4,
    input [26:0] i_x,
    input [26:0] i_y,
    input [26:0] i_z,
    input [26:0] i_w,
    output [26:0] o_x,
    output [26:0] o_y,
    output [26:0] o_z
);

    VEC_dot_4 x (
        .i_clk(i_clk),
        .i_a_x(i_m_1_1),
        .i_a_y(i_m_1_2),
        .i_a_z(i_m_1_3),
        .i_a_w(i_m_1_4),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .i_b_w(i_w),
        .o_dot(o_x)
    );
    VEC_dot_4 y (
        .i_clk(i_clk),
        .i_a_x(i_m_2_1),
        .i_a_y(i_m_2_2),
        .i_a_z(i_m_2_3),
        .i_a_w(i_m_2_4),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .i_b_w(i_w),
        .o_dot(o_y)
    );
    VEC_dot_4 z (
        .i_clk(i_clk),
        .i_a_x(i_m_3_1),
        .i_a_y(i_m_3_2),
        .i_a_z(i_m_3_3),
        .i_a_w(i_m_3_4),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .i_b_w(i_w),
        .o_dot(o_z)
    );
    VEC_dot_4 w (
        .i_clk(i_clk),
        .i_a_x(i_m_4_1),
        .i_a_y(i_m_4_2),
        .i_a_z(i_m_4_3),
        .i_a_w(i_m_4_4),
        .i_b_x(i_x),
        .i_b_y(i_y),
        .i_b_z(i_z),
        .i_b_w(i_w),
        .o_dot(o_w)
    );

endmodule
/* verilator lint_on UNUSEDSIGNAL */  /* verilator lint_on DECLFILENAME */
