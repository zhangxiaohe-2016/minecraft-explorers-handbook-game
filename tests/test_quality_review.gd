extends "res://tests/test_book_review.gd"

func click_map(map: ExplorationMap, pixel: Vector2) -> void:
	var at:=map.get_global_transform_with_canvas()*pixel
	var move:=InputEventMouseMotion.new()
	move.position=at
	root.push_input(move,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		root.push_input(event,true)
		await process_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	game.player.set_process_unhandled_input(false)
	game.close_modal()
	var state: ExpeditionProgress=game.progress
	check(not state.save_enabled,"review isolates player save")
	state.inventory["stone_axe"]=0
	state.inventory["wood_sword"]=1
	state.inventory["bread"]=1
	state.flags.forest_complete=true
	game.mansion.start()
	check(state.count("stone_axe")==0 and state.has_flag("mansion_started"),"sword-only inventory can enter mansion")
	game.equip(0)
	press(KEY_5)
	check(game.player.held_id=="wood_sword" and game.slot==4,"keyboard 5 switches from empty hand to sword")
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed=true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	check(game.slot==0,"wheel wraps from fifth slot to first")
	state.inventory["map"]=1
	press(KEY_M)
	await process_frame
	var map: ExplorationMap
	for child in game.hud.modal.get_children():
		if child is ExplorationMap:map=child
	check(map!=null,"M opens interactive map")
	state.journey.explored=["10,10"]
	state.journey.waypoints=[]
	await click_map(map,Vector2(210,210))
	check("10,10" in state.journey.waypoints,"viewport mouse click adds flag through GUI at scaled coordinates")
	await click_map(map,Vector2(210,210))
	check(state.journey.waypoints.is_empty(),"second viewport mouse click removes flag")
	await click_map(map,Vector2(30,30))
	check(state.journey.waypoints.is_empty(),"GUI rejects unexplored cell")
	check(not map.toggle_waypoint(Vector2(-1,5)).ok and not map.toggle_waypoint(Vector2(480,5)).ok,"map bounds reject outside coordinates")
	for size in [Vector2i(960,600),Vector2i(1600,1000)]:
		root.size=size
		await process_frame
		await process_frame
		await click_map(map,Vector2(210,210))
		check("10,10" in state.journey.waypoints,"GUI coordinate mapping after resize %s"%size)
		await click_map(map,Vector2(210,210))
		check(state.journey.waypoints.is_empty(),"GUI deletion after resize %s"%size)
	print("QUALITY REVIEW RESULT: %d failures"%failures)
	quit(1 if failures else 0)
