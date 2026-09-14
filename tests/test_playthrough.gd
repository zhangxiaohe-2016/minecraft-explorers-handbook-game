extends SceneTree

var failures := 0
var game: Node3D

func check(condition: bool, label: String) -> void:
	if condition: print("PASS: ",label)
	else:
		push_error("FAIL: "+label)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game.close_modal()
	var start_z: float = game.player.position.z
	Input.action_press("forward")
	await create_timer(0.8).timeout
	Input.action_release("forward")
	check(game.player.position.z < start_z-2.0,"W input moves player on terrain")
	check(game.player.is_on_floor(),"terrain supports character collision")
	check(game.progress.has_flag("moved"),"movement completes first tutorial step")
	var tab_key := InputEventKey.new()
	tab_key.physical_keycode = KEY_TAB
	tab_key.pressed = true
	Input.parse_input_event(tab_key)
	await process_frame
	check(game.hud.current_modal=="craft","Tab opens crafting UI")
	tab_key = InputEventKey.new()
	tab_key.physical_keycode = KEY_TAB
	tab_key.pressed = false
	Input.parse_input_event(tab_key)
	tab_key = InputEventKey.new()
	tab_key.physical_keycode = KEY_TAB
	tab_key.pressed = true
	Input.parse_input_event(tab_key)
	await process_frame
	check(game.hud.current_modal=="" and game.player.active,"Tab closes UI instead of only moving button focus")
	tab_key = InputEventKey.new()
	tab_key.physical_keycode = KEY_TAB
	tab_key.pressed = false
	Input.parse_input_event(tab_key)
	# Exercise camera ray + held mouse mining through the actual game loop.
	game.player.position = Vector3(5.5,2.05,8.0)
	game.player.rotation = Vector3.ZERO
	game.player.camera.look_at(Vector3(5.5,3.4,5.5))
	await create_timer(0.2).timeout
	check(not game.player.ray().is_empty(),"resource collision is visible to interaction ray")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await create_timer(1.4).timeout
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	Input.parse_input_event(click)
	check(game.progress.count("log")==3,"held left mouse harvests tree and awards logs")
	# Gather remaining supplies through shared rule engine, then exercise world mutations.
	game.progress.gather("tree_1","log")
	for i in range(6): game.progress.craft("plank",false)
	game.progress.craft("bench",false)
	game.player.position = Vector3(-1,2.05,4)
	game.target = {}
	game.interact()
	check(game.progress.has_flag("bench") and not game.world.bench_marker.visible,"E installs crafted workbench")
	game.progress.craft("stick",false)
	game.progress.craft("wood_pickaxe",game.near_workbench())
	game.equip(1)
	await process_frame
	check(game.player.hand.get_child_count()==1,"Blender GLB equips in first-person hand")
	for i in range(1,15):
		if i%5!=0: game.progress.gather("rock_%d"%i,"stone")
	game.progress.gather("rock_0","coal")
	for i in range(game.world.blueprint.size()):
		check(game.world.build_next(),"world construction %d"%i)
	check(game.progress.has_flag("shelter") and not game.world.ghost.visible,"all real blueprint blocks complete shelter")
	game.progress.craft("door",true)
	game.progress.craft("torch",false)
	game.progress.craft("furnace",true)
	game.target = {}
	game.player.position = Vector3(-5,2.05,5)
	game.interact()
	game.interact()
	check(game.progress.has_flag("door") and game.progress.has_flag("torch"),"E installs door and torch in world")
	game.player.position = Vector3(-1,2.05,4)
	game.interact()
	check(game.progress.has_flag("furnace"),"optional furnace can be placed")
	game.player.position = Vector3(-5,2.05,1)
	await physics_frame
	game.start_night()
	check(game.night,"night starts only after preparation inside cabin")
	game.world.toggle_door()
	game.update_night(10)
	check(game.night_elapsed==0,"open door pauses shelter challenge")
	game.world.toggle_door()
	await create_timer(4.2).timeout
	game.update_night(31)
	check(game.progress.has_flag("complete") and game.hud.current_modal=="complete","closed shelter reaches dawn and displays ending")
	game.hud.show_modal("journal")
	check(game.hud.current_modal=="journal","whole-book journal opens after completion")
	game.hud.close_modal()
	game.player.active = false
	game.player.position = Vector3(-0.3,2.2,10.5)
	game.player.rotation.y = 0.2
	game.player.camera.rotation.x = -0.03
	game.update_hint()
	game.hud.toast_time = 0
	await create_timer(3.5).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts")
		root.get_texture().get_image().save_png("res://artifacts/completed-camp.png")
	print("RENDER sample: fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("PLAYTHROUGH RESULT: ",failures," failures")
	quit(1 if failures else 0)
