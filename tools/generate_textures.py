#!/usr/bin/env python3
"""Deterministic weathered PBR textures, pure stdlib, CC0/original project assets.
The PNGs are checked into the repository by the build workflow.
"""
import math
import os
import random
import struct
import zlib

SIZE = 512
SEED = 1997
OUT = "assets/textures"
os.makedirs(OUT, exist_ok=True)

def chunk(name, data):
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data) & 0xffffffff)

def save_png(name, pixels, w=SIZE, h=SIZE):
    raw = b"".join(b"\0" + bytes(pixels[y*w*4:(y+1)*w*4]) for y in range(h))
    hdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", hdr) + chunk(b"IDAT", zlib.compress(raw, 8)) + chunk(b"IEND", b"")
    with open(os.path.join(OUT,name), "wb") as f:
        f.write(data)

def hash2(x,y,seed):
    n=(x*374761393+y*668265263+seed*1442695041)&0xffffffff
    n=((n^(n>>13))*1274126177)&0xffffffff
    return (n^(n>>16))/4294967295.0

def noise(x,y,scale,seed):
    xx=x/scale; yy=y/scale
    x0=int(xx); y0=int(yy)
    fx=xx-x0; fy=yy-y0
    sx=fx*fx*(3-2*fx); sy=fy*fy*(3-2*fy)
    a=hash2(x0,y0,seed)*(1-sx)+hash2(x0+1,y0,seed)*sx
    b=hash2(x0,y0+1,seed)*(1-sx)+hash2(x0+1,y0+1,seed)*sx
    return a*(1-sy)+b*sy

def fbm(x,y,seed):
    return .53*noise(x,y,54,seed)+.29*noise(x,y,20,seed+10)+.13*noise(x,y,7,seed+20)+.05*noise(x,y,2,seed+30)

def clamp(x):
    return max(0,min(255,int(x)))

def produce(kind):
    color = bytearray(SIZE*SIZE*4)
    height = [[0.0]*SIZE for _ in range(SIZE)]
    roughness = bytearray(SIZE*SIZE*4)
    for y in range(SIZE):
        for x in range(SIZE):
            n=fbm(x,y, SEED+len(kind)*21)
            fine=hash2(x,y,SEED)
            if kind=="concrete":
                seams=min(x%128, 128-x%128, y%128,128-y%128)
                joints=0.3 if seams<2 else 1.0
                stains=max(0,fbm(x+113,y+53,33)-0.54)*1.5
                drip=max(0,noise(x,y,70,56)-.60) * 0.45
                val=(0.66+n*0.24-stains*.36-drip*.27)*joints
                rgb=(val*174+3, val*174+4, val*179+5)
                hh=n*.51 + fine*.03 + (1-joints)*(-0.1)
                r=0.90
            elif kind=="asphalt":
                puddle=noise(x,y,84,109)<.29
                grains=hash2(x*7,y*13,37)
                val=0.43+n*.20+grains*.055
                if puddle:
                    val*=.89
                rgb=(val*140+4,val*151+5,val*165+8)
                hh=n*.27 + grains*.11 + (0.015 if puddle else 0.0)
                r=.36 if puddle else .75
            elif kind=="rust":
                rust=noise(x,y,67,89)>.49
                val=0.42+n*.34
                rgb=(val*143 + (55 if rust else 0), val*140-(22 if rust else 0), val*147-(58 if rust else 0))
                hh=n*.75+fine*.2
                r=.81 if rust else .37
            elif kind=="tile":
                seam=(x%128<3 or y%128<3)
                val=0.58+n*.29 - (0.36 if seam else 0)
                rgb=(val*140,val*138,val*138)
                hh=n*.56-(.18 if seam else 0)
                r=.89
            else:
                val=0.15+n*.21
                rgb=(val*91,val*93,val*102)
                hh=n*.2 + fine*.02
                r=.31
            i=4*(y*SIZE+x)
            color[i:i+4]=bytes([clamp(rgb[0]),clamp(rgb[1]),clamp(rgb[2]),255])
            roughness[i:i+4]=bytes([clamp(r*255)]*3+[255])
            height[y][x]=hh
    normal=bytearray(SIZE*SIZE*4)
    for y in range(SIZE):
        for x in range(SIZE):
            h0=height[y][(x-1)%SIZE]-height[y][(x+1)%SIZE]
            h1=height[(y-1)%SIZE][x]-height[(y+1)%SIZE][x]
            vx=h0*1.5; vy=h1*1.5; vz=1.0
            length=math.sqrt(vx*vx+vy*vy+vz*vz)
            i=4*(y*SIZE+x)
            normal[i:i+4]=bytes([clamp((vx/length*.5+.5)*255),clamp((vy/length*.5+.5)*255),clamp((vz/length*.5+.5)*255),255])
    save_png(kind+"_albedo.png",color)
    save_png(kind+"_normal.png",normal)
    save_png(kind+"_roughness.png",roughness)
    print("TEXTURE_OK",kind)

for name in ["concrete","asphalt","tile","rust","leather"]:
    produce(name)
