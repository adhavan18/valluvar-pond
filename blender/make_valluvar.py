# Models Thiruvalluvar for Valluvar's Pond and exports models/valluvar.glb.
# An original stylised figure: seated cross-legged, long white beard, matted topknot, ash lines,
# rudraksha beads, shoulder cloth, sacred thread, a palm-leaf bundle in the left hand, and the
# right hand forward to hold the fishing rod (the rod itself is made in the game).
#
# Run:  blender --background --python blender/make_valluvar.py            (seated, for the pond)
#       POSE=stand blender --background --python blender/make_valluvar.py (standing, for walking)
# Built facing -Y with Z up, so the glTF export gives the game +Z forward, Y up.
import math
import os
import bpy
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)

POSE = os.environ.get("POSE", "sit")
LIFT = 0.62   # how far the upper body rises when he stands


def drop_since(before):
    """Removes what a seated-only section made, when building the standing figure."""
    if POSE == "stand":
        for o in set(bpy.data.objects) - before:
            bpy.data.objects.remove(o, do_unlink=True)



def material(name, rgb, rough=0.75):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


SKIN = material("skin", (0.40, 0.22, 0.12))
SKIN_DARK = material("skin_shadow", (0.30, 0.16, 0.09))
CLOTH = material("cloth", (0.93, 0.89, 0.78))
BORDER = material("cloth_border", (0.72, 0.28, 0.12))
HAIR = material("hair", (0.90, 0.90, 0.87))
DARK = material("dark", (0.07, 0.05, 0.04), 0.4)
ASH = material("ash", (0.97, 0.97, 0.94))
RED = material("kumkum", (0.70, 0.10, 0.08))
BEAD = material("rudraksha", (0.33, 0.17, 0.09), 0.9)
LEAF = material("palm_leaf", (0.80, 0.66, 0.38))
THREAD = material("thread", (0.96, 0.94, 0.86))


def finish(obj, mat, smooth=True):
    obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def ball(loc, radius, mat, scale=(1, 1, 1), rot=(0, 0, 0), seg=28):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=seg, ring_count=seg // 2)
    o = bpy.context.object
    o.scale = scale
    o.rotation_euler = rot
    return finish(o, mat)


def tube(a, b, r1, mat, r2=None, verts=16):
    """A tapered cylinder from a to b, with rounded joints."""
    a, b = Vector(a), Vector(b)
    r2 = r1 if r2 is None else r2
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    finish(o, mat)
    ball(a, r1, mat, seg=16)
    ball(b, r2, mat, seg=16)
    return o


def ring(loc, major, minor, mat, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=major, minor_radius=minor, major_segments=40, minor_segments=10)
    o = bpy.context.object
    o.rotation_euler = rot
    o.scale = scale
    return finish(o, mat)


def box(loc, size, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = rot
    return finish(o, mat, smooth=False)


# ---- Dhoti and crossed legs ----
_before = set(bpy.data.objects)
ball((0, -0.08, 0.20), 0.5, CLOTH, scale=(1.22, 1.0, 0.42))
for s in (-1, 1):
    ball((0.50 * s, -0.12, 0.20), 0.2, CLOTH, scale=(1.0, 1.15, 0.85))            # knee
    tube((0.48 * s, -0.15, 0.19), (-0.12 * s, -0.52, 0.17), 0.115, CLOTH, 0.085)  # shin, under cloth
    ball((-0.22 * s, -0.58, 0.16), 0.085, SKIN, scale=(1.5, 0.9, 0.7))            # foot
# The dhoti's coloured border, lying across the lap.
# The dhoti's coloured border: a band where the cloth folds at the waist.
ring((0, -0.02, 0.50), 0.275, 0.022, BORDER, scale=(1.05, 0.82, 1.0))

drop_since(_before)

# ---- Torso ----
ball((0, 0, 0.74), 0.30, SKIN, scale=(1.02, 0.78, 1.5))
ball((0, -0.07, 0.60), 0.22, SKIN, scale=(1.1, 0.9, 0.85))          # a gentle belly
for s in (-1, 1):
    ball((0.31 * s, 0, 1.10), 0.105, SKIN)                           # shoulders
    ball((0.13 * s, -0.19, 0.98), 0.012, SKIN_DARK, seg=10)
tube((0, 0, 1.12), (0, -0.01, 1.28), 0.095, SKIN, 0.085)             # neck

# Shoulder cloth over the left shoulder, and the sacred thread over the same shoulder.
ring((0.0, 0.0, 0.78), 0.385, 0.06, CLOTH, rot=(math.radians(90), math.radians(-38), 0), scale=(1.0, 1.0, 0.62))
ring((0.0, -0.01, 0.80), 0.40, 0.009, THREAD, rot=(math.radians(90), math.radians(-30), 0), scale=(1.0, 1.0, 0.66))

# Rudraksha beads around the neck.
for i in range(18):
    a = math.tau * i / 18
    ball((math.sin(a) * 0.155, -math.cos(a) * 0.125 - 0.01, 1.135 - 0.05 * max(0.0, math.cos(a))), 0.021, BEAD, seg=10)

# ---- Head ----
HEAD = Vector((0, -0.01, 1.46))
ball(HEAD, 0.235, SKIN, scale=(0.95, 1.0, 1.08))
for s in (-1, 1):
    ball(HEAD + Vector((0.225 * s, 0.02, -0.01)), 0.06, SKIN, scale=(0.45, 0.8, 1.2))          # ears
    ball(HEAD + Vector((0.085 * s, -0.212, 0.03)), 0.024, DARK, seg=12)                        # eyes
    tube(HEAD + Vector((0.035 * s, -0.215, 0.085)), HEAD + Vector((0.135 * s, -0.19, 0.095)), 0.011, HAIR, 0.007, verts=8)  # brows
    ball(HEAD + Vector((0.055 * s, -0.225, -0.075)), 0.05, HAIR, scale=(1.5, 0.6, 0.55), rot=(0, 0.35 * s, 0))  # moustache
ball(HEAD + Vector((0, -0.235, -0.02)), 0.036, SKIN, scale=(0.85, 1.0, 1.25))                  # nose
# Three lines of sacred ash and a kumkum dot.
for k in range(3):
    z = 0.125 + k * 0.026
    y = -math.sqrt(max(0.0, 0.235 ** 2 - (z / 1.08) ** 2 - 0.06 ** 2)) + 0.004   # lie on the forehead
    tube(HEAD + Vector((-0.07, y, z)), HEAD + Vector((0.07, y, z)), 0.006, ASH, verts=8)
ball(HEAD + Vector((0, -0.222, 0.098)), 0.016, RED, seg=10)

# Beard: full at the jaw, long and tapering to the chest.
ball(HEAD + Vector((0, -0.13, -0.16)), 0.17, HAIR, scale=(1.05, 0.72, 0.9))
ball(HEAD + Vector((0, -0.16, -0.31)), 0.13, HAIR, scale=(0.95, 0.62, 1.25))
ball(HEAD + Vector((0, -0.175, -0.46)), 0.085, HAIR, scale=(0.85, 0.6, 1.45))
for s in (-1, 1):
    ball(HEAD + Vector((0.165 * s, -0.07, -0.10)), 0.085, HAIR, scale=(0.6, 0.9, 1.3))        # sideburns into the beard

# Hair swept back, with the matted topknot (jata).
ball(HEAD + Vector((0, 0.045, 0.045)), 0.245, HAIR, scale=(0.98, 0.95, 1.02))
ball(HEAD + Vector((0, 0.15, -0.10)), 0.15, HAIR, scale=(1.1, 0.7, 1.3))                       # hair at the nape
ball(HEAD + Vector((0, 0.03, 0.29)), 0.125, HAIR, scale=(1.0, 1.0, 0.85))
ball(HEAD + Vector((0, 0.03, 0.41)), 0.085, HAIR)
ring(HEAD + Vector((0, 0.03, 0.335)), 0.085, 0.014, BEAD)                                      # the cord that ties it

# ---- Arms ----
_before = set(bpy.data.objects)
# Right arm forward, hand closed where the game puts the rod: game (0.42, 0.86, 0.5) = here (0.42, -0.5, 0.86).
tube((0.33, 0.0, 1.08), (0.47, -0.22, 0.80), 0.082, SKIN, 0.07)
tube((0.47, -0.22, 0.80), (0.42, -0.47, 0.85), 0.068, SKIN, 0.058)
ball((0.42, -0.51, 0.86), 0.075, SKIN, scale=(0.9, 1.0, 1.0))
# Left arm resting, hand on the palm-leaf bundle in the lap.
tube((-0.33, 0.0, 1.08), (-0.46, -0.20, 0.72), 0.082, SKIN, 0.07)
tube((-0.46, -0.20, 0.72), (-0.22, -0.43, 0.50), 0.068, SKIN, 0.058)
ball((-0.19, -0.46, 0.49), 0.072, SKIN, scale=(1.1, 1.0, 0.75))

# ---- Palm-leaf bundle (olai suvadi): leaves between two boards, tied with a cord ----
for k in range(5):
    box((-0.02, -0.52, 0.415 + k * 0.012), (0.60, 0.13, 0.009), LEAF, rot=(0, 0, math.radians(14)))
box((-0.02, -0.52, 0.405), (0.62, 0.14, 0.012), BEAD, rot=(0, 0, math.radians(14)))
box((-0.02, -0.52, 0.478), (0.62, 0.14, 0.012), BEAD, rot=(0, 0, math.radians(14)))
for off in (-0.17, 0.17):
    c = Vector((-0.02 + off * math.cos(math.radians(14)), -0.52 + off * math.sin(math.radians(14)), 0.44))
    ring(c, 0.075, 0.006, RED, rot=(0, math.radians(90), math.radians(14)), scale=(1.0, 1.0, 0.6))

drop_since(_before)

# ---- Standing: a long dhoti, feet, a walking staff, and the palm leaves under his arm ----
if POSE == "stand":
    for o in bpy.data.objects:
        o.location.z += LIFT
    tube((0, 0, 0.36), (0, 0, 1.06), 0.34, CLOTH, 0.30, verts=24)
    ring((0, 0, 0.30), 0.335, 0.022, BORDER)
    for s in (-1, 1):
        ball((0.13 * s, -0.15, 0.06), 0.085, SKIN, scale=(1.0, 1.7, 0.6))
    # Right arm on the staff.
    tube((0.33, 0.0, 1.70), (0.50, -0.12, 1.36), 0.082, SKIN, 0.07)
    tube((0.50, -0.12, 1.36), (0.46, -0.36, 1.42), 0.068, SKIN, 0.058)
    ball((0.46, -0.40, 1.43), 0.075, SKIN)
    tube((0.46, -0.42, 0.03), (0.46, -0.42, 2.08), 0.028, BEAD, 0.022, verts=8)
    # Left arm carrying the bundle.
    tube((-0.33, 0.0, 1.70), (-0.44, -0.04, 1.34), 0.082, SKIN, 0.07)
    tube((-0.44, -0.04, 1.34), (-0.40, -0.26, 1.12), 0.068, SKIN, 0.058)
    ball((-0.40, -0.30, 1.10), 0.072, SKIN)
    for k in range(4):
        box((-0.40, -0.36, 1.065 + k * 0.014), (0.13, 0.52, 0.011), LEAF)
    box((-0.40, -0.36, 1.052), (0.14, 0.54, 0.012), BEAD)
    box((-0.40, -0.36, 1.124), (0.14, 0.54, 0.012), BEAD)

# ---- Export ----
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models", "valluvar_walk.glb" if POSE == "stand" else "valluvar.glb")
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.object.join()
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.context.object.name = "Valluvar"
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_yup=True)
print("exported", out, len(bpy.context.object.data.polygons), "faces")
