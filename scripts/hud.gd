class_name ExplorerHUD
extends CanvasLayer

signal action(id: String)
var root: Control
var quest_title: Label
var quest_body: Label
var quest_number: Label
var hint: Label
var toast_label: Label
var clock_label: Label
var inventory_line: Label
var chapter_label: Label
var gather_bar: ProgressBar
var modal: Panel
var modal_content: Control
var current_modal := ""
var font: Font
var state: ExpeditionProgress
var near_bench := false
var toast_time := 0.0
var hotbar: Array[Panel] = []
var quest_card: Panel

const INK := Color("182d2a")
const CREAM := Color("f2ebd4")
const MUTED := Color("acbcac")
const GOLD := Color("e5bb6e")
const MINT := Color("b5ce9c")
const QUESTS := [
	["先试着走一走", "移动鼠标看向四周。\n按 W A S D 行走，空格跳跃。\n沿着木栅栏走进营地。"],
	["从一块原木开始", "走近右侧的橡树，对准树干。\n按住鼠标左键，收集原木。\n不需要工具，空手就能开始。"],
	["做一张工作台", "按 Tab 打开制作。\n原木 → 木板 → 工作台。\n走到营地金色标记处，按 E 放置。"],
	["制作你的第一把镐", "站在工作台旁，按 Tab。\n先做木棍，再用 3 木板 + 2 木棍\n制作木镐，按 2 拿在手里。"],
	["去石丘找圆石与煤", "沿小路往前，石丘在右侧。\n拿着木镐，按住左键开采。\n带黑色斑点的石块会掉落煤炭。"],
	["给自己建一个家", "回到小屋地基附近。\n按住鼠标右键，沿蓝图放置圆石。\n每块消耗 1 圆石，包含墙壁和屋顶。"],
	["一扇门，一束光", "在工作台制作木门，并制作火把。\n回到小屋门前按 E，依次安装。\n有了门和光，夜晚就不再陌生。"],
	["准备好迎接第一夜", "按 E 开门，走进小屋，再关门。\n在屋内按 N，开始夜晚挑战。\n安心留在屋内，等待黎明。"],
	["你的旅程，才刚刚开始", "第一夜已完成，营地进度已保存。\n按 J 翻开探索手记，查看全书路线。\n你可以继续采集、制作和探索营地。"]
]

func setup(progress: ExpeditionProgress) -> void:
	state = progress
	var display_font := FontVariation.new()
	display_font.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	display_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	font = display_font
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := panel(root,Rect2(28,24,275,74),Color(0.07,0.15,0.13,0.87))
	text(top,"方 境",Vector2(18,7),Vector2(120,35),26,CREAM)
	text(top,"EXPLORER’S HANDBOOK",Vector2(19,43),Vector2(245,20),11,MINT)
	var chapter := panel(root,Rect2(536,28,368,52),Color(0.07,0.15,0.13,0.85))
	chapter_label = text(chapter,"01  /  林地营地      ·      初次启程",Vector2(18,12),Vector2(340,28),17,CREAM)
	var clock_panel := panel(root,Rect2(1160,28,252,52),Color(0.07,0.15,0.13,0.85))
	clock_label = text(clock_panel,"☀  安全教学 · 日光正好",Vector2(16,13),Vector2(230,27),16,GOLD)
	quest_card = panel(root,Rect2(28,124,318,228),Color(0.065,0.135,0.12,0.91))
	quest_number = text(quest_card,"探索目标  /  01",Vector2(20,16),Vector2(280,22),12,MINT)
	quest_title = text(quest_card,"",Vector2(20,50),Vector2(278,36),24,CREAM)
	quest_body = text(quest_card,"",Vector2(20,101),Vector2(280,100),16,CREAM)
	text(root,"W A S D  移动     空格  跳跃     Shift  快走",Vector2(30,805),Vector2(510,24),14,CREAM)
	text(root,"Tab  制作 / 背包     J  手记     Esc  暂停",Vector2(30,836),Vector2(510,24),14,CREAM)
	var resource_panel := panel(root,Rect2(1005,783,407,77),Color(0.07,0.15,0.13,0.88))
	text(resource_panel,"随身物资",Vector2(16,9),Vector2(350,20),12,MINT)
	inventory_line = text(resource_panel,"",Vector2(16,36),Vector2(380,26),16,CREAM)
	for i in range(4):
		var slot := panel(root,Rect2(551+i*86,789,78,76),Color(0.07,0.15,0.13,0.9))
		text(slot,str(i+1),Vector2(8,5),Vector2(20,18),11,MINT)
		text(slot,["空手","木镐","石斧","火把"][i],Vector2(8,30),Vector2(63,25),16,CREAM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hotbar.append(slot)
	text(root,"+",Vector2(706,432),Vector2(28,28),23,CREAM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = text(root,"",Vector2(420,654),Vector2(600,62),19,CREAM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = text(root,"",Vector2(400,110),Vector2(640,45),19,GOLD)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gather_bar = ProgressBar.new()
	gather_bar.position = Vector2(645,494)
	gather_bar.size = Vector2(150,5)
	gather_bar.show_percentage = false
	gather_bar.max_value = 1
	gather_bar.add_theme_stylebox_override("background",style(Color(0.05,0.1,0.08,0.5)))
	gather_bar.add_theme_stylebox_override("fill",style(GOLD))
	root.add_child(gather_bar)
	gather_bar.hide()
	refresh()

func style(color: Color, border := Color(0.55,0.69,0.53,0.32)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	return s

func panel(parent: Node, rect: Rect2, color := INK) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",style(color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func text(parent: Node, value: String, pos: Vector2, size: Vector2, font_size := 16, color := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.025,0.02,0.6))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func button(parent: Node, title: String, rect: Rect2, id: String, primary := false) -> Button:
	var b := Button.new()
	b.text = title
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",INK if primary else CREAM)
	b.add_theme_stylebox_override("normal",style(GOLD if primary else Color("30463c")))
	b.add_theme_stylebox_override("hover",style(Color("efd09a") if primary else Color("49624f"),GOLD))
	b.add_theme_stylebox_override("pressed",style(Color("b69c64")))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),GOLD))
	b.pressed.connect(func(): action.emit(id))
	parent.add_child(b)
	return b

func refresh() -> void:
	var step := state.stage()
	quest_number.text = "探索目标  /  %02d" % (step+1)
	quest_title.text = QUESTS[step][0]
	quest_body.text = QUESTS[step][1]
	if step == 5:
		quest_body.text += "\n已放置 %d / 46 块" % state.built.size()
	inventory_line.text = "原木 %d   木板 %d   圆石 %d   煤 %d" % [state.count("log"),state.count("plank"),state.count("stone"),state.count("coal")]

func select_slot(index: int) -> void:
	for i in hotbar.size():
		hotbar[i].add_theme_stylebox_override("panel",style(Color(0.1,0.2,0.16,0.94),GOLD if i==index else Color(0.5,0.6,0.4,0.3)))

func toast(value: String) -> void:
	toast_label.text = value
	toast_time = 4.0
	root.move_child(toast_label, root.get_child_count()-1)
	toast_label.position.y = 805 if current_modal != "" else 110

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	toast_label.modulate.a = minf(1,toast_time)

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	current_modal = ""

func show_modal(kind: String) -> void:
	close_modal()
	current_modal = kind
	modal = panel(root,Rect2(200,105,1040,685),Color(0.055,0.115,0.10,0.98))
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	if kind == "welcome":
		text(modal,"方境  /  探索者手记",Vector2(46,32),Vector2(700,28),16,MINT)
		text(modal,"你的第一趟远行。" if state.has_flag("complete") else "从第一块木头开始。",Vector2(46,91),Vector2(960,76),48,CREAM)
		text(modal,"一座营地，是走向整个世界的起点。",Vector2(49,179),Vector2(900,40),22,GOLD)
		var intro := "你的第一夜已经完成，房屋和背包都保留了。\n这一程：领取补给、制作床、烹饪食物，沿西北小路发现村庄。\n\n与农夫、制图师交易，带着地图平安返回营地。" if state.has_flag("complete") else "跟随手册，采集木头、制作工具，亲手搭起第一间小屋。\n不需要玩过游戏。左侧目标会一步步带你完成。\n\n现在是安全教学时间：只有你准备好，夜晚才会到来。"
		text(modal,intro,Vector2(49,254),Vector2(920,160),20,CREAM)
		text(modal,"鼠标  看四周     W A S D  行走     空格  跳跃\n左键按住  采集     E  互动     Tab  制作     Esc  暂停",Vector2(49,461),Vector2(900,70),17,MUTED)
		button(modal,"继续这段旅程" if state.has_flag("started") else "开始我的第一天  →",Rect2(49,563,316,60),"start",true)
		text(modal,"02 / 08     平原村庄 · 补给、交易与地图" if state.has_flag("complete") else "01 / 08     林地营地 · 第一次启程",Vector2(410,578),Vector2(580,33),15,MINT)
	elif kind == "craft":
		text(modal,"制作与背包",Vector2(28,22),Vector2(600,44),29)
		text(modal,"靠近工作台 · 可以制作全部配方" if near_bench else "随身制作 · 需要工作台的配方请回营地制作",Vector2(30,76),Vector2(930,29),15,GOLD)
		button(modal,"返回  [Tab]",Rect2(835,23,173,43),"close")
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(28,123)
		scroll.size = Vector2(984,490)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		modal.add_child(scroll)
		var contents := Control.new()
		contents.custom_minimum_size = Vector2(980,ceili(float(state.recipes.size())/3.0)*166)
		scroll.add_child(contents)
		for i in state.recipes.size():
			var recipe: Dictionary = state.recipes[i]
			var x := (i%3)*322
			var y := (i/3)*166
			var card := panel(contents,Rect2(x,y,306,151),Color("243a31"))
			text(card,str(recipe.name)+" · 已有 "+str(state.count(recipe.id)),Vector2(14,9),Vector2(282,31),17)
			var costs := ""
			for id in recipe.cost:
				costs += "%s %d/%d  " % [state.items[id].name,state.count(id),int(recipe.cost[id])]
			text(card,costs,Vector2(14,47),Vector2(288,27),13,MINT if state.can_pay(recipe.cost) else GOLD)
			text(card,"需要工作台" if recipe.station else "随身可制作",Vector2(14,82),Vector2(140,22),12,MUTED)
			var available: bool = state.can_pay(recipe.cost) and (near_bench or not recipe.station)
			var b := button(card,"制作" if available else "缺材料 / 工作台",Rect2(133,101,164,35),"craft:"+recipe.id,available)
			b.disabled = not available
		var inv := "背包  "
		for id in state.inventory:
			if state.count(id)>0: inv += "%s ×%d   " % [state.items[id].name,state.count(id)]
		var label := text(modal,inv,Vector2(30,631),Vector2(977,45),14,CREAM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif kind == "journal":
		text(modal,"探索手记",Vector2(30,22),Vector2(700,45),30)
		text(modal,"一本手册，一整个待探索的世界。",Vector2(32,77),Vector2(760,30),17,MINT)
		button(modal,"返回  [J]",Rect2(835,23,173,43),"close")
		for i in state.chapters.size():
			var chapter: Dictionary = state.chapters[i]
			var x := 28+(i%2)*500
			var y := 128+(i/2)*121
			var card := panel(modal,Rect2(x,y,484,105),Color("2c4135") if i==0 else Color("1d3029"))
			text(card,chapter.number,Vector2(16,17),Vector2(45,30),23,GOLD if i==0 else MUTED)
			text(card,chapter.name,Vector2(69,14),Vector2(280,30),21)
			text(card,"已完成" if i==0 and state.has_flag("complete") else ("当前可玩" if i==0 else ("部分开放" if i==1 else "计划中")),Vector2(371,20),Vector2(100,23),13,MINT)
			var subtitle := text(card,chapter.subtitle,Vector2(69,54),Vector2(397,45),13,MUTED)
			subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text(modal,"书中依据：出发准备 / Home Sweet Home。首关采用安全教学与辅助蓝图建造。",Vector2(31,633),Vector2(975,30),14,MINT)
	elif kind == "pause":
		text(modal,"歇一会儿，再出发。",Vector2(49,65),Vector2(920,64),40)
		text(modal,"游戏已暂停，进度已保存。\n\nW A S D 行走 / 鼠标转向 / 空格跳跃 / Shift 快走\n左键按住采集 / 右键按住建屋 / E 互动\n1—4 切换工具 / Tab 制作背包 / J 探索手记\n\n迷路或卡住可以回营地，不会丢失已收集的物品。",Vector2(50,167),Vector2(920,244),20)
		button(modal,"继续游戏",Rect2(49,474,275,55),"close",true)
		button(modal,"回到营地",Rect2(345,474,275,55),"return_camp")
		button(modal,"探索手记",Rect2(641,474,275,55),"journal")
		button(modal,"保存并退出",Rect2(49,559,275,49),"quit")
	elif kind == "complete":
		text(modal,"CHAPTER 01  /  COMPLETE",Vector2(49,56),Vector2(900,30),16,MINT)
		text(modal,"你守住了第一束光。",Vector2(49,122),Vector2(940,73),43)
		text(modal,"第一夜 · 已完成",Vector2(51,225),Vector2(900,43),25,GOLD)
		text(modal,"你已经学会采集、制作工具、采石、建屋和照明。\n营地与背包已保存，这里将成为后续远征的起点。\n\n接下来可以领取补给、学习烹饪和休息，\n开启前往平原村庄的第一次远行。",Vector2(51,294),Vector2(930,188),21)
		button(modal,"继续探索营地",Rect2(49,566,305,60),"close",true)
		button(modal,"翻开全书路线",Rect2(384,566,305,60),"journal")
