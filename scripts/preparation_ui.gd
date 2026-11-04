extends Control

## Preparation-only presentation. Inventory/recipes stay in GameState/Recipes;
## this controller never creates fighters, spends money or moves board tiles.
const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")
const Abilities := preload("res://scripts/unit_abilities.gd")
const Plan := preload("res://scripts/preparation_plan.gd")

var host
var pin_text: Label
var shop_plan: Label
var details: Control
var detail_title: Label
var detail_body: Label
var portrait: Label
var unit_art: Control
var drop_panel: PanelContainer
var drop_text: Label
var selected_formula := ""
var book_wired := false
var surfaces: Array = []
var enemy_art: Control
var plan_expanded := false


func setup(main) -> void:
	host = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side = host.get_node("Margins/Root/SidePanel")
	enemy_art = Control.new()
	enemy_art.set_script(preload("res://scripts/monster_art.gd"))
	enemy_art.custom_minimum_size = Vector2(100, 100)
	side.add_child(enemy_art)
	side.move_child(enemy_art, 0)
	host.get_node("Margins/Root/SidePanel/SynergyHint").hide()
	for source in [side, host.get_node("Margins/Root/TeamPanel")]:
		var surface := Panel.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(surface)
		host.move_child(surface, host.get_node("Margins").get_index())
		surfaces.append([source, surface])
	host.get_node("Margins/Root/SidePanel/BattleSpacer").hide()
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(panel)
	side.move_child(panel, side.get_child_count() - 2)
	var col := VBoxContainer.new()
	panel.add_child(col)
	col.add_theme_constant_override("separation", 8)
	var actions := HBoxContainer.new()
	col.add_child(actions)
	_button(actions, "📖 สูตร", "เปิดคู่มือเพื่อเลือกสูตรที่ต้องการวางแผน", host._toggle_book)
	_button(actions, "รายละเอียด", "เปิดหรือย่อขั้นตอนการผสม", func():
		plan_expanded = not plan_expanded
		refresh())
	_button(actions, "×", "ยกเลิกสูตรที่ปักหมุด", func(): pin(""))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 95
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	pin_text = _label(scroll, "", 16)
	shop_plan = _label(host.get_node("ShopPopup/Box/Col"), "", 13)
	shop_plan.max_lines_visible = 3
	shop_plan.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host.get_node("ShopPopup/Box/Col").move_child(shop_plan, 3)
	_make_details()
	drop_panel = PanelContainer.new()
	add_child(drop_panel)
	drop_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	drop_panel.offset_left = 20
	drop_panel.offset_right = -20
	drop_panel.offset_top = -115
	drop_panel.offset_bottom = -12
	drop_panel.z_index = 150
	drop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_text = _label(drop_panel, "", 14)
	drop_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_panel.hide()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _make_details() -> void:
	details = Control.new()
	add_child(details)
	details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details.z_index = 200
	var dim := ColorRect.new()
	details.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.04, 0.72)
	dim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_details())
	var panel := PanelContainer.new()
	details.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -275
	panel.offset_bottom = 275
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var heading := HBoxContainer.new()
	col.add_child(heading)
	detail_title = _label(heading, "", 22)
	_button(heading, "Close", "ปิดรายละเอียดและกลับไปจัดทีม", close_details)
	unit_art = preload("res://scripts/compound_art.gd").new()
	unit_art.custom_minimum_size = Vector2(0, 105)
	col.add_child(unit_art)
	portrait = _label(col, "", 40)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.custom_minimum_size.y = 70
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	detail_body = _label(scroll, "", 17)
	_button(col, "Plan", "ปักหมุดสูตรของตัวนี้และแสดงธาตุที่ยังขาด", _plan_selected)
	_button(col, "ขายสารนี้", "ขายผ่านหน้าต่างยืนยัน", _sell_selected)
	details.hide()

func _sell_selected() -> void:
	if selected_formula != "":
		for tile in get_tree().get_nodes_in_group("molecules"):
			if tile.formula == selected_formula:
				host._on_molecule_sell_requested(tile)
				break
		close_details()

func show_unit(tile: Control) -> void:
	selected_formula = tile.formula
	host._close_book()
	host._close_shop()
	details.show()
	_refresh_details()
	UiAdaptive.refresh_scene.call_deferred(host)


func close_details() -> bool:
	if details == null or not details.visible:
		return false
	details.hide()
	return true


func _refresh_details() -> void:
	var recipe = Recipes.find_by_formula(selected_formula)
	var entry: Dictionary = GameState.roster.get(selected_formula, {})
	if recipe == null or entry.is_empty():
		close_details()
		return
	var row: String = entry.get("row", "bench")
	var stats := Abilities.combat_stats(selected_formula, entry, row,
		Traits.active_tiers(GameState.fielded_roster(), GameState.trait_bonus()))
	var rewards = preload("res://scripts/boss_rewards.gd")
	stats.hp *= (1.0 + rewards.bonus(GameState.run_buffs, "hp")) * (1.0 + preload("res://scripts/run_risk.gd").value(GameState, "team_hp", row))
	stats.atk *= 1.0 + rewards.bonus(GameState.run_buffs, "atk")
	detail_title.text = "%s · %s" % [selected_formula, recipe.thai]
	portrait.text = "%s  ×%d" % [selected_formula, int(entry.get("count", 1))]
	portrait.add_theme_color_override("font_color", Recipes.KIND_COLOR[recipe.kind])
	unit_art.setup(selected_formula, int(entry.get("tier", 1)))
	var skill := Abilities.skill_of(selected_formula)
	skill = skill.duplicate(true)
	skill.cooldown = maxi(2, int(skill.get("cooldown", 2)) - int(rewards.bonus(GameState.run_buffs, "cooldown")))
	var trait_names: Array[String] = []
	for trait_id in entry.get("traits", []):
		trait_names.append(Traits.label_of(trait_id))
	detail_body.text = "%s · %s\nตำแหน่งปัจจุบัน: %s\n\nHP %d     ATK %.1f\nรวมตำแหน่ง สแตก สายพลัง และบัฟรัน\n\nสกิล: %s\n%s\nคูลดาวน์ %d ตา · ใช้ครั้งแรกใน %d ตา\n\nสายพลัง: %s\n\nเหตุผลทางเคมี: %s" % [
		Abilities.role_label(selected_formula), Abilities.row_label(selected_formula),
		Traits.ROW_LABEL[row], roundi(stats.hp), stats.atk,
		skill.get("name", ""), skill.get("description", ""), int(skill.get("cooldown", 0)),
		maxi(1, ceili(float(skill.get("cooldown", 0)) * 0.5)),
		" · ".join(trait_names), skill.get("chemistry", "")]
	var start_ratio := 1.0 + preload("res://scripts/run_risk.gd").value(GameState, "start_hp", row)
	if start_ratio < 1.0 and row != "bench":
		detail_body.text += "\n\nผลเดินทาง: เริ่มสู้ HP %d%%" % roundi(start_ratio * 100)
	detail_body.text += "\n\nสภาพปัจจุบัน: HP %d%%" % roundi(preload("res://scripts/run_flow.gd").condition(GameState, selected_formula) * 100)
	if row == "bench":
		detail_body.text += "\n\nตัวสำรองยังไม่ร่วมต่อสู้หรือเพิ่มสายพลัง"


func _plan_selected() -> void:
	for key in Recipes.RECIPES:
		if Recipes.RECIPES[key].formula == selected_formula:
			pin(key)
			close_details()
			return
	for key in Recipes.TIER2_RECIPES:
		if Recipes.TIER2_RECIPES[key].formula == selected_formula:
			pin(key)
			close_details()
			return


func pin(key: String) -> void:
	GameState.pin_recipe(key)
	refresh()
	if key != "":
		host._close_book()
		host.show_status("ปักหมุดสูตรแล้ว เปิดร้านเพื่อดูธาตุที่ยังขาด", host.STATUS_INFO)


func _wire_book() -> void:
	if book_wired or host._recipe_labels.is_empty():
		return
	book_wired = true
	for key in host._recipe_labels:
		var label: Label = host._recipe_labels[key]
		var index := label.get_index()
		var row := HBoxContainer.new()
		host._recipe_list.add_child(row)
		host._recipe_list.move_child(row, index)
		label.reparent(row)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(row, "Plan", "เปิดเผยสูตรนี้เพื่อวางแผน แล้วปักหมุดธาตุที่ขาด (ไม่บันทึกเป็นสูตรที่ค้นพบ)", pin.bind(str(key)))


func refresh() -> void:
	if host == null or pin_text == null:
		return
	_wire_book()
	enemy_art.set("kind", GameState.next_monster_kind)
	var enemy := GameState.encounter_enemy()
	enemy_art.visible = GameState.is_boss_wave() or GameState.journey.get("phase", "") == "combat"
	enemy_art.set("kind", enemy.kind)
	enemy_art.set("formula", enemy.formula)
	enemy_art.set("boss_mode", GameState.is_boss_wave())
	var key: String = GameState.pinned_recipe
	var recipe := Plan.recipe_for(key)
	var missing := {}
	shop_plan.visible = not recipe.is_empty()
	if recipe.is_empty():
		pin_text.text = "เลือกสูตรที่อยากผสม"
		pin_text.tooltip_text = "เปิดสูตรแล้วกด Plan เพื่อปักหมุด คลิกสารประกอบเพื่อดูสกิลและค่าสถานะ"
	else:
		var plan := Plan.requirements(key, GameState.board_items, GameState.roster)
		missing = plan.missing_atoms
		pin_text.text = "เป้าหมาย: %s\n%s\n%s · %s" % [recipe.formula,
			" · ".join(plan.components), Abilities.role_label(recipe.formula), Abilities.row_label(recipe.formula)]
		if not plan.fielded.is_empty():
			pin_text.text += "\nย้ายจากทีมมาผสม: %s" % ", ".join(plan.fielded)
		if not plan.steps.is_empty():
			pin_text.text += "\nผสมวัตถุดิบก่อน:\n%s" % "\n".join(plan.steps)
		var shopping: Array[String] = []
		for symbol in missing:
			shopping.append("%s ×%d%s" % [symbol, missing[symbol],
				" (ยังไม่อยู่ในร้าน)" if not GameState.shop_offer.has(symbol) else ""])
		shop_plan.text = "เป้าหมาย %s · %s" % [recipe.formula,
			"ขาด " + ", ".join(shopping) if not shopping.is_empty() else "ธาตุครบแล้ว กลับไปผสมบนกระดาน"]
		shop_plan.tooltip_text = shop_plan.text
		pin_text.text += "\n" + ("ขาด " + ", ".join(shopping) if not shopping.is_empty() else "ธาตุครบแล้ว พร้อมผสม")
		pin_text.tooltip_text = pin_text.text
		if not plan_expanded:
			pin_text.text = "%s\n%s" % [recipe.formula,
				"ขาด " + ", ".join(shopping) if not shopping.is_empty() else "พร้อมผสม"]
	for symbol in host._shop_buttons:
		var button: Button = host._shop_buttons[symbol]
		if not button.has_meta("plan_badge"):
			var badge := Label.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_font_size_override("font_size", 10)
			badge.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
			button.add_child(badge)
			badge.position = Vector2(5, 0)
			button.set_meta("plan_badge", badge)
		var badge: Label = button.get_meta("plan_badge")
		badge.text = "ขาด %d" % int(missing[symbol]) if missing.has(symbol) else ""
		host._paint_shop_button(button, Color(1, 0.85, 0.4) if missing.has(symbol) else Recipes.ELEMENTS[symbol].color)
	if details.visible:
		_refresh_details()


func preview_drop(tile: Control) -> void:
	var zone: String = host._zone_at(tile.global_position + tile.size * 0.5)
	for row in [host._front_row, host._back_row]:
		var selected: bool = host._zone_container(zone) == row
		row.self_modulate = Color(1.3, 1.2, 0.8) if selected else Color.WHITE
	if not tile.is_in_group("molecules"):
		return
	drop_panel.show()
	if host._in_sell_zone(tile):
		drop_text.text = "ปล่อยเพื่อขาย %s · คืน 💰%d (จะถามยืนยันก่อนขาย)" % [tile.formula, Recipes.sell_value(tile.formula)]
		return
	var old: String = GameState.roster.get(tile.formula, {}).get("row", "bench")
	if old == "bench" and zone != "bench" and GameState.fielded_formulas().size() >= GameState.field_limit():
		drop_text.text = "สนามเต็ม %d/%d · ย้ายตัวอื่นกลับกระดาน หรือซื้อ +Slot ก่อน" % [GameState.fielded_formulas().size(), GameState.field_limit()]
		return
	drop_text.text = "%s · %s · %s\n%s" % [tile.formula, Traits.ROW_LABEL[zone],
		Abilities.row_label(tile.formula), Plan.synergy_change(GameState.roster, tile.formula, zone, GameState.trait_bonus())]


func clear_drop_preview() -> void:
	drop_panel.hide()
	for row in [host._front_row, host._back_row]:
		row.self_modulate = Color.WHITE


func _process(_delta: float) -> void:
	for pair in surfaces:
		pair[1].global_position = pair[0].global_position - Vector2(4, 4)
		pair[1].size = pair[0].size + Vector2(8, 8)

