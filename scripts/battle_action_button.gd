extends Button
## Keep action explanations readable, including while energy is insufficient.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 310
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	margin.add_child(label)
	return panel
