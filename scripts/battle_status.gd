extends VBoxContainer

## Presentation only: the battle supplies a snapshot of its actual state.
## Cache the snapshot so unchanged refreshes do not allocate more Controls.
var snapshot: Dictionary = {}
var cooldown: ProgressBar
var cooldown_label: Label
var badges: HFlowContainer

const COLORS := {
	"shield": Color("82cfff"), "guard": Color("a9d8ff"),
	"attack": Color("ffaf89"), "armor": Color("efbc82"),
	"poison": Color("b0e778"), "fire": Color("ffbe66"),
	"rust": Color("e6a77e"), "clock": Color("a2dbe8"),
	"boost": Color("f2d58c"), "dead": Color("c7bec8"),
}

class Symbol extends Control:
	var kind := "shield"
	var ink := Color.WHITE
	func _draw() -> void:
		var p := size * 0.5
		match kind:
			"shield", "guard":
				draw_polyline(PackedVector2Array([p + Vector2(-6,-6), p + Vector2(6,-6),
					p + Vector2(5,2), p + Vector2(0,7), p + Vector2(-5,2), p + Vector2(-6,-6)]), ink, 2)
			"clock":
				draw_arc(p, 6, 0, TAU, 16, ink, 2)
				draw_line(p, p + Vector2(0,-4), ink, 2)
				draw_line(p, p + Vector2(4,1), ink, 2)
			"poison":
				draw_circle(p + Vector2(0,2), 5, ink)
				draw_line(p + Vector2(0,-7), p + Vector2(0,1), ink, 3)
			"fire", "rust":
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7), p+Vector2(6,3),
					p+Vector2(0,7), p+Vector2(-6,3)]), ink)
			_:
				var sign_y := -1.0 if kind == "boost" else 1.0
				draw_line(p + Vector2(0,-6), p + Vector2(0,6), ink, 2)
				draw_polyline(PackedVector2Array([p+Vector2(-5,0), p+Vector2(0,6*sign_y), p+Vector2(5,0)]), ink, 2)


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	custom_minimum_size.x = 136
	cooldown = ProgressBar.new()
	cooldown.custom_minimum_size.y = 24
	cooldown.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("172736")
	cooldown.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("285261")
	cooldown.add_theme_stylebox_override("fill", fill)
	add_child(cooldown)
	cooldown_label = Label.new()
	cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 13)
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown.add_child(cooldown_label)
	badges = HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 3)
	badges.add_theme_constant_override("v_separation", 2)
	add_child(badges)


func show_state(data: Dictionary) -> void:
	if data == snapshot:
		return
	snapshot = data.duplicate(true)
	cooldown_label.text = data.get("cooldown_text", "")
	cooldown.tooltip_text = data.get("cooldown_tip", "")
	cooldown.max_value = maxf(1.0, float(data.get("total", 1)))
	cooldown.value = float(data.get("progress", 0))
	cooldown_label.modulate = COLORS.dead if data.get("dead", false) else Color.WHITE
	for child in badges.get_children():
		badges.remove_child(child)
		child.queue_free()
	for entry in data.get("effects", []):
		var panel := PanelContainer.new()
		var color: Color = COLORS.get(entry.kind, Color.WHITE)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color.r * 0.13, color.g * 0.13, color.b * 0.13, 0.98)
		style.border_color = color.darkened(0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 3
		style.content_margin_right = 4
		panel.add_theme_stylebox_override("panel", style)
		panel.tooltip_text = entry.tip
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		var icon := Symbol.new()
		icon.custom_minimum_size = Vector2(16,20)
		icon.kind = entry.kind
		icon.ink = color
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label := Label.new()
		label.text = entry.text
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		panel.add_child(row)
		badges.add_child(panel)
