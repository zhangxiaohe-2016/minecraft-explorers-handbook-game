extends SceneTree

var game: Node3D
var failures:=0

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures+=1

func _initialize() -> void:
	call_deferred("run")

func press(key: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event=InputEventKey.new()
	event.physical_keycode=key
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func aim(pos: Vector3, target: Vector3) -> void:
	game.player.position=pos
	game.player.velocity=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.look_at(Vector3(target.x,pos.y,target.z))
	game.player.camera.look_at(target)
	await physics_frame
	await physics_frame
	game.target=game.player.ray()

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	var state: ExpeditionProgress=game.progress
	game.close_modal()
	check(not game.journey.compass_display.visible,"no compass displayed before acquisition")
	state.flags.journey_complete=true
	await aim(Vector3(-30.2,2.05,2),Vector3(-30.2,2.45,-0.55))
	check(game.journey.target_kind()=="chest","lookout box is reachable above terrain")
	press(KEY_E)
	check(state.count("compass")==1,"real E interaction awards compass")
	press(KEY_E)
	check(state.count("compass")==1,"compass reward cannot duplicate")
	await create_timer(0.1).timeout
	check(game.journey.compass_display.visible,"owned compass is visible without equipping")
	press(KEY_C)
	check(game.hud.current_modal=="compass","C opens compass usage instructions")
	press(KEY_C)
	check(game.hud.current_modal=="","C closes usage instructions")
	var spawn:=CompassDisplay.WORLD_SPAWN
	check(CompassDisplay.direction_at(spawn+Vector3(0,0,10),0).is_equal_approx(Vector2.UP),"spawn ahead gives upward red needle")
	check(CompassDisplay.direction_at(spawn+Vector3(0,0,10),PI/2).is_equal_approx(Vector2.RIGHT),"turning left places spawn to the right")
	check(CompassDisplay.direction_at(spawn+Vector3(0,0,10),PI).is_equal_approx(Vector2.DOWN),"turning around places spawn behind")
	state.journey.spawn=[-32,2.1,-29]
	check(CompassDisplay.direction_at(spawn+Vector3(10,0,0),0).is_equal_approx(Vector2.LEFT),"village bed does not change world-spawn direction")
	for entry in [["flower",4],["birch",16],["dark",28]]:
		await aim(Vector3(-30,2.05,entry[1]+2.5),Vector3(-30,3.2,entry[1]))
		check(game.journey.target_kind()=="forest","real ray reaches "+entry[0]+" observation sign")
		press(KEY_E)
		check(game.hud.current_modal=="forest_"+entry[0],"E opens biome explanation")
		game.on_action("journey:observe:forest_"+entry[0])
		game.close_modal()
	check(state.has_flag("forest_dark") and state.has_flag("forest_birch") and state.has_flag("forest_flower"),"all three biome observations recorded")
	# Interaction assertions above use real input events. Isolate the timed walk
	# from keyboard activity in other windows during the rendered test.
	root.set_disable_input(true)
	game.close_modal()
	# Exercise the physical southbound path, not only teleported interactions.
	await aim(Vector3(-32,2.05,0),Vector3(-32,3.6,30))
	game.player.rotation.y=PI
	game.player.camera.rotation=Vector3.ZERO
	Input.action_press("forward")
	await create_timer(6.5).timeout
	Input.action_release("forward")
	check(game.player.position.z>25 and game.player.position.y>1.8,"forest path can be walked without collision blockage or falling")
	if DisplayServer.get_name()!="headless":
		await aim(Vector3(-32,2.05,21),Vector3(-26,4,29))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/forest-compass.png")
	game.player.position=spawn
	await create_timer(0.5).timeout
	check(state.has_flag("forest_complete"),"returning to world spawn completes forest route")
	state.save_path="/tmp/explorer-forest-test.json"
	state.save_enabled=true
	state.save_game()
	state.save_enabled=false
	var restored:=ExpeditionProgress.new()
	restored.save_path=state.save_path
	check(restored.load_game() and restored.count("compass")==1 and restored.has_flag("forest_complete"),"compass and forest completion survive reload")
	check(restored.built.size()==46 and restored.count("bench")==21,"existing possessions and cabin survive")
	print("FOREST RESULT: %d failures"%failures)
	quit(failures)
