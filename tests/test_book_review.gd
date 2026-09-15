extends SceneTree

var game: Node3D
var failures:=0

func check(ok: bool,message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures+=1

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
	event.pressed=false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func aim(pos: Vector3,target: Vector3) -> void:
	game.player.position=pos
	game.player.velocity=Vector3.ZERO
	game.player.rotation=Vector3.ZERO
	game.player.look_at(Vector3(target.x,pos.y,target.z))
	game.player.camera.look_at(target)
	await physics_frame
	await physics_frame
	game.target=game.player.ray()

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

func press_mouse_left(hold: float) -> void:
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await create_timer(hold).timeout
	click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=false
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	game.player.set_process_unhandled_input(false)
	game.close_modal()
	var state: ExpeditionProgress=game.progress
	check(state.has_flag("complete"),"camp fixture keeps first-night completion")
	check(state.count("wood_sword")==0,"fixture starts without wood sword")

	# --- Wooden sword recipe: 2 planks + 1 stick, workbench required (p.9/16) ---
	var craft_fail:=state.craft("wood_sword",true)
	check(state.count("wood_sword")==0 and craft_fail!="","wood sword cannot be crafted without materials")
	state.add("plank",1)
	state.add("stick",1)
	craft_fail=state.craft("wood_sword",false)
	check(state.count("wood_sword")==0 and craft_fail.contains("工作台"),"wood sword recipe requires a nearby workbench")
	var sticks_before:=state.count("stick")
	state.add("plank",1)
	craft_fail=state.craft("wood_sword",true)
	check(state.count("wood_sword")==1 and state.count("plank")==0 and state.count("stick")==sticks_before-1,"2 planks + 1 stick craft a wood sword")
	check(state.has_flag("crafted_wood_sword"),"crafting the sword records the recipe flag")

	# --- Hotbar slot 5 and first-person model ---
	check(game.hud.hotbar.size()==5,"HUD shows five hotbar slots")
	game.equip(0)
	press(KEY_5)
	check(game.player.held_id=="wood_sword" and game.slot==4,"keyboard 5 switches from empty hand to wood sword")
	var sword_node: Node=null
	for child in game.player.hand.get_children():
		if child is Node3D and child.name=="WoodSword":sword_node=child
	check(sword_node!=null and sword_node.get_child_count()>0,"first-person hand shows a procedural wood sword mesh")
	game.equip(2)
	check(game.player.held_id=="stone_axe","slot 3 still equips stone axe")
	game.player.held_id=""
	game.player.hold("wood_sword")
	check(game.player.held_id=="wood_sword" and game.player.hand.get_child_count()>0,"re-equipping rebuilds the sword model")
	await aim(Vector3(-0.5,2.05,10),Vector3(-0.5,2.8,12))
	await screenshot("book-wood-sword")

	# --- Mansion entry accepts wood sword alone; real attack with 5 ---
	state.inventory["stone_axe"]=0
	if state.count("bread")==0:state.add("bread",1)
	state.add("log",1)
	state.flags.mansion_started=false
	game.mansion.start()
	check(not state.has_flag("mansion_started"),"mansion still requires forest completion")
	state.flags.forest_complete=true
	game.mansion.start()
	check(state.count("stone_axe")==0 and state.has_flag("mansion_started"),"wood sword + food opens mansion without stone axe")
	# Restore one axe only for the comparative weapon test below.
	state.add("stone_axe",1)
	var guard: MansionGuard=null
	for child in game.mansion.get_children():
		if child is MansionGuard and not child.caster:guard=child
	check(guard!=null,"mansion still spawns a vindicator")
	var local_stand:=MansionExpedition.ORIGIN+Vector3(11,4.1,2.1)
	var local_look:=MansionExpedition.ORIGIN+Vector3(11,5.2,4)
	guard.position=Vector3(11,4.1,4)
	guard.cooldown=99
	guard.windup=0
	await aim(local_stand,local_look)
	game.equip(4)
	game.mansion.hit_cooldown=0
	game.mansion.immunity=5
	var guard_hp:=guard.health
	await press_mouse_left(0.12)
	check(guard.health==guard_hp-1,"real left-click hits with equipped wood sword")
	check(game.mansion.hit_cooldown>0.2 and game.mansion.hit_cooldown<0.4,"wood sword uses the shorter teaching attack interval")
	var after_sword:=guard.health
	game.mansion.attack()
	check(guard.health==after_sword,"attack cooldown blocks immediate second hit")
	guard.position=Vector3(11,4.1,4)
	guard.cooldown=99
	await aim(local_stand,local_look)
	game.mansion.hit_cooldown=0
	game.equip(2)
	game.target={"collider":guard}
	game.mansion.attack()
	check(guard.health==after_sword-1,"stone axe remains a valid mansion weapon")
	guard.position=Vector3(11,4.1,4)
	guard.cooldown=99
	await aim(local_stand,local_look)
	game.mansion.hit_cooldown=0
	game.equip(0)
	game.target={"collider":guard}
	var empty_hp:=guard.health
	game.mansion.attack()
	check(guard.health==empty_hp,"empty hand cannot damage mansion guards")

	# --- Map waypoints (p.21) ---
	state.add("map",1)
	state.journey.explored=[]
	var unexplored: Array = state.journey.explored
	check(unexplored.is_empty(),"start waypoint tests with an empty explore record")
	game.journey.open_panel("map")
	check(game.hud.current_modal=="map","map panel opens when the player owns a map")
	var map: ExplorationMap=null
	for child in game.hud.modal.get_children():
		if child is ExplorationMap:map=child
	check(map!=null,"map panel embeds the ExplorationMap control")
	var reject:=map.toggle_waypoint(Vector2(40,40))
	check(not reject.ok and reject.reason=="unexplored","unexplored cells reject waypoints")
	state.journey.explored=["10,10","11,10","12,10"]
	map.queue_redraw()
	var added:=map.toggle_waypoint(Vector2(10*20+5,10*20+5))
	check(added.ok and not added.get("removed",true) and "10,10" in state.journey.waypoints,"clicking an explored cell places a pink flag")
	var removed:=map.toggle_waypoint(Vector2(10*20+5,10*20+5))
	check(removed.ok and removed.get("removed",false) and "10,10" not in state.journey.waypoints,"clicking the same cell removes the flag")
	for i in range(12):
		var key: String=str(10+(i%3))+","+str(10+(i/3))
		if key not in state.journey.explored:state.journey.explored.append(key)
		map.toggle_waypoint(Vector2((10+(i%3))*20+5,(10+(i/3))*20+5))
	check(state.journey.waypoints.size()==12,"twelve explored cells can hold flags")
	var overflow:=map.toggle_waypoint(Vector2(13*20+5,10*20+5))
	state.journey.explored.append("13,10")
	overflow=map.toggle_waypoint(Vector2(13*20+5,10*20+5))
	check(not overflow.ok and overflow.reason=="full","a thirteenth flag is rejected with a clear reason")
	await screenshot("book-map-flags")
	game.close_modal()
	state.save_path="/tmp/explorer-book-review.json"
	state.save_enabled=true
	state.save_game()
	state.save_enabled=false
	var restored:=ExpeditionProgress.new()
	restored.save_path=state.save_path
	check(restored.load_game() and restored.journey.waypoints.size()==12,"waypoint flags survive save and reload")
	check(restored.count("wood_sword")==1 and restored.has_flag("crafted_wood_sword"),"wood sword progress survives save and reload")
	check(restored.journey.get("waypoints") is Array,"legacy journey data still exposes an Array waypoints field")
	var legacy:=ExpeditionProgress.new()
	legacy.save_enabled=false
	legacy.journey.erase("waypoints")
	legacy.save_path="/tmp/explorer-book-review-legacy.json"
	# Simulate an older v2 save that predates waypoints.
	var raw:={"version":2,"inventory":state.inventory,"flags":state.flags,"harvested":state.harvested,"built":state.built,"position":[],"look":[],"journey":{"hunger":20.0,"time":0.0,"explored":["10,10"],"crops":{},"job":{},"fuel":0,"spawn":[],"health":10}}
	var file:=FileAccess.open("/tmp/explorer-book-review-legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	legacy.save_enabled=true
	legacy.load_game()
	legacy.save_enabled=false
	check(legacy.journey.get("waypoints") is Array and legacy.journey.waypoints.is_empty(),"older saves without waypoints initialize an empty list")

	# --- Sunflowers face east and respond to E (p.25) ---
	var sunflowers:=0
	var face_x:=-999.0
	var back_x:=999.0
	var plant0: Node3D=null
	for child in game.world.get_children():
		if child is Node3D and child.name.begins_with("Sunflower"):
			sunflowers+=1
			check(child.get_meta("flower_direction",Vector3.ZERO)==Vector3.RIGHT,"sunflower %s stores east-facing direction"%child.name)
			if plant0==null:plant0=child
			for part in child.get_children():
				if part is MeshInstance3D:
					face_x=maxf(face_x,part.position.x)
					back_x=minf(back_x,part.position.x)
	check(sunflowers==12,"plains spawn twelve teaching sunflowers")
	check(face_x>0 and back_x<0,"golden flower faces sit on the +X (east) side of the stem")
	var plant_y:=plant0.position.y
	var stand:=plant0.position+Vector3(2.2,0.15,0.3)
	var look:=plant0.position+Vector3(0.075,1.55,0)
	await aim(stand,look)
	check(game.journey.target_kind()=="sunflower","camera ray reaches a sunflower interaction collider")
	press(KEY_E)
	check(state.has_flag("sunflower_observed"),"E on a sunflower records the east-facing lesson")
	press(KEY_E)
	check(state.has_flag("sunflower_observed"),"observing again keeps a stable flag and does not block walking")
	check(game.player.active,"sunflower interaction returns to free movement")
	await aim(Vector3(-11.0,plant_y+0.2,7.5),Vector3(-14.5,plant_y+1.2,4.0))
	await screenshot("book-sunflowers")

	print("BOOK REVIEW RESULT: ",failures," failures")
	quit(1 if failures else 0)
