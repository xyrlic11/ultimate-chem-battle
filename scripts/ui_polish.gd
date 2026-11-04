extends Node

## Shared presentation for static and dynamically created UI.
## Scale affects rendering only; container spacing stays stable.
func _ready() -> void:
	get_tree().node_added.connect(_queue_style)
	_style_tree(get_tree().root)

func _style_tree(node: Node) -> void:
	_queue_style(node)
	for child in node.get_children():
		_style_tree(child)

func _queue_style(node: Node) -> void:
	if node is Button or node is Label:
		_style.call_deferred(node.get_instance_id())

func _style(instance_id: int) -> void:
	# Status badges can be removed before the deferred style callback runs.
	var node = instance_from_id(instance_id)
	if not is_instance_valid(node) or node.has_meta("ui_polished"):
		return
	node.set_meta("ui_polished", true)
	if node is Button:
		var button := node as Button
		button.pivot_offset = button.size * 0.5
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
		button.mouse_entered.connect(_button_motion.bind(button, true))
		button.mouse_exited.connect(_button_motion.bind(button, false))
		button.focus_entered.connect(_button_motion.bind(button, true))
		button.focus_exited.connect(_button_motion.bind(button, false))
		button.add_theme_font_size_override("font_size", maxi(16, button.get_theme_font_size("font_size")))
	elif node is Label:
		var label := node as Label
		label.add_theme_font_size_override("font_size", maxi(14, label.get_theme_font_size("font_size")))
		if not label.tooltip_text.is_empty():
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.gui_input.connect(_tap_info.bind(label))
			# Compact highlighted keywords advertise hover information.
			if label.text.length() <= 30 and not label.text.contains("\n"):
				highlight(label, label.get_theme_color("font_color"))

func _tap_info(event: InputEvent, label: Label) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var info := AcceptDialog.new()
		info.title = label.text
		info.dialog_text = label.tooltip_text
		info.ok_button_text = "ปิด"
		get_tree().root.add_child(info)
		info.confirmed.connect(info.queue_free)
		info.canceled.connect(info.queue_free)
		info.popup_centered(Vector2i(mini(420, int(get_viewport().get_visible_rect().size.x)-32),180))
		label.accept_event()

func highlight(label: Label, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	# Wrapped/ellipsized labels have a zero text minimum width. Shrinking those
	# would collapse them into one-character columns inside containers.
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", color.lightened(0.08))
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(color, 0.10)
	pill.border_color = Color(color, 0.42)
	pill.border_width_bottom = 2
	pill.corner_radius_top_left = 4
	pill.corner_radius_top_right = 4
	pill.corner_radius_bottom_left = 4
	pill.corner_radius_bottom_right = 4
	pill.content_margin_left = 4
	pill.content_margin_right = 4
	label.add_theme_stylebox_override("normal", pill)

func _button_motion(button: Button, active: bool) -> void:
	if not is_instance_valid(button):
		return
	if DisplayServer.is_touchscreen_available():
		button.scale = Vector2.ONE
		return
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		if old.is_valid():
			old.kill()
	var tween := button.create_tween()
	button.set_meta("hover_tween", tween)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var zoom := 1.035 if active and not button.disabled else 1.0
	tween.tween_property(button, "scale", Vector2.ONE * zoom, 0.14)
