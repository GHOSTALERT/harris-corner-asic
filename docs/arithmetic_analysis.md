# Arithmetic analysis and width decisions

All bounds below are reproduced by `python3 model/bounds.py` (output in `logs/bounds.log`). Pixels are unsigned 8-bit (0..255).

## Conventions
* Sobel is evaluated as correlation on the window (row 0 = top, col 0 = left): `Ix = (p02+2p12+p22) - (p00+2p10+p20)`, `Iy = (p20+2p21+p22) - (p00+2p01+p02)`.
* `k = K_Q / 2^K_FRAC`, `K_FRAC = 10`, `K_Q` is an 11-bit unsigned runtime input (k < 2). Default `K_Q = 41` -> k = 0.040039 (target 0.04, error 0.1 %; step 1/1024).
* Scaled response: **`R_s = 2^K_FRAC * (Sxx*Syy - Sxy^2) - K_Q * (Sxx+Syy)^2`** (= `R * 2^K_FRAC` for the quantised k). Threshold `thr` is given in the same scaled units (signed, 64 bit). Comparison is **strictly greater**: `corner = R_s > thr`.
* The datapath is exact integer arithmetic. The only quantisation anywhere is the representation of `k`. There is no rounding or truncation of `R`.

## Width table
| Quantity | Math min | Math max | Type | Bits needed | RTL width | Exact? |
|---|---|---|---|---|---|---|
| Pixel | 0 | 255 | unsigned | 8 | 8 | exact |
| Sobel side sums (pos / neg) | 0 | 1020 | unsigned | 10 | 12 signed intermediate | exact |
| Ix, Iy | -1020 | +1020 | signed | 11 | 11 | exact (vertex enumeration of all 512 corner windows) |
| Pxx, Pyy = I^2 | 0 | 1,040,400 | unsigned | 20 (2^20 = 1,048,576) | 20 u | exact |
| Pxy = Ix*Iy | -1,040,400 | +1,040,400 | signed | 21 | 21 s | exact |
| 5-term column sum (internal) | | 5,202,000 | signed | 24 (unsigned data needs +1 sign guard) | IN_W+4 = 24 / 25 | exact |
| Sxx, Syy | 0 | 26,010,000 | unsigned | 25 (2^25 = 33,554,432) | 25 u | exact |
| Sxy | -26,010,000 | +26,010,000 | signed | 26 | 26 s | exact |
| Sxx*Syy | 0 | 6.765e14 | unsigned | 50 (2^50 = 1.126e15) | 50 u | exact |
| Sxy^2 | 0 | 6.765e14 | unsigned | 50 | 50 u (computed as |Sxy|^2) | exact |
| det = SxxSyy - Sxy^2 | -6.765e14 | +6.765e14 | signed | 51 | 51 s | exact |
| trace = Sxx+Syy | 0 | 52,020,000 | unsigned | 26 (2^26 = 67.1e6) | 26 u | exact |
| trace^2 | 0 | 2.706e15 | unsigned | 52 (2^52 = 4.50e15) | 52 u | exact |
| det * 2^10 | -6.93e17 | +6.93e17 | signed | 61 (2^60 = 1.15e18) | 61 s | exact (shift) |
| K_Q * trace^2 (K_Q <= 2047) | 0 | 5.539e18 | unsigned | 63 (2^63 = 9.22e18) | 63 u | exact |
| R_s (default K_FRAC) | -6.23e18 (loose bound) | +6.93e17 | signed | 64 | 64 s | exact |

Notes
* The independent bounds for Pxy, S* are rigorous but not jointly tight: Ix=1020 and Iy=1020 cannot both occur (they conflict on pixel p02), and vertex enumeration gives a joint `max|Ix*Iy| = 585,225`. The RTL deliberately uses the rigorous independent bound so widths never depend on a subtle joint-range proof.
* The R_s lower bound is also loose: the lowest value actually reached in unit tests is -5.539e18 (`Sxx=Syy=max, Sxy=0, K_Q=2047`). It fits 64-bit signed with margin either way.
* Width of `R_W = 54 + K_FRAC` (64 at default) follows from `|R_s| < 2^(53+K_FRAC)`.
* Truncations in RTL (22-bit full products -> 20/21 bit; 26-bit |Sxy|^2 -> 50 bit; 25/26-bit boxsum internal -> output) discard only bits proven zero/sign by the table; the unit tests drive the extreme operands to confirm.
* SystemVerilog sizing: every multiply/add lives in an explicit sized signal; zero extension is explicit (`{1'b0, x}`, `{N{1'b0}}`); signed values use explicit sign-extend (`{4{v[msb]}}`, `$signed`). No unsized literals are used in arithmetic.

## Choosing K_FRAC
A coarser k grid changes which corners cross the threshold: with K_FRAC=8, the nearest k to 0.04 is 10/256 = 0.0391 (2.3 % error); K_FRAC=10 gives 41/1024 (0.1 %). Multiplier cost is only the extra 2 bits of `K_Q`. `K_FRAC` is a module parameter; `K_Q` is a runtime input and **must be held static while data is in the pipeline** (it is consumed at response stage 3).

## Threshold scale contract
`thr` is in `R * 2^K_FRAC` units. To use a real-valued threshold T: `thr = round(T * 2^K_FRAC)`. The Python model (`model/harris_reference.py`) uses the identical definition.
