extends Control
const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")
const Abilities := preload("res://scripts/unit_abilities.gd")
var trait_id := "acid"
func setup(id: String) -> void:
	trait_id = id
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 160
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.04, 0.9)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	set_meta("dismiss_panel", panel)
	var bounds := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(820, bounds.x - 64), minf(580, bounds.y - 48))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "สาย%s · สมาชิกทั้งหมด" % Traits.label_of(trait_id)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Traits.color_of(trait_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "ปิด ×"
	header.add_child(close)
	close.pressed.connect(queue_free)
	for tier in Traits.TRAITS[trait_id].tiers:
		var label := Label.new()
		label.text = "%d ชนิด · %s" % [tier.count, tier.text]
		label.add_theme_font_size_override("font_size", 18)
		box.add_child(label)
	var note := Label.new()
	note.text = "นับชนิดที่ลงสนาม · ตัวซ้ำไม่นับเพิ่ม · ชี้ตัวเพื่อดูสกิล"
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = minf(340, maxf(100, bounds.y - 280))
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if bounds.x < 1100 else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var seen := {}
	for table in [Recipes.RECIPES, Recipes.TIER2_RECIPES]:
		for key in table:
			var recipe: Dictionary = table[key]
			if seen.has(recipe.formula) or not Recipes.traits_of_recipe(recipe).has(trait_id):
				continue
			seen[recipe.formula] = true
			var owned := GameState.roster.has(recipe.formula)
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(180, 142)
			cell.tooltip_text = "%s · %s\n%s" % [recipe.formula, recipe.thai, Abilities.tooltip(recipe.formula)]
			var style := StyleBoxFlat.new()
			style.bg_color = Color("26312d") if owned else Color("211d2d")
			style.border_color = Color("82e3b0") if owned else Color("544b64")
			style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			cell.add_theme_stylebox_override("panel", style)
			grid.add_child(cell)
			var content := VBoxContainer.new()
			cell.add_child(content)
			content.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var art = preload("res://scripts/compound_art.gd").new()
			content.add_child(art)
			art.custom_minimum_size = Vector2(64, 64)
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			art.setup(recipe.formula, int(recipe.get("tier", 1)))
			art.modulate = Color.WHITE if owned else Color(0.6, 0.6, 0.6, 0.65)
			for text in [recipe.formula, "มีแล้ว" if owned else "ยังไม่มี"]:
				var label := Label.new()
				label.text = text
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.add_theme_color_override("font_color", Color("82e3b0") if owned else Color("a9a0b6"))
				if text == recipe.formula: label.add_theme_color_override("font_color", Traits.name_color(recipe.formula))
				content.add_child(label)
