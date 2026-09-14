extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
	else: print("PASS: ", label)

func _initialize() -> void:
	var state := ExpeditionProgress.new()
	state.save_enabled = false
	check(state.chapters.size()==8,"whole-book chapter registry")
	check(state.stage()==0,"newcomer starts with movement tutorial")
	state.flags.moved = true
	check(state.stage()==1,"movement opens gathering")
	state.gather("test_stone","stone")
	check(state.count("stone")==0 and state.harvested.is_empty(),"stone cannot be harvested without a pickaxe")
	state.craft("wood_pickaxe",true)
	check(state.count("wood_pickaxe")==0,"missing ingredients cannot create tools")
	state.gather("tree_a","log")
	state.gather("tree_a","log")
	check(state.count("log")==3,"resource cannot be harvested twice")
	state.gather("tree_b","log")
	for i in range(6): state.craft("plank",false)
	check(state.count("plank")==24 and state.count("log")==0,"logs convert to four planks")
	state.craft("bench",false)
	check(state.place_bench(),"crafted bench can be installed")
	check(not state.place_bench(),"bench installation cannot repeat")
	state.craft("stick",false)
	state.craft("wood_pickaxe",false)
	check(state.count("wood_pickaxe")==0,"pickaxe requires nearby bench")
	state.craft("wood_pickaxe",true)
	check(state.count("wood_pickaxe")==1,"book recipe creates wooden pickaxe")
	for i in range(12): state.gather("stone_%d"%i,"stone")
	state.gather("coal_a","coal")
	check(state.stage()==5,"stone and coal lead to shelter building")
	for i in range(46): check(state.build_block(i),"blueprint block %d consumes stone"%i)
	var stone_left := state.count("stone")
	check(not state.build_block(0) and state.count("stone")==stone_left,"duplicate blueprint block does not spend inventory")
	state.flags.shelter = true
	state.craft("door",true)
	check(state.count("door")==3,"six planks yield three oak doors")
	check(state.install("door"),"door installed")
	state.craft("torch",false)
	check(state.count("torch")==4,"coal and stick yield four torches")
	check(state.install("torch"),"torch installed")
	state.craft("furnace",true)
	check(state.count("furnace")==1,"eight cobblestones create furnace")
	check(state.stage()==7,"all preparation unlocks first night")
	state.flags.complete = true
	check(state.stage()==8,"completion unlocks journal ending")
	# Use a separate user-data directory (--user-data-dir) when testing disk persistence.
	state.position = [-0.5,2.1,12.0]
	state.look = [0.12,-0.04]
	state.save_path = "/tmp/explorer-test-save.json"
	state.save_enabled = true
	state.save_game()
	var restored := ExpeditionProgress.new()
	restored.save_path = state.save_path
	check(restored.load_game(),"versioned save reloads")
	check(restored.inventory==state.inventory and restored.built==state.built and restored.harvested==state.harvested,"inventory, resource depletion and construction survive reload")
	check(restored.position==state.position and restored.stage()==8,"position and chapter progress survive reload")
	print("RESULT: ", failures, " failures")
	quit(1 if failures else 0)
