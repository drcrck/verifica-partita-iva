"""Genera icone, splash screen e grafiche Play Store di Partita IVA.

Ridisegno vettoriale dell'icona originale del 2014: bandiera UE con fabbrica.
Uso:  python tool/make_icons.py      (dalla cartella app/)
Poi:  dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

BLUE = (0, 51, 153, 255)  # Reflex Blue UE
YELLOW = (255, 204, 0, 255)
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
STORE = os.path.join(os.path.dirname(__file__), "..", "store")


def star(draw, cx, cy, r, fill):
    pts = []
    for i in range(10):
        rad = r if i % 2 == 0 else r * 0.381966
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    draw.polygon(pts, fill=fill)


def stars_ring(draw, cx, cy, R, r, fill):
    for k in range(12):
        a = -math.pi / 2 + k * math.pi / 6
        star(draw, cx + R * math.cos(a), cy + R * math.sin(a), r, fill)


def factory_mask(size, cx, cy, width):
    """Maschera (L) della fabbrica: 255 = pieno, 0 = vuoto (finestre, fuga)."""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    u = width / 100.0
    # Il disegno va da y=-10 (fumo) a y=100 (base): centrato in verticale.
    ox, oy = cx - 50 * u, cy - 45 * u

    def P(x, y):
        return (ox + x * u, oy + y * u)

    # Ciminiere
    d.rectangle([P(16, 4), P(28, 42)], fill=255)
    d.rectangle([P(53, 4), P(65, 40)], fill=255)
    # Corpo superiore con tetto a shed
    d.polygon([P(0, 61), P(0, 46), P(36, 31), P(38, 46), P(74, 31),
               P(76, 44), P(100, 44), P(100, 61)], fill=255)
    # Corpo inferiore
    d.rectangle([P(0, 65), P(100, 100)], fill=255)
    # Finestre
    for x in (9, 28, 47):
        d.rectangle([P(x, 72), P(x + 11, 89)], fill=0)
    # Fumo: due "tilde" sopra le ciminiere, disegnate come forma piena
    # (contorno della curva spostato di +/- metà spessore lungo la normale).
    for chx in (22, 59):
        n = 80
        half = 1.8  # metà spessore, in unità
        top, bot = [], []
        for i in range(n + 1):
            t = i / n
            x = chx - 10 + 20 * t
            y = -4 - 2.8 * math.sin(t * 2 * math.pi)
            dy = -2.8 * 2 * math.pi * math.cos(t * 2 * math.pi) / 20
            nx, ny = -dy / math.hypot(1, dy), 1 / math.hypot(1, dy)
            top.append(P(x + nx * half, y + ny * half))
            bot.append(P(x - nx * half, y - ny * half))
        d.polygon(top + bot[::-1], fill=255)
        for (x, y) in ((chx - 10, -4), (chx + 10, -4)):  # estremi arrotondati
            c = P(x, y)
            d.ellipse([c[0] - half * u, c[1] - half * u, c[0] + half * u, c[1] + half * u], fill=255)
    return m


def emblem(size, scale, fg_star=YELLOW, fg_factory=WHITE, bg=None):
    """Stelle + fabbrica. scale = raggio esterno dell'anello / lato."""
    S = size * SS
    img = Image.new("RGBA", (S, S), bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    r = S * scale * 0.14  # raggio stella
    R = S * scale - r  # raggio anello
    stars_ring(d, c, c, R, r, fg_star)
    fw = S * scale * 0.95  # larghezza fabbrica
    layer = Image.new("RGBA", (S, S), fg_factory)
    img.paste(layer, (0, 0), factory_mask(S, c, c + S * scale * 0.02, fw))
    return img.resize((size, size), Image.LANCZOS)


def save(img, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("ok", os.path.relpath(path), img.size)


def feature_graphic():
    W, H = 1024, 500
    S = SS
    img = Image.new("RGBA", (W * S, H * S), BLUE)
    em = emblem(H * S, 0.44)
    img.alpha_composite(em, (int(30 * S), 0))
    d = ImageDraw.Draw(img)
    fonts = "C:/Windows/Fonts/"
    bold = ImageFont.truetype(fonts + "segoeuib.ttf", 84 * S)
    reg = ImageFont.truetype(fonts + "segoeui.ttf", 34 * S)
    x = 530 * S
    d.text((x, 150 * S), "Partita IVA", font=bold, fill=WHITE)
    d.text((x, 270 * S), "Verifica VIES in tutta l'UE", font=reg, fill=YELLOW)
    d.text((x, 318 * S), "Codice fiscale · Lettura da foto", font=reg, fill=WHITE)
    d.text((x, 366 * S), "Ricevuta PDF · Cronologia", font=reg, fill=WHITE)
    return img.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    # Icona classica / iOS: a tutto campo come l'originale.
    save(emblem(1024, 0.47, bg=BLUE), OUT, "icon.png")
    # Icona adattiva Android: il contenuto deve stare nel cerchio sicuro (66%).
    save(emblem(1024, 0.32), OUT, "icon_foreground.png")
    # Icona tematica Android 13+: solo forma, il colore lo mette il sistema.
    save(emblem(1024, 0.32, fg_star=WHITE, fg_factory=WHITE), OUT, "icon_monochrome.png")
    # Splash (pre Android 12 e iOS): logo grande su fondo blu.
    save(emblem(1152, 0.48), OUT, "splash.png")
    # Splash Android 12+: il sistema ritaglia un cerchio di 2/3 del lato.
    save(emblem(1152, 0.32), OUT, "splash_android12.png")
    # Play Store
    save(emblem(512, 0.47, bg=BLUE).convert("RGB"), STORE, "icon-512.png")
    save(feature_graphic().convert("RGB"), STORE, "feature-1024x500.png")
