class_name ExplorerArt
extends RefCounted

var materials: Dictionary = {}
var meshes: Dictionary = {}
var box_materials: Dictionary = {}

func _init() -> void:
	for id in ["grass", "dirt", "sand", "stone", "coal", "plank", "log", "log_top", "leaf", "bench_top", "bench_side", "furnace", "wool", "roof", "soil", "cloth", "villager_face", "cartography"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/" + id + ".png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.roughness = 0.95
		materials[id] = mat

func color_mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if not meshes.has(size):
		var cube := BoxMesh.new()
		cube.size = size
		meshes[size] = cube
	instance.mesh = meshes[size]
	if mat is BaseMaterial3D and mat.albedo_texture != null:
		var key := mat.get_instance_id()
		if not box_materials.has(key):
			var tiled: BaseMaterial3D = mat.duplicate()
			tiled.uv1_scale = Vector3(3, 2, 1)
			box_materials[key] = tiled
		instance.material_override = box_materials[key]
	else:
		instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		instance.add_child(body)
	return instance

func label(parent: Node3D, text: String, pos: Vector3, color := Color("fff0c9")) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
	node.font = font
	node.font_size = 36
	node.pixel_size = 0.007
	node.modulate = color
	node.outline_modulate = Color("253a32")
	node.outline_size = 8
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	parent.add_child(node)
	return node

func bench(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	box(root, Vector3(0, 0.5, 0), Vector3.ONE, materials.bench_side, true)
	box(root, Vector3(0, 1.005, 0), Vector3(1.005, 0.015, 1.005), materials.bench_top)
	return root

func wood_sword(parent: Node3D) -> Node3D:
	var root:=Node3D.new()
	root.name="WoodSword"
	parent.add_child(root)
	var edge:=color_mat(Color("654727"))
	var blade:=color_mat(Color("b68b48"))
	box(root,Vector3(0,0.1,0),Vector3(0.055,0.24,0.065),edge)
	box(root,Vector3(0,-0.03,0),Vector3(0.09,0.06,0.08),edge)
	box(root,Vector3(0,0.24,0),Vector3(0.29,0.065,0.08),edge)
	for row in range(9):
		var width:=0.14 if row<7 else (0.10 if row==7 else 0.055)
		box(root,Vector3(0,0.3+row*0.065,0),Vector3(width,0.066,0.065),edge)
		box(root,Vector3(-0.008,0.3+row*0.065,0.035),Vector3(width*0.65,0.066,0.008),blade)
	return root

func pickaxe(parent: Node3D, head_color: Color) -> Node3D:
	var root:=Node3D.new()
	root.name="Pickaxe"
	parent.add_child(root)
	var handle:=color_mat(Color("6b4a2a"))
	var head:=color_mat(head_color)
	box(root,Vector3(0,0.12,0),Vector3(0.07,0.42,0.07),handle)
	box(root,Vector3(0,0.34,0),Vector3(0.42,0.08,0.09),head)
	box(root,Vector3(-0.2,0.28,0),Vector3(0.1,0.1,0.08),head)
	box(root,Vector3(0.2,0.28,0),Vector3(0.1,0.1,0.08),head)
	return root

func furnace(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	box(root, Vector3(0, 0.5, 0), Vector3.ONE, materials.stone, true)
	box(root, Vector3(0, 0.5, 0.508), Vector3(0.99, 0.99, 0.012), materials.furnace)
	return root

func mark(node: Node, kind: String, id := "") -> void:
	if node is StaticBody3D:
		node.set_meta("journey_kind",kind)
		node.set_meta("journey_id",id)
	for child in node.get_children(): mark(child,kind,id)

func bed(parent: Node3D, pos: Vector3, id := "camp") -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position=pos
	for x in [-0.35,0.35]:
		for z in [-0.75,0.75]: box(node,Vector3(x,0.17,z),Vector3(0.12,0.34,0.12),materials.plank)
	box(node,Vector3(0,0.3,0),Vector3(0.98,0.13,1.95),materials.plank)
	box(node,Vector3(0,0.44,0),Vector3(0.98,0.23,1.95),materials.wool,true)
	box(node,Vector3(0,0.58,-0.63),Vector3(0.87,0.08,0.55),color_mat(Color("faf8ee")))
	mark(node,"bed",id)
	return node

func chest(parent: Node3D,pos: Vector3,id := "supplies") -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position=pos
	box(node,Vector3(0,0.44,0),Vector3(0.95,0.88,0.85),materials.plank,true)
	var rim:=color_mat(Color("4b3824"))
	for x in [-0.455,0.455]: box(node,Vector3(x,0.44,0.432),Vector3(0.06,0.88,0.025),rim)
	for y in [0.04,0.58,0.85]:box(node,Vector3(0,y,0.432),Vector3(0.93,0.06,0.025),rim)
	box(node,Vector3(0,0.54,0.46),Vector3(0.12,0.24,0.055),color_mat(Color("c4c4ac")))
	mark(node,"chest",id)
	return node

func villager(parent: Node3D,pos: Vector3,profession: String) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	node.position=pos
	var robe:=color_mat(Color("806247") if profession=="farmer" else Color("775c4c"))
	var skin:=color_mat(Color("b99579"))
	for x in [-0.14,0.14]:box(node,Vector3(x,0.22,0),Vector3(0.23,0.44,0.3),color_mat(Color("493f31")))
	box(node,Vector3(0,0.95,0),Vector3(0.63,1.15,0.41),robe,true)
	box(node,Vector3(0,1.72,0),Vector3(0.56,0.64,0.52),skin)
	box(node,Vector3(0,1.72,0.269),Vector3(0.56,0.64,0.015),materials.villager_face)
	box(node,Vector3(0,1.52,0.36),Vector3(0.15,0.33,0.22),skin)
	box(node,Vector3(0,1.13,0.31),Vector3(0.73,0.23,0.28),robe)
	box(node,Vector3(0.2,1.13,0.34),Vector3(0.13,0.23,0.22),skin)
	if profession=="farmer":
		box(node,Vector3(0,2.04,0),Vector3(0.94,0.12,0.86),materials.cloth)
		box(node,Vector3(0,2.15,0),Vector3(0.59,0.18,0.56),materials.roof)
	else:
		box(node,Vector3(0.19,1.78,0.288),Vector3(0.17,0.19,0.026),color_mat(Color("d6bb69")))
		box(node,Vector3(0.19,1.78,0.308),Vector3(0.115,0.125,0.015),color_mat(Color("d1e0db")))
	mark(node,"villager",profession)
	return node

func cartography_table(parent: Node3D,pos: Vector3) -> Node3D:
	var node:=Node3D.new()
	parent.add_child(node)
	node.position=pos
	box(node,Vector3(0,0.5,0),Vector3.ONE,materials.log,true)
	box(node,Vector3(0,1.012,0),Vector3(1,0.024,1),materials.cartography)
	mark(node,"cartography")
	return node

func torch(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	box(root, Vector3(0, 0.34, 0), Vector3(0.11, 0.68, 0.11), materials.plank)
	var flame := color_mat(Color("ffce64"), true)
	box(root, Vector3(0, 0.74, 0), Vector3(0.15, 0.22, 0.15), flame)
	box(root, Vector3(0, 0.84, 0), Vector3(0.08, 0.16, 0.08), color_mat(Color("fff4c7"), true))
	var light := OmniLight3D.new()
	light.position.y = 0.85
	light.light_color = Color("ffc27a")
	light.light_energy = 1.8
	light.omni_range = 8.0
	light.shadow_enabled = true
	root.add_child(light)
	return root

static func quad(st: SurfaceTool, corners: Array, normal: Vector3, uv_scale := Vector2.ONE) -> void:
	st.set_meta("used", true)
	var uv := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uv[i] * uv_scale)
		st.add_vertex(corners[i])
