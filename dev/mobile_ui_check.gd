extends "res://dev/gameplay_video.gd"

func shot(label: String) -> void:
	await hold(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/mobile-ui/" + label + ".png"))

func run() -> void:
	state = root.get_node("GameState")
	assert(state.SAVE_PATH == "user://save_headless.cfg")
	state._loading = true
	state.wave = 3
	state.gold = 120
	state.pending_reward = {}
	state.tutorial_done = true
	state.battle_tutorial_done = true
	state.journey = Expedition.fresh(3)
	state.journey.offers = ["merchant", "cache", "researcher"]
	state.roster = {}
	state.board_items = []
	state.shop_offer = ["H", "O", "Na", "Cl", "Fe", "C"]
	for formula in ["Fe2", "H2O"]:
		var recipe = Recipes.find_by_formula(formula)
		state.roster[formula] = {"thai":recipe.thai,"kind":recipe.kind,"count":1,"traits":Recipes.traits_of_recipe(recipe),"tier":1,"row":"front" if formula == "Fe2" else "back"}
		state.board_items.append({"type":"molecule","key":formula,"x":100,"y":100,"tier":1})
	var main = await scene("res://scenes/Main.tscn")
	await shot("main")
	var icons = load("res://scripts/profile_icons.gd")
	for key in icons.SPRITES:
		assert(icons.SPRITES[key].size() == 16)
		for line in icons.SPRITES[key]: assert(line.length() == 16)
	for tile in get_nodes_in_group("molecules"):
		main._planning.show_unit(tile)
		await shot("profile-" + tile.formula)
		assert(main._planning.skill_icon.texture.get_size() == Vector2(16, 16))
		assert(not main._planning.detail_body.text.contains("ตำแหน่ง"))
		assert(not main._planning.detail_body.text.contains("สภาพปัจจุบัน"))
		main._planning.close_details()
	main._toggle_shop()
	await shot("shop")
	main._close_shop()
	var adaptive = root.get_node("UiAdaptive")
	main._toggle_book()
	await shot("recipes")
	assert(not adaptive._dismiss_outside(main._recipe_book.get_node("Box").get_global_rect().get_center()))
	assert(main._recipe_book.visible)
	assert(adaptive._dismiss_outside(Vector2(2, 200)))
	assert(not main._recipe_book.visible)
	main._toggle_shop()
	assert(adaptive._dismiss_outside(Vector2(2, 200)))
	assert(not main._shop_popup.visible)
	assert(not quit_on_go_back)
	assert(main.get_meta("mobile_nav").get_child_count() == 5)
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await hold(0.4)
	var settings = main.get_node("%SettingsPanel")
	assert(settings.visible and paused)
	settings._ui_slider.value = 125
	settings._ui_slider.drag_ended.emit(true)
	await shot("scale-125")
	assert(is_equal_approx(adaptive.ui_scale, 1.25))
	var config := ConfigFile.new()
	assert(config.load(adaptive._scale_path) == OK)
	assert(is_equal_approx(float(config.get_value("display", "ui_scale")), 1.25))
	settings._ui_slider.value = 80
	settings._ui_slider.drag_ended.emit(true)
	await shot("scale-80")
	adaptive.set_ui_scale(1.0)
	settings.close()
	await hold(0.3)
	assert(not paused)
	root.get_node("UiAdaptive")._nav(main, "Team")
	await shot("team")
	var event = await scene("res://scenes/Event.tscn")
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await hold(0.4)
	assert(event.get_node("SettingsPanel").visible and paused)
	adaptive._back_time = -1000
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await hold(0.4)
	assert(not paused)
	await shot("routes")
	Expedition.select(state,"merchant")
	Expedition.enter(state)
	event._read_next()
	await shot("event")
	await scene("res://scenes/Battle.tscn")
	await shot("battle")
	var home = await scene("res://scenes/Home.tscn")
	adaptive._back_time = -1000
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await shot("exit-confirm")
	var dialog = home.get_node("ExitConfirmation")
	dialog.find_child("Cancel", true, false).pressed.emit()
	await process_frame
	assert(home.get_node_or_null("ExitConfirmation") == null)
	adaptive._back_time = -1000
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	adaptive._back_time = -1000
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	assert(home.get_node_or_null("ExitConfirmation") == null)
	adaptive._back_time = -1000
	adaptive.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	print("MOBILE_UI_CHECK_COMPLETE")
	home.get_node("ExitConfirmation").find_child("Confirm", true, false).pressed.emit()
