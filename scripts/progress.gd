class_name ExpeditionProgress
extends RefCounted

signal changed
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
var journey: Dictionary = {"hunger":20.0,"time":0.0,"explored":[],"crops":{},"job":{},"fuel":0,"spawn":[]}
var save_enabled := true
var notice := ""

func _init() -> void:
	items = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	recipes = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	chapters = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	trades = JSON.parse_string(FileAccess.get_file_as_string("res://data/trades.json"))

func count(id: String) -> int:
	return int(inventory.get(id, 0))

func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))

func add(id: String, amount: int) -> void:
	inventory[id] = count(id) + amount
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
	if kind in ["stone", "coal"] and count("wood_pickaxe") == 0:
		return "石头需要用镐开采。先在工作台制作一把木镐。"
	harvested.append(id)
	var amount := 3 if kind == "log" else (6 if kind == "stone" else 2)
	add(kind, amount)
	flags["gathered_" + kind] = true
	save_game()
	return "+%d %s" % [amount, items[kind].name]

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
	if count("wood_pickaxe") == 0: return 3
	if not has_flag("gathered_stone") or not has_flag("gathered_coal"): return 4
	if not has_flag("shelter"): return 5
	if not has_flag("door") or not has_flag("torch"): return 6
	return 7

func save_game() -> void:
	if not save_enabled:
		return
	var data := {"version": 2, "chapter": "temperate" if has_flag("complete") else "camp", "inventory": inventory, "flags": flags,
		"harvested": harvested, "built": built, "position": position, "look": look, "journey":journey}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t", true, true))
		file.close()
		DirAccess.rename_absolute(save_path + ".tmp", save_path)

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) not in [1,2]:
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
	if save_enabled and int(data.version)==1 and not FileAccess.file_exists(save_path+".pre-v2"):
		DirAccess.copy_absolute(save_path,save_path+".pre-v2")
	return true

func begin_smelting(output: String) -> String:
	if not journey.job.is_empty(): return "熔炉正在工作，等这一份完成后再放入。"
	var ingredient := "raw_beef" if output=="cooked_beef" else "log"
	if output not in ["cooked_beef","charcoal"]: return "未知的熔炼配方。"
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
	if float(journey.hunger)>=20: return "现在很饱，留到路上再吃吧。"
	pay({id:1})
	journey.hunger=minf(20,float(journey.hunger)+int(points[id]))
	flags.ate=true
	save_game()
	return "吃下%s，饥饿值恢复到 %d / 20。" % [items[id].name,int(journey.hunger)]

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
	journey={"hunger":20.0,"time":0.0,"explored":[],"crops":{},"job":{},"fuel":0,"spawn":[]}
	save_game()
