extends "res://dev/reaction_check.gd"

var failures := 0

func check(value: bool, label: String) -> void:
	if value:
		checks += 1
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	state = root.get_node("GameState")
	state.SAVE_PATH = "user://shop_persistence_check.cfg"
	setup_team(2, ["Fe2", "H2O"])
	state.gold = 227
	state.shop_offer = ["Ca", "Cu", "H", "O", "Na", "Cl"]
	state.save_game()
	var original: Array = state.shop_offer.duplicate()
	seed(42)
	check(state.roll_shop(true), "paid reroll succeeds")
	var paid: Array = state.shop_offer.duplicate()
	check(paid != original and state.gold == 225, "offers changed and gold deducted once")
	state.load_game()
	check(state.gold == 225 and state.shop_offer == paid, "immediate reload restores both paid offers and gold")

	state.shop_price_mult = 1.2
	check(state.roll_shop(), "free reroll succeeds")
	var free: Array = state.shop_offer.duplicate()
	check(state.shop_price_mult == 1.0, "free reroll resets shop multiplier")
	state.load_game()
	check(state.gold == 225 and state.shop_offer == free, "free offers persist with no deduction")

	state.gold = 1
	state.save_game()
	check(not state.roll_shop(true), "unaffordable reroll is rejected")
	check(state.gold == 1 and state.shop_offer == free, "unaffordable reroll changes neither gold nor offers")
	state.load_game()
	check(state.gold == 1 and state.shop_offer == free, "unaffordable reroll leaves saved data unchanged")
	print("SHOP_PERSISTENCE_CHECK_COMPLETE: %d passed, %d failed" % [checks, failures])
	quit(1 if failures else 0)
