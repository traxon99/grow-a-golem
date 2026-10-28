"""Builds Grow A Golem's original low-poly golem meshes in Blender (#16).

Run inside Blender (Scripting tab, or the Blender MCP add-on):

    exec(open(r"<repo>/scripts/blender/build_golems.py").read())

Everything is authored from primitives here, so the art is original and the
models can be rebuilt. Units are studs (one Blender unit = one stud) and the
golem faces +Y, which the default FBX export turns into Roblox's -Z.

Each tier gets one collection, ``Golem_<tier>``, with one mesh object per
slot and colour role: ``<Slot>_Main`` (tier colour), ``<Slot>_Trim`` (the
darker shade) and ``<Slot>_Glow`` (runes and eyes, recoloured by skins).
Every object's origin is its slot's attachment centre (the invisible carrier
part in GolemService), placed at the scale-1 golem's pose so the whole golem
can be seen together. ``export_fbx`` writes one FBX per tier.
"""

import math
import os
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

# Carrier centres in the golem root's space, in Roblox axes (Y up, -Z front).
SLOTS = {
    "Head": (0, 6, 0),
    "Torso": (0, 1, 0),
    "LeftArm": (-5, 0.5, 0),
    "RightArm": (5, 0.5, 0),
    "LeftLeg": (-2, -5.5, 0),
    "RightLeg": (2, -5.5, 0),
}

# Tier colours match Config.Tiers; trim is a darker shade (TRIM_SHADE).
TIERS = [
    ("stone", (128, 122, 110)),
    ("copper", (184, 108, 60)),
    ("iron", (150, 156, 166)),
    ("crystal", (150, 110, 255)),
    ("stormglass", (100, 190, 255)),
    ("abyssite", (55, 175, 160)),
    ("sunsteel", (255, 190, 70)),
    ("aether", (230, 170, 255)),
]
GLOW = (90, 200, 255)
TRIM_SHADE = 0.68

# Roblox axes to Blender axes: (x, y, z) -> (x, -z, y).
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
TO_ROBLOX = TO_BLENDER.inverted()


def rbx(x, y, z):
    return Vector((x, -z, y))


class Part:
    """Collects primitives for one slot, in the slot's local Roblox space."""

    def __init__(self, rng):
        self.rng = rng
        self.meshes = {"Main": bmesh.new(), "Trim": bmesh.new(), "Glow": bmesh.new()}
        # Added to every position; tier styles are drawn against a slot's
        # surface and the shared body sets where that surface is.
        self.shift = Vector((0, 0, 0))

    def _matrix(self, at, size, rot):
        # Primitives are built along Blender Z, which is Roblox Y.
        m = (
            Matrix.Translation(Vector(at) + self.shift)
            @ (
                Matrix.Rotation(math.radians(rot[1]), 4, "Y")
                @ Matrix.Rotation(math.radians(rot[0]), 4, "X")
                @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
            )
            @ Matrix.Diagonal((size[0], size[1], size[2], 1))
        )
        return TO_BLENDER @ m @ TO_ROBLOX

    def _jitter(self, verts, amount):
        if amount <= 0:
            return
        for v in verts:
            v.co += Vector(
                (
                    self.rng.uniform(-amount, amount),
                    self.rng.uniform(-amount, amount),
                    self.rng.uniform(-amount, amount),
                )
            )

    def box(self, role, at, size, rot=(0, 0, 0), jitter=0.0, bevel=0.0):
        bm = self.meshes[role]
        verts = bmesh.ops.create_cube(bm, size=1, matrix=self._matrix(Vector(at), size, rot))["verts"]
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(bm, geom=verts + edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
            verts = list({v for e in edges if e.is_valid for v in e.verts})
        self._jitter(verts, jitter)

    def frustum(self, role, at, bottom, top, height, segments=4, depth=1.0, rot=(0, 0, 0), jitter=0.0, spin=45):
        """A tapered prism standing on Roblox Y. ``depth`` squashes it front to back."""
        bm = self.meshes[role]
        m = self._matrix(Vector(at), (1, height, depth), rot) @ TO_BLENDER @ Matrix.Rotation(
            math.radians(spin), 4, "Y"
        ) @ TO_ROBLOX
        verts = bmesh.ops.create_cone(
            bm, cap_ends=True, segments=segments, radius1=bottom, radius2=top, depth=1, matrix=m
        )["verts"]
        self._jitter(verts, jitter)

    def rock(self, role, at, size, rot=(0, 0, 0), jitter=0.12, round=False):
        """A faceted boulder; ``round`` gives it more faces for a smoother bulk."""
        bm = self.meshes[role]
        verts = bmesh.ops.create_icosphere(
            bm, subdivisions=2 if round else 1, radius=0.5, matrix=self._matrix(Vector(at), size, rot)
        )["verts"]
        self._jitter(verts, jitter * min(size))

    def spike(self, role, at, radius, height, rot=(0, 0, 0), segments=5):
        """A pointed crystal or horn: a short prism with a tip, base at ``at``."""
        bm = self.meshes[role]
        m = self._matrix(Vector(at), (1, 1, 1), rot)
        base = height * 0.35
        lift = TO_BLENDER @ Matrix.Translation((0, base / 2, 0)) @ TO_ROBLOX
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=base, matrix=m @ lift)
        tip = TO_BLENDER @ Matrix.Translation((0, base + (height - base) / 2, 0)) @ TO_ROBLOX
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=0, depth=height - base, matrix=m @ tip)

    def ring(self, role, at, radius, thickness, rot=(0, 0, 0), segments=10):
        bm = self.meshes[role]
        m = self._matrix(Vector(at), (1, 1, 1), rot)
        for i in range(segments):
            a0 = 2 * math.pi * i / segments
            a1 = 2 * math.pi * (i + 1) / segments
            mid = (a0 + a1) / 2
            length = 2 * radius * math.sin(math.pi / segments) + thickness * 0.3
            seg = (
                Matrix.Translation((radius * math.cos(mid), 0, radius * math.sin(mid)))
                @ Matrix.Rotation(-mid, 4, "Y")
                @ Matrix.Diagonal((thickness, thickness, length, 1))
            )
            bmesh.ops.create_cube(bm, size=1, matrix=m @ TO_BLENDER @ seg @ TO_ROBLOX)


# ---------------------------------------------------------------- the shared body
# A hunched boulder: one big rounded body, a small head set low and forward,
# long heavy arms whose fists hang near the ground, and short stubby legs.
# Each tier's "rough" sets how jagged the stone is; metal tiers are cut smooth.

def lump(p, t, role, at, size, rot=(0, 0, 0)):
    p.rock(role, at, size, rot=rot, jitter=t["rough"] * 0.6 + 0.02, round=True)


def base_torso(p, t):
    w = t["chest"]
    lump(p, t, "Main", (0, 1.2, 0.5), (w * 1.75, 7.0, 6.2), rot=(-14, 0, 0))
    lump(p, t, "Main", (0, -2.0, 0.4), (w * 1.25, 3.4, 4.8))
    lump(p, t, "Main", (0, -3.6, 0.3), (w * 1.35, 3.0, 4.4))  # hips, which the thighs sink into
    lump(p, t, "Trim", (0, 3.6, 1.3), (w * 1.3, 2.6, 4.0), rot=(-20, 0, 0))  # hunched back
    p.shift = Vector((0, 0, -0.8))


def base_head(p, t):
    lump(p, t, "Main", (0, -1.3, -1.7), (3.3, 2.8, 3.2))
    p.box("Trim", (0, -0.45, -2.75), (3.1, 0.7, 0.9), rot=(-15, 0, 0), jitter=t["rough"] * 0.3, bevel=0.12)  # brow
    for side in (-1, 1):
        p.box("Glow", (side * 0.65, -1.05, -3.0), (0.6, 0.38, 0.2), rot=(0, 0, side * -12))
    p.shift = Vector((0, -0.8, -1.1))


def base_arm(p, t, side):
    lump(p, t, "Trim", (side * 0.2, 2.8, 0.2), (3.8, 3.0, 3.6))  # shoulder
    lump(p, t, "Main", (side * 0.1, 0.6, 0), (2.8, 4.8, 2.8))
    lump(p, t, "Main", (0, -2.9, -0.2), (3.5, 4.8, 3.5))
    lump(p, t, "Main", (0, -5.7, -0.4), (3.9, 3.0, 3.9))  # fist
    p.box("Trim", (0, -5.3, -2.2), (2.6, 0.9, 0.5), bevel=0.1)  # knuckles
    p.shift = Vector((0, -0.6, 0))


def base_leg(p, t, side):
    lump(p, t, "Main", (side * 0.2, 0.9, 0), (3.8, 5.4, 3.6))  # reaches up into the hips
    lump(p, t, "Trim", (0, -1.55, -0.3), (3.9, 2.0, 4.4))  # foot
    for toe in (-1.0, 0, 1.0):
        p.box("Trim", (toe, -2.05, -2.35), (0.8, 0.8, 0.8), jitter=t["rough"] * 0.2, bevel=0.1)


# ---------------------------------------------------------------- the starter
# Stone is the first golem players get, so it's cute rather than hulking:
# chunky faceted stones, a big round head with big eyes, short chubby arms and
# round stubby feet.

def pebble(p, role, at, size, jitter=0.06):
    p.rock(role, at, size, jitter=jitter, round=True)


def cute_torso(p, t):
    pebble(p, "Main", (0, 0.8, 0.3), (8.0, 6.4, 6.0))
    pebble(p, "Main", (0, -3.2, 0.3), (6.6, 3.4, 4.8))  # hips, which the thighs sink into
    pebble(p, "Glow", (0, 0.9, -2.75), (1.1, 1.1, 0.5), jitter=0.02)  # core
    for x, y, z, d in ((-2.6, 3.3, 0.6, 1.6), (2.4, 3.5, 1.2, 1.3), (0.4, 3.9, 2.0, 1.4), (-2.9, -0.8, -1.8, 1.1)):
        pebble(p, "Trim", (x, y, z), (d, d * 0.8, d))


def cute_head(p, t):
    pebble(p, "Main", (0, -0.9, -1.1), (4.4, 3.8, 4.0), jitter=0.04)
    pebble(p, "Trim", (0.6, 0.9, -0.9), (1.4, 1.1, 1.3))  # pebble on top
    for side in (-1, 1):
        p.box("Glow", (side * 0.95, -0.8, -3.05), (0.85, 1.05, 0.2), bevel=0.12)


def cute_arm(p, t, side):
    # Pulled in toward the body so the shoulder sits against it.
    pebble(p, "Trim", (side * -0.4, 2.6, 0.1), (3.6, 3.2, 3.6))  # shoulder
    pebble(p, "Main", (side * -0.2, 0.2, 0), (3.0, 4.6, 3.0))
    pebble(p, "Main", (0, -2.8, -0.3), (3.8, 3.4, 3.8))  # fist


def cute_leg(p, t, side):
    pebble(p, "Main", (side * 0.2, 0.9, 0), (3.9, 5.4, 3.7))
    pebble(p, "Trim", (0, -1.5, -0.4), (4.0, 2.0, 4.4))  # round foot


# ---------------------------------------------------------------- tier styles

def style_stone(p, slot, side, t):
    """The cute starter: its body is all in cute_*; nothing to add."""


def style_copper(p, slot, side, t):
    """Riveted boiler plates, a pressure gauge face and exhaust pipes."""
    if slot == "Torso":
        p.frustum("Trim", (0, 1.4, -1.55), 1.4, 1.4, 0.5, segments=8, rot=(90, 0, 0), spin=0)
        p.frustum("Glow", (0, 1.4, -1.85), 0.9, 0.9, 0.2, segments=8, rot=(90, 0, 0), spin=0)
        for x in (-1.4, 1.4):
            p.frustum("Trim", (x, 3.6, 1.6), 0.35, 0.3, 2.4, segments=6, spin=0)
            p.frustum("Glow", (x, 4.85, 1.6), 0.25, 0.25, 0.2, segments=6, spin=0)
        for x in (-2.6, -1.3, 1.3, 2.6):
            p.box("Trim", (x, -0.2, -1.85), (0.3, 0.3, 0.3))
    elif slot == "Head":
        p.frustum("Trim", (0, 1.0, -0.4), 1.5, 1.2, 0.5, segments=8, spin=0)
        p.box("Trim", (0, -0.3, -2.05), (2.4, 0.15, 0.2))
    elif slot in ("LeftArm", "RightArm"):
        p.frustum("Trim", (0, 3.0, 0), 1.9, 1.6, 0.6, segments=8, spin=0)
        p.frustum("Trim", (0, -2.9, 0), 1.65, 1.65, 0.5, segments=8, spin=0)
    else:
        p.frustum("Trim", (0, 0, 0), 1.6, 1.6, 0.5, segments=8, spin=0)


def style_iron(p, slot, side, t):
    """A knight's armour: big pauldrons, a slit visor and a plated skirt."""
    if slot == "Torso":
        p.frustum("Trim", (0, 1.6, -1.6), 1.6, 2.4, 3.2, depth=0.25, segments=4)
        p.box("Glow", (0, 1.8, -1.95), (0.4, 1.4, 0.2))
        for x in (-1.8, 0, 1.8):
            p.box("Trim", (x, -3.9, -1.5), (1.6, 1.2, 0.4), rot=(-10, 0, 0), bevel=0.1)
    elif slot == "Head":
        p.box("Trim", (0, 0.2, -0.4), (3.5, 0.5, 3.4), bevel=0.1)
        p.spike("Trim", (0, 0.4, 0.4), 0.4, 1.6, rot=(-20, 0, 0), segments=4)
    elif slot in ("LeftArm", "RightArm"):
        for i, y in enumerate((3.6, 2.8)):
            p.box("Trim", (side * 0.5, y, 0), (3.9 - i * 0.4, 0.7, 3.6 - i * 0.3), rot=(0, 0, side * -18), bevel=0.12)
        p.box("Trim", (0, -2.3, 0), (3.2, 1.5, 3.2), bevel=0.15)
    else:
        p.box("Trim", (0, 0.1, -1.4), (2.2, 1.4, 0.5), bevel=0.15)


def style_crystal(p, slot, side, t):
    """A dark rock body cracked open by crystal clusters."""
    if slot == "Torso":
        for x, z, h, lean in ((-2.0, 1.3, 3.0, -20), (-0.6, 1.8, 3.8, -6), (1.0, 1.6, 2.6, 14), (2.2, 1.0, 2.0, 28)):
            p.spike("Trim", (x, 3.3, z), 0.55, h, rot=(18, 0, lean))
        p.rock("Glow", (0, 1.3, -1.9), (1.4, 1.6, 0.6), jitter=0.05)
    elif slot == "Head":
        p.spike("Trim", (-0.6, 0.6, 0), 0.35, 1.8, rot=(0, 0, 20))
        p.spike("Trim", (0.5, 0.6, -0.3), 0.3, 1.4, rot=(-10, 0, -18))
    elif slot in ("LeftArm", "RightArm"):
        for h, lean in ((2.6, 15), (1.9, 40)):
            p.spike("Trim", (side * 0.6, 3.6, 0), 0.45, h, rot=(0, 0, side * -lean))
        for z in (-0.8, 0.6):
            p.spike("Trim", (0, -4.4, z), 0.35, 1.3, rot=(-90 if z < 0 else 90, 0, 0))
    else:
        p.spike("Trim", (side * 1.2, 0.6, 0.3), 0.3, 1.2, rot=(0, 0, side * -60))


def style_stormglass(p, slot, side, t):
    """Sharp glass panes, swept fins and a lightning-bolt core."""
    if slot == "Torso":
        for k, (dx, dy) in enumerate(((0.0, 2.4), (0.45, 1.5), (-0.3, 0.9), (0.2, 0.0))):
            p.box("Glow", (dx, dy, -1.95), (0.45, 1.0, 0.2), rot=(0, 0, 30 if k % 2 else -30))
        for x in (-1.6, 1.6):
            p.spike("Trim", (x, 3.2, 1.6), 0.5, 3.4, rot=(50, 0, x * 8), segments=3)
    elif slot == "Head":
        p.spike("Trim", (0, 0.7, -0.2), 0.45, 2.6, rot=(55, 0, 0), segments=3)
        for s in (-1, 1):
            p.spike("Trim", (s * 1.6, 0.0, 0), 0.3, 1.5, rot=(40, 0, s * -55), segments=3)
    elif slot in ("LeftArm", "RightArm"):
        p.spike("Trim", (side * 1.0, 3.4, 0.4), 0.6, 3.0, rot=(30, 0, side * -45), segments=3)
        p.spike("Trim", (side * 0.9, -2.0, 0.6), 0.4, 2.2, rot=(60, 0, side * -70), segments=3)
    else:
        p.spike("Trim", (side * 1.3, 0.3, 0.6), 0.35, 1.8, rot=(70, 0, side * -50), segments=3)


def style_abyssite(p, slot, side, t):
    """Deep-sea plating: back spines, barnacles and a glowing lure."""
    if slot == "Torso":
        for y, h in ((3.4, 2.4), (2.2, 2.0), (1.0, 1.6), (-0.2, 1.2)):
            p.spike("Trim", (0, y, 2.0), 0.35, h, rot=(70, 0, 0), segments=4)
        for x, y in ((-2.2, 0.4), (2.0, 2.2), (1.4, -0.8)):
            p.frustum("Trim", (x, y, -1.55), 0.4, 0.2, 0.5, segments=6, rot=(-90, 0, 0), spin=0)
        p.rock("Glow", (0, 1.3, -1.9), (1.2, 1.2, 0.6), jitter=0.05)
    elif slot == "Head":
        p.frustum("Trim", (0, 1.3, -0.9), 0.12, 0.12, 2.2, segments=4, rot=(-40, 0, 0))
        p.rock("Glow", (0, 2.1, -2.0), (0.7, 0.7, 0.7), jitter=0.03)
    elif slot in ("LeftArm", "RightArm"):
        for k in range(3):
            p.spike("Trim", (side * 1.3, 2.6 - k * 0.9, 0.3), 0.3, 1.4 - k * 0.2, rot=(20, 0, side * -75), segments=4)
        p.frustum("Trim", (side * 0.9, -4.6, 0.6), 0.35, 0.15, 0.5, segments=6, rot=(0, 0, side * -90), spin=0)
    else:
        p.spike("Trim", (0, 0.4, 1.4), 0.3, 1.1, rot=(80, 0, 0), segments=4)


def style_sunsteel(p, slot, side, t):
    """Gilded armour with a sun disc on the chest and a rayed crown."""
    if slot == "Torso":
        p.frustum("Trim", (0, 1.4, -1.6), 1.5, 1.5, 0.4, segments=10, rot=(90, 0, 0), spin=0)
        p.frustum("Glow", (0, 1.4, -1.85), 0.9, 0.9, 0.2, segments=10, rot=(90, 0, 0), spin=0)
        for k in range(8):
            a = math.radians(k * 45)
            p.spike("Trim", (math.cos(a) * 1.5, 1.4 + math.sin(a) * 1.5, -1.6), 0.22, 0.8,
                    rot=(0, 0, math.degrees(a) - 90), segments=4)
        p.box("Trim", (0, -2.9, -1.5), (3.0, 1.2, 0.6), bevel=0.15)
    elif slot == "Head":
        for k, x in enumerate((-1.2, -0.6, 0, 0.6, 1.2)):
            p.spike("Glow" if k == 2 else "Trim", (x, 0.6, -1.2), 0.22, 1.6 - abs(x) * 0.5,
                    rot=(-10, 0, -x * 12), segments=4)
    elif slot in ("LeftArm", "RightArm"):
        p.frustum("Trim", (side * 0.3, 3.4, 0), 2.0, 1.2, 1.4, segments=8, spin=0)
        p.spike("Trim", (side * 0.6, 4.0, 0), 0.35, 1.6, rot=(0, 0, side * -25), segments=4)
        p.frustum("Trim", (0, -3.0, 0), 1.75, 1.75, 0.6, segments=8, spin=0)
    else:
        p.frustum("Trim", (0, 0.1, 0), 1.65, 1.65, 0.6, segments=8, spin=0)
        p.box("Trim", (0, 0.1, -1.55), (1.0, 1.0, 0.4), rot=(0, 0, 45))


def style_aether(p, slot, side, t):
    """A star-forged guardian: floating plates, a halo and star facets."""
    if slot == "Torso":
        p.spike("Glow", (0, 0.6, -1.7), 0.7, 1.6, rot=(0, 0, 0), segments=4)
        p.spike("Glow", (0, 2.2, -1.7), 0.7, 1.6, rot=(180, 0, 0), segments=4)
        for x in (-2.6, 2.6):
            p.box("Trim", (x, 3.8, 1.6), (1.2, 1.2, 0.6), rot=(0, 0, 45))
    elif slot == "Head":
        p.ring("Glow", (0, 1.6, 0.6), 1.9, 0.22, rot=(-20, 0, 0), segments=12)
        p.spike("Trim", (0, 0.8, -1.2), 0.3, 1.2, rot=(-25, 0, 0), segments=4)
    elif slot in ("LeftArm", "RightArm"):
        p.ring("Trim", (0, -2.8, 0), 1.9, 0.25, segments=10)
        p.spike("Trim", (side * 0.4, 4.0, 0), 0.6, 2.2, rot=(0, 0, side * -12), segments=4)
    else:
        p.ring("Trim", (0, 0.2, 0), 1.75, 0.22, segments=10)


# Per-tier proportions: chest/waist radii and how rough the surface is.
STYLES = {
    "stone": (style_stone, dict(chest=4.9, waist=3.4, rough=0.18, cute=True)),
    "copper": (style_copper, dict(chest=4.8, waist=3.6, rough=0.0)),
    "iron": (style_iron, dict(chest=5.2, waist=3.3, rough=0.0)),
    "crystal": (style_crystal, dict(chest=5.0, waist=3.4, rough=0.14)),
    "stormglass": (style_stormglass, dict(chest=5.3, waist=3.0, rough=0.04)),
    "abyssite": (style_abyssite, dict(chest=5.0, waist=3.6, rough=0.08)),
    "sunsteel": (style_sunsteel, dict(chest=5.4, waist=3.3, rough=0.0)),
    "aether": (style_aether, dict(chest=5.2, waist=2.8, rough=0.0)),
}


def material(name, rgb, emit=False):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    color = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.8
        if emit:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat


def shade(rgb, k):
    return tuple(max(0, min(255, int(c * k))) for c in rgb)


def build_tier(tier, rgb, offset_x=0.0):
    name = f"Golem_{tier}"
    old = bpy.data.collections.get(name)
    if old:
        for obj in list(old.objects):
            bpy.data.meshes.remove(obj.data)
        bpy.data.collections.remove(old)
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    mats = {
        "Main": material(f"{tier}_Main", rgb),
        "Trim": material(f"{tier}_Trim", shade(rgb, TRIM_SHADE)),
        "Glow": material(f"{tier}_Glow", GLOW, emit=True),
    }
    style, t = STYLES[tier]
    for slot, centre in SLOTS.items():
        rng = random.Random(f"{tier}:{slot}")
        side = -1 if slot.startswith("Left") else 1
        p = Part(rng)
        cute = t.get("cute")
        if slot == "Torso":
            (cute_torso if cute else base_torso)(p, t)
        elif slot == "Head":
            (cute_head if cute else base_head)(p, t)
        elif slot.endswith("Arm"):
            (cute_arm if cute else base_arm)(p, t, side)
        else:
            (cute_leg if cute else base_leg)(p, t, side)
        style(p, slot, side, t)
        for role, bm in p.meshes.items():
            if not bm.verts:
                bm.free()
                continue
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            mesh = bpy.data.meshes.new(f"{tier}_{slot}_{role}")
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(mats[role])
            obj = bpy.data.objects.new(f"{slot}_{role}", mesh)
            obj.location = rbx(*centre) + Vector((offset_x, 0, 8))
            obj["slot"] = slot
            obj["role"] = role
            coll.objects.link(obj)
    return coll


def build_all(spacing=16.0):
    for i, (tier, rgb) in enumerate(TIERS):
        build_tier(tier, rgb, offset_x=(i - (len(TIERS) - 1) / 2) * spacing)


def mesh_bounds(obj):
    """Bounding-box centre (offset from the slot centre) and size, in Roblox axes."""
    xs, ys, zs = zip(*(tuple(TO_ROBLOX.to_3x3() @ v.co) for v in obj.data.vertices))
    lo = Vector((min(xs), min(ys), min(zs)))
    hi = Vector((max(xs), max(ys), max(zs)))
    return [round(c, 4) for c in (lo + hi) / 2], [round(c, 4) for c in hi - lo]


def export_fbx(folder):
    """One FBX per tier, with each object moved back to the golem's origin.

    Also writes ``golem_meshes.json``: each mesh's bounding-box offset from its
    slot centre and its size, which the game needs to place the uploaded
    MeshParts (Roblox centres a MeshPart on its bounding box).
    """
    import json

    os.makedirs(folder, exist_ok=True)
    manifest = {}
    for tier, _ in TIERS:
        for obj in bpy.data.collections[f"Golem_{tier}"].objects:
            offset, size = mesh_bounds(obj)
            manifest.setdefault(tier, {}).setdefault(obj["slot"], {})[obj["role"]] = {"offset": offset, "size": size}
    with open(os.path.join(folder, "golem_meshes.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
        f.write("\n")
    for tier, _ in TIERS:
        coll = bpy.data.collections[f"Golem_{tier}"]
        saved = {obj: obj.location.copy() for obj in coll.objects}
        for obj in coll.objects:
            obj.location = rbx(*SLOTS[obj["slot"]])
        bpy.ops.object.select_all(action="DESELECT")
        for obj in coll.objects:
            obj.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(folder, f"golem_{tier}.fbx"),
            use_selection=True,
            object_types={"MESH"},
            apply_unit_scale=True,
            axis_forward="-Z",
            axis_up="Y",
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
        )
        for obj, loc in saved.items():
            obj.location = loc
