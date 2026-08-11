#!/usr/bin/env python3
"""Deterministic, palette-locked pixel-art generator for Time Strata Drill Bureau.

The source contract is JSON: palette indexes, frame metadata, and integer pixel
matrices.  `--build-source` creates the reviewed golden-sample source and
`--generate` turns it into PNG sprite sheets, nearest-neighbour previews,
SpriteFrames resources, a contact sheet, and a palette report.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets" / "art_source" / "golden_sample.json"
SPRITES = ROOT / "assets" / "sprites"
PREVIEWS = ROOT / "assets" / "previews"

# Index 0 is transparent; remaining colors are the fixed technical palette.
PALETTE = [
    None, "#10141F", "#1B2638", "#2F3A4C", "#53606F", "#7A8791", "#C3CCD0",
    "#F2E6CF", "#C98C55", "#A65B45", "#703B3B", "#D3A45C", "#F0D77A",
    "#426B69", "#55917F", "#73D1C8", "#A8E0C8", "#274C67", "#427AA1",
    "#8FC7FF", "#605080", "#8A68A6", "#D59CFF", "#7D334E", "#D85B6A",
]
RGB = [(0, 0, 0, 0)] + [tuple(bytes.fromhex(c[1:])) + (255,) for c in PALETTE[1:]]

def blank(w: int, h: int) -> list[list[int]]:
    return [[0] * w for _ in range(h)]

def put(m: list[list[int]], x: int, y: int, c: int) -> None:
    if 0 <= y < len(m) and 0 <= x < len(m[0]): m[y][x] = c

def rect(m: list[list[int]], x: int, y: int, w: int, h: int, c: int) -> None:
    for yy in range(y, y+h):
        for xx in range(x, x+w): put(m, xx, yy, c)

def line(m: list[list[int]], x0:int,y0:int,x1:int,y1:int,c:int) -> None:
    dx, dy = abs(x1-x0), -abs(y1-y0); sx = 1 if x0<x1 else -1; sy = 1 if y0<y1 else -1; err=dx+dy
    while True:
        put(m,x0,y0,c)
        if x0==x1 and y0==y1: break
        e=2*err
        if e>=dy: err+=dy; x0+=sx
        if e<=dx: err+=dx; y0+=sy

def drill_frame(state: str, phase: int) -> list[list[int]]:
    m=blank(32,32); o=1
    # New silhouette: squat repair crawler, copper boiler on the back and a narrow carbide nose.
    line(m,8,22,9,12,o); line(m,9,12,13,7,o); line(m,13,7,20,7,o); line(m,20,7,24,12,o)
    line(m,24,12,25,20,o); line(m,25,20,21,24,o); line(m,21,24,9,24,o); line(m,9,24,8,22,o)
    rect(m,10,12,13,10,3); rect(m,12,9,8,4,4); rect(m,11,13,10,8,8)
    # Sloped cab: warm rim, blue glass and a single pale visor sparkle.
    line(m,13,9,19,9,8); line(m,12,10,12,15,8); line(m,19,10,21,15,8)
    rect(m,14,11,5,4,17); put(m,15,11,19); put(m,18,12,19); put(m,14,15,3)
    # Boiler/radiator is deliberately off-centre so the hull does not read as a box.
    rect(m,9,14,3,6,10); rect(m,10,13,3,8,8); put(m,11,14,12); put(m,11,19,9)
    # Riveted armor, tool hatch and a shaded crawler base.
    rect(m,19,16,4,5,4); put(m,20,17,6); put(m,22,19,6); line(m,13,21,22,21,5)
    rect(m,10,22,12,2,1); rect(m,11,23,10,2,4); put(m,12,24,6); put(m,16,24,2); put(m,20,24,6)
    # Carbide biter: three teeth on an outlined cone at the front.
    line(m,24,13,30,16,o); line(m,24,20,30,16,o); line(m,25,14,29,16,6); line(m,25,19,29,16,6)
    put(m,27,15,7); put(m,28,16,12); put(m,27,17,7)
    # Compact thruster, exhaust grille and cargo rail behind the crawler.
    rect(m,5,15,4,5,o); rect(m,6,16,3,3,4); put(m,5,17,9); line(m,7,15,7,20,6)
    line(m,9,20,9,23,6); line(m,8,21,10,21,6); put(m,8,23,4)
    if state=="thrust":
        flame=[8,12,10,6][phase]; rect(m,4-flame//3,16,flame//3,2,12); put(m,3-flame//3,17,7)
    elif state=="drill":
        for p in range(phase%4+2): put(m,28+p,14+(p*3)%6,12 if p%2 else 7)
        put(m,25,16,12); put(m,26,16,7)
    elif state=="overheat":
        for x,y in [(11,11),(15,8),(20,11),(9,14),(22,14)]: put(m,x,y,24 if phase%2 else 9)
        rect(m,5,15,3,5,9)
    elif state=="light_damage":
        line(m,16,15,18,18,1); put(m,12,20,9)
    elif state=="heavy_damage":
        for x,y in [(13,14),(14,15),(16,16),(17,17),(21,19),(10,19)]: put(m,x,y,1)
        put(m,7,15,9); put(m,20,10,24)
    elif state=="destroyed":
        # Scatter remains around stable anchor, changing each frame but not canvas.
        for i,(x,y) in enumerate([(9,18),(14,13),(20,18),(24,12),(7,23),(26,21),(13,26),(18,8)]):
            put(m,x+(phase+i)%3-1,y+(phase*2+i)%3-1,[4,8,9,12][i%4])
        rect(m,12,16,7,4,3 if phase<4 else 2); put(m,18,14,24)
    return m

def tile(kind:int) -> list[list[int]]:
    # Every tile begins with coal outline and a different material silhouette;
    # this is an authored kit, not a recoloured square.
    m=blank(16,16); rect(m,0,0,16,16,1)
    if kind==0: # solid shale: chunky diagonals and a compressed seam
        rect(m,1,1,14,14,2); line(m,1,4,6,1,4); line(m,3,15,10,8,3); line(m,8,2,14,7,4); line(m,10,14,14,10,5); put(m,4,5,5); put(m,12,4,3); put(m,7,12,4)
    elif kind==1: # brittle rock: pale face with a branching fracture
        rect(m,1,1,14,14,4); line(m,2,2,8,8,5); line(m,8,8,13,6,2); line(m,8,8,6,14,2); line(m,6,14,3,12,2); put(m,3,4,6); put(m,11,3,5); put(m,12,12,3)
    elif kind==2: # invulnerable plated boundary
        rect(m,1,1,14,14,3); rect(m,1,1,14,3,6); rect(m,1,12,14,3,2); line(m,3,5,12,5,4); line(m,3,11,12,11,4); put(m,3,2,7); put(m,12,2,7); put(m,3,13,5); put(m,12,13,5)
    elif kind in (3,4,5,6): # faced rock edges
        rect(m,1,1,14,14,2); edge={3:(0,0,16,4),4:(0,12,16,4),5:(0,0,4,16),6:(12,0,4,16)}[kind]; rect(m,*edge,5)
        if kind in (3,4): line(m,2,3 if kind==3 else 12,13,3 if kind==3 else 12,6)
        else: line(m,3 if kind==5 else 12,2,3 if kind==5 else 12,13,6)
        put(m,7,7,4); put(m,10,10,3)
    elif kind==7: # inner structural corner
        rect(m,1,1,14,14,2); rect(m,1,1,7,4,6); rect(m,1,1,4,8,6); line(m,4,8,11,8,4); line(m,8,4,8,11,4); put(m,3,3,7); put(m,10,10,5)
    elif kind==8: # outer corner
        rect(m,1,1,14,14,3); rect(m,10,1,5,5,6); rect(m,1,10,5,5,6); line(m,5,10,10,5,5); put(m,12,3,7); put(m,3,12,7)
    elif kind==9: # distant rock wall with a recessed pipe scar
        rect(m,0,0,16,16,17); rect(m,2,2,12,12,2); line(m,3,4,12,4,3); line(m,5,7,11,7,3); put(m,3,11,4); put(m,12,10,4); put(m,8,13,3)
    elif kind==10: # bolted I-beam support
        rect(m,0,0,16,16,2); rect(m,2,1,3,15,6); rect(m,11,1,3,15,6); rect(m,4,3,8,3,4); rect(m,4,10,8,3,4); put(m,3,2,7); put(m,12,2,7); put(m,3,14,5); put(m,12,14,5)
    elif kind==11: # copper pipe elbow
        rect(m,0,0,16,16,2); line(m,1,11,11,11,8); line(m,11,11,11,3,8); line(m,2,10,10,10,11); line(m,10,10,10,3,11); put(m,4,11,12); put(m,11,6,12); put(m,13,3,6)
    elif kind==12: # steam socket with mechanical collar
        rect(m,0,0,16,16,3); rect(m,3,10,10,5,1); rect(m,4,11,8,4,6); rect(m,6,5,4,6,2); rect(m,7,4,2,6,12); put(m,5,12,8); put(m,10,12,8); put(m,7,14,4)
    elif kind==13: # live cable tray
        rect(m,0,0,16,16,3); rect(m,1,10,14,5,1); rect(m,2,11,12,3,4); line(m,3,12,13,12,19); put(m,4,11,24); put(m,8,13,19); put(m,12,11,24); put(m,2,14,6); put(m,13,14,6)
    elif kind==14: # loose collapse shale with falling chips
        rect(m,1,4,14,11,4); line(m,2,5,8,10,2); line(m,8,10,13,6,2); line(m,9,3,11,5,5); put(m,3,12,5); put(m,12,12,5); put(m,5,2,4); put(m,14,8,4)
    else: # interactive: chevrons + spark points, not colour-only highlighting
        rect(m,1,1,14,14,2); line(m,2,12,8,6,12); line(m,8,6,14,12,12); line(m,3,14,9,8,11); put(m,4,4,7); put(m,12,4,7); put(m,8,2,12)
    return m

def ore_frame(ore:int, phase:int) -> list[list[int]]:
    m=blank(16,16); o=1
    if ore==0: # ferrite: embedded rough ore cluster, not a freestanding square
        line(m,3,12,5,4,o); line(m,5,4,11,3,o); line(m,11,3,13,10,o); line(m,13,10,9,13,o); line(m,9,13,3,12,o)
        rect(m,5,6,6,5,4); put(m,5,5,6); put(m,8,4,5); put(m,11,7,6); put(m,9,10,3); put(m,6,10,5)
    elif ore==1: # copper thread: branching vein caught in stone
        line(m,2,12,5,8,o); line(m,5,8,7,3,o); line(m,7,3,11,7,o); line(m,11,7,14,5,o)
        line(m,5,8,10,11,8); line(m,10,11,13,13,8); line(m,6,7,7,3,11); line(m,8,4,11,7,12); put(m,12,6,12 if phase%2 else 11); put(m,11,11,10)
    else: # lumen: tall split prism with lit internal planes
        line(m,8,1,13,7,o); line(m,13,7,10,14,o); line(m,10,14,5,14,o); line(m,5,14,3,8,o); line(m,3,8,8,1,o)
        line(m,8,2,8,13,15); line(m,8,2,12,7,16); line(m,8,13,5,8,14); put(m,10,8,19); put(m,7,5,7 if phase%2 else 12); put(m,6,11,16)
    return m

def hazard_frame(kind:int,state:int,phase:int=0)->list[list[int]]:
    m=blank(16,16); o=1
    if kind==0: # steam
        rect(m,3,11,10,4,o); rect(m,4,11,8,3,4); rect(m,6,7,4,5,o); rect(m,7,8,2,3,8); put(m,4,13,6); put(m,11,13,6); put(m,8,10,12 if state else 5)
        if state==1: line(m,7,7,10,4,12); line(m,10,4,12,2,12); put(m,5,7,12); put(m,12,5,12)
        if state==2: line(m,7,7,5,2,16); line(m,8,7,10,1,7); line(m,9,7,13,4,16); put(m,4,3,16); put(m,12,6,7)
    elif kind==1: # cable
        rect(m,1,11,14,4,o); rect(m,2,12,12,2,4); line(m,3,12,12,12,8); line(m,5,12,5,5,8); line(m,5,5,8,3,8); put(m,5,5,6); put(m,3,14,6); put(m,12,14,6)
        if state==1: put(m,9,8,12); put(m,11,6,12); put(m,12,9,12)
        if state==2: line(m,8,7,10,5,7); line(m,10,5,12,7,7); line(m,12,7,14,4,7); put(m,8,10,19)
    else: # collapse shale
        line(m,2,6,5,3,o); line(m,5,3,12,5,o); line(m,12,5,14,10,o); line(m,14,10,9,14,o); line(m,9,14,2,12,o)
        rect(m,4,6,8,6,4); line(m,4,6,8,10,2); line(m,10,5,8,10,2); put(m,5,11,5); put(m,12,9,5)
        if state==1: put(m,4,2,12); put(m,9,1,12); line(m,11,2,13,4,12)
        if state==2: line(m,8,1,8,5,7); put(m,7,3,7); put(m,9,4,7); put(m,3,2,4); put(m,12,2,4)
    return m

def mite_frame(state:int, phase:int)->list[list[int]]:
    m=blank(16,16); o=1; dx=(phase%3-1 if state==1 else 0)
    # Beetle profile: segmented scrap shell, shovel forelegs and a high antenna.
    line(m,4+dx,9,6+dx,5,o); line(m,6+dx,5,10+dx,5,o); line(m,10+dx,5,13+dx,9,o); line(m,13+dx,9,11+dx,11,o); line(m,11+dx,11,5+dx,11,o); line(m,5+dx,11,4+dx,9,o)
    rect(m,6+dx,7,5,3,13); put(m,7+dx,6,16); put(m,10+dx,7,16); line(m,8+dx,7,8+dx,10,4); put(m,11+dx,9,4)
    for x in (5+dx,8+dx,11+dx): line(m,x,11,x-1,14,6)
    line(m,6+dx,6,4+dx,3,4); line(m,10+dx,6,12+dx,3,4)
    if state==2: line(m,5+dx,7,2+dx,4,24); line(m,11+dx,7,14+dx,4,24)
    if state==3: line(m,4+dx,9,1+dx,8,8); put(m,2+dx,8,11)
    return m

def icon(kind:int)->list[list[int]]:
    m=blank(16,16); o=1
    if kind==0: # scrap
        rect(m,3,4,10,8,o); rect(m,4,5,8,6,11); put(m,5,5,7)
    elif kind==1: # core
        line(m,8,2,13,8,15); line(m,13,8,8,14,15); line(m,8,14,3,8,15); line(m,3,8,8,2,15); put(m,8,8,7)
    elif kind==2: # data
        rect(m,3,3,10,10,o); rect(m,4,4,8,8,19); line(m,5,7,10,7,7)
    elif kind==3: # shard
        line(m,8,2,12,8,22); line(m,12,8,8,14,22); line(m,8,14,4,8,22); line(m,4,8,8,2,22)
    elif kind==4: # durability
        line(m,8,2,13,5,24); line(m,13,5,11,13,24); line(m,11,13,5,13,24); line(m,5,13,3,5,24); line(m,3,5,8,2,24)
    elif kind==5: # energy
        line(m,9,1,4,9,12); line(m,4,9,8,9,12); line(m,7,15,12,7,12); line(m,12,7,8,7,12)
    elif kind==6: # heat
        line(m,8,2,5,8,9); line(m,5,8,8,14,24); line(m,8,14,11,8,24); line(m,11,8,8,2,9)
    elif kind==7: # cargo
        rect(m,2,5,12,8,o); rect(m,3,6,10,6,5); line(m,2,5,14,5,7)
    elif kind==8: # sonar
        line(m,3,12,8,3,19); line(m,8,3,13,12,19); put(m,8,8,7); line(m,1,13,15,13,19)
    elif kind==9: # beacon
        rect(m,6,6,4,8,6); put(m,8,3,12); line(m,4,5,8,2,12); line(m,8,2,12,5,12)
    else: # blast pin
        rect(m,7,3,3,9,8); rect(m,5,11,7,3,6); put(m,8,2,24)
    return m

def frames_named(prefix:str, width:int,height:int, makers:list[tuple[str,list[list[int]]]],fps:int=8)->dict[str,Any]:
    return {"id":prefix,"frame_size":[width,height],"fps":fps,"anchor":[width//2,height//2],"frames":[{"name":n,"pixels":p} for n,p in makers]}

def build_source()->dict[str,Any]:
    drill=[]
    for state,count in [("idle",4),("thrust",4),("drill",6),("overheat",4),("light_damage",1),("heavy_damage",1),("destroyed",8)]:
        drill += [(f"{state}_{i:02d}", drill_frame(state,i)) for i in range(count)]
    layers=[]
    for i,name in enumerate(["carbide_biter","compact_thruster","copper_loop","remote_charge","cargo_frame"]):
        m=blank(32,32); # source overlays deliberately share same anchored canvas.
        if i==0:
            line(m,24,13,31,16,1); line(m,24,20,31,16,1); line(m,25,14,30,16,6); line(m,25,19,30,16,6); put(m,27,15,12); put(m,29,16,7); put(m,27,18,12)
        if i==1:
            rect(m,3,15,5,5,1); rect(m,4,16,3,3,4); line(m,7,15,7,20,6); put(m,3,17,9); put(m,2,17,12); put(m,5,16,6)
        if i==2:
            line(m,9,13,10,20,1); line(m,10,12,17,10,1); line(m,17,10,21,13,1); line(m,21,13,21,20,1); line(m,21,20,17,22,1); line(m,17,22,10,20,1)
            line(m,10,13,17,11,8); line(m,17,11,20,14,8); line(m,20,14,20,19,8); line(m,20,19,17,21,8); line(m,17,21,11,19,8); put(m,11,14,12); put(m,19,18,12)
        if i==3:
            rect(m,18,21,5,6,1); rect(m,19,22,3,4,8); line(m,20,21,20,17,6); put(m,20,17,24); put(m,19,25,6); put(m,22,25,6)
        if i==4:
            line(m,8,21,8,25,6); line(m,8,25,22,25,6); line(m,22,25,22,21,6); line(m,10,22,20,22,4); put(m,11,25,5); put(m,19,25,5); line(m,9,20,21,20,1)
        layers.append((name,m))
    tiles=[(f"industrial_{n}",tile(i)) for i,n in enumerate(["solid","brittle","boundary","edge_n","edge_s","edge_w","edge_e","inner_corner","outer_corner","background","support","copper_pipe","steam_base","cable_base","collapse_shale","interactive"]) ]
    ores=[]
    for o,n in enumerate(["ferrite","copper_thread","lumen"]): ores += [(f"{n}_{i:02d}",ore_frame(o,i)) for i in range(4)]
    hazards=[]
    for k,n in enumerate(["steam","cable","shale"]): hazards += [(f"{n}_{s}_{i:02d}",hazard_frame(k,s,i)) for s,label in enumerate(["idle","warning","active"]) for i in range(2)]
    mites=[(f"mite_{['calm','move','alert','retreat'][s]}_{i:02d}",mite_frame(s,i)) for s in range(4) for i in range(4)]
    # Workshop is a readable miniature location: open bay, lift rig, tool wall and boiler.
    workshop=blank(48,32); rect(workshop,1,7,46,23,1); rect(workshop,3,9,42,19,17); rect(workshop,4,10,40,17,3)
    rect(workshop,6,14,19,12,1); rect(workshop,8,16,15,8,2); rect(workshop,9,17,13,6,4); line(workshop,9,17,21,17,6); put(workshop,11,19,12); put(workshop,16,19,8); put(workshop,20,20,6)
    line(workshop,5,12,27,12,8); line(workshop,7,9,7,15,6); line(workshop,25,9,25,15,6); put(workshop,7,9,7); put(workshop,25,9,7)
    rect(workshop,29,12,12,15,1); rect(workshop,31,14,8,11,4); line(workshop,32,16,38,16,6); line(workshop,32,22,38,22,3); put(workshop,33,18,12); put(workshop,38,19,6)
    line(workshop,39,4,39,12,8); line(workshop,39,4,45,4,8); rect(workshop,43,4,2,7,8); put(workshop,44,10,12)
    line(workshop,3,28,44,28,6); put(workshop,5,10,6); put(workshop,42,10,6); put(workshop,5,27,5); put(workshop,42,27,5)
    icons=[(n,icon(i)) for i,n in enumerate(["scrap","core","data","chronoshard","durability","energy","heat","cargo","sonar","beacon","blast_pin"])]
    return {"format":"time_strata_artgen.v1","palette":PALETTE,"assets":[frames_named("drill_default",32,32,drill,10),frames_named("modules_default",32,32,layers,0),frames_named("industrial_tiles",16,16,tiles,0),frames_named("industrial_ores",16,16,ores,8),frames_named("industrial_hazards",16,16,hazards,8),frames_named("scrap_mite",16,16,mites,8),frames_named("workshop_l1",48,32,[('workshop_l1',workshop)],0),frames_named("ui_icons",16,16,icons,0)]}

def to_image(matrix:list[list[int]])->Image.Image:
    h,w=len(matrix),len(matrix[0]); im=Image.new("RGBA",(w,h)); im.putdata([RGB[v] for row in matrix for v in row]); return im

def render_asset(asset:dict[str,Any])->tuple[Image.Image,dict[str,Any]]:
    w,h=asset["frame_size"]; frames=asset["frames"]; cols=min(8,len(frames)); rows=(len(frames)+cols-1)//cols
    sheet=Image.new("RGBA",(w*cols,h*rows))
    meta=[]
    for i,f in enumerate(frames):
        x,y=(i%cols)*w,(i//cols)*h; sheet.alpha_composite(to_image(f["pixels"]),(x,y)); meta.append({"name":f["name"],"rect":[x,y,w,h],"anchor":asset["anchor"]})
    return sheet,{"id":asset["id"],"frame_size":asset["frame_size"],"fps":asset["fps"],"frames":meta}

def make_scene(source:dict[str,Any])->Image.Image:
    # Author the screenshot at the actual game resolution, then only nearest-scale it.
    # It must read as a playable moment before any asset contact sheet is consulted.
    im=Image.new("RGBA",(320,180),RGB[1]); px=im.load()
    assets={a['id']:a for a in source['assets']}; tiles=assets['industrial_tiles']; ores=assets['industrial_ores']; hazards=assets['industrial_hazards']
    def stamp(asset:dict[str,Any], index:int, x:int, y:int, scale:int=1)->None:
        src=to_image(asset['frames'][index]['pixels'])
        if scale != 1: src=src.resize((src.width*scale,src.height*scale),Image.Resampling.NEAREST)
        im.alpha_composite(src,(x,y))
    # Far layer: dark, low-contrast factory silhouettes and horizontal strata only.
    for x in range(0,320,20):
        h=24 + ((x//20*5)%3)*6
        rect_scene(im,x,18,16,h,2); rect_scene(im,x+3,22,10,h-8,17)
        line_scene(im,x+3,24,x+12,24,3); put_scene(im,x+6,31,4)
    for x in range(10,310,36): line_scene(im,x,98,x+18,92,17); line_scene(im,x+18,92,x+31,98,17)
    # Mid layer: a narrow tunnel lane with two structural bays.
    for x in (48,224):
        rect_scene(im,x,38,6,101,1); rect_scene(im,x+1,40,4,96,5); rect_scene(im,x-7,40,20,5,8)
        rect_scene(im,x-6,136,18,4,4); put_scene(im,x+2,41,7); put_scene(im,x+2,134,6)
    # Sparse copper run; it guides the eye rightward to the threat instead of filling the frame.
    line_scene(im,0,78,96,78,8); line_scene(im,96,78,96,94,8); line_scene(im,96,94,150,94,8)
    for x,y in [(20,78),(72,78),(96,87),(128,94)]: rect_scene(im,x-1,y-1,3,3,10); put_scene(im,x,y,12)
    # Foreground ceiling and floor: black outline separates them sharply from the mid layer.
    roof=[9,9,3,9,10,9,9,3,9,9,10,9,3,9,9,10,9,9,3,9]
    for tx,k in enumerate(roof): stamp(tiles,k,tx*16,0)
    ground=[0,0,1,0,10,0,14,0,0,1,0,11,0,10,0,0,1,0,14,0]
    for tx,k in enumerate(ground): stamp(tiles,k,tx*16,124)
    for tx,k in enumerate([9,0,0,9,0,0,9,0,0,9,0,0,9,0,0,9,0,0,9,0]): stamp(tiles,k,tx*16,140)
    for ty in range(4,8): stamp(tiles,5,0,ty*16); stamp(tiles,6,304,ty*16)
    # Warm lights are limited to two route markers, producing a deliberate warm/cold contrast.
    for x,y in [(82,54),(186,62)]:
        rect_scene(im,x,y,2,13,6); rect_scene(im,x-3,y+13,8,5,12); put_scene(im,x-1,y+15,7)
        for dx,dy in [(-5,20),(5,20),(-11,27),(11,27)]: put_scene(im,x+dx,y+dy,11)
    # Quiet distant boiler: bluer, flatter, and partly occluded by the playable foreground.
    rect_scene(im,250,62,38,55,17); rect_scene(im,253,66,32,47,2); rect_scene(im,257,70,24,4,3); rect_scene(im,262,78,14,24,1)
    line_scene(im,269,79,269,102,8); put_scene(im,269,79,12); put_scene(im,255,110,4); put_scene(im,283,110,4)
    # One clear action sequence: drill -> debris -> brittle wall -> ore/hazard choice.
    stamp(assets['drill_default'],10,112,94)
    for x,y,c in [(144,111,12),(149,108,7),(153,114,11),(158,109,12),(162,115,5),(166,108,16)]: put_scene(im,x,y,c)
    stamp(tiles,1,168,108); stamp(ores,1,188,108); stamp(ores,5,213,109); stamp(hazards,4,244,100); stamp(assets['scrap_mite'],5,205,119)
    # Readable HUD: a separate status rail, with each icon physically bound to one meter.
    rect_scene(im,0,152,320,28,1); rect_scene(im,3,154,314,23,6); rect_scene(im,5,156,310,19,3); line_scene(im,5,156,315,156,4)
    for i,c in enumerate([24,19,9,11]):
        stamp(assets['ui_icons'],4+i,10+i*53,158)
        rect_scene(im,27+i*53,162,28,7,1); rect_scene(im,29+i*53,164,21,3,c); put_scene(im,31+i*53,164,7)
        if i < 3: line_scene(im,61+i*53,159,61+i*53,172,1)
    for i,c in enumerate([19,12,24]):
        stamp(assets['ui_icons'],8+i,244+i*23,158)
        rect_scene(im,244+i*23,171,16,3,1); rect_scene(im,246+i*23,172,12,1,c)
    return im.resize((640,360),Image.Resampling.NEAREST)

def rect_scene(im:Image.Image,x:int,y:int,w:int,h:int,c:int)->None:
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            if 0<=xx<im.width and 0<=yy<im.height: im.putpixel((xx,yy),RGB[c])
def put_scene(im:Image.Image,x:int,y:int,c:int)->None:
    if 0<=x<im.width and 0<=y<im.height: im.putpixel((x,y),RGB[c])
def line_scene(im:Image.Image,x0:int,y0:int,x1:int,y1:int,c:int)->None:
    dx,dy=abs(x1-x0),-abs(y1-y0);sx=1 if x0<x1 else -1;sy=1 if y0<y1 else -1;err=dx+dy
    while True:
        if 0<=x0<im.width and 0<=y0<im.height: im.putpixel((x0,y0),RGB[c])
        if x0==x1 and y0==y1:return
        e=2*err
        if e>=dy:err+=dy;x0+=sx
        if e<=dx:err+=dx;y0+=sy

def write_spriteframes(meta:dict[str,Any], path:Path)->None:
    """Write a valid Godot 4 SpriteFrames resource wired to every atlas region."""
    groups: dict[str, list[dict[str, Any]]] = {}
    for frame in meta['frames']:
        # Names end in _00.  Preserve meaningful animation states for multi-word
        # drill damage and multi-subject hazards; static frames remain named assets.
        stem = frame['name'].rsplit('_', 1)[0]
        pieces = stem.split('_')
        state_words = {'idle','thrust','drill','overheat','destroyed','warning','active','calm','move','alert','retreat'}
        if stem in {'light_damage','heavy_damage'}:
            group = stem
        elif pieces[-1] in state_words:
            group = pieces[-1]
        else:
            group = stem or 'default'
        groups.setdefault(group, []).append(frame)
    count = len(meta['frames']) + 1
    lines=[f"[gd_resource type=\"SpriteFrames\" load_steps={count} format=3]", "", f"[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/{meta['png']}\" id=\"1_sheet\"]", ""]
    for i, frame in enumerate(meta['frames']):
        x,y,w,h=frame['rect']; sid=f"AtlasTexture_{i:03d}"
        lines += [f"[sub_resource type=\"AtlasTexture\" id=\"{sid}\"]", 'atlas = ExtResource("1_sheet")', f"region = Rect2({x}, {y}, {w}, {h})", ""]
    lines += ["[resource]", "animations = ["]
    for gi,(group,frames) in enumerate(groups.items()):
        entries=', '.join('{"duration": 1.0, "texture": SubResource("AtlasTexture_%03d")}' % meta['frames'].index(frame) for frame in frames)
        comma=',' if gi < len(groups)-1 else ''
        lines.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}%s' % (entries, 'false' if group=='destroyed' else 'true', group, meta['fps'], comma))
    lines += ["]"]
    path.write_text("\n".join(lines)+"\n",encoding="utf-8")

def generate()->None:
    source=json.loads(SRC.read_text(encoding='utf-8')); SPRITES.mkdir(parents=True,exist_ok=True); PREVIEWS.mkdir(parents=True,exist_ok=True)
    index={"format":source['format'],"palette":PALETTE,"assets":[]}; contact=[]
    for asset in source['assets']:
        sheet,meta=render_asset(asset); out=SPRITES/f"{asset['id']}.png"; sheet.save(out,compress_level=9)
        sheet.resize((sheet.width*4,sheet.height*4),Image.Resampling.NEAREST).save(PREVIEWS/f"{asset['id']}_4x.png",compress_level=9)
        meta['png']=out.name; meta['sha256']=hashlib.sha256(out.read_bytes()).hexdigest(); index['assets'].append(meta); contact.append((asset['id'],sheet))
        write_spriteframes(meta,SPRITES/f"{asset['id']}.tres")
    # deterministic contact sheet with palette-backed opaque grid.
    cw=640; ch=0; placements=[]; x=y=8; row=0
    for name,s in contact:
        if x+s.width+8>cw: x=8;y+=row+28;row=0
        placements.append((name,s,x,y));x+=s.width+8;row=max(row,s.height)
    ch=y+row+8; contact_im=Image.new('RGBA',(cw,ch),RGB[1])
    for _,s,x,y in placements: contact_im.alpha_composite(s,(x,y))
    contact_im.save(PREVIEWS/'golden_contact_sheet_1x.png',compress_level=9); contact_im.resize((cw*4,ch*4),Image.Resampling.NEAREST).save(PREVIEWS/'golden_contact_sheet_4x.png',compress_level=9)
    scene=make_scene(source); scene.save(PREVIEWS/'golden_scene_640x360_1x.png',compress_level=9); scene.resize((2560,1440),Image.Resampling.NEAREST).save(PREVIEWS/'golden_scene_640x360_4x.png',compress_level=9)
    index['source_sha256']=hashlib.sha256(SRC.read_bytes()).hexdigest(); (SPRITES/'golden_sample_manifest.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+"\n",encoding='utf-8')

def main()->None:
    p=argparse.ArgumentParser();p.add_argument('--build-source',action='store_true');p.add_argument('--generate',action='store_true');a=p.parse_args()
    if a.build_source:
        SRC.parent.mkdir(parents=True,exist_ok=True); SRC.write_text(json.dumps(build_source(),ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
    if a.generate: generate()
    if not(a.build_source or a.generate): p.error('use --build-source and/or --generate')
if __name__=='__main__': main()
