extends Node3D

var progress := ExpeditionProgress.new()
var art := ExplorerArt.new()
var world: ExplorerWorld
var player: ExplorerPlayer
var hud: ExplorerHUD
var sun: DirectionalLight3D
var environment: Environment
var target: Dictionary = {}
var gather_id := ""
var gather_time := 0.0
var build_time := 0.0
var autosave_time := 0.0
var update_time := 0.0
var slot := 0
var night := false
var night_elapsed := 0.0
var next_step := -1
var ambience: AudioStreamPlayer
var smoke_mode := false
var journey: VillageJourney

func _ready() -> void:
	smoke_mode = "--smoke" in OS.get_cmdline_user_args()
	if smoke_mode or "--capture" in OS.get_cmdline_user_args() or "--integration" in OS.get_cmdline_user_args(): progress.save_enabled = false
	else: progress.load_game()
	if "--integration" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--fixture="):
				progress.save_path=argument.trim_prefix("--fixture=")
				progress.load_game()
	setup_input()
	setup_light()
	world = ExplorerWorld.new()
	add_child(world)
	world.setup(progress,art)
	player = ExplorerPlayer.new()
	add_child(player)
	player.position = Vector3(-0.5,2.15,12)
	player.rotation.y = 0.12
	player.camera.rotation.x = -0.04
	if progress.position.size()==3:
		player.position = Vector3(progress.position[0],progress.position[1],progress.position[2])
	if progress.look.size()==2:
		player.rotation.y = progress.look[0]
		player.camera.rotation.x = progress.look[1]
	hud = ExplorerHUD.new()
	add_child(hud)
	hud.setup(progress)
	hud.action.connect(on_action)
	hud.select_slot(0)
	progress.changed.connect(func(): hud.refresh())
	journey = VillageJourney.new()
	journey.game = self
	add_child(journey)
	set_modal("welcome")
	get_tree().auto_accept_quit = false
	if smoke_mode:
		get_tree().create_timer(2).timeout.connect(run_smoke)
	elif "--capture" in OS.get_cmdline_user_args():
		get_tree().create_timer(5).timeout.connect(capture_preview)

func setup_input() -> void:
	var mapping := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"sprint":KEY_SHIFT}
	for id in mapping:
		if not InputMap.has_action(id): InputMap.add_action(id)
		var event := InputEventKey.new()
		event.physical_keycode = mapping[id]
		InputMap.action_add_event(id,event)

func setup_light() -> void:
	var we := WorldEnvironment.new()
	environment = Environment.new()
	we.environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5e96a5")
	sky_mat.sky_horizon_color = Color("d1dbc0")
	sky_mat.ground_bottom_color = Color("546349")
	sky_mat.ground_horizon_color = Color("c6d2b9")
	sky_mat.sun_angle_max = 12.0
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d2cc")
	environment.ambient_light_energy = 0.43
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8cbbc")
	environment.fog_density = 0.0025
	environment.fog_sky_affect = 0.15
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.3
	environment.glow_enabled = true
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-32,0)
	sun.light_color = Color("ffe9cd")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	sun.shadow_blur = 1.3
	add_child(sun)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			if hud.current_modal=="compass": close_modal()
			elif hud.current_modal=="": journey.open_panel("compass")
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if hud.current_modal == "": set_modal("pause")
			else: close_modal()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			if hud.current_modal == "craft": close_modal()
			elif hud.current_modal == "": set_modal("craft")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_J:
			if hud.current_modal == "journal": close_modal()
			elif hud.current_modal == "": set_modal("journal")
		elif event.physical_keycode in [KEY_M, KEY_F]:
			var panel := "map" if event.physical_keycode == KEY_M else "food"
			if hud.current_modal == panel: close_modal()
			elif hud.current_modal == "": journey.open_panel(panel)
			get_viewport().set_input_as_handled()
		elif player.active:
			match event.physical_keycode:
				KEY_E: interact()
				KEY_N: start_night()
				KEY_1: equip(0)
				KEY_2: equip(1)
				KEY_3: equip(2)
				KEY_4: equip(3)
	elif event is InputEventMouseButton and event.pressed and player.active:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: equip((slot+3)%4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: equip((slot+1)%4)

func equip(index: int) -> void:
	var id: String = ["", "wood_pickaxe", "stone_axe", "torch"][index]
	if id != "" and progress.count(id)==0:
		hud.toast("还没有这件道具，按 Tab 查看配方。")
		return
	slot = index
	player.hold(id)
	hud.select_slot(index)

func _process(delta: float) -> void:
	if not is_instance_valid(hud): return
	if not player.active: return
	if player.walked > 2.0 and not progress.has_flag("moved"):
		progress.flags.moved = true
		progress.save_game()
	if player.position.y < -4:
		journey.respawn()
	if absf(player.position.x)>46 or absf(player.position.z)>46:
		return_camp()
		hud.toast("已回到营地。第一章的探索范围到这里为止。")
	if player.position.y<0.95 and absf(player.position.x-world.river_x(player.position.z))<4.0:
		return_camp()
		hud.toast("水域探索将在后续章节开放，先在岸上练习吧。")
	target = player.ray()
	update_time += delta
	if update_time > 0.12:
		update_time = 0
		update_hint()
		if next_step != progress.stage():
			next_step = progress.stage()
			hud.refresh()
			world.update_ghost()
	update_gather(delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and progress.stage()==5 and near_cabin():
		build_time -= delta
		if build_time<=0:
			build_time = 0.18
			if player.position.distance_to(world.ghost.position)<0.9:
				hud.toast("退开一点，给这块墙留出位置。")
			elif world.build_next():
				hud.refresh()
				player.swing = 1
				tone(175,0.06,0.10)
			else:
				hud.toast("圆石用完了。拿上木镐，再去石丘采集。")
	else: build_time = 0
	if night: update_night(delta)
	autosave_time += delta
	if autosave_time > 6:
		autosave_time = 0
		save()

func near_cabin() -> bool:
	return Vector2(player.position.x+4.5,player.position.z-1).length()<7.0

func near_workbench() -> bool:
	if progress.has_flag("bench") and player.position.distance_to(ExplorerWorld.BENCH)<4.0: return true
	if journey!=null and journey.village!=null:
		for pos in journey.village.workbenches:
			if player.position.distance_to(pos)<4.0:return true
	return false

func update_hint() -> void:
	var message := ""
	if not target.is_empty():
		var body: Object = target.collider
		if body.has_meta("resource_id"):
			var kind: String = body.get_meta("kind")
			message = state_item(kind) + "\n按住左键  采集"
			if kind in ["stone","coal"] and player.held_id != "wood_pickaxe":
				message = state_item(kind) + "\n需要木镐 · 制作后按 2 装备"
		elif body.has_meta("door"):
			message = "木门\nE  " + ("关门" if world.door_open else "开门")
	if message=="":
		if not progress.has_flag("bench") and player.position.distance_to(ExplorerWorld.BENCH)<3.5:
			message = "工作台位置\nE  放置工作台" if progress.count("bench")>0 else "工作台位置\nTab  制作一张工作台"
		elif near_cabin() and progress.stage()==5:
			message = "庇护所蓝图  %d / %d\n按住右键  逐块建造 · 每块 1 圆石" % [progress.built.size(),world.blueprint.size()]
		elif near_cabin() and progress.stage()==6:
			message = "E  安装木门" if not progress.has_flag("door") else "E  安装屋内火把"
		elif near_workbench():
			message = "工作台\nTab  打开制作与背包"
		elif world.inside_house(player.position) and progress.stage()==7:
			message = "准备就绪\n关好门，按 N 开始第一夜"
	if near_cabin() and progress.stage()==6:
		message = "E  安装木门" if not progress.has_flag("door") else "E  安装屋内火把"
	elif near_workbench() and progress.count("furnace")>0 and not progress.has_flag("furnace"):
		message = "E  摆放熔炉     Tab  制作与背包"
	if journey != null:
		var addition := journey.hint()
		if addition != "": message = addition
	hud.hint.text = message

func state_item(id: String) -> String:
	return progress.items[id].name

func update_gather(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or target.is_empty() or not target.collider.has_meta("resource_id"):
		gather_time = 0
		gather_id = ""
		hud.gather_bar.hide()
		return
	var id: String = target.collider.get_meta("resource_id")
	var kind: String = target.collider.get_meta("kind")
	if kind in ["stone","coal"] and player.held_id != "wood_pickaxe":
		hud.gather_bar.hide()
		return
	if id!=gather_id:
		gather_id = id
		gather_time = 0
	var duration := 0.48 if kind=="log" and player.held_id=="stone_axe" else 1.1
	gather_time += delta
	player.swing = fmod(gather_time*2.8,1.0)
	hud.gather_bar.show()
	hud.gather_bar.value = gather_time/duration
	if gather_time >= duration:
		var result := progress.gather(id,kind)
		hud.toast(result)
		if id in progress.harvested and world.collectables.has(id):
			world.collectables[id].queue_free()
			world.collectables.erase(id)
			tone(250 if kind=="log" else 380,0.12,0.14)
		gather_time = 0
		gather_id = ""
		hud.gather_bar.hide()

func interact() -> void:
	if journey != null and journey.interact(): return
	# Finish the teaching installation before the door starts handling normal use.
	if near_cabin() and progress.has_flag("door") and not progress.has_flag("torch") and progress.count("torch") > 0:
		if progress.install("torch"):
			art.torch(world,ExplorerWorld.CAMP+Vector3(0.7,0.3,1.2))
			hud.toast("火把已点亮。对准木门按 E 开门，进屋后关门并按 N。")
			hud.refresh()
		return
	if not target.is_empty() and target.collider.has_meta("door"):
		world.toggle_door()
		tone(260,0.08,0.10)
		return
	if not progress.has_flag("bench") and player.position.distance_to(ExplorerWorld.BENCH)<3.5:
		if progress.place_bench():
			world.bench_marker.hide()
			art.bench(world,ExplorerWorld.BENCH)
			hud.toast("工作台已放好。站在这里按 Tab，制作木棍和木镐。")
		else: hud.toast("先按 Tab，用四块木板制作工作台。")
	elif near_cabin() and progress.has_flag("shelter") and not progress.has_flag("door"):
		if progress.install("door"):
			world.create_door()
			hud.toast("木门已安装。对准门按 E，可以开门和关门。")
		else: hud.toast("先去工作台，用六块木板制作木门。")
	elif near_cabin() and progress.has_flag("shelter") and not progress.has_flag("torch"):
		if progress.install("torch"):
			art.torch(world,ExplorerWorld.CAMP+Vector3(0.7,0.3,1.2))
			hud.toast("火把照亮了小屋。进屋关门后，按 N 迎接第一夜。")
		else: hud.toast("按 Tab，用一块煤和一根木棍制作火把。")
	elif near_workbench() and progress.count("furnace")>0 and not progress.has_flag("furnace"):
		if progress.install("furnace"):
			var furnace := art.furnace(world,ExplorerWorld.BENCH+Vector3(2,0,0))
			art.mark(furnace,"furnace")
			hud.toast("熔炉已摆放。完成第一夜后，对准它按 E，烹饪食物或烧制木炭。")
	elif near_workbench(): set_modal("craft")
	hud.refresh()

func start_night() -> void:
	if night: return
	if progress.stage()!=7:
		hud.toast("先完成庇护所、木门和火把，再迎接夜晚。")
		return
	if not world.inside_house(player.position) or world.door_open:
		hud.toast("请走进小屋并关好门，再按 N。")
		return
	night = true
	night_elapsed = 0
	hud.toast("夜幕将至。留在亮着火把的小屋里，等待黎明。")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sun,"light_energy",0.12,4)
	tween.tween_property(environment,"ambient_light_energy",0.17,4)
	tween.tween_property(environment.sky.sky_material,"sky_top_color",Color("111e3a"),4)
	tween.tween_property(environment.sky.sky_material,"sky_horizon_color",Color("465a6a"),4)

func update_night(delta: float) -> void:
	if world.inside_house(player.position) and not world.door_open:
		night_elapsed += delta
		hud.clock_label.text = "夜晚 · 距黎明 %02d 秒" % maxi(0,ceili(30-night_elapsed))
	else:
		hud.clock_label.text = "夜晚 · 回屋关门继续"
	hud.quest_title.text = "守候你的第一夜"
	hud.quest_body.text = "留在屋里，并保持木门关闭。\n温暖的火把会陪你等到黎明。\n\n进度 %d / 30 秒" % int(night_elapsed)
	if night_elapsed>=30:
		night = false
		progress.flags.complete = true
		save()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(sun,"light_energy",1.15,3)
		tween.tween_property(environment,"ambient_light_energy",0.43,3)
		tween.tween_property(environment.sky.sky_material,"sky_top_color",Color("5e96a5"),3)
		tween.tween_property(environment.sky.sky_material,"sky_horizon_color",Color("d1dbc0"),3)
		hud.clock_label.text = "清晨 · 新的旅程在等你"
		hud.refresh()
		set_modal("complete")
		tone(620,0.3,0.12)

func set_modal(kind: String) -> void:
	save()
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.near_bench = near_workbench()
	hud.show_modal(kind)

func close_modal() -> void:
	hud.close_modal()
	player.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func on_action(id: String) -> void:
	if journey != null and journey.on_action(id): return
	if id.begins_with("craft:"):
		var recipe := id.trim_prefix("craft:")
		var result := progress.craft(recipe,near_workbench())
		hud.show_modal("craft")
		hud.toast(result)
		tone(480,0.10,0.10)
		if recipe=="wood_pickaxe" and progress.count("wood_pickaxe")>0: equip(1)
		return
	match id:
		"start":
			progress.flags.started = true
			progress.save_game()
			close_modal()
		"close": close_modal()
		"journal": set_modal("journal")
		"return_camp":
			return_camp()
			close_modal()
		"quit":
			save()
			get_tree().quit()

func return_camp() -> void:
	player.position = Vector3(-0.5,2.15,12)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.12
	player.camera.rotation.x = -0.04
	save()

func save() -> void:
	if not is_instance_valid(player): return
	progress.position = [player.position.x,player.position.y,player.position.z]
	progress.look = [player.rotation.y,player.camera.rotation.x]
	progress.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and "--integration" not in OS.get_cmdline_user_args() and is_instance_valid(hud) and player.active:
		set_modal("pause")

func tone(frequency: float, duration: float, volume: float) -> void:
	if smoke_mode: return
	var audio := AudioStreamPlayer.new()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := int(duration*22050)
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	for i in samples:
		var t := float(i)/22050
		var envelope := pow(1.0-float(i)/samples,2.0)
		bytes.encode_s16(i*2,int(sin(t*TAU*frequency)*envelope*volume*32767))
	wav.data = bytes
	audio.stream = wav
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func run_smoke() -> void:
	print("SMOKE world ready: ", world.blueprint.size(), " blueprint blocks, ", world.collectables.size(), " resources")
	assert(world.blueprint.size()==46)
	assert(world.collectables.size()>25)
	assert(player.is_on_floor(), "Player must spawn on solid terrain")
	get_tree().quit()

func capture_preview() -> void:
	hud.close_modal()
	player.active = false
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	get_viewport().get_texture().get_image().save_png("res://artifacts/first-light.png")
	print("Captured artifacts/first-light.png")
	get_tree().quit()
