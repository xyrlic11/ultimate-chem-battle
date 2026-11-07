extends Node

const Recipes := preload("res://scripts/recipes.gd")
const Expedition := preload("res://scripts/expedition.gd")
const DEMO_SAVE := "user://reaction_scene_demo.cfg"

@export var neutralize := false

func _ready() -> void:
	_start_demo.call_deferred()

func _start_demo() -> void:
	GameState.SAVE_PATH = DEMO_SAVE
	GameState.reset_progress()
	GameState._loading = true
	GameState.wave = 5 if neutralize else 15
	GameState.gold = 200
	GameState.tutorial_done = true
	GameState.battle_tutorial_done = true
	GameState.reaction_unlocked = true
	GameState.journey = Expedition.fresh(GameState.wave)
	GameState.shop_offer = ["H", "Cl", "Na", "O", "Fe", "C"]
	for formula in ["NaOH" if neutralize else "HCl", "Fe2", "H2O"]:
		var recipe: Dictionary = Recipes.find_by_formula(formula).duplicate(true)
		recipe.traits = Recipes.traits_of_recipe(recipe)
		GameState.add_to_roster(recipe)
		GameState.roster[formula].count = 3
		GameState.board_items.append({"type": "molecule", "key": formula, "tier": 1, "x": 100, "y": 100})
	GameState._loading = false
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
