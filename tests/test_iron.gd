extends SceneTree

var game: Node3D
var failures:=0

func check(ok: bool,message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures+=1

func _initialize() -> void:
	call_deferred("run")

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

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

func run() -> void:
	# Rule layer
	var rules:=ExpeditionProgress.new()
	rules.save_enabled=false
	check(rules.MAX_DURABILITY.stone_pickaxe==131 and rules.MAX_DURABILITY.iron_pickaxe==250,"book pickaxe durabilities: stone 131, iron 250")
	check(rules.best_pickaxe()=="","no pickaxe owned")
	rules.add("wood_pickaxe",1)
	check(rules.best_pickaxe()=="wood_pickaxe","wood pickaxe is the only option")
	rules.add("stone_pickaxe",1)
	check(rules.best_pickaxe()=="stone_pickaxe","stone outranks wood")
	rules.add("iron_pickaxe",1)
	check(rules.best_pickaxe()=="iron_pickaxe","iron is best pickaxe")
	check(not rules.can_mine("iron","wood_pickaxe") and rules.can_mine("iron","stone_pickaxe") and rules.can_mine("iron","iron_pickaxe"),"iron requires stone pickaxe or better")
	check(rules.can_mine("stone","wood_pickaxe") and rules.can_mine("stone","stone_pickaxe"),"wood pickaxe still mines stone and coal")
	rules.inventory.erase("stone_pickaxe")
	rules.inventory.erase("iron_pickaxe")
	rules.sync_tools()
	var no_iron:=rules.gather("iron_x","iron")
	check(no_iron.contains("石镐") and rules.count("raw_iron")==0,"wood pickaxe alone cannot mine iron")
	rules.add("stone_pickaxe",1)
	var got:=rules.gather("iron_x","iron")
	check(got.contains("粗铁") and rules.count("raw_iron")==1,"stone pickaxe yields one raw iron")
	check(rules.count("iron_ore")==0,"iron ore is not an inventory item, raw iron is")
	# Smelting chain
	var no_fuel:=rules.begin_smelting("iron_ingot")
	check(rules.count("raw_iron")==1 and rules.journey.job.is_empty() and no_fuel.contains("燃料"),"missing fuel does not consume raw iron")
	rules.add("coal",1)
	var started:=rules.begin_smelting("iron_ingot")
	check(rules.count("raw_iron")==0 and str(rules.journey.job.get("output",""))=="iron_ingot","furnace accepts raw iron and starts smelting")
	var again:=rules.begin_smelting("iron_ingot")
	check(again.contains("工作") or again.contains("正在"),"furnace rejects a second job while busy")
	rules.tick_smelting(6.1)
	check(rules.count("iron_ingot")==1 and rules.journey.job.is_empty(),"smelting completes into iron ingot")
	# Craft iron pickaxe needs 3 ingots + 2 sticks
	rules.add("raw_iron",2)
	rules.add("coal",1)
	rules.begin_smelting("iron_ingot")
	rules.tick_smelting(6.1)
	rules.add("coal",1)
	rules.begin_smelting("iron_ingot")
	rules.tick_smelting(6.1)
	check(rules.count("iron_ingot")==3,"two more smelts reach three iron ingots")
	rules.flags.bench=true
	var missing:=rules.craft("iron_pickaxe",false)
	check(rules.count("iron_pickaxe")==0 and missing.contains("工作台"),"iron pickaxe requires a workbench")
	rules.add("stick",2)
	missing=rules.craft("iron_pickaxe",true)
	check(rules.count("iron_pickaxe")==1 and missing.contains("铁镐"),"three iron ingots and two sticks craft iron pickaxe")	# Integration world
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	game.player.set_process_unhandled_input(false)
	game.close_modal()
	var live: ExpeditionProgress=game.progress
	var iron_nodes:=0
	var first_iron: Node3D=null
	for id in game.world.collectables:
		var node=game.world.collectables[id]
		for child in node.get_children():
			if child.has_meta("kind") and str(child.get_meta("kind"))=="iron":
				iron_nodes+=1
				if first_iron==null:first_iron=node
				break
	check(iron_nodes>=3,"world exposes a reachable iron outcrop")
	check(first_iron!=null,"iron node exists for real mining")
	# Wrong tool cannot mine iron.
	live.add("wood_pickaxe",1)
	game.equip(1)
	check(game.player.held_id=="wood_pickaxe","slot 2 equips wood pickaxe when it is best")
	var iron_before:=live.count("raw_iron")
	var wix:=first_iron.global_position.x
	var wiz:=first_iron.global_position.z
	var wiy:=first_iron.global_position.y
	await aim(Vector3(wix+1.6,float(game.world.height_at(int(wix+1.6),int(wiz)))+0.05,wiz+0.2),Vector3(wix,wiy+0.15,wiz))
	await hold_click(0.35)
	check(live.count("raw_iron")==iron_before,"wood pickaxe swing at iron does not yield ore")
	# Stone pickaxe mines iron for real.
	live.add("stone",3)
	live.add("stick",2)
	live.flags.bench=true
	game.player.position=Vector3(-1,2.05,3.5)
	await physics_frame
	game.set_modal("craft")
	game.on_action("craft:stone_pickaxe")
	check(live.count("stone_pickaxe")>=1 and game.player.held_id=="stone_pickaxe","crafting stone pickaxe auto-equips the better tool")
	game.close_modal()
	# Re-aim at a remaining iron node
	first_iron=null
	for id in game.world.collectables:
		var node=game.world.collectables[id]
		for child in node.get_children():
			if child.has_meta("kind") and str(child.get_meta("kind"))=="iron":
				first_iron=node
				break
		if first_iron!=null:break
	check(first_iron!=null,"iron node still present after failed wood swing")
	var ix:=first_iron.global_position.x
	var iz:=first_iron.global_position.z
	var iy:=first_iron.global_position.y
	var stand:=Vector3(ix+1.6,float(game.world.height_at(int(ix+1.6),int(iz)))+0.05,iz+0.2)
	await aim(stand,Vector3(ix,iy+0.15,iz))
	check(game.target.get("collider")!=null and game.target.collider.has_meta("kind") and str(game.target.collider.get_meta("kind"))=="iron","camera ray reaches iron ore body")
	var raw_before:=live.count("raw_iron")
	await hold_click(1.5)
	check(live.count("raw_iron")==raw_before+1,"real left-click with stone pickaxe yields raw iron")
	check(live.held_durability("stone_pickaxe")<int(live.MAX_DURABILITY.stone_pickaxe),"mining iron wears the stone pickaxe")
	await aim(Vector3(-1,2.05,3.5),Vector3(-1,2.5,2))
	# Furnace UI path needs the ore we just mined.
	live.add("coal",1)
	live.flags.furnace=true
	game.player.position=Vector3(-1,2.05,3.0)
	await physics_frame
	game.journey.open_panel("furnace")
	check(game.hud.current_modal=="furnace","furnace panel opens")
	game.on_action("journey:cook:iron_ingot")
	check(str(live.journey.job.get("output",""))=="iron_ingot","furnace button starts iron smelting")
	await create_timer(6.2).timeout
	check(live.count("iron_ingot")>=1,"timed smelting produces iron ingot")
	game.close_modal()
	# Craft iron pickaxe for real
	live.add("stick",2)
	while live.count("iron_ingot")<3:
		live.add("raw_iron",1)
		live.add("coal",1)
		live.begin_smelting("iron_ingot")
		live.tick_smelting(6.1)
	game.player.position=Vector3(-1,2.05,3.5)
	await physics_frame
	game.set_modal("craft")
	var before_iron_pick:=live.count("iron_pickaxe")
	game.on_action("craft:iron_pickaxe")
	check(live.count("iron_pickaxe")==before_iron_pick+1 and live.held_durability("iron_pickaxe")==250,"iron pickaxe crafts at full book durability and equips")
	check(game.player.held_id=="iron_pickaxe","slot 2 now holds iron pickaxe")
	check(game.hud.durability_label.text.contains("铁镐") or game.hud.durability_label.text.contains("250"),"HUD shows iron pickaxe durability")
	game.close_modal()
	# Save/reload chain
	state_save(live)
	var restored:=ExpeditionProgress.new()
	restored.save_path=live.save_path
	check(restored.load_game() and restored.count("iron_pickaxe")>=1,"iron tools survive reload")
	check(restored.best_pickaxe()=="iron_pickaxe","reload keeps iron as best pickaxe")
	await aim(Vector3(-1,2.05,3.5),Vector3(-1,2.5,2))
	await screenshot("iron-chain")
	print("IRON RESULT: ",failures," failures")
	quit(1 if failures else 0)

func state_save(state: ExpeditionProgress) -> void:
	state.save_enabled=true
	state.save_path="/tmp/explorer-iron-test.json"
	state.save_game()
	state.save_enabled=false

func progress_can_mine_iron(state: ExpeditionProgress, held: String) -> bool:
	return state.can_mine("iron", held)
