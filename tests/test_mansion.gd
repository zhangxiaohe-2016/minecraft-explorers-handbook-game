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
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func aim(local_pos: Vector3,local_target: Vector3) -> void:
	game.player.position=MansionExpedition.ORIGIN+local_pos
	game.player.velocity=Vector3.ZERO
	game.player.look_at(MansionExpedition.ORIGIN+Vector3(local_target.x,local_pos.y,local_target.z))
	game.player.camera.look_at(MansionExpedition.ORIGIN+local_target)
	await physics_frame
	await physics_frame
	game.target=game.player.ray()

func interact(local_pos: Vector3,local_target: Vector3,id: String) -> void:
	await aim(local_pos,local_target)
	check(game.mansion.target_id()==id,"ray reaches "+id)
	press(KEY_E)
	await process_frame

func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")

func walk(seconds: float) -> void:
	root.set_disable_input(true)
	Input.action_press("forward")
	await create_timer(seconds).timeout
	Input.action_release("forward")
	root.set_disable_input(false)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	# Ignore physical mouse motion/warp events during deterministic camera tests.
	game.player.set_process_unhandled_input(false)
	game.close_modal()
	var state: ExpeditionProgress=game.progress
	if "--reloadcheck" in OS.get_cmdline_user_args():
		check(state.has_flag("mansion_complete"),"completed route loads into real scene")
		check(not is_instance_valid(game.mansion.gate) and not is_instance_valid(game.mansion.cell_door) and not is_instance_valid(game.mansion.secret_door),"opened doors stay open after restart")
		var guards:=0
		for child in game.mansion.get_children():
			if child is MansionGuard:guards+=1
		check(guards==0,"defeated guards do not respawn on load")
		check(game.mansion.allay.global_position.distance_to(game.player.global_position)<3,"rescued allay resumes following after reload")
		print("MANSION RELOAD RESULT: %d failures"%failures)
		quit(failures)
		return
	check(int(state.journey.health)==10,"older save receives full health")
	await interact(Vector3(14,0.1,-3),Vector3(14,1.4,-1),"entrance")
	check(not state.has_flag("mansion_started"),"forest completion gates mansion")
	state.flags.forest_complete=true
	state.flags.journey_complete=true
	state.add("compass",1)
	await interact(Vector3(14,0.1,-3),Vector3(14,1.4,-1),"entrance")
	game.on_action("mansion:start")
	check(not state.has_flag("mansion_started"),"food is required before entry")
	state.add("bread",4)
	game.on_action("mansion:start")
	check(state.has_flag("mansion_started") and game.player.active,"briefing opens gate with sufficient equipment")
	await aim(Vector3(11,0.1,-4),Vector3(11,1.6,4))
	await walk(1.8)
	check(game.player.position.z>MansionExpedition.ORIGIN.z+2,"main door and foundation are physically passable")
	await aim(Vector3(29,9,-13),Vector3(11,7,8))
	await screenshot("mansion-exterior")
	await interact(Vector3(6.5,0.1,9),Vector3(6.5,0.5,11.5),"farm")
	check(state.count("wheat")==6,"farm awards useful ingredients")
	press(KEY_E)
	check(state.count("wheat")==6,"farm does not duplicate rewards")
	await interact(Vector3(16,0.1,1),Vector3(16,1.3,3),"statue")
	check(state.has_flag("mansion_clue"),"statue gives secret room clue")
	await screenshot("mansion-statue")
	# Walk both ramps using movement and physics, without jumping.
	for level in range(2):
		await aim(Vector3(0.7,level*4+0.1,18.5),Vector3(12,level*4+1.6,18.5))
		await walk(3)
		var local: Vector3=game.player.position-MansionExpedition.ORIGIN
		print("STAIR ",level," position ",local)
		check(local.x>9 and local.y>=level*4+3.85,"walk up stair flight "+str(level+1))
		await aim(Vector3(10.5,level*4+4.1,18.5),Vector3(0.5,level*4+5.6,18.5))
		await walk(2.2)
		local=game.player.position-MansionExpedition.ORIGIN
		check(local.x<2 and local.y<level*4+1,"walk down stair flight "+str(level+1))
	# Enemy damage, pause, walls, telegraph and weapon cooldown.
	var guard: MansionGuard
	var caster: MansionGuard
	for child in game.mansion.get_children():
		if child is MansionGuard:
			if child.caster:caster=child
			else:guard=child
	await aim(Vector3(7,4.1,4),Vector3(11,5.5,4))
	guard.position=Vector3(11,4.1,4)
	check(not guard.line_of_sight(),"solid wall blocks enemy line of sight")
	await aim(Vector3(11,4.1,7),Vector3(11,5.5,9))
	guard.position=Vector3(11,4.1,9)
	guard.cooldown=0
	await create_timer(0.15).timeout
	check(guard.windup>0,"vindicator warns before hitting")
	game.set_modal("pause")
	var hp:=int(state.journey.health)
	var windup:=guard.windup
	await create_timer(1.2).timeout
	check(int(state.journey.health)==hp and is_equal_approx(guard.windup,windup),"pause freezes damage and enemy attack timer")
	game.close_modal()
	await create_timer(1.1).timeout
	check(int(state.journey.health)<hp,"staying in melee range causes damage")
	state.journey.hunger=20
	state.eat("bread")
	check(int(state.journey.health)>hp-2,"food heals even when hunger is full")
	for i in range(3):
		await aim(guard.position+Vector3(0,0,-1.9),guard.position+Vector3(0,1,0))
		game.equip(2)
		game.mansion.hit_cooldown=0
		if i==0:
			var click:=InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT
			click.pressed=true
			Input.parse_input_event(click)
			Input.flush_buffered_events()
			await create_timer(0.1).timeout
			click=InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT
			Input.parse_input_event(click)
			Input.flush_buffered_events()
			check(guard.health==2,"left mouse input hits with equipped stone axe")
		else:game.mansion.attack()
		if i==0:
			var health:=guard.health
			game.mansion.attack()
			check(guard.health==health,"player attack cooldown prevents double hits")
	check(state.has_flag("defeated_vindicator"),"stone axe can defeat guard")
	await process_frame
	await interact(Vector3(5,4.1,9),Vector3(5,4.5,11),"storage")
	check(state.count("emerald")==3,"storage yields emeralds and bread")
	await interact(Vector3(15,4.1,7),Vector3(15,5.3,8.8),"cell")
	check(state.has_flag("mansion_cell_open"),"cell door opens")
	await interact(Vector3(18,4.1,10),Vector3(18,5.4,12),"allay")
	check(state.has_flag("mansion_allay") and state.count("log")==2,"allay accepts one log and follows")
	await aim(Vector3(17,8.1,10),Vector3(17,9.6,6))
	caster.cooldown=0
	await create_timer(0.2).timeout
	check(caster.windup>0 and caster.marker.visible,"evoker telegraphs ground attack")
	await screenshot("mansion-evoker")
	var before_dodge:=int(state.journey.health)
	game.player.position.x+=3
	await create_timer(1.3).timeout
	check(int(state.journey.health)==before_dodge,"moving off cast target avoids damage")
	for i in range(3):
		await aim(caster.position+Vector3(0,0,2),caster.position+Vector3(0,1,0))
		game.mansion.hit_cooldown=0
		game.mansion.attack()
	check(state.has_flag("defeated_evoker"),"evoker can be defeated")
	await process_frame
	await interact(Vector3(11,8.1,7.5),Vector3(9,9.5,7.5),"secret")
	check(state.has_flag("mansion_secret_open"),"clue unlocks concealed bookcase")
	await process_frame
	await interact(Vector3(5,8.1,9),Vector3(5,8.5,11.5),"secret_chest")
	check(state.count("mansion_notes")==1,"secret room grants persistent notes")
	await aim(Vector3(7,8.1,13),Vector3(4.5,9,6.5))
	await create_timer(0.35).timeout
	await screenshot("mansion-secret")
	var loot:=state.inventory.duplicate()
	game.mansion.immunity=0
	game.mansion.hurt(100)
	check(state.inventory==loot and int(state.journey.health)==10,"defeat safely returns player without dropping inventory")
	game.player.position=Vector3(-4.5,2.1,1)
	await create_timer(0.3).timeout
	check(state.has_flag("mansion_complete"),"bringing observations and allay home completes route")
	state.save_path="/tmp/explorer-mansion-test.json"
	state.save_enabled=true
	game.save()
	state.save_enabled=false
	var restored:=ExpeditionProgress.new()
	restored.save_path=state.save_path
	check(restored.load_game() and restored.has_flag("mansion_complete") and restored.has_flag("defeated_evoker") and restored.count("mansion_notes")==1,"mansion progress survives save and reload")
	check(restored.built.size()==46 and restored.count("bench")==21,"legacy shelter and equipment remain intact")
	print("MANSION RESULT: %d failures"%failures)
	quit(failures)
