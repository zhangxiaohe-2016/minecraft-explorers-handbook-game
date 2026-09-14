class_name VillageJourney
extends Node

var game: Node3D
var state: ExpeditionProgress
var village: PlainsVillage
var last_walked:=0.0
var refresh_time:=0.0
var job_label: Label
var job_bar: ProgressBar
var fuel_label: Label
var hunger_label: Label
var furnace_flame: Node3D
var bed_added:=false
var compass_display: CompassDisplay

func _ready() -> void:
	state=game.progress
	village=PlainsVillage.new()
	game.world.add_child(village)
	village.setup(game.art,state)
	game.art.chest(game.world,Vector3(-8.5,2,4.5))
	game.art.label(game.world,"远行补给箱\nE  查看",Vector3(-8.5,3.8,4.5))
	if state.has_flag("bed"): place_bed_model()
	for child in game.world.get_children():
		if child is Node3D and child.position.distance_to(ExplorerWorld.BENCH+Vector3(2,0,0))<0.1:
			game.art.mark(child,"furnace")
	furnace_flame=Node3D.new()
	game.world.add_child(furnace_flame)
	var mat: Material=game.art.color_mat(Color("ffbf4c"),true)
	for i in range(4):
		game.art.box(furnace_flame,ExplorerWorld.BENCH+Vector3(1.7+i*0.2,0.2,0.519),Vector3(0.11,0.15+(i%2)*0.08,0.015),mat)
	var light:=OmniLight3D.new()
	light.position=ExplorerWorld.BENCH+Vector3(2,0.5,0.6)
	light.light_color=Color("ffc473")
	light.omni_range=4
	furnace_flame.add_child(light)
	furnace_flame.visible=false
	hunger_label=game.hud.text(game.hud.root,"",Vector2(1007,748),Vector2(403,25),16,ExplorerHUD.CREAM)
	game.hud.text(game.hud.root,"M  地图     F  食物",Vector2(1030,860),Vector2(340,22),13,ExplorerHUD.CREAM)
	compass_display=CompassDisplay.new()
	compass_display.position=Vector2(1240,142)
	compass_display.size=Vector2(120,120)
	compass_display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	compass_display.player=game.player
	compass_display.state=state
	game.hud.root.add_child(compass_display)
	compass_display.caption=game.hud.text(compass_display,"",Vector2(-115,130),Vector2(310,70),17,ExplorerHUD.CREAM)

func stage() -> int:
	if state.has_flag("journey_complete") and state.has_flag("temperate_landmark"):return 8
	if state.has_flag("journey_complete"):return 7
	if not state.has_flag("supplies"):return 0
	if not state.has_flag("bed"):return 1
	if not state.has_flag("cooked_cooked_beef"):return 2
	if not state.has_flag("village_found"):return 3
	if state.count("map")==0:return 4
	return 5

func _process(delta: float) -> void:
	if state==null:return
	var menu: String=game.hud.current_modal
	if menu not in ["welcome","pause"]:
		state.journey.time=float(state.journey.time)+delta
		if state.tick_smelting(delta):
			game.hud.toast("熔炼完成，成品已放入背包。按 F 查看食物。")
	if furnace_flame!=null: furnace_flame.visible=not state.journey.job.is_empty()
	if menu=="furnace" and is_instance_valid(job_label):
		job_label.text="空闲 · 可以放入食材或原木" if state.journey.job.is_empty() else "正在制作 %s · 剩余 %.1f 秒" % [state.items[state.journey.job.output].name,float(state.journey.job.remaining)]
		job_bar.value=0 if state.journey.job.is_empty() else 1.0-float(state.journey.job.remaining)/6.0
		fuel_label.text="生牛肉 %d    原木 %d\n煤 %d    木炭 %d    木板 %d\n炉内还可加热 %d 次"%[state.count("raw_beef"),state.count("log"),state.count("coal"),state.count("charcoal"),state.count("plank"),int(state.journey.fuel)]
	if not state.has_flag("complete"):
		hunger_label.hide()
		last_walked=game.player.walked
		return
	hunger_label.show()
	if game.player.active:
		var distance:=maxf(0,game.player.walked-last_walked)
		var drain:=0.055 if Input.is_action_pressed("sprint") else 0.025
		state.journey.hunger=maxf(0,float(state.journey.hunger)-distance*drain)
		if game.player.position.distance_to(PlainsVillage.CENTER)<14 and not state.has_flag("village_found"):
			state.flags.village_found=true
			state.save_game()
			game.hud.toast("发现平原村庄！农夫和制图师就在前方。")
		if stage()==5 and game.near_cabin():
			state.flags.journey_complete=true
			state.save_game()
			open_panel("journey_complete")
	last_walked=game.player.walked
	game.player.sprint_allowed=float(state.journey.hunger)>6
	refresh_time+=delta
	if refresh_time>0.3:
		refresh_time=0
		if state.count("map")>0 and game.player.active: reveal_map()
		update_quest()
		var hunger:=int(ceil(float(state.journey.hunger)))
		hunger_label.text="饥饿值 %d / 20    F  吃东西%s"%[hunger," · 太饿时无法快跑" if hunger<=6 else ""]

func update_quest() -> void:
	var titles:=["为第一次远行做准备","在小屋安放一张床","让熔炉真正点起火","沿小路寻找村庄","与村民交换一张地图","带着地图回到营地","第一趟远行，完成","去森林瞭望台认路","温带路线已记录"]
	var bodies:=["门外新增了一个教学补给箱。\n对准箱子按 E，取出羊毛、\n木板、食材和少量燃料。", "工作台旁按 Tab：\n3 羊毛 + 3 木板 → 白色床。\n走进小屋，按 E 放置。\n对准床按 E 可休息并设定重生点。", "对准熔炉按 E 打开。\n选择烹饪牛肉，等 6 秒完成。\n成品自动收进背包，按 F 可食用。\n煤、木炭或木板都能作燃料。", "从石丘旁的小路向西北走。\n沿「村庄 ↖」路牌前进。\n尖顶屋、水井和农田就在前方。", "对准成熟麦穗按 E 收获。\n找农夫：6 小麦换 1 绿宝石。\n找制图师：1 绿宝石换定位地图。\n价格是本关的教学设定。", "按 M 打开地图，红箭头是你。\n金色方块代表营地。\n走回小屋附近，完成第一次远行。\n饥饿时按 F，吃些熟食或面包。", "补给、休息、烹饪、交易和地图\n已经连接成一条完整探索路线。\n你可以继续收获、交易与制图。", "沿村庄西侧的小路向南走，寻找森林瞭望台。\n对准瞭望台补给箱按 E，领取指南针。\n这是下一段温带路线的地标。", "你已经记录营地、村庄和森林瞭望台。\n指南针用于确认方向。\n下一步将进入更深的森林与遗迹。"]
	var index:=stage()
	game.hud.quest_number.text="平原远行  /  %02d"%(index+1)
	game.hud.quest_title.text=titles[index]
	game.hud.quest_body.text=bodies[index]
	if index==2 and not state.has_flag("furnace"):
		game.hud.quest_body.text="先采集 8 圆石，在工作台制作熔炉。\n工作台附近按 E 摆放。\n再对准熔炉按 E，开始烹饪。\n成品收进背包后，按 F 可食用。"
	game.hud.chapter_label.text="02  /  平原村庄      ·      第一次远行"
	game.hud.clock_label.text="白昼 · 探索与归途"
	if state.has_flag("journey_complete") and state.count("compass")>0:
		game.hud.quest_number.text="森林考察  /  观察与返程"
		game.hud.chapter_label.text="02  /  森林      ·      辨认与返程"
		game.hud.quest_title.text="辨认三种森林"
		game.hud.quest_body.text="沿瞭望台向南的林间路前进。\n对准各观察牌按 E 记录：\n繁花森林、白桦林、黑森林。\n右上红针始终指向世界出生点。"
		if state.has_flag("forest_flower") and state.has_flag("forest_birch") and state.has_flag("forest_dark"):
			game.hud.quest_title.text="用指南针回到出生点"
			game.hud.quest_body.text="转身，让红针朝表盘上方。\n沿小路绕开树木，向营地前进。\n出生点在营地南侧入口。\n床不会改变普通指南针的指向。"
			if game.player.active and Vector2(game.player.position.x+0.5,game.player.position.z-12).length()<2 and not state.has_flag("forest_complete"):
				state.flags.forest_complete=true
				state.save_game()
				game.hud.toast("森林考察完成：你已辨认三种森林，并借助指南针返回！")
		if state.has_flag("forest_complete"):
			game.hud.quest_title.text="森林考察完成"
			game.hud.quest_body.text="三种森林已记录，返程练习已完成。\n可再次访问观察牌温习。\n下一节：林地府邸（第 30–31 页）。\n府邸与战斗尚未开放。"

func reveal_map() -> void:
	var x:=int(floor((game.player.position.x+48)/4))
	var z:=int(floor((game.player.position.z+48)/4))
	for dx in range(-3,4):
		for dz in range(-3,4):
			if dx*dx+dz*dz>10:continue
			var key:=str(x+dx)+","+str(z+dz)
			if x+dx>=0 and x+dx<24 and z+dz>=0 and z+dz<24 and key not in state.journey.explored:
				state.journey.explored.append(key)

func target_kind() -> String:
	if game.target.is_empty() or not is_instance_valid(game.target.collider):return ""
	return str(game.target.collider.get_meta("journey_kind",""))

func hint() -> String:
	var kind:=target_kind()
	if not state.has_flag("complete"):
		return "远行内容\n完成第一夜后开放" if kind!="" else ""
	match kind:
		"forest":return "森林观察牌\nE  辨认与记录"
		"chest":
			var chest_id:=str(game.target.collider.get_meta("journey_id",""))
			if chest_id=="lookout": return "瞭望台补给\nE  "+("已领取指南针" if state.has_flag("temperate_landmark") else "领取指南针")
			return "远行补给箱\nE  "+("已领取补给" if state.has_flag("supplies") else "领取一次性教学补给")
		"bed":return "白色床\nE  休息，并设定重生点"
		"furnace":return "熔炉\nE  烹饪食物 / 烧制木炭"
		"villager":return "村民\nE  交谈与交易"
		"cartography":return "制图台\nE  查看地图的使用说明"
		"workbench":return "村庄工作台\nE 或 Tab  制作"
		"crop":return "成熟小麦\nE  收获 3 份小麦"
	if not state.has_flag("bed") and state.count("bed")>0 and game.world.inside_house(game.player.position):
		return "白色床已做好\nE  放在小屋内"
	if state.has_flag("furnace") and game.player.position.distance_to(ExplorerWorld.BENCH+Vector3(2,0,0))<2.5:
		return "E  使用熔炉     Tab  工作台制作"
	return ""

func interact() -> bool:
	var kind:=target_kind()
	if not state.has_flag("complete"):
		if kind!="":game.hud.toast("先完成营地的第一夜，再开始远行。")
		return kind!=""
	if kind=="chest":
		if str(game.target.collider.get_meta("journey_id",""))=="lookout":
			if state.has_flag("temperate_landmark"): game.hud.toast("瞭望台补给已经领过了。")
			else:
				state.add("compass",1)
				state.flags.temperate_landmark=true
				state.save_game()
				game.hud.toast("获得指南针。下一段温带路线已经记录。")
			return true
		if state.has_flag("supplies"):game.hud.toast("补给已经领过了。箱子不会重复发放物品。")
		else:
			for id in {"wool":3,"plank":8,"raw_beef":2,"coal":2}:
				state.add(id,{"wool":3,"plank":8,"raw_beef":2,"coal":2}[id])
			state.flags.supplies=true
			state.save_game()
			game.hud.toast("收到：3 羊毛、8 木板、2 生牛肉、2 煤。先制作白色床。")
		return true
	if kind=="forest":
		if not state.has_flag("journey_complete") or state.count("compass")==0:
			game.hud.toast("先完成村庄往返，并在瞭望台领取指南针。")
		else:
			open_panel("forest_"+str(game.target.collider.get_meta("journey_id")))
		return true
	if kind=="bed":
		var id: String=game.target.collider.get_meta("journey_id")
		state.journey.spawn=[-5,2.1,1.8] if id=="camp" else [-32,2.1,-29]
		state.flags["rested_"+id]=true
		state.save_game()
		game.hud.toast("休息完毕。重生点已设在"+("营地小屋。" if id=="camp" else "村庄旅人小屋。"))
		return true
	if kind=="villager":
		open_panel(str(game.target.collider.get_meta("journey_id")))
		return true
	if kind=="workbench":
		game.set_modal("craft")
		return true
	if kind=="cartography":
		open_panel("map" if state.count("map")>0 else "cartographer")
		return true
	if kind=="crop":
		var id: String=game.target.collider.get_meta("journey_id")
		if float(state.journey.time)-float(state.journey.crops.get(id,-1000))>=90:
			state.journey.crops[id]=float(state.journey.time)
			state.add("wheat",3)
			state.save_game()
			game.hud.toast("+3 小麦。村民会照看农田，90 秒后可再次收获。")
		return true
	if not state.has_flag("bed") and state.count("bed")>0 and game.world.inside_house(game.player.position):
		if state.install("bed"):
			place_bed_model()
			game.hud.toast("白色床已放好。对准床按 E 可设定重生点。")
		return true
	if kind=="furnace" or (state.has_flag("furnace") and game.player.position.distance_to(ExplorerWorld.BENCH+Vector3(2,0,0))<2.5):
		open_panel("furnace")
		return true
	return false

func place_bed_model() -> void:
	if bed_added:return
	game.art.bed(game.world,Vector3(-4,2,0.8))
	bed_added=true

func respawn() -> void:
	if state.journey.spawn.size()==3:
		var p: Array=state.journey.spawn
		game.player.position=Vector3(p[0],p[1],p[2])
		game.player.velocity=Vector3.ZERO
		game.hud.toast("已回到最近设定的床边，物资保留。")
	else: game.return_camp()

func open_panel(kind: String) -> void:
	if kind=="compass" and state.count("compass")==0:
		game.hud.toast("还没有指南针。瞭望台补给箱可领取一枚。")
		return
	if kind in ["map","food"] and not state.has_flag("complete"):
		game.hud.toast("先完成第一夜，接着学习补给和地图。")
		return
	if kind=="map" and state.count("map")==0:
		game.hud.toast("还没有地图。沿西北小路找到村庄，与制图师交易。")
		return
	game.set_modal(kind)
	var ui: ExplorerHUD=game.hud
	var panel: Panel=ui.modal
	var titles:={"furnace":"熔炉 · 烹饪与木炭","food":"旅途补给","farmer":"农夫 · 交谈与交易","cartographer":"制图师 · 地图与方向","map":"我的探索地图","journey_complete":"第一次远行，平安归来"}
	titles.merge({"compass":"路线与方向","forest_flower":"森林观察手记","forest_birch":"森林观察手记","forest_dark":"森林观察手记"})
	ui.text(panel,titles.get(kind,kind),Vector2(32,25),Vector2(780,48),30)
	ui.button(panel,"返回  [Esc]",Rect2(838,28,170,43),"close")
	match kind:
		"compass":
			ui.text(panel,"指南针 · 回到世界出生点",Vector2(40,105),Vector2(950,50),28,ExplorerHUD.GOLD)
			ui.text(panel,"第 18 页：普通指南针指向世界出生点。\n\n领取后，右上角会自动显示表盘。红色针尖就是目标方向。\n转动视角，让红针朝表盘上方，再沿可通行的小路前进。\n\n本世界的出生点在营地南侧入口。睡床只改变床边重生点，\n不会改变普通指南针的方向。指南针也不负责指向任务目标。\n\n书中磁石可重新绑定指南针；磁石功能尚未实现。",Vector2(40,190),Vector2(950,380),22)
		"forest_flower", "forest_birch", "forest_dark":
			var descriptions := {"forest_flower":"繁花森林 · 第 28 页\n\n树木较疏，空地上有成簇的花。\n书中这些花可用来制造染料、装饰物品。\n本次先学习辨认景观，染料制作尚未开放。", "forest_birch":"白桦林 · 第 28 页\n\n白色树皮带深色斑纹，让林中显得更明亮。\n古老白桦林的树更高；本路线展示普通白桦林。\n可对准白桦树干，按住左键采集木材。", "forest_dark":"黑森林 · 第 28–29 页\n\n密集深色树冠遮蔽阳光，巨型蘑菇穿出林间。\n书中阴影里可能藏着敌对生物。\n当前为安全观察路线，怪物与战斗尚未开放。"}
			ui.text(panel,descriptions[kind],Vector2(40,145),Vector2(950,300),25,ExplorerHUD.CREAM)
			ui.button(panel,"记录这片森林",Rect2(40,515,950,65),"journey:observe:"+kind,true)
		"furnace":
			ui.text(panel,"依据第 9、14–15 页：燃料加热食材，也能把原木烧成木炭。",Vector2(34,92),Vector2(970,37),17,ExplorerHUD.MINT)
			job_label=ui.text(panel,"",Vector2(40,156),Vector2(950,39),22,ExplorerHUD.GOLD)
			job_bar=ProgressBar.new()
			job_bar.position=Vector2(40,220)
			job_bar.size=Vector2(950,20)
			job_bar.max_value=1
			job_bar.show_percentage=false
			panel.add_child(job_bar)
			fuel_label=ui.text(panel,"",Vector2(40,285),Vector2(940,130),22)
			ui.button(panel,"生牛肉 → 熟牛肉",Rect2(40,449,440,58),"journey:cook:cooked_beef",true)
			ui.button(panel,"原木 → 木炭",Rect2(510,449,480,58),"journey:cook:charcoal")
			ui.text(panel,"成品自动收进背包。离开面板后仍会继续；Esc 暂停时停止。\n优先使用煤、其次木炭、最后木板。煤或木炭可加热 8 次，本关木板可加热 1 次。",Vector2(40,552),Vector2(960,78),16,ExplorerHUD.MUTED)
		"food":
			ui.text(panel,"当前饥饿值：%.1f / 20。熟食比生食更适合长途探索。"%float(state.journey.hunger),Vector2(35,95),Vector2(960,42),20,ExplorerHUD.MINT)
			var ids:=["cooked_beef","bread","raw_beef"]
			for i in range(3):
				var id: String=ids[i]
				var y:=179+i*132
				var icon:=TextureRect.new()
				icon.texture=load("res://assets/textures/"+id+".png")
				icon.position=Vector2(46,y-7)
				icon.size=Vector2(90,90)
				icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				panel.add_child(icon)
				ui.text(panel,"%s ×%d"%[state.items[id].name,state.count(id)],Vector2(165,y),Vector2(530,38),25)
				ui.text(panel,"恢复 %d 点饥饿值"%[8,5,3][i],Vector2(166,y+44),Vector2(530,29),17,ExplorerHUD.MUTED)
				var b:=ui.button(panel,"吃一份",Rect2(714,y+7,270,57),"journey:eat:"+id,true)
				b.disabled=state.count(id)==0 or float(state.journey.hunger)>=20
			ui.text(panel,"饥饿值低于或等于 6 时不能快跑。当前教学模式不会因饥饿死亡。",Vector2(40,614),Vector2(960,38),16,ExplorerHUD.MUTED)
		"farmer":
			ui.text(panel,"「出远门要带些吃的。农田里成熟的小麦，可以拿来和我交换。」",Vector2(36,106),Vector2(970,62),22,ExplorerHUD.CREAM)
			ui.text(panel,"你的物资：小麦 %d    绿宝石 %d"%[state.count("wheat"),state.count("emerald")],Vector2(40,222),Vector2(950,45),23,ExplorerHUD.GOLD)
			ui.button(panel,"6 小麦 → 1 绿宝石",Rect2(40,326,950,65),"journey:trade:wheat",true)
			ui.button(panel,"1 绿宝石 → 3 面包",Rect2(40,422,950,65),"journey:trade:bread")
			ui.text(panel,"第 26 页：有职业的村民能够交易，使用绿宝石和其他物品作为货币。\n本关交易数量为教学设定。麦田由村民照看，收获后 90 秒重新成熟。",Vector2(40,550),Vector2(960,76),17,ExplorerHUD.MUTED)
		"cartographer":
			ui.text(panel,"「地图会记住你走过的地方。带着它出发，也记得回家的路。」",Vector2(36,105),Vector2(970,74),23)
			ui.text(panel,"定位地图\n记录地形、自己的位置，以及发现的营地和村庄。\n地图上方是北方，红箭头表示你的位置和朝向。",Vector2(40,226),Vector2(960,133),23,ExplorerHUD.MINT)
			ui.button(panel,"查看我的地图  [M]" if state.count("map")>0 else "1 绿宝石 → 1 定位地图",Rect2(40,431,950,65),"journey:map" if state.count("map")>0 else "journey:trade:map",true)
			ui.text(panel,"依据第 20–21、26 页。当前持有绿宝石：%d\n本次先通过制图师获得地图；纸张、指南针合成与地图缩放后续补充。"%state.count("emerald"),Vector2(40,557),Vector2(960,76),17,ExplorerHUD.MUTED)
		"map":
			reveal_map()
			var map:=ExplorationMap.new()
			map.position=Vector2(42,152)
			map.size=Vector2(480,480)
			map.world=game.world
			map.state=state
			map.player=game.player
			panel.add_child(map)
			ui.text(panel,"北 N ↑",Vector2(218,97),Vector2(240,35),20,ExplorerHUD.GOLD)
			ui.text(panel,"图例\n\n红箭头  ·  你的位置与朝向\n金色方块  ·  林地营地\n白色圆点  ·  已发现的村庄\n浅褐色  ·  尚未探索\n蓝色  ·  河流",Vector2(585,155),Vector2(425,320),21)
			ui.text(panel,"随身携带地图时，会自动记录\n附近地形。探索记录随存档保留。\n\n按 M 或 Esc 返回游戏。",Vector2(585,493),Vector2(425,143),17,ExplorerHUD.MUTED)
		"journey_complete":
			ui.text(panel,"你带回来的，不只是一张地图。",Vector2(41,139),Vector2(950,69),35,ExplorerHUD.GOLD)
			ui.text(panel,"从营地准备食物，到第一次发现村庄、收获作物、\n与村民交易，再沿着地图返回。\n\n你的营地、背包、农田状态和探索记录都已保存。\n接下来可以继续补给，或在这片平原自由走走。\n森林、丛林及更远的章节仍待后续开发。",Vector2(43,269),Vector2(950,237),23)
			ui.button(panel,"继续探索",Rect2(42,573,430,62),"close",true)
			ui.button(panel,"打开探索手记",Rect2(506,573,483,62),"journal")

func on_action(id: String) -> bool:
	if not id.begins_with("journey:"):return false
	if id=="journey:map":
		open_panel("map")
		return true
	var parts:=id.split(":")
	if parts.size()<3:return true
	var result:=""
	var panel: String=game.hud.current_modal
	match parts[1]:
		"observe":
			state.flags[parts[2]]=true
			state.save_game()
			result="已记录。继续沿林间路观察其他森林。"
		"cook":result=state.begin_smelting(parts[2])
		"eat":result=state.eat(parts[2])
		"trade":result=state.trade(parts[2])
	open_panel(panel)
	game.hud.toast(result)
	return true
