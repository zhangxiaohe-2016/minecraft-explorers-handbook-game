class_name ExplorerWorld
extends Node3D

const HALF := 48
const CAMP := Vector3(-6, 2, -1)
const BENCH := Vector3(-1, 2, 2)
var art: ExplorerArt
var progress: ExpeditionProgress
var noise := FastNoiseLite.new()
var collectables: Dictionary = {}
var blueprint: Array[Vector3] = []
var cabin: Node3D
var ghost: MeshInstance3D
var bench_marker: Node3D
var door_node: Node3D
var door_open := false
var camp_sign: Label3D
var water: MeshInstance3D
var leaves: Array[Transform3D] = []

func setup(state: ExpeditionProgress, library: ExplorerArt) -> void:
	progress = state
	art = library
	noise.seed = 84236
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	terrain()
	vegetation()
	create_camp()
	create_temperate_landmark()
	create_forest_route()
	create_sunflowers()
	restore()

func river_x(z: float) -> float:
	return 18.0 + sin(z * 0.08) * 4.0

func height_at(x: int, z: int) -> int:
	var river_distance := absf(float(x) - river_x(z))
	if river_distance < 3.0: return 0
	if river_distance < 4.5: return 1
	if mansion_area(x,z):return 2
	if forest_area(x,z): return 2
	if village_area(x,z) or journey_road(x,z): return 2
	if x > -13 and x < 12 and z > -12 and z < 19: return 2
	var hill := maxf(0.0, float(-z - 13) / 8.0)
	return maxi(2, int(3.0 + noise.get_noise_2d(x, z) * 5.0 + hill))

func village_area(x: float,z: float) -> bool:
	return x>-39 and x<-10 and z>-40 and z<-11

func forest_area(x: float,z: float) -> bool:
	return x>=-43 and x<=-17 and z>=-10 and z<=36

func mansion_area(x: float,z: float) -> bool:
	return x>=-16 and x<=10 and z>=19 and z<=44

func journey_road(x: float,z: float) -> bool:
	var p:=Vector2(x,z)
	if absf(x+3)<1.5 and z>=12 and z<=22:return true
	if absf(x+32)<1.4 and z>=-18 and z<33:return true
	if absf(z-12)<1.4 and x>=-32 and x<=0:return true
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(-1,-8),Vector2(-23,-23)))<1.65

func terrain() -> void:
	for cx in range(-HALF, HALF, 16):
		for cz in range(-HALF, HALF, 16):
			var surfaces: Dictionary = {}
			for id in ["grass", "dirt", "sand", "stone"]:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[id] = st
			for x in range(cx, cx + 16):
				for z in range(cz, cz + 16):
					var h := float(height_at(x, z))
					var sandy := absf(float(x) - river_x(z)) < 5.0
					var path := (absf(float(x) + sin(float(z) * 0.2) * 1.5) < 1.4 and z < 15 and z > -19) or journey_road(x,z)
					var top_id := "sand" if sandy or path else ("stone" if h > 9 else "grass")
					ExplorerArt.quad(surfaces[top_id], [Vector3(x,h,z), Vector3(x+1,h,z), Vector3(x+1,h,z+1), Vector3(x,h,z+1)], Vector3.UP)
					for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var low := float(height_at(x+d.x,z+d.y))
						if x+d.x < -HALF or x+d.x >= HALF or z+d.y < -HALF or z+d.y >= HALF: low = -3.0
						if low >= h: continue
						var side: SurfaceTool = surfaces["sand" if sandy else "dirt"]
						if d.x == 1:
							ExplorerArt.quad(side, [Vector3(x+1,h,z),Vector3(x+1,low,z),Vector3(x+1,low,z+1),Vector3(x+1,h,z+1)],Vector3.RIGHT,Vector2(1,h-low))
						elif d.x == -1:
							ExplorerArt.quad(side, [Vector3(x,h,z+1),Vector3(x,low,z+1),Vector3(x,low,z),Vector3(x,h,z)],Vector3.LEFT,Vector2(1,h-low))
						elif d.y == 1:
							ExplorerArt.quad(side, [Vector3(x+1,h,z+1),Vector3(x+1,low,z+1),Vector3(x,low,z+1),Vector3(x,h,z+1)],Vector3.BACK,Vector2(1,h-low))
						else:
							ExplorerArt.quad(side, [Vector3(x,h,z),Vector3(x,low,z),Vector3(x+1,low,z),Vector3(x+1,h,z)],Vector3.FORWARD,Vector2(1,h-low))
			var mesh := ArrayMesh.new()
			for id in surfaces:
				var st: SurfaceTool = surfaces[id]
				if not st.has_meta("used"): continue
				st.set_material(art.materials[id])
				st.commit(mesh)
			var part := MeshInstance3D.new()
			part.mesh = mesh
			add_child(part)
			part.create_trimesh_collision()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode cull_disabled; void vertex(){ VERTEX.y += sin(VERTEX.x*1.8+TIME*1.0)*0.025+cos(VERTEX.z*1.6+TIME*0.8)*0.02; } void fragment(){ float r=sin(UV.x*600.0+sin(UV.y*180.0+TIME)*2.0+TIME)*sin(UV.y*380.0-TIME); ALBEDO=mix(vec3(0.10,0.42,0.48),vec3(0.32,0.65,0.64),smoothstep(0.60,0.95,r)); ROUGHNESS=0.22; METALLIC=0.25; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	water = art.box(self, Vector3(18, 0.8, 0), Vector3(16, 0.08, HALF*2), mat)
	# Distant stepped silhouettes are scenery; play area is the 96m terrain.
	var mountain_mat := art.color_mat(Color("667e79"))
	for i in range(17):
		var x := -90.0 + i * 12.0
		var h := 13.0 + sin(i * 2.4) * 6.0
		for tier in range(4):
			art.box(self, Vector3(x, h * (1.0 - tier * 0.19) * 0.5 - 1, -68), Vector3(19 - tier*3, h*(1.0-tier*0.19), 17+ tier*2), mountain_mat)

func vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9576
	var tree_positions := [Vector2(5,5),Vector2(7,0),Vector2(5,-5),Vector2(-10,9),Vector2(-10,2),Vector2(8,11),Vector2(10,-9)]
	for i in range(110):
		var p := Vector2(rng.randi_range(-43,43), rng.randi_range(-43,40))
		if absf(p.x-river_x(p.y)) < 7 or (p.x>-12 and p.x<12 and p.y>-12 and p.y<19): continue
		tree_positions.append(p)
	for i in tree_positions.size():
		var p: Vector2 = tree_positions[i]
		# Preserve old resource IDs: skip rendering after the unchanged position list is built.
		if village_area(p.x,p.y) or journey_road(p.x,p.y) or forest_area(p.x,p.y) or mansion_area(p.x,p.y): continue
		var y := height_at(int(p.x),int(p.y))
		var id := "tree_%d" % i
		if id in progress.harvested: continue
		var tree := Node3D.new()
		add_child(tree)
		tree.position = Vector3(p.x+0.5,y,p.y+0.5)
		var tall := 4 + (i%2)
		for j in tall:
			art.box(tree,Vector3(0,j+0.5,0),Vector3(0.82,1,0.82),art.materials.log)
		art.box(tree,Vector3(0,tall+0.01,0),Vector3(0.83,0.025,0.83),art.materials.log_top)
		for tier in range(3):
			var width := 4.2 - tier*0.95
			art.box(tree,Vector3(0,tall-0.6+tier*0.9,0),Vector3(width,1.3,width),art.materials.leaf)
		var body := StaticBody3D.new()
		body.set_meta("resource_id",id)
		body.set_meta("kind","log")
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.85,tall,0.85)
		shape.shape = box_shape
		shape.position.y = tall*0.5
		body.add_child(shape)
		tree.add_child(body)
		collectables[id] = tree
	for i in range(28):
		var p := Vector3(5+(i%6)*1.15,2.4,-7-(i/6)*1.2)
		var kind := "coal" if i%5==0 else "stone"
		var id := "rock_%d" % i
		if id in progress.harvested: continue
		var rock := art.box(self,p,Vector3(0.94,0.8+(i%3)*0.16,0.94),art.materials[kind],true)
		rock.get_child(0).set_meta("resource_id",id)
		rock.get_child(0).set_meta("kind",kind)
		collectables[id] = rock
	# One GPU-instanced batch per flower colour and grass, rather than nodes per blade.
	var batches: Dictionary = {"grass":[],"cream":[],"yellow":[],"red":[]}
	for i in range(1900):
		var x := rng.randf_range(-44,44)
		var z := rng.randf_range(-44,43)
		if village_area(x,z) or journey_road(x,z) or forest_area(x,z) or mansion_area(x,z): continue
		if absf(x-river_x(z))<5.5 or (x>-8 and x<3 and z>-4 and z<14): continue
		var y := float(height_at(int(floor(x)),int(floor(z))))
		var transform := Transform3D(Basis.IDENTITY,Vector3(x,y+0.17,z))
		transform.basis = transform.basis.scaled(Vector3(0.06,0.35,0.06))
		batches.grass.append(transform)
		if i%3==0:
			var flower := Transform3D(Basis.IDENTITY,Vector3(x,y+0.39,z))
			flower.basis = flower.basis.scaled(Vector3(0.19,0.10,0.19))
			batches[["cream","yellow","red"][i%7%3]].append(flower)
	for id in batches:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = batches[id].size()
		for i in mm.instance_count: mm.set_instance_transform(i,batches[id][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = art.color_mat({"grass":Color("628840"),"cream":Color("f3e9bf"),"yellow":Color("efc957"),"red":Color("c46e51")}[id])
		add_child(instance)
	var cloud_mat := art.color_mat(Color("e9efdb"))
	for i in range(14):
		var x := rng.randf_range(-65,65)
		var z := rng.randf_range(-65,45)
		art.box(self,Vector3(x,28+i%3*3,z),Vector3(9+i%4*3,0.8,3+i%3*2),cloud_mat)

func create_camp() -> void:
	cabin = Node3D.new()
	add_child(cabin)
	# 4×5 footprint, two-block walls, flat stone roof; source: Home Sweet Home.
	for x in range(4):
		for z in range(5):
			art.box(self,CAMP+Vector3(x,0.035,z),Vector3(1,0.07,1),art.materials.plank)
			if x==0 or x==3 or z==0 or z==4:
				for y in range(2):
					if z==4 and x==1: continue
					blueprint.append(CAMP+Vector3(x,y+0.5,z))
	for x in range(4):
		for z in range(5): blueprint.append(CAMP+Vector3(x,2.5,z))
	ghost = art.box(self,Vector3.ZERO,Vector3.ONE*1.015,art.color_mat(Color(0.88,0.76,0.41,0.35),true))
	bench_marker = Node3D.new()
	add_child(bench_marker)
	art.box(bench_marker,BENCH+Vector3(0,0.06,0),Vector3(1.3,0.10,1.3),art.color_mat(Color("d2ac64")))
	art.label(bench_marker,"工作台位置",BENCH+Vector3(0,1.2,0))
	camp_sign = art.label(self,"林地营地\n一处安心出发的地方",Vector3(-5,5.5,1))
	art.label(self,"石丘 · 圆石与煤",Vector3(8,4.4,-9),Color("e4ead2"))
	art.label(self,"橡树林 · 原木",Vector3(5,7.5,5),Color("e4ead2"))
	# Trail marker and fence create an identifiable starting vista.
	for x in [-9.5,2.5]:
		for z in [7.5,9.5,11.5]:
			art.box(self,Vector3(x,2.7,z),Vector3(0.18,1.4,0.18),art.materials.plank,true)
		for z in [8.5,10.5]:
			for y in [2.5,3.0]:
				art.box(self,Vector3(x,y,z),Vector3(0.12,0.12,2),art.materials.plank)
	art.torch(self,Vector3(-9.5,3.4,7.5))
	art.torch(self,Vector3(2.5,3.4,7.5))
	art.box(self,Vector3(0,2.05,13),Vector3(3.6,0.1,2.0),art.materials.plank)

func create_temperate_landmark() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(-32, 2, -4)
	for x in [-1.4, 1.4]:
		for z in [-1.4, 1.4]:
			art.box(root, Vector3(x, 1.8, z), Vector3(0.28, 3.6, 0.28), art.materials.log, true)
	for y in [0.25, 3.45]:
		art.box(root, Vector3(0, y, -1.4), Vector3(3.1, 0.22, 0.22), art.materials.plank)
		art.box(root, Vector3(0, y, 1.4), Vector3(3.1, 0.22, 0.22), art.materials.plank)
		art.box(root, Vector3(-1.4, y, 0), Vector3(0.22, 0.22, 3.1), art.materials.plank)
		art.box(root, Vector3(1.4, y, 0), Vector3(0.22, 0.22, 3.1), art.materials.plank)
	art.box(root, Vector3(0, 3.62, 0), Vector3(3.2, 0.22, 3.2), art.materials.roof)
	# Ground-level wayfinding shelter: the previous isolated steps led nowhere.
	art.torch(root, Vector3(0, 3.75, -1.12))
	art.label(self, "森林瞭望台\n路线与地标", Vector3(-32, 6.0, -4), Color("e4ead2"))
	art.chest(self, Vector3(-30.2, 2, -0.55), "lookout")
	art.label(self, "瞭望台补给\nE  查看", Vector3(-30.2, 3.8, -0.55), Color("f3d279")).pixel_size=0.004

func create_sunflowers() -> void:
	var green:=art.color_mat(Color("40763b"))
	var yellow:=art.color_mat(Color("f2cb35"))
	var center:=art.color_mat(Color("a9762b"))
	for i in range(12):
		var x: float=-15+(i%3)*0.9
		var z: float=3+(i/3)*1.1
		var plant:=Node3D.new()
		plant.name="Sunflower%d"%i
		add_child(plant)
		plant.position=Vector3(x,height_at(floori(x),floori(z)),z)
		art.box(plant,Vector3(0,0.85,0),Vector3(0.06,1.7,0.06),green)
		for level in range(3):
			art.box(plant,Vector3(0,0.45+level*0.35,0.13 if level%2==0 else -0.13),Vector3(0.07,0.13,0.25),green)
		# All golden flower faces point +X (east), never toward the camera.
		art.box(plant,Vector3(-0.04,1.65,0),Vector3(0.05,0.4,0.4),green)
		for j in range(8):
			var angle:=j*TAU/8
			art.box(plant,Vector3(0.02,1.65+sin(angle)*0.2,cos(angle)*0.2),Vector3(0.08,0.16,0.16),yellow)
		var face:=art.box(plant,Vector3(0.075,1.65,0),Vector3(0.07,0.23,0.23),center,true)
		art.mark(face,"sunflower")
		face.get_child(0).collision_layer=2
		plant.set_meta("flower_direction",Vector3.RIGHT)
	art.label(self,"向日葵 · E 观察方向",Vector3(-14,4.7,5)).pixel_size=0.003

func create_forest_route() -> void:
	var white := art.color_mat(Color("dddcd1"))
	var bark := art.color_mat(Color("41413d"))
	var dark_wood := art.color_mat(Color("473624"))
	var dark_leaf := art.materials.leaf.duplicate() as StandardMaterial3D
	dark_leaf.albedo_color=Color("798b65")
	for region in range(3):
		var z := 4+region*12
		var id: String=["flower","birch","dark"][region]
		var title: String=["繁花森林","白桦林","黑森林"][region]
		var sign := art.box(self,Vector3(-30,3.2,z),Vector3(1.5,0.9,0.15),art.materials.plank,true)
		art.mark(sign,"forest",id)
		art.box(self,Vector3(-30,2.5,z),Vector3(0.12,1,0.12),art.materials.log)
		var label := art.label(self,title+"\nE  观察记录",Vector3(-30,4.1,z))
		label.pixel_size=0.004
		for i in range(4 if region==0 else 10):
			var x := -40.0+(i%2)*18
			var tz := float(z-4+(i/2)*2)
			var height := 5.0+(i%3)
			var tree_id := "forest_"+id+"_"+str(i)
			if tree_id in progress.harvested:continue
			var tree := Node3D.new()
			add_child(tree)
			tree.position=Vector3(x,2,tz)
			var trunk := art.box(tree,Vector3(0,height/2,0),Vector3(0.9,height,0.9),white if region==1 else (dark_wood if region==2 else art.materials.log),true)
			trunk.get_child(0).set_meta("resource_id",tree_id)
			trunk.get_child(0).set_meta("kind","log")
			collectables[tree_id]=tree
			if region==1:
				for j in range(int(height)):
					art.box(tree,Vector3(0.12*(j%2),j+0.4,0),Vector3(0.93,0.12,0.93),bark)
			art.box(tree,Vector3(0,height,0),Vector3(6 if region==2 else 4,2.4,5),dark_leaf if region==2 else art.materials.leaf)
		if region==0:
			for i in range(72):
				var p := Vector3(-28+(i%9)*0.7,2.3,1+(i/9)*0.7)
				art.box(self,p,Vector3(0.05,0.6,0.05),art.materials.leaf)
				art.box(self,p+Vector3(0,0.3,0),Vector3(0.3,0.12,0.3),art.color_mat([Color("e86662"),Color("e2b4de"),Color("ffd264")][i%3]))
		if region==2:
			art.box(self,Vector3(-26,4,29),Vector3(0.9,4,0.9),white,true)
			art.box(self,Vector3(-26,6,29),Vector3(4.5,0.9,4.5),art.color_mat(Color("ad3530")))
			for i in range(9):
				art.box(self,Vector3(-27.5+(i%3)*1.5,6.46,27.5+(i/3)*1.5),Vector3(0.35,0.025,0.35),white)
			for i in range(4):
				for side in [-1,1]:
					art.box(self,Vector3(-27.5+i,6,29+side*2.26),Vector3(0.22,0.22,0.025),white)
					art.box(self,Vector3(-26+side*2.26,6,27.5+i),Vector3(0.025,0.22,0.22),white)
	art.label(self,"森林 ↓\n营地 →",Vector3(-32,4.3,12)).pixel_size=0.004

func restore() -> void:
	for index in progress.built:
		if index >= 0 and index < blueprint.size():
			art.box(cabin,blueprint[index],Vector3.ONE,art.materials.stone,true)
	if progress.has_flag("bench"):
		bench_marker.hide()
		art.bench(self,BENCH)
	if progress.has_flag("door"): create_door()
	if progress.has_flag("torch"): art.torch(self,CAMP+Vector3(0.7,0.3,1.2))
	if progress.has_flag("furnace"): art.furnace(self,BENCH+Vector3(2,0,0))
	update_ghost()

func update_ghost() -> void:
	ghost.visible = progress.has_flag("gathered_stone") and progress.built.size()<blueprint.size()
	for i in blueprint.size():
		if i not in progress.built:
			ghost.position = blueprint[i]
			return

func build_next() -> bool:
	for i in blueprint.size():
		if i not in progress.built:
			if not progress.build_block(i): return false
			art.box(cabin,blueprint[i],Vector3.ONE,art.materials.stone,true)
			if progress.built.size()==blueprint.size():
				progress.flags.shelter = true
				progress.save_game()
			update_ghost()
			return true
	return false

func create_door() -> void:
	door_node = Node3D.new()
	add_child(door_node)
	door_node.position = CAMP+Vector3(0.5,0,4.42)
	# Door frame with four upper windows, following the book's oak door.
	var planks: Material = art.materials.plank
	art.box(door_node,Vector3(0.5,0.45,0),Vector3(0.94,0.9,0.13),planks)
	for x in [0.04,0.48,0.92]:
		art.box(door_node,Vector3(x,1.4,0),Vector3(0.1,1.1,0.13),planks)
	for y in [0.96,1.45,1.94]:
		art.box(door_node,Vector3(0.48,y,0),Vector3(0.94,0.1,0.13),planks)
	art.box(door_node,Vector3(0.8,0.8,0.11),Vector3(0.1,0.1,0.12),art.color_mat(Color("544a31")))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var rect := BoxShape3D.new()
	rect.size = Vector3(0.94,2,0.14)
	shape.shape = rect
	shape.position = Vector3(0.48,1,0)
	body.add_child(shape)
	body.set_meta("door",true)
	door_node.add_child(body)

func toggle_door() -> void:
	if not is_instance_valid(door_node): return
	door_open = not door_open
	create_tween().tween_property(door_node,"rotation:y",-PI/2 if door_open else 0.0,0.25)

func inside_house(pos: Vector3) -> bool:
	return pos.x>CAMP.x+0.5 and pos.x<CAMP.x+2.5 and pos.z>CAMP.z+0.5 and pos.z<CAMP.z+3.5 and pos.y<5
