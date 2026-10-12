"""Generate the ground and wall textures (with normal maps) for every kind of area.

Run from the project root:  python3 tools/gen_textures.py
Writes textures/<name>_albedo.png and <name>_normal.png for:
  floor (crypt stone), grass, heath, dirt, cobble, cave, flags (abbey floor): 4 variants side by side
  wall (brick), rock (cave wall), wood (palisade): a face and a cap side by side
Stone stays fairly neutral and is tinted per area in code; outdoor ground has its own colour.
"""
import numpy as np
from PIL import Image

rng = np.random.default_rng(7)
S = 128


def fbm(size, octaves=5, base=4):
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        grid = rng.random((n, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        out += np.asarray(img, dtype=float) / 255 * amp
        total += amp
        amp *= 0.5
    return out / total


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def normal_map(h, strength=3.0):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def crack(h, alb, length=60):
    x, y = rng.uniform(10, S - 10, 2)
    a = rng.uniform(0, np.pi * 2)
    for _ in range(length):
        a += rng.normal(0, 0.35)
        x, y = x + np.cos(a), y + np.sin(a)
        if not (1 <= x < S - 1 and 1 <= y < S - 1):
            break
        xi, yi = int(x), int(y)
        h[yi, xi] -= 0.35
        alb[yi, xi] *= 0.45
        h[yi, xi + 1] -= 0.12


def floor_tile(kind):
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    n_pts = rng.integers(5, 9)
    pts = rng.uniform(0, S, (n_pts, 2))
    d = np.stack([np.hypot(xx - px, yy - py) for px, py in pts])
    order = np.sort(d, axis=0)
    owner = np.argmin(d, axis=0)
    edge = order[1] - order[0]
    border = np.minimum.reduce([xx, yy, S - 1 - xx, S - 1 - yy])
    stone_tone = rng.uniform(0.8, 1.15, n_pts)[owner]
    noise = fbm(S, 5, 4)
    fine = fbm(S, 3, 32)
    h = smoothstep(0, 7, edge) * smoothstep(0, 5, border) * (0.75 + 0.25 * stone_tone) + noise * 0.25 + fine * 0.08
    alb = (0.42 + noise * 0.18 + fine * 0.1) * stone_tone
    mortar = 1 - smoothstep(0, 3, np.minimum(edge, border * 1.5))
    alb = alb * (1 - mortar * 0.6)
    if kind >= 2:
        for _ in range(rng.integers(1, 3)):
            crack(h, alb)
    if kind == 3:  # scattered grit and pebbles
        for _ in range(25):
            px, py, r = rng.uniform(0, S), rng.uniform(0, S), rng.uniform(1, 3)
            m = np.hypot(xx - px, yy - py) < r
            h[m] += 0.25
            alb[m] *= 0.8
    rgb = np.dstack([alb * 1.0, alb * 0.94, alb * 0.86])
    return np.clip(rgb, 0, 1), h


def brick_face():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    rows = 5
    bh = S / rows
    h = np.zeros((S, S))
    alb = np.zeros((S, S))
    noise = fbm(S, 5, 4)
    fine = fbm(S, 3, 32)
    for r in range(rows):
        bw = S / 2.5
        off = (r % 2) * bw / 2
        y0 = r * bh
        for c in range(-1, 4):
            x0 = c * bw + off
            inside = (xx >= x0) & (xx < x0 + bw) & (yy >= y0) & (yy < y0 + bh)
            ex = np.minimum(xx - x0, x0 + bw - xx)
            ey = np.minimum(yy - y0, y0 + bh - yy)
            e = np.minimum(ex, ey)
            tone = rng.uniform(0.75, 1.15)
            h = np.where(inside, smoothstep(0, 4, e) * (0.8 + 0.2 * tone), h)
            alb = np.where(inside, (0.4 + 0.1 * tone) * (0.55 + 0.45 * smoothstep(0, 3, e)), alb)
    h += noise * 0.2 + fine * 0.1
    alb *= 0.85 + noise * 0.3
    for _ in range(3):
        crack(h, alb, 30)
    rgb = np.dstack([alb, alb * 0.93, alb * 0.85])
    return np.clip(rgb, 0, 1), h


def cap_stone():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    border = np.minimum.reduce([xx, yy, S - 1 - xx, S - 1 - yy])
    noise = fbm(S, 5, 3)
    h = smoothstep(0, 14, border) + noise * 0.3
    alb = (0.5 + noise * 0.2) * (0.6 + 0.4 * smoothstep(0, 6, border))
    rgb = np.dstack([alb, alb * 0.95, alb * 0.88])
    return np.clip(rgb, 0, 1), h


def save(tiles, name):
    alb = np.hstack([t[0] for t in tiles])
    nrm = np.hstack([normal_map(t[1]) for t in tiles])
    Image.fromarray((alb * 255).astype(np.uint8)).save(f"textures/{name}_albedo.png")
    Image.fromarray(nrm).save(f"textures/{name}_normal.png")


def blob_noise(k, base):
    return fbm(S, 5, base)


def grass_tile(k, dry=False):
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    n = fbm(S, 5, 4)
    fine = fbm(S, 3, 32)
    h = n * 0.4 + fine * 0.3
    # blades: short dark/bright streaks
    alb_g = 0.32 + n * 0.25 + fine * 0.15
    for _ in range(420):
        x, y = rng.uniform(0, S, 2)
        l = rng.uniform(3, 7)
        a = rng.uniform(-0.5, 0.5) - np.pi / 2
        b = rng.uniform(0.7, 1.35)
        for t in np.linspace(0, l, 8):
            xi, yi = int(x + np.cos(a) * t) % S, int(y + np.sin(a) * t) % S
            alb_g[yi, xi] *= b
            h[yi, xi] += 0.08 * b
    dirt = smoothstep(0.62, 0.75, blob_noise(k, 3)) if k >= 2 else np.zeros((S, S))
    if dry:
        g = np.dstack([alb_g * 0.95, alb_g * 0.85, alb_g * 0.5])
    else:
        g = np.dstack([alb_g * 0.6, alb_g * 0.7, alb_g * 0.42])
    d = np.dstack([0.42 + n * 0.2, 0.33 + n * 0.15, 0.22 + n * 0.1])
    rgb = g * (1 - dirt[..., None]) + d * dirt[..., None]
    if k == 3:
        for _ in range(4):
            px, py, r = rng.uniform(10, S - 10), rng.uniform(10, S - 10), rng.uniform(3, 6)
            m = np.hypot(xx - px, yy - py) < r
            h[m] += 0.4
            rgb[m] = rgb[m] * 0.3 + np.array([0.45, 0.43, 0.4]) * 0.7
    return np.clip(rgb, 0, 1), h


def dirt_tile(k):
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    n = fbm(S, 5, 4)
    fine = fbm(S, 3, 32)
    h = n * 0.5 + fine * 0.25
    alb = 0.4 + n * 0.22 + fine * 0.1
    rgb = np.dstack([alb * 1.0, alb * 0.8, alb * 0.58])
    for _ in range(30 + k * 15):
        px, py, r = rng.uniform(0, S), rng.uniform(0, S), rng.uniform(0.8, 2.4)
        m = np.hypot(xx - px, yy - py) < r
        h[m] += 0.3
        rgb[m] *= rng.uniform(0.7, 1.25)
    if k >= 2:  # cart ruts
        off = rng.uniform(30, 90)
        for d in (0, 22):
            m = np.abs(yy - (off + d) - np.sin(xx / 20) * 3) < 3
            h[m] -= 0.3
            rgb[m] *= 0.8
    return np.clip(rgb, 0, 1), h


def cobble_tile(k):
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    n_pts = 22 + k * 3
    pts = rng.uniform(0, S, (n_pts, 2))
    # tile seamlessly: include wrapped copies
    allp = np.concatenate([pts + [dx, dy] for dx in (-S, 0, S) for dy in (-S, 0, S)])
    d = np.stack([np.hypot(xx - px, yy - py) for px, py in allp])
    order = np.sort(d, axis=0)
    owner = np.argmin(d, axis=0) % n_pts
    edge = order[1] - order[0]
    tone = rng.uniform(0.75, 1.2, n_pts)[owner]
    n = fbm(S, 4, 8)
    h = smoothstep(0, 5, edge) * (0.8 + 0.2 * tone) + n * 0.15
    alb = (0.42 + n * 0.15) * tone * (0.45 + 0.55 * smoothstep(0, 3, edge))
    moss = smoothstep(0.6, 0.7, fbm(S, 4, 4)) * (1 - smoothstep(0, 3, edge))
    rgb = np.dstack([alb * 0.98, alb * 0.95, alb * 0.9])
    rgb = rgb * (1 - moss[..., None]) + np.dstack([alb * 0.5, alb * 0.75, alb * 0.35]) * moss[..., None]
    return np.clip(rgb, 0, 1), h


def cave_tile(k):
    n = fbm(S, 6, 3)
    fine = fbm(S, 3, 24)
    h = n * 0.8 + fine * 0.2
    alb = 0.36 + n * 0.25 + fine * 0.08
    if k >= 1:
        for _ in range(k):
            crack(h, alb, 50)
    rgb = np.dstack([alb * 1.0, alb * 0.9, alb * 0.78])
    return np.clip(rgb, 0, 1), h


def flag_tile(k):
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    cell = S / 2
    ex = np.minimum(xx % cell, cell - xx % cell)
    ey = np.minimum(yy % cell, cell - yy % cell)
    e = np.minimum(ex, ey)
    n = fbm(S, 5, 4)
    checker = ((xx // cell + yy // cell) % 2)
    tone = np.where(checker == 0, 0.48, 0.36)
    h = smoothstep(0, 4, e) + n * 0.2
    alb = (tone + n * 0.12) * (0.5 + 0.5 * smoothstep(0, 3, e))
    if k >= 2:
        crack(h, alb, 40)
    rgb = np.dstack([alb * 1.0, alb * 0.9, alb * 0.82])
    return np.clip(rgb, 0, 1), h


def rock_face():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    n = fbm(S, 6, 3)
    strata = np.sin(yy / 7 + n * 6) * 0.5 + 0.5
    h = n * 0.9 + strata * 0.25
    alb = 0.32 + n * 0.25 + strata * 0.06
    for _ in range(3):
        crack(h, alb, 50)
    rgb = np.dstack([alb, alb * 0.9, alb * 0.78])
    return np.clip(rgb, 0, 1), h


def rock_cap():
    n = fbm(S, 6, 3)
    h = n
    alb = 0.38 + n * 0.25
    rgb = np.dstack([alb, alb * 0.92, alb * 0.82])
    return np.clip(rgb, 0, 1), h


def log_face():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    logs = 6
    w = S / logs
    u = (xx % w) / w
    rnd = fbm(S, 3, 32)
    grain = np.sin(yy / 2.5 + fbm(S, 4, 4) * 10) * 0.5 + 0.5
    h = np.sqrt(np.clip(1 - (u * 2 - 1) ** 2, 0, 1)) + grain * 0.1
    alb = (0.3 + grain * 0.08 + rnd * 0.1) * (0.5 + 0.5 * h)
    rgb = np.dstack([alb * 1.1, alb * 0.85, alb * 0.6])
    return np.clip(rgb, 0, 1), h


def log_cap():
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    logs = 6
    w = S / logs
    c = (xx % w) - w / 2
    rings = np.sin(np.hypot(c, (yy % w) - w / 2) * 1.6) * 0.5 + 0.5
    h = rings * 0.3
    alb = 0.38 + rings * 0.12
    rgb = np.dstack([alb * 1.1, alb * 0.9, alb * 0.65])
    return np.clip(rgb, 0, 1), h


save([floor_tile(k) for k in range(4)], "floor")
save([brick_face(), cap_stone()], "wall")
save([grass_tile(k) for k in range(4)], "grass")
save([grass_tile(k, True) for k in range(4)], "heath")
save([dirt_tile(k) for k in range(4)], "dirt")
save([cobble_tile(k) for k in range(4)], "cobble")
save([cave_tile(k) for k in range(4)], "cave")
save([flag_tile(k) for k in range(4)], "flags")
save([rock_face(), rock_cap()], "rock")
save([log_face(), log_cap()], "wood")
print("textures written")
