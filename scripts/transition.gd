extends CanvasLayer

## Autoload `Transition`. Fades to black between scenes instead of hard-cutting.
##
## `change_scene_to_file()` swaps the whole tree in a single frame, which reads
## as a glitch rather than as moving somewhere. Every scene change in the game
## goes through here.
##
## Lives on a very high CanvasLayer so it covers whatever the current scene has
## drawn, including other CanvasLayers the game might add later.

const FADE_LAYER := 128

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = FADE_LAYER
	# The pause menu can trigger a scene change while the tree is paused, and a
	# pausable fade tween would simply never advance.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.04, 0.04, 0.06, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Ignored while transparent so it never eats a click during normal play;
	# flipped to STOP for the duration of a fade so the player cannot
	# double-trigger a scene change mid-transition.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func change_scene(path: String, fade_out := 0.28, fade_in := 0.28) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, fade_out)
	await tween.finished

	get_tree().change_scene_to_file(path)
	# One frame for the new scene to instantiate before it becomes visible,
	# otherwise the fade-in reveals a half-built layout.
	await get_tree().process_frame

	var tween_in := create_tween()
	tween_in.tween_property(_rect, "color:a", 0.0, fade_in)
	await tween_in.finished

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Fade to black and stay there -- used on quit so the window does not vanish
## mid-frame.
func fade_out_and_quit(duration := 0.35) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished
	get_tree().quit()
