#!/usr/bin/env python3
"""Strict verification for the generated golden pixel-art sample."""
from __future__ import annotations
import hashlib, json, subprocess, sys
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[3]
SPRITES=ROOT/'assets'/'sprites'; PREVIEWS=ROOT/'assets'/'previews'
PALETTE={None,'#10141f','#1b2638','#2f3a4c','#53606f','#7a8791','#c3ccd0','#f2e6cf','#c98c55','#a65b45','#703b3b','#d3a45c','#f0d77a','#426b69','#55917f','#73d1c8','#a8e0c8','#274c67','#427aa1','#8fc7ff','#605080','#8a68a6','#d59cff','#7d334e','#d85b6a'}
EXPECTED={'drill_default':(32,32,28),'modules_default':(32,32,5),'industrial_tiles':(16,16,16),'industrial_ores':(16,16,12),'industrial_hazards':(16,16,18),'scrap_mite':(16,16,16),'workshop_l1':(48,32,1),'ui_icons':(16,16,11)}
def hx(p:Path)->str:return hashlib.sha256(p.read_bytes()).hexdigest()
def main()->None:
    manifest=json.loads((SPRITES/'golden_sample_manifest.json').read_text(encoding='utf-8'))
    before={p.name:hx(p) for p in SPRITES.glob('*.png')}
    subprocess.run([sys.executable,str(ROOT/'src/tools/artgen/artgen.py'),'--generate'],cwd=ROOT,check=True)
    after={p.name:hx(p) for p in SPRITES.glob('*.png')}
    errors=[]; report={'deterministic':before==after,'assets':{},'errors':errors}
    if before!=after: errors.append('regeneration SHA-256 mismatch')
    for asset in manifest['assets']:
        ident=asset['id']; w,h,n=EXPECTED[ident]; p=SPRITES/asset['png']; im=Image.open(p).convert('RGBA')
        colors=set(im.getdata()); bad=[]
        for r,g,b,a in colors:
            value=None if a==0 else '#%02x%02x%02x'%(r,g,b)
            if value not in PALETTE or a not in (0,255): bad.append((r,g,b,a))
        # Sheets are packed at eight columns, so an incomplete last row is valid.
        good_dims=im.width%w==0 and im.height%h==0 and all(
            f['rect'][0] >= 0 and f['rect'][1] >= 0 and
            f['rect'][0]+f['rect'][2] <= im.width and f['rect'][1]+f['rect'][3] <= im.height
            for f in asset['frames'])
        good_meta=len(asset['frames'])==n and all(f['anchor']==[w//2,h//2] for f in asset['frames'])
        good_tres=(SPRITES/f'{ident}.tres').read_text(encoding='utf-8').find('ExtResource("1_sheet")')>=0
        report['assets'][ident]={'size':[im.width,im.height],'frame_size':[w,h],'frames':n,'palette_ok':not bad,'opaque_or_transparent_only':all(a in (0,255) for _,_,_,a in colors),'dimensions_ok':good_dims,'anchors_ok':good_meta,'spriteframes_ok':good_tres,'sha256':hx(p)}
        if bad: errors.append(f'{ident}: unregistered color or alpha')
        if not good_dims or not good_meta or not good_tres: errors.append(f'{ident}: metadata/layout invalid')
    scene=Image.open(PREVIEWS/'golden_scene_640x360_1x.png'); report['golden_scene_size']=list(scene.size)
    if scene.size!=(640,360):errors.append('golden scene must be 640x360')
    (PREVIEWS/'art_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    raise SystemExit(1 if errors else 0)
if __name__=='__main__':main()
