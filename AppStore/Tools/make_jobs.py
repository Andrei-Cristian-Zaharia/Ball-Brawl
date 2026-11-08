#!/usr/bin/env python3
"""Writes a StoreArt render job per language (see Ball/UI/StoreArt.swift).

usage: make_jobs.py <raw captures dir> <output dir> <jobs dir>
Raw captures are expected at <raw>/<lang>/{phone,pad}/<scene>.png (made with capture.sh).
Languages with "shots" in marketing/<lang>.json also get the 6 framed screenshots in 4 sizes.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
raw, out, jobs = (os.path.abspath(p) for p in sys.argv[1:4])
SCENES = [("01-abilities", "abilities", ["wizard", "magma"]), ("02-daily", "daily", ["cell", "bomb"]),
          ("03-collection", "collection", ["spike", "glitch"]), ("04-arenas", "arenas", ["wolf", "clockwork"]),
          ("05-modes", "modes", ["moss", "portal"]), ("06-crusade", "crusade", ["harpoon", "eclipse"])]
TILTS = [-3, 2.5, -2.5, 3, -2, 2.5]
DEVICES = [("iPhone-6.9in", 1320, 2868, False), ("iPhone-6.1in", 1179, 2556, False),
           ("iPad-13in", 2064, 2752, True), ("iPad-12.9in", 2048, 2732, True)]

os.makedirs(jobs, exist_ok=True)
for name in sorted(os.listdir(os.path.join(HERE, "marketing"))):
    lang = name[:-5]
    m = json.load(open(os.path.join(HERE, "marketing", name), encoding="utf-8"))
    items = [
        {"kind": "header", "width": 3840, "height": 1646, "tagline": m["tagline"],
         "file": f"{out}/CreativeAssets/{lang}/ProductPageHeader-3840x1646.png"},
        {"kind": "search", "width": 3840, "height": 2560, "bullets": m["bullets"], "tilt": 7,
         "screen": f"{raw}/{lang}/pad/abilities.png", "file": f"{out}/CreativeAssets/{lang}/SearchResults-3840x2560.png"},
    ]
    for (shot, scene, balls), tilt in zip(SCENES, TILTS) if "shots" in m else []:
        for device, w, h, pad in DEVICES:
            items.append({"kind": "shot", "width": w, "height": h, "isPad": pad, "lines": m["shots"][shot],
                          "screen": f"{raw}/{lang}/{'pad' if pad else 'phone'}/{scene}.png",
                          "tilt": tilt * (0.6 if pad else 1), "balls": balls,
                          "file": f"{out}/Screenshots/{lang}/{device}/{shot}.png"})
    json.dump({"items": items}, open(f"{jobs}/job_{lang}.json", "w", encoding="utf-8"), ensure_ascii=False)
    print(lang, len(items), "images")
