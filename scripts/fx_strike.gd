extends Control

## A one-shot streak from one point to another, for Phase C's per-turn attack
## cue (2026-09-01): the attacker chip/monster_art can never visibly move
## toward its target -- every fighter lives inside an HBoxContainer/
## VBoxContainer (FrontRow/BackRow/MonsterSide), and a Container overwrites a
## child's `position` every layout pass, same reason fx.gd rules out screen
## shake entirely. This draws the "who hit whom" line as a transient overlay
## instead, exactly like fx_burst.gd's particles never touch a real node.

const LIFETIME := 0.20

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _color := Color.WHITE
var _age := 0.0


func setup(from_global: Vector2, to_global: Vector2, color: Color) -> void:
	_from = from_global
	_to = to_global
	_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	# Travels most of the way there fast, then the streak itself shrinks and
	# fades -- reads as an impact arriving, not a line just sitting there.
	var reach := clampf(t * 2.2, 0.0, 1.0)
	var head := _from.lerp(_to, reach) - global_position
	var tail := _from.lerp(_to, maxf(0.0, reach - 0.35)) - global_position
	var alpha := 1.0 - t * t
	draw_line(tail, head, Color(_color.r, _color.g, _color.b, alpha), 4.0)
	draw_circle(head, 5.0 * (1.0 - t * 0.5), Color(_color.r, _color.g, _color.b, alpha))
