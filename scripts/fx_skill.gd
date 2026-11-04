extends Control
const Timing := preload("res://scripts/combat_timing.gd")

## Deterministic overlay. No global RNG calls: adding a visual must never
## reroll crits, targets, or gas-trait extra attacks.
var from_global := Vector2.ZERO
var to_global := Vector2.ZERO
var effect := "attack"
var ink := Color.WHITE
var age := 0.0
var duration := 0.55
var speed := 1.0


func setup(start: Vector2, finish: Vector2, kind: String, color: Color, rate: float) -> void:
	from_global = start
	to_global = finish
	effect = kind
	ink = color
	speed = rate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta * speed * Timing.VISUAL_RATE
	if age >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var t := clampf(age / duration, 0.0, 1.0)
	var start := from_global - global_position
	var finish := to_global - global_position
	var travel := minf(1.0, t / 0.4)
	var head := start.lerp(finish, travel)
	var color := Color(ink, 1.0 - t * t)
	if start.distance_to(finish) > 4:
		draw_line(start, finish, Color(ink, 0.55 * (1.0-t*0.5)), 3)
		draw_line(start.lerp(finish, maxf(0,travel-0.25)), head, color, 5)
		draw_rect(Rect2(head-Vector2(4,4), Vector2(8,8)), color)
	var radius := 12.0 + 18.0 * t
	draw_arc(start, 11, 0, TAU, 20, color, 2)
	if travel < 1.0 and start.distance_to(finish) > 4:
		return
	match effect:
		"heal":
			draw_rect(Rect2(finish-Vector2(4,radius), Vector2(8,radius*2)), color)
			draw_rect(Rect2(finish-Vector2(radius,4), Vector2(radius*2,8)), color)
		"shield":
			draw_polyline(PackedVector2Array([finish+Vector2(-radius,-radius), finish+Vector2(radius,-radius),
				finish+Vector2(radius*0.8,radius*0.3), finish+Vector2(0,radius),
				finish+Vector2(-radius*0.8,radius*0.3), finish+Vector2(-radius,-radius)]), color, 4)
		"clock":
			draw_arc(finish, radius, t*TAU, t*TAU+TAU*0.85, 24, color, 4)
			draw_line(finish, finish + Vector2(0,-radius*0.7), color, 3)
		"poison":
			for i in 3:
				draw_circle(finish + Vector2((i-1)*14, -t*20), 6, color)
		_:
			for i in 6:
				var ray := Vector2.from_angle(float(i)*TAU/6.0)
				draw_line(finish + ray*radius*0.4, finish + ray*radius, color, 4)
