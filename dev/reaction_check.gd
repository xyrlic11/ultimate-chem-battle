extends "res://dev/gameplay_video.gd"

const Plans := preload("res://scripts/reaction_plan.gd")
const Flow := preload("res://scripts/run_flow.gd")
const Traits := preload("res://scripts/traits.gd")
var checks := 0

func check(value: bool, label: String) -> void:
	if not value:
		push_error("FAIL: " + label)
		quit(1)
		assert(value, label)
	checks += 1
	print("PASS: " + label)

func setup_team(stage: int, formulas: Array) -> void:
	state._loading = true
	state.clear_run_rewards()
	state.wave = stage
	state.gold = 200
	state.roster = {}
	state.board_items = []
	state.tutorial_done = true
	state.battle_tutorial_done = true
	state.reaction_unlocked = true
	for formula in formulas:
		var recipe: Dictionary = Recipes.find_by_formula(formula).duplicate(true)
		recipe.traits = Recipes.traits_of_recipe(recipe)
		state.add_to_roster(recipe)
	state.journey = Expedition.fresh(stage)
	state._loading = false

func battle():
	var node = load("res://scenes/Battle.tscn").instantiate()
	node.silent = true
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	root.add_child(node)
	current_scene = node
	node._tick_timer.stop()
	return node

func run() -> void:
	seed(42)
	state = root.get_node("GameState")
	state.SAVE_PATH = "user://reaction_regression.cfg"
	await scene("res://scenes/Home.tscn")
	check(current_scene.name == "Home", "game boots")
	current_scene._on_new_pressed()
	await hold(0.9)
	check(current_scene.name == "Battle", "new run goes directly to battle")
	current_scene._tick_timer.stop()
	check(not state.reaction_unlocked and current_scene._reaction_id == "", "opening battle locked")
	current_scene._finish(true)
	check(state.reaction_unlocked, "first victory unlocks planning")
	setup_team(15, ["HCl", "H2O"])
	check(state.commit_reaction("oxide"), "commit active HCl")
	var before: Dictionary = state.roster.duplicate(true)
	var b = await battle()
	check(b._enemy_formula == "Fe2O3" and b._reaction_used, "exact oxide pair triggers at start")
	check(is_equal_approx(b._source_total(b._monster.armor_break_sources, 0.45), 0.15), "armor vulnerability 15 percent")
	check(not b._try_reaction(), "oxide cannot trigger twice")
	b._set_timed_source(b._monster.armor_break_sources, "HCl", 0.15, 2)
	check(b._monster.armor_break_sources.size() == 1, "HCl skill does not double stack reaction")
	seed(77)
	var enhanced: float = b._attack(b._players[0], b._monster, false, true)
	b._monster.armor_break_sources.clear()
	seed(77)
	var baseline: float = b._attack(b._players[0], b._monster, false, true)
	check(absf(enhanced / baseline - 1.15) < 0.02, "actual attack damage increases")
	b._set_timed_source(b._monster.armor_break_sources, "HCl", 0.15, 2)
	b._tick_unit_effects()
	check(b._monster.armor_break_sources.has("HCl"), "armor lasts first round")
	b._turn = 1
	b._tick_unit_effects()
	check(b._monster.armor_break_sources.has("HCl"), "armor lasts second round")
	b._turn = 2
	b._tick_unit_effects()
	check(not b._monster.armor_break_sources.has("HCl"), "armor expires after second round")
	check(state.roster == before, "reaction consumes no roster or crafting inventory")
	state.set_row("HCl", "bench")
	b = await battle()
	check(not b._reaction_used and b._monster.armor_break_sources.is_empty(), "stale roster plan safely ignored")
	check(not state.commit_reaction("oxide"), "bench source cannot commit")
	check(state.commit_reaction(""), "none can commit")
	b = await battle()
	check(b._reaction_id == "", "no plan leaves battle unchanged")
	setup_team(5, ["NaOH", "H2O"])
	check(state.commit_reaction("neutralize"), "commit active NaOH")
	b = await battle()
	check(not b._reaction_used, "neutralization waits for corrosion")
	var target = b._players[0]
	target.dot_sources["test"] = {"value": 1.0, "turns": 2}
	b._apply_boss_skill(target)
	check(b._reaction_used and target.status_kind == "" and target.status_value == 0.0, "HCl corrosion actually cleansed")
	check(target.dot_sources.has("test"), "unrelated poison retained")
	b._apply_boss_skill(target)
	check(target.status_kind == "corroded", "second corrosion remains")
	b = await battle()
	for f in b._players:
		if f.formula == "NaOH": f.hp = 0
	b._apply_boss_skill(b._players[1])
	check(not b._reaction_used, "defeated source cannot neutralize")
	state.wave = 25
	state.journey = Expedition.fresh(25)
	b = await battle()
	check(b._reaction_id == "", "other acid H2SO3 does not match HCl")
	setup_team(2, ["NaOH", "H2O"])
	state.commit_reaction("neutralize")
	state.save_game()
	state.reaction_plan = ""
	state.reaction_unlocked = false
	state.load_game()
	check(state.reaction_plan == "neutralize" and state.reaction_unlocked, "new save round trip")
	var cfg := ConfigFile.new()
	cfg.load(state.SAVE_PATH)
	cfg.erase_section_key("progress", "reaction_plan")
	cfg.erase_section_key("progress", "reaction_unlocked")
	cfg.save(state.SAVE_PATH)
	state.load_game()
	check(state.reaction_plan == "" and state.reaction_unlocked, "old save defaults at later stage")
	check(Plans.sanitize({"bad": 1}) == "" and not state.commit_reaction("unknown"), "invalid plan rejected")
	var gold: int = state.gold
	check(state.roll_shop(true) and state.gold < gold and state.shop_offer.size() > 0, "paid shop reroll")
	check(Recipes.find_recipe(["H", "H", "O"]).formula == "H2O", "water crafting recipe")
	state.add_to_roster(Recipes.find_by_formula("H2O"))
	check(state.roster.H2O.count == 2, "compound stacking")
	state.add_to_roster(Recipes.find_by_formula("KOH"))
	check(not Traits.active_tiers(state.fielded_roster(), {}).is_empty(), "active synergy calculation")
	check(Recipes.beats("acid", "metal") and Recipes.beats("base", "acid"), "old counters preserved")
	var main = await scene("res://scenes/Main.tscn")
	main._toggle_shop()
	var ui = main.find_child("ReactionPlan", true, false)
	check(ui.visible and ui.selector.item_count == 3, "one selector with none and two plans")
	ui.selector.item_selected.emit(2)
	check(state.reaction_plan == "neutralize", "selector commits real state")
	main._on_battle_button_pressed()
	await hold(0.9)
	check(current_scene.name == "Event", "regular preparation goes to event")
	# Use actual event definitions rather than inventing a fixture branch.
	var found := false
	for id in Expedition.ENCOUNTERS:
		var actions: Array = Expedition.ENCOUNTERS[id].choices.duplicate()
		for stage in Expedition.ENCOUNTERS[id].get("stages", {}).values(): actions.append_array(stage)
		for action in actions:
			if action.has("combat"):
				state.journey = {"step":2,"phase":"combat","selected":id,"choice":action.id}
				found = true
				break
		if found: break
	check(found, "real combat event fixture found")
	current_scene._launch_battle()
	await hold(0.9)
	check(current_scene.name == "Battle", "event fight launches directly")
	current_scene._tick_timer.stop()
	check(state.reaction_plan == "neutralize", "event retains committed plan")
	state.journey = {"step":2,"phase":"result","choice":"help"}
	check(Expedition.followup(state) and state.journey.phase == "combat", "peaceful outcome queues one fallback fight")
	state.journey = {"step":2,"phase":"routes"}
	check(Flow.skip(state) and Expedition.followup(state), "skip queues required normal fight")
	check(state.wave == 2 and state.journey.fallback, "skip stays at the same stage")
	check(not Expedition.followup(state), "fallback cannot be queued twice")
	state.save_game()
	state.load_game()
	check(state.wave == 2 and state.journey.phase == "combat" and state.journey.choice == "skip", "skip fallback survives save and load")
	setup_team(2, ["Fe2", "H2O"])
	b = await battle()
	for tick in range(200):
		if b._battle_over: break
		await b._on_tick()
	check(b._battle_over, "normal auto combat resolves to result without a plan")
	state.clear_run_rewards()
	check(not state.reaction_unlocked and state.reaction_plan == "", "run reset clears reaction")
	print("REACTION_CHECK_COMPLETE: %d checks" % checks)
	quit()


