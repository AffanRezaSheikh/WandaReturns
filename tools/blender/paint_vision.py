"""Paints Vision's textures to fit the realistic body (measurements in
vision_spec.py), following the owner's turnaround sheet: teal-grey suit with
crimson panels, gauntlets and boots, crimson face with teal cranium plates,
and the yellow cape with crimson circuit stripes. Flat colour blocks and ink
lines; the muscle shading itself comes from the real geometry.

Run with the system Python (needs Pillow):  python3 tools/blender/paint_vision.py
Writes tools/blender/textures/vision_{body,head,cape}.png
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vision_spec as S

SS = 2
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")
T, TD, TL, TLINE = S.TEAL, S.TEAL_D, S.TEAL_L, S.TEAL_LINE
C, CD, CL, CLINE = S.CRIM, S.CRIM_D, S.CRIM_L, S.CRIM_LINE
INK = S.INK


def catmull(pts, closed=False, n=12):
    p = list(pts)
    ext = ([p[-1]] + p + [p[0], p[1]]) if closed else ([p[0]] + p + [p[-1]])
    out = []
    for i in range(len(p) if closed else len(p) - 1):
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        for k in range(n):
            t = k / n
            out.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    if not closed:
        out.append(p[-1])
    return out


def mx(pts, s):
    return [(x * s, z) for x, z in pts]


class Canvas:
    def __init__(self, w, h, mapper, bg):
        self.w, self.h, self.map = w, h, mapper
        self.img = Image.new("RGB", (w * SS, h * SS), bg)
        self.d = ImageDraw.Draw(self.img)

    def px(self, pts):
        return [(self.map(p)[0] * SS, self.map(p)[1] * SS) for p in pts]

    def poly(self, pts, fill, line=None, w=2.5):
        self.d.polygon(self.px(pts), fill=fill)
        if line:
            self.line(list(pts) + [pts[0]], line, w)

    def line(self, pts, col, w=2.5):
        q = self.px(pts)
        ww = max(1, int(round(w * SS)))
        self.d.line(q, fill=col, width=ww, joint="curve")
        for x, y in (q[0], q[-1]):
            self.d.ellipse([x - ww / 2, y - ww / 2, x + ww / 2, y + ww / 2], fill=col)

    def spline(self, ctrl, col, w=2.5):
        self.line(catmull(ctrl), col, w)

    def blob(self, ctrl, fill, line=None, w=2.5):
        self.poly(catmull(ctrl, closed=True), fill, line, w)

    def done(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def frame(a, b):
    """Local frame along a limb seen from the front: f(t, s) -> (x, z); t metres from a to b, s metres outward."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln
    return (lambda t, s: (a[0] + ux * t - uz * s, a[1] + uz * t + ux * s)), ln


SH, EL, WR = [(p[0], p[2]) for p in (S.SHOULDER, S.ELBOW, S.WRIST)]
UPPER, UPPER_LEN = frame(SH, EL)
FORE, FORE_LEN = frame(EL, WR)
BT = S.BOOT_TOP


def loc(f, pts, s):
    return mx([f(t, q) for t, q in pts], s)


def leg(pts, s):
    """Points given as (offset from the leg's centre line, z)."""
    return [((S.leg_x(z) + o) * s, z) for o, z in pts]


# ------------------------------------------------------------------ body
def body_base(c, back):
    """Colour blocks that wrap round the silhouette, identical on front and back."""
    for s in (1, -1):
        top = [(-0.045, BT), (-0.018, BT + 0.04), (0.018, BT + 0.04), (0.045, BT)] if not back else [(-0.024, BT), (0.0, BT - 0.024), (0.024, BT)]
        edge = leg([(-0.16, BT)] + top + [(0.16, BT)], s)
        c.poly([(0.01 * s, -0.03)] + edge + [(0.42 * s, -0.03)], C)                                            # boots
        c.poly(leg([(-0.022, BT - 0.012), (-0.10, BT - 0.012), (-0.10, 0.03), (-0.03, 0.03)], s), CD)
        c.line(edge, INK, 3)
        c.line([(x, z - 0.03) for x, z in edge], CLINE, 2)
        c.spline(leg([(-0.07, 0.132), (0.0, 0.118), (0.07, 0.132)], s), CLINE, 2.5)
        # gauntlet and glove
        c.poly(loc(FORE, [(0.034, -0.105), (0.008, 0.0), (0.034, 0.105), (0.62, 0.16), (0.62, -0.13)], s), C)
        c.poly(loc(FORE, [(0.05, -0.105), (0.06, -0.028), (0.62, -0.028), (0.62, -0.13)], s), CD)
        c.poly(loc(FORE, [(0.034, -0.105), (0.008, 0.0), (0.034, 0.105), (0.064, 0.105), (0.038, 0.0), (0.064, -0.105)], s), CL)
        c.line(loc(FORE, [(0.034, -0.105), (0.008, 0.0), (0.034, 0.105)], s), INK, 3)
        c.line(loc(FORE, [(0.064, -0.105), (0.038, 0.0), (0.064, 0.105)], s), CLINE, 2.5)
        for t in (0.115, 0.175):
            c.line(loc(FORE, [(t, -0.08), (t - 0.012, 0.0), (t, 0.08)], s), CLINE, 2)
        c.poly(loc(FORE, [(0.08, 0.014), (0.08, 0.032), (0.215, 0.024), (0.215, 0.010)], s), CL)
        c.line(loc(FORE, [(FORE_LEN - 0.004, -0.07), (FORE_LEN - 0.004, 0.07)], s), CLINE, 2.5)
        # upper arm: strap over the shoulder, stripe down the outside, chevron above the elbow
        c.poly(mx([(0.105, 1.605), (0.125, 1.625), (0.225, 1.60), (0.305, 1.535), (0.280, 1.505), (0.215, 1.565)], s), C, CLINE, 2.5)
        c.poly(loc(UPPER, [(-0.06, 0.04), (-0.06, 0.13), (0.14, 0.13), (0.185, 0.062), (0.14, 0.04)], s), C)
        c.line(loc(UPPER, [(-0.06, 0.04), (0.14, 0.04), (0.185, 0.062), (0.14, 0.13)], s), CLINE, 2.5)
        c.poly(loc(UPPER, [(0.205, -0.10), (0.243, 0.0), (0.205, 0.10), (0.24, 0.10), (0.28, 0.0), (0.24, -0.10)], s), C, CLINE, 2.5)
        # crimson flank and outer-thigh panels
        if back:
            c.poly(mx([(0.135, 1.235), (0.262, 1.235), (0.262, 0.99), (0.125, 0.99), (0.10, 1.11)], s), C, CLINE, 2.5)
            c.poly(mx([(0.15, 0.972), (0.32, 0.972), (0.32, 0.70), (0.205, 0.655), (0.165, 0.80)], s), C, CLINE, 2.5)
        else:
            c.poly(mx([(0.112, 1.20), (0.16, 1.235), (0.262, 1.235), (0.262, 0.99), (0.15, 0.99), (0.078, 1.047), (0.106, 1.115)], s), C, CLINE, 2.5)
            c.blob(mx([(0.140, 1.085), (0.172, 1.08), (0.176, 1.048), (0.144, 1.038)], s), T, CLINE, 2)
            c.poly(mx([(0.172, 0.972), (0.32, 0.972), (0.32, 0.70), (0.212, 0.655), (0.186, 0.80)], s), C, CLINE, 2.5)


def body_front():
    c = Canvas(1024, 1408, lambda p: ((p[0] - S.BX0) * 800.0, (S.BZ1 - p[1]) * 800.0), T)
    c.poly([(-0.125, 1.66), (0.125, 1.66), (0.085, 1.52), (0.032, 1.45), (0, 1.412), (-0.032, 1.45), (-0.085, 1.52)], C, CLINE, 2.5)   # collar triangle
    c.poly([(-0.044, 1.428), (0.044, 1.428), (0.038, 1.35), (0.022, 1.30), (0, 1.266), (-0.022, 1.30), (-0.038, 1.35)], C, CLINE, 2.5)  # sternum
    body_base(c, False)
    path = [(0.122, 1.50), (0.142, 1.42), (0.140, 1.345), (0.124, 1.295), (0.118, 1.20), (0.110, 1.12), (0.088, 1.066), (0.056, 1.046)]
    for s in (1, -1):
        c.spline(mx(path, s), CLINE, 9)                                                                        # crimson pinstripe
        c.spline(mx(path, s), C, 5.5)
        c.spline(mx([(0.030, 1.338), (0.075, 1.318), (0.140, 1.322), (0.195, 1.362), (0.212, 1.43)], s), TLINE, 2.5)   # under the pectoral
        for z in (1.262, 1.196, 1.132):
            c.spline(mx([(0.012, z + 0.004), (0.048, z - 0.004), (0.084, z + 0.006)], s), TLINE, 2)
        c.spline(mx([(0.070, 1.038), (0.064, 0.985), (0.036, 0.905), (0.0, 0.855)], s), TLINE, 3)             # trunks panel
        c.spline(mx([(0.036, 1.038), (0.026, 0.996), (0.0, 0.978)], s), TLINE, 2)
        c.poly(leg([(-0.05, 0.586), (0.05, 0.586), (0.058, 0.528), (0.032, 0.478), (-0.032, 0.478), (-0.058, 0.528)], s), TD, TLINE, 2.5)   # knee
        c.poly(leg([(0.034, BT - 0.04), (0.048, BT - 0.04), (0.044, 0.16), (0.034, 0.16)], s), CL)            # boot stripe
    c.line([(0, 1.266), (0, 1.066)], TLINE, 2)
    c.line([(-0.070, 1.038), (0.070, 1.038)], TLINE, 3)
    c.poly([(-0.038, 1.043), (0.038, 1.043), (0.032, 1.060), (-0.032, 1.060)], S.GOLD, INK, 2.5)              # belt buckle
    return c.done()


def body_back():
    c = Canvas(1024, 1408, lambda p: ((p[0] - S.BX0) * 800.0, (S.BZ1 - p[1]) * 800.0), T)
    c.poly([(-0.05, 1.66), (0.05, 1.66), (0.056, 1.44), (0.032, 1.22), (0, 1.07), (-0.032, 1.22), (-0.056, 1.44)], C, CLINE, 2.5)       # spine panel
    body_base(c, True)
    for s in (1, -1):
        c.spline(mx([(0.035, 1.22), (0.078, 1.12), (0.122, 1.045)], s), TLINE, 2.5)
        c.line(leg([(0.0, BT - 0.024), (0.0, 0.07)], s), CLINE, 2.5)
        c.blob(loc(UPPER, [(0.262, -0.04), (0.262, 0.04), (0.322, 0.045), (0.322, -0.035)], s), TD, TLINE, 2)   # elbow pad
    c.line([(-0.122, 1.045), (0.122, 1.045)], TLINE, 3)
    return c.done()


# ------------------------------------------------------------------ head (cylindrical: degrees round the head, height)
def paint_head():
    w, h = 1024, 704
    c = Canvas(w, h, lambda p: ((p[0] / 360.0 + 0.5) * w, (1 - (p[1] - S.HZ0) / (S.HZ1 - S.HZ0)) * h), T)

    def ring(pts, fill, line=CLINE, wd=2.5):
        for s in (1, -1):
            for shift in (0, -360 * s):
                c.poly([(th * s + shift, z) for th, z in pts], fill, line, wd)

    def rrect(t0, t1, z0, z1, r=0.25):
        dt, dz = (t1 - t0) * r * 0.5, (z1 - z0) * r
        return [(t0 + dt, z0), (t1 - dt, z0), (t1, z0 + dz), (t1, z1 - dz), (t1 - dt, z1), (t0 + dt, z1), (t0, z1 - dz), (t0, z0 + dz)]

    ring([(48, 1.45), (48, 1.688), (84, 1.688), (100, 1.700), (116, 1.722), (181, 1.722), (181, 1.45)], C)       # jaw, neck, nape
    ring(rrect(70, 174, 1.776, 1.812), C)                                                                        # band above the ear
    ring(rrect(118, 171, 1.826, 1.862), C)                                                                       # crown plates
    for shift in (0, 360, -360):                                                                                 # grey U on the nape
        u_line = [(146 + shift, 1.70), (158 + shift, 1.672), (202 + shift, 1.672), (214 + shift, 1.70)]
        c.line(u_line, TLINE, 9)
        c.line(u_line, "#86a09d", 5)
    half = [(0, 1.822), (5, 1.838), (10, 1.853), (20, 1.862), (32, 1.852), (44, 1.826), (54, 1.790), (58, 1.752), (58, 1.704), (54, 1.662), (50, 1.45)]
    face = half + [(-th, z) for th, z in reversed(half)]
    c.poly(face, C, INK, 3)
    c.poly([(-10, 1.522), (10, 1.522), (12, 1.598), (-12, 1.598)], TD, TLINE, 2.5)                              # throat block
    c.line([(0, 1.522), (0, 1.598)], TLINE, 2)
    for s in (1, -1):
        c.blob([(s * 5, 1.772), (s * 19, 1.781), (s * 34, 1.772), (s * 35, 1.748), (s * 20, 1.738), (s * 6, 1.745)], CD)   # eye socket
        c.spline([(s * 11, 1.742), (s * 19, 1.722), (s * 23, 1.700), (s * 17, 1.662)], CLINE, 2)                # cheek seam
        c.spline([(s * 36, 1.742), (s * 34, 1.706), (s * 31, 1.674), (s * 25, 1.640)], CLINE, 2)
        c.spline([(s * 12, 1.806), (s * 18, 1.830), (s * 20, 1.856)], CLINE, 2)                                 # forehead seam
    c.poly([(-4.5, 1.652), (4.5, 1.652), (6.5, 1.612), (-6.5, 1.612)], "#4b6c6e", TLINE, 2)                     # chin strip
    img = c.done()
    gx, gy = c.map((0.0, S.GEM[2]))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in ((34, 60), (24, 90), (15, 150)):
        gd.ellipse([gx - r, gy - r * 1.25, gx + r, gy + r * 1.25], fill=(255, 214, 110, a))
    out = img.convert("RGBA")
    out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))
    return out.convert("RGB")


# ------------------------------------------------------------------ cape (flattened cloth: metres across, fraction down)
def paint_cape():
    w = h = 1024
    wb = S.CAPE["w_bot"]
    c = Canvas(w, h, lambda p: ((p[0] / (2 * wb) + 0.5) * w, p[1] * h), S.CAPE_Y)

    def rad(rho, v):
        return (rho * S.cape_half_width(v), v)

    def stripe(pts, wd):
        c.line(pts, CLINE, wd + 4)
        c.line(pts, C, wd)

    for s in (1, -1):
        for rho, v0, dr in ((0.22, 0.30, 0.045), (0.60, 0.22, 0.05), (0.82, 0.45, 0.03)):
            c.poly([rad(s * rho, v0), rad(s * (rho + dr), 1.0), rad(s * (rho - dr * 0.4), 1.0)], S.CAPE_SH)
        c.poly([rad(s * 0.935, 0.0), rad(s * 1.02, 0.0), rad(s * 1.02, 1.0), rad(s * 0.935, 1.0)], C)
        c.line([rad(s * 0.935, 0.0), rad(s * 0.935, 1.0)], CLINE, 2.5)
        stripe([(s * 0.066, 0.0), (s * 0.066, 0.335), (s * 0.098, 0.39), (s * 0.098, 0.745), (s * 0.066, 0.80), (s * 0.066, 1.0)], 6)
        stripe([rad(s * 0.42, 0.0), rad(s * 0.42, 0.34), rad(s * 0.50, 0.40), rad(s * 0.50, 0.74), rad(s * 0.42, 0.80), rad(s * 0.42, 1.0)], 9)
        stripe([rad(s * 0.64, 0.0), rad(s * 0.64, 0.50), rad(s * 0.56, 0.58), rad(s * 0.56, 1.0)], 20)
        stripe([rad(s * 0.935, 0.44), rad(s * 0.74, 0.585), rad(s * 0.74, 1.0)], 24)
        stripe([rad(s * 0.80, 0.0), rad(s * 0.80, 0.24), rad(s * 0.86, 0.30)], 12)
        stripe([rad(s * 0.935, 0.80), rad(s * 0.845, 0.80), rad(s * 0.845, 0.90)], 16)
        c.poly([rad(s * 0.86, 0.935), rad(s * 0.90, 0.935), rad(s * 0.90, 1.0), rad(s * 0.86, 1.0)], C, CLINE, 2)
        c.poly([rad(s * 0.62, 0.90), rad(s * 0.665, 0.90), rad(s * 0.665, 1.0), rad(s * 0.62, 1.0)], C, CLINE, 2)
    pts = [(0.021, 0.0), (0.021, 0.35), (0.052, 0.40), (0.052, 0.735), (0.021, 0.785), (0.021, 1.0)]
    c.poly(pts + [(-x, v) for x, v in reversed(pts)], C, CLINE, 3)
    c.line([(0.0, 0.42), (0.0, 0.715)], CD, 3)
    return c.done()


def main():
    os.makedirs(OUT, exist_ok=True)
    body = Image.new("RGB", (2048, 1408))
    body.paste(body_front(), (0, 0))
    body.paste(body_back(), (1024, 0))
    body.save(os.path.join(OUT, "vision_body.png"))
    paint_head().save(os.path.join(OUT, "vision_head.png"))
    paint_cape().save(os.path.join(OUT, "vision_cape.png"))
    print("PAINTED", OUT)


if __name__ == "__main__":
    main()
