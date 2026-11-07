extends "res://dev/gameplay_video.gd"

func run() -> void:
	state = root.get_node("GameState")
	assert(state.SAVE_PATH == "user://save_headless.cfg")
	state._loading = true
	state.gold = 120
	state.wave = 3
	state.slots_bought = 1
	state.tutorial_done = true
	state.battle_tutorial_done = true
	state.pending_reward = {}
	state.run_buffs = []
	state.run_modifiers = []
	state.unit_condition = {}
	state.roster = {}
	state.board_items = []
	state.journey = Expedition.fresh(3)
	state.shop_offer = ["H", "O", "Na", "Cl", "Fe", "C"]
	for formula in ["Fe2", "NaOH", "KCl", "CH4"]:
		var recipe = Recipes.find_by_formula(formula)
		state.roster[formula] = {"thai":recipe.thai,"kind":recipe.kind,"count":1,"traits":Recipes.traits_of_recipe(recipe),"tier":1,"row":"front" if formula == "Fe2" else "back"}
		state.board_items.append({"type":"molecule","key":formula,"x":100,"y":100,"tier":1})
	var main = await scene("res://scenes/Main.tscn")
	for tile in get_nodes_in_group("molecules"):
		if tile.formula == "KCl": main._planning.show_unit(tile)
	print("PROFILE_PLAYGROUND_READY: isolated test state, no APK export")
