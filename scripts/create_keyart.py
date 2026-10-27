#!/usr/bin/env python3
"""Original vector key-art drafts. These are illustrations, not gameplay captures.
Optionally render PNGs with cairosvg; no external art, fonts or images are loaded.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'keyart'
OUT.mkdir(parents=True, exist_ok=True)


def golem(x, y, scale=1, color='#7f9571', rider=True):
    return f'''<g transform="translate({x} {y}) scale({scale})">
<path d="M-105 40L-150 185H-74L-40 90M105 40L150 185H74L40 90" fill="#58645c"/>
<path d="M-110-185L110-185L130 55L-130 55Z" fill="{color}"/>
<path d="M-110-185L-65-160L-75 25L-130 55Z" fill="#536d61"/>
<path d="M-190-170L-130-190L-115-10L-195 30L-225-25Z" fill="{color}"/>
<path d="M190-170L130-190L115-10L195 30L225-25Z" fill="{color}"/>
<path d="M-90-325L75-325L100-220L60-180H-80L-110-230Z" fill="{color}"/>
<path d="M-90-325L-55-290L-65-210L-110-230Z" fill="#536d61"/>
<path d="M-70-280H-20V-260H-70ZM20-280H70V-260H20Z" fill="#adffdf"/>
<path d="M-43-235H43L25-218H-25Z" fill="#334b44"/>
<path d="M0-145L40-100L0-55L-40-100Z" fill="#adffdf"/>
<path d="M0-130L25-100L0-70L-25-100Z" fill="#48bdae"/>
{('<g transform="translate(142 -218)"><circle cy="-35" r="21" fill="#f2c39f"/><path d="M-27-45L0-115L38-45Z" fill="#7d75de"/><path d="M-22-10L22-10L34 50H-36Z" fill="#7d75de"/><path d="M23 10L55-15" stroke="#f2c39f" stroke-width="12"/><path d="M55 15V-90" stroke="#d7ae70" stroke-width="8"/><path d="M55-110L70-90L55-70L40-90Z" fill="#affff2"/></g>' if rider else '')}
</g>'''


def svg(width, height, body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#255084"/><stop offset="1" stop-color="#92e1d1"/></linearGradient></defs>
<rect width="100%" height="100%" fill="url(#sky)"/>{body}</svg>'''


for name, color in [('icon-a', '#7f9571'), ('icon-b', '#b394dd')]:
    body = '<circle cx="256" cy="230" r="210" fill="#ebcc77"/>'
    body += golem(245, 390, 1.1, color)
    content = svg(512, 512, body)
    (OUT / (name + '.svg')).write_text(content)
for name, color, mode in [('ride', '#7f9571', 'ride'), ('boss', '#8992c2', 'boss'), ('party', '#b7966d', 'party')]:
    body = '<circle cx="1520" cy="230" r="140" fill="#ffe2a0"/>'
    body += '<path d="M0 790L580 640L1300 690L1920 800L1600 930L400 940Z" fill="#79a46a"/><path d="M400 940L800 1080L1600 930Z" fill="#596d70"/>'
    body += '<path d="M60 480h450M1410 500h460M80 340h300" stroke="#e6faf3" stroke-width="65" stroke-linecap="round"/>'
    body += golem(820, 800, 1.65, color)
    if mode == 'boss':
        body += '<ellipse cx="1450" cy="860" rx="320" ry="90" fill="none" stroke="#ffba84" stroke-width="15"/>'
        body += golem(1450, 730, 1.4, '#7a6974', False)
    if mode == 'party':
        body += golem(1430, 810, 1.05, '#b394dd') + golem(350, 805, .9, '#75a9b9')
    body += '<g fill="#b6f1e5"><path d="M1540 820L1590 650L1640 820Z"/><path d="M1660 840L1700 720L1750 840Z"/></g>'
    (OUT / f'thumbnail-{name}.svg').write_text(svg(1920, 1080, body))
try:
    import cairosvg
except ImportError:
    print('Created SVG sources. Install cairosvg to rasterise optional PNGs.')
else:
    for path in OUT.glob('*.svg'):
        cairosvg.svg2png(url=str(path), write_to=str(path.with_suffix('.png')))
    print('Created two 512px icons and three 1920x1080 illustration drafts (SVG + PNG).')
