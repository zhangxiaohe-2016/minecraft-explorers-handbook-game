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

func hold_click(seconds: float) -> void:
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await create_timer(seconds).timeout
	click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=false
	Input.parse_input_event(click)
	Input.flush_buffered_events()

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

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

func run() -> void:
	# Rule-level checks first (no scene needed).
	var state:=ExpeditionProgress.new()
	state.save_enabled=false
	check(state.MAX_DURABILITY.wood_pickaxe==59 and state.MAX_DURABILITY.wood_sword==60 and state.MAX_DURABILITY.stone_axe==132,"book durability values: pick 59, sword 60, stone axe 132")
	state.add("wood_pickaxe",1)
	check(state.held_durability("wood_pickaxe")==59,"crafted tool starts at full durability")
	state.add("wood_pickaxe",1)
	check(state.tool_durability.wood_pickaxe==[59,59],"two same-type tools keep separate durability slots")
	state.tool_durability.wood_pickaxe[0]=3
	check(state.held_durability("wood_pickaxe")==3,"active tool tracks its own wear")
	var worn:=state.wear_tool("wood_pickaxe",2)
	check(state.held_durability("wood_pickaxe")==1 and not worn.broken,"wear reduces only the equipped instance")
	var broke:=state.wear_tool("wood_pickaxe",5)
	check(broke.broken and state.count("wood_pickaxe")==1 and state.held_durability("wood_pickaxe")==59,"breaking removes one tool and equips the backup at full durability")
	state.wear_tool("wood_pickaxe",59)
	check(state.count("wood_pickaxe")==0,"breaking the last tool empties the slot")
	var no_wear:=state.wear_tool("wood_sword",1)
	check(not no_wear.ok,"wear is rejected when the tool is missing")
	state.add("stone_axe",1)
	var axe:=state.wear_tool("stone_axe",1)
	check(state.held_durability("stone_axe")==131 and axe.remaining==131,"successful use deducts one point from stone axe")
	# Low/critical flags without long grind.
	state.tool_durability.stone_axe=[20]
	axe=state.wear_tool("stone_axe",1)
	check(axe.low and not axe.critical,"low durability warning near twenty percent")
	state.tool_durability.stone_axe=[5]
	axe=state.wear_tool("stone_axe",1)
	check(axe.critical,"critical durability warning near ten percent")
	# Save migration and no-duplicate reload.
	state.inventory={"wood_pickaxe":2,"stone_axe":1,"log":1}
	state.tool_durability={"wood_pickaxe":[10,59],"stone_axe":[80]}
	state.save_enabled=true
	state.save_path="/tmp/explorer-durability-test.json"
	state.save_game()
	var restored:=ExpeditionProgress.new()
	restored.save_path=state.save_path
	check(restored.load_game() and restored.count("wood_pickaxe")==2,"reload keeps tool counts")
	check(restored.tool_durability.wood_pickaxe==[10,59] and restored.tool_durability.stone_axe==[80],"reload keeps worn durability, does not refresh")
	restored.save_game()
	var again:=ExpeditionProgress.new()
	again.save_path=state.save_path
	again.load_game()
	check(again.count("wood_pickaxe")==2 and again.tool_durability.wood_pickaxe==[10,59],"second reload does not duplicate or restore tools")
	# Legacy v2 save without durability fields.
	var raw:={"version":2,"inventory":{"wood_pickaxe":3,"stone_axe":4,"torch":5},"flags":{"complete":true},"harvested":[],"built":[0],"position":[],"look":[],"journey":{"hunger":20.0,"time":0.0,"explored":[],"crops":{},"job":{},"fuel":0,"spawn":[],"health":10,"waypoints":[]}}
	var file:=FileAccess.open("/tmp/explorer-durability-legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var legacy:=ExpeditionProgress.new()
	legacy.save_path="/tmp/explorer-durability-legacy.json"
	legacy.save_enabled=true
	check(legacy.load_game() and legacy.count("wood_pickaxe")==3 and legacy.count("stone_axe")==4,"legacy save keeps all tool counts")
	check(legacy.tool_durability.wood_pickaxe==[59,59,59] and legacy.tool_durability.stone_axe==[132,132,132,132],"legacy tools initialize to full durability once")
	legacy.save_game()
	legacy.tool_durability.wood_pickaxe[0]=1
	legacy.save_game()
	var legacy2:=ExpeditionProgress.new()
	legacy2.save_path="/tmp/explorer-durability-legacy.json"
	legacy2.load_game()
	check(legacy2.tool_durability.wood_pickaxe[0]==1,"migration does not reset wear after the first v3 write")
	# .pre-v3 backup must be the untouched legacy file, not the rewritten v3.
	var backup_path:=legacy.save_path+".pre-v3"
	check(FileAccess.file_exists(backup_path),".pre-v3 backup file is created on first v3 migration")
	var backup_text:=FileAccess.get_file_as_string(backup_path)
	var backup_data=JSON.parse_string(backup_text)
	check(backup_data is Dictionary and int(backup_data.get("version",0))==2 and not backup_data.has("tool_durability"),".pre-v3 keeps original v2 payload without durability fields")
	check(int(backup_data.inventory.get("wood_pickaxe",0))==3,".pre-v3 preserves original tool counts")

	# Integration: real gather wears pickaxe; miss and pause do not.
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	game.player.set_process_unhandled_input(false)
	game.close_modal()
	var live: ExpeditionProgress=game.progress
	live.add("wood_pickaxe",2)
	live.add("stone_axe",2)
	live.tool_durability.wood_pickaxe=[1,59]
	live.tool_durability.stone_axe=[1,132]
	live.tool_durability.wood_sword=[]
	game.equip(1)
	check(game.player.held_id=="wood_pickaxe" and live.held_durability("wood_pickaxe")==1,"HUD equip shows worn pickaxe")
	check(game.hud.durability_label.text.contains("耐久 1 / 59"),"hotbar shows remaining durability")
	await aim(Vector3(2.5,2.05,4),Vector3(4,2.5,4))
	var before_air:=live.held_durability("wood_pickaxe")
	game.set_modal("pause")
	await create_timer(0.2).timeout
	game.close_modal()
	check(live.held_durability("wood_pickaxe")==before_air,"pause does not consume durability")
	var stone_node: Node3D=null
	for id in game.world.collectables:
		var node: Node=game.world.collectables[id]
		for child in node.get_children():
			if child.has_meta("kind") and str(child.get_meta("kind"))=="stone":
				stone_node=node
				break
		if stone_node!=null:break
	check(stone_node!=null,"world still has a stone collectable")
	await aim(stone_node.global_position+Vector3(0,0.2,1.6),stone_node.global_position+Vector3(0,0.5,0))
	check(game.target.get("collider")!=null,"camera ray reaches stone")
	var stone_before:=live.count("stone")
	await hold_click(1.4)
	check(live.count("stone")>stone_before,"real left-click mines stone")
	check(live.count("wood_pickaxe")==1 and live.held_durability("wood_pickaxe")==59,"broken pickaxe auto-switches to backup")
	check(game.player.held_id=="wood_pickaxe","player remains equipped with backup pickaxe")
	live.tool_durability.wood_pickaxe=[1]
	game.apply_wear("wood_pickaxe")
	check(live.count("wood_pickaxe")==0 and game.player.held_id=="","last pickaxe break returns to empty hand")
	game.equip(2)
	live.tool_durability.stone_axe=[1]
	game.apply_wear("stone_axe")
	check(live.count("stone_axe")==1 and live.held_durability("stone_axe")==132,"stone axe break equips spare axe")
	live.add("wood_sword",1)
	live.tool_durability.wood_sword=[1]
	game.equip(4)
	check(game.player.held_id=="wood_sword","sword equips from slot 5")
	check(game.hud.durability_label.text.contains("木剑"),"HUD lists sword durability")
	game.apply_wear("wood_sword")
	check(live.count("wood_sword")==0 and game.player.held_id=="","sword break clears held item")
	live.add("plank",5)
	live.add("stick",3)
	live.flags.bench=true
	game.player.position=Vector3(-1,2.05,3.5)
	await physics_frame
	game.set_modal("craft")
	game.on_action("craft:wood_sword")
	check(live.count("wood_sword")==1 and live.held_durability("wood_sword")==60,"newly crafted sword is full durability")
	game.close_modal()
	await aim(Vector3(-0.5,2.05,10),Vector3(-0.5,2.5,12))
	game.equip(4)
	await screenshot("durability-hud")

	# Combat: successful hit wears sword; miss / no target does not.
	live.flags.complete=true
	live.flags.forest_complete=true
	live.flags.mansion_started=true
	live.add("bread",2)
	live.add("wood_sword",2)
	live.tool_durability.wood_sword=[5,60]
	game.equip(4)
	var guard: MansionGuard=null
	for child in game.mansion.get_children():
		if child is MansionGuard and not child.caster:guard=child
	check(guard!=null,"mansion guard exists for combat durability")
	if guard!=null:
		guard.cooldown=99
		guard.windup=0
		guard.position=Vector3(11,4.1,4)
		var stand:=MansionExpedition.ORIGIN+Vector3(11,4.1,2.1)
		var look_at:=MansionExpedition.ORIGIN+Vector3(11,5.2,4)
		await aim(stand,look_at)
		# Air swing / no target: attack returns without wear.
		game.target={}
		var miss_before:=live.held_durability("wood_sword")
		game.mansion.hit_cooldown=0
		game.mansion.attack()
		check(live.held_durability("wood_sword")==miss_before,"swing without a guard target does not consume sword durability")
		# Real click hit wears once.
		guard.position=Vector3(11,4.1,4)
		guard.cooldown=99
		await aim(stand,look_at)
		game.equip(4)
		game.mansion.hit_cooldown=0
		var hp:=guard.health
		var before_hit:=live.held_durability("wood_sword")
		await press_mouse_left(0.12)
		check(guard.health==hp-1,"real left-click damages the guard")
		check(live.held_durability("wood_sword")==before_hit-1,"successful combat hit consumes exactly one durability")
		# Same click held longer still blocked by cooldown, not multi-wear.
		game.mansion.hit_cooldown=0
		var after_one:=live.held_durability("wood_sword")
		await press_mouse_left(0.05)
		game.mansion.hit_cooldown=0
		guard.position=Vector3(11,4.1,4)
		game.target={"collider":guard}
		game.mansion.attack()
		check(live.held_durability("wood_sword")<=after_one,"follow-up attack is gated by cooldown")
	print("DURABILITY RESULT: ",failures," failures")
	quit(1 if failures else 0)
