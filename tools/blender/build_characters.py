"""Character maker (Blender, headless). Builds anime-proportioned, rigged,
animated humanoids from a config and exports assets/models/<name>.glb.
All characters share one skeleton and one set of animation clips.

Run: Blender --background --python tools/blender/build_characters.py -- <project_root> <preview_dir> [names...]
"""
import bpy, bmesh, math, os, random, sys
from math import sin, cos, radians, pi, sqrt
from mathutils import Vector, Euler

ARGS = sys.argv[sys.argv.index("--") + 1:]
ROOT, PREV = ARGS[0], ARGS[1]
os.makedirs(PREV, exist_ok=True)
C0 = Vector((0, 0, 1.618))      # head centre the face/hair/tiara code is tuned for
HR = 0.112
NECK = Vector((0, 0, 1.52))
HEAD_SCALE = 1.14               # anime proportions: the finished head is scaled up about the neck

CHARS = {
    "wanda": dict(sex="f", skin="#f6c9ae", eyes="#2fae62", lips="#c04a62", brow="#5a1c0e",
                  zones=dict(torso="#7a1230", trunks="#7a1230", sleeve="#b52a48", forearm="#3d0a1e", hands="#3d0a1e", legs="#b52a48", boots="#3d0a1e"),
                  hair=dict(style="long", a="#8f2e16", b="#b9541e"), head="tiara", headcol="#d81e38",
                  cape=dict(col="#c2152c", collar="low"), belt="#3d0a1e", gems="#ff3048", bust=True, sub=2),
    "vision": dict(sex="m", skin="#c9242c", eyes="#fff0a0", blank_eyes=True, lips="#9c1820", brow="#7a1018",
                   zones=dict(torso="#2e9a50", trunks="#ecc420", sleeve="#2e9a50", forearm="#ecc420", hands="#ecc420", legs="#2e9a50", boots="#ecc420"),
                   hair=dict(style="none"), head="cowl", headcol="#2e9a50",
                   cape=dict(col="#ecc420", collar="high"), belt=None, gems="#ffe060", chest_gem=True, brow_gem=True, sub=2),
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


def sphere(r, loc, scale=(1, 1, 1), m=None, seg=14, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
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


def grid_mesh(name, pts, cols, rows, m, thick=0.0):
    faces = [(r * cols + c, r * cols + c + 1, (r + 1) * cols + c + 1, (r + 1) * cols + c) for r in range(rows - 1) for c in range(cols - 1)]
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in pts], [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    SC.collection.objects.link(ob)
    if thick:
        s = ob.modifiers.new("solid", "SOLIDIFY")
        s.thickness = thick
        s.offset = 0.0
    apply_mods(ob)
    smooth(ob)
    setmat(ob, m)
    return ob


def head_deform(x, y, z, grow=1.0, jaw=0.46):
    x *= 0.9 * grow
    y *= grow
    z *= 1.12 * grow
    if z < 0:
        t = min(1.0, -z / (HR * 1.12))
        x *= 1 - jaw * t ** 1.6
        y *= (1 - 0.2 * t ** 1.5) if y < 0 else (1 - 0.3 * t)
    return x, y, z


def face_y(x, z, jaw=0.46):
    zl = z - C0.z
    t = min(1.0, -zl / (HR * 1.12)) if zl < 0 else 0.0
    x0 = x / (0.9 * (1 - jaw * t ** 1.6))
    z0 = zl / 1.12
    return -sqrt(max(0.0, HR * HR - x0 * x0 - z0 * z0)) * (1 - 0.2 * t ** 1.5)


def skeleton(sex):
    f = sex == "f"
    return dict(
        spine=[(0, 0, 0.95), (0, 0, 1.10), (0, -0.006, 1.26), (0, 0, 1.37), (0, 0, 1.455), (0, 0, 1.52)],
        spine_r=[(0.148, 0.108), (0.09, 0.076), (0.122, 0.097), (0.106, 0.078), (0.042, 0.042), (0.039, 0.039)] if f else
                [(0.128, 0.102), (0.112, 0.088), (0.15, 0.108), (0.14, 0.09), (0.052, 0.052), (0.048, 0.048)],
        arm=[(0.15, 0, 1.385), (0.285, 0.005, 1.165), (0.41, 0, 0.955), (0.458, -0.005, 0.875)] if f else
            [(0.185, 0, 1.39), (0.325, 0.005, 1.17), (0.45, 0, 0.955), (0.5, -0.005, 0.87)],
        arm_r=[(0.048, 0.048), (0.035, 0.035), (0.027, 0.027), (0.033, 0.02)] if f else [(0.062, 0.062), (0.046, 0.046), (0.035, 0.035), (0.04, 0.025)],
        leg=[(0.09, 0, 0.88), (0.095, -0.005, 0.5), (0.1, 0.012, 0.1), (0.1, -0.14, 0.045), (0.098, 0.012, 0.34)],
        leg_r=[(0.096, 0.1), (0.055, 0.058), (0.037, 0.04), (0.043, 0.03), (0.057, 0.062)] if f else [(0.092, 0.098), (0.062, 0.064), (0.044, 0.046), (0.05, 0.034), (0.066, 0.07)],
        chest_x=0.125 if f else 0.155)


# ------------------------------------------------------------------ body
def build_body(cfg, sk):
    V, Rd, E = list(sk["spine"]), list(sk["spine_r"]), [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
    for s in (1, -1):
        b = len(V)
        V += [(s * x, y, z) for x, y, z in sk["arm"]]
        Rd += sk["arm_r"]
        E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3)]
        b = len(V)
        V += [(s * x, y, z) for x, y, z in sk["leg"]]
        Rd += sk["leg_r"]
        E += [(0, b), (b, b + 1), (b + 1, b + 4), (b + 4, b + 2), (b + 2, b + 3)]
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
    names = ["torso", "trunks", "sleeve", "forearm", "hands", "legs", "boots", "skin"] + (["shoes"] if "shoes" in cfg["zones"] else [])
    for k in names:
        ob.data.materials.append(M[k])
    ex, wx = sk["arm"][1][0], sk["arm"][2][0]
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
    extras = []
    if cfg.get("belt"):
        extras += [torus(sk["spine_r"][1][0] + 0.008, 0.013, (0, 0, 1.03), scale=(1, 0.82, 1), m=M["belt"]),
                   sphere(0.02, (0, -sk["spine_r"][1][1] - 0.016, 1.03), (1, 0.5, 1), M["gem"], 10, 6)]
    if "shoes" not in cfg["zones"] and cfg["sex"] == "f":       # cuffs skin badly on the male build
        for s in (1, -1):
            extras.append(torus(0.06, 0.013, (s * 0.095, -0.005, 0.475), m=M["boots"]))
            e0, w0 = Vector(sk["arm"][1]), Vector(sk["arm"][2])
            cp = e0 + (w0 - e0) * 0.4
            ang = math.atan2(w0.x - e0.x, e0.z - w0.z)
            extras.append(torus(sk["arm_r"][1][0] + 0.004, 0.01, (s * cp.x, cp.y, cp.z), rot=(0, -s * ang, 0), m=M["forearm"]))
    if cfg.get("bust"):
        for s in (1, -1):
            extras.append(sphere(0.05, (s * 0.052, -0.058, 1.28), (1.08, 0.72, 0.92), M["torso"], 14, 9))
    if cfg.get("chest_gem"):
        extras.append(cube((0.07, 0.012, 0.07), (0, -0.107, 1.3), (0, radians(45), 0), M["gem"]))
    return join([ob] + extras, "Body")


# ------------------------------------------------------------------ head
def build_head(cfg):
    jaw = 0.46 if cfg["sex"] == "f" else 0.36
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
        parts.append(cube((0.027, 0.006, 0.005), (ex * 1.03, fy(ex, ez + 0.043) - 0.002, ez + 0.043), (0, -s * (0.1 if cfg["sex"] == "f" else -0.1), s * 0.25), M["brow"]))
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


def build_cape(cfg, sk):
    cols, rows = 13, 17
    w0 = sk["arm"][0][0] + 0.035
    pts = []
    for r in range(rows):
        v = r / (rows - 1)
        for cidx in range(cols):
            u = -1 + 2 * cidx / (cols - 1)
            x = u * (w0 + 0.33 * v ** 0.9)
            z = 1.435 - v * 1.27 + abs(u) ** 2 * 0.03 * (1 - v)
            y = 0.09 + 0.055 * v - (u * u) * 0.085 * (1 - v) ** 2.2 + sin(u * 8.5) * 0.016 * v + 0.02 * v * (1 - u * u)
            pts.append(Vector((x, y, z)))
    parts = [grid_mesh("Cape", pts, cols, rows, M["cape"], thick=0.007)]
    hi = cfg["cape"]["collar"] == "high"
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
    setmat(col, M["cape"] if hi else M["headgear"])
    parts.append(col)
    parts.append(sphere(0.014, (0, -r1 + 0.002, 1.425), (1, 0.6, 1), M["gem"], 8, 5))
    return join(parts, "Cape")


def build_scythe(sk):
    hx, hz = -sk["arm"][3][0], sk["arm"][3][2]
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
def bone_list(sk):
    B = [("hips", (0, 0, 0.95), (0, 0, 1.08), None, False), ("spine", (0, 0, 1.08), (0, 0, 1.24), "hips", True),
         ("chest", (0, 0, 1.24), (0, 0, 1.42), "spine", True), ("neck", (0, 0, 1.42), (0, 0, 1.52), "chest", True),
         ("head", (0, 0, 1.52), (0, 0, 1.74), "neck", True),
         ("cape1", (0, 0.085, 1.42), (0, 0.105, 1.02), "chest", False), ("cape2", (0, 0.105, 1.02), (0, 0.125, 0.62), "cape1", True),
         ("cape3", (0, 0.125, 0.62), (0, 0.14, 0.18), "cape2", True)]
    a, l = sk["arm"], sk["leg"]
    for s, sfx in ((1, "L"), (-1, "R")):
        m = lambda p: (s * p[0], p[1], p[2])
        B += [("upper_arm." + sfx, m(a[0]), m(a[1]), "chest", False), ("forearm." + sfx, m(a[1]), m(a[2]), "upper_arm." + sfx, True),
              ("hand." + sfx, m(a[2]), m(a[3]), "forearm." + sfx, True),
              ("thigh." + sfx, m(l[0]), m(l[1]), "hips", False), ("shin." + sfx, m(l[1]), m(l[2]), "thigh." + sfx, True),
              ("foot." + sfx, m(l[2]), (s * l[3][0], l[3][1], 0.03), "shin." + sfx, True)]
    return B


def build_rig(name, bones, body, head_parts, hair, cape, scythe):
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
    for n in ("cape1", "cape2", "cape3"):
        ad.bones[n].use_deform = False
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for n in ("cape1", "cape2", "cape3"):
        ad.bones[n].use_deform = True

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
        def cape_w(c):
            if c.z > 1.40:
                return {"chest": 1.0}
            v = (1.435 - c.z) / 1.27
            ks = [(0.0, "chest"), (0.12, "cape1"), (0.45, "cape2"), (0.8, "cape3")]
            for i in range(len(ks) - 1):
                if v <= ks[i + 1][0]:
                    t = (v - ks[i][0]) / (ks[i + 1][0] - ks[i][0])
                    return {ks[i][1]: 1 - t, ks[i + 1][1]: t}
            return {"cape3": 1.0}
        bind(cape, cape_w)
    if scythe:
        bind(scythe, lambda c: {"hand.R": 1.0})
    return arm


# ------------------------------------------------------------------ animation
def set_pose(arm, names, pose, frame, prev):
    for name in names:
        pb = arm.pose.bones[name]
        rx, ry, rz = pose.get(name, (0, 0, 0))
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


ARM = 25.0


def both(d, key, lv, rv=None):
    d[key + ".L"] = lv
    d[key + ".R"] = rv if rv is not None else (lv[0], -lv[1], -lv[2])
    return d


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
            "cape1": (34 + 4 * s, 0, 0), "cape2": (14 + 5 * s, 0, 0), "cape3": (8 + 6 * s, 0, 0)}


def p_hover(t):
    s, c2 = sin(t * 2 * pi), sin(t * 2 * pi - 1.0)
    return {"thigh.L": (-14 + 2 * s, 0, 0), "shin.L": (30, 0, 0), "thigh.R": (5 - 2 * s, 0, 0), "shin.R": (14, 0, 0), "foot.L": (34, 0, 0), "foot.R": (34, 0, 0),
            "chest": (-4 + s, 0, 0), "head": (3, 0, 0), "upper_arm.L": (-8, -14 + 3 * s, 0), "upper_arm.R": (-8, 14 - 3 * s, 0),
            "forearm.L": (-30 + 4 * c2, 0, 0), "forearm.R": (-30 - 4 * c2, 0, 0),
            "cape1": (14 + 5 * s, 0, 3 * c2), "cape2": (8 + 7 * c2, 0, 4 * s), "cape3": (8 + 9 * sin(t * 2 * pi - 2), 0, 0), "_loc": (0, 0, 0.03 * s)}


def p_fly(t):
    s = sin(t * 2 * pi)
    return {"hips": (58, 0, 0), "spine": (6, 0, 0), "head": (-48, 0, 0), "thigh.L": (12 + 2 * s, 0, 0), "thigh.R": (4 - 2 * s, 0, 0), "shin.L": (6, 0, 0), "shin.R": (14, 0, 0),
            "foot.L": (40, 0, 0), "foot.R": (40, 0, 0), "upper_arm.L": (-150, 8, 0), "upper_arm.R": (20, -10, 0), "forearm.L": (-8, 0, 0), "forearm.R": (-10, 0, 0),
            "cape1": (-40 + 4 * s, 0, 0), "cape2": (-8 + 5 * s, 0, 0), "cape3": (4 + 6 * s, 0, 0)}


def p_dash(t):
    return {"hips": (16, 0, 0), "spine": (9, 0, 0), "chest": (10, 0, 0), "head": (-24, 0, 0),
            "thigh.L": (-42, 0, 0), "shin.L": (48, 0, 0), "thigh.R": (30, 0, 0), "shin.R": (22, 0, 0), "foot.R": (35, 0, 0),
            "upper_arm.L": (58, 8, 0), "upper_arm.R": (58, -8, 0), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0),
            "cape1": (62, 0, 0), "cape2": (14, 0, 0), "cape3": (6 + 5 * sin(t * 12), 0, 0), "_loc": (0, 0, -0.05)}


def p_cast(t):
    k = min(1.0, t / 0.3)
    k = k * k * (3 - 2 * k)
    hold = sin(min(1.0, max(0.0, (t - 0.3) / 0.7)) * pi)
    return {"chest": (-6 * k + 8 * hold, 0, 0), "head": (4 * k, 0, 0), "thigh.L": (-10 * k, 2, 0), "thigh.R": (10 * k, -2, 0), "shin.R": (10 * k, 0, 0),
            "upper_arm.L": (-78 * k - 6 * hold, ARM - 18 * k, 0), "upper_arm.R": (-78 * k - 6 * hold, -ARM + 18 * k, 0),
            "forearm.L": (-24 * k + 14 * hold, 0, 0), "forearm.R": (-24 * k + 14 * hold, 0, 0),
            "cape1": (10 * k + 14 * hold, 0, 0), "cape2": (8 * hold, 0, 0), "cape3": (10 * hold, 0, 0)}


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


CLIPS = [("idle-loop", 60, p_idle), ("walk-loop", 30, lambda t: stride(t, 27, 48, 20, 14, 4, 0.012, 9)),
         ("run-loop", 20, lambda t: stride(t, 46, 92, 42, 78, 20, 0.03, 38)), ("shamble-loop", 40, p_shamble), ("air-loop", 24, p_air),
         ("hover-loop", 50, p_hover), ("fly-loop", 30, p_fly), ("dash", 8, p_dash), ("cast", 22, p_cast), ("charge-loop", 30, p_charge),
         ("attack", 18, p_attack), ("hit", 10, p_hit), ("down", 22, p_down), ("talk-loop", 50, p_talk), ("held-loop", 44, p_held), ("sit", 2, p_sit)]


# ------------------------------------------------------------------ preview
def setup_preview():
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.07, 0.11, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
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
    cam = bpy.data.objects.new("cam", cd)
    SC.collection.objects.link(cam)
    SC.camera = cam
    SC.render.engine = "BLENDER_EEVEE"
    SC.view_settings.view_transform = "Standard"
    SC.render.resolution_x, SC.render.resolution_y = 420, 700
    SC.render.image_settings.file_format = "PNG"
    return cam


def shot(cam, name, ang, dist=4.5, look=0.95, height=1.1):
    a = radians(ang)
    cam.location = (sin(a) * dist, -cos(a) * dist, height)
    cam.rotation_euler = (Vector((0, 0, look)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    SC.render.filepath = os.path.join(PREV, name + ".png")
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ build one
def build(name):
    global SC
    cfg = CHARS[name]
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
    if cfg.get("cape"):
        mat("cape", cfg["cape"]["col"], 0.6)
    sk = skeleton(cfg["sex"])
    body = build_body(cfg, sk)
    head_parts = [build_head(cfg)]
    hair = build_hair(cfg)
    if cfg["head"] == "tiara":
        head_parts.append(build_tiara())
    for ob in head_parts + ([hair] if hair else []):                     # anime head: scale up about the neck
        for v in ob.data.vertices:
            v.co = NECK + (v.co - NECK) * HEAD_SCALE
    cape = build_cape(cfg, sk) if cfg.get("cape") else None
    scythe = build_scythe(sk) if cfg.get("scythe") else None
    bones = bone_list(sk)
    arm = build_rig(name, bones, body, head_parts, hair, cape, scythe)
    names = [b[0] for b in bones]
    acts = {n: make_action(arm, names, n, ln, fn) for n, ln, fn in CLIPS}
    tris = sum(len(p.vertices) - 2 for o in SC.objects if o.type == "MESH" for p in o.data.polygons)
    print("BUILT", name, "tris:", tris)
    if "--no-render" not in ARGS:
        cam = setup_preview()
        arm.animation_data.action = acts["idle-loop"]
        SC.frame_set(1)
        shot(cam, name + "_front", 0)
        shot(cam, name + "_q", 140)
        shot(cam, name + "_face", 14, dist=1.35, look=1.64, height=1.67)
        arm.animation_data.action = acts["cast" if name in ("wanda", "vision") else "attack"]
        SC.frame_set(14 if name in ("wanda", "vision") else 10)
        shot(cam, name + "_act", 50)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for o in list(SC.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    out = os.path.join(ROOT, "assets", "models", name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
                              export_yup=True, export_apply=False, export_skins=True, export_force_sampling=True)
    print("EXPORTED", out)


for nm in ([a for a in ARGS[2:] if not a.startswith("--")] or list(CHARS)):
    build(nm)
