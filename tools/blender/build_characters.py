"""Character maker (Blender, headless). Builds rigged, animated humanoids from a
config and exports assets/models/<name>.glb. All characters share one set of
bone names and animation clips.

Vision is the "heroic, painted" build: proportions and details follow the
owner's turnaround sheet (see vision_spec.py / paint_vision.py).

Run: Blender --background --python tools/blender/build_characters.py -- <project_root> <preview_dir> [names...]
"""
import bpy, bmesh, math, os, random, sys
from math import sin, cos, radians, pi, sqrt
from mathutils import Vector, Euler, kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vision_spec as VS
import basemesh as BM

ARGS = sys.argv[sys.argv.index("--") + 1:]
ROOT, PREV = ARGS[0], ARGS[1]
os.makedirs(PREV, exist_ok=True)
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures")
C0 = Vector(VS.C0)              # head centre the face/hair/tiara code is tuned for
HR = VS.HR
NECK = Vector((0, 0, 1.52))
HEAD_SCALE = 1.14               # anime proportions: the finished head is scaled up about the neck
CAPE_V = [0.06, 0.30, 0.54, 0.78, 1.0]      # cape bone joints, shoulders -> hem
CAPE_COLS = 5

CHARS = {
    "wanda": dict(sex="f", skin="#f6c9ae", eyes="#2fae62", lips="#c04a62", brow="#5a1c0e",
                  zones=dict(torso="#7a1230", trunks="#7a1230", sleeve="#b52a48", forearm="#3d0a1e", hands="#3d0a1e", legs="#b52a48", boots="#3d0a1e"),
                  hair=dict(style="long", a="#8f2e16", b="#b9541e"), head="tiara", headcol="#d81e38",
                  cape=dict(col="#c2152c", collar="low"), belt="#3d0a1e", gems="#ff3048", bust=True, sub=2),
    "vision": dict(sex="m", build="basemesh", painted=True, skin=VS.CRIM, eyes="#fff6f0", blank_eyes=True, lips=VS.CRIM_D, brow=VS.INK,
                   zones={}, hair=dict(style="none"), head="vision", headcol=VS.TEAL,
                   cape=dict(col=VS.CAPE_Y, collar=None, **VS.CAPE), belt=None, gems=VS.GEM_COL, sub=1, arm_down=12.0, leg_in=5.0),
    "black_talon": dict(sex="m", skin="#7a5240", eyes="#f0e8d0", lips="#5a3028", brow="#20100c",
                        zones=dict(torso="#b01c22", trunks="#1c2c7c", sleeve="#1c2c7c", forearm="#e0b020", hands="#e0b020", legs="#1c2c7c", boots="#e0b020"),
                        hair=dict(style="none"), head="crest", headcol="#1c2c7c", cape=dict(col="#141c58", collar="low"), belt="#e0b020", gems="#ff5020", sub=1),
    "nekra": dict(sex="f", skin="#ece8f0", eyes="#d02040", lips="#701028", brow="#1a1020",
                  zones=dict(torso="#241028", trunks="#241028", sleeve="#ece8f0", forearm="#5c1028", hands="#5c1028", legs="#ece8f0", boots="#5c1028"),
                  hair=dict(style="long", a="#1c1226", b="#3a2450"), head="none", cape=dict(col="#5c1028", collar="low"), belt="#5c1028", gems="#d02040", bust=True, sub=1),
    "grim_reaper": dict(sex="m", skin="#e4b494", eyes="#f0e8d0", lips="#8a4a40", brow="#2a1408",
                        zones=dict(torso="#5a2a90", trunks="#2c1450", sleeve="#5a2a90", forearm="#2c1450", hands="#2c1450", legs="#5a2a90", boots="#2c1450"),
                        hair=dict(style="none"), head="horns", headcol="#5a2a90", cape=dict(col="#2a3a9c", collar="high"), belt="#2c1450", gems="#c0c8d8", scythe=True, sub=1),
    "citizen_f": dict(sex="f", skin="#eebb9e", eyes="#6a4a2a", lips="#b05a5a", brow="#3a2414",
                      zones=dict(torso="#5a80b4", trunks="#3a4460", sleeve="#5a80b4", forearm="#eebb9e", hands="#eebb9e", legs="#3a4460", boots="#3a4460", shoes="#2a2028"),
                      hair=dict(style="bob", a="#4a2c18", b="#6a4020"), head="none", cape=None, belt=None, gems="#ffffff", bust=True, sub=1),
    "citizen_m": dict(sex="m", skin="#e4b08e", eyes="#3a4a6a", lips="#9a5a50", brow="#2a1c10",
                      zones=dict(torso="#8a5a3a", trunks="#3c3c48", sleeve="#8a5a3a", forearm="#e4b08e", hands="#e4b08e", legs="#3c3c48", boots="#3c3c48", shoes="#2a2028"),
                      hair=dict(style="short", a="#2a1c10", b="#40281a"), head="none", cape=None, belt=None, gems="#ffffff", sub=1),
}
SC = None
M = {}
ARM = 25.0                      # degrees the arms are lowered from the A-pose in every clip
LEG_IN = 0.0                    # degrees the legs are brought in from a splayed rest stance


# ------------------------------------------------------------------ utilities
def lin(h):
    h = h.lstrip("#")
    return tuple(((int(h[i:i + 2], 16) / 255.0) ** 2.2) for i in (0, 2, 4)) + (1.0,)


def mat(name, hexcol, rough=0.6, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = lin(hexcol)
        b.inputs["Emission Strength"].default_value = emit
    M[name] = m
    return m


def mat_tex(name, filename, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(TEX, filename))
    m.node_tree.links.new(b.inputs["Base Color"], t.outputs["Color"])
    b.inputs["Roughness"].default_value = rough
    M[name] = m
    return m


def active(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def smooth(ob):
    for p in ob.data.polygons:
        p.use_smooth = True


def apply_mods(ob):
    active(ob)
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def setmat(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)


def join(obs, name):
    active(obs[0])
    for o in obs:
        o.select_set(True)
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def sphere(r, loc, scale=(1, 1, 1), m=None, seg=14, rings=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    smooth(ob)
    if m:
        setmat(ob, m)
    return ob


def cube(size, loc, rot=(0, 0, 0), m=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if m:
        setmat(ob, m)
    return ob


def torus(R, r, loc, rot=(0, 0, 0), scale=(1, 1, 1), m=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=20, minor_segments=6, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    smooth(ob)
    if m:
        setmat(ob, m)
    return ob


def grid_mesh(name, pts, cols, rows, m, thick=0.0, wrap=None, offset=0.008):
    faces = [(r * cols + c, r * cols + c + 1, (r + 1) * cols + c + 1, (r + 1) * cols + c) for r in range(rows - 1) for c in range(cols - 1)]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in pts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    SC.collection.objects.link(ob)
    if wrap is not None:                                    # lay the patch on a body surface
        sw = ob.modifiers.new("wrap", "SHRINKWRAP")
        sw.target = wrap
        sw.wrap_method = "NEAREST_SURFACEPOINT"
        sw.wrap_mode = "ABOVE_SURFACE"
        sw.offset = offset
    if thick:
        s = ob.modifiers.new("solid", "SOLIDIFY")
        s.thickness = thick
        s.offset = 0.0
    apply_mods(ob)
    smooth(ob)
    setmat(ob, m)
    return ob


def head_params(cfg):
    centre = NECK + (C0 - NECK) * HEAD_SCALE
    return dict(wx=0.9, wy=1.0, wz=1.12, jaw=0.46 if cfg["sex"] == "f" else 0.36, chin=0.2, scale=HEAD_SCALE, centre=tuple(centre))


STD_HEAD = dict(wx=0.9, wy=1.0, wz=1.12, jaw=0.46, chin=0.2)


def head_deform(x, y, z, grow=1.0, jaw=0.46):
    return VS.head_deform(x, y, z, dict(STD_HEAD, jaw=jaw), grow)


def face_y(x, z, jaw=0.46):
    return VS.face_y_base(x, z, dict(STD_HEAD, jaw=jaw))


def skeleton(cfg):
    f = cfg["sex"] == "f"
    return dict(
        spine=[(0, 0, 0.95), (0, 0, 1.10), (0, -0.006, 1.26), (0, 0, 1.37), (0, 0, 1.455), (0, 0, 1.52)],
        spine_r=[(0.148, 0.108), (0.09, 0.076), (0.122, 0.097), (0.106, 0.078), (0.042, 0.042), (0.039, 0.039)] if f else
                [(0.128, 0.102), (0.112, 0.088), (0.15, 0.108), (0.14, 0.09), (0.052, 0.052), (0.048, 0.048)],
        arm=[(0.15, 0, 1.385), (0.285, 0.005, 1.165), (0.41, 0, 0.955)] if f else [(0.185, 0, 1.39), (0.325, 0.005, 1.17), (0.45, 0, 0.955)],
        arm_r=[(0.048, 0.048), (0.035, 0.035), (0.027, 0.027)] if f else [(0.062, 0.062), (0.046, 0.046), (0.035, 0.035)],
        arm_j=dict(shoulder=0, elbow=1, wrist=2),
        mitten=((0.458, -0.005, 0.875), (0.033, 0.02)) if f else ((0.5, -0.005, 0.87), (0.04, 0.025)),
        leg=[(0.09, 0, 0.88), (0.095, -0.005, 0.5), (0.098, 0.012, 0.34), (0.1, 0.012, 0.1), (0.1, -0.14, 0.045)],
        leg_r=[(0.096, 0.1), (0.055, 0.058), (0.057, 0.062), (0.037, 0.04), (0.043, 0.03)] if f else
              [(0.092, 0.098), (0.062, 0.064), (0.066, 0.07), (0.044, 0.046), (0.05, 0.034)],
        leg_j=dict(hip=0, knee=1, ankle=3, toe=4), chest_x=0.125 if f else 0.155, hand_len=None,
        axis=[0.95, 1.08, 1.24, 1.42, 1.52, 1.74])


def joint(sk, limb, name):
    return Vector(sk[limb][sk[limb + "_j"][name]])


def hand_tip(sk):
    if sk["mitten"]:
        return Vector(sk["mitten"][0])
    w, p = Vector(sk["arm"][-1]), Vector(sk["arm"][-2])
    return w + (w - p).normalized() * sk["hand_len"]


# ------------------------------------------------------------------ body
def add_fingers(V, Rd, E, wrist_index, sk, s):
    """Palm, four fingers and a thumb as skin-modifier branches (relaxed, slightly curled)."""
    w, p = Vector(sk["arm"][-1]), Vector(sk["arm"][-2])
    d = (w - p).normalized()
    f = Vector((0, -1, 0))
    f = (f - d * f.dot(d)).normalized()
    n = d.cross(f)                                            # towards the body

    def add(pt, r, parent):
        V.append((s * pt.x, pt.y, pt.z))
        Rd.append(r if isinstance(r, tuple) else (r, r))
        E.append((parent, len(V) - 1))
        return len(V) - 1

    palm = add(w + d * 0.045, (0.036, 0.019), wrist_index)
    for o, ln in ((0.030, 0.072), (0.010, 0.080), (-0.010, 0.074), (-0.030, 0.058)):
        k = add(w + d * 0.092 + f * o, 0.0125, palm)
        m = add(w + d * (0.092 + ln * 0.5) + f * o + n * 0.004, 0.0105, k)
        add(w + d * (0.092 + ln) + f * o + n * 0.014, 0.0088, m)
    tb = w + d * 0.03 + f * 0.034
    t1 = add(tb, 0.015, palm)
    tm = tb + (d * 0.55 + f * 0.75).normalized() * 0.04
    t2 = add(tm, 0.0125, t1)
    add(tm + (d * 0.85 + f * 0.35 + n * 0.2).normalized() * 0.034, 0.0105, t2)


def build_body(cfg, sk):
    V, Rd, E = list(sk["spine"]), list(sk["spine_r"]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
    for s in (1, -1):
        b = len(V)
        chain = [(s * x, y, z) for x, y, z in sk["arm"]]
        V += chain
        Rd += sk["arm_r"]
        E += [(3, b)] + [(b + i, b + i + 1) for i in range(len(chain) - 1)]
        wrist = b + len(chain) - 1
        if sk["mitten"]:
            tip, r = sk["mitten"]
            V.append((s * tip[0], tip[1], tip[2]))
            Rd.append(r)
            E.append((wrist, len(V) - 1))
        else:
            add_fingers(V, Rd, E, wrist, sk, s)
        b = len(V)
        chain = [(s * x, y, z) for x, y, z in sk["leg"]]
        V += chain
        Rd += sk["leg_r"]
        E += [(0, b)] + [(b + i, b + i + 1) for i in range(len(chain) - 1)]
    me = bpy.data.meshes.new("Body")
    me.from_pydata(V, E, [])
    ob = bpy.data.objects.new("Body", me)
    SC.collection.objects.link(ob)
    skm = ob.modifiers.new("skin", "SKIN")
    skm.use_smooth_shade = True
    skm.branch_smoothing = 0.6
    for i, r in enumerate(Rd):
        me.skin_vertices[0].data[i].radius = r
        me.skin_vertices[0].data[i].use_root = (i == 0)
    ss = ob.modifiers.new("sub", "SUBSURF")
    ss.levels = cfg["sub"]
    apply_mods(ob)
    smooth(ob)
    vol = []
    if cfg.get("painted"):
        ob.data.materials.append(M["bodytex"])
        for s in (1, -1):                                       # pectorals
            vol.append(sphere(0.07, (s * 0.088, -0.092, 1.385), (1.25, 0.6, 0.95), M["bodytex"], 16, 10))
    else:
        names = ["torso", "trunks", "sleeve", "forearm", "hands", "legs", "boots", "skin"] + (["shoes"] if "shoes" in cfg["zones"] else [])
        for k in names:
            ob.data.materials.append(M[k])
        ex, wx = joint(sk, "arm", "elbow").x, joint(sk, "arm", "wrist").x
        boot_top = 0.47 if "shoes" not in cfg["zones"] else -1
        for p in ob.data.polygons:
            c = p.center
            ax = abs(c.x)
            if c.z > 1.445 and ax < 0.1:
                z = "skin"
            elif ax > wx - 0.004 and c.z < 1.2:
                z = "hands"
            elif ax > ex + 0.05 and c.z < 1.3:
                z = "forearm"
            elif ax > sk["chest_x"] + 0.035 and c.z < 1.42:
                z = "sleeve"
            elif "shoes" in cfg["zones"] and c.z < 0.115:
                z = "shoes"
            elif c.z < boot_top:
                z = "boots"
            elif c.z < 0.84:
                z = "legs"
            elif c.z < 1.0:
                z = "trunks"
            else:
                z = "torso"
            p.material_index = names.index(z)
        if cfg.get("bust"):
            for s in (1, -1):
                vol.append(sphere(0.05, (s * 0.052, -0.058, 1.28), (1.08, 0.72, 0.92), M["torso"], 14, 9))
    return join([ob] + vol, "Body") if vol else ob


def strip_on(body, path, widths, m, off=0.008, thick=0.012, across=4):
    """A band that follows a path across the body surface (shrink-wrapped, then given thickness)."""
    pts, ws = [], []
    for i in range(len(path) - 1):
        for k in range(5):
            t = k / 5.0
            pts.append(path[i].lerp(path[i + 1], t))
            ws.append(widths[i] + (widths[i + 1] - widths[i]) * t)
    pts.append(path[-1])
    ws.append(widths[-1])
    for _ in range(2):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    verts = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = Vector((p.x * 0.5, p.y, p.z - 1.42)).normalized()
        lat = t.cross(nrm).normalized()
        for a in range(across):
            verts.append(p + lat * ws[i] * (a / (across - 1) - 0.5))
    return grid_mesh("strip", verts, across, len(pts), m, thick=thick, wrap=body, offset=off)


def build_body_extras(cfg, sk, body):
    """Pieces added on top of the body: list of (object, bone-or-None). None = copy the body's weights."""
    out = []
    el, wr = joint(sk, "arm", "elbow"), joint(sk, "arm", "wrist")
    ang = math.atan2(wr.x - el.x, el.z - wr.z)
    if cfg.get("belt"):
        out.append((torus(sk["spine_r"][1][0] + 0.008, 0.013, (0, 0, 1.03), scale=(1, 0.82, 1), m=M["belt"]), None))
        out.append((sphere(0.02, (0, -sk["spine_r"][1][1] - 0.016, 1.03), (1, 0.5, 1), M["gem"], 10, 6), None))
    if cfg.get("painted"):
        d = (wr - el).normalized()
        for s in (1, -1):
            cp = el + d * 0.05
            out.append((torus(0.061, 0.0115, (s * cp.x, cp.y, cp.z), rot=(0, -s * ang, 0), m=M["bodytex"]), None))     # gauntlet cuff
            out.append((torus(0.073, 0.011, (s * 0.108, 0.012, 0.428), m=M["bodytex"]), None))                       # boot rim
            path = [Vector((s * x, y, z)) for x, y, z in ((0.168, 0.075, 1.568), (0.166, 0.010, 1.592), (0.142, -0.068, 1.560),
                                                          (0.097, -0.112, 1.495), (0.047, -0.128, 1.430), (0.014, -0.128, 1.392))]
            out.append((strip_on(body, path, [0.085, 0.085, 0.07, 0.05, 0.032, 0.014], M["trim"]), "chest"))         # gold yoke band
            out.append((cube((0.115, 0.03, 0.052), (s * 0.158, 0.146, 1.538), (radians(-8), 0, s * radians(-6)), M["trim"]), "chest"))   # tab over the cape
        pts = [Vector(((a - b) * 0.0145, -0.17, 1.352 + (a + b) * 0.024)) for a in (-1, -0.5, 0, 0.5, 1) for b in (-1, -0.5, 0, 0.5, 1)]
        out.append((grid_mesh("diamond", pts, 5, 5, M["trim"], thick=0.008, wrap=body, offset=0.006), "chest"))
    elif "shoes" not in cfg["zones"]:
        for s in (1, -1):
            out.append((torus(0.06, 0.013, (s * 0.095, -0.005, 0.475), m=M["boots"]), None))
            cp = el + (wr - el) * 0.4
            out.append((torus(sk["arm_r"][sk["arm_j"]["elbow"]][0] + 0.004, 0.01, (s * cp.x, cp.y, cp.z), rot=(0, -s * ang, 0), m=M["forearm"]), None))
    return out


# ------------------------------------------------------------------ head
def build_head(cfg, hp):
    jaw = hp["jaw"]
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=HR, location=(0, 0, 0))
    head = bpy.context.active_object
    for v in head.data.vertices:
        v.co = Vector(head_deform(*v.co, jaw=jaw)) + C0
    smooth(head)
    setmat(head, M["skin"])
    parts = [head]
    fy = lambda x, z: face_y(x, z, jaw)
    parts.append(sphere(0.0085, (0, fy(0, 1.588) - 0.004, 1.588), (0.9, 1.2, 1.2), M["skin"], 8, 5))
    for s in (1, -1):
        ex, ez = s * 0.042, 1.626
        ey = fy(ex, ez)
        parts.append(sphere(0.023, (ex, ey + 0.009, ez), (1.05, 0.45, 1.12), M["eye_w"], 14, 9))
        if not cfg.get("blank_eyes"):
            parts.append(sphere(0.0148, (ex * 0.95, ey - 0.0015, ez - 0.002), (1, 0.4, 1.12), M["iris"], 14, 7))
            parts.append(sphere(0.0072, (ex * 0.95, ey - 0.0058, ez - 0.003), (1, 0.4, 1.15), M["pupil"], 10, 6))
            parts.append(sphere(0.0042, (ex * 0.95 + 0.006, ey - 0.0085, ez + 0.007), (1, 0.4, 1), M["eye_w"], 8, 5))
        parts.append(cube((0.03, 0.007, 0.0065), (ex * 1.02, fy(ex, ez + 0.021) - 0.003, ez + 0.021), (0, -s * 0.16, s * 0.25), M["pupil"]))
        parts.append(cube((0.027, 0.006, 0.005), (ex * 1.03, fy(ex, ez + 0.043) - 0.002, ez + 0.043),
                          (0, -s * (0.1 if cfg["sex"] == "f" else -0.1), s * 0.25), M["brow"]))
    parts.append(sphere(0.0085, (0, fy(0, 1.552) + 0.003, 1.552), (1.5, 0.7, 0.55), M["lips"], 10, 6))
    if cfg.get("brow_gem"):
        parts.append(sphere(0.011, (0, fy(0, 1.672) - 0.012, 1.672), (1, 0.6, 1.2), M["gem"], 8, 5))
    return join(parts, "Head")


def lock(parts, pts, r0, r1, m):
    cu = bpy.data.curves.new("lock", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 1
    cu.resolution_u = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        t = i / (len(pts) - 1)
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        sp.points[i].radius = (r0 + (r1 - r0) * t ** 0.8) * min(1.0, 0.25 + 4.0 * t)
    sp.use_endpoint_u = True
    sp.order_u = 4
    ob = bpy.data.objects.new("lock", cu)
    SC.collection.objects.link(ob)
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    mo = bpy.data.objects.new("lockm", me)
    SC.collection.objects.link(mo)
    bpy.data.objects.remove(ob)
    smooth(mo)
    setmat(mo, m)
    parts.append(mo)


def build_hair(cfg):
    style = cfg["hair"]["style"]
    cowl = cfg["head"] in ("cowl", "crest", "horns")
    if style == "none" and not cowl:
        return None
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=HR, location=(0, 0, 0))
    cap = bpy.context.active_object
    for v in cap.data.vertices:
        v.co = Vector(head_deform(*v.co, grow=1.05)) + C0 + Vector((0, 0.006, 0.004))
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    if cowl:
        kill = [f for f in bm.faces if (f.calc_center_median().y < -0.02 and 1.535 < f.calc_center_median().z < 1.668 and abs(f.calc_center_median().x) < 0.082)]
    else:
        lim = 1.682 if cfg["head"] == "tiara" else 1.672
        kill = [f for f in bm.faces if (f.calc_center_median().y < -0.03 and f.calc_center_median().z < lim) or f.calc_center_median().z < 1.5]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(cap.data)
    bm.free()
    smooth(cap)
    setmat(cap, M["headgear"] if cowl else M["hair"])
    parts.append(cap)
    if cfg["head"] == "crest":                                            # rooster comb
        pts = []
        for r in range(2):
            for i in range(13):
                a = radians(-50 + 150 * i / 12)
                rad = HR * 1.17 + r * (0.06 + 0.02 * sin(i * 1.6))
                pts.append(Vector((0, -cos(a) * rad * 0.95 + 0.006, C0.z + sin(a) * rad * 1.1)))
        parts.append(grid_mesh("crest", pts, 13, 2, M["gem"], thick=0.016))
    if cfg["head"] == "horns":
        for s in (1, -1):
            bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.026, radius2=0.0, depth=0.19, location=(s * 0.105, 0.0, C0.z + 0.13), rotation=(0, s * radians(24), 0))
            h = bpy.context.active_object
            smooth(h)
            setmat(h, M["headgear"])
            parts.append(h)
    if cowl or style == "none":
        return join(parts, "Hair")
    rnd = random.Random(7)
    if style == "long":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=1.0, location=(0, 0, 0))
        mass = bpy.context.active_object
        for v in mass.data.vertices:
            t = (1 - v.co.z) / 2
            w = 0.128 + 0.035 * sin(t * pi) - 0.03 * t
            v.co = Vector((v.co.x * w, 0.06 + v.co.y * (0.062 - 0.02 * t) + 0.035 * t, 1.66 - t * 0.52 + 0.012 * sin(v.co.x * 14)))
        smooth(mass)
        setmat(mass, M["hair"])
        parts.append(mass)
    n = 11 if style == "long" else 9
    length0 = dict(long=0.5, bob=0.2, short=0.085)[style]
    for layer in range(2 if style != "short" else 1):
        for i in range(n):
            a = radians(-112 + 224 * i / (n - 1)) + layer * 0.09
            rr = 0.078 + layer * 0.012
            root = Vector((sin(a) * rr * 0.92, cos(a) * rr + 0.012, 1.65 + 0.03 * cos(a) - layer * 0.02))
            length = length0 * rnd.uniform(0.88, 1.15) - abs(sin(a)) * 0.06 * (length0 / 0.5)
            ph = rnd.uniform(0, 6.28)
            pts = []
            for k in range(7):
                t = k / 6
                side = sin(a)
                x = root.x * (1 + 0.75 * t ** 0.6) + sin(t * 5.5 + ph) * 0.014 * t
                y = root.y + (0.035 + 0.03 * cos(a)) * t ** 0.7 + cos(t * 5.0 + ph) * 0.01 * t + abs(side) * 0.03 * t
                z = root.z - length * t ** 1.15 - 0.012 * (1 - t) * abs(side)
                if z < 1.47:
                    y = max(y, 0.085 + 0.02 * layer - abs(x) * 0.25)
                pts.append((x, y, z))
            lock(parts, pts, 0.052 - layer * 0.008, 0.02 if style == "long" else 0.026, M["hair"] if (i + layer) % 3 else M["hair2"])
    front = dict(long=0.36, bob=0.2, short=0.0)[style]
    if front:
        for s in (1, -1):
            for j in range(2):
                pts = []
                for k in range(7):
                    t = k / 6
                    pts.append((s * (0.07 + 0.012 * j + 0.05 * t ** 0.6 + 0.008 * sin(t * 6 + j)),
                                -0.02 + 0.03 * j - 0.055 * t ** 1.4 * (front / 0.36) + 0.01 * sin(t * 5 + j * 2), 1.675 - (front + 0.07 * j) * t ** 1.1))
                lock(parts, pts, 0.034, 0.013, M["hair2"] if j else M["hair"])
    if cfg["head"] == "none":                                             # fringe over the forehead
        for i in range(6):
            x0 = -0.065 + 0.026 * i
            pts = [(x0 * 0.5, -0.03, 1.735), (x0 * 0.8, -0.075, 1.725), (x0, face_y(x0, 1.69) - 0.014, 1.695), (x0 * 1.12 + 0.006, face_y(x0, 1.662) - 0.012, 1.664 + 0.006 * (i % 2))]
            lock(parts, pts, 0.03, 0.012, M["hair2"] if i % 2 else M["hair"])
    return join(parts, "Hair")


def build_tiara():
    cols, rows = 81, 8
    pts = []
    for r in range(rows):
        v = r / (rows - 1)
        for cidx in range(cols):
            th = radians(-104 + 208 * cidx / (cols - 1))
            a = abs(math.degrees(th))
            peak = max(0.0, 1 - abs(a - 40) / 19.0) ** 1.25
            top = 1.692 + 0.125 * peak - (max(0.0, a - 70) / 34.0) * 0.03
            bot = 1.668 - 0.034 * max(0.0, 1 - a / 13.0)
            k = min(1.0, max(0.0, (a - 62) / 24.0))
            bot -= (k * k * (3 - 2 * k)) * 0.1
            z = bot + (top - bot) * v
            z0 = (min(z, 1.72) - C0.z) / 1.12
            kk = sqrt(max(0.3, 1 - (z0 / HR) ** 2))
            tl = min(1.0, -(z - C0.z) / (HR * 1.12)) if z < C0.z else 0.0
            rx = 0.9 * HR * kk * (1 - 0.46 * tl ** 1.6) + 0.011
            ry = HR * kk * (1 - 0.2 * tl ** 1.5) + 0.011
            flare = max(0.0, z - 1.72) * 0.55
            pts.append(Vector((sin(th) * (rx + flare), -cos(th) * (ry + flare * 0.3) + max(0.0, z - 1.72) * 0.3, z)))
    ob = grid_mesh("Crown", pts, cols, rows, M["headgear"], thick=0.009)
    gem = sphere(0.008, (0, face_y(0, 1.676) - 0.014, 1.676), (1, 0.6, 1.3), M["gem"], 8, 5)
    return join([ob, gem], "Crown")


# ------------------------------------------------------------------ cape
def cape_params(cfg, sk):
    c = cfg["cape"]
    w_top = c.get("w_top", joint(sk, "arm", "shoulder").x + 0.035)
    return dict(top_z=c.get("top_z", 1.435), length=c.get("length", 1.27), w_top=w_top, w_bot=c.get("w_bot", w_top + 0.33), back_y=c.get("back_y", 0.09))


def cape_point(cp, u, v):
    hw = cp["w_top"] + (cp["w_bot"] - cp["w_top"]) * v ** 0.9
    return Vector((u * hw, cp["back_y"] + 0.055 * v - (u * u) * 0.085 * (1 - v) ** 2.2 + sin(u * 8.5) * 0.016 * v + 0.02 * v * (1 - u * u),
                   cp["top_z"] - v * cp["length"] + abs(u) ** 2 * 0.03 * (1 - v)))


def cape_uv_of(cp, co):
    """(u, v) on the cape for a vertex position."""
    v = min(1.0, max(0.0, (cp["top_z"] - co.z) / cp["length"]))
    hw = cp["w_top"] + (cp["w_bot"] - cp["w_top"]) * v ** 0.9
    return min(1.0, max(-1.0, co.x / hw)), v


def build_cape(cfg, sk, cp):
    cols, rows = 17, 21
    pts = [cape_point(cp, -1 + 2 * c / (cols - 1), r / (rows - 1)) for r in range(rows) for c in range(cols)]
    parts = [grid_mesh("Cape", pts, cols, rows, M["cape"], thick=0.007)]
    collar = cfg["cape"].get("collar")
    if collar:
        hi = collar == "high"
        r1 = sk["spine_r"][4][0] + 0.03
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r1 + (0.085 if hi else 0.028), depth=0.15 if hi else 0.05, end_fill_type="NOTHING", location=(0, 0.014, 1.495 if hi else 1.45))
        col = bpy.context.active_object
        if hi:
            bm = bmesh.new()
            bm.from_mesh(col.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -0.05], context="FACES")
            bm.to_mesh(col.data)
            bm.free()
        s = col.modifiers.new("s", "SOLIDIFY")
        s.thickness = 0.008
        apply_mods(col)
        smooth(col)
        setmat(col, M["collar"] if hi else M["headgear"])
        parts.append(col)
        parts.append(sphere(0.014, (0, -r1 + 0.002, 1.425), (1, 0.6, 1), M["gem"], 8, 5))
    return join(parts, "Cape") if len(parts) > 1 else parts[0]


def build_scythe(sk):
    tip = hand_tip(sk)
    hx, hz = -tip.x, tip.z
    pts = []
    for r in range(2):
        for i in range(15):
            t = i / 14
            a = radians(200 + 150 * t)
            rad = 0.36 - r * (0.015 + 0.1 * sin(pi * t) ** 0.8)
            pts.append(Vector((hx - 0.16 + cos(a) * rad, -0.03, hz + 0.16 + sin(a) * rad)))
    blade = grid_mesh("Scythe", pts, 15, 2, M["metal"], thick=0.014)
    return join([blade, sphere(0.05, (hx, -0.01, hz - 0.02), (1, 1, 1), M["metal"], 10, 6)], "Scythe")


# ------------------------------------------------------------------ rig
def bone_list(sk, cp):
    ax = sk["axis"]
    B = [("hips", (0, 0, ax[0]), (0, 0, ax[1]), None, False), ("spine", (0, 0, ax[1]), (0, 0, ax[2]), "hips", True),
         ("chest", (0, 0, ax[2]), (0, 0, ax[3]), "spine", True), ("neck", (0, 0, ax[3]), (0, 0, ax[4]), "chest", True),
         ("head", (0, 0, ax[4]), (0, 0, ax[5]), "neck", True)]
    if cp:
        for c in range(CAPE_COLS):
            u = (-1 + 2 * c / (CAPE_COLS - 1)) * 0.96
            for r in range(4):
                B.append(("cape_%d_%d" % (c, r + 1), tuple(cape_point(cp, u, CAPE_V[r])), tuple(cape_point(cp, u, CAPE_V[r + 1])),
                          "chest" if r == 0 else "cape_%d_%d" % (c, r), r > 0))
    tip = hand_tip(sk)
    toe = joint(sk, "leg", "toe")
    for s, sfx in ((1, "L"), (-1, "R")):
        m = lambda p: (s * p[0], p[1], p[2])
        sh, el, wr = joint(sk, "arm", "shoulder"), joint(sk, "arm", "elbow"), joint(sk, "arm", "wrist")
        hp, kn, an = joint(sk, "leg", "hip"), joint(sk, "leg", "knee"), joint(sk, "leg", "ankle")
        B += [("upper_arm." + sfx, m(sh), m(el), "chest", False), ("forearm." + sfx, m(el), m(wr), "upper_arm." + sfx, True),
              ("hand." + sfx, m(wr), m(tip), "forearm." + sfx, True),
              ("thigh." + sfx, m(hp), m(kn), "hips", False), ("shin." + sfx, m(kn), m(an), "thigh." + sfx, True),
              ("foot." + sfx, m(an), (s * toe.x, toe.y, 0.03), "shin." + sfx, True)]
    return B


def copy_weights(src, dst):
    """Give dst the skin weights of the nearest vertex of src (for pieces laid on the body)."""
    kd = kdtree.KDTree(len(src.data.vertices))
    for v in src.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    names = [g.name for g in src.vertex_groups]
    groups = {}
    for v in dst.data.vertices:
        _, idx, _ = kd.find(dst.matrix_world @ v.co)
        for ge in src.data.vertices[idx].groups:
            nm = names[ge.group]
            if nm not in groups:
                groups[nm] = dst.vertex_groups.new(name=nm)
            groups[nm].add([v.index], ge.weight, "REPLACE")


def rigid(ob, bone):
    g = ob.vertex_groups.new(name=bone)
    g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")


def build_rig(name, bones, body, extras, head_parts, hair, cape, cp, scythe):
    ad = bpy.data.armatures.new(name + "_rig")
    arm = bpy.data.objects.new(name, ad)
    SC.collection.objects.link(arm)
    active(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, h, t, par, con in bones:
        b = ad.edit_bones.new(bn)
        b.head, b.tail = h, t
        if par:
            b.parent = ad.edit_bones[par]
            b.use_connect = con
    bpy.ops.object.mode_set(mode="OBJECT")
    cape_bones = [b.name for b in ad.bones if b.name.startswith("cape_")]
    for n in cape_bones:
        ad.bones[n].use_deform = False
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for n in cape_bones:
        ad.bones[n].use_deform = True
    for ob, bone in extras:
        if bone:
            rigid(ob, bone)
        else:
            copy_weights(body, ob)
    if extras:
        body = join([body] + [e[0] for e in extras], "Body")

    def bind(ob, wfn):
        ob.parent = arm
        md = ob.modifiers.new("Armature", "ARMATURE")
        md.object = arm
        groups = {}
        for v in ob.data.vertices:
            for bone, w in wfn(v.co).items():
                if w > 0.001:
                    if bone not in groups:
                        groups[bone] = ob.vertex_groups.new(name=bone)
                    groups[bone].add([v.index], w, "REPLACE")

    for hp in head_parts:
        bind(hp, lambda c: {"head": 1.0})
    if hair:
        def hair_w(c):
            w = min(1.0, max(0.0, (c.z - 1.40) / 0.13))
            return {"head": w, "chest": 1 - w}
        bind(hair, hair_w)
    if cape:
        keys = [(0.0, 0), (0.18, 1), (0.42, 2), (0.66, 3), (0.90, 4)]         # row 0 = chest

        def cape_w(c):
            u, v = cape_uv_of(cp, c)
            if v <= 0.025 or c.y < 0.02:                                       # top edge, collar and clasp ride the chest
                return {"chest": 1.0}
            rows = {4: 1.0}
            for i in range(len(keys) - 1):
                if v <= keys[i + 1][0]:
                    t = (v - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
                    rows = {keys[i][1]: 1 - t, keys[i + 1][1]: t}
                    break
            cu = (u + 1) * 0.5 * (CAPE_COLS - 1)
            c0 = min(CAPE_COLS - 2, int(cu))
            fc = cu - c0
            out = {}
            for r, wr in rows.items():
                if r == 0:
                    out["chest"] = out.get("chest", 0.0) + wr
                else:
                    out["cape_%d_%d" % (c0, r)] = wr * (1 - fc)
                    out["cape_%d_%d" % (c0 + 1, r)] = wr * fc
            return out
        bind(cape, cape_w)
    if scythe:
        bind(scythe, lambda c: {"hand.R": 1.0})
    return arm, body


# ------------------------------------------------------------------ UVs for painted characters
def set_uvs(ob, mat_name, fn):
    """fn(polygon, vertex_co) -> (u, v), applied to faces that use mat_name."""
    me = ob.data
    slot = [i for i, m in enumerate(me.materials) if m and m.name == mat_name]
    if not slot:
        return
    uvl = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        if p.material_index != slot[0]:
            continue
        uvs = [fn(p, me.vertices[me.loops[li].vertex_index].co) for li in p.loop_indices]
        us = [u for u, _ in uvs if u is not None]
        if us and max(us) - min(us) > 0.5:                                      # the face straddles the wrap seam
            uvs = [((u + 1.0) if (u is not None and u < 0.5) else u, v) for u, v in uvs]
            us = [u for u, _ in uvs if u is not None]
        mean = sum(us) / len(us) if us else 0.5
        for li, (u, v) in zip(p.loop_indices, uvs):
            uvl.data[li].uv = (mean if u is None else u, v)
    me.update()


def paint_uvs(body, cape, cp):
    set_uvs(body, "bodytex", lambda p, co: VS.body_uv(co.x, co.z, p.normal.y > 0.0))

    def head_fn(p, co):
        u, v = VS.head_uv((co.x, co.y, co.z))
        return (None if math.hypot(co.x, co.y - VS.HEAD_Y) < 1e-4 else u), v
    set_uvs(body, "headtex", head_fn)
    set_uvs(cape, "cape", lambda p, co: VS.cape_uv(*cape_uv_of(cp, co), cp))


# ------------------------------------------------------------------ hero built on the realistic base mesh
def build_base_hero(cfg):
    """Vision: realistic anatomy (basemesh.py) + suit pieces. Returns (sk, body, extras, head_parts)."""
    import numpy as np
    body, eyes = BM.load(height=VS.HEIGHT)
    BM.heroic(BM.Body(body))
    b = BM.Body(body)
    me = body.data
    me.materials.append(M["bodytex"])
    me.materials.append(M["headtex"])
    me.polygons.foreach_set("material_index", b.faces("head").astype("int32"))
    low = np.array([p.center.z for p in me.polygons]) < VS.BOOT_TOP + 0.012
    boots = BM.shell(b, b.faces("feet") | (b.faces("shin") & low), 0.008, "Boots", voxel=0.008, smooth_iters=3, floor=0.0)
    el = Vector(VS.ELBOW)

    def cuff(co):
        d = (co - Vector((el.x if co.x > 0 else -el.x, el.y, el.z))).length
        return 0.007 + 0.013 * max(0.0, 1 - d / 0.085)
    gaunt = BM.shell(b, b.faces("forearm"), cuff, "Gauntlets")
    for o in (boots, gaunt):
        setmat(o, M["bodytex"])
    extras = [(boots, None), (gaunt, None)]
    for s in (1, -1):
        path = [Vector((s * x, y, z)) for x, y, z in ((0.165, 0.075, 1.555), (0.152, 0.0, 1.575), (0.128, -0.075, 1.548),
                                                      (0.088, -0.13, 1.495), (0.042, -0.155, 1.435), (0.013, -0.16, 1.398))]
        extras.append((strip_on(body, path, [0.05, 0.05, 0.042, 0.032, 0.022, 0.011], M["trim"], off=0.005, thick=0.008), "chest"))
        extras.append((cube((0.12, 0.03, 0.055), (s * 0.16, 0.178, 1.548), (radians(-8), 0, s * radians(-6)), M["trim"]), "chest"))
    pts = [Vector(((a - c) * 0.0145, -0.22, 1.352 + (a + c) * 0.024)) for a in (-1, -0.5, 0, 0.5, 1) for c in (-1, -0.5, 0, 0.5, 1)]
    extras.append((grid_mesh("diamond", pts, 5, 5, M["trim"], thick=0.008, wrap=body, offset=0.006), "chest"))
    bits = []
    for e in eyes:
        setmat(e, M["eye_w"])
        bits.append(e)
    for s in (1, -1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.025, depth=0.011, location=(s * VS.EAR[0], VS.EAR[1], VS.EAR[2]), rotation=(0, radians(90), 0))
        disc = bpy.context.active_object
        smooth(disc)
        setmat(disc, M["trim_teal"])
        bits.append(disc)
        bits.append(cube((0.003, 0.036, 0.005), (s * (VS.EAR[0] + 0.006), VS.EAR[1], VS.EAR[2]), (0, 0, 0), M["line"]))
    bits.append(sphere(0.0105, VS.GEM, (0.85, 0.55, 1.35), M["gem"], 12, 8))
    head_bits = join(bits, "HeadBits")
    active(head_bits)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    sk = dict(axis=VS.AXIS, arm=[VS.SHOULDER, VS.ELBOW, VS.WRIST], arm_j=dict(shoulder=0, elbow=1, wrist=2), mitten=(VS.HAND_TIP, None),
              leg=[VS.HIP, VS.KNEE, VS.ANKLE, VS.TOE], leg_j=dict(hip=0, knee=1, ankle=2, toe=3), spine_r=None)
    return sk, body, extras, [head_bits]


# ------------------------------------------------------------------ animation
# ------------------------------------------------------------------ animation
def set_pose(arm, names, pose, frame, prev):
    for name in names:
        pb = arm.pose.bones[name]
        if name.startswith("cape_"):
            row = int(name[-1])
            rx, ry, rz = pose.get("cape%d" % min(row, 3), (0, 0, 0))
            if row == 4:
                rx, ry, rz = rx * 0.6, ry * 0.6, rz * 0.6
        else:
            rx, ry, rz = pose.get(name, (0, 0, 0))
            if name.startswith("thigh."):
                ry += LEG_IN if name.endswith("L") else -LEG_IN
        m3 = pb.bone.matrix_local.to_3x3()
        q = (m3.inverted() @ Euler((radians(rx), radians(ry), radians(rz)), "XYZ").to_matrix() @ m3).to_quaternion()
        if name in prev and prev[name].dot(q) < 0:
            q.negate()
        prev[name] = q.copy()
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    hp = arm.pose.bones["hips"]
    hp.location = hp.bone.matrix_local.to_3x3().inverted() @ Vector(pose.get("_loc", (0, 0, 0)))
    hp.keyframe_insert("location", frame=frame)


def make_action(arm, names, name, length, fn):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    prev = {}
    for f in range(0, length + 1):
        set_pose(arm, names, fn(f / length), f + 1, prev)
    return act


def p_idle(t):
    s, c2 = sin(t * 2 * pi), sin(t * 2 * pi - 0.9)
    return {"chest": (1.2 * s, 0, 0), "head": (-1.0 * s + 1.5, 0, 2 * c2),
            "upper_arm.L": (2 * c2, ARM + 1.5 * s, 0), "upper_arm.R": (2 * c2, -ARM - 1.5 * s, 0),
            "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0), "thigh.L": (0, 2, 0), "thigh.R": (0, -2, 0),
            "cape1": (3 + 2 * s, 0, 1.5 * c2), "cape2": (2 + 3 * c2, 0, 2 * c2), "cape3": (2 + 4 * sin(t * 2 * pi - 1.8), 0, 0), "_loc": (0, 0, 0.004 * s)}


def stride(t, th, bend, armsw, elbow, lean, bob, cape):
    ph = t * 2 * pi
    out = {}
    for sfx, o, sg in (("L", 0.0, 1), ("R", pi, -1)):
        a = ph + o
        out["thigh." + sfx] = (-th * sin(a) - th * 0.12, sg * 1.5, 0)
        out["shin." + sfx] = (6 + bend * max(0.0, cos(a + 0.55)) ** 2, 0, 0)
        out["foot." + sfx] = (-10 * sin(a) + 6 * max(0.0, cos(a + 0.55)), 0, 0)
        out["upper_arm." + sfx] = (armsw * sin(a), sg * (ARM - 4), 0)
        out["forearm." + sfx] = (-elbow - 8 * max(0.0, -sin(a)), 0, 0)
    out.update({"hips": (lean * 0.45, 0, -4 * sin(ph)), "spine": (lean * 0.3, 0, 4 * sin(ph)), "chest": (lean * 0.45, 0, 4 * sin(ph)),
                "head": (-lean * 0.6, 0, -4 * sin(ph)), "cape1": (cape + 3 * sin(2 * ph), 0, 3 * sin(ph)),
                "cape2": (cape * 0.5 + 5 * sin(2 * ph - 0.9), 0, 4 * sin(ph - 0.6)), "cape3": (cape * 0.35 + 7 * sin(2 * ph - 1.8), 0, 5 * sin(ph - 1.2)),
                "_loc": (0, 0, -bob + bob * cos(2 * ph + 0.4))})
    return out


def p_shamble(t):
    o = stride(t, 15, 26, 4, 10, 14, 0.01, 4)
    s = sin(t * 2 * pi)
    o.update({"upper_arm.L": (-78 + 5 * s, 10, 0), "upper_arm.R": (-62 - 6 * s, -6, 0), "forearm.L": (-14, 0, 0), "forearm.R": (-28, 0, 0),
              "head": (4, 0, 14 + 3 * s), "chest": (12, 0, -5 * s)})
    return o


def p_air(t):
    s = sin(t * 2 * pi)
    return {"thigh.L": (-48 + 3 * s, 0, 0), "shin.L": (72, 0, 0), "thigh.R": (14 - 3 * s, 0, 0), "shin.R": (28, 0, 0),
            "foot.L": (25, 0, 0), "foot.R": (30, 0, 0), "chest": (6, 0, 0), "head": (-6, 0, 0),
            "upper_arm.L": (12, -32 + 4 * s, 0), "upper_arm.R": (12, 32 - 4 * s, 0), "forearm.L": (-25, 0, 0), "forearm.R": (-25, 0, 0),
            "cape1": (24 + 4 * s, 0, 0), "cape2": (10 + 5 * s, 0, 0), "cape3": (6 + 6 * s, 0, 0)}


def p_hover(t):
    s, c2 = sin(t * 2 * pi), sin(t * 2 * pi - 1.0)
    return {"thigh.L": (-14 + 2 * s, 0, 0), "shin.L": (30, 0, 0), "thigh.R": (5 - 2 * s, 0, 0), "shin.R": (14, 0, 0), "foot.L": (34, 0, 0), "foot.R": (34, 0, 0),
            "chest": (-4 + s, 0, 0), "head": (3, 0, 0), "upper_arm.L": (-8, ARM - 34 + 3 * s, 0), "upper_arm.R": (-8, -ARM + 34 - 3 * s, 0),
            "forearm.L": (-30 + 4 * c2, 0, 0), "forearm.R": (-30 - 4 * c2, 0, 0),
            "cape1": (10 + 4 * s, 0, 3 * c2), "cape2": (6 + 6 * c2, 0, 4 * s), "cape3": (6 + 8 * sin(t * 2 * pi - 2), 0, 0), "_loc": (0, 0, 0.03 * s)}


def p_fly(t):
    s = sin(t * 2 * pi)
    return {"hips": (58, 0, 0), "spine": (6, 0, 0), "head": (-48, 0, 0), "thigh.L": (12 + 2 * s, 0, 0), "thigh.R": (4 - 2 * s, 0, 0), "shin.L": (6, 0, 0), "shin.R": (14, 0, 0),
            "foot.L": (40, 0, 0), "foot.R": (40, 0, 0), "upper_arm.L": (-150, 8, 0), "upper_arm.R": (20, -10, 0), "forearm.L": (-8, 0, 0), "forearm.R": (-10, 0, 0),
            "cape1": (-30 + 4 * s, 0, 0), "cape2": (-6 + 5 * s, 0, 0), "cape3": (4 + 6 * s, 0, 0)}


def p_dash(t):
    return {"hips": (16, 0, 0), "spine": (9, 0, 0), "chest": (10, 0, 0), "head": (-24, 0, 0),
            "thigh.L": (-42, 0, 0), "shin.L": (48, 0, 0), "thigh.R": (30, 0, 0), "shin.R": (22, 0, 0), "foot.R": (35, 0, 0),
            "upper_arm.L": (58, 8, 0), "upper_arm.R": (58, -8, 0), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0),
            "cape1": (40, 0, 0), "cape2": (12, 0, 0), "cape3": (6 + 5 * sin(t * 12), 0, 0), "_loc": (0, 0, -0.05)}


def p_cast(t):
    k = min(1.0, t / 0.3)
    k = k * k * (3 - 2 * k)
    hold = sin(min(1.0, max(0.0, (t - 0.3) / 0.7)) * pi)
    return {"chest": (-6 * k + 8 * hold, 0, 0), "head": (4 * k, 0, 0), "thigh.L": (-10 * k, 2, 0), "thigh.R": (10 * k, -2, 0), "shin.R": (10 * k, 0, 0),
            "upper_arm.L": (-78 * k - 6 * hold, ARM - 18 * k, 0), "upper_arm.R": (-78 * k - 6 * hold, -ARM + 18 * k, 0),
            "forearm.L": (-24 * k + 14 * hold, 0, 0), "forearm.R": (-24 * k + 14 * hold, 0, 0),
            "cape1": (10 * k + 14 * hold, 0, 0), "cape2": (8 * hold, 0, 0), "cape3": (10 * hold, 0, 0)}


def p_beam(t):
    """Vision braces and fires from the Mind Stone: chin down, fists clenched at his sides, cape lifting."""
    s = sin(t * 2 * pi)
    return {"chest": (7 + s, 0, 0), "spine": (3, 0, 0), "head": (5, 0, 0), "thigh.L": (-12, 4, 0), "thigh.R": (12, -4, 0), "shin.L": (8, 0, 0), "shin.R": (14, 0, 0),
            "upper_arm.L": (14, ARM + 8, 0), "upper_arm.R": (14, -ARM - 8, 0), "forearm.L": (-46 + 2 * s, 0, 0), "forearm.R": (-46 - 2 * s, 0, 0),
            "cape1": (16 + 5 * s, 0, 0), "cape2": (10 + 7 * sin(t * 2 * pi - 1), 0, 0), "cape3": (10 + 9 * sin(t * 2 * pi - 2), 0, 0)}


def p_charge(t):
    s = sin(t * 2 * pi)
    return {"chest": (-8, 0, 0), "head": (6, 0, 0), "thigh.L": (-8, 3, 0), "thigh.R": (10, -3, 0), "shin.R": (12, 0, 0),
            "upper_arm.L": (-50 + 2 * s, ARM - 5, 0), "upper_arm.R": (-50 - 2 * s, -ARM + 5, 0), "forearm.L": (-72 + 3 * s, 0, 0), "forearm.R": (-72 - 3 * s, 0, 0),
            "cape1": (12 + 6 * s, 0, 0), "cape2": (10 + 8 * sin(t * 2 * pi - 1), 0, 0), "cape3": (10 + 10 * sin(t * 2 * pi - 2), 0, 0)}


def p_attack(t):
    w = min(1.0, t / 0.35)
    st = min(1.0, max(0.0, (t - 0.35) / 0.25))
    rec = min(1.0, max(0.0, (t - 0.6) / 0.4))
    a = 45 * w - 150 * st + 105 * rec
    return {"chest": (-6 * w + 22 * st - 16 * rec, 0, 18 * w - 36 * st + 18 * rec), "hips": (0, 0, -8 * w + 16 * st - 8 * rec),
            "upper_arm.R": (a, -ARM, 0), "forearm.R": (-50 * w + 40 * st + 10 * rec - 12, 0, 0),
            "upper_arm.L": (a * 0.5, ARM, 0), "forearm.L": (-30, 0, 0), "thigh.L": (-22 * st + 22 * rec, 0, 0), "shin.L": (14 * st - 14 * rec, 0, 0),
            "thigh.R": (10 * st - 10 * rec, 0, 0), "cape1": (8 + 10 * st, 0, 0)}


def p_hit(t):
    k = sin(t * pi)
    return {"chest": (-20 * k, 0, 6 * k), "head": (-12 * k, 0, 0), "upper_arm.L": (10 * k, ARM + 20 * k, 0), "upper_arm.R": (10 * k, -ARM - 20 * k, 0),
            "thigh.L": (-6 * k, 0, 0), "thigh.R": (8 * k, 0, 0), "_loc": (0, 0.05 * k, 0)}


def p_down(t):
    k = min(1.0, t / 0.55)
    k = k * k * (3 - 2 * k)
    return {"hips": (-86 * k, 0, 0), "head": (10 * k, 0, 12 * k), "upper_arm.L": (0, ARM + 50 * k, 0), "upper_arm.R": (0, -ARM - 40 * k, 0),
            "thigh.L": (8 * k, 6 * k, 0), "thigh.R": (-4 * k, -8 * k, 0), "shin.R": (20 * k, 0, 0), "_loc": (0, 0.25 * k, -0.84 * k)}


def p_talk(t):
    s, s2 = sin(t * 2 * pi), sin(t * 4 * pi)
    o = p_idle(t)
    o.update({"upper_arm.R": (-28 + 6 * s, -ARM + 6, 0), "forearm.R": (-78 + 16 * s2, 0, 0), "head": (2 + 2 * s2, 0, 5 * s), "chest": (1.5 * s, 0, 3 * s)})
    return o


def p_held(t):
    s, c2 = sin(t * 2 * pi), sin(t * 2 * pi - 1.3)
    return {"chest": (-12 + 2 * s, 0, 0), "head": (-16, 0, 6 * c2), "upper_arm.L": (10 * c2, -40 + 8 * s, 0), "upper_arm.R": (-10 * c2, 40 - 8 * s, 0),
            "forearm.L": (-20, 0, 0), "forearm.R": (-34, 0, 0), "thigh.L": (-10 + 14 * s, 4, 0), "thigh.R": (6 - 14 * s, -4, 0),
            "shin.L": (26 + 10 * c2, 0, 0), "shin.R": (20 - 10 * c2, 0, 0), "foot.L": (30, 0, 0), "foot.R": (30, 0, 0),
            "cape1": (10 + 6 * s, 0, 0), "cape2": (8 + 8 * c2, 0, 0), "_loc": (0, 0, 0.03 * s)}


def p_sit(t):
    return {"thigh.L": (-84, 6, 0), "thigh.R": (-84, -6, 0), "shin.L": (78, 0, 0), "shin.R": (78, 0, 0), "upper_arm.L": (-52, ARM - 12, 0), "upper_arm.R": (-52, -ARM + 12, 0),
            "forearm.L": (-30, 0, 0), "forearm.R": (-30, 0, 0), "chest": (-4, 0, 0), "cape1": (20, 0, 0), "cape2": (30, 0, 0), "cape3": (30, 0, 0), "_loc": (0, 0, -0.42)}


CLIPS = [("idle-loop", 60, p_idle), ("walk-loop", 30, lambda t: stride(t, 27, 48, 20, 14, 4, 0.012, 6)),
         ("run-loop", 20, lambda t: stride(t, 46, 92, 42, 78, 20, 0.03, 22)), ("shamble-loop", 40, p_shamble), ("air-loop", 24, p_air),
         ("hover-loop", 50, p_hover), ("fly-loop", 30, p_fly), ("dash", 8, p_dash), ("cast", 22, p_cast), ("charge-loop", 30, p_charge),
         ("beam-loop", 30, p_beam), ("attack", 18, p_attack), ("hit", 10, p_hit), ("down", 22, p_down), ("talk-loop", 50, p_talk),
         ("held-loop", 44, p_held), ("sit", 2, p_sit), ("apose", 2, lambda t: {})]


# ------------------------------------------------------------------ preview
def setup_preview(ortho):
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.07, 0.11, 1) if not ortho else (0.4, 0.4, 0.44, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6 if not ortho else 0.45
    SC.world = w
    for nm, loc, energy, col in (("key", (-2.5, -3.5, 3.5), 500, (1, 0.95, 0.9)), ("fill", (3, -2, 1.5), 150, (0.8, 0.85, 1)), ("rim", (1.5, 3.5, 3), 400, (1, 0.6, 0.65))):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy, ld.color, ld.size = energy, col, 2.5
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        SC.collection.objects.link(lo)
        lo.rotation_euler = (Vector((0, 0, 0.95)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cd = bpy.data.cameras.new("cam")
    cd.lens = 70
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = 2.25
    cam = bpy.data.objects.new("cam", cd)
    SC.collection.objects.link(cam)
    SC.camera = cam
    SC.render.engine = "BLENDER_EEVEE"
    SC.view_settings.view_transform = "Standard"
    SC.render.resolution_x, SC.render.resolution_y = (420, 700) if not ortho else (560, 760)
    SC.render.image_settings.file_format = "PNG"
    return cam


def shot(cam, name, ang, dist=4.5, look=0.95, height=1.1, ortho_scale=None):
    a = radians(ang)
    cam.location = (sin(a) * dist, -cos(a) * dist, height)
    cam.rotation_euler = (Vector((0, 0, look)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if ortho_scale:
        cam.data.ortho_scale = ortho_scale
    SC.render.filepath = os.path.join(PREV, name + ".png")
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ build one
def build(name):
    global SC, ARM, LEG_IN
    cfg = CHARS[name]
    ARM = cfg.get("arm_down", 25.0)
    LEG_IN = cfg.get("leg_in", 0.0)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SC = bpy.context.scene
    M.clear()
    for z, col in cfg["zones"].items():
        mat(z, col, 0.5, 0.05)
    mat("skin", cfg["skin"], 0.55)
    mat("eye_w", "#f8f0e4" if not cfg.get("blank_eyes") else cfg["eyes"], 0.3, 0.0, 1.2 if cfg.get("blank_eyes") else 0.0)
    mat("iris", cfg["eyes"], 0.25, 0.0, 0.5)
    mat("pupil", "#160a14", 0.3)
    mat("brow", cfg["brow"], 0.6)
    mat("lips", cfg["lips"], 0.4)
    mat("gem", cfg["gems"], 0.2, 0.0, 2.5)
    mat("metal", "#c0c8d8", 0.25, 0.9)
    mat("belt", cfg.get("belt") or "#202020", 0.4, 0.15)
    mat("hair", cfg["hair"].get("a", "#202020"), 0.45)
    mat("hair2", cfg["hair"].get("b", "#303030"), 0.45)
    mat("headgear", cfg.get("headcol", "#808080"), 0.3, 0.3)
    painted = cfg.get("painted", False)
    if painted:
        mat_tex("bodytex", name + "_body.png")
        mat_tex("headtex", name + "_head.png", 0.5)
        mat_tex("cape", name + "_cape.png", 0.65)
        mat("trim", VS.GOLD, 0.45, 0.2)
        mat("trim_teal", VS.TEAL, 0.5)
        mat("line", VS.TEAL_LINE, 0.6)
    elif cfg.get("cape"):
        mat("cape", cfg["cape"]["col"], 0.6)
        mat("collar", cfg["cape"]["col"], 0.6)
    base = cfg.get("build") == "basemesh"
    if base:
        sk, body, extras, head_parts = build_base_hero(cfg)
        hair = None
    else:
        sk = skeleton(cfg)
        hp = head_params(cfg)
        body = build_body(cfg, sk)
        extras = build_body_extras(cfg, sk, body)
        head_parts = [build_head(cfg, hp)]
        hair = build_hair(cfg)
        if cfg["head"] == "tiara":
            head_parts.append(build_tiara())
        centre = Vector(hp["centre"])
        for ob in head_parts + ([hair] if hair else []):                 # move the finished head onto this body
            for v in ob.data.vertices:
                v.co = centre + (v.co - C0) * hp["scale"]
    cp = cape_params(cfg, sk) if cfg.get("cape") else None
    cape = build_cape(cfg, sk, cp) if cp else None
    scythe = build_scythe(sk) if cfg.get("scythe") else None
    bones = bone_list(sk, cp)
    arm, body = build_rig(name, bones, body, extras, head_parts, hair, cape, cp, scythe)
    if painted:
        paint_uvs(body, cape, cp)
    if base:
        BM.cavity_colors(BM.Body(body))
    names = [b[0] for b in bones]
    acts = {n: make_action(arm, names, n, ln, fn) for n, ln, fn in CLIPS}
    tris = sum(len(p.vertices) - 2 for o in SC.objects if o.type == "MESH" for p in o.data.polygons)
    print("BUILT", name, "tris:", tris, "bones:", len(bones))
    if "--no-render" not in ARGS:
        cam = setup_preview(painted)
        if painted:                                                       # turnaround in the A-pose, like the reference sheet
            arm.animation_data.action = acts["apose"]
            SC.frame_set(1)
            for nm, ang in (("front", 0), ("side", 90), ("back", 180)):
                shot(cam, name + "_" + nm, ang, dist=6.0, look=0.95, height=0.95)
            shot(cam, name + "_face", 0, dist=6.0, look=1.72, height=1.72, ortho_scale=0.46)
            shot(cam, name + "_faceq", 55, dist=6.0, look=1.72, height=1.72, ortho_scale=0.46)
            arm.animation_data.action = acts["fly-loop"]
            SC.frame_set(8)
            shot(cam, name + "_act", 60, dist=6.0, look=0.95, height=0.95, ortho_scale=2.6)
            shot(cam, name + "_q", 140, dist=6.0, look=0.95, height=1.6, ortho_scale=2.6)
        else:
            arm.animation_data.action = acts["idle-loop"]
            SC.frame_set(1)
            shot(cam, name + "_front", 0)
            shot(cam, name + "_q", 140)
            shot(cam, name + "_face", 14, dist=1.35, look=1.64, height=1.67)
            arm.animation_data.action = acts["cast" if name == "wanda" else "attack"]
            SC.frame_set(14 if name == "wanda" else 10)
            shot(cam, name + "_act", 50)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for o in list(SC.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    out = os.path.join(ROOT, "assets", "models", name + ".glb")
    kw = dict(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
              export_yup=True, export_apply=False, export_skins=True, export_force_sampling=True)
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE" if cfg.get("build") == "basemesh" else "NONE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("EXPORTED", out)


for nm in ([a for a in ARGS[2:] if not a.startswith("--")] or list(CHARS)):
    build(nm)
