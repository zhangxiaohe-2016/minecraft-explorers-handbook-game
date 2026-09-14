extends SceneTree

var game: Node3D
var failures:=0

func check(value: bool,label: String) -> void:
	if value: print("PASS: ",label)
	else:
		push_error("FAIL: "+label)
		failures+=1

func _initialize() -> void:
	call_deferred("run")

func aim(from: Vector3,at: Vector3) -> void:
	game.player.position=from
	game.player.velocity=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.camera.look_at(at)
	await physics_frame
	await physics_frame
	game.target=game.player.ray()

func press(key: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func snapshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	var state: ExpeditionProgress=game.progress
	check(state.has_flag("complete") and state.built.size()==46,"v1 house and first-night completion migrate")
	check(state.count("bench")==21 and state.count("stone_axe")==4 and state.count("torch")==39,"existing player inventory is preserved exactly")
	check("tree_2" not in game.world.collectables and "rock_3" not in game.world.collectables,"depleted resources keep their old IDs")
	check(state.journey.hunger==20 and state.journey.explored.is_empty(),"new journey fields initialize safely")
	state.trade("map")
	check(state.count("map")==0,"map cannot be acquired without payment")
	var no_fuel:=ExpeditionProgress.new()
	no_fuel.save_enabled=false
	no_fuel.add("raw_beef",2)
	no_fuel.begin_smelting("cooked_beef")
	check(no_fuel.count("raw_beef")==2 and no_fuel.journey.job.is_empty(),"missing fuel does not consume food")
	no_fuel.add("plank",1)
	no_fuel.begin_smelting("cooked_beef")
	no_fuel.begin_smelting("cooked_beef")
	check(no_fuel.count("raw_beef")==1 and no_fuel.count("plank")==0,"single furnace job cannot double-spend input")
	await snapshot("journey-welcome")
	game.close_modal()
	await aim(Vector3(-8.5,2.05,7),Vector3(-8.5,2.5,4.5))
	check(game.journey.target_kind()=="chest","camera ray targets the supply chest")
	press(KEY_E)
	check(state.has_flag("supplies") and state.count("wool")==3,"E grants one-time teaching supplies")
	press(KEY_E)
	check(state.count("wool")==3,"supply chest cannot duplicate rewards")
	game.player.position=Vector3(-1,2.05,4)
	game.set_modal("craft")
	game.on_action("craft:bed")
	check(state.count("bed")==1 and state.count("wool")==0,"bed recipe consumes three wool and three planks")
	await snapshot("journey-crafting")
	game.close_modal()
	game.player.position=Vector3(-5,2.05,1.8)
	game.target={}
	game.interact()
	check(state.has_flag("bed") and state.count("bed")==0,"bed installs inside existing cabin")
	await aim(Vector3(-5,2.05,2.1),Vector3(-4,2.45,0.8))
	press(KEY_E)
	check(state.journey.spawn.size()==3,"using bed saves a respawn point")
	await aim(Vector3(1,2.05,4.4),Vector3(1,2.5,2))
	press(KEY_E)
	check(game.hud.current_modal=="furnace","E opens the existing player's furnace")
	game.on_action("journey:cook:cooked_beef")
	check(state.count("raw_beef")==1 and not state.journey.job.is_empty(),"cooking spends actual input and starts a job")
	var remaining: float=state.journey.job.remaining
	game.set_modal("pause")
	await create_timer(0.3).timeout
	check(state.journey.job.remaining==remaining,"pause freezes cooking timer")
	game.journey.open_panel("furnace")
	await snapshot("journey-furnace")
	await create_timer(6.2).timeout
	check(state.count("cooked_beef")==1 and state.journey.job.is_empty(),"real cooking timer yields cooked food")
	state.begin_smelting("charcoal")
	state.tick_smelting(6.1)
	check(state.count("charcoal")==1,"logs can be smelted to charcoal")
	state.journey.hunger=10
	game.journey.open_panel("food")
	game.on_action("journey:eat:cooked_beef")
	check(state.journey.hunger==18 and state.count("cooked_beef")==0,"eating cooked beef restores eight hunger points")
	game.close_modal()
	state.journey.hunger=6
	await create_timer(0.1).timeout
	check(not game.player.sprint_allowed,"low hunger disables sprint without blocking walking")
	state.journey.hunger=20
	var raw_before:=state.count("raw_beef")
	state.eat("raw_beef")
	check(state.count("raw_beef")==raw_before,"full hunger does not waste food")
	await aim(Vector3(-18.5,2.05,-12),Vector3(-25,3,-25))
	await create_timer(0.5).timeout
	check(state.has_flag("village_found"),"approaching village records discovery")
	await create_timer(1).timeout
	print("VILLAGE RENDER sample: fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	await snapshot("plains-village")
	# Crops use their actual interactable collider and persistent growth clock.
	var crop: Node3D=game.journey.village.crops.wheat_0
	game.target={"collider":crop.get_child(crop.get_child_count()-1)}
	game.interact()
	game.interact()
	check(state.count("wheat")==3,"a growing crop cannot be harvested repeatedly")
	crop=game.journey.village.crops.wheat_1
	game.target={"collider":crop.get_child(crop.get_child_count()-1)}
	game.interact()
	check(state.count("wheat")==6,"two mature crop plots provide six wheat")
	await aim(Vector3(-19,2.05,-13.5),Vector3(-19,3.1,-16.5))
	press(KEY_E)
	check(game.hud.current_modal=="farmer","ray and E open farmer conversation")
	game.on_action("journey:trade:wheat")
	check(state.count("emerald")==1 and state.count("wheat")==0,"farmer trades wheat for emerald")
	game.close_modal()
	await aim(Vector3(-19.5,2.05,-25.5),Vector3(-19.5,3.1,-28.8))
	press(KEY_E)
	check(game.hud.current_modal=="cartographer","ray and E open cartographer conversation")
	game.on_action("journey:trade:map")
	check(state.count("map")==1 and state.count("emerald")==0,"map requires an actual emerald")
	game.close_modal()
	press(KEY_M)
	check(game.hud.current_modal=="map","M opens the exploration map")
	check(state.journey.explored.size()>0,"map reveals nearby terrain")
	await snapshot("exploration-map")
	press(KEY_M)
	check(game.player.active,"M returns from map to gameplay")
	var player_pos: Vector3=game.player.position
	game.player.position=Vector3(-20,2.05,-33)
	check(game.near_workbench(),"village workbench uses shared crafting system")
	game.player.position=player_pos
	state.journey.time=float(state.journey.time)+91
	await create_timer(0.1).timeout
	check(game.journey.village.crops.wheat_0.visible,"harvested crops regrow after the saved interval")
	game.player.position=Vector3(-5,2.05,7)
	await create_timer(0.2).timeout
	check(state.has_flag("journey_complete") and game.hud.current_modal=="journey_complete","returning with map completes the new route")
	state.save_path="/tmp/explorer-village-save.json"
	state.save_enabled=true
	state.save_game()
	state.save_enabled=false
	var restored:=ExpeditionProgress.new()
	restored.save_path=state.save_path
	check(restored.load_game() and restored.has_flag("journey_complete"),"v2 journey completion survives save/load")
	check(restored.journey.explored==state.journey.explored,"map exploration survives save/load")
	var crop_times_match: bool=restored.journey.crops.size()==state.journey.crops.size()
	for id in state.journey.crops:
		crop_times_match=crop_times_match and restored.journey.crops.has(id) and is_equal_approx(float(restored.journey.crops.get(id,-1000)),float(state.journey.crops[id]))
	check(crop_times_match,"crop timestamps survive JSON save/load within floating-point precision")
	check(restored.count("bench")==21 and restored.built.size()==46,"new chapter never removes old possessions or shelter")
	print("VILLAGE RESULT: ",failures," failures")
	quit(1 if failures else 0)
