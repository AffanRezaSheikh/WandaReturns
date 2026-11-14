"""Realistic anatomy for hero characters.

Loads the realistic body from Blender Studio's "Human Base Meshes" bundle
(public domain / CC0, see base_meshes/) and shapes it into a heroic build:
taller, broader chest and shoulders, deeper muscle definition, suit-smooth
groin, flattened ears. Also provides region masks (the bundle's face sets),
joint landmarks taken from the region boundaries, and "shell" pieces
(boots, gauntlets) grown from the body surface.
"""
import os
import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
BUNDLE = os.path.join(HERE, "base_meshes", "human-base-meshes-bundle-v1.4.1", "human_base_meshes_bundle.blend")

# face-set ids of the realistic bodies
SETS = dict(
    chest=[1], abdomen=[19], pelvis=[18], head=[17, 22, 2, 3, 4, 5, 7, 8], ears=[4, 5], lids=[2, 3], nose=[7], lips=[8], face=[22],
    hands=[9, 10] + list(range(64, 104)), palm=[9, 10], forearm=[11, 12], upper_arm=[20, 21],
    feet=[13, 14, 25, 26] + list(range(27, 64)), shin=[15, 16], thigh=[23, 24])


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Body:
    """Numpy view of the body mesh: coordinates, edges, face sets, region masks."""

    def __init__(self, ob):
        self.ob = ob
        me = self.me = ob.data
        n = len(me.vertices)
        co = np.empty(n * 3)
        me.vertices.foreach_get("co", co)
        self.co = co.reshape(-1, 3)
        e = np.empty(len(me.edges) * 2, dtype=np.int32)
        me.edges.foreach_get("vertices", e)
        self.edges = e.reshape(-1, 2)
        self.deg = np.maximum(1.0, np.bincount(self.edges.ravel(), minlength=n).astype(float))
        ids = np.empty(len(me.polygons), dtype=np.int32)
        me.attributes[".sculpt_face_set"].data.foreach_get("value", ids)
        self.face_set = ids
        lv = np.empty(len(me.loops), dtype=np.int32)
        me.loops.foreach_get("vertex_index", lv)
        lt = np.empty(len(me.polygons), dtype=np.int32)
        me.polygons.foreach_get("loop_total", lt)
        self.loop_vert = lv
        self.loop_face = np.repeat(np.arange(len(me.polygons)), lt)
        self.height = float(self.co[:, 2].max())

    def faces(self, *names):
        ids = [i for nm in names for i in SETS[nm]]
        return np.isin(self.face_set, ids)

    def mask(self, *names):
        """Vertices touching any face of the named regions."""
        f = self.faces(*names)
        m = np.zeros(len(self.co), dtype=bool)
        m[self.loop_vert[f[self.loop_face]]] = True
        return m

    def joint(self, a, b, side=0):
        """Centre of the seam between two regions (side: +1 left, -1 right, 0 both)."""
        m = self.mask(a) & self.mask(b)
        if side:
            m &= (self.co[:, 0] * side) > 0.0
        return Vector(self.co[m].mean(axis=0))

    def smooth(self, co, iters, lam=0.5):
        c = co.copy()
        e0, e1 = self.edges[:, 0], self.edges[:, 1]
        for _ in range(iters):
            acc = np.zeros_like(c)
            np.add.at(acc, e0, c[e1])
            np.add.at(acc, e1, c[e0])
            c += lam * (acc / self.deg[:, None] - c)
        return c

    def soften(self, w, iters):
        """Blur a per-vertex weight across the surface."""
        return self.smooth(w.astype(float)[:, None], iters, 0.6)[:, 0]

    def write(self):
        self.me.vertices.foreach_set("co", self.co.ravel())
        self.me.update()

    def normals(self):
        self.write()
        n = np.empty(len(self.co) * 3)
        self.me.vertices.foreach_get("normal", n)
        return n.reshape(-1, 3)


def load(name="GEO-body_male_realistic", level=1, height=1.88):
    """Appends the body (+ eyeballs), bakes the sculpt level, stands it on z=0 at the given height."""
    sc = bpy.context.scene
    with bpy.data.libraries.load(BUNDLE, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == name or n.startswith(name + ".eye")]
    src_obs = list(dst.objects)
    for o in src_obs:
        sc.collection.objects.link(o)
    base = [o for o in src_obs if o.name == name][0]
    base.location = (0, 0, 0)
    for m in base.modifiers:
        if m.type == "MULTIRES":
            m.levels = level
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(base.evaluated_get(dg))
    eye_meshes = []
    for o in src_obs:
        if o is not base:
            em = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
            em.transform(o.matrix_world)
            eye_meshes.append(em)
    for o in src_obs:
        bpy.data.objects.remove(o)
    zs = [v.co.z for v in me.vertices]
    s = height / (max(zs) - min(zs))
    fit = Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -min(zs)))
    body = bpy.data.objects.new("Body", me)
    sc.collection.objects.link(body)
    me.transform(fit)
    me.materials.clear()
    eyes = []
    for em in eye_meshes:
        em.transform(fit)
        em.materials.clear()
        eo = bpy.data.objects.new("Eye", em)
        sc.collection.objects.link(eo)
        eyes.append(eo)
    for p in me.polygons:
        p.use_smooth = True
    return body, eyes


def heroic(b, gain=0.6, chest=0.055, bulk=0.002):
    """Reshape the body in place: suit-smooth groin, flattened ears, deeper muscle cuts, broader chest."""
    h = b.height
    co = b.co
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    # the bodysuit has no anatomy at the groin: press anything that protrudes back onto a smooth front, then blend
    g = (np.abs(x) < 0.10) & (z > 0.39 * h) & (z < 0.545 * h) & (y < 0.03)
    lim = np.interp(z, [0.39 * h, 0.425 * h, 0.47 * h, 0.545 * h], [0.02, -0.035, -0.085, -0.115])
    co[:, 1] = np.where(g, np.maximum(y, lim), y)
    low = g & (np.abs(x) < 0.06) & (z < 0.452 * h)
    co[:, 2] = np.where(low, np.maximum(z, 0.452 * h - (0.452 * h - z) * 0.15), z)
    gs = np.clip(b.soften(g, 5) * 1.3, 0, 1)
    co += (b.smooth(co, 45) - co) * gs[:, None]
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    # ears lie flat (Vision has plates there, not ears)
    ears = b.mask("ears")
    lim = np.percentile(np.abs(x[b.mask("head") & ~ears & (np.abs(z - z[ears].mean()) < 0.03)]), 97)
    over = np.abs(x) - lim
    co[:, 0] = np.where(ears & (over > 0), np.sign(x) * (lim + over * 0.18), x)
    # deeper muscle definition: exaggerate the difference from a heavily smoothed body
    body_w = b.soften(~(b.mask("head") | b.mask("hands") | b.mask("feet")), 8)
    detail = co - b.smooth(co, 36)
    co += detail * (gain * body_w)[:, None]
    # heroic proportions: wider, deeper chest and shoulders
    z = co[:, 2]
    bump = np.exp(-((z - 0.775 * h) / (0.09 * h)) ** 2) * (1 - b.soften(b.mask("head"), 6))
    co[:, 0] *= 1 + chest * bump
    yc = 0.012
    co[:, 1] = yc + (co[:, 1] - yc) * (1 + chest * 0.55 * bump)
    b.co = co
    co += b.normals() * (bulk * body_w)[:, None]
    b.write()


def cavity_colors(b, name="Col", depth=0.0032, dark=0.42, light=0.10):
    """Vertex colours that darken the creases between muscles (painterly ink shading)."""
    n = b.normals()
    d = ((b.co - b.smooth(b.co, 7)) * n).sum(axis=1)
    f = 1.0 - np.clip(-d / depth, 0, 1) * dark + np.clip(d / depth, 0, 1) * light
    f = np.clip(b.soften(f, 1), 0.0, 1.2)
    me = b.me
    attr = me.color_attributes.get(name) or me.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    cols = np.ones((len(b.co), 4))
    cols[:, 0] = cols[:, 1] = cols[:, 2] = f
    attr.data.foreach_set("color", cols.ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = list(me.color_attributes).index(attr)
    me.update()


def shell(b, face_mask, amount, name, voxel=None, smooth_iters=0, floor=None):
    """A separate piece grown from part of the body surface (boot, gauntlet...).
    amount: metres, or a function(Vector) -> metres. Returns the new object."""
    bm = bmesh.new()
    bm.from_mesh(b.me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not face_mask[f.index]], context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * (amount(v.co) if callable(amount) else amount)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if voxel:
        r = ob.modifiers.new("remesh", "REMESH")
        r.mode = "VOXEL"
        r.voxel_size = voxel
    if smooth_iters:
        sm = ob.modifiers.new("smooth", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = smooth_iters
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    if floor is not None:
        for v in ob.data.vertices:
            v.co.z = max(v.co.z, floor)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def landmarks(b):
    """Joint and feature positions measured from the mesh (left side = +x)."""
    co = b.co
    h = b.height
    head = b.mask("head")
    mid = np.abs(co[:, 0]) < 0.012
    prof = head & mid & (co[:, 1] < -0.02)                           # the face's centre-line profile
    tip = co[prof][np.argmin(co[prof][:, 1])]                        # nose tip
    out = dict(
        height=h, neck=list(b.joint("chest", "head")),
        shoulder=list(b.joint("chest", "upper_arm", 1)), elbow=list(b.joint("upper_arm", "forearm", 1)), wrist=list(b.joint("forearm", "palm", 1)),
        hip=list(b.joint("pelvis", "thigh", 1)), knee=list(b.joint("thigh", "shin", 1)), ankle=list(b.joint("shin", "feet", 1)),
        waist=list(b.joint("abdomen", "pelvis")), ribs=list(b.joint("chest", "abdomen")),
        nose_tip=[float(c) for c in tip], head_top=float(co[head][:, 2].max()),
        head_back=float(co[head][:, 1].max()), head_half_width=float(np.percentile(np.abs(co[head & ~b.mask("ears")][:, 0]), 99.5)),
    )
    for nm in ("lips", "nose", "lids", "ears", "face"):
        m = b.mask(nm) & (co[:, 0] > -0.001 if nm in ("lids", "ears") else np.ones(len(co), dtype=bool))
        c = co[m]
        out[nm] = dict(centre=[float(v) for v in c.mean(axis=0)], lo=[float(v) for v in c.min(axis=0)], hi=[float(v) for v in c.max(axis=0)])
    hand = b.mask("hands") & (co[:, 0] > 0)
    foot = b.mask("feet") & (co[:, 0] > 0)
    out["fingertip"] = [float(v) for v in co[hand][np.argmin(co[hand][:, 2])]]
    out["toe"] = [float(v) for v in co[foot][np.argmin(co[foot][:, 1])]]
    out["heel"] = [float(v) for v in co[foot][np.argmax(co[foot][:, 1])]]
    out["chin"] = [float(v) for v in co[prof][np.argmin(co[prof][:, 2])]]
    return out
