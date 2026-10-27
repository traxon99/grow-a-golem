#!/usr/bin/env python3
"""Rebuild original, explicitly authored low-poly templates and synthesized SFX.
No third-party models, recordings, textures, fonts or samples are used.
"""
from pathlib import Path
import math
import random
import struct
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
counter = 0


def item(parent, cls, name):
    global counter
    counter += 1
    obj = ET.SubElement(parent, "Item", {"class": cls, "referent": f"asset{counter}"})
    props = ET.SubElement(obj, "Properties")
    ET.SubElement(props, "string", name="Name").text = name
    return obj, props


def vector(props, name, xyz):
    el = ET.SubElement(props, "Vector3", name=name)
    for axis, value in zip("XYZ", xyz):
        ET.SubElement(el, axis).text = str(value)


def part(parent, name, size, pos, color, transparent=False, wedge=False):
    obj, props = item(parent, "WedgePart" if wedge else "Part", name)
    vector(props, "size", size)
    cf = ET.SubElement(props, "CoordinateFrame", name="CFrame")
    for axis, value in zip("XYZ", pos):
        ET.SubElement(cf, axis).text = str(value)
    for i in range(3):
        for j in range(3):
            ET.SubElement(cf, f"R{i}{j}").text = str(int(i == j))
    ET.SubElement(props, "Color3uint8", name="Color3uint8").text = str(
        0xFF000000 | color[0] << 16 | color[1] << 8 | color[2])
    for flag, value in [("Anchored", True), ("CanCollide", False), ("CanTouch", False), ("CanQuery", False)]:
        ET.SubElement(props, "bool", name=flag).text = str(value).lower()
    ET.SubElement(props, "float", name="Transparency").text = "1" if transparent else "0"
    return obj


def model(parent, name):
    obj, props = item(parent, "Model", name)
    pivot = part(obj, "ArtPivot", (.01, .01, .01), (0, 0, 0), (0, 0, 0), True)
    ET.SubElement(props, "Ref", name="PrimaryPart").text = pivot.attrib["referent"]
    return obj


def lighter(c, delta):
    return tuple(max(0, min(255, channel + delta)) for channel in c)


def build_models():
    xml = ET.Element("roblox", version="4")
    assets, _ = item(xml, "Folder", "Assets")
    golem, _ = item(assets, "Folder", "Golem")
    # Every slot is authored around its attachment centre, in golem scale-1 studs.
    pieces = {"Head": (4, 3, 3.5), "Torso": (7, 7, 4.5),
              "LeftArm": (2.5, 7, 2.5), "RightArm": (2.5, 7, 2.5),
              "LeftLeg": (3, 5, 3), "RightLeg": (3, 5, 3)}
    tiers = [("stone", (128, 122, 110)), ("copper", (184, 108, 60)),
             ("iron", (150, 156, 166)), ("crystal", (150, 110, 255)),
             ("stormglass", (100, 190, 255)), ("abyssite", (55, 175, 160)),
             ("sunsteel", (255, 190, 70)), ("aether", (230, 170, 255))]
    for index, (tier, color) in enumerate(tiers):
        folder, _ = item(golem, "Folder", tier)
        for name, (x, y, z) in pieces.items():
            obj = model(folder, name)
            part(obj, "FacetedBody", (x*.9, y*.94, z*.92), (0, 0, 0), color)
            for side in (-1, 1):
                part(obj, "SidePlate", (x*.2, y*.65, z), (side*x*.4, 0, 0), lighter(color, -22), wedge=True)
            part(obj, "RuneInset", (x*.22, y*.24, .15), (0, y*.12, -z*.5), (120, 245, 255))
            if index >= 1:
                part(obj, "ForgedBand", (x*1.02, y*.12, z*1.02), (0, -y*.27, 0), lighter(color, 28))
            if index >= 2:
                for side in (-1, 1):
                    part(obj, "Rivet", (.18, .18, .16), (side*x*.3, y*.3, -z*.51), (250, 205, 100))
            if index >= 3:
                for side in (-1, 1):
                    part(obj, "CrystalCrest", (x*.2, y*.38, z*.35), (side*x*.25, y*.55, 0), lighter(color, 35), wedge=True)
    enemies, _ = item(assets, "Folder", "Enemies")
    # Boss meshes are normalised to one stud tall: EnemyModels scales to def.size.Y.
    for boss, color in [("boss1", (110, 100, 82)), ("boss2", (170, 65, 35)), ("boss3", (170, 190, 235)),
                        ("boss4", (95, 180, 235)), ("boss5", (55, 165, 150)), ("boss6", (245, 175, 60))]:
        obj = model(enemies, boss)
        if boss in ("boss1", "boss5", "boss6"):
            part(obj, "Torso", (.64, .46, .42), (0, .03, 0), color)
            part(obj, "Jaw", (.52, .2, .45), (0, .34, -.05), lighter(color, 25), wedge=True)
            for side in (-1, 1):
                part(obj, "Fist", (.25, .4, .3), (side*.45, -.03, 0), lighter(color, -20))
                part(obj, "Foot", (.23, .25, .35), (side*.2, -.32, 0), lighter(color, -30))
        elif boss == "boss2":
            part(obj, "Carapace", (.8, .35, .7), (0, -.02, .08), color, wedge=True)
            part(obj, "Chimney", (.35, .5, .28), (0, .26, .12), lighter(color, -30))
            for side in (-1, 1):
                for z in (-.25, .2):
                    part(obj, "CrawlerLeg", (.22, .45, .14), (side*.4, -.23, z), lighter(color, -15), wedge=True)
        else:
            part(obj, "Body", (.4, .35, .7), (0, -.04, .06), color)
            part(obj, "Head", (.26, .23, .32), (0, .23, -.3), lighter(color, 15))
            for side in (-1, 1):
                for z in (-.18, .3):
                    part(obj, "Leg", (.1, .35, .12), (side*.17, -.3, z), lighter(color, -35))
                part(obj, "Antler" if boss == "boss3" else "Wing", (.12 if boss == "boss3" else .65, .3, .16), (side*.25, .4, -.22), (180, 240, 255), wedge=True)
        for side in (-1, 1):
            part(obj, "Eye", (.07, .06, .02), (side*.09, .28, -.47), (125, 250, 255))
    props, _ = item(assets, "Folder", "Props")
    for name, color, shapes in [
        ("rock", (120, 115, 100), [((6, 3, 4), (0, 1.5, 0)), ((3, 2, 3), (1, 3, 0))]),
        ("basalt", (65, 55, 60), [((3, 8, 3), (0, 4, 0)), ((2, 5, 2), (2, 2.5, 1))]),
        ("crystalCluster", (155, 175, 245), [((2, 7, 2), (0, 3.5, 0)), ((1.5, 4, 1.5), (2, 2, 0)), ((1, 3, 1), (-1, 1.5, 1))])]:
        obj = model(props, name)
        for n, (size, pos) in enumerate(shapes):
            part(obj, f"Facet{n}", size, pos, lighter(color, n*15), wedge=True)
    out = ASSETS / "models" / "Assets.rbxmx"
    out.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(xml)
    ET.ElementTree(xml).write(out, encoding="utf-8", xml_declaration=True)


def build_audio():
    out = ASSETS / "audio"
    out.mkdir(parents=True, exist_ok=True)
    names = ["golemStep", "bossStep", "punch", "mine", "mineBreak", "enemyAttack", "defeat", "quake", "mend", "magnet", "slamWarn", "slam", "downed", "artifact", "levelUp", "grow", "click", "tutorialStep", "wind"]
    for index, name in enumerate(names):
        rng = random.Random(index)
        rate, duration = 22050, (2 if name == "wind" else .65)
        pcm = []
        for i in range(int(rate*duration)):
            t = i/rate
            if name == "wind":
                v = .12*rng.uniform(-1, 1) + .07*math.sin(2*math.pi*110*t)
                v *= math.sin(math.pi*t/duration)**2
            elif name in ("artifact", "levelUp", "mend", "tutorialStep"):
                note = min(3, int(t/.14))
                f = 440 * (1, 1.25, 1.5, 2)[note]
                v = .25*math.sin(2*math.pi*f*t)*math.exp(-4*(t % .14))*(1-t/duration)
            else:
                f = 55 + index*13
                v = (.4*math.sin(2*math.pi*(f*t + 20*t*t)) + .16*rng.uniform(-1, 1))*math.exp(-9*t)
            v *= min(1, t/.005, (duration-t)/.015)
            pcm.append(struct.pack("<h", int(max(-1, min(1, v))*32767)))
        with wave.open(str(out / f"{name}.wav"), "wb") as wav:
            wav.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            wav.writeframes(b"".join(pcm))


if __name__ == "__main__":
    build_models()
    build_audio()
    print("Wrote original model templates and 19 mono PCM sound files.")
