`timescale 1ns / 1ps
`define CORDW 10 // Coordinate width 2^10 = 1024

`define SCREEN_WIDTH 640
`define SCREEN_HEIGHT 480

// `define EPSILON 27'h1ee6666 // 0.1
`define EPSILON 27'h1e11eb8 //0.01
// `define EPSILON 27'h1f26666 // 0.2
// `define MAX_DIST 27'h2180000
`define MAX_DIST 27'h20d0000
// glsl float z = u_resolution.y / tan(radians(FIELD_OF_VIEW) / 2.0);
// see get_fov_magic_num.c and fractal.frag
`define FOV_MAGIC_NUMBER 27'h1fc0000

/* verilator lint_off DECLFILENAME */
/* verilator lint_off UNUSEDSIGNAL */

module distance_to_color (
    input [26:0] distance,
    input [9:0] num_itr,
    input hit,
    output [11:0] o_color
);
    wire [7:0] red, green, blue;
    wire [26:0] distance_scaled;
    wire signed [15:0] distance_int;
    FpShift scale (
        .iA(distance),
        .iShift(8),
        .oShifted(distance_scaled)
    );
    Fp2Int dist_fp_2_int (
        .iA(distance_scaled),
        .oInteger(distance_int)
    );
    wire [7:0] col;
    // assign green = hit ? 8'd255 - distance_int[7:0] + 8'd125 : 8'd0;
    assign blue = hit ? 8'd255 : 8'd0;
    // assign red   = 8'd255 - distance_int[7:0] + 8'd125;
    // assign col   = hit ? 8'd255 : 8'd0;
    assign col = hit ? {distance_int[7], distance_int[6:0]} + 8'd125 : 8'd0;
    // assign col   = 8'd255 - distance_int[7:0] + 8'd125;
    assign red = col;
    // assign green = hit ? 8'd255 - distance_int[8:1] + 8'd125 : 8'd0;
    // assign red   = hit ? 8'd255 : 8'd0;
    // assign green = hit ? 8'd255 : 8'd0;
    assign green = 0;
    // assign blue  = col;
    // assign o_color = hit ? distance_int[7:0] : 8'd0;
    assign o_color = {red[7:4], green[7:4], blue[7:4]};
endmodule

/*
vec3 fragToWorldVector() {
    vec2 xy = gl_FragCoord.xy - u_resolution.xy / 2.0;
    float z = u_resolution.y / tan(radians(FIELD_OF_VIEW) / 2.0);
    vec3 viewDir = lookAt(
            -u_camera,
            vec3(0.0, 0.0, 0.0),
            vec3(0.0, 1.0, 0.0)
        ) * normalize(vec3(xy, -z));
    return normalize(viewDir.xyz);
*/
module frag_to_world_vector (
    input i_clk,
    input [`CORDW-1:0] i_x,  // integers, screen coords
    input [`CORDW-1:0] i_y,
    input [26:0] look_at_1_1,  // Look at matrix, calculated on the HPS
    input [26:0] look_at_1_2,  // https://lygia.xyz/space/lookAt
    input [26:0] look_at_1_3,
    input [26:0] look_at_2_1,
    input [26:0] look_at_2_2,
    input [26:0] look_at_2_3,
    input [26:0] look_at_3_1,
    input [26:0] look_at_3_2,
    input [26:0] look_at_3_3,
    output [26:0] o_x,  // floats, world space vector
    output [26:0] o_y,
    output [26:0] o_z
);
    wire signed [`CORDW:0] x_signed, y_signed, x_adj, y_adj;
    assign x_signed = {1'b0, i_x};
    assign y_signed = {1'b0, i_y};

    // vec2 xy = gl_FragCoord.xy - u_resolution.xy / 2.0;
    assign x_adj = x_signed - (`SCREEN_WIDTH >> 1);
    assign y_adj = y_signed - (`SCREEN_HEIGHT >> 1);
    wire [26:0] x_fp, y_fp, z_fp, res_x_fp, res_y_fp;
    Int2Fp px_fp (
        .iInteger({{5{x_adj[`CORDW]}}, x_adj[`CORDW:0]}),
        .oA(x_fp)
    );
    Int2Fp py_fp (
        .iInteger({{5{y_adj[`CORDW]}}, y_adj[`CORDW:0]}),
        .oA(y_fp)
    );
    Int2Fp calc_res_x_fp (
        .iInteger(`SCREEN_WIDTH),
        .oA(res_x_fp)
    );
    Int2Fp calc_res_y_fp (
        .iInteger(`SCREEN_HEIGHT),
        .oA(res_y_fp)
    );

    // float z = u_resolution.y / tan(radians(FIELD_OF_VIEW) / 2.0);
    FpMul z_calc (
        .iA(res_y_fp),
        .iB(`FOV_MAGIC_NUMBER),
        .oProd(z_fp)
    );


    // vec3 viewDir = lookAt(
    //     -u_camera, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0)
    // ) * normalize(
    //     vec3(xy, -z)
    // );
    wire [26:0] x_norm_fp, y_norm_fp, z_norm_fp;
    VEC_normalize hi (
        .i_clk(i_clk),
        .i_x(x_fp),
        .i_y(y_fp),
        .i_z(z_fp),
        .o_norm_x(x_norm_fp),
        .o_norm_y(y_norm_fp),
        .o_norm_z(z_norm_fp)
    );
    wire [26:0] z_neg_fp;
    FpNegate negate_z (
        .iA(z_norm_fp),
        .oNegative(z_neg_fp)
    );
    VEC_3x3_mult oh_god (
        .i_clk(i_clk),
        .i_m_1_1(look_at_1_1),
        .i_m_1_2(look_at_1_2),
        .i_m_1_3(look_at_1_3),
        .i_m_2_1(look_at_2_1),
        .i_m_2_2(look_at_2_2),
        .i_m_2_3(look_at_2_3),
        .i_m_3_1(look_at_3_1),
        .i_m_3_2(look_at_3_2),
        .i_m_3_3(look_at_3_3),
        .i_x(x_norm_fp),
        .i_y(y_norm_fp),
        .i_z(z_neg_fp),
        .o_x(o_x),
        .o_y(o_y),
        .o_z(o_z)
    );
endmodule

module sdf (
    input clk,
    input [26:0] point_x,
    input [26:0] point_y,
    input [26:0] point_z,
    output [26:0] distance
);
    wire [26:0] cube_dist, sphere_dist;

    box BOX (
        .clk(clk),
        .point_x(point_x),
        .point_y(point_y),
        .point_z(point_z),
        .dim_x(27'h1fc0000),
        .dim_y(27'h1fc0000),
        .dim_z(27'h1fc0000),
        .distance(cube_dist)
    );

    // assign distance = cube_dist;

    sphere BALL (
        .clk(clk),
        .point_x(point_x),
        .point_y(point_y),
        .point_z(point_z),
        .radius(27'h1fd3333),
        .distance(sphere_dist)
    );

    sdf_difference #(
        .SDF_A_PIPELINE_CYCLES(9),
        .SDF_B_PIPELINE_CYCLES(11)
    ) UNION (
        .clk(clk),
        .i_dist_a(sphere_dist),
        .i_dist_b(cube_dist),
        .o_dist(distance)
    );

endmodule

module ray_stage #(
    parameter SDF_STAGES = 11
) (
    input clk,
    input [`CORDW-1:0] pixel_x,
    input [`CORDW-1:0] pixel_y,
    input [26:0] point_x,
    input [26:0] point_y,
    input [26:0] point_z,
    input [26:0] frag_dir_x,
    input [26:0] frag_dir_y,
    input [26:0] frag_dir_z,
    input [26:0] depth,
    output reg [26:0] o_point_x,
    output reg [26:0] o_point_y,
    output reg [26:0] o_point_z,
    output reg [26:0] o_frag_dir_x,
    output reg [26:0] o_frag_dir_y,
    output reg [26:0] o_frag_dir_z,
    output reg [26:0] o_depth,
    output reg [`CORDW-1:0] o_pixel_x,
    output reg [`CORDW-1:0] o_pixel_y,
    output reg o_hit,
    output reg o_max_depth
);
    reg [26:0]
        point_x_pipe[SDF_STAGES+2:0], point_y_pipe[SDF_STAGES+2:0], point_z_pipe[SDF_STAGES+2:0];
    reg [26:0]
        frag_dir_x_pipe[SDF_STAGES+2:0],
        frag_dir_y_pipe[SDF_STAGES+2:0],
        frag_dir_z_pipe[SDF_STAGES+2:0];
    reg [`CORDW-1:0] pixel_x_pipe[SDF_STAGES+2:0], pixel_y_pipe[SDF_STAGES+2:0];
    reg  [26:0] depth_pipe[SDF_STAGES+2:0];
    wire [26:0] distance;
    wire [26:0] scaled_frag_x, scaled_frag_y, scaled_frag_z;
    wire [26:0] new_point_x, new_point_y, new_point_z;
    wire [26:0] new_depth;
    reg hit_pipe[2:0];
    reg max_depth;

    sdf SDF (
        .clk(clk),
        .point_x(point_x),
        .point_y(point_y),
        .point_z(point_z),
        .distance(distance)
    );

    VEC_el_mul scale_mul (
        .i_clk(clk),
        .i_a_x(frag_dir_x_pipe[SDF_STAGES]),
        .i_a_y(frag_dir_y_pipe[SDF_STAGES]),
        .i_a_z(frag_dir_z_pipe[SDF_STAGES]),
        .i_b_x(distance),
        .i_b_y(distance),
        .i_b_z(distance),
        .o_el_mul_x(scaled_frag_x),
        .o_el_mul_y(scaled_frag_y),
        .o_el_mul_z(scaled_frag_z)
    );

    VEC_add new_p_add (
        .i_clk  (clk),
        .i_a_x  (scaled_frag_x),
        .i_a_y  (scaled_frag_y),
        .i_a_z  (scaled_frag_z),
        .i_b_x  (point_x_pipe[SDF_STAGES]),
        .i_b_y  (point_y_pipe[SDF_STAGES]),
        .i_b_z  (point_z_pipe[SDF_STAGES]),
        .o_add_x(new_point_x),
        .o_add_y(new_point_y),
        .o_add_z(new_point_z)
    );

    FpAdd new_depth_add (
        .iCLK(clk),
        .iA  (depth_pipe[SDF_STAGES]),
        .iB  (distance),
        .oSum(new_depth)
    );

    FpCompare ep_compare (
        .iA(`EPSILON),
        .iB(distance),
        .oA_larger(hit_pipe[0])
    );
    FpCompare max_dist_compare (
        .iA(new_depth),
        .iB(`MAX_DIST),
        .oA_larger(max_depth)
    );

    always @(posedge clk) begin
        o_max_depth <= max_depth;
        o_hit <= hit_pipe[2];
        hit_pipe[2] <= hit_pipe[1];
        hit_pipe[1] <= hit_pipe[0];
        o_point_x <= hit_pipe[2] | max_depth ? point_x_pipe[SDF_STAGES+2] : new_point_x;
        o_point_y <= hit_pipe[2] | max_depth ? point_y_pipe[SDF_STAGES+2] : new_point_y;
        o_point_z <= hit_pipe[2] | max_depth ? point_z_pipe[SDF_STAGES+2] : new_point_z;
        o_frag_dir_x <= frag_dir_x_pipe[SDF_STAGES+2];
        o_frag_dir_y <= frag_dir_y_pipe[SDF_STAGES+2];
        o_frag_dir_z <= frag_dir_z_pipe[SDF_STAGES+2];
        o_pixel_x <= pixel_x_pipe[SDF_STAGES+2];
        o_pixel_y <= pixel_y_pipe[SDF_STAGES+2];
        o_depth <= hit_pipe[2] | max_depth ? depth_pipe[SDF_STAGES+2] : new_depth;
    end

    genvar i;
    generate
        for (i = 0; i < SDF_STAGES + 2; i = i + 1) begin : g_ray_pipeline
            always @(posedge clk) begin
                /* verilator lint_off BLKSEQ*/
                point_x_pipe[0] <= point_x;
                point_y_pipe[0] <= point_y;
                point_z_pipe[0] <= point_z;
                frag_dir_x_pipe[0] <= frag_dir_x;
                frag_dir_y_pipe[0] <= frag_dir_y;
                frag_dir_z_pipe[0] <= frag_dir_z;
                pixel_x_pipe[0] <= pixel_x;
                pixel_y_pipe[0] <= pixel_y;
                depth_pipe[0] <= depth;
                /* verilator lint_on BLKSEQ */
                point_x_pipe[i+1] <= point_x_pipe[i];
                point_y_pipe[i+1] <= point_y_pipe[i];
                point_z_pipe[i+1] <= point_z_pipe[i];
                frag_dir_x_pipe[i+1] <= frag_dir_x_pipe[i];
                frag_dir_y_pipe[i+1] <= frag_dir_y_pipe[i];
                frag_dir_z_pipe[i+1] <= frag_dir_z_pipe[i];
                pixel_x_pipe[i+1] <= pixel_x_pipe[i];
                pixel_y_pipe[i+1] <= pixel_y_pipe[i];
                depth_pipe[i+1] <= depth_pipe[i];
            end
        end
    endgenerate
endmodule
/*
rayInfo raymarch() {
    vec3 dir = fragToWorldVector();
    float depth = MIN_DIST;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(u_camera + depth * dir);
        if (dist < EPSILON) {
            return rayInfo(vec3(1.0, 1.0, 1.0) * (MAX_MARCHING_STEPS / (i * 5)));
        }
        depth += dist;
        if (depth >= MAX_DIST) {
            return rayInfo(vec3(0.0, 0.0, 0.0));
        u}
    }
    return rayInfo(vec3(0.0, 1.0, 0.0));
}
*/
module raymarcher #(
    parameter ITR_PER_LOOP = 5,
    parameter FRAG_DIR_PIPELINE_CYCLES = 8,
    parameter PIPELINE_ARR_SIZE = ITR_PER_LOOP + FRAG_DIR_PIPELINE_CYCLES
) (
    input                   clk,
    input                   m10k_clk,
    input                   reset,
    input      [      26:0] look_at_1_1,   // Look at matrix, calculated on the HPS
    input      [      26:0] look_at_1_2,   // https://lygia.xyz/space/lookAt
    input      [      26:0] look_at_1_3,
    input      [      26:0] look_at_2_1,
    input      [      26:0] look_at_2_2,
    input      [      26:0] look_at_2_3,
    input      [      26:0] look_at_3_1,
    input      [      26:0] look_at_3_2,
    input      [      26:0] look_at_3_3,
    input      [      26:0] eye_x,
    input      [      26:0] eye_y,
    input      [      26:0] eye_z,
    input      [`CORDW-1:0] read_pixel_x,
    input      [`CORDW-1:0] read_pixel_y,
    output reg [      11:0] o_color
);
    reg [`CORDW-1:0] x, y;

    reg [26:0] frag_dir_x[ITR_PER_LOOP:0], frag_dir_y[ITR_PER_LOOP:0], frag_dir_z[ITR_PER_LOOP:0];


    reg [26:0] depth[PIPELINE_ARR_SIZE:0];
    reg [26:0]
        point_x[PIPELINE_ARR_SIZE:0], point_y[PIPELINE_ARR_SIZE:0], point_z[PIPELINE_ARR_SIZE:0];
    reg [`CORDW-1:0] pixel_x[PIPELINE_ARR_SIZE:0], pixel_y[PIPELINE_ARR_SIZE:0];
    reg hit[PIPELINE_ARR_SIZE:0], max_depth[PIPELINE_ARR_SIZE:0];
    reg [9:0] itr_before_hit[PIPELINE_ARR_SIZE:0];

    wire send_new_pixel;
    reg [9:0] pipeline_fill_counter;
    reg pipeline_full;

    assign send_new_pixel = hit[PIPELINE_ARR_SIZE] | max_depth[PIPELINE_ARR_SIZE] | ~pipeline_full;

    // assign send_new_pixel = 1;

    always @(posedge clk) begin
        if (reset) begin
            /* verilator lint_off BLKSEQ*/
            x <= 0;
            y <= 0;
            pipeline_fill_counter <= 0;
            pipeline_full <= 0;
            /* verilator lint_on BLKSEQ*/
        end else if (send_new_pixel) begin
            // Set fresh raymarch initial values
            /* verilator lint_off BLKSEQ*/
            itr_before_hit[0] <= 0;
            depth[0] <= 0;
            point_x[0] <= eye_x;
            point_y[0] <= eye_y;
            point_z[0] <= eye_z;
            pixel_x[0] <= x;
            pixel_y[0] <= y;
            x <= x == `SCREEN_WIDTH - 1 ? 0 : x + 1;
            y <= x == `SCREEN_WIDTH - 1 ? (y == `SCREEN_HEIGHT - 1 ? 0 : y + 1) : y;
            /* verilator lint_on BLKSEQ*/
        end else begin
            // Pixel is not done being solved, keep trying
            /* verilator lint_off BLKSEQ*/
            depth[0]   <= depth[PIPELINE_ARR_SIZE];
            point_x[0] <= point_x[PIPELINE_ARR_SIZE];
            point_y[0] <= point_y[PIPELINE_ARR_SIZE];
            point_z[0] <= point_z[PIPELINE_ARR_SIZE];
            pixel_x[0] <= pixel_x[PIPELINE_ARR_SIZE];
            pixel_y[0] <= pixel_y[PIPELINE_ARR_SIZE];
            /* verilator lint_on BLKSEQ*/
        end
        /* verilator lint_off BLKSEQ*/
        if (pipeline_fill_counter < 1000) begin
            pipeline_fill_counter <= pipeline_fill_counter + 1;
        end else begin
            pipeline_full <= 1;
        end
        /* verilator lint_on BLKSEQ*/
    end

    frag_to_world_vector F (
        .i_clk(clk),
        .i_x(pixel_x[0]),
        .i_y(pixel_y[0]),
        .look_at_1_1(look_at_1_1),
        .look_at_1_2(look_at_1_2),
        .look_at_1_3(look_at_1_3),
        .look_at_2_1(look_at_2_1),
        .look_at_2_2(look_at_2_2),
        .look_at_2_3(look_at_2_3),
        .look_at_3_1(look_at_3_1),
        .look_at_3_2(look_at_3_2),
        .look_at_3_3(look_at_3_3),
        .o_x(frag_dir_x[0]),
        .o_y(frag_dir_y[0]),
        .o_z(frag_dir_z[0])
    );

    genvar i;
    generate
        for (i = 0; i < FRAG_DIR_PIPELINE_CYCLES; i = i + 1) begin : g_ray_stages
            always @(posedge clk) begin
                depth[i+1]   <= depth[i];
                point_x[i+1] <= point_x[i];
                point_y[i+1] <= point_y[i];
                point_z[i+1] <= point_z[i];
                pixel_x[i+1] <= pixel_x[i];
                pixel_y[i+1] <= pixel_y[i];
            end
        end
    endgenerate
    genvar n;
    generate
        for (n = 0; n < ITR_PER_LOOP; n = n + 1) begin : g_ray_stages
            always @(posedge clk) begin
                frag_dir_x[n+1] <= frag_dir_x[n];
                frag_dir_y[n+1] <= frag_dir_y[n];
                frag_dir_z[n+1] <= frag_dir_z[n];
            end
            ray_stage its_not_a_stage_mom (
                .clk(clk),
                .pixel_x(pixel_x[n+FRAG_DIR_PIPELINE_CYCLES]),
                .pixel_y(pixel_y[n+FRAG_DIR_PIPELINE_CYCLES]),
                .point_x(point_x[n+FRAG_DIR_PIPELINE_CYCLES]),
                .point_y(point_y[n+FRAG_DIR_PIPELINE_CYCLES]),
                .point_z(point_z[n+FRAG_DIR_PIPELINE_CYCLES]),
                .frag_dir_x(frag_dir_x[n]),
                .frag_dir_y(frag_dir_y[n]),
                .frag_dir_z(frag_dir_z[n]),
                .depth(depth[n+FRAG_DIR_PIPELINE_CYCLES]),
                .o_point_x(point_x[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_point_y(point_y[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_point_z(point_z[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_frag_dir_x(frag_dir_x[n+1]),
                .o_frag_dir_y(frag_dir_y[n+1]),
                .o_frag_dir_z(frag_dir_z[n+1]),
                .o_pixel_x(pixel_x[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_pixel_y(pixel_y[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_depth(depth[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_hit(hit[n+FRAG_DIR_PIPELINE_CYCLES+1]),
                .o_max_depth(max_depth[n+FRAG_DIR_PIPELINE_CYCLES+1])
            );
        end
    endgenerate

    wire [11:0] color_output;
    reg  [11:0] write_color;
    distance_to_color COLOR (
        .distance(depth[PIPELINE_ARR_SIZE]),
        .num_itr(itr_before_hit[PIPELINE_ARR_SIZE]),
        .hit(hit[PIPELINE_ARR_SIZE] & ~max_depth[PIPELINE_ARR_SIZE]),
        .o_color(color_output)
    );

    wire [`CORDW-1:0] write_pixel_x;
    wire [`CORDW-1:0] write_pixel_y;
    assign write_pixel_x = pixel_x[PIPELINE_ARR_SIZE];
    assign write_pixel_y = pixel_y[PIPELINE_ARR_SIZE];
    assign write_color   = color_output;

    M10K do_electric_sheep_dream_of_24_bit_color (
        .q(o_color),
        .d(write_color),
        /* verilator lint_off WIDTHEXPAND */
        .write_address(write_pixel_x + write_pixel_y * `SCREEN_WIDTH),
        .read_address(read_pixel_x + read_pixel_y * `SCREEN_WIDTH),
        /* verilator lint_on WIDTHEXPAND */
        .we(1),
        .clk(m10k_clk)
    );

endmodule

module M10K (
    output reg [11:0] q,
    input [11:0] d,
    input [18:0] write_address,
    read_address,
    input we,
    clk
);
    // force M10K ram style
    reg [11:0] mem[307200-1:0]  /* synthesis ramstyle = "no_rw_check, M10K" */;

    always @(posedge clk) begin
        if (we) begin
            mem[write_address] <= d;
        end
        q <= mem[read_address];  // q doesn't get d in this clock cycle
    end
endmodule

/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on DECLFILENAME */
