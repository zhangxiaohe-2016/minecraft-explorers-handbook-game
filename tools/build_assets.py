"""Deterministic authored pixel textures; no external game assets required."""
from pathlib import Path
import random, struct, zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'textures'
OUT.mkdir(parents=True, exist_ok=True)

def png(name, pixels, size=16):
    raw = b''.join(b'\0' + bytes(c for rgb in row for c in rgb) for row in pixels)
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))
    (OUT / (name + '.png')).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size,size,8,2,0,0,0)) + chunk(b'IDAT',zlib.compress(raw)) + chunk(b'IEND', b''))

def rgb(hexstr): return tuple(bytes.fromhex(hexstr))

def make(name, colors, mode='noise'):
    rng = random.Random(name)
    pal = [rgb(c) for c in colors]
    p = [[rng.choice(pal) for x in range(16)] for y in range(16)]
    for y in range(16):
        for x in range(16):
            if mode == 'plank':
                p[y][x] = pal[0] if y%4==0 or (x + (y//4%2)*8)%16==0 else pal[1+rng.randrange(len(pal)-1)]
            if mode == 'bark':
                p[y][x] = pal[(x//2 + (1 if y%7==0 else 0))%len(pal)]
            if mode == 'ring':
                d = min(x,y,15-x,15-y)
                p[y][x] = pal[d%len(pal)]
            if mode == 'cobble':
                centers = [(2,2),(7,1),(12,2),(1,7),(6,6),(12,7),(3,12),(8,11),(13,13)]
                ds = sorted((min(abs(x-cx),16-abs(x-cx))**2 + min(abs(y-cy),16-abs(y-cy))**2,i) for i,(cx,cy) in enumerate(centers))
                seam = ds[1][0]-ds[0][0] < 6
                base = pal[1+ds[0][1]%(len(pal)-1)]
                p[y][x] = pal[0] if seam else tuple(max(0,min(255,c+rng.randrange(-8,9))) for c in base)
            if mode == 'bench_top':
                p[y][x] = rgb('513621') if x in [0,1,5,10,14,15] or y in [0,1,5,10,14,15] else pal[rng.randrange(len(pal))]
            if mode == 'bench_side':
                p[y][x] = pal[rng.randrange(len(pal))]
                if x in [0,1,14,15] or y<3: p[y][x]=rgb('503420')
                if x in [4,5,10,11] and 5<y<13: p[y][x]=rgb('aeb0a4')
                if y==12 and 5<x<11: p[y][x]=rgb('594029')
            if mode == 'furnace':
                if 3<=x<=12 and (3<=y<=6 or 10<=y<=13): p[y][x]=rgb('252e31')
                if y in [2,9] and 2<=x<=13: p[y][x]=rgb('a5aba7')
                if y==14 and 3<=x<=12: p[y][x]=rgb('4b5352')
            if mode == 'coal':
                if ((x//2)*7 + (y//2)*3)%11<3: p[y][x]=rgb('303839')
    png(name,p)

make('grass',['688c38','789844','819f49','739640','87a64d'])
make('dirt',['77543c','876047','987052','694b37'])
make('sand',['d6c99b','dfd2a7','e2d5ae','cdbf8e'])
make('stone',['555b60','9b9fa3','b5b5b0','7d8589'], 'cobble')
make('coal',['778385','8c9794','929a94','6e797b'],'coal')
make('plank',['77532e','c49755','bd8c4b','d4ab67'],'plank')
make('log',['543b25','76502d','916636','62472b'],'bark')
make('log_top',['79552f','b78b4d','c49a58','98713e'],'ring')
make('leaf',['3e6636','49783b','588543','648f48','71974c'])
make('bench_top',['bd8548','c59053','ad713d'],'bench_top')
make('bench_side',['bb8f51','c99e61','a97d44'],'bench_side')
make('furnace',['8c9490','77837f','939b94','697570'],'furnace')
print('Generated', len(list(OUT.glob('*.png'))), 'pixel textures')
make('wool',['e3e3db','efeee7','d8d9d2','f4f1e8'])
make('roof',['71512e','bd995d','c6a469','ac864b'],'plank')
make('soil',['594333','674e38','74583c','493929'])
make('cloth',['eddfa4','f2e8ba','ded09a','f7efc9'])
# A authored 16px face: brow, eyes, nose and robe colours match the village reference.
face=[[rgb('b99579') for x in range(16)] for y in range(16)]
for y in range(16):
 for x in range(16):
  if y<3: face[y][x]=rgb('a27c63')
  if y in [5,6] and 2<=x<=13: face[y][x]=rgb('503d2c')
  if y in [7,8] and x in [3,4,5,10,11,12]:face[y][x]=rgb('efe9db')
  if y in [7,8] and x in [4,11]:face[y][x]=rgb('4a6b46')
  if y in [13,14] and 5<=x<=10:face[y][x]=rgb('7a5843')
png('villager_face',face)
# Cartography table top: parchment map and compass on dark wood.
cart=[[rgb('67492c') for x in range(16)] for y in range(16)]
for y in range(16):
 for x in range(16):
  if 2<=x<=13 and 6<=y<=13:cart[y][x]=rgb('ead8a1') if (x+y)%4 else rgb('c8b77e')
  if 2<=x<=5 and 1<=y<=4:cart[y][x]=rgb('b9bab0')
  if (x,y) in [(3,2),(4,3)]:cart[y][x]=rgb('b44939')
png('cartography',cart)

def food_icon(name, colors, rows):
    assert len(rows)==16 and all(len(row)==16 for row in rows)
    palette = {key: rgb(value) for key,value in colors.items()}
    pixels=[]
    for row in rows:
        pixels.append([palette[key]+(255,) if key!='.' else (0,0,0,0) for key in row])
    raw=b''.join(b'\0'+bytes(c for p in row for c in p) for row in pixels)
    def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data))
    (OUT/(name+'.png')).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',16,16,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
steak=[
'................','................','...........dd...','..........dhmd..','.........dhmmd..','.......ddhmmmd..','....dddhhmmmd...','...dhhhhmmmmd...','..dhhhhmmmmd....','.dhhhhmmmmmd....','.dhhmmmmmmmd....','.dmmmmmmmmd.....','..dmmmmmmd......','...dddddd.......','................','................']
food_icon('raw_beef',{'d':'812a2c','m':'b9373e','h':'e96e63'},steak)
food_icon('cooked_beef',{'d':'4b342c','m':'76503b','h':'a87a50'},steak)
bread=['................','................','................','.......dddd.....','.....ddhhmmd....','....dhhmhmmmd...','...dhhmhhmmmd...','..dhhhmhhmmmd...','.dhhmhhmmmmmd...','.dhmhhhmmmmd....','.dhhhhhmmmd.....','..dmmmmmmmd.....','...ddddddd......','................','................','................']
food_icon('bread',{'d':'79502d','m':'ad793d','h':'dab369'},bread)
