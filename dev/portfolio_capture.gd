extends SceneTree
var started := false
func _process(_d: float) -> bool:
 if not started:
  started = true
  run()
 return false
func shot(name: String) -> void:
 await create_timer(0.35).timeout
 await RenderingServer.frame_post_draw
 var path := ProjectSettings.globalize_path("res://../KMITL-Game-Overview/assets/" + name)
 root.get_texture().get_image().save_png(path)
func run() -> void:
 var state = root.get_node("GameState")
 if state.SAVE_PATH != "user://save_headless.cfg":
  quit(1)
  return
 state._loading = true
 state.gold = 120
 state.wave = 5
 state.slots_bought = 1
 state.tutorial_done = true
 state.battle_tutorial_done = true
 state.pending_reward = {}
 state.roster = {}
 var recipes = load("res://scripts/recipes.gd")
 for formula in ["Fe2","NaCl","H2O","CH4"]:
  var recipe = recipes.find_by_formula(formula)
  state.roster[formula] = {"thai":recipe.thai,"kind":recipe.kind,"count":1,"traits":recipes.traits_of_recipe(recipe),"tier":1,"row":"front" if formula in ["Fe2","NaCl"] else "back"}
 state.board_items = [{"type":"atom","key":"H","x":200,"y":210},{"type":"atom","key":"H","x":360,"y":210},{"type":"atom","key":"O","x":540,"y":210}]
 for formula in state.roster:
  state.board_items.append({"type":"molecule","key":formula,"x":100,"y":100,"tier":1})
 state.shop_offer = ["H","O","Na","Cl","Fe","C"]
 var main = load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await shot("preparation.png")
 main._toggle_shop()
 await shot("shop.png")
 main.queue_free()
 await process_frame
 var battle = load("res://scenes/Battle.tscn").instantiate()
 root.add_child(battle)
 current_scene = battle
 await process_frame
 battle._tick_timer.stop()
 await shot("battle.png")
 print("Portfolio screenshots captured using isolated test state")
 quit()

