extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var art := ExplorerArt.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bcc7b6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d6ded1")
	env.environment.ambient_light_energy = 0.6
	env.environment.ssao_enabled = true
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-27,0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.position = Vector3(6.5,7,11)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.6,-0.8))
	art.box(scene,Vector3(0,-0.22,-1),Vector3(40,0.3,40),art.color_mat(Color("8c9a85")))
	var names := ["木镐","石斧","火把","工作台","熔炉","木门"]
	for i in range(6):
		var pos := Vector3((i%3-1)*3,0,1.7 if i<3 else -2)
		art.box(scene,pos,Vector3(2.3,0.4,2.1),art.color_mat(Color("354b40")))
		art.label(scene,names[i],pos+Vector3(0,0.5,1.25))
		if i<3:
			var id: String = ["wood_pickaxe","stone_axe","torch"][i]
			var prop: Node3D = load("res://assets/models/"+id+".glb").instantiate()
			scene.add_child(prop)
			prop.position = pos+Vector3(0,0.9,0)
			prop.scale = Vector3.ONE*1.6
		elif i==3: art.bench(scene,pos+Vector3(0,0.2,0))
		elif i==4: art.furnace(scene,pos+Vector3(0,0.2,0))
		else:
			var door_world := ExplorerWorld.new()
			door_world.art = art
			scene.add_child(door_world)
			door_world.create_door()
			door_world.door_node.position = pos+Vector3(-0.5,0.2,0)
	var overlay := ExplorerHUD.new()
	scene.add_child(overlay)
	overlay.set_process(false)
	var display_font := FontVariation.new()
	display_font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	display_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
	overlay.font = display_font
	var control := Control.new()
	overlay.add_child(control)
	overlay.text(control,"方境  /  第一组道具样板",Vector2(42,27),Vector2(1000,52),32,Color("22392c"))
	overlay.text(control,"依据手册插图重建  ·  真实 3D 模型与像素纹理",Vector2(44,87),Vector2(1100,31),17,Color("354b40"))
	await create_timer(3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/prop-study.png")
	print("Saved prop-study.png")
	quit()
