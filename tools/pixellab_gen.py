"""PixelLab API ile harita binası (map object) üretir ve indirir.

Çalıştırma (proje klasöründen):  python tools/pixellab_gen.py ev [market gym ...]
Anahtar: proje klasöründeki .pixellab_key dosyası (git'e girmez).
Çıktı: assets/pixellab/map/<ad>.png, arabalar (car_<id>) assets/pixellab/cars/  (şeffaf arka planlı, low top-down)
Her çağrı hesaptan üretim hakkı harcar; aynı ad zaten indirildiyse tekrar üretilmez (--force ile üretilir).
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "pixellab", "map")
API = "https://api.pixellab.ai/v2"
STYLE = ", cozy pixel art, Stardew Valley style, warm colors, clean dark outlines, Istanbul neighborhood"

PROMPTS = {
    "ev": "modest old 4-story Istanbul apartment block for students, worn beige plaster with damp stains, flat roof with satellite dishes and a water tank, small narrow balconies with laundry hanging, plain aluminum windows, simple metal entrance door, cheap and slightly run-down",
    "market": "small corner grocery store, flat roof with AC units, green and white striped awning, big shop window with colorful products, glass door, fruit crates outside",
    "gym": "neighborhood boxing gym, curved corrugated metal roof, dark blue walls, wide window strip, yellow sign board above glass entrance",
    "galeri": "used car dealership showroom, large glass front showing cars inside, colorful bunting flags on flat roof, yellow sign band",
    "carsi": "row of three small shops side by side, each with different colored striped awning, shop windows, flat roofs",
    "durak": "modern bus stop shelter, red and white roof, glass back panel with advertisement, metal bench, bus stop sign pole",
    "eef": "3-story university faculty building, navy blue walls, grid of windows, flat roof with AC units, columned entrance canopy",
    "mak": "3-story university faculty building, red brick walls, grid of windows, flat roof with AC units, columned entrance canopy",
    "fen": "3-story university faculty building, teal walls, grid of windows, flat roof with AC units, columned entrance canopy",
    "yemekhane": "university cafeteria building, red brick walls, large windows, flat roof with ventilation chimneys, double glass doors",
    "kampus_kafe": "small wooden campus cafe, warm lit windows, brown tiled roof, outdoor terrace with three colorful umbrellas",
    "kisla": "historic Ottoman military barracks, sandstone facade, arched windows, red tiled roof, central clock tower with arched gate",
    "kapi": "university entrance gate, two stone pillars, arch with dark blue sign board on top",
    "metrobus": "long articulated white Istanbul metrobus city bus with red stripe and accordion joint in the middle, seen from the side, facing right",
}
CAR_FRONT = ("front view of a {} parked facing the viewer, symmetrical, headlights and grille visible, "
             "clean shiny paint, no text, no logo")
for _id, _desc in {
    "sahin": "boxy old beige 1990s Turkish sedan car (Tofas Sahin)",
    "toros": "old white 1990s Renault 12 Toros sedan car",
    "doblo": "white Fiat Doblo small boxy van",
    "egea": "red modern compact sedan car (Fiat Egea)",
    "passat": "dark blue Volkswagen Passat sedan car",
    "golf": "light grey Volkswagen Golf GTI hatchback with red grille stripe",
    "bmw": "black BMW 3 series sports sedan with kidney grille",
    "mercedes": "silver Mercedes C-class luxury sedan",
}.items():
    PROMPTS["car_" + _id] = CAR_FRONT.format(_desc)
PROMPTS.update({   # silahlar (yandan, sağa bakar) ve çarşıdaki büst
    "weapon_musta": "golden brass knuckles weapon, side view, single item, shiny metal",
    "weapon_sopa": "wooden baseball bat lying horizontally pointing right, black grip tape on handle, side view, single item",
    "weapon_bicak": "folding pocket knife with steel blade pointing right and dark wooden handle, side view, single item",
    "messi_bust": "statue bust of a bearded football legend with short brown hair, painted, wearing the Argentina national team jersey with light blue and white vertical stripes, on a wide grey stone pedestal with a large blank golden plaque on the front",
})
SIZES = {"metrobus": (128, 64), "weapon_musta": (32, 32), "weapon_sopa": (48, 48), "weapon_bicak": (32, 32),
         "messi_bust": (64, 64)}   # varsayılan 96x96; arabalar 64x64
VIEWS = {"weapon_musta": "side", "weapon_sopa": "side", "weapon_bicak": "side"}   # varsayılan low top-down
CAR_OUT = os.path.join(ROOT, "assets", "pixellab", "cars")


def out_dir(name):
    return CAR_OUT if name.startswith("car_") else OUT


def key():
    return open(os.path.join(ROOT, ".pixellab_key"), encoding="utf-8").read().strip()


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, headers={
        "Authorization": "Bearer " + key(), "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}") if e.headers.get("content-type", "").startswith("application/json") else {}


def generate(name):
    w, h = SIZES.get(name, (64, 64) if name.startswith("car_") else (96, 96))
    status, res = call("POST", "/map-objects", {
        "description": PROMPTS[name] + STYLE,
        "image_size": {"width": w, "height": h},
        "view": VIEWS.get(name, "low top-down"),
        "outline": "single color outline",
        "shading": "medium shading",
        "detail": "medium detail",
    })
    if status != 200:
        print(name, "HATA", status, res)
        return False
    oid = res["object_id"]
    print(name, "kuyrukta:", oid, res.get("usage"))
    for _ in range(60):
        time.sleep(4)
        status, info = call("GET", "/map-objects/" + oid)
        if status == 200 and info.get("status") == "completed":
            url = info.get("download_url") or info.get("image_url")
            if not url:
                print(name, "indirme adresi yok:", info)
                return False
            out = out_dir(name)
            os.makedirs(out, exist_ok=True)
            req = urllib.request.Request(url, headers={"Authorization": "Bearer " + key()} if url.startswith(API) else {})
            with urllib.request.urlopen(req, timeout=60) as r:
                open(os.path.join(out, name + ".png"), "wb").write(r.read())
            print(name, "indirildi", info.get("width"), "x", info.get("height"))
            return True
        if status == 410 or info.get("status") == "failed":
            print(name, "BAŞARISIZ", info)
            return False
    print(name, "zaman aşımı")
    return False


if __name__ == "__main__":
    force = "--force" in sys.argv
    for n in [a for a in sys.argv[1:] if not a.startswith("--")]:
        if not force and os.path.exists(os.path.join(out_dir(n), n + ".png")):
            print(n, "zaten var, atlandı")
            continue
        generate(n)
