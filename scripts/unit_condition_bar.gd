extends Control
var formula := ""
var _ratio := -1.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var ratio := preload("res://scripts/run_flow.gd").condition(state, formula)
	if not is_equal_approx(ratio, _ratio):
		_ratio = ratio
		visible = ratio < 0.999
		queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("291c2d"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * maxf(0, _ratio), size.y)), Color("e79a78") if _ratio < 0.3 else Color("83cfa4"))
