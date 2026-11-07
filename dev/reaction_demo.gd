extends "res://dev/reaction_check.gd"

# Development-only fixture. Uses actual boss encounters and an isolated save.
func run() -> void:
	seed(42)
	state = root.get_node("GameState")
	state.SAVE_PATH = "user://reaction_demo.cfg"
	var neutral := "--neutralize" in OS.get_cmdline_user_args()
	setup_team(5 if neutral else 15, ["NaOH", "Fe2", "H2O"] if neutral else ["HCl", "Fe2", "H2O"])
	state.shop_offer = ["H", "Cl", "Na", "O", "Fe", "C"]
	for formula in state.roster:
		state.roster[formula].count = 3
		state.board_items.append({"type":"molecule", "key":formula,"tier":1,"x":100,"y":100})
	state.commit_reaction("neutralize" if neutral else "oxide")
	var main = await scene("res://scenes/Main.tscn")
	main._toggle_shop()
	if "--capture" not in OS.get_cmdline_user_args(): return
	await hold(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/reaction-selector.png"))
	var b = await scene("res://scenes/Battle.tscn")
	b._tick_timer.stop()
	if neutral:
		b._apply_boss_skill(b._players[0])
	await hold(0.25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/reaction-battle.png"))
	print("REACTION_DEMO_CAPTURE_COMPLETE")
	quit()
