#!/usr/bin/env python3
"""Original vector key-art drafts for the game page (#16, roadmap R3.9).

These are illustrations in the game's low-poly style, not gameplay captures.
Everything is drawn here from plain shapes: no external art, fonts or images.
Renders PNGs with cairosvg if installed, otherwise with Playwright's Chromium.

Outputs in assets/keyart/:
  icon-a, icon-b             512x512 icons, face first so they read at 48 px
  thumbnail-ride             a wizard rides a golem across a floating island
  thumbnail-boss             a golem dodges Old Rockjaw's ground slam
  thumbnail-party            three friends' golems explore together
  thumbnail-giant            a starter golem beside the titan it grows into
"""
import shutil
import subprocess
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'keyart'
OUT.mkdir(parents=True, exist_ok=True)

INK = '#1d2633'  # outline, so shapes stay readable when the image is tiny

# Golem palettes: base, light face, shadow face, glow (eyes and core).
STONE = ('#8b8f7a', '#b3b69c', '#5f6455', '#7dfbe0')
COPPER = ('#c4733f', '#e69a5f', '#8a4a27', '#ffe27a')
IRON = ('#8f9aab', '#bcc6d4', '#5e687a', '#8fd8ff')
CRYSTAL = ('#9a72ff', '#c6adff', '#6643c9', '#b8fff6')


def poly(points, fill, stroke=True, extra=''):
    pts = ' '.join(f'{x},{y}' for x, y in points)
    line = f' stroke="{INK}" stroke-width="7" stroke-linejoin="round"' if stroke else ''
    return f'<polygon points="{pts}" fill="{fill}"{line}{extra}/>'


def mirror(points):
    return [(-x, y) for x, y in points]


def wizard(x, y, s=1.0):
    """The rider: robe, hat and a staff with a glowing tip. Feet at (x, y)."""
    return f'''<g transform="translate({x} {y}) scale({s})">
{poly([(-38, 0), (38, 0), (22, -70), (-22, -70)], '#6f5fe0')}
{poly([(-22, -70), (22, -70), (10, -40), (-10, -40)], '#5446bf', False)}
<circle cx="0" cy="-88" r="22" fill="#f2c39f" stroke="{INK}" stroke-width="6"/>
{poly([(-36, -100), (36, -100), (6, -170), (-2, -168)], '#6f5fe0')}
{poly([(-36, -100), (36, -100), (30, -112), (-30, -112)], '#ffd25e')}
<path d="M24 -50 L58 -78" stroke="#f2c39f" stroke-width="13" stroke-linecap="round"/>
<path d="M60 0 V-150" stroke="#8a5a32" stroke-width="10" stroke-linecap="round"/>
<g filter="url(#glow)">{poly([(60, -190), (78, -160), (60, -132), (42, -160)], '#aefcff')}</g>
</g>'''


def golem(x, y, s, pal, rider=True):
    """A faceted golem standing with its feet at (x, y)."""
    base, light, dark, glow = pal
    parts = []
    for side in (1, -1):
        f = (lambda p: p) if side == 1 else mirror
        shade = light if side == 1 else dark
        parts.append(poly(f([(-100, -160), (-28, -160), (-22, -30), (-112, -30)]), base))
        parts.append(poly(f([(-135, -38), (-12, -38), (-6, 0), (-142, 0)]), shade))
    # torso with a lit left face and a shadowed lower right face
    parts.append(poly([(-155, -410), (155, -410), (178, -265), (125, -145), (-125, -145), (-178, -265)], base))
    parts.append(poly([(-155, -410), (10, -410), (-45, -290), (-178, -265)], light, False))
    parts.append(poly([(178, -265), (125, -145), (15, -145), (70, -270)], dark, False))
    parts.append(poly([(-155, -410), (155, -410), (178, -265), (125, -145), (-125, -145), (-178, -265)], 'none'))
    parts.append(f'<g filter="url(#glow)">{poly([(0, -340), (34, -290), (0, -240), (-34, -290)], glow)}</g>')
    # arms: shoulder boulder, forearm, fist
    for side in (1, -1):
        f = (lambda p: p) if side == 1 else mirror
        shade = light if side == 1 else dark
        parts.append(poly(f([(-252, -440), (-150, -432), (-138, -340), (-250, -320)]), shade))
        parts.append(poly(f([(-245, -330), (-150, -345), (-162, -205), (-236, -195)]), base))
        parts.append(poly(f([(-268, -210), (-138, -212), (-140, -105), (-262, -98)]), shade))
    # head: brow ridge over glowing eye slits
    parts.append(poly([(-92, -560), (92, -560), (114, -478), (78, -420), (-78, -420), (-114, -478)], base))
    parts.append(poly([(-92, -560), (30, -560), (-30, -500), (-114, -478)], light, False))
    parts.append(poly([(-92, -560), (92, -560), (114, -478), (78, -420), (-78, -420), (-114, -478)], 'none'))
    parts.append(poly([(-106, -510), (106, -510), (96, -484), (-96, -484)], dark))
    parts.append(f'<g filter="url(#glow)"><rect x="-70" y="-480" width="50" height="18" rx="4" fill="{glow}"/>'
                 f'<rect x="20" y="-480" width="50" height="18" rx="4" fill="{glow}"/></g>')
    parts.append(poly([(-34, -446), (34, -446), (24, -434), (-24, -434)], INK, False))
    if rider:
        parts.append(wizard(195, -428, 0.95))
    return f'<g transform="translate({x} {y}) scale({s})">{"".join(parts)}</g>'


def rockjaw(x, y, s):
    """Old Rockjaw, zone 1's boss: a knuckle-walking boulder with a heavy jaw.
    Faces left. Feet at (x, y)."""
    stone, light, dark, moss = '#7d7466', '#a39886', '#544d44', '#6fae4c'
    p = [
        poly([(70, -150), (200, -150), (215, 0), (60, 0)], dark),
        poly([(-230, -400), (120, -440), (270, -310), (250, -130), (-170, -115), (-275, -250)], stone),
        poly([(-230, -400), (120, -440), (40, -330), (-275, -250)], light, False),
        poly([(270, -310), (250, -130), (60, -125), (120, -280)], dark, False),
        poly([(-230, -400), (120, -440), (270, -310), (250, -130), (-170, -115), (-275, -250)], 'none'),
        poly([(-215, -392), (118, -432), (220, -370), (70, -350), (-60, -372), (-140, -340)], moss),
        poly([(-320, -240), (-60, -210), (-85, -88), (-305, -118)], dark),
    ]
    teeth = ''.join(poly([(tx, -232 + i * 3), (tx + 26, -228 + i * 3), (tx + 13, -262 + i * 3)], '#f3ecd6')
                    for i, tx in enumerate((-300, -250, -200, -150, -100)))
    p.append(teeth)
    p.append(f'<g filter="url(#glow)"><circle cx="-220" cy="-300" r="15" fill="#ffc34d"/>'
             f'<circle cx="-140" cy="-312" r="15" fill="#ffc34d"/></g>')
    # the slamming arm, raised overhead
    p.append(poly([(-215, -360), (-115, -372), (-205, -585), (-300, -560)], stone))
    p.append(poly([(-345, -660), (-180, -672), (-168, -555), (-335, -540)], light))
    p.append(poly([(-40, -110), (90, -110), (95, 0), (-55, 0)], stone))
    return f'<g transform="translate({x} {y}) scale({s})">{"".join(p)}</g>'


def island(cx, top, w, grass='#7cc25a', cliff='#6d6a7d'):
    """A floating island: grass top with a faceted rock underside."""
    hw = w / 2
    return (poly([(cx - hw, top), (cx - hw * 0.6, top + w * 0.28), (cx - hw * 0.15, top + w * 0.5),
                  (cx + hw * 0.3, top + w * 0.36), (cx + hw, top)], cliff)
            + poly([(cx - hw * 0.15, top + w * 0.5), (cx + hw * 0.3, top + w * 0.36), (cx + hw, top),
                    (cx + hw * 0.2, top + w * 0.08)], '#4e4b5f', False)
            + f'<ellipse cx="{cx}" cy="{top}" rx="{hw + 6}" ry="{w * 0.09}" fill="{grass}" stroke="{INK}" stroke-width="7"/>'
            + f'<ellipse cx="{cx - hw * 0.15}" cy="{top - w * 0.012}" rx="{hw * 0.7}" ry="{w * 0.05}" fill="#97d873"/>')


def crystal_cluster(x, y, s=1.0, color='#8ef0ff'):
    shards = ''.join(poly([(dx - 18, 0), (dx + 18, 0), (dx + 6 * lean, -h), (dx - 6 + 6 * lean, -h + 10)], color)
                     for dx, h, lean in ((-30, 90, -1), (0, 140, 0), (34, 100, 1)))
    return f'<g transform="translate({x} {y}) scale({s})" filter="url(#glow)">{shards}</g>'


def cloud(x, y, s=1.0):
    return (f'<g transform="translate({x} {y}) scale({s})" fill="#f3fbff" opacity="0.92">'
            '<ellipse cx="0" cy="0" rx="110" ry="42"/><ellipse cx="-70" cy="10" rx="70" ry="32"/>'
            '<ellipse cx="80" cy="12" rx="80" ry="30"/><ellipse cx="10" cy="-30" rx="60" ry="40"/></g>')


def svg(width, height, sky, body):
    top, bottom = sky
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
<radialGradient id="sun"><stop offset="0" stop-color="#fff3c4"/><stop offset="0.6" stop-color="#ffd877"/><stop offset="1" stop-color="#ffd877" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>
<rect width="100%" height="100%" fill="url(#sky)"/>{body}</svg>'''


def write(name, content):
    (OUT / f'{name}.svg').write_text(content)


DAY = ('#3d7fd6', '#a9e8ff')
DUSK = ('#3b2f7a', '#ff9f6b')

# Icons: the golem's face fills the frame; the rider peeks over the shoulder.
for name, pal, sky in (('icon-a', STONE, ('#2f8be0', '#8fe3ff')), ('icon-b', CRYSTAL, ('#ff9a4d', '#ffd36b'))):
    body = '<circle cx="256" cy="200" r="250" fill="url(#sun)"/>'
    body += golem(236, 690, 1.0, pal)
    write(name, svg(512, 512, sky, body))

# Ride: the core fantasy. A wizard on the shoulder, crystals to mine.
body = '<circle cx="1560" cy="220" r="260" fill="url(#sun)"/>'
body += cloud(260, 230, 1.3) + cloud(1300, 420, 0.9) + cloud(1720, 640, 1.1)
body += island(1600, 560, 380, '#7cc25a') + island(260, 640, 300, '#a0d36a')
body += island(960, 820, 1500)
body += crystal_cluster(1330, 860, 1.2) + crystal_cluster(1500, 880, 0.8, '#ffb3f0')
body += golem(820, 940, 1.3, STONE)
write('thumbnail-ride', svg(1920, 1080, DAY, body))

# Boss: Old Rockjaw winds up a slam; the warning ring shows where it lands.
body = '<circle cx="380" cy="200" r="240" fill="url(#sun)"/>'
body += cloud(1600, 180, 1.2) + cloud(300, 520, 0.8)
body += island(960, 800, 1700, '#8bbf5c')
body += '<ellipse cx="820" cy="900" rx="330" ry="80" fill="#ff7a3d" fill-opacity="0.3" stroke="#ff7a3d" stroke-width="12" stroke-dasharray="40 22"/>'
body += rockjaw(1470, 900, 1.2)
body += golem(560, 940, 1.05, COPPER)
body += ''.join(poly([(px, py), (px + 30, py - 8), (px + 22, py + 22)], '#a39886') for px, py in ((1000, 330), (1060, 270), (1130, 360)))
write('thumbnail-boss', svg(1920, 1080, DUSK, body))

# Party: three friends' golems in different forge tiers.
body = '<circle cx="960" cy="180" r="230" fill="url(#sun)"/>'
body += cloud(240, 200, 1.1) + cloud(1680, 260, 1.2)
body += island(960, 800, 1800, '#7cc25a')
body += golem(420, 900, 0.95, IRON) + golem(1500, 900, 0.95, CRYSTAL) + golem(960, 960, 1.15, COPPER)
write('thumbnail-party', svg(1920, 1080, DAY, body))

# Giant: the growth promise. A starter golem beside its grown-up self.
body = '<circle cx="1450" cy="300" r="300" fill="url(#sun)"/>'
body += cloud(300, 260, 1.2) + cloud(1750, 560, 0.9)
body += island(960, 860, 1800, '#7cc25a')
body += golem(1180, 960, 1.55, CRYSTAL)
body += golem(480, 960, 0.5, STONE)
body += '<path d="M600 700 C 700 560, 820 520, 900 520" fill="none" stroke="#ffffff" stroke-width="14" stroke-linecap="round" stroke-dasharray="4 30"/>'
body += poly([(890, 495), (940, 522), (888, 548)], '#ffffff', False)
write('thumbnail-giant', svg(1920, 1080, DUSK, body))


def render():
    svgs = sorted(OUT.glob('*.svg'))
    try:
        import cairosvg
    except ImportError:
        cairosvg = None
    if cairosvg:
        for path in svgs:
            cairosvg.svg2png(url=str(path), write_to=str(path.with_suffix('.png')))
        return True
    if not shutil.which('node'):
        return False
    script = '''
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  for (const f of process.argv.slice(1)) {
    const m = require('fs').readFileSync(f, 'utf8').match(/width="(\\d+)" height="(\\d+)"/);
    const p = await b.newPage({ viewport: { width: +m[1], height: +m[2] } });
    await p.goto('file://' + f);
    await p.screenshot({ path: f.replace(/\\.svg$/, '.png') });
    await p.close();
  }
  await b.close();
})();'''
    result = subprocess.run(['node', '-e', script, *map(str, svgs)])
    return result.returncode == 0


if render():
    print('Created two 512px icons and four 1920x1080 illustration drafts (SVG + PNG).')
else:
    print('Created SVG sources. Install cairosvg or Playwright to render PNGs.')
