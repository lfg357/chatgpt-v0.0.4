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
    # Center anchor is always (16,16); 1px coal outline holds the silhouette.
    rect(m,8,11,14,10,o); rect(m,11,8,9,3,o); rect(m,11,21,10,3,o)
    rect(m,9,12,13,8,3); rect(m,12,9,7,2,4); rect(m,11,13,12,6,5)
    # Double-panel maintenance hull: recessed screen, inspection plate and rivets.
    rect(m,12,14,8,4,6); rect(m,13,14,3,1,19); put(m,14,13,7)
    rect(m,16,14,4,4,17); rect(m,17,15,2,2,18); put(m,17,15,19)
    line(m,12,18,20,18,4); put(m,11,13,6); put(m,20,13,6); put(m,11,19,4); put(m,20,19,4)
    # Carbide drill at the right, reinforced by compact outline.
    rect(m,22,13,4,6,o); line(m,26,13,30,16,6); line(m,26,19,30,16,6); put(m,30,16,7)
    # Copper cooling loop.
    line(m,11,11,19,11,8); line(m,10,12,10,19,8); line(m,11,20,19,20,8); line(m,20,12,20,19,8)
    put(m,11,12,12); put(m,19,19,11)
    # Compact thruster and cargo frame.
    rect(m,5,13,4,6,o); rect(m,6,14,3,4,4); rect(m,4,15,2,2,9); put(m,6,14,6); put(m,6,18,3)
    line(m,10,22,20,22,6); put(m,9,22,6); put(m,21,22,6); line(m,11,23,19,23,3); put(m,12,24,4); put(m,18,24,4)
    if state=="thrust":
        flame=[12,9,12,7][phase]; rect(m,4-flame//3,15,flame//3,2,12); put(m,3-flame//3,16,7)
    elif state=="drill":
        for p in range(phase%3+1): put(m,28+p,15+(p%2),12)
        put(m,26,16,12); put(m,27,16,7)
    elif state=="overheat":
        for x,y in [(13,10),(17,10),(15,8),(18,13)]: put(m,x,y,24 if phase%2 else 9)
        rect(m,5,13,3,6,9)
    elif state=="light_damage":
        put(m,16,16,1); put(m,17,17,1); put(m,12,19,9)
    elif state=="heavy_damage":
        for x,y in [(13,15),(14,16),(17,17),(18,18),(10,19)]: put(m,x,y,1)
        put(m,7,14,9); put(m,20,11,24)
    elif state=="destroyed":
        # Scatter remains around stable anchor, changing each frame but not canvas.
        for i,(x,y) in enumerate([(10,17),(15,14),(19,18),(22,12),(7,22),(25,21),(13,25),(18,9)]):
            put(m,x+(phase+i)%3-1,y+(phase*2+i)%3-1,[4,8,9,12][i%4])
        rect(m,12,15,7,4,3 if phase<4 else 2); put(m,18,14,24)
    return m

def tile(kind:int) -> list[list[int]]:
    m=blank(16,16); rect(m,0,0,16,16,1)
    if kind==0: # solid rock
        rect(m,1,1,14,14,3); rect(m,2,2,5,4,4); rect(m,9,2,4,5,2); rect(m,4,9,7,5,2); put(m,3,8,5); put(m,12,11,4); put(m,7,3,5); put(m,8,12,4); line(m,2,7,5,9,2)
    elif kind==1: # brittle rock
        rect(m,1,1,14,14,4); line(m,3,2,7,8,2); line(m,7,8,11,6,2); line(m,7,8,8,13,2); put(m,11,12,5); put(m,4,4,5); put(m,12,3,3)
    elif kind==2: rect(m,1,1,14,14,3); rect(m,1,1,14,2,6); rect(m,1,13,14,2,2); line(m,3,3,12,3,5); put(m,3,1,7); put(m,12,1,7); put(m,5,14,4); put(m,10,14,4)
    elif kind in (3,4,5,6):
        rect(m,1,1,14,14,3); edge={3:(0,0,16,3),4:(0,13,16,3),5:(0,0,3,16),6:(13,0,3,16)}[kind]; rect(m,*edge,6); put(m,4,4,4); put(m,11,11,2)
    elif kind in (7,8):
        rect(m,1,1,14,14,3); rect(m,0 if kind==7 else 11,0,5,5,6); line(m,4 if kind==7 else 11,4,11 if kind==7 else 4,11,5)
    elif kind==9: rect(m,0,0,16,16,2); rect(m,2,2,12,12,3); rect(m,4,4,7,1,4); put(m,11,9,4); put(m,3,11,4); put(m,12,5,5); line(m,5,12,9,12,2)
    elif kind==10:
        rect(m,0,0,16,16,3); rect(m,2,1,3,15,6); rect(m,11,1,3,15,6); line(m,4,4,11,4,5); line(m,4,10,11,10,5); put(m,3,3,1); put(m,12,3,1); put(m,3,12,1); put(m,12,12,1)
    elif kind==11:
        rect(m,0,0,16,16,2); line(m,1,8,14,8,8); line(m,4,2,4,8,8); line(m,11,8,11,14,8); put(m,4,2,12); put(m,11,14,12); put(m,2,8,6); put(m,13,8,6)
    elif kind==12:
        rect(m,0,0,16,16,3); rect(m,4,9,8,6,6); rect(m,6,4,4,5,1); rect(m,7,5,2,4,12); put(m,5,11,8); put(m,6,10,4); put(m,10,13,4); line(m,5,14,11,14,3)
    elif kind==13:
        rect(m,0,0,16,16,3); rect(m,2,10,12,4,2); line(m,3,11,12,11,19); put(m,4,10,24); put(m,10,10,24); put(m,6,12,19); put(m,12,12,19)
    elif kind==14:
        rect(m,0,0,16,16,4); line(m,3,2,7,7,2); line(m,7,7,5,13,2); line(m,9,4,13,10,2); rect(m,2,13,12,2,3); put(m,3,12,5); put(m,12,11,5)
    else: # interactive highlighted rock: hatch/shine, not hue-only
        rect(m,1,1,14,14,3); rect(m,2,2,5,4,4); line(m,2,12,12,2,12); put(m,3,12,7); put(m,12,3,7); line(m,5,14,14,5,11); put(m,8,8,7)
    return m

def ore_frame(ore:int, phase:int) -> list[list[int]]:
    m=blank(16,16); o=1; rect(m,4,4,8,8,o)
    if ore==0: # ferrite
        rect(m,5,5,6,6,4); put(m,6,5,6); put(m,9,8,2); put(m,5,10,5); put(m,10,6,5); put(m,7,9,3); put(m,5,7,3)
    elif ore==1: # copper thread
        line(m,4,10,7,4,8); line(m,7,4,12,8,8); line(m,12,8,8,12,8); put(m,7,5,12 if phase%2 else 11); put(m,5,9,11); put(m,10,9,12); put(m,8,11,10)
    else: # lumen crystal
        line(m,8,2,13,8,15); line(m,13,8,8,14,15); line(m,8,14,3,8,15); line(m,3,8,8,2,15); put(m,8,6,7 if phase%2 else 12); put(m,7,5,16); put(m,10,8,19); put(m,7,11,14)
    return m

def hazard_frame(kind:int,state:int,phase:int=0)->list[list[int]]:
    m=blank(16,16); o=1
    if kind==0: # steam
        rect(m,4,11,8,4,6); rect(m,6,8,4,3,2); put(m,7,9,12 if state else 5); put(m,5,12,4); put(m,10,13,4); line(m,5,14,11,14,3)
        if state==1: line(m,7,7,10,4,12); line(m,10,4,12,2,12); put(m,5,6,12)
        if state==2: rect(m,6,1,4,7,7); put(m,5,3,16); put(m,10,5,16); put(m,8,2,16)
    elif kind==1: # cable
        rect(m,2,10,12,4,2); line(m,3,11,13,11,19 if state==2 else 8); line(m,6,11,6,5,8); put(m,6,4,24 if state else 5); put(m,3,12,4); put(m,12,12,4)
        if state==1: put(m,9,8,12); put(m,10,7,12)
        if state==2: put(m,8,6,7); put(m,11,4,7)
    else: # collapse shale
        rect(m,2,5,12,8,4); line(m,3,6,8,10,2); line(m,11,5,8,10,2); put(m,4,11,5); put(m,12,9,5); line(m,3,13,13,13,3)
        if state==1: put(m,4,3,12); put(m,11,3,12)
        if state==2: line(m,8,2,8,5,7); put(m,7,3,7); put(m,9,4,7)
    return m

def mite_frame(state:int, phase:int)->list[list[int]]:
    m=blank(16,16); o=1; dx=(phase%2 if state==1 else 0)
    rect(m,5+dx,6,6,5,o); rect(m,6+dx,6,4,4,13); put(m,7+dx,7,16); put(m,9+dx,8,16); put(m,6+dx,10,4); put(m,10+dx,10,4)
    for x in (4+dx,6+dx,10+dx): line(m,x,10,x-1,13,4)
    line(m,6+dx,6,5+dx,4,4); line(m,9+dx,6,10+dx,4,4)
    if state==2: line(m,5+dx,6,3+dx,3,24); line(m,10+dx,6,12+dx,3,24)
    if state==3: line(m,5+dx,6,2+dx,5,8); put(m,3+dx,5,11)
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
        if i==0: line(m,22,13,30,16,6); line(m,22,19,30,16,6); put(m,29,16,7); put(m,25,15,4); put(m,25,18,4)
        if i==1: rect(m,3,13,5,6,1); rect(m,4,14,3,4,4); put(m,3,16,12); put(m,5,14,6); put(m,5,18,3)
        if i==2: line(m,10,11,20,11,8); line(m,10,11,10,20,8); line(m,10,20,20,20,8); line(m,20,11,20,20,8); put(m,10,13,12); put(m,20,18,11)
        if i==3: rect(m,17,22,5,5,1); rect(m,18,23,3,3,8); put(m,19,22,24); put(m,18,26,4)
        if i==4: line(m,9,22,21,22,6); line(m,10,21,10,24,6); line(m,20,21,20,24,6); line(m,11,23,19,23,3); put(m,12,24,4); put(m,18,24,4)
        layers.append((name,m))
    tiles=[(f"industrial_{n}",tile(i)) for i,n in enumerate(["solid","brittle","boundary","edge_n","edge_s","edge_w","edge_e","inner_corner","outer_corner","background","support","copper_pipe","steam_base","cable_base","collapse_shale","interactive"]) ]
    ores=[]
    for o,n in enumerate(["ferrite","copper_thread","lumen"]): ores += [(f"{n}_{i:02d}",ore_frame(o,i)) for i in range(4)]
    hazards=[]
    for k,n in enumerate(["steam","cable","shale"]): hazards += [(f"{n}_{s}_{i:02d}",hazard_frame(k,s,i)) for s,label in enumerate(["idle","warning","active"]) for i in range(2)]
    mites=[(f"mite_{['calm','move','alert','retreat'][s]}_{i:02d}",mite_frame(s,i)) for s in range(4) for i in range(4)]
    workshop=blank(48,32); rect(workshop,3,8,42,21,1); rect(workshop,5,10,38,17,3); rect(workshop,8,13,13,10,6); rect(workshop,25,12,14,15,4); rect(workshop,28,15,8,4,2); line(workshop,3,8,45,8,8); put(workshop,12,14,12); put(workshop,33,13,12); line(workshop,38,4,38,12,8); put(workshop,38,3,12)
    # Bench, toolboard, pressure gauge, locker seams, roof bolts and service light.
    rect(workshop,6,24,17,3,2); line(workshop,8,17,19,17,17); put(workshop,10,18,11); put(workshop,14,18,9); put(workshop,18,18,8)
    rect(workshop,25,12,14,2,6); line(workshop,29,20,35,20,6); put(workshop,27,15,6); put(workshop,37,15,6); put(workshop,30,23,5); put(workshop,35,23,5)
    line(workshop,38,3,42,3,8); rect(workshop,41,3,2,8,8); put(workshop,42,10,12); put(workshop,5,9,6); put(workshop,43,9,6); put(workshop,7,27,4); put(workshop,41,27,4)
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
    im=Image.new("RGBA",(640,360),RGB[1]); px=im.load()
    # Coal-rock walls with hard stepped bands and warm practical light pools.
    for y in range(360):
        for x in range(640):
            px[x,y]=RGB[2 if (x//32+y//24)%3 else 3]
    for x in range(0,640,16):
        for y in range(0,360,16):
            if (x//16*3+y//16*5)%11==0: px[x+4,y+5]=RGB[4]
    # Tunnel negative space: distant girders, floor gratings and stepped rock ceiling.
    rect_scene(im,0,238,640,122,1); rect_scene(im,0,245,640,5,6); rect_scene(im,0,254,640,4,4)
    for x in range(8,640,32):
        rect_scene(im,x,258,18,3,3); rect_scene(im,x+3,262,2,6,5); rect_scene(im,x+13,262,2,6,5)
    for x in range(0,640,48):
        line_scene(im,x,202,x+24,190,3); line_scene(im,x+24,190,x+48,202,3)
        put_scene(im,x+24,190,5)
    for x in (40,180,440,560):
        rect_scene(im,x,70,8,175,6); rect_scene(im,x-8,76,24,6,8)
    for x in range(20,620,96):
        line_scene(im,x,108,x+64,108,8); line_scene(im,x+64,108,x+64,184,8)
        rect_scene(im,x+16,105,5,6,6); rect_scene(im,x+17,106,2,2,7)
    # Layered overhead copper service pipe with joints, valves and condensate marks.
    line_scene(im,8,145,150,145,8); line_scene(im,150,145,150,165,8); line_scene(im,150,165,282,165,8)
    line_scene(im,282,165,282,134,8); line_scene(im,282,134,420,134,8)
    for x,y in [(52,145),(150,151),(215,165),(282,150),(360,134)]:
        rect_scene(im,x-2,y-2,5,5,11); put_scene(im,x,y,12)
    for x,y in [(170,180),(173,184),(347,152),(350,156)]: put_scene(im,x,y,5)
    for x,y in [(90,82),(330,65),(535,120)]:
        rect_scene(im,x,y,4,13,6); rect_scene(im,x-4,y+13,12,8,12); rect_scene(im,x-1,y+15,6,4,7)
        # Hard-edged lamp spill; ordered dots preserve pixel language.
        for dx,dy in [(-10,22),(10,22),(-18,29),(18,29),(-28,37),(28,37)]: put_scene(im,x+dx,y+dy,11)
    # tile strip, ores, hazards and mite use actual source pixels scaled 4.
    assets={a['id']:a for a in source['assets']}
    tileasset=assets['industrial_tiles'];
    for i in range(8): im.alpha_composite(to_image(tileasset['frames'][i]['pixels']).resize((64,64),Image.Resampling.NEAREST),(i*64,250))
    oreasset=assets['industrial_ores'];
    for i in range(3): im.alpha_composite(to_image(oreasset['frames'][i*4+1]['pixels']).resize((48,48),Image.Resampling.NEAREST),(355+i*55,188))
    haz=assets['industrial_hazards']; im.alpha_composite(to_image(haz['frames'][4]['pixels']).resize((64,64),Image.Resampling.NEAREST),(520,183)); im.alpha_composite(to_image(haz['frames'][10]['pixels']).resize((64,64),Image.Resampling.NEAREST),(590,183))
    im.alpha_composite(to_image(assets['scrap_mite']['frames'][5]['pixels']).resize((48,48),Image.Resampling.NEAREST),(450,205))
    # drilling rig
    im.alpha_composite(to_image(assets['drill_default']['frames'][10]['pixels']).resize((128,128),Image.Resampling.NEAREST),(190,155))
    # HUD bands: icon sockets, segmented bars and non-text directional pips.
    rect_scene(im,14,14,215,48,1); rect_scene(im,18,18,207,40,3)
    for i,c in enumerate([24,19,9,11]):
        rect_scene(im,26+i*47,29,38,12,1); rect_scene(im,29+i*47,32,32,6,c); put_scene(im,31+i*47,33,7)
    for x in range(22,220,16): put_scene(im,x,51,5)
    rect_scene(im,478,14,148,48,1); rect_scene(im,482,18,140,40,3); rect_scene(im,490,28,120,14,1); rect_scene(im,493,31,114,8,12)
    for x in range(495,607,12): put_scene(im,x,34,7)
    rect_scene(im,486,47,32,5,18); rect_scene(im,524,47,32,5,19); rect_scene(im,562,47,32,5,24)
    return im

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
