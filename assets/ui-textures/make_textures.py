"""Builds the tiling UI textures in this folder. They are original, made from
seeded noise and shapes, so we own them outright.

Run: python3 assets/ui-textures/make_textures.py  (needs numpy and Pillow)

Every texture is grayscale, light (45-100% brightness) and tiles
seamlessly. The game tints it with ImageColor3 and draws it faintly over the
panel's own color, so text stays readable. See docs/reference/ui-materials.md.
"""

import os

import numpy as np
from PIL import Image

SIZE = 256
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)


def periodic_noise(cells: int) -> np.ndarray:
    """Smooth value noise that wraps at the edges (bilinear over a cells x cells grid)."""
    grid = rng.random((cells, cells))
    fx = xx / SIZE * cells
    fy = yy / SIZE * cells
    x0 = np.floor(fx).astype(int) % cells
    y0 = np.floor(fy).astype(int) % cells
    x1 = (x0 + 1) % cells
    y1 = (y0 + 1) % cells
    tx = fx - np.floor(fx)
    ty = fy - np.floor(fy)
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    top = grid[y0, x0] * (1 - tx) + grid[y0, x1] * tx
    bottom = grid[y1, x0] * (1 - tx) + grid[y1, x1] * tx
    return top * (1 - ty) + bottom * ty


def fbm(*cells: int) -> np.ndarray:
    total = np.zeros((SIZE, SIZE))
    weight = 1.0
    norm = 0.0
    for c in cells:
        total += periodic_noise(c) * weight
        norm += weight
        weight *= 0.5
    return total / norm


def save(name: str, value: np.ndarray, low: float = 0.45, high: float = 1.0):
    v = np.clip(value, 0, 1)
    v = low + (high - low) * v
    Image.fromarray((v * 255).astype(np.uint8), "L").save(os.path.join(OUT, name + ".png"), optimize=True)


def wood() -> np.ndarray:
    # Horizontal planks, 64 px tall, with grain that wobbles along x.
    plank = SIZE // 4
    row = (yy // plank).astype(int)
    warp = fbm(4, 8) * 10
    grain = 0.5 + 0.5 * np.sin((yy + warp) / plank * 2 * np.pi * 6 + row * 1.7)
    streaks = fbm(2, 32)
    v = 0.55 + 0.25 * grain + 0.25 * streaks
    v += (row % 2) * 0.05 - 0.02  # planks differ slightly in tone
    seam = (yy % plank) < 2
    v[seam] = 0.15
    # Butt joints, staggered on each plank.
    for r in range(4):
        jx = int(rng.integers(0, SIZE))
        band = (row == r) & (np.abs(((xx - jx + SIZE / 2) % SIZE) - SIZE / 2) < 1.5)
        v[band] = 0.2
    return v


def stone() -> np.ndarray:
    # Offset blocks, 64 x 32 px, each a slightly different shade, with mortar.
    bw, bh = 64, 32
    row = (yy // bh).astype(int)
    shifted = (xx + (row % 2) * bw / 2) % SIZE
    col = (shifted // bw).astype(int)
    shade = rng.random((SIZE // bh, SIZE // bw))[row, col]
    speckle = fbm(16, 64)
    v = 0.5 + 0.22 * shade + 0.35 * speckle
    # Bevel: lighter top-left of each block, darker bottom-right.
    lx = shifted % bw
    ly = yy % bh
    v[(ly < 4) | (lx < 4)] += 0.12
    v[(ly > bh - 5) | (lx > bw - 5)] -= 0.12
    mortar = (ly < 2) | (lx < 2)
    v[mortar] = 0.1
    return v


def metal() -> np.ndarray:
    # Brushed steel: fine horizontal streaks plus a little broad shading.
    streak = rng.random(SIZE)[yy.astype(int)]
    along = fbm(2, 4)
    v = 0.55 + 0.25 * streak + 0.2 * along
    return v


def studs() -> np.ndarray:
    # Classic building-brick studs on a 32 px grid, lit from the top left.
    cell = 32
    cx = (xx % cell) - cell / 2 + 0.5
    cy = (yy % cell) - cell / 2 + 0.5
    r = np.sqrt(cx * cx + cy * cy)
    v = np.full((SIZE, SIZE), 0.62)
    shadow = np.sqrt((cx - 2) ** 2 + (cy - 2) ** 2) < 10
    v[shadow] = 0.35
    top = r < 10
    light = 0.75 - (cx + cy) / 40
    v[top] = 0.6 + light[top] * 0.5
    v[(r >= 8.5) & (r < 10) & top] -= 0.1  # rim
    return v


def crystal() -> np.ndarray:
    # Faceted gem: wrapped Voronoi cells, each facet a flat shade with a bright edge.
    count = 28
    px = rng.random(count) * SIZE
    py = rng.random(count) * SIZE
    shade = rng.random(count)
    best = np.full((SIZE, SIZE), 1e9)
    second = np.full((SIZE, SIZE), 1e9)
    owner = np.zeros((SIZE, SIZE), int)
    for i in range(count):
        dx = np.abs(xx - px[i])
        dy = np.abs(yy - py[i])
        dx = np.minimum(dx, SIZE - dx)
        dy = np.minimum(dy, SIZE - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        owner = np.where(closer, i, owner)
        best = np.minimum(best, d)
    v = 0.45 + 0.45 * shade[owner]
    v[(second - best) < 2.5] = 1.0
    return v


if __name__ == "__main__":
    save("wood", wood())
    save("stone", stone())
    save("metal", metal())
    save("studs", studs())
    save("crystal", crystal())
    print("wrote", ", ".join(n + ".png" for n in ["wood", "stone", "metal", "studs", "crystal"]))
