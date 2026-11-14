"""Builds Wanda in Blender (headless): stylised body, face, long auburn hair,
two-pointed crimson headpiece, bodysuit, gloves, boots, cape; rigs her, authors
the animation clips and exports assets/models/wanda.glb (+ preview renders).

Run:  Blender --background --python tools/blender/build_wanda.py -- <project_root> [preview_dir]
"""
import bpy, math, os, random, sys
from math import sin, cos, radians, pi, sqrt
from mathutils import Vector, Euler

ARGS = sys.argv[sys.argv.index("--") + 1:]
ROOT = ARGS[0]
PREV = ARGS[1] if len(ARGS) > 1 else os.path.join(ROOT, "documentation", "wanda_preview")
os.makedirs(PREV, exist_ok=True)
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
HEAD_C = Vector((0, 0, 1.618))
HR = 0.112


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
    return m


M = dict(
    skin=mat("skin", "#eebb9e", 0.55), suit=mat("suit", "#6e0f2a", 0.45, 0.1), dark=mat("dark", "#33081a", 0.4, 0.15),
    cape=mat("cape", "#b01028", 0.6), crown=mat("crown", "#cc1830", 0.3, 0.35), hair=mat("hair", "#7e2a14", 0.45),
    hair2=mat("hair2", "#a03e18", 0.45), eye_w=mat("eye_white", "#f4ead8", 0.3), iris=mat("iris", "#2f9a55", 0.25, 0.0, 0.6),
    pupil=mat("pupil", "#160a14", 0.3), brow=mat("brow", "#4a160c", 0.6), lips=mat("lips", "#b8405a", 0.4),
    gem=mat("gem", "#ff3048", 0.2, 0.0, 2.5),
)


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


def sphere(name, r, loc, scale=(1, 1, 1), m=None, seg=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    smooth(ob)
    if m:
        setmat(ob, m)
    return ob


def torus(name, R, r, loc, rot=(0, 0, 0), scale=(1, 1, 1), m=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=24, minor_segments=8, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    smooth(ob)
    if m:
        setmat(ob, m)
    return ob


def grid_mesh(name, pts, cols, rows, m, thick=0.0, sub=0):
    """pts: row-major list of Vector, (rows x cols)."""
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
    if sub:
        ss = ob.modifiers.new("sub", "SUBSURF")
        ss.levels = sub
    apply_mods(ob)
    smooth(ob)
    setmat(ob, m)
    return ob


def head_deform(x, y, z, r=HR, grow=1.0):
    """Maps a point of a sphere of radius r (local coords) onto the head shape."""
    x *= 0.9 * grow
    y *= grow
    z *= 1.12 * grow
    if z < 0:
        t = min(1.0, -z / (r * 1.12))
        x *= 1 - 0.46 * t ** 1.6
        y *= (1 - 0.2 * t ** 1.5) if y < 0 else (1 - 0.3 * t)
    return x, y, z


def face_y(x, z):
    """y of the face surface (front) at world x, z - used to place features."""
    zl = z - HEAD_C.z
    t = min(1.0, -zl / (HR * 1.12)) if zl < 0 else 0.0
    x0 = x / (0.9 * (1 - 0.46 * t ** 1.6))
    z0 = zl / 1.12
    y0 = -sqrt(max(0.0, HR * HR - x0 * x0 - z0 * z0))
    return y0 * (1 - 0.2 * t ** 1.5)


# ------------------------------------------------------------------ body
def build_body():
    V = [(0, 0, 0.95), (0, 0, 1.10), (0, -0.006, 1.26), (0, 0, 1.37), (0, 0, 1.455), (0, 0, 1.52)]
    Rd = [(0.15, 0.108), (0.092, 0.078), (0.124, 0.098), (0.108, 0.078), (0.043, 0.043), (0.04, 0.04)]
    E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]
    for s in (1, -1):
        b = len(V)
        V += [(s * 0.15, 0, 1.385), (s * 0.285, 0.005, 1.165), (s * 0.41, 0, 0.955), (s * 0.458, -0.005, 0.875)]
        Rd += [(0.05, 0.05), (0.036, 0.036), (0.028, 0.028), (0.034, 0.02)]
        E += [(3, b), (b, b + 1), (b + 1, b + 2), (b + 2, b + 3)]
        b = len(V)
        V += [(s * 0.09, 0, 0.88), (s * 0.095, -0.005, 0.5), (s * 0.1, 0.012, 0.1), (s * 0.1, -0.14, 0.045), (s * 0.098, 0.012, 0.34)]
        Rd += [(0.098, 0.1), (0.056, 0.058), (0.038, 0.04), (0.044, 0.03), (0.058, 0.062)]
        E += [(0, b), (b, b + 1), (b + 1, b + 4), (b + 4, b + 2), (b + 2, b + 3)]
    me = bpy.data.meshes.new("Body")
    me.from_pydata(V, E, [])
    ob = bpy.data.objects.new("Body", me)
    SC.collection.objects.link(ob)
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    for i, r in enumerate(Rd):
        me.skin_vertices[0].data[i].radius = r
        me.skin_vertices[0].data[i].use_root = (i == 0)
    ss = ob.modifiers.new("sub", "SUBSURF")
    ss.levels = 2
    apply_mods(ob)
    smooth(ob)
    for k in ("suit", "dark", "skin"):
        ob.data.materials.append(M[k])
    for p in ob.data.polygons:
        c = p.center
        if c.z > 1.445:
            p.material_index = 2
        elif c.z < 0.47 or abs(c.x) > 0.335:
            p.material_index = 1
    extras = [torus("belt", 0.097, 0.013, (0, 0, 1.03), scale=(1, 0.82, 1), m=M["dark"]),
              sphere("buckle", 0.02, (0, -0.092, 1.03), (1, 0.5, 1), M["gem"], 10, 6)]
    for s in (1, -1):
        extras.append(torus("bootcuff", 0.06, 0.013, (s * 0.095, -0.005, 0.475), m=M["dark"]))
        extras.append(torus("glovecuff", 0.037, 0.01, (s * 0.335, 0.003, 1.082), rot=(0, -s * radians(30.8), 0), m=M["dark"]))
        extras.append(sphere("bust", 0.05, (s * 0.052, -0.058, 1.28), (1.08, 0.72, 0.92), M["suit"], 14, 9))
    return join([ob] + extras, "Body")


# ------------------------------------------------------------------ head
def build_head():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=HR, location=(0, 0, 0))
    head = bpy.context.active_object
    for v in head.data.vertices:
        v.co = Vector(head_deform(*v.co)) + HEAD_C
    smooth(head)
    setmat(head, M["skin"])
    parts = [head]
    parts.append(sphere("nose", 0.013, (0, face_y(0, 1.592) - 0.006, 1.592), (0.85, 1.2, 1.3), M["skin"], 10, 6))
    for s in (1, -1):
        ex, ez = s * 0.04, 1.63
        ey = face_y(ex, ez)
        parts.append(sphere("eye", 0.0175, (ex, ey + 0.006, ez), (1.25, 0.5, 0.82), M["eye_w"], 12, 8))
        parts.append(sphere("iris", 0.0098, (ex * 0.97, ey - 0.0015, ez - 0.001), (1, 0.4, 1), M["iris"], 12, 6))
        parts.append(sphere("pupil", 0.0048, (ex * 0.97, ey - 0.0048, ez - 0.001), (1, 0.4, 1), M["pupil"], 8, 5))
        for nm, w, zz, tilt, mm in (("lash", 0.023, ez + 0.0125, 0.12, M["pupil"]), ("brow", 0.024, ez + 0.031, -0.1, M["brow"])):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(ex * 1.02, face_y(ex, zz) - 0.002, zz), rotation=(0, -s * tilt, s * 0.25))
            o = bpy.context.active_object
            o.scale = (w, 0.006, 0.0038 if nm == "lash" else 0.0055)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            setmat(o, mm)
            parts.append(o)
    parts.append(sphere("lips", 0.01, (0, face_y(0, 1.556) + 0.002, 1.556), (2.0, 0.7, 0.72), M["lips"], 12, 6))
    return join(parts, "Head")


def build_hair():
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=HR, location=(0, 0, 0))
    cap = bpy.context.active_object
    for v in cap.data.vertices:
        v.co = Vector(head_deform(*v.co, grow=1.05)) + HEAD_C + Vector((0, 0.006, 0.004))
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    kill = [f for f in bm.faces if (f.calc_center_median().y < -0.03 and f.calc_center_median().z < 1.682) or f.calc_center_median().z < 1.5]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(cap.data)
    bm.free()
    smooth(cap)
    setmat(cap, M["hair"])
    parts.append(cap)

    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=14, radius=1.0, location=(0, 0, 0))
    mass = bpy.context.active_object
    for v in mass.data.vertices:
        t = (1 - v.co.z) / 2                                             # 0 top .. 1 bottom
        w = 0.128 + 0.035 * sin(t * pi) - 0.03 * t
        v.co = Vector((v.co.x * w, 0.06 + v.co.y * (0.062 - 0.02 * t) + 0.035 * t, 1.66 - t * 0.52 + 0.012 * sin(v.co.x * 14)))
    smooth(mass)
    setmat(mass, M["hair"])
    parts.append(mass)

    def lock(pts, r0, r1, m):
        cu = bpy.data.curves.new("lock", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = 1.0
        cu.bevel_resolution = 2
        cu.resolution_u = 5
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
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        mo = bpy.data.objects.new("lockm", me)
        SC.collection.objects.link(mo)
        bpy.data.objects.remove(ob)
        smooth(mo)
        setmat(mo, m)
        parts.append(mo)

    n = 11
    for layer in range(2):
        for i in range(n):
            a = radians(-112 + 224 * i / (n - 1)) + layer * 0.09          # 0 = straight back
            rr = 0.078 + layer * 0.012
            root = Vector((sin(a) * rr * 0.92, cos(a) * rr + 0.012, 1.65 + 0.03 * cos(a) - layer * 0.02))
            length = random.uniform(0.44, 0.58) - abs(sin(a)) * 0.06
            ph = random.uniform(0, 6.28)
            pts = []
            for k in range(7):
                t = k / 6
                side = sin(a)
                x = root.x * (1 + 0.75 * t ** 0.6) + sin(t * 5.5 + ph) * 0.014 * t
                y = root.y + (0.035 + 0.03 * cos(a)) * t ** 0.7 + cos(t * 5.0 + ph) * 0.01 * t + abs(side) * 0.03 * t
                z = root.z - length * t ** 1.15 - 0.012 * (1 - t) * abs(side)
                if z < 1.47:                                              # keep clear of the shoulders / back
                    y = max(y, 0.085 + 0.02 * layer - abs(x) * 0.25)
                    x = x * 1.0 if abs(x) < 0.17 else x
                pts.append((x, y, z))
            lock(pts, 0.052 - layer * 0.008, 0.02, M["hair"] if (i + layer) % 3 else M["hair2"])
    for s in (1, -1):                                                     # locks framing the face, over the shoulders
        for j in range(2):
            pts = []
            for k in range(7):
                t = k / 6
                x = s * (0.07 + 0.012 * j + 0.05 * t ** 0.6 + 0.008 * sin(t * 6 + j))
                y = -0.02 + 0.03 * j - 0.055 * t ** 1.4 + 0.01 * sin(t * 5 + j * 2)
                z = 1.675 - (0.33 + 0.07 * j) * t ** 1.1
                pts.append((x, y, z))
            lock(pts, 0.034, 0.013, M["hair2"] if j else M["hair"])
    return join(parts, "Hair")


def build_crown():
    cols, rows = 97, 9
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
            z0 = (min(z, 1.72) - HEAD_C.z) / 1.12
            kk = sqrt(max(0.3, 1 - (z0 / HR) ** 2))
            tl = min(1.0, -(z - HEAD_C.z) / (HR * 1.12)) if z < HEAD_C.z else 0.0
            rx = 0.9 * HR * kk * (1 - 0.46 * tl ** 1.6) + 0.011
            ry = HR * kk * (1 - 0.2 * tl ** 1.5) + 0.011
            flare = max(0.0, z - 1.72) * 0.55
            pts.append(Vector((sin(th) * (rx + flare), -cos(th) * (ry + flare * 0.3) + max(0.0, z - 1.72) * 0.3, z)))
    ob = grid_mesh("Crown", pts, cols, rows, M["crown"], thick=0.009)
    gem = sphere("crown_gem", 0.008, (0, face_y(0, 1.676) - 0.014, 1.676), (1, 0.6, 1.3), M["gem"], 10, 6)
    return join([ob, gem], "Crown")


def build_cape():
    cols, rows = 15, 19
    pts = []
    for r in range(rows):
        v = r / (rows - 1)
        for cidx in range(cols):
            u = -1 + 2 * cidx / (cols - 1)
            x = u * (0.185 + 0.33 * v ** 0.9)
            z = 1.435 - v * 1.27 - (1 - abs(u)) * 0.0 + abs(u) ** 2 * 0.03 * (1 - v)
            y = 0.085 + 0.055 * v - (u * u) * 0.085 * (1 - v) ** 2.2 + sin(u * 8.5) * 0.016 * v + 0.02 * v * (1 - u * u)
            pts.append(Vector((x, y, z)))
    cape = grid_mesh("Cape", pts, cols, rows, M["cape"], thick=0.007)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.066, radius2=0.092, depth=0.05, end_fill_type="NOTHING", location=(0, 0.014, 1.45))
    col = bpy.context.active_object
    s = col.modifiers.new("s", "SOLIDIFY")
    s.thickness = 0.008
    apply_mods(col)
    smooth(col)
    setmat(col, M["crown"])
    clasp = sphere("clasp", 0.014, (0, -0.07, 1.425), (1, 0.6, 1), M["gem"], 10, 6)
    return join([cape, col, clasp], "Cape")


# ------------------------------------------------------------------ rig
BONES = [  # name, head, tail, parent, connected
    ("hips", (0, 0, 0.95), (0, 0, 1.08), None, False), ("spine", (0, 0, 1.08), (0, 0, 1.24), "hips", True),
    ("chest", (0, 0, 1.24), (0, 0, 1.42), "spine", True), ("neck", (0, 0, 1.42), (0, 0, 1.52), "chest", True),
    ("head", (0, 0, 1.52), (0, 0, 1.74), "neck", True),
    ("cape1", (0, 0.085, 1.42), (0, 0.105, 1.02), "chest", False), ("cape2", (0, 0.105, 1.02), (0, 0.125, 0.62), "cape1", True),
    ("cape3", (0, 0.125, 0.62), (0, 0.14, 0.18), "cape2", True),
]
for s, sfx in ((1, "L"), (-1, "R")):
    BONES += [
        ("upper_arm." + sfx, (s * 0.15, 0, 1.385), (s * 0.285, 0.005, 1.165), "chest", False),
        ("forearm." + sfx, (s * 0.285, 0.005, 1.165), (s * 0.41, 0, 0.955), "upper_arm." + sfx, True),
        ("hand." + sfx, (s * 0.41, 0, 0.955), (s * 0.46, -0.005, 0.87), "forearm." + sfx, True),
        ("thigh." + sfx, (s * 0.085, 0, 0.9), (s * 0.095, -0.005, 0.5), "hips", False),
        ("shin." + sfx, (s * 0.095, -0.005, 0.5), (s * 0.1, 0.012, 0.1), "thigh." + sfx, True),
        ("foot." + sfx, (s * 0.1, 0.012, 0.1), (s * 0.1, -0.14, 0.03), "shin." + sfx, True),
    ]


def build_rig(body, head, hair, crown, cape):
    ad = bpy.data.armatures.new("WandaRig")
    arm = bpy.data.objects.new("Wanda", ad)
    SC.collection.objects.link(arm)
    active(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, par, con in BONES:
        b = ad.edit_bones.new(name)
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

    bind(head, lambda c: {"head": 1.0})
    bind(crown, lambda c: {"head": 1.0})

    def hair_w(c):
        w = min(1.0, max(0.0, (c.z - 1.40) / 0.13))
        return {"head": w, "chest": 1 - w}
    bind(hair, hair_w)

    def cape_w(c):
        v = (1.435 - c.z) / 1.27
        if c.z > 1.40:
            return {"chest": 1.0}
        ks = [(0.0, "chest"), (0.12, "cape1"), (0.45, "cape2"), (0.8, "cape3")]
        for i in range(len(ks) - 1):
            if v <= ks[i + 1][0]:
                t = (v - ks[i][0]) / (ks[i + 1][0] - ks[i][0])
                return {ks[i][1]: 1 - t, ks[i + 1][1]: t}
        return {"cape3": 1.0}
    bind(cape, cape_w)
    return arm


# ------------------------------------------------------------------ animation
ANIM_BONES = [b[0] for b in BONES]


def set_pose(arm, pose, frame, prev):
    for name in ANIM_BONES:
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


def make_action(arm, name, length, fn):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    prev = {}
    for f in range(0, length + 1):
        set_pose(arm, fn(f / length), f + 1, prev)
    return act


ARM = 25.0   # arms lowered from the A-pose


def p_idle(t):
    s, c2 = sin(t * 2 * pi), sin(t * 2 * pi - 0.9)
    return {"chest": (1.2 * s, 0, 0), "head": (-1.0 * s + 1.5, 0, 2 * c2),
            "upper_arm.L": (2 * c2, ARM + 1.5 * s, 0), "upper_arm.R": (2 * c2, -ARM - 1.5 * s, 0),
            "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0), "thigh.L": (0, 2, 0), "thigh.R": (0, -2, 0),
            "cape1": (3 + 2 * s, 0, 1.5 * c2), "cape2": (2 + 3 * c2, 0, 2 * c2), "cape3": (2 + 4 * sin(t * 2 * pi - 1.8), 0, 0),
            "_loc": (0, 0, 0.004 * s)}


def _stride(t, th, bend, armsw, elbow, lean, bob, cape):
    ph = t * 2 * pi
    out = {}
    for sfx, o, sg in (("L", 0.0, 1), ("R", pi, -1)):
        a = ph + o
        out["thigh." + sfx] = (-th * sin(a) - th * 0.12, sg * 1.5, 0)
        out["shin." + sfx] = (6 + bend * max(0.0, cos(a + 0.55)) ** 2, 0, 0)
        out["foot." + sfx] = (-10 * sin(a) + 6 * max(0.0, cos(a + 0.55)), 0, 0)
        out["upper_arm." + sfx] = (armsw * sin(a), sg * (ARM - 4), 0)
        out["forearm." + sfx] = (-elbow - 8 * max(0.0, -sin(a)), 0, 0)
    out["hips"] = (lean * 0.45, 0, -4 * sin(ph))
    out["spine"] = (lean * 0.3, 0, 4 * sin(ph))
    out["chest"] = (lean * 0.45, 0, 4 * sin(ph))
    out["head"] = (-lean * 0.6, 0, -4 * sin(ph))
    out["cape1"] = (cape + 3 * sin(2 * ph), 0, 3 * sin(ph))
    out["cape2"] = (cape * 0.5 + 5 * sin(2 * ph - 0.9), 0, 4 * sin(ph - 0.6))
    out["cape3"] = (cape * 0.35 + 7 * sin(2 * ph - 1.8), 0, 5 * sin(ph - 1.2))
    out["_loc"] = (0, 0, -bob + bob * cos(2 * ph + 0.4))
    return out


def p_walk(t):
    return _stride(t, 27, 48, 20, 14, 4, 0.012, 9)


def p_run(t):
    return _stride(t, 46, 92, 42, 78, 20, 0.03, 38)


def p_air(t):
    s = sin(t * 2 * pi)
    return {"thigh.L": (-48 + 3 * s, 0, 0), "shin.L": (72, 0, 0), "thigh.R": (14 - 3 * s, 0, 0), "shin.R": (28, 0, 0),
            "foot.L": (25, 0, 0), "foot.R": (30, 0, 0), "chest": (6, 0, 0), "head": (-6, 0, 0),
            "upper_arm.L": (12, -32 + 4 * s, 0), "upper_arm.R": (12, 32 - 4 * s, 0), "forearm.L": (-25, 0, 0), "forearm.R": (-25, 0, 0),
            "cape1": (34 + 4 * s, 0, 0), "cape2": (14 + 5 * s, 0, 0), "cape3": (8 + 6 * s, 0, 0)}


def p_dash(t):
    return {"hips": (16, 0, 0), "spine": (9, 0, 0), "chest": (10, 0, 0), "head": (-24, 0, 0),
            "thigh.L": (-42, 0, 0), "shin.L": (48, 0, 0), "thigh.R": (30, 0, 0), "shin.R": (22, 0, 0), "foot.R": (35, 0, 0),
            "upper_arm.L": (58, 8, 0), "upper_arm.R": (58, -8, 0), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0),
            "cape1": (62, 0, 0), "cape2": (14, 0, 0), "cape3": (6 + 5 * sin(t * 12), 0, 0), "_loc": (0, 0, -0.05)}


def p_cast(t):
    k = min(1.0, t / 0.35)
    k = k * k * (3 - 2 * k)
    hold = sin(min(1.0, max(0.0, (t - 0.35) / 0.65)) * pi)
    return {"chest": (-6 * k + 8 * hold, 0, 0), "head": (4 * k, 0, 0), "thigh.L": (-10 * k, 2, 0), "thigh.R": (10 * k, -2, 0), "shin.R": (10 * k, 0, 0),
            "upper_arm.L": (-78 * k - 6 * hold, ARM - 18 * k, 0), "upper_arm.R": (-78 * k - 6 * hold, -ARM + 18 * k, 0),
            "forearm.L": (-24 * k + 14 * hold, 0, 0), "forearm.R": (-24 * k + 14 * hold, 0, 0),
            "cape1": (10 * k + 14 * hold, 0, 0), "cape2": (8 * hold, 0, 0), "cape3": (10 * hold, 0, 0)}


# ------------------------------------------------------------------ preview
def setup_preview():
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.09, 0.07, 0.11, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    SC.world = w
    for name, loc, energy, col in (("key", (-2.5, -3.5, 3.5), 500, (1, 0.95, 0.9)), ("fill", (3, -2, 1.5), 150, (0.8, 0.85, 1)), ("rim", (1.5, 3.5, 3), 400, (1, 0.6, 0.65))):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.color = col
        ld.size = 2.5
        lo = bpy.data.objects.new(name, ld)
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
    SC.render.resolution_x, SC.render.resolution_y = 520, 860
    SC.render.image_settings.file_format = "PNG"
    return cam


def shot(cam, name, ang, dist=4.3, look=0.9, height=1.05):
    a = radians(ang)
    cam.location = (sin(a) * dist, -cos(a) * dist, height)
    cam.rotation_euler = (Vector((0, 0, look)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    SC.render.filepath = os.path.join(PREV, name + ".png")
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ main
body, head, hair, crown, cape = build_body(), build_head(), build_hair(), build_crown(), build_cape()
arm = build_rig(body, head, hair, crown, cape)
ACTIONS = [make_action(arm, "idle-loop", 60, p_idle), make_action(arm, "walk-loop", 30, p_walk), make_action(arm, "run-loop", 20, p_run),
           make_action(arm, "air-loop", 24, p_air), make_action(arm, "dash", 8, p_dash), make_action(arm, "cast", 26, p_cast)]
tris = sum(len(p.vertices) - 2 for o in (body, head, hair, crown, cape) for p in o.data.polygons)
print("WANDA tris:", tris, "groups on body:", len(body.vertex_groups))

if "--no-render" not in ARGS:
    cam = setup_preview()
    arm.animation_data.action = ACTIONS[0]
    SC.frame_set(1)
    for nm, ang in (("front", 0), ("three_q", 35), ("side", 90), ("back", 180)):
        shot(cam, nm, ang)
    shot(cam, "face", 12, dist=1.25, look=1.6, height=1.63)
    for act, fr, nm in ((ACTIONS[1], 8, "pose_walk"), (ACTIONS[2], 6, "pose_run"), (ACTIONS[5], 22, "pose_cast")):
        arm.animation_data.action = act
        SC.frame_set(fr)
        shot(cam, nm, 55)

arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)
for o in list(SC.objects):
    if o.type in ("LIGHT", "CAMERA"):
        bpy.data.objects.remove(o)
out = os.path.join(ROOT, "assets", "models", "wanda.glb")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
                          export_yup=True, export_apply=False, export_skins=True, export_force_sampling=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "blender", "wanda.blend"))
print("WANDA exported", out)
