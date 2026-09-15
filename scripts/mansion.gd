class_name MansionExpedition
extends Node3D

const ORIGIN:=Vector3(-14,2,21)
var game: Node3D
var state: ExpeditionProgress
var art: ExplorerArt
var dark: StandardMaterial3D
var carpet: StandardMaterial3D
var gate: Node3D
var secret_door: Node3D
var cell_door: Node3D
var allay: Node3D
var health_label: Label
var hit_cooldown:=0.0
var immunity:=0.0
var bob_time:=0.0
var fang_effects: Array[Dictionary]=[]
var tiled_materials: Dictionary={}

func _ready() -> void:
	position=ORIGIN
	state=game.progress
	art=game.art
	# Older saves may stand where the new building now exists.
	var old_local: Vector3=game.player.position-ORIGIN
	if not state.has_flag("mansion_started") and Rect2(0,0,22,22).has_point(Vector2(old_local.x,old_local.z)):
		game.player.position=ORIGIN+Vector3(11,0.1,-3)
	dark=art.materials.plank.duplicate()
	dark.albedo_color=Color("584135")
	carpet=art.color_mat(Color("9c2531"))
	build_shell()
	build_rooms()
	for entry in [["vindicator",Vector3(11,4.1,8),false],["evoker",Vector3(17,8.1,6),true]]:
		if not state.has_flag("defeated_"+entry[0]):
			var guard:=MansionGuard.new()
			add_child(guard)
			guard.setup(self,entry[0],entry[1],entry[2])
	health_label=game.hud.text(game.hud.root,"",Vector2(1015,350),Vector2(380,70),18,ExplorerHUD.CREAM)
	art.label(game.world,"林地府邸 ↓\n准备食物与木剑/石斧",Vector3(-3,4.1,16),Color("f3d279")).pixel_size=0.004
	if state.has_flag("mansion_started"):gate.queue_free()
	if state.has_flag("mansion_secret_open"):secret_door.queue_free()
	if state.has_flag("mansion_cell_open"):cell_door.queue_free()
	if state.has_flag("mansion_allay"):allay.global_position=game.player.global_position+Vector3(1,1.5,0)

func block(pos: Vector3,size: Vector3,mat: Material,solid:=true) -> MeshInstance3D:
	var mesh:=art.box(self,pos,size,mat,solid)
	if mat is StandardMaterial3D and mat.albedo_texture!=null:
		var key:=mat.get_instance_id()
		if not tiled_materials.has(key):
			var tiled: StandardMaterial3D=mat.duplicate()
			tiled.uv1_triplanar=true
			tiled.uv1_world_triplanar=true
			tiled.uv1_scale=Vector3.ONE
			tiled_materials[key]=tiled
		mesh.material_override=tiled_materials[key]
	return mesh

func tag(node: Node,id: String) -> void:
	if node is StaticBody3D:node.set_meta("mansion_id",id)
	for child in node.get_children():tag(child,id)

func sign_at(pos: Vector3,text: String,id: String) -> void:
	var plaque:=block(pos,Vector3(1.3,0.55,0.12),dark)
	tag(plaque,id)
	art.label(self,text,pos+Vector3(0,0.45,0)).pixel_size=0.0035

func build_shell() -> void:
	block(Vector3(11,-0.15,11),Vector3(22.6,0.3,22.6),art.materials.stone)
	for level in range(3):
		var y:=level*4.0
		if level==0:block(Vector3(11,y+0.035,11),Vector3(22,0.07,22),art.materials.plank)
		else:
			block(Vector3(11,y-0.12,8.5),Vector3(22,0.24,17),art.materials.plank)
			block(Vector3(0.5,y-0.12,19.5),Vector3(1,0.24,5),art.materials.plank)
			block(Vector3(15.5,y-0.12,19.5),Vector3(13,0.24,5),art.materials.plank)
			block(Vector3(5,y-0.12,21),Vector3(8,0.24,2),art.materials.plank)
		for x in [0.0,22.0]:
			block(Vector3(x,y+2,11),Vector3(0.3,4,22),dark)
			for z in [1.0,7.0,14.0,21.0]:block(Vector3(x,y+2,z),Vector3(0.48,4,0.45),art.materials.stone)
		# North facade leaves a three-metre entrance and inset blue window grids.
		for x in range(22):
			if level==0 and x>=9 and x<=12:continue
			block(Vector3(x+0.5,y+2,0),Vector3(1,4,0.3),dark)
		block(Vector3(11,y+2,22),Vector3(22,4,0.3),dark)
		for z in [-0.2,22.2]:
			block(Vector3(11,y+0.3,z),Vector3(22.5,0.6,0.4),art.materials.stone)
			if level==0 and z<0:
				# Keep the entrance walkable; the decorative foundation skips its gap.
				get_child(get_child_count()-1).queue_free()
				block(Vector3(4.4,y+0.3,z),Vector3(8.8,0.6,0.4),art.materials.stone)
				block(Vector3(17.6,y+0.3,z),Vector3(8.8,0.6,0.4),art.materials.stone)
			block(Vector3(11,y+3.8,z),Vector3(22.7,0.28,0.5),art.materials.stone)
			for x in [3.0,7.0,15.0,19.0]:
				window(Vector3(x,y+2.1,z+(-0.025 if z<0 else 0.025)))
		for x in [0.0,8.8,13.2,22.0]:
			block(Vector3(x,y+2,-0.26),Vector3(0.45,4,0.55),art.materials.stone)
		# Rooms on both sides of a red-carpeted central corridor.
		for x in [9.0,13.0]:
			block(Vector3(x,y+2,3),Vector3(0.25,4,6),dark)
			block(Vector3(x,y+2,12),Vector3(0.25,4,6),dark)
			block(Vector3(x,y+3.6,7.5),Vector3(0.25,0.8,3),dark)
		block(Vector3(11,y+(0.095 if level==0 else 0.025),8),Vector3(2,0.04,16),carpet,false)
		block(Vector3(11,y+2,15),Vector3(22,4,0.2),dark)
		# Opening to the stair hall, cut by using two side panels instead.
		get_child(get_child_count()-1).queue_free()
		block(Vector3(4.5,y+2,15),Vector3(9,4,0.2),dark)
		block(Vector3(17.5,y+2,15),Vector3(9,4,0.2),dark)
		for z in [3.0,11.0,16.0]:
			lamp(Vector3(11,y+3.1,z))
		if level<2:
			var ramp:=block(Vector3(5,y+1.86,18.5),Vector3(sqrt(80),0.25,2.7),dark)
			ramp.rotation.z=atan(0.5)
			for i in range(16):block(Vector3(1.25+i*0.5,y+0.13+i*0.25,18.5),Vector3(0.49,0.05,2.6),art.materials.plank,false)
			art.label(self,"沿木梯上楼 →",Vector3(1.1,y+1.1,16.5)).pixel_size=0.003
			# Guard rails around the open staircase, retaining entry and landing.
			block(Vector3(5,y+5,17),Vector3(7.8,0.12,0.12),dark)
		for pos in [Vector3(4,y+2.8,7),Vector3(18,y+2.8,7)]:lamp(pos)
	for tier in range(4):
		block(Vector3(11,12+tier*0.35,11),Vector3(24-tier*0.9,0.35,24-tier*0.9),dark)
	gate=block(Vector3(11,1.5,0),Vector3(3.8,3,0.25),dark)
	tag(gate,"entrance")
	sign_at(Vector3(14,1.4,-1),"林地府邸 · E 入内须知","entrance")
	art.label(self,"林地府邸",Vector3(11,13.9,0),Color("e2cfa1")).pixel_size=0.009

func window(pos: Vector3) -> void:
	block(pos,Vector3(1.8,2.1,0.05),art.color_mat(Color("253a42")),false)
	var frame:=art.color_mat(Color("7aafba"))
	for x in [-0.9,0.0,0.9]:block(pos+Vector3(x,0,-0.04 if pos.z<0 else 0.04),Vector3(0.09,2.2,0.04),frame,false)
	for y in [-1.05,0.0,1.05]:block(pos+Vector3(0,y,-0.04 if pos.z<0 else 0.04),Vector3(1.9,0.09,0.04),frame,false)

func lamp(pos: Vector3) -> void:
	var light:=OmniLight3D.new()
	light.position=pos
	light.light_color=Color("ffd39a")
	light.light_energy=0.8
	light.omni_range=7
	add_child(light)
	block(pos,Vector3(0.18,0.24,0.18),art.color_mat(Color("ffc778"),true),false)

func build_rooms() -> void:
	# Ground-floor farm, modelled on the stacked crop beds in the book.
	for row in range(3):
		block(Vector3(4,0.3,3+row*2.5),Vector3(5,0.6,1.3),art.materials.soil)
		for i in range(10):
			block(Vector3(1.8+i*0.48,0.95,3+row*2.5),Vector3(0.12,0.8,0.12),art.color_mat(Color("ccb54d")),false)
	var farm:=art.chest(self,Vector3(6.5,0,11.5))
	tag(farm,"farm")
	art.label(self,"农场房 · E 收集补给",Vector3(5,2.6,11.5)).pixel_size=0.0035
	# A harmless giant chicken statue (explicitly described in printed page 30).
	block(Vector3(18,1.7,7),Vector3(2.2,2.2,2.5),art.materials.wool)
	block(Vector3(18,3,5.7),Vector3(1.5,1.6,1.3),art.materials.wool)
	block(Vector3(18,2.7,4.8),Vector3(1.1,0.45,0.5),art.color_mat(Color("dfb846")))
	block(Vector3(18,2.1,5),Vector3(0.5,0.6,0.4),carpet)
	for x in [17.5,18.5]:
		block(Vector3(x,0.45,7),Vector3(0.3,0.9,0.4),art.color_mat(Color("cfb244")))
		block(Vector3(x,3.2,5.02),Vector3(0.18,0.18,0.03),art.color_mat(Color("263231")),false)
	sign_at(Vector3(16,1.3,3),"雕像室 · E 查看线索","statue")
	for x in [2.0,5.0]:
		for z in [3.0,7.0,11.0]:
			for height in [4.0,5.5]:
				block(Vector3(x,height+1.12,z),Vector3(2,0.15,1.4),art.materials.plank)
				var chest:=art.chest(self,Vector3(x,height,z))
				tag(chest,"storage")
	art.label(self,"储藏房 · 小心巡逻守卫",Vector3(6,6.5,7)).pixel_size=0.0035
	# Stone cell with an operable barred door, and a small blue allay.
	for x in range(15,22):
		if x in [17,18]:continue
		block(Vector3(x,5.5,9),Vector3(0.1,3,0.1),art.materials.stone)
	cell_door=Node3D.new()
	add_child(cell_door)
	for x in [17.0,17.5,18.0]:art.box(cell_door,Vector3(x,5.5,9),Vector3(0.1,3,0.1),art.materials.stone,true)
	tag(cell_door,"cell")
	sign_at(Vector3(15,5.3,8.8),"牢房 · E 开门","cell")
	allay=Node3D.new()
	add_child(allay)
	allay.position=Vector3(18,5.4,12)
	var blue:=art.color_mat(Color("60cfe8"),true)
	art.box(allay,Vector3.ZERO,Vector3(0.38,0.38,0.35),blue,true)
	art.box(allay,Vector3(0,-0.33,0),Vector3(0.22,0.36,0.2),blue)
	for side in [-1,1]:
		art.box(allay,Vector3(side*0.27,-0.15,0),Vector3(0.2,0.3,0.035),art.color_mat(Color("b0eff4"),true))
		art.box(allay,Vector3(side*0.09,0.03,-0.18),Vector3(0.055,0.09,0.025),art.materials.wool)
	tag(allay,"allay")
	art.label(allay,"悦灵 · E 递给它一块原木",Vector3(0,0.6,0)).pixel_size=0.0025
	# Concealed bookcase opens to an inert imitation End portal room.
	secret_door=block(Vector3(9,9.5,7.5),Vector3(0.45,3,3),dark)
	tag(secret_door,"secret")
	for i in range(12):
		var book:=art.box(secret_door,Vector3(0.24,-0.8+(i/6)*1.2,-1.1+(i%6)*0.43),Vector3(0.08,0.8,0.3),art.color_mat([Color("8b3434"),Color("687a55"),Color("b39b57")][i%3]))
		book.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in range(3,7):
		for z in range(5,9):
			if x in [3,6] or z in [5,8]:block(Vector3(x,8.4,z),Vector3(0.95,0.8,0.95),art.color_mat(Color("72844e")))
	block(Vector3(4.5,8.06,6.5),Vector3(2,0.1,2),art.color_mat(Color("c98036")),false)
	var secret_chest:=art.chest(self,Vector3(5,8,11.5))
	tag(secret_chest,"secret_chest")
	art.label(self,"仿制传送门 · 无法传送",Vector3(4.5,10,6.5)).pixel_size=0.003

func target_id() -> String:
	if game.target.is_empty():return ""
	return str(game.target.collider.get_meta("mansion_id",""))

func hint() -> String:
	if not game.target.is_empty() and game.target.collider is MansionGuard:
		return "守卫\n5 木剑 / 3 石斧 · 按住左键攻击 · 抬手时后退"
	var id:=target_id()
	if id=="":return ""
	return {"entrance":"林地府邸\nE  查看入内须知", "farm":"农场房补给\nE  收集小麦", "statue":"无害雕像\nE  查看与寻找线索", "storage":"储藏箱\nE  收集一次性物资", "cell":"牢房铁门\nE  打开", "allay":"悦灵\nE  递给它 1 原木", "secret":"异常的书架\nE  检查", "secret_chest":"秘密房间宝箱\nE  取出考察手记"}.get(id,"")

func interact() -> bool:
	var id:=target_id()
	if id=="":return false
	if not state.has_flag("forest_complete"):
		game.hud.toast("先完成三种森林的观察，并返回出生点。")
		return true
	if id=="entrance":
		open_briefing()
		return true
	if not state.has_flag("mansion_started"):return true
	match id:
		"farm":reward("mansion_farm",{"wheat":6},"获得 6 小麦，可以制作面包。接着去雕像室找线索。")
		"statue":
			state.flags.mansion_clue=true
			state.save_game()
			game.hud.toast("这只巨鸡只是雕像。墙上笔记：三楼西侧有一面可推动的书架。")
		"storage":reward("mansion_storage",{"emerald":3,"bread":3},"获得 3 绿宝石、3 面包。二楼东侧牢房里有悦灵。")
		"cell":
			state.flags.mansion_cell_open=true
			state.save_game()
			if is_instance_valid(cell_door):cell_door.queue_free()
			game.hud.toast("牢房已打开。走近悦灵，对准它按 E，递给它一块原木。")
		"allay":
			if state.has_flag("mansion_allay"):game.hud.toast("悦灵已经愿意跟随你。")
			elif not state.has_flag("mansion_cell_open"):game.hud.toast("先打开牢房门。")
			elif state.pay({"log":1}):
				state.flags.mansion_allay=true
				state.save_game()
				game.hud.toast("悦灵接过原木，开始跟随你。")
			else:game.hud.toast("需要 1 原木。可到森林采集后再来。")
		"secret":
			if not state.has_flag("mansion_clue"):game.hud.toast("书架有些异常。先去一楼东侧雕像室寻找线索。")
			else:
				state.flags.mansion_secret_open=true
				state.save_game()
				secret_door.queue_free()
				game.hud.toast("书架后露出一间秘密房间。里面的仿制传送门无法传送。")
		"secret_chest":reward("mansion_secret",{"mansion_notes":1},"得到府邸考察手记。把发现和悦灵一起带回营地。")
	return true

func reward(flag: String,items: Dictionary,message: String) -> void:
	if state.has_flag(flag):game.hud.toast("这里的物资已取走，不会重复发放。")
	else:
		for id in items:state.add(id,items[id])
		state.flags[flag]=true
		state.save_game()
		game.hud.toast(message)

func open_briefing() -> void:
	game.set_modal("mansion")
	var ui: ExplorerHUD=game.hud
	ui.text(ui.modal,"林地府邸 · 进入前读一读",Vector2(40,32),Vector2(950,50),30)
	ui.text(ui.modal,"一楼：农场补给、巨鸡雕像的秘密线索。\n二楼：储藏房与牢房，小心巡逻的卫道士。\n三楼：书架后的秘密房间，留意唤魔者的施法。\n\n5 木剑 / 3 石斧，近距离按住左键攻击。\n抬斧时后退；看见脚下红色提示时，立即走开。\nF 食物恢复饥饿和 2 点生命。Esc 暂停。\n生命耗尽回到床边，物资保留。\n\n简化战斗教学：木剑攻击间隔较短；无耐久。\n悦灵跟随；恼鬼召唤尚未加入。",Vector2(40,115),Vector2(970,420),22)
	ui.button(ui.modal,"准备好了，进入府邸",Rect2(40,577,610,60),"mansion:start",true)
	ui.button(ui.modal,"先回去准备",Rect2(680,577,310,60),"close")

func start() -> void:
	if not state.has_flag("forest_complete"):return
	if state.count("stone_axe")+state.count("wood_sword")==0 or state.count("bread")+state.count("cooked_beef")==0:
		game.hud.toast("先准备木剑或石斧，以及至少一份面包或熟牛肉。")
		return
	state.flags.mansion_started=true
	state.save_game()
	if is_instance_valid(gate):gate.queue_free()
	game.close_modal()
	game.hud.toast("进入府邸。先探索一楼两侧房间，楼梯在走廊尽头。")

func update_combat(delta: float) -> void:
	hit_cooldown=maxf(0,hit_cooldown-delta)
	immunity=maxf(0,immunity-delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):attack()

func attack() -> void:
	if hit_cooldown>0 or not game.player.active or not state.has_flag("mansion_started") or game.target.is_empty():return
	var enemy: Object=game.target.collider
	if not enemy is MansionGuard:return
	if game.player.global_position.distance_to(enemy.global_position)>3.2:
		return
	if game.player.held_id not in ["stone_axe","wood_sword"]:
		game.hud.toast("按 5 装备木剑，或按 3 装备石斧，再近距离攻击。")
		return
	hit_cooldown=0.35 if game.player.held_id=="wood_sword" else 0.55
	game.player.swing=1
	enemy.strike()

func hurt(amount: int) -> void:
	if immunity>0 or not game.player.active:return
	state.journey.health=maxi(0,int(state.journey.health)-amount)
	immunity=1.0
	game.tone(65,0.15,0.15)
	if int(state.journey.health)==0:
		state.journey.health=10
		game.journey.respawn()
		game.player.velocity=Vector3.ZERO
		for child in get_children():
			if child is MansionGuard:
				child.windup=0
				child.marker.hide()
		game.hud.toast("生命耗尽，已安全返回休息点，物资保留。补给后再来。")
	else:game.hud.toast("受到攻击！后退躲避，按 F 吃食物恢复生命。")
	game.save()

func show_fangs(point: Vector3) -> void:
	var effect:=Node3D.new()
	add_child(effect)
	effect.global_position=point
	for side in [-1,1]:
		var fang:=MeshInstance3D.new()
		var mesh:=CylinderMesh.new()
		mesh.top_radius=0
		mesh.bottom_radius=0.25
		mesh.height=0.9
		mesh.radial_segments=4
		fang.mesh=mesh
		fang.material_override=art.color_mat(Color("e3dcc5"))
		fang.position=Vector3(side*0.36,0.4,0)
		effect.add_child(fang)
	fang_effects.append({"node":effect,"time":0.6})

func _process(delta: float) -> void:
	health_label.visible=state.has_flag("mansion_started")
	health_label.text="生命 %d / 10\n抬斧时后退 · 远离红色施法区"%int(state.journey.health)
	if not game.player.active:return
	for i in range(fang_effects.size()-1,-1,-1):
		fang_effects[i].time-=delta
		if fang_effects[i].time<=0:
			fang_effects[i].node.queue_free()
			fang_effects.remove_at(i)
		else:fang_effects[i].node.scale.y=sin(float(fang_effects[i].time)/0.6*PI)
	bob_time+=delta
	if state.has_flag("mansion_allay"):
		var goal: Vector3=game.player.global_position+game.player.global_basis.x*0.9+Vector3(0,1.35+sin(bob_time*3)*0.15,0)
		allay.global_position=allay.global_position.lerp(goal,minf(1,delta*3))
	elif is_instance_valid(allay):allay.position.y=5.4+sin(bob_time*2)*0.12
	if state.has_flag("mansion_started") and not state.has_flag("mansion_complete") and ready_to_return() and game.near_cabin():
		state.flags.mansion_complete=true
		game.save()
		game.hud.toast("府邸考察完成！带回了补给、秘密手记和悦灵。")

func ready_to_return() -> bool:
	return state.has_flag("mansion_farm") and state.has_flag("mansion_storage") and state.has_flag("mansion_allay") and state.has_flag("mansion_secret")

func update_quest() -> void:
	game.hud.chapter_label.text="02  /  林地府邸      ·      探索与撤退"
	game.hud.quest_number.text="府邸考察  /  第 30–31 页"
	game.hud.quest_title.text="准备进入林地府邸"
	game.hud.quest_body.text="带上木剑或石斧、熟食和一块原木。\n营地南侧岔路向南走，\n对准府邸门旁告示按 E。\n阅读危险提示后再进入。"
	if state.has_flag("mansion_started"):
		game.hud.quest_title.text="探索府邸的房间"
		game.hud.quest_body.text="一楼：农场 %s · 雕像 %s\n二楼：储藏 %s · 悦灵 %s\n三楼：秘密房间 %s\n走廊尽头上楼\n5 木剑 / 3 石斧 · 左键攻击 · F 食物"%[done("mansion_farm"),done("mansion_clue"),done("mansion_storage"),done("mansion_allay"),done("mansion_secret")]
	if ready_to_return():
		game.hud.quest_title.text="带着发现回到营地"
		game.hud.quest_body.text="沿楼梯下楼，穿过北侧正门。\n红针指向世界出生点。\n走回营地小屋，完成府邸考察。\n悦灵会跟着你。"
	if state.has_flag("mansion_complete"):
		game.hud.quest_title.text="府邸考察完成"
		game.hud.quest_body.text="你已带回物资、手记和悦灵。\n房间与战斗记录已经保存。\n下一节：丛林与神庙（第 32–33 页）。"

func done(flag: String) -> String:
	return "✓" if state.has_flag(flag) else "○"
