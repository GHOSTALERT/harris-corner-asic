"""Derive worst-case bounds by enumeration (not by hand). Run: python3 model/bounds.py"""
import itertools, numpy as np
gx = np.array([[-1,0,1],[-2,0,2],[-1,0,1]]).ravel(); gy = np.array([[-1,-2,-1],[0,0,0],[1,2,1]]).ravel()
# Ix, Iy are linear in the 9 pixels -> extremes at hypercube vertices
V = np.array(list(itertools.product([0,255], repeat=9)))
IX = V@gx; IY = V@gy
print('Ix range', IX.min(), IX.max(), ' Iy range', IY.min(), IY.max())
# joint extremes at vertices (Ix^2+Iy^2 convex -> exact; IxIy: vertex lower bound, independent bound is rigorous)
print('joint max Ix^2 (vertices)', (IX**2).max(), ' joint max |IxIy| (vertices)', abs(IX*IY).max())
a = 1020
print('independent bounds: Pxx,Pyy max', a*a, ' |Pxy| max', a*a, ' 2^20 =', 2**20)
S = 25*a*a; print('Sxx,Syy max', S, '2^25 =', 2**25, ' |Sxy| max', S)
print('Sxx*Syy max', S*S, '2^50 =', 2**50, ' Sxy^2 max', S*S)
T = 2*S; print('trace max', T, '2^26 =', 2**26, ' trace^2 max', T*T, '2^52 =', 2**52)
KF = 10; KQmax = 2**(KF+1)-1
print('K_Q max', KQmax, ' Kq*tr^2 max', KQmax*T*T, '2^63 =', 2**63)
print('det range', -S*S, S*S, ' det<<K max', (S*S)<<KF, '2^60 =', 2**60)
lo = -(S*S<<KF) - KQmax*T*T if False else -KQmax*T*T - 0   # R_s <= det_s_max - ktr_min ; R_s >= det_s_min - ktr_max
lo = -(S*S<<KF) - KQmax*T*T; hi = (S*S<<KF)
print('R_s range', lo, hi, ' signed64 range', -2**63, 2**63-1, ' fits:', -2**63 <= lo and hi < 2**63)
