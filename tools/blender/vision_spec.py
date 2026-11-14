"""Shared measurements for Vision, used by the Blender builder (geometry, UVs)
and the texture painter. Vision's body is the realistic base mesh shaped by
basemesh.heroic(); the numbers below were measured from it (metres, +Z up,
character faces -Y, +X is his left). Pure Python: no bpy, no PIL.
"""
import math

HEIGHT = 1.88
# joints (left side)
SHOULDER, ELBOW, WRIST, HAND_TIP = (0.200, 0.0, 1.500), (0.330, 0.001, 1.220), (0.418, -0.071, 0.987), (0.475, -0.124, 0.800)
HIP, KNEE, ANKLE, TOE = (0.100, -0.010, 0.970), (0.155, 0.019, 0.502), (0.191, 0.066, 0.078), (0.247, -0.149, 0.030)
AXIS = [0.96, 1.10, 1.30, 1.50, 1.64, 1.88]          # hips, spine, chest, neck, head, crown
BOOT_TOP = 0.43
# head
HEAD_Y = -0.05                    # axis of the cylindrical head mapping
HZ0, HZ1 = 1.50, 1.89             # height range covered by the head texture
EYE = (0.034, -0.125, 1.758)
EAR = (0.086, -0.042, 1.733)
GEM = (0.0, -0.150, 1.808)
CHIN_Z, MOUTH_Z, NOSE_Z, TOP_Z = 1.620, 1.667, 1.718, 1.880
CAPE = dict(top_z=1.565, length=1.40, w_top=0.225, w_bot=0.58, back_y=0.165)
# body texture: front | back planar projection
BX0, BX1, BZ0, BZ1 = -0.64, 0.64, -0.03, 1.73
# palette sampled from the owner's turnaround sheet
TEAL, TEAL_D, TEAL_L, TEAL_LINE = "#56807e", "#41676a", "#6c9a97", "#27444a"
CRIM, CRIM_D, CRIM_L, CRIM_LINE = "#a03a56", "#7e2c44", "#bd5e74", "#4e1626"
GOLD, GOLD_D = "#d8ce8c", "#a89a5c"
CAPE_Y, CAPE_SH = "#e6dc90", "#c7b47a"
INK = "#331915"
GEM_COL = "#ffe37a"

# --- stylised (non-base-mesh) heads: authored around this centre -------------
C0 = (0.0, 0.0, 1.618)
HR = 0.112


def head_deform(x, y, z, hp, grow=1.0):
    x *= hp["wx"] * grow
    y *= hp["wy"] * grow
    z *= hp["wz"] * grow
    if z < 0:
        t = min(1.0, -z / (HR * hp["wz"]))
        x *= 1 - hp["jaw"] * t ** 1.6
        y *= (1 - hp["chin"] * t ** 1.5) if y < 0 else (1 - 0.3 * t)
    return x, y, z


def face_y_base(x, z, hp):
    zl = z - C0[2]
    t = min(1.0, -zl / (HR * hp["wz"])) if zl < 0 else 0.0
    x0 = x / (hp["wx"] * (1 - hp["jaw"] * t ** 1.6))
    z0 = zl / hp["wz"]
    return -math.sqrt(max(0.0, HR * HR - x0 * x0 - z0 * z0)) * hp["wy"] * (1 - hp["chin"] * t ** 1.5)


def head_uv(p):
    """Cylindrical UV for Vision's head and neck: u wraps (front = 0.5), v runs HZ0 -> HZ1."""
    return math.atan2(p[0], -(p[1] - HEAD_Y)) / math.tau + 0.5, (p[2] - HZ0) / (HZ1 - HZ0)


def body_uv(x, z, back):
    return (x - BX0) / (BX1 - BX0) * 0.5 + (0.5 if back else 0.0), (z - BZ0) / (BZ1 - BZ0)


def cape_half_width(v, c=CAPE):
    return c["w_top"] + (c["w_bot"] - c["w_top"]) * v ** 0.9


def cape_uv(u, v, c=CAPE):
    return 0.5 + u * cape_half_width(v, c) / (2.0 * c["w_bot"]), 1.0 - v


def leg_x(z):
    """Centre line of the (slightly splayed) left leg at height z."""
    if z > KNEE[2]:
        t = (HIP[2] - z) / (HIP[2] - KNEE[2])
        return HIP[0] + (KNEE[0] - HIP[0]) * max(0.0, t)
    t = (KNEE[2] - z) / (KNEE[2] - ANKLE[2])
    return KNEE[0] + (ANKLE[0] - KNEE[0]) * min(1.0, t)
