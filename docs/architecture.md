# Architecture

```
pixel_in[7:0],pixel_valid
  -> window3x3 (2 line buffers, 3 column regs)  -- win_valid for r>=2,c>=2
  -> sobel_grad  (Ix,Iy 11b signed)
  -> gradient_products (Pxx,Pyy 20u ; Pxy 21s)
  -> boxsum5x5  (4 line buffers/channel, vertical 5-sum then 5-column horizontal sum)
  -> harris_response (exact scaled R_s, 64b signed)
  -> corner_threshold (R_s > thr)  -> corner_out, corner_valid
```

## Token-based streaming
Only *valid* tokens carry data between stages. Spatial stages (window3x3, boxsum5x5) advance their counters and line buffers **only on an input token**, so gaps in `pixel_valid` never corrupt alignment. Arithmetic stages are pure registered pipelines with a valid bit; a token always advances exactly one stage per clock, so no flush pixels are needed: the last output appears a fixed number of clocks after the last required input pixel.

The Sobel stage emits tokens only for interior centres, so boxsum5x5 sees a (W-2) x (H-2) image (raster order, with the 2 skipped border columns simply absent). boxsum5x5 therefore needs W,H >= 7 to produce any output; smaller images produce no output (documented behaviour, tested at 7x7 -> 1 output).

## Coordinates (input image, (row, col), origin top-left)
* window3x3: pixel (r,c) accepted -> window centred at (r-1, c-1); valid if r>=2 and c>=2 -> centres rows 1..H-2, cols 1..W-2.
* boxsum5x5 input token = Sobel centre (R,C) in the interior image (R = r-1, C = c-1 in input coordinates, interior index = input index - 1). Output valid for interior index >= 4 -> box centred at interior index - 2, i.e. input centre rows/cols 3..H-4 / 3..W-4.
* Combined: the 7x7 footprint; the pixel accepted last for output centre (r0,c0) is (r0+3, c0+3).

## Latency (clock cycles, register stages)
| Stage | Latency |
|---|---|
| window3x3 | 1 |
| sobel_grad | 1 |
| gradient_products | 1 |
| boxsum5x5 | 2 |
| harris_response | 4 |
| corner_threshold | 1 |
| **Total** | **10** |

Definition: pixel accepted at the clock edge following the cycle where `pixel_valid=1`, output visible 10 cycles after the cycle in which the pixel was driven (checked cycle-exactly in `tb_harris`, with and without input gaps). Output tokens appear in raster order of centres; throughput is one input pixel per clock (no stalls, no back-pressure).

## Reset
Synchronous, active-low `rst_n`, applied to counters and valid bits only. Datapath and line-buffer data are not reset (masked by valid/ position counters until populated); reset mid-frame restarts the counters at (0,0).

## Memory
Line buffers are plain register arrays indexed by the column counter (asynchronous read, synchronous write), the portable baseline. For large widths these should be replaced by SRAM macros/compiled memories (not done here).
