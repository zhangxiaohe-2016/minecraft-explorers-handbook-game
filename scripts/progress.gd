class_name ExpeditionProgress
extends RefCounted

signal changed
const TOOL_IDS: Array[String] = ["wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "stone_axe", "wood_sword"]
const MAX_DURABILITY := {
	"wood_pickaxe": 59,
	"stone_pickaxe": 131,
	"iron_pickaxe": 250,
	"stone_axe": 132,
	"wood_sword": 60
}
const PICKAXES: Array[String] = ["iron_pickaxe", "stone_pickaxe", "wood_pickaxe"]
var save_path := "user://expedition_v1.json"
var items: Dictionary = {}
var recipes: Array = []
var chapters: Array = []
var trades: Dictionary = {}
var inventory: Dictionary = {}
var flags: Dictionary = {}
var harvested: Array = []
var built: Array = []
var position: Array = []
var look: Array = []
var journey: Dictionary = {"hunger":20.0,"time":0.0,"explored":[],"crops":{},"job":{},"fuel":0,"spawn":[],"health":10,"waypoints":[]}
var tool_durability: Dictionary = {}
var save_enabled := true
var notice := ""

func _init() -> void:
	items = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	recipes = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	chapters = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	trades = JSON.parse_string(FileAccess.get_file_as_string("res://data/trades.json"))

func is_tool(id: String) -> bool:
	return id in TOOL_IDS

func best_pickaxe() -> String:
	for id in PICKAXES:
		if count(id) > 0:
			return id
	return ""

func pickaxe_tier(id: String) -> int:
	return PICKAXES.find(id)

func can_mine(kind: String, held: String) -> bool:
	if kind in ["stone", "coal"]:
		return held in ["wood_pickaxe", "stone_pickaxe", "iron_pickaxe"]
	if kind == "iron":
		return held in ["stone_pickaxe", "iron_pickaxe"]
	return true

func count(id: String) -> int:
	return int(inventory.get(id, 0))

func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))

func sync_tools() -> void:
	for id in TOOL_IDS:
		if not tool_durability.get(id) is Array:
			tool_durability[id] = []
		var list: Array = tool_durability[id]
		var n := count(id)
		while list.size() > n:
			list.pop_back()
		while list.size() < n:
			list.append(MAX_DURABILITY[id])

func held_durability(id: String) -> int:
	if not is_tool(id) or count(id) <= 0:
		return -1
	sync_tools()
	var list: Array = tool_durability[id]
	if list.is_empty():
		return -1
	return clampi(int(list[0]), 0, int(MAX_DURABILITY[id]))

func wear_tool(id: String, amount := 1) -> Dictionary:
	if not is_tool(id) or amount <= 0 or count(id) <= 0:
		return {"ok": false}
	sync_tools()
	var list: Array = tool_durability[id]
	if list.is_empty():
		return {"ok": false}
	var max_d := int(MAX_DURABILITY[id])
	var left := maxi(0, int(list[0]) - amount)
	list[0] = left
	var broken := left <= 0
	if broken:
		list.pop_front()
		inventory[id] = count(id) - 1
		if inventory[id] <= 0:
			inventory.erase(id)
	changed.emit()
	save_game()
	return {
		"ok": true,
		"broken": broken,
		"remaining": left,
		"backups": count(id),
		"low": (not broken) and left * 5 <= max_d,
		"critical": (not broken) and left * 10 <= max_d,
		"max": max_d
	}

func add(id: String, amount: int) -> void:
	inventory[id] = count(id) + amount
	if is_tool(id):
		sync_tools()
	changed.emit()

func can_pay(cost: Dictionary) -> bool:
	for id in cost:
		if count(id) < int(cost[id]):
			return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for id in cost:
		inventory[id] = count(id) - int(cost[id])
		if is_tool(id):
			sync_tools()
	changed.emit()
	return true

func craft(id: String, near_bench: bool) -> String:
	for recipe in recipes:
		if recipe.id != id:
			continue
		if recipe.station and not near_bench:
			return "请走近营地工作台，再制作这件工具。"
		if not can_pay(recipe.cost):
			return "材料还不够。配方下面会显示你缺少的数量。"
		pay(recipe.cost)
		for output in recipe.output:
			add(output, int(recipe.output[output]))
		flags["crafted_" + id] = true
		save_game()
		return "已制作  " + str(recipe.name)
	return "没有找到这个配方。"

func gather(id: String, kind: String) -> String:
	if id in harvested:
		return "这里已经采集过了。"
	if kind in ["stone", "coal"] and best_pickaxe() == "":
		return "石头需要用镐开采。先在工作台制作一把木镐。"
	if kind == "iron" and count("stone_pickaxe") + count("iron_pickaxe") == 0:
		return "铁矿需要石镐或更好的镐。先用圆石制作石镐。"
	harvested.append(id)
	var amount := 3 if kind == "log" else (1 if kind == "iron" else (6 if kind == "stone" else 2))
	add("raw_iron" if kind == "iron" else kind, amount)
	flags["gathered_" + kind] = true
	save_game()
	return "+%d %s" % [amount, items["raw_iron" if kind == "iron" else kind].name]

func place_bench() -> bool:
	if has_flag("bench") or not pay({"bench": 1}):
		return false
	flags.bench = true
	save_game()
	return true

func build_block(index: int) -> bool:
	if index in built or not pay({"stone": 1}):
		return false
	built.append(index)
	save_game()
	return true

func install(id: String) -> bool:
	if has_flag(id) or not pay({id: 1}):
		return false
	flags[id] = true
	save_game()
	return true

func stage() -> int:
	if has_flag("complete"): return 8
	if not has_flag("moved"): return 0
	if not has_flag("gathered_log"): return 1
	if not has_flag("bench"): return 2
	if best_pickaxe() == "": return 3
	if not has_flag("gathered_stone") or not has_flag("gathered_coal"): return 4
	if not has_flag("shelter"): return 5
	if not has_flag("door") or not has_flag("torch"): return 6
	return 7

func save_game() -> void:
	if not save_enabled:
		return
	sync_tools()
	var data := {"version": 3, "chapter": "temperate" if has_flag("complete") else "camp", "inventory": inventory, "flags": flags,
		"harvested": harvested, "built": built, "position": position, "look": look, "journey":journey, "tool_durability": tool_durability}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t", true, true))
		file.close()
		DirAccess.rename_absolute(save_path + ".tmp", save_path)

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) not in [1,2,3]:
		return false
	for key in ["inventory", "flags"]:
		if not data.get(key) is Dictionary: return false
	for key in ["harvested", "built", "position", "look"]:
		if not data.get(key) is Array: return false
	inventory = {}
	for id in data.inventory:
		if items.has(id): inventory[id] = maxi(0, int(data.inventory[id]))
	flags = data.flags
	harvested = data.harvested
	built = data.built.map(func(v): return int(v))
	position = data.position
	look = data.look
	if data.get("journey") is Dictionary:
		journey.merge(data.journey,true)
	if not journey.get("waypoints") is Array:
		journey.waypoints=[]
	tool_durability = {}
	if data.get("tool_durability") is Dictionary:
		for id in TOOL_IDS:
			tool_durability[id] = []
			if data.tool_durability.get(id) is Array:
				for value in data.tool_durability[id]:
					tool_durability[id].append(clampi(int(value), 0, int(MAX_DURABILITY[id])))
	sync_tools()
	if save_enabled and int(data.version) < 2 and not FileAccess.file_exists(save_path+".pre-v2"):
		DirAccess.copy_absolute(save_path,save_path+".pre-v2")
	if save_enabled and int(data.version) < 3 and not FileAccess.file_exists(save_path+".pre-v3"):
		DirAccess.copy_absolute(save_path,save_path+".pre-v3")
	return true

func begin_smelting(output: String) -> String:
	if not journey.job.is_empty(): return "熔炉正在工作，等这一份完成后再放入。"
	var recipes := {"cooked_beef":"raw_beef", "charcoal":"log", "iron_ingot":"raw_iron"}
	if not recipes.has(output): return "未知的熔炼配方。"
	var ingredient: String = recipes[output]
	if count(ingredient)<1: return "缺少"+str(items[ingredient].name)+"。"
	var fuel_id := ""
	if int(journey.fuel)<=0:
		for id in ["coal","charcoal","plank"]:
			if count(id)>0:
				fuel_id=id
				break
		if fuel_id=="": return "需要燃料：煤、木炭或木板。先把原木制成木板也可以。"
		pay({fuel_id:1})
		journey.fuel=8 if fuel_id in ["coal","charcoal"] else 1
	pay({ingredient:1})
	journey.fuel=int(journey.fuel)-1
	journey.job={"output":output,"remaining":6.0,"duration":6.0}
	save_game()
	return "熔炉已经点火，6 秒后可取出成品。"

func tick_smelting(delta: float) -> bool:
	if journey.job.is_empty(): return false
	journey.job.remaining=float(journey.job.remaining)-delta
	if float(journey.job.remaining)>0: return false
	var output: String=journey.job.output
	journey.job={}
	add(output,1)
	flags["cooked_"+output]=true
	save_game()
	return true

func eat(id: String) -> String:
	var points: Dictionary={"raw_beef":3,"cooked_beef":8,"bread":5}
	if not points.has(id) or count(id)<1: return "背包里没有这份食物。"
	if float(journey.hunger)>=20 and int(journey.health)>=10: return "现在很饱，留到路上再吃吧。"
	pay({id:1})
	journey.hunger=minf(20,float(journey.hunger)+int(points[id]))
	journey.health=mini(10,int(journey.health)+2)
	flags.ate=true
	save_game()
	return "吃下%s，饥饿 %d / 20，生命 %d / 10。" % [items[id].name,int(journey.hunger),int(journey.health)]

func trade(id: String) -> String:
	var offers := trades
	if not offers.has(id): return "这位村民没有这个交易。"
	if id=="map" and count("map")>0: return "已经有一张地图了，按 M 查看。"
	var offer: Dictionary=offers[id]
	if not pay(offer.cost): return "物品不足。可以先到村里的农田收集小麦。"
	for item in offer.output: add(item,int(offer.output[item]))
	flags["traded_"+id]=true
	save_game()
	return "交易完成。"+("按 M 打开地图，走过的地方会被记录。" if id=="map" else "")

func reset() -> void:
	inventory.clear()
	flags.clear()
	harvested.clear()
	built.clear()
	position.clear()
	look.clear()
	journey={"hunger":20.0,"time":0.0,"explored":[],"crops":{},"job":{},"fuel":0,"spawn":[],"health":10,"waypoints":[]}
	tool_durability={}
	sync_tools()
	save_game()
