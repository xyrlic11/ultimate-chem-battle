extends Node


const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")
const Campaign := preload("res://scripts/campaign.gd")
const Rewards := preload("res://scripts/boss_rewards.gd")
const Expedition := preload("res://scripts/expedition.gd")
const ReactionPlan := preload("res://scripts/reaction_plan.gd")
var reaction_plan := ""
var reaction_unlocked := false
var unit_condition: Dictionary = {}
var recovered_steps: Array = []
var event_flags: Dictionary = {}
var route_plan: Dictionary = {}
var run_modifiers: Array = []
var journey: Dictionary = {}
var journey_history: Array = []
var run_buffs: Array = []
var pending_reward: Dictionary = {}
var rewarded_bosses: Array = []

static var SAVE_PATH: String = _pick_save_path()


static func _pick_save_path() -> String:
	# Select the isolated file before load_game can migrate a player save.
	for arg in OS.get_cmdline_args():
		if arg.replace("\\", "/").get_file() in ["ReactionOxideDemo.tscn", "ReactionNeutralizeDemo.tscn"]:
			return "user://reaction_scene_demo.cfg"
	if DisplayServer.get_name() == "headless":
		return "user://save_headless.cfg"
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			return "user://save_headless.cfg"
	return "user://save.cfg"
const SAVE_VERSION := 3
const MIN_SUPPORTED_SAVE := 1

const FINAL_WAVE := Campaign.FINAL_WAVE

const FIELD_SLOTS_BASE := 3
const FIELD_SLOTS_MAX := 7
const FIELD_SLOT_BASE_COST := 45
const FIELD_SLOT_COST_STEP := 55

const STARTING_GOLD := 120


signal gold_changed(amount)
signal roster_changed
signal progress_reset

var gold: int = STARTING_GOLD
var roster: Dictionary = {}

var board_items: Array = []

var discovered: Array = []
var pinned_recipe: String = ""


func pin_recipe(key: String) -> void:
	if key != "" and not Recipes.RECIPES.has(key) and not Recipes.TIER2_RECIPES.has(key):
		return
	pinned_recipe = key
	save_game()

var slots_bought: int = 0

signal shop_offer_changed


const SHOP_SLOTS := 6
const REROLL_COST := 2

const INTEREST_PER := 10
const MAX_INTEREST := 5

var shop_offer: Array = []

var shop_price_mult: float = 1.0

var runs_won: int = 0

var tutorial_done: bool = false

var battle_tutorial_done: bool = false

var next_monster_kind: String = "neutral"

var wave: int = 1:
	set(value):
		wave = maxi(1, value)
		save_game()

var _loading := false


func _ready() -> void:
	load_game()
	if shop_offer.is_empty():
		shop_offer = _opening_offer()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_game()


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	save_game()
	return true


func lose_gold(amount: int) -> int:
	var lost: int = clampi(amount, 0, gold)
	gold -= lost
	gold_changed.emit(gold)
	save_game()
	return lost


func add_to_roster(entry: Dictionary) -> void:
	var formula: String = entry.formula
	var tier: int = maxi(1, int(entry.get("tier", 1)))
	if roster.has(formula):
		roster[formula].count += 1
		roster[formula]["tier"] = maxi(int(roster[formula].get("tier", 1)), tier)
	else:
		unit_condition[formula] = 1.0
		roster[formula] = {
			"thai": entry.thai,
			"kind": entry.kind,
			"count": 1,
			"tier": tier,
			"traits": entry.get("traits", []),
			"bonus_traits": [],
			"row": Traits.ROW_FRONT if fielded_formulas().size() < field_limit() else Traits.ROW_BENCH,
		}
	roster_changed.emit()
	save_game()


func set_row(formula: String, row: String) -> bool:
	if not roster.has(formula):
		return false
	if row != Traits.ROW_FRONT and row != Traits.ROW_BACK and row != Traits.ROW_BENCH:
		return false
	var current: String = roster[formula].get("row", Traits.ROW_FRONT)
	if current == row:
		return true

	if current == Traits.ROW_BENCH and row != Traits.ROW_BENCH:
		if fielded_formulas().size() >= field_limit():
			return false

	roster[formula].row = row
	roster_changed.emit()
	save_game()
	return true


func formulas_in_row(row: String) -> Array:
	var out: Array = []
	for formula in roster.keys():
		if roster[formula].get("row", Traits.ROW_FRONT) == row:
			out.append(formula)
	out.sort()
	return out


func interest_earned() -> int:
	return mini(int(gold / INTEREST_PER), MAX_INTEREST)


func roll_shop(charge := false) -> bool:
	if charge and gold < REROLL_COST:
		return false
	shop_offer = _random_offer()
	if charge:
		# spend_gold saves immediately, so the new offers must already be set.
		spend_gold(REROLL_COST)
	else:
		shop_price_mult = 1.0
		save_game()
	shop_offer_changed.emit()
	return true


func _opening_offer() -> Array:
	var seeded: Array = ["H", "O", "Na", "Cl"]
	var rest: Array = []
	for symbol in Recipes.ELEMENTS.keys():
		if not seeded.has(symbol):
			rest.append(symbol)
	rest.shuffle()

	var out: Array = seeded.duplicate()
	var spare: int = mini(SHOP_SLOTS - out.size(), rest.size())
	for i in spare:
		out.append(rest[i])
	out.shuffle()
	return out


func _random_offer() -> Array:
	var pool: Array = Recipes.ELEMENTS.keys()
	var weights: Dictionary = {}
	for symbol in pool:
		weights[symbol] = 20.0 / float(maxi(1, Recipes.cost_of(symbol)))

	var picked: Array = []
	var remaining: Array = pool.duplicate()
	var slots: int = mini(SHOP_SLOTS, remaining.size())

	for _i in slots:
		var total := 0.0
		for symbol in remaining:
			total += weights[symbol]
		var roll := randf() * total
		var chosen: String = remaining[0]
		for symbol in remaining:
			roll -= weights[symbol]
			if roll <= 0.0:
				chosen = symbol
				break
		picked.append(chosen)
		remaining.erase(chosen)

	picked.sort()
	return picked


func set_tutorial_done() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	save_game()


func set_battle_tutorial_done() -> void:
	if battle_tutorial_done:
		return
	battle_tutorial_done = true
	save_game()


func mark_discovered(recipe_key: String) -> void:
	if discovered.has(recipe_key):
		return
	discovered.append(recipe_key)
	save_game()


func set_board_items(items: Array) -> void:
	board_items = _sanitize_board_items(items)
	save_game()


func clear_roster() -> void:
	roster.clear()
	roster_changed.emit()
	save_game()


func reset_progress() -> void:
	_loading = true
	gold = STARTING_GOLD
	wave = 1
	roster.clear()
	clear_run_rewards()
	board_items.clear()
	discovered.clear()
	pinned_recipe = ""
	slots_bought = 0
	shop_offer = _opening_offer()
	tutorial_done = false
	battle_tutorial_done = false
	runs_won = 0
	next_monster_kind = "neutral"
	shop_price_mult = 1.0
	_loading = false

	save_game()
	gold_changed.emit(gold)
	roster_changed.emit()
	progress_reset.emit()


func complete_run() -> void:
	clear_run_rewards()
	pinned_recipe = ""
	runs_won += 1
	_loading = true
	gold = STARTING_GOLD
	wave = 1
	roster.clear()
	board_items.clear()
	slots_bought = 0
	shop_offer = _random_offer()
	next_monster_kind = "neutral"
	shop_price_mult = 1.0
	_loading = false

	save_game()
	gold_changed.emit(gold)
	roster_changed.emit()
	progress_reset.emit()


func end_run_in_defeat() -> void:
	clear_run_rewards()
	pinned_recipe = ""
	_loading = true
	gold = STARTING_GOLD
	wave = 1
	roster.clear()
	board_items.clear()
	slots_bought = 0
	shop_offer = _random_offer()
	next_monster_kind = "neutral"
	shop_price_mult = 1.0
	_loading = false

	save_game()
	gold_changed.emit(gold)
	roster_changed.emit()
	progress_reset.emit()


func save_game() -> void:
	if _loading:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("progress", "gold", gold)
	cfg.set_value("progress", "wave", wave)
	cfg.set_value("progress", "roster", roster)
	cfg.set_value("progress", "discovered", discovered)
	cfg.set_value("progress", "pinned_recipe", pinned_recipe)
	cfg.set_value("progress", "board_items", board_items)
	cfg.set_value("progress", "runs_won", runs_won)
	cfg.set_value("progress", "slots_bought", slots_bought)
	cfg.set_value("progress", "shop_offer", shop_offer)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "battle_tutorial_done", battle_tutorial_done)
	cfg.set_value("progress", "reaction_plan", reaction_plan)
	cfg.set_value("progress", "reaction_unlocked", reaction_unlocked)
	cfg.set_value("progress", "next_monster", next_monster_kind)
	cfg.set_value("progress", "run_buffs", run_buffs)
	cfg.set_value("progress", "pending_reward", pending_reward)
	cfg.set_value("progress", "rewarded_bosses", rewarded_bosses)
	cfg.set_value("progress", "unit_condition", unit_condition)
	cfg.set_value("progress", "recovered_steps", recovered_steps)
	cfg.set_value("progress", "event_flags", event_flags)
	cfg.set_value("progress", "route_plan", route_plan)
	cfg.set_value("progress", "run_modifiers", run_modifiers)
	cfg.set_value("progress", "campaign_version", Campaign.VERSION)
	cfg.set_value("progress", "journey", journey)
	cfg.set_value("progress", "journey_history", journey_history)

	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("GameState: could not write %s (error %d)" % [SAVE_PATH, err])


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # No save yet (or unreadable) -- start fresh, silently.

	var version := int(cfg.get_value("meta", "version", 0))
	if version < MIN_SUPPORTED_SAVE or version > SAVE_VERSION:
		push_warning("GameState: unsupported save version %d, starting fresh." % version)
		return

	_loading = true
	gold = maxi(0, int(cfg.get_value("progress", "gold", STARTING_GOLD)))
	var campaign_version := int(cfg.get_value("progress", "campaign_version", 1))
	wave = Campaign.migrate_stage(int(cfg.get_value("progress", "wave", 1)), campaign_version)
	reaction_plan = ReactionPlan.sanitize(cfg.get_value("progress", "reaction_plan", ""))
	reaction_unlocked = bool(cfg.get_value("progress", "reaction_unlocked", wave > 1))
	route_plan = {}
	var saved_plan = cfg.get_value("progress", "route_plan", {})
	if campaign_version >= Campaign.VERSION and saved_plan is Dictionary:
		for key in saved_plan:
			if str(key).is_valid_int() and int(key) in range(1, FINAL_WAVE + 1) and saved_plan[key] is Dictionary:
				var offers = saved_plan[key].get("offers", [])
				if offers is Array and offers.size() == 3 and offers.all(func(id): return Expedition.ENCOUNTERS.has(id)):
					route_plan[str(key)] = {"offers": offers.duplicate()}
	run_modifiers = preload("res://scripts/run_risk.gd").sanitize(cfg.get_value("progress", "run_modifiers", []))
	var saved_journey = cfg.get_value("progress", "journey", {})
	if campaign_version < Campaign.VERSION and saved_journey is Dictionary and saved_journey.has("step"):
		saved_journey.step = Campaign.migrate_stage(int(saved_journey.step), campaign_version)
	journey = Expedition.sanitize(saved_journey, wave)
	journey_history = []
	var stored_history = cfg.get_value("progress", "journey_history", [])
	if stored_history is Array:
		for item in stored_history.slice(-FINAL_WAVE):
			if item is Dictionary and int(item.get("step", 0)) in range(1, FINAL_WAVE + 1):
				var migrated: Dictionary = item.duplicate(true)
				migrated.step = Campaign.migrate_stage(int(item.step), campaign_version)
				journey_history.append(migrated)
	run_buffs = []
	var stored_buffs = cfg.get_value("progress", "run_buffs", [])
	if stored_buffs is Array:
		for id in stored_buffs:
			if Rewards.CARDS.has(id):
				run_buffs.append(id)
	rewarded_bosses = []
	var stored_bosses = cfg.get_value("progress", "rewarded_bosses", [])
	if stored_bosses is Array:
		for boss_wave in stored_bosses:
			if typeof(boss_wave) == TYPE_INT:
				var migrated_boss := Campaign.migrate_stage(boss_wave, campaign_version)
				if Campaign.is_boss(migrated_boss) and not rewarded_bosses.has(migrated_boss):
					rewarded_bosses.append(migrated_boss)
	pending_reward = {}
	var stored_reward = cfg.get_value("progress", "pending_reward", {})
	if campaign_version < Campaign.VERSION and stored_reward is Dictionary and stored_reward.has("wave"):
		stored_reward.wave = Campaign.migrate_stage(int(stored_reward.wave), campaign_version)
	if stored_reward is Dictionary and stored_reward.get("offers", null) is Array and stored_reward.get("offers", []).size() == 3:
		var valid := Campaign.is_boss(int(stored_reward.get("wave", 0))) and Rewards.CARDS.has(stored_reward.get("automatic", ""))
		for id in stored_reward.offers:
			valid = valid and Rewards.CARDS.has(id)
		if valid:
			pending_reward = stored_reward.duplicate(true)
	roster = _sanitize_roster(cfg.get_value("progress", "roster", {}))
	unit_condition = {}
	var saved_condition = cfg.get_value("progress", "unit_condition", {})
	if saved_condition is Dictionary:
		for formula in roster:
			unit_condition[formula] = clampf(float(saved_condition.get(formula, 1.0)), 0, 1)
	recovered_steps = []
	var saved_recovery = cfg.get_value("progress", "recovered_steps", [])
	if saved_recovery is Array:
		for step in saved_recovery:
			if step is int and step in range(1, FINAL_WAVE + 1) and not recovered_steps.has(step):
				recovered_steps.append(step)
	event_flags = {}
	var saved_flags = cfg.get_value("progress", "event_flags", {})
	if saved_flags is Dictionary:
		for key in saved_flags:
			if key is String and typeof(saved_flags[key]) in [TYPE_BOOL, TYPE_INT, TYPE_STRING]:
				event_flags[key] = saved_flags[key]
	discovered = _sanitize_discovered(cfg.get_value("progress", "discovered", []))
	pinned_recipe = str(cfg.get_value("progress", "pinned_recipe", ""))
	if not Recipes.RECIPES.has(pinned_recipe) and not Recipes.TIER2_RECIPES.has(pinned_recipe):
		pinned_recipe = ""
	board_items = _sanitize_board_items(cfg.get_value("progress", "board_items", []))
	runs_won = maxi(0, int(cfg.get_value("progress", "runs_won", 0)))
	slots_bought = maxi(0, int(cfg.get_value("progress", "slots_bought", 0)))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	battle_tutorial_done = bool(cfg.get_value("progress", "battle_tutorial_done", false))
	next_monster_kind = str(cfg.get_value("progress", "next_monster", "neutral"))
	if not Recipes.KIND_STATS.has(next_monster_kind):
		next_monster_kind = "neutral"
	if Campaign.is_boss(wave):
		next_monster_kind = Campaign.BOSSES[wave].kind

	shop_offer = []
	var raw_offer = cfg.get_value("progress", "shop_offer", [])
	if raw_offer is Array:
		for s in raw_offer:
			if typeof(s) == TYPE_STRING and Recipes.ELEMENTS.has(s) and not shop_offer.has(s):
				shop_offer.append(s)
	if shop_offer.size() < SHOP_SLOTS:
		shop_offer = _random_offer()
	_loading = false

	gold_changed.emit(gold)
	roster_changed.emit()

	if version < SAVE_VERSION or campaign_version < Campaign.VERSION:
		save_game()  # Write the migrated shape back out once.


func _sanitize_board_items(raw) -> Array:
	var clean: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return clean

	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var type := str(entry.get("type", ""))
		var key := str(entry.get("key", ""))
		if type == "atom":
			if not Recipes.ELEMENTS.has(key):
				continue
		elif type == "molecule":
			if Recipes.find_by_formula(key) == null:
				continue
		else:
			continue

		clean.append({
			"type": type,
			"key": key,
			"tier": clampi(int(entry.get("tier", 1)), 1, 2),
			"x": maxf(0.0, float(entry.get("x", 0.0))),
			"y": maxf(0.0, float(entry.get("y", 0.0))),
		})
	return clean
func _sanitize_discovered(raw) -> Array:
	var clean: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return clean
	for key in raw:
		if typeof(key) != TYPE_STRING or clean.has(key):
			continue
		if Recipes.RECIPES.has(key) or Recipes.TIER2_RECIPES.has(key):
			clean.append(key)
	return clean


func _sanitize_roster(raw) -> Dictionary:
	var clean := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return clean

	for formula in raw.keys():
		var entry = raw[formula]
		if typeof(formula) != TYPE_STRING or typeof(entry) != TYPE_DICTIONARY:
			continue

		var kind := str(entry.get("kind", ""))
		if not Recipes.KIND_STATS.has(kind):
			continue  # Kind was renamed or removed since this save was written.

		var recipe = Recipes.find_by_formula(formula)
		var derived: Array = (
			Recipes.traits_of_recipe(recipe) if recipe != null
			else Recipes.traits_of(kind, [])
		)

		var row := str(entry.get("row", Traits.ROW_FRONT))
		if row != Traits.ROW_FRONT and row != Traits.ROW_BACK and row != Traits.ROW_BENCH:
			row = Traits.ROW_FRONT

		var bonus: Array = []
		var raw_bonus = entry.get("bonus_traits", [])
		if raw_bonus is Array:
			for t in raw_bonus:
				if typeof(t) == TYPE_STRING and Traits.TRAITS.has(t) \
						and not derived.has(t) and not bonus.has(t):
					bonus.append(t)

		clean[formula] = {
			"thai": str(entry.get("thai", formula)),
			"kind": kind,
			"count": maxi(1, int(entry.get("count", 1))),
			"tier": clampi(int(entry.get("tier", 1)), 1, 2),
			"traits": derived + bonus,
			"bonus_traits": bonus,
			"row": row,
		}

	return clean


func roll_next_monster() -> void:
	if Campaign.is_boss(wave):
		next_monster_kind = Campaign.BOSSES[wave].kind
	elif wave <= 1:
		next_monster_kind = "neutral"
	else:
		var kinds := ["acid", "base", "metal"]
		next_monster_kind = kinds[randi() % kinds.size()]
	save_game()


func consume_from_roster(formula: String) -> void:
	if not roster.has(formula):
		return
	var left: int = int(roster[formula].get("count", 1)) - 1
	if left > 0:
		roster[formula]["count"] = left
	else:
		roster.erase(formula)
		unit_condition.erase(formula)
	roster_changed.emit()
	save_game()


func sell_compound(formula: String) -> int:
	if not roster.has(formula):
		return 0
	var refund := Recipes.sell_value(formula)
	var entry: Dictionary = roster[formula]
	if int(entry.get("count", 1)) > 1:
		entry["count"] = int(entry["count"]) - 1
	else:
		roster.erase(formula)
		unit_condition.erase(formula)
	gold += refund
	gold_changed.emit(gold)
	roster_changed.emit()
	save_game()
	return refund


func is_final_wave() -> bool:
	return wave >= FINAL_WAVE

func is_boss_wave() -> bool:
	return Campaign.is_boss(wave)

func clear_run_rewards() -> void:
	reaction_plan = ""
	reaction_unlocked = false
	unit_condition.clear()
	recovered_steps.clear()
	event_flags.clear()
	route_plan.clear()
	run_modifiers.clear()
	journey.clear()
	journey_history.clear()
	run_buffs.clear()
	pending_reward.clear()
	rewarded_bosses.clear()

func grant_boss_reward(boss_wave: int) -> void:
	if not Campaign.is_boss(boss_wave) or rewarded_bosses.has(boss_wave) or not pending_reward.is_empty():
		return
	pending_reward = Rewards.roll(boss_wave)
	run_buffs.append(pending_reward.automatic)
	rewarded_bosses.append(boss_wave)
	save_game()

func choose_boss_reward(id: String) -> bool:
	if pending_reward.is_empty() or not pending_reward.offers.has(id):
		return false
	run_buffs.append(id)
	pending_reward.clear()
	save_game()
	return true

func trait_bonus() -> Dictionary:
	return Rewards.trait_bonus(run_buffs)

func encounter_enemy() -> Dictionary:
	if int(journey.get("step", 0)) == wave:
		return Expedition.enemy(self)
	return Campaign.enemy(wave, next_monster_kind)


func field_limit() -> int:
	return mini(FIELD_SLOTS_BASE + slots_bought, FIELD_SLOTS_MAX)


func slot_price() -> int:
	if field_limit() >= FIELD_SLOTS_MAX:
		return 0
	return FIELD_SLOT_BASE_COST + FIELD_SLOT_COST_STEP * slots_bought


func buy_field_slot() -> bool:
	if field_limit() >= FIELD_SLOTS_MAX:
		return false
	if not spend_gold(slot_price()):
		return false
	slots_bought += 1
	roster_changed.emit()
	save_game()
	return true


func fielded_formulas() -> Array:
	var out: Array = []
	for formula in roster.keys():
		if roster[formula].get("row", Traits.ROW_FRONT) != Traits.ROW_BENCH:
			out.append(formula)
	out.sort()
	return out


func commit_reaction(id: String) -> bool:
	if id != "" and (not reaction_unlocked or not ReactionPlan.PLANS.has(id)):
		return false
	if not ReactionPlan.available(id, fielded_formulas()):
		return false
	reaction_plan = id
	save_game()
	return true


func fielded_roster() -> Dictionary:
	var out: Dictionary = {}
	for formula in fielded_formulas():
		out[formula] = roster[formula]
	return out
