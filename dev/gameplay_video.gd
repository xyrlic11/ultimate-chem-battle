extends SceneTree

const Recipes = preload("res://scripts/recipes.gd")
const Expedition = preload("res://scripts/expedition.gd")
var started := false
var state
var mode := "prep"

func _process(_delta: float) -> bool:
	if not started:
		started = true
		run()
	return false

func hold(seconds: float) -> void:
	await create_timer(seconds).timeout

func scene(path: String):
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var node = load(path).instantiate()
	root.add_child(node)
	current_scene = node
	await hold(0.5)
	return node

func run() -> void:
	seed(42)
	state = root.get_node("GameState")
	assert(state.SAVE_PATH == "user://save_headless.cfg")
	state._loading = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="): mode = arg.trim_prefix("--clip=")
	state.gold = 120
	state.wave = 5 if mode == "battle" else 3
	state.slots_bought = 1
	state.tutorial_done = true
	state.battle_tutorial_done = true
	state.pending_reward = {}
	state.roster = {}
	state.board_items = []
	state.unit_condition = {}
	state.run_modifiers = []
	state.run_buffs = []
	state.rewarded_bosses = []
	state.route_plan = {}
	state.journey = Expedition.fresh(state.wave)
	state.shop_offer = ["H", "O", "Na", "Cl", "Fe", "C"]
	for formula in (["Fe2", "NaCl", "H2O", "CH4"] if mode == "battle" else ["Fe2", "NaCl"]):
		var recipe = Recipes.find_by_formula(formula)
		state.roster[formula] = {"thai":recipe.thai,"kind":recipe.kind,"count":1,"traits":Recipes.traits_of_recipe(recipe),"tier":1,"row":"front" if formula in ["Fe2", "NaCl"] else "back"}
		state.board_items.append({"type":"molecule","key":formula,"x":100,"y":100,"tier":1})
	if mode == "prep": await preparation()
	elif mode == "event": await event_clip()
	else: await battle_clip()
	print("VIDEO_COMPLETE ", mode)
	quit()

func preparation() -> void:
	var main = await scene("res://scenes/Main.tscn")
	await hold(2)
	main._toggle_shop()
	await hold(3)
	for symbol in ["H", "H", "O"]:
		main._on_shop_button_pressed(symbol)
		await hold(1.2)
	main._close_shop()
	await hold(1)
	var atoms = get_nodes_in_group("atoms")
	var center: Vector2 = main._board.size * Vector2(0.5, 0.48)
	for i in atoms.size():
		var target: Vector2 = center + Vector2((i - 1) * 125, 0)
		var tween = main.create_tween()
		tween.tween_property(atoms[i], "position", target, 0.7)
		await tween.finished
	await hold(2)
	for i in atoms.size():
		var tween = main.create_tween()
		tween.tween_property(atoms[i], "position", center + Vector2((i - 1) * 25, 0), 0.8)
		await tween.finished
	main._resolve_cluster(main._get_cluster(atoms[0]), atoms[0])
	await hold(5)
	for molecule in get_nodes_in_group("molecules"):
		if molecule.formula == "H2O":
			main._on_molecule_drag_started(molecule)
			var destination: Vector2 = main._back_row.global_position + Vector2(30, 35)
			var tween = main.create_tween()
			tween.tween_property(molecule, "global_position", destination, 1.2)
			await tween.finished
			main._on_molecule_drag_ended(molecule)
	await hold(3)
	main._toggle_shop()
	await hold(1.5)
	main._on_reroll_pressed()
	await hold(2.5)
	main._close_shop()
	await hold(2)

func event_clip() -> void:
	state.journey.offers = ["merchant", "cache", "researcher"]
	var event = await scene("res://scenes/Event.tscn")
	await hold(4)
	assert(Expedition.select(state, "merchant"))
	event._render()
	await hold(4)
	Expedition.enter(state)
	event._render()
	await hold(3)
	event._read_next()
	await hold(4)
	for step in 3:
		if state.journey.phase != "story": break
		var choices: Array = Expedition.choices(state)
		for action in choices:
			if Expedition.available(state, action):
				print("EVENT_CHOICE ", action.id)
				event._choose(action.id)
				break
		await hold(4)
		if state.journey.phase == "story":
			event._read_next()
			await hold(3)
	await hold(3)

func battle_clip() -> void:
	var event = await scene("res://scenes/Event.tscn")
	await hold(3)
	Expedition.resolve(state, "fight")
	var battle = await scene("res://scenes/Battle.tscn")
	for second in 85:
		await hold(1)
		if battle._battle_over:
			await hold(4)
			break
		if second == 18 or second == 34:
			battle._on_speed_pressed()
			await hold(1.5)
			battle._select_combat_rate(4 if second == 18 else 8)
		if second == 45:
			battle._on_burst_pressed()
