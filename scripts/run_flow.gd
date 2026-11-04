extends RefCounted
const Recipes := preload("res://scripts/recipes.gd")
# Prototype recovery values, isolated from baseline combat balance.
const PASSIVE_RECOVERY := 0.08
const PAID_RECOVERY := 0.25
const HEAL_COST := 20
static func begin(state) -> void:
	var metrics = Engine.get_main_loop().root.get_node_or_null("Playtest")
	if metrics: metrics.begin()
	state._loading = true
	for formula in ["Fe2", "H2O"]:
		var recipe: Dictionary = Recipes.find_by_formula(formula).duplicate(true)
		recipe.traits = Recipes.traits_of_recipe(recipe)
		state.add_to_roster(recipe)
		state.roster[formula].row = "front" if formula == "Fe2" else "back"
		state.board_items.append({"type":"molecule","key":formula,"tier":1,"x":70,"y":180})
	state.journey = {"step":1,"phase":"combat","selected":"opening","choice":"fight","offers":[],"stage":"","outcome":""}
	state._loading = false
	state.save_game()
static func condition(state, formula: String) -> float:
	return clampf(float(state.unit_condition.get(formula, 1.0)), 0, 1)
static func record(state, fighters: Array) -> void:
	for fighter in fighters:
		if state.roster.has(fighter.formula):
			state.unit_condition[fighter.formula] = clampf(fighter.hp / maxf(1.0, fighter.max_hp), 0, 1)
static func heal(state, amount: float) -> void:
	for formula in state.roster:
		state.unit_condition[formula] = minf(1.0, condition(state, formula) + amount)
static func hurt(state, amount: float) -> void:
	for formula in state.fielded_roster():
		state.unit_condition[formula] = maxf(0.0, condition(state, formula) - amount)
static func recover(state, step: int) -> bool:
	if state.recovered_steps.has(step):
		return false
	state.recovered_steps.append(step)
	heal(state, PASSIVE_RECOVERY)
	return true
static func needs_heal(state) -> bool:
	for formula in state.roster:
		if condition(state, formula) < 0.999:
			return true
	return false
static func buy_heal(state) -> bool:
	if not needs_heal(state) or state.gold < HEAL_COST:
		return false
	state._loading = true
	state.lose_gold(HEAL_COST)
	heal(state, PAID_RECOVERY)
	state._loading = false
	state.roster_changed.emit()
	state.save_game()
	return true
static func skip(state) -> bool:
	if state.journey.get("phase", "") != "routes" or state.is_boss_wave():
		return false
	state.journey.phase = "result"
	var metrics = Engine.get_main_loop().root.get_node_or_null("Playtest")
	if metrics: metrics.skipped()
	state.journey.choice = "skip"
	state.journey.selected = ""
	state.journey.outcome = "คุณผ่านโอกาสนี้และกลับค่าย"
	return true
