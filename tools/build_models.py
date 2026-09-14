"""Run with Blender --background --python tools/build_models.py.
Reconstructed pixel silhouettes referencing book images page017/page018.
Each pixel has physical thickness; preserve flat edges and a small palette.
"""
import bpy
from pathlib import Path
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)

PALETTE = {'d':'493721','h':'91672f','H':'b08a43','e':'414846','m':'8d9690','M':'c3c8bb','w':'79552c','W':'b3934b','f':'f7b537','F':'fff2b0'}
MATS = {}
for key, color in PALETTE.items():
    m = bpy.data.materials.new(key)
    def linear(v): return v/12.92 if v <= 0.04045 else ((v+0.055)/1.055)**2.4
    m.diffuse_color = tuple(linear(int(color[i:i+2],16)/255) for i in (0,2,4))+(1,)
    m.use_nodes = True
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=m.diffuse_color
    bsdf.inputs['Roughness'].default_value=.92
    MATS[key]=m

PICK = [
'................',
'.....eeeeee.....',
'...eeMMMMMMe....',
'..eMMMMmmmmMe...',
'...eeeeehdmMMe..',
'.......hHdemMe..',
'......hHd.emMe..',
'.....hHd..emMe..',
'....hHd....eMe..',
'...hHd.....eMe..',
'..hHd.......e...',
'.hHd............',
'.dd.............',
'................',
]
AXE = [
'................',
'.......ee.......',
'......eMMe......',
'.....eMMMMe.....',
'....eMMMMMme....',
'....emMMmMMMe...',
'.....eehHeMe....',
'......hHd.ee....',
'.....hHd........',
'....hHd.........',
'...hHd..........',
'..hHd...........',
'.hHd............',
'.dd.............',
]
TORCH = ['....FF....','...FFFF...','...FffF...','....ff....','....HH....','....Hh....','....Hh....','....Hh....','....Hh....','....Hh....','....Hd....']

def export(name, rows, wood=False):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    cubes=[]
    for y,row in enumerate(rows):
        for x,key in enumerate(row):
            if key=='.': continue
            if wood: key={'e':'d','m':'w','M':'W'}.get(key,key)
            bpy.ops.mesh.primitive_cube_add(size=1, location=((x-7.5)*.061, 0, (len(rows)-y-4)*.061))
            obj=bpy.context.object
            obj.scale=(.061,.080,.061)
            bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
            obj.data.materials.append(MATS[key]); cubes.append(obj)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=cubes[0]
    bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    source = OUT.parents[1] / 'source_models'
    source.mkdir(exist_ok=True)
    (source / '.gdignore').touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)

export('wood_pickaxe',PICK,True)
export('stone_axe',AXE)
export('torch',TORCH)
print('Exported tool samples to', OUT)
