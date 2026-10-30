#!/usr/bin/env python3
"""Set Godot import options for every texture in assets/textures:
mipmaps + VRAM compression (they are loaded from code, so the editor can't
auto-detect 3D use), and normal-map mode for *_normal textures.
Run after Godot has created the .import files (open the editor or `godot --import`)."""
import os, re, glob
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")
WANT = {
    "compress/mode": "2",
    "compress/high_quality": "false",
    "mipmaps/generate": "true",
    "mipmaps/limit": "-1",
    "detect_3d/compress_to": "0",
    "process/fix_alpha_border": "true",
}
changed = 0
for f in sorted(glob.glob(os.path.join(D, "*.import"))):
    s = open(f).read()
    want = dict(WANT)
    base = os.path.basename(f)
    want["compress/normal_map"] = "1" if "_normal" in base else "2"
    if "_normal" in base:
        want["compress/high_quality"] = "true"
    head, sep, params = s.partition("[params]")
    if not sep:
        continue
    lines = params.strip("\n").split("\n")
    keys = {}
    for i, ln in enumerate(lines):
        if "=" in ln:
            keys[ln.split("=", 1)[0]] = i
    for k, v in want.items():
        if k in keys:
            lines[keys[k]] = f"{k}={v}"
        else:
            lines.append(f"{k}={v}")
    new = head + "[params]\n\n" + "\n".join(l for l in lines if l.strip() != "") + "\n"
    if new != s:
        open(f, "w").write(new)
        changed += 1
print("updated", changed, "import files")
