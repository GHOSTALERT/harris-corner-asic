# Interface specification: harris_top

| Port | Dir | Width | Description |
|---|---|---|---|
| clk | in | 1 | clock, rising edge |
| rst_n | in | 1 | synchronous active-low reset |
| pixel_in | in | 8 | unsigned grayscale pixel |
| pixel_valid | in | 1 | pixel accepted when 1; gaps allowed anywhere |
| k_q | in | K_FRAC+1 = 11 | k = k_q/2^10, static while pipeline is busy |
| thr | in | R_W = 64 | signed scaled threshold (R*2^K_FRAC), static while busy; strict `>` |
| corner_out | out | 1 | 1 if R_s > thr for this centre |
| corner_valid | out | 1 | 1 only for interior centres (rows 3..H-4, cols 3..W-4) |
| resp_dbg | out | 64 | R_s aligned with corner_out (verification/tuning) |

Parameters: `IMG_W`, `IMG_H` (>= 7 for output), `K_FRAC` (10), `R_W` (54+K_FRAC).

Contract
* Pixels arrive in raster order (row 0 left->right, then row 1, ...). Frames are contiguous: after IMG_W*IMG_H accepted pixels the next accepted pixel is (0,0) of the next frame. There are no frame/line markers; dimensions are parameters. Violating the pixel count desynchronises counters; recover with reset.
* No back-pressure; the design accepts a pixel every cycle.
* Outputs: one `corner_valid` pulse per interior centre, raster order, 10 cycles after the cycle the bottom-right footprint pixel was driven.
* Border pixels (outside rows/cols 3..H-4/W-4) never produce `corner_valid`.
