extends Label

## A damage/heal number that drifts up and fades, then deletes itself.
## Spawned by Fx.float_text(); not meant to be placed in a scene.

const RISE := 46.0
const LIFETIME := 0.85


func setup(global_pos: Vector2, text_value: String, color: Color, font_size: int) -> void:
	text = text_value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	# An outline keeps the number legible over a fighter chip, a HP bar or the
	# battle log, all of which it can pass across on the way up.
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("outline_size", 5)

	# Size has to be resolved before it can be centred on the target.
	reset_size()
	global_position = global_pos - size * 0.5
	# Small horizontal scatter so simultaneous hits do not stack into one
	# unreadable clump.
	var drift := randf_range(-14.0, 14.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position",
		global_position + Vector2(drift, -RISE), LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
