extends "res://dev/reaction_check.gd"

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	mouse_button(point, true)
	mouse_button(point, false)
	await process_frame

func mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func mouse_move(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func run() -> void:
	seed(42)
	state = root.get_node("GameState")
	state.SAVE_PATH = "user://ziva_findings_test.cfg"
	setup_team(2, ["Fe2", "H2O"])
	state.tutorial_done = false
	state.discovered.clear()
	state.shop_offer = ["H", "O", "Na", "Cl"]
	var main = await scene("res://scenes/Main.tscn")
	var coach = main.get_node("%Tutorial")
	check(coach._text.text.contains("เดินทาง") and coach._target.text.contains("เดินทาง"), "coach matches travel button")
	await click(main.get_node("%ShopButton"))
	var hydrogen: Button = main._shop_buttons.H
	var gold: int = state.gold
	await click(hydrogen)
	await click(hydrogen)
	var atoms := get_nodes_in_group("atoms")
	check(atoms.size() == 2 and state.gold == gold - 2 * Recipes.cost_of("H"), "buy two H via shop pointer input")
	main._close_shop()
	await process_frame
	# Separate the purchased tiles so the start point is unambiguous.
	atoms[0].position = Vector2(120, 160)
	atoms[1].position = Vector2(290, 160)
	await process_frame
	var start: Vector2 = atoms[0].get_global_rect().get_center()
	var end: Vector2 = atoms[1].get_global_rect().get_center()
	root.warp_mouse(start)
	await process_frame
	mouse_button(start, true)
	root.warp_mouse(start.lerp(end, 0.5))
	await process_frame
	mouse_move(start, start.lerp(end, 0.5))
	check(main._dragging == atoms[0], "viewport drag reaches the actual atom")
	root.warp_mouse(end)
	await process_frame
	mouse_move(start.lerp(end, 0.5), end)
	mouse_button(end, false)
	await hold(2.0)
	check(state.roster.has("H2") and get_nodes_in_group("atoms").is_empty(), "drag and drop crafts H2 and consumes both atoms")
	check(state.fielded_formulas().has("H2"), "new H2 deploys into free team slot")
	await click(main.get_node("%BattleButton"))
	await hold(0.9)
	check(current_scene.name == "Event", "travel opens stage-two routes")
	await click(current_scene._skip_button)
	check(state.wave == 2 and state.journey.phase == "combat" and state.journey.fallback, "actual Skip button queues stage-two normal combat")
	await click(current_scene._card_row.get_child(-1))
	await hold(0.9)
	check(current_scene.name == "Battle" and current_scene.battle_stage == 2, "fight button enters required stage-two battle")
	var b = current_scene
	b._finish(true)
	await process_frame
	check(state.wave == 3 and b.get_node("StageBadge").text == "2/25", "victory shows completed stage while progress advances once")
	b._finish(true)
	check(state.wave == 3 and state.journey_history.size() == 1, "repeated finish cannot advance twice")

	setup_team(2, ["H2"])
	state.journey.offers = ["merchant"]
	check(Expedition.select(state, "merchant") and Expedition.retreat(state) and Expedition.followup(state), "retreat queues normal fight")
	check(state.encounter_enemy().formula == preload("res://scripts/campaign.gd").enemy(2, state.next_monster_kind).formula, "fallback uses normal monster")
	state.journey = Expedition.fresh(2)
	state.journey.offers = ["merchant"]
	check(Expedition.select(state, "merchant") and Expedition.resolve(state, "help") and Expedition.followup(state), "peaceful merchant choice queues normal fight")
	state.journey = {"step": 2, "phase": "result", "choice": "", "outcome": ""}
	state.save_game()
	state.load_game()
	check(Expedition.followup(state) and state.wave == 2, "empty outcome survives reload and queues normal fight")
	state.journey = Expedition.fresh(2)
	state.journey.offers = ["merchant"]
	check(Expedition.select(state, "merchant") and Expedition.resolve(state, "fight"), "event's own fight selected")
	check(not Expedition.followup(state) and not state.journey.fallback and state.encounter_enemy().formula == "Cu2", "event fight replaces normal combat")

	for plan in [{"stage":15, "source":"HCl", "index":1, "id":"oxide"}, {"stage":5, "source":"NaOH", "index":2, "id":"neutralize"}]:
		var demo_path := "res://dev/ReactionOxideDemo.tscn" if plan.id == "oxide" else "res://dev/ReactionNeutralizeDemo.tscn"
		await scene(demo_path)
		main = current_scene
		check(main.name == "Main" and state.wave == plan.stage and state.fielded_formulas().has(plan.source), "scene fixture enters normal preparation")
		check(state.SAVE_PATH == "user://reaction_scene_demo.cfg" and state.reaction_plan == "", "scene fixture uses isolated save and starts with no plan")
		await click(main.get_node("%ShopButton"))
		var ui = main.find_child("ReactionPlan", true, false)
		check(ui.visible and not ui.selector.is_item_disabled(plan.index), "available plan in shop: " + plan.id)
		var other := 3 - int(plan.index)
		check(ui.selector.is_item_disabled(other) and not ui.selector.get_popup().get_item_tooltip(other).is_empty(), "missing source is disabled with reason")
		await click(ui.selector)
		var popup: PopupMenu = ui.selector.get_popup()
		check(popup.visible, "reaction dropdown opens via pointer")
		popup.index_pressed.emit(plan.index)
		popup.hide()
		await process_frame
		check(state.reaction_plan == plan.id, "option menu commits " + plan.id)
		main._close_shop()
		await click(main.get_node("%BattleButton"))
		await hold(0.9)
		check(current_scene.name == "Event", "boss route opens")
		await click(current_scene._card_row.get_child(-1))
		await hold(0.9)
		check(current_scene.name == "Battle", "boss encounter starts")
		b = current_scene
		b._tick_timer.stop()
		# Run combat logic quickly while leaving the UI feedback enabled.
		b._skipping_combat = true
		if plan.id == "oxide":
			check(b._reaction_used and b._monster.armor_break_sources.has("HCl"), "Fe2O3 armor break applied at battle start")
			check(b._log_list.get_children().any(func(line): return line.text.contains("สลายเกราะ")), "oxide feedback appears in battle log")
		else:
			for tick in range(12):
				if b._reaction_used or b._battle_over: break
				await b._on_tick()
			check(b._reaction_used and not b._players.any(func(f): return f.status_kind == "corroded"), "HCl heavy attack triggers actual cleanse")
			check(b._log_list.get_children().any(func(line): return line.text.contains("ล้างกัดกร่อน")), "neutralization feedback appears in battle log")
			# Isolate the second heavy attack from ordinary cleanse skills.
			for fighter in b._players:
				fighter.ability_cd = 100
			b._charging = true
			await b._on_tick()
			check(b._players.any(func(f): return f.status_kind == "corroded"), "next heavy attack retains corrosion")
		b._finish(false)
		await process_frame
		check(b.get_node("StageBadge").text == "%d/25" % plan.stage, "defeat badge stays on fought stage")

	print("ZIVA_FINDINGS_CHECK_COMPLETE: %d checks" % checks)
	quit()
