"""Golden reference for the streaming Harris detector (v1, no NMS).
Coordinates: input image (r,c). Output centre (r,c) valid for 3 <= r <= H-4, 3 <= c <= W-4.
Sobel centre (r,c) valid for 1..H-2 / 1..W-2; box-sum centre needs a 5x5 block of valid Sobel centres.
Fixed-point contract (matches RTL exactly):  R_s = 2^K_FRAC*(Sxx*Syy - Sxy^2) - K_Q*(Sxx+Syy)^2
corner = R_s > THR_s  (strict).  k = K_Q/2^K_FRAC.
All integer maths uses Python ints (object arrays) -> no silent overflow.
"""
import numpy as np

K_FRAC = 10
K_Q_DEFAULT = 41            # k ~= 0.040039

def sobel(img):
    a = np.asarray(img, dtype=np.int64)
    H, W = a.shape
    ix = np.zeros((H, W), np.int64); iy = np.zeros((H, W), np.int64)
    ok = np.zeros((H, W), bool)
    if H >= 3 and W >= 3:
        p = lambda di, dj: a[1+di:H-1+di, 1+dj:W-1+dj]
        ix[1:H-1, 1:W-1] = (p(-1,1) + 2*p(0,1) + p(1,1)) - (p(-1,-1) + 2*p(0,-1) + p(1,-1))
        iy[1:H-1, 1:W-1] = (p(1,-1) + 2*p(1,0) + p(1,1)) - (p(-1,-1) + 2*p(-1,0) + p(-1,1))
        ok[1:H-1, 1:W-1] = True
    return ix, iy, ok

def box5(x, ok):
    """5x5 box sum centred at (r,c); valid where the full 5x5 block lies in `ok`."""
    H, W = x.shape
    s = np.zeros((H, W), np.int64); v = np.zeros((H, W), bool)
    for r in range(2, H-2):
        for c in range(2, W-2):
            if ok[r-2:r+3, c-2:c+3].all():
                s[r, c] = x[r-2:r+3, c-2:c+3].sum(); v[r, c] = True
    return s, v

def run(img, k_q=K_Q_DEFAULT, k_frac=K_FRAC, thr=0):
    ix, iy, ok = sobel(img)
    pxx, pyy, pxy = ix*ix, iy*iy, ix*iy
    sxx, v = box5(pxx, ok); syy, _ = box5(pyy, ok); sxy, _ = box5(pxy, ok)
    X = sxx.astype(object); Y = syy.astype(object); Z = sxy.astype(object)
    det = X*Y - Z*Z
    tr = X + Y
    R_s = (det << k_frac) - k_q * tr * tr          # exact, scaled by 2^k_frac
    R_s = np.where(v, R_s, 0).astype(object)
    corner = np.array([[bool(v[r, c]) and R_s[r, c] > thr for c in range(v.shape[1])]
                       for r in range(v.shape[0])])
    return dict(ix=ix, iy=iy, sobel_ok=ok, pxx=pxx, pyy=pyy, pxy=pxy,
                sxx=sxx, syy=syy, sxy=sxy, valid=v, R_s=R_s, corner=corner)

def run_float(img, k=0.04):
    """Unquantised mathematical reference (float64 on exact integer sums) for quantisation study."""
    m = run(img, k_q=0)
    X = m['sxx'].astype(float); Y = m['syy'].astype(float); Z = m['sxy'].astype(float)
    return np.where(m['valid'], X*Y - Z*Z - k*(X+Y)**2, 0.0), m['valid']

if __name__ == '__main__':
    img = np.zeros((16, 16), np.uint8); img[8:, 8:] = 255
    m = run(img, thr=0)
    print('valid', m['valid'].sum(), 'corners', int(m['corner'].sum()))
