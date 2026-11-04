extends Control
const Campaign := preload("res://scripts/campaign.gd")


const AtomScene := preload("res://scenes/Atom.tscn")
const MoleculeScene := preload("res://scenes/Molecule.tscn")
const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")
const UnitAbilities := preload("res://scripts/unit_abilities.gd")
var _planning: Control

@onready var _board: Control = %Board
@onready var _board_hint: Label = %BoardHint
@onready var _bond_preview: Label = %BondPreview

var _bonding := false
var _bond_anim: Control
@onready var _shop_grid: GridContainer = %ElementGrid
@onready var _recipe_list: VBoxContainer = %RecipeList
@onready var _recipe_scroll: ScrollContainer = %RecipeScroll
@onready var _shop_title: Label = %ShopTitle
@onready var _status_label: Label = %StatusLabel
@onready var _clear_button: Button = %ClearButton
@onready var _gold_label: Label = %GoldLabel
@onready var _battle_button: Button = %BattleButton
@onready var _front_row: Panel = %FrontRow
@onready var _back_row: Panel = %BackRow
@onready var _shop_button: Button = %ShopButton
@onready var _shop_popup: Control = %ShopPopup
@onready var _shop_close: Button = %ShopClose
@onready var _synergy_list: VBoxContainer = %SynergyList
@onready var _recipe_title: Button = %RecipeTitle
@onready var _recipe_strip: Label = %RecipeStrip
@onready var _recipe_book: Control = %RecipeBook
@onready var _book_close: Button = %BookClose
@onready var _status_bar: Panel = %StatusBar
@onready var _reroll_button: Button = %RerollButton
@onready var _interest_label: Label = %InterestLabel
@onready var _next_monster: Label = %NextMonsterLabel
@onready var _team_title: Label = %TeamTitle
@onready var _buy_slot_button: Button = %BuySlotButton

var _sell_dialog: ConfirmationDialog
var _sell_pending_tile: Control

var _recipe_labels: Dictionary = {}
var _shop_buttons: Dictionary = {}
var _status_tween: Tween

const STATUS_OK := Color(0.55, 1.0, 0.55)
const STATUS_BAD := Color(1.0, 0.5, 0.5)
const STATUS_INFO := Color(0.85, 0.85, 0.95)

const RECIPE_LOCKED := UiTokens.TEXT_MUTED
const GOLD := Color(1, 0.85, 0.4)

const ACCENT_PRIMARY := UiTokens.QUEST_GOLD
const ACCENT_SECONDARY := UiTokens.ARCANE


func _rebuild_shop() -> void:
	for child in _shop_grid.get_children():
		child.queue_free()
	_shop_buttons.clear()

	for symbol in GameState.shop_offer:
		if not Recipes.ELEMENTS.has(symbol):
			continue
		var btn := _build_shop_button(symbol)
		_shop_grid.add_child(btn)
		_paint_shop_button(btn, Recipes.ELEMENTS[symbol].color)
		_shop_buttons[symbol] = btn

	_refresh_gold()
	if _planning != null:
		_planning.refresh()


func _on_reroll_pressed() -> void:
	if not GameState.roll_shop(true):
		Audio.play("reject")
		show_status("เงินไม่พอสุ่มร้านใหม่ (ต้องการ 💰%d)" % GameState.REROLL_COST, STATUS_BAD)
		return
	Audio.play("pickup")
	show_status("สุ่มร้านใหม่แล้ว", STATUS_INFO)


func _build_shop_button(symbol: String) -> Button:
	var info: Dictionary = Recipes.ELEMENTS[symbol]
	var cost := _shop_cost(symbol)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 74)
	btn.tooltip_text = "%s — %s (%s)\nราคา 💰%d" % [symbol, info.name, info.thai, cost]
	btn.pressed.connect(_on_shop_button_pressed.bind(symbol))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	btn.add_child(box)

	box.add_child(_chip_line(symbol, 20, info.color))
	box.add_child(_chip_line(info.name, 10, Color(0.72, 0.75, 0.84)))
	box.add_child(_chip_line("💰%d" % cost, 12, GOLD))
	return btn


func _chip_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _paint_shop_button(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var base := btn.get_theme_stylebox(state)
		if not (base is StyleBoxFlat):
			continue
		var style := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = color
		style.border_width_left = 4
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		btn.add_theme_stylebox_override(state, style)

func _paint_button_tier(btn: Button, border: Color, bg_tint: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var base := btn.get_theme_stylebox(state)
		if not (base is StyleBoxFlat):
			continue
		var style := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = border
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.bg_color = style.bg_color.lerp(bg_tint, bg_tint.a)
		btn.add_theme_stylebox_override(state, style)


func _style_button_tiers() -> void:
	_paint_button_tier(_battle_button, ACCENT_PRIMARY,
		Color(ACCENT_PRIMARY.r, ACCENT_PRIMARY.g, ACCENT_PRIMARY.b, 0.28))
	_battle_button.add_theme_font_size_override("font_size", 17)
	_battle_button.add_theme_color_override("font_color", Color(1, 0.97, 0.94))
	_battle_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	for b in [_reroll_button, _buy_slot_button]:
		_paint_button_tier(b, ACCENT_SECONDARY,
			Color(ACCENT_SECONDARY.r, ACCENT_SECONDARY.g, ACCENT_SECONDARY.b, 0.10))

	_clear_button.text = "🗑 Clear"
	_clear_button.tooltip_text = "ล้างกระดาน คืนครึ่งราคาของทุกอะตอมที่ยังไม่ผสม"
	var quiet := StyleBoxFlat.new()
	quiet.bg_color = Color(0, 0, 0, 0)
	quiet.content_margin_left = 8.0
	quiet.content_margin_right = 8.0
	quiet.content_margin_top = 4.0
	quiet.content_margin_bottom = 4.0
	for state in ["normal", "hover", "pressed"]:
		_clear_button.add_theme_stylebox_override(state, quiet)
	_clear_button.add_theme_font_size_override("font_size", 12)
	_clear_button.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	_clear_button.add_theme_color_override("font_hover_color", UiTokens.DANGER)


func _ready() -> void:
	var care := Button.new()
	care.text = "รักษาทีม · %d" % preload("res://scripts/run_flow.gd").HEAL_COST
	care.tooltip_text = "ใช้ทองฟื้น HP ลูกทีมบางส่วน บาดแผลยังติดตามไปไฟต์ถัดไป"
	_battle_button.get_parent().get_parent().add_child(care)
	care.pressed.connect(func():
		if preload("res://scripts/run_flow.gd").buy_heal(GameState):
			show_status("ทีมฟื้นตัวบางส่วนแล้ว", STATUS_OK)
		else:
			show_status("ทีมยังพร้อม หรือทองไม่พอ", STATUS_INFO))
	_resume_reward.call_deferred()
	_planning = Control.new()
	_planning.set_script(load("res://scripts/preparation_ui.gd"))
	add_child(_planning)
	_planning.setup(self)
	_front_row.resized.connect(_repack_row.bind(_front_row))
	_back_row.resized.connect(_repack_row.bind(_back_row))
	_bond_anim = Control.new()
	_bond_anim.set_script(load("res://scripts/bond_anim.gd"))
	_bond_anim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_bond_anim)

	_rebuild_shop()

	var recipe_keys := Recipes.RECIPES.keys()
	recipe_keys.sort_custom(func(a, b):
		var sa: bool = STARTER_HINTS.has(a)
		var sb: bool = STARTER_HINTS.has(b)
		if sa != sb:
			return sa
		var ca: int = a.split(",").size()
		var cb: int = b.split(",").size()
		return ca < cb if ca != cb else a < b
	)
	for key in recipe_keys:
		var row := Label.new()
		row.text = _recipe_placeholder(key)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", RECIPE_LOCKED)
		_recipe_list.add_child(row)
		_recipe_labels[key] = row

	var header := Label.new()
	header.text = "⚗ ปฏิกิริยาขั้นที่ 2 (สารประกอบ + สารประกอบ)"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", GOLD)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	_recipe_list.add_child(header)

	var tier2_keys := Recipes.TIER2_RECIPES.keys()
	tier2_keys.sort()
	for key in tier2_keys:
		var row := Label.new()
		row.text = _tier2_placeholder(key)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", RECIPE_LOCKED)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD
		_recipe_list.add_child(row)
		_recipe_labels[key] = row

	for found_key in GameState.discovered:
		var known = Recipes.RECIPES.get(found_key)
		if known != null:
			_reveal_recipe(found_key, known)
			continue
		var known2 = Recipes.TIER2_RECIPES.get(found_key)
		if known2 != null:
			_reveal_tier2(found_key, known2)
	_planning.refresh()

	_clear_button.pressed.connect(_on_clear_pressed)
	_battle_button.pressed.connect(_on_battle_button_pressed)
	_buy_slot_button.pressed.connect(_on_buy_slot_pressed)
	_recipe_title.pressed.connect(_toggle_book)
	_book_close.pressed.connect(_close_book)
	_shop_button.pressed.connect(_toggle_shop)
	_shop_close.pressed.connect(_close_shop)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.shop_offer_changed.connect(_rebuild_shop)

	_sell_dialog = ConfirmationDialog.new()
	add_child(_sell_dialog)
	_sell_dialog.ok_button_text = "ขาย"
	_sell_dialog.cancel_button_text = "ยกเลิก"
	_sell_dialog.confirmed.connect(_on_sell_confirmed)
	_sell_dialog.canceled.connect(_on_sell_canceled)

	_style_button_tiers()

	Audio.play_music("shop")

	_refresh_gold()
	_refresh_battle_button()
	_refresh_team_title()
	_refresh_synergy_panel()
	_refresh_recipe_title()
	_refresh_next_monster()
	_connect_board_persistence()
	await _restore_board()
	_seed_opening_board()
	_refresh_board_hint()
	_planning.refresh()

	if not is_equal_approx(GameState.shop_price_mult, 1.0):
		if GameState.shop_price_mult < 1.0:
			show_status("🏪 ร้านค้ารอบนี้ราคาถูกลง!", STATUS_OK)
		else:
			show_status("💥 ร้านค้ารอบนี้ราคาแพงขึ้น!", STATUS_BAD)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if _planning.close_details():
			get_viewport().set_input_as_handled()
			return
		if _recipe_book.visible or _shop_popup.visible:
			_close_book()
			_close_shop()
			get_viewport().set_input_as_handled()
			return
		var panel := get_node_or_null("%SettingsPanel")
		if panel != null and not panel.visible:
			Audio.play("click")
			panel.open(true)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_R and event.ctrl_pressed:
		GameState.reset_progress()
		for source in [_board, _front_row, _back_row]:
			for child in source.get_children():
				if child is Control and (child.is_in_group("atoms") or child.is_in_group("molecules")):
					child.queue_free()
		for key in _recipe_labels.keys():
			var label: Label = _recipe_labels[key]
			label.text = _tier2_placeholder(key) if Recipes.TIER2_RECIPES.has(key) \
				else _recipe_placeholder(key)
			label.add_theme_color_override("font_color", RECIPE_LOCKED)
		_refresh_recipe_title()
		show_status("เริ่มเกมใหม่แล้ว 💰%d" % GameState.gold, STATUS_INFO)
		get_viewport().set_input_as_handled()

func _shop_cost(symbol: String) -> int:
	return maxi(1, roundi(Recipes.cost_of(symbol) * GameState.shop_price_mult))


func _on_shop_button_pressed(symbol: String) -> void:
	var cost := _shop_cost(symbol)
	if not GameState.spend_gold(cost):
		Audio.play("reject")
		show_status("เงินไม่พอซื้อ %s (ต้องการ 💰%d)" % [symbol, cost], STATUS_BAD)
		return
	Audio.play("buy")

	_make_atom_tile(symbol, Vector2(
		randf_range(20, max(40, _board.size.x - 100)),
		randf_range(20, max(40, _board.size.y - 100))
	))
	_refresh_board_hint()

func _on_atom_drag_started(atom: Control) -> void:
	_set_drag_visuals(atom, true)
	_dragging = atom
	_drag_origin = atom.position
	_close_book()
	_close_shop()
	Audio.play("pickup", 0.12)
	var parent := atom.get_parent()
	parent.move_child(atom, parent.get_child_count() - 1)
	_board.sell_zone_active = true
	_board.queue_redraw()

func _on_atom_drag_ended(atom: Control) -> void:
	_set_drag_visuals(atom, false)
	_dragging = null
	_clear_preview()
	_board.sell_zone_active = false
	_board.queue_redraw()
	if _try_sell_drop(atom):
		return
	if _apply_zone_drop(atom):
		_clamp_to_board(atom)
		_resolve_cluster(_get_cluster(atom), atom)
	_queue_persist()


func _resolve_cluster(cluster: Array, anchor: Control = null) -> void:
	if cluster.size() <= 1:
		return

	var parts: Array = []
	var loose: Array = []
	for node in cluster:
		if node.is_in_group("molecules"):
			parts.append({"formula": node.formula, "atoms": Recipes.atoms_of(node.formula)})
		else:
			loose.append(node.symbol)
			parts.append({"formula": "", "atoms": [node.symbol]})

	for s in loose:
		if Recipes.is_noble(s):
			_reject_cluster(cluster, "ธาตุหมู่ 8 เสถียรอยู่แล้ว ไม่สามารถสร้างพันธะได้ ❌")
			return

	var intent: Array = _intent(cluster, anchor)
	var result: Dictionary = Recipes.match_cluster(parts, intent)
	if result.is_empty():
		_reject_cluster(cluster, _why_blocked(parts, cluster, intent))
		return

	_bond_cluster(cluster, parts, result)

func _get_cluster(start: Control) -> Array:
	if start.get_parent() != _board:
		return [start]
	var cluster: Array = [start]
	var to_check: Array = [start]
	var all_atoms: Array = get_tree().get_nodes_in_group("atoms")
	all_atoms.append_array(get_tree().get_nodes_in_group("molecules"))
	while to_check.size() > 0:
		var current: Control = to_check.pop_back()
		var current_rect: Rect2 = current.get_global_rect().grow(-16)
		for other in all_atoms:
			if other.get_parent() != _board or other.is_queued_for_deletion():
				continue
			if cluster.has(other):
				continue
			var other_rect: Rect2 = other.get_global_rect().grow(-16)
			if current_rect.intersects(other_rect):
				cluster.append(other)
				to_check.append(other)
	return cluster

func _bond_cluster(cluster: Array, parts: Array, result: Dictionary) -> void:
	var recipe: Dictionary = result.recipe
	var made: int = int(result.get("count", 1))
	var key: String = str(result.key)

	if _bonding:
		return
	_bonding = true

	var used: Array = result.get("used", [])
	var taken: Array = []
	var taken_parts: Array = []
	var leftover: Array = []
	for i in cluster.size():
		if used.has(i):
			taken.append(cluster[i])
			taken_parts.append(parts[i])
		else:
			leftover.append(parts[i])

	var centroid := Vector2.ZERO
	var points: Array = []
	for a in taken:
		var mid: Vector2 = a.position + a.size / 2.0
		points.append(mid)
		centroid += mid
		a.remove_from_group("atoms")
		a.remove_from_group("molecules")
	centroid /= maxf(float(taken.size()), 1.0)

	_refresh_board_hint()
	_bond_anim.play(points, taken_parts,
		Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE),
		GameState.discovered.has(key))
	await _bond_anim.finished

	if not is_inside_tree():
		return
	_bonding = false

	for p in taken_parts:
		var f: String = str(p.get("formula", ""))
		if f != "":
			GameState.consume_from_roster(f)

	for a in taken:
		if is_instance_valid(a):
			a.queue_free()

	for i in made:
		var spread := Vector2(28.0 * (float(i) - float(made - 1) * 0.5), 0.0)
		_spawn_molecule(recipe, centroid + spread, int(result.get("tier", 1)))

	Fx.burst(self, _board.global_position + centroid,
		Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE), 24)
	Fx.float_text(self, _board.global_position + centroid - Vector2(0, 40),
		recipe.formula, Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE), 30)

	Audio.play("bond")
	GameState.mark_discovered(key)
	if int(result.get("tier", 1)) == 2:
		_reveal_tier2(key, recipe)
	else:
		_reveal_recipe(key, recipe)
	_refresh_recipe_title()
	_refresh_next_monster()
	var spare: Array = []
	for p in leftover:
		var f: String = str(p.get("formula", ""))
		spare.append(f if f != "" else " + ".join(p.get("atoms", [])))
	var tail: String = ""
	if not spare.is_empty():
		tail = "  (%s เหลือ ไม่ได้เข้าร่วม)" % " + ".join(spare)

	if made > 1:
		show_status("ดุลสมการถูกต้อง! ได้ %s (%s) ×%d 🎉%s" % [
			recipe.formula, recipe.thai, made, tail], STATUS_OK)
	else:
		show_status("ผสมสำเร็จ! ได้ %s (%s) 🎉%s" % [
			recipe.formula, recipe.thai, tail], STATUS_OK)
	_refresh_board_hint()


func _spawn_molecule(recipe: Dictionary, centroid: Vector2, tier: int) -> Control:
	var molecule := _make_molecule_tile(recipe, centroid, tier, true)
	molecule.pop_in()

	GameState.add_to_roster({
		"formula": recipe.formula,
		"thai": recipe.thai,
		"kind": recipe.kind,
		"traits": Recipes.traits_of_recipe(recipe),
		"tier": tier,
	})

	Fx.burst(self, _board.global_position + centroid,
		Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE), 24 if tier == 1 else 40)
	Fx.float_text(self, _board.global_position + centroid - Vector2(0, 40),
		recipe.formula, Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE), 30 if tier == 1 else 38)

	_settle_into_row(molecule)
	return molecule


func _on_molecule_drag_started(molecule: Control) -> void:
	_set_drag_visuals(molecule, true)
	_dragging = molecule
	_drag_origin = molecule.position
	_close_book()
	_close_shop()
	Audio.play("pickup", 0.12)
	var parent := molecule.get_parent()
	parent.move_child(molecule, parent.get_child_count() - 1)
	_board.sell_zone_active = true
	_board.queue_redraw()


func _on_molecule_drag_ended(molecule: Control) -> void:
	_set_drag_visuals(molecule, false)
	_dragging = null
	_clear_preview()
	_board.sell_zone_active = false
	_board.queue_redraw()
	if _try_sell_drop(molecule):
		return
	if _apply_zone_drop(molecule):
		_resolve_cluster(_get_cluster(molecule), molecule)
	_queue_persist()


func _reject_cluster(cluster: Array, message: String) -> void:
	Audio.play("reject")
	var centroid := Vector2.ZERO
	for a in cluster:
		centroid += a.position + a.size / 2.0
	centroid /= cluster.size()

	for a in cluster:
		a.flash(STATUS_BAD)
		a.shake()
		var dir: Vector2 = (a.position + a.size / 2.0) - centroid
		if dir.length() < 1.0:
			dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
		dir = dir.normalized()
		var target: Vector2 = _clamp_point(a, a.position + dir * 70.0)
		var tween: Tween = a.create_tween()
		tween.tween_property(a, "position", target, 0.25).set_trans(Tween.TRANS_QUAD)

	show_status(message, STATUS_BAD)

func _reveal_recipe(key: String, recipe: Dictionary) -> void:
	var label: Label = _recipe_labels.get(key)
	if label == null:
		return
	label.text = "%s -> %s (%s)" % [" + ".join(key.split(",")), recipe.formula, recipe.thai]
	label.add_theme_color_override("font_color", Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE))
	_celebrate_recipe(label)

const STARTER_HINTS := ["H,H", "Cl,Na", "H,H,O"]


func _recipe_placeholder(key: String) -> String:
	if STARTER_HINTS.has(key):
		return "%s -> ???" % " + ".join(key.split(","))

	var atom_count: int = key.split(",").size()
	var marks: Array = []
	for _i in atom_count:
		marks.append("?")
	return "%s -> ???" % " + ".join(marks)

func _tier2_placeholder(key: String) -> String:
	return "%s -> ???" % " + ".join(key.split(","))


func _reveal_tier2(key: String, recipe: Dictionary) -> void:
	var label: Label = _recipe_labels.get(key)
	if label == null:
		return
	label.text = "%s -> %s (%s)" % [" + ".join(key.split(",")), recipe.formula, recipe.thai]
	label.tooltip_text = str(recipe.get("note", ""))
	label.add_theme_color_override("font_color", Recipes.KIND_COLOR.get(recipe.kind, Color.WHITE))


func _refresh_recipe_title() -> void:
	_recipe_title.text = "📖 สูตรผสมธาตุ  %d/%d" % [GameState.discovered.size(), _recipe_labels.size()]
	_refresh_recipe_strip()
	if _shop_title != null:
		_shop_title.text = "🧪 ร้านค้าธาตุ  ·  ด่าน %d/%d" % [
			GameState.wave, GameState.FINAL_WAVE]

func _clamp_point(atom: Control, point: Vector2) -> Vector2:
	var max_x: float = max(0.0, _board.size.x - atom.size.x)
	var max_y: float = max(0.0, _board.size.y - atom.size.y)
	return Vector2(clampf(point.x, 0, max_x), clampf(point.y, 0, max_y))

func _clamp_to_board(atom: Control) -> void:
	atom.position = _clamp_point(atom, atom.position)

func _on_clear_pressed() -> void:
	var refund := 0
	for child in _board.get_children():
		if child is Control and child.is_in_group("atoms"):
			refund += _refund_for(child.symbol)
			child.queue_free()
	if refund > 0:
		GameState.add_gold(refund)
		Audio.play("buy")
		show_status("ล้างกระดานแล้ว คืนเงิน 💰%d (ครึ่งราคา)" % refund, STATUS_OK)
	else:
		show_status("ล้างกระดานแล้ว", STATUS_INFO)
	_refresh_board_hint()

func _on_battle_button_pressed() -> void:
	Audio.play("buy")
	var coach := get_node_or_null("%Tutorial")
	if coach != null and coach.has_method("finish"):
		coach.finish()
	Transition.change_scene("res://scenes/Battle.tscn" if GameState.journey.get("phase", "") == "combat" else "res://scenes/Event.tscn")

func _on_gold_changed(_amount: int) -> void:
	_refresh_gold()

func _refresh_gold() -> void:
	_gold_label.text = "💰 %d" % GameState.gold
	for symbol in _shop_buttons.keys():
		var btn: Button = _shop_buttons[symbol]
		btn.disabled = GameState.gold < _shop_cost(symbol)
	_refresh_slot_button()
	if _reroll_button:
		_reroll_button.disabled = GameState.gold < GameState.REROLL_COST
		_reroll_button.text = "🔄 Reroll 💰%d" % GameState.REROLL_COST
		_reroll_button.tooltip_text = "สุ่มร้านค้าใหม่ทั้งหมด ใช้เงิน %d" % GameState.REROLL_COST
	if _interest_label:
		var interest: int = GameState.interest_earned()
		var capped: bool = interest >= GameState.MAX_INTEREST
		_interest_label.text = "ดอกเบี้ย +%d%s" % [
			interest, " · เต็ม" if capped else ""
		]
		_interest_label.tooltip_text = "รับดอกเบี้ยเมื่อชนะ จากเงินที่เก็บไว้ สูงสุด +%d ต่อด่าน" % GameState.MAX_INTEREST
		_interest_label.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.58) if capped else Color(0.55, 0.78, 0.6))

func _refresh_battle_button() -> void:
	var count: int = GameState.fielded_formulas().size()
	_battle_button.text = "เดินทาง →"
	_battle_button.tooltip_text = "เลือกเส้นทางและตอบเหตุการณ์ ทีมพร้อมต่อสู้ %d ชนิด · บอสบังคับที่จุด 5/10/15/20/25" % count
	_battle_button.disabled = not GameState.pending_reward.is_empty()

func _on_roster_changed() -> void:
	_refresh_battle_button()
	_refresh_team_title()
	_refresh_synergy_panel()
	if _planning != null:
		_planning.refresh()

func _refresh_team_title() -> void:
	var fielded: int = GameState.fielded_formulas().size()
	_team_title.text = "🧬 ทีม %d/%d" % [fielded, GameState.field_limit()]
	var health: Array[String] = []
	for formula in GameState.roster:
		health.append("%s · HP %d%%" % [formula, roundi(preload("res://scripts/run_flow.gd").condition(GameState, formula) * 100)])
	_team_title.tooltip_text = "\n".join(health)
	_team_title.add_theme_color_override("font_color",
		GOLD if fielded >= GameState.field_limit() else Color(0.9, 0.92, 0.97))
	_refresh_slot_button()

func _refresh_synergy_panel() -> void:
	for c in _synergy_list.get_children():
		c.queue_free()

	var counts := Traits.trait_counts(GameState.fielded_roster(), GameState.trait_bonus())

	var active := Traits.active_tiers(GameState.fielded_roster(), GameState.trait_bonus())
	for trait_id in Traits.ORDER:
		var count := int(counts.get(trait_id, 0))
		var tier := int(active.get(trait_id, 0))
		var color: Color = Traits.color_of(trait_id)

		var next_at := Traits.next_threshold(trait_id, count)
		var progress := "%d/%d" % [count, next_at] if next_at > 0 else "%d (สูงสุด)" % count

		var head := Button.new()
		head.text = "%s  %s" % [Traits.label_of(trait_id), progress]
		head.tooltip_text = Traits.active_text(trait_id, tier) if tier > 0 else "อีก %d ชนิดเพื่อเปิดสายพลัง" % (next_at - count)
		head.mouse_filter = Control.MOUSE_FILTER_STOP
		head.add_theme_font_size_override("font_size", 16)
		head.add_theme_color_override("font_color", color if tier > 0 else color.darkened(0.45))
		_synergy_list.add_child(head)
		head.pressed.connect(_open_trait.bind(trait_id))

		var meter := ProgressBar.new()
		meter.custom_minimum_size.y = 8
		meter.max_value = next_at if next_at > 0 else count
		meter.value = count
		meter.show_percentage = false
		meter.modulate = color
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_synergy_list.add_child(meter)
	if not GameState.run_buffs.is_empty():
		var buffs := Label.new()
		buffs.text = "บัฟรัน · %d" % GameState.run_buffs.size()
		var details: Array[String] = []
		for id in GameState.run_buffs:
			var card: Dictionary = preload("res://scripts/boss_rewards.gd").CARDS[id]
			details.append("%s · %s\n%s" % [card.name, card.tag, card.tip])
		buffs.tooltip_text = "\n\n".join(details)
		buffs.add_theme_color_override("font_color", UiTokens.QUEST_GOLD)
		_synergy_list.add_child(buffs)

func _open_trait(id: String) -> void:
	var panel := preload("res://scripts/trait_details.gd").new()
	panel.setup(id)
	add_child(panel)

func _resume_reward() -> void:
	if GameState.pending_reward.is_empty():
		if GameState.rewarded_bosses.has(GameState.FINAL_WAVE):
			GameState.complete_run()
			Transition.change_scene("res://scenes/Home.tscn")
		return
	var panel := preload("res://scripts/reward_panel.gd").new()
	panel.finished.connect(func():
		_refresh_synergy_panel()
		_refresh_battle_button()
		if GameState.rewarded_bosses.has(GameState.FINAL_WAVE):
			GameState.complete_run()
			Transition.change_scene("res://scenes/Home.tscn"))
	add_child(panel)

func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTokens.TEXT_MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label

const STATUS_HOLD_SECONDS := 10.0
const STATUS_FADE_SECONDS := 1.5

func show_status(message: String, color: Color) -> void:
	if _status_tween:
		_status_tween.kill()
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)
	_status_bar.modulate.a = 1.0
	_status_tween = create_tween()
	_status_tween.tween_interval(STATUS_HOLD_SECONDS)
	_status_tween.tween_property(_status_bar, "modulate:a", 0.0, STATUS_FADE_SECONDS)


func _refresh_next_monster() -> void:
	var kind: String = GameState.next_monster_kind
	if not GameState.is_boss_wave() and GameState.journey.get("phase", "") != "combat":
		_next_monster.text = "เลือกเหตุการณ์ · บอสใน %d ช่วง" % (Campaign.STAGES_PER_REGION - GameState.wave % Campaign.STAGES_PER_REGION)
		_next_monster.tooltip_text = "กดเดินทางเพื่อเลือกเหตุการณ์ คุณไม่จำเป็นต้องสู้มอนทุกช่วง · บอสบังคับที่จุด 5/10/15/20/25"
		_next_monster.add_theme_color_override("font_color", UiTokens.ARCANE)
		return
	kind = str(GameState.encounter_enemy().kind)
	var counter := Recipes.counter_of(kind)
	if counter.is_empty():
		_next_monster.text = "หุ่นฝึกซ้อม"
		_next_monster.tooltip_text = "ไม่มีธาตุใดได้เปรียบ"
		_next_monster.add_theme_color_override("font_color", Color(0.62, 0.66, 0.78))
		return
	_next_monster.text = "%s · แพ้%s" % [
		Recipes.KIND_LABEL.get(kind, kind), Recipes.KIND_LABEL.get(counter, counter)]
	var enemy := GameState.encounter_enemy()
	_next_monster.text = ("บอส " if GameState.is_boss_wave() else "") + enemy.formula + " · แพ้" + str(Recipes.KIND_LABEL.get(counter, counter))
	_next_monster.tooltip_text = "ศัตรูสาย%s · ใช้สาย%sได้เปรียบ\n%s" % [Recipes.KIND_LABEL.get(kind, kind), Recipes.KIND_LABEL.get(counter, counter), Recipes.reason_beats(counter, kind)]
	_next_monster.tooltip_text = "%s · %s\n%s" % [enemy.formula, enemy.name, _next_monster.tooltip_text]
	_next_monster.add_theme_color_override("font_color", Recipes.KIND_COLOR.get(kind, Color.WHITE))


func _refresh_slot_button() -> void:
	if _buy_slot_button == null:
		return
	var price: int = GameState.slot_price()
	if price <= 0:
		_buy_slot_button.text = "Full"
		_buy_slot_button.tooltip_text = "ซื้อช่องลงสนามได้ครบตามเพดานแล้ว"
		_buy_slot_button.disabled = true
		return
	_buy_slot_button.text = "+Slot 💰%d" % price
	_buy_slot_button.tooltip_text = "ซื้อช่องลงสนามเพิ่มอีก 1 ช่อง"
	_buy_slot_button.disabled = GameState.gold < price


func _on_buy_slot_pressed() -> void:
	var price: int = GameState.slot_price()
	if not GameState.buy_field_slot():
		Audio.play("reject")
		show_status("เงินไม่พอขยายสนาม (ต้องการ 💰%d)" % price, STATUS_BAD)
		return
	Audio.play("bond")
	show_status("ขยายสนามแล้ว! ลงสนามได้ %d ตัว" % GameState.field_limit(), STATUS_OK)


const OPENING_ATOMS := ["H", "H", "O"]


const OPENING_ROW_Y := 0.45

const ZONE_MIX := Traits.ROW_BENCH

const ROW_TILE_GAP := 6.0


func _zone_at(global_point: Vector2) -> String:
	if _front_row.get_parent().get_global_rect().has_point(global_point):
		return Traits.ROW_FRONT
	if _back_row.get_parent().get_global_rect().has_point(global_point):
		return Traits.ROW_BACK
	return ZONE_MIX


func _zone_container(zone: String) -> Control:
	match zone:
		Traits.ROW_FRONT:
			return _front_row
		Traits.ROW_BACK:
			return _back_row
		_:
			return _board


func _place_in_zone(tile: Control, zone: String) -> void:
	var target := _zone_container(zone)
	var old_parent := tile.get_parent()
	if old_parent != target:
		tile.reparent(target, true)
	if target == _board:
		_clamp_to_board(tile)
	else:
		_repack_row(target)
	if old_parent != null and old_parent != target and old_parent in [_front_row, _back_row]:
		_repack_row(old_parent)


func _repack_row(container: Control) -> void:
	var x := ROW_TILE_GAP
	var y := ROW_TILE_GAP
	var row_h := 0.0
	for child in container.get_children():
		if not (child is Control) or child.is_queued_for_deletion():
			continue
		var tile: Control = child
		if tile == _dragging:
			continue  # Follows the cursor; repacking around it would fight that.
		if x > ROW_TILE_GAP and x + tile.size.x > container.size.x - ROW_TILE_GAP:
			x = ROW_TILE_GAP
			y += row_h + ROW_TILE_GAP
			row_h = 0.0
		tile.position = Vector2(x, y)
		x += tile.size.x + ROW_TILE_GAP
		row_h = maxf(row_h, tile.size.y)
	container.custom_minimum_size.y = y + row_h + ROW_TILE_GAP


func _gather_tiles_into_zone(formula: String, zone: String, except: Control) -> int:
	var moved := 0
	for source in [_board, _front_row, _back_row]:
		for child in source.get_children():
			if child == except or not (child is Control) or not child.is_in_group("molecules"):
				continue
			if child.formula != formula:
				continue
			_place_in_zone(child, zone)
			moved += 1
	return moved


func _settle_into_row(tile: Control) -> void:
	if not tile.is_in_group("molecules"):
		_place_in_zone(tile, ZONE_MIX)
		return
	var entry: Dictionary = GameState.roster.get(tile.formula, {})
	var zone: String = str(entry.get("row", Traits.ROW_FRONT))
	_place_in_zone(tile, zone)


var _drag_origin := Vector2.ZERO


func _apply_zone_drop(tile: Control) -> bool:
	var global_centre: Vector2 = tile.global_position + tile.size * 0.5
	var zone := _zone_at(global_centre)

	if tile.is_in_group("atoms"):
		if zone != ZONE_MIX:
			_place_in_zone(tile, ZONE_MIX)
			show_status("อะตอมเดี่ยวอยู่บนบอร์ดเท่านั้น ต้องผสมเป็นสารประกอบก่อนถึงลงสนามได้",
				STATUS_INFO)
			Audio.play("reject")
			return false
		return true

	if not tile.is_in_group("molecules"):
		return true

	var formula: String = tile.formula
	if not GameState.set_row(formula, zone):
		tile.position = _drag_origin
		show_status("สนามเต็มแล้ว (%d/%d) — ขยายสนาม หรือย้ายตัวอื่นออกจากสนามก่อน" % [
			GameState.fielded_formulas().size(), GameState.field_limit()], STATUS_BAD)
		Audio.play("reject")
		return false

	_place_in_zone(tile, zone)
	var followers := _gather_tiles_into_zone(formula, zone, tile)
	Audio.play("click", 0.1)

	var where: String = Traits.ROW_LABEL.get(zone, zone)
	if followers > 0:
		show_status("%s ×%d ย้ายไป%s (สารเดียวกันอยู่แถวเดียวกันเสมอ)" % [
			formula, followers + 1, where], STATUS_INFO)
	else:
		show_status("%s ย้ายไป%s" % [formula, where], STATUS_INFO)
	return zone == ZONE_MIX


func _make_atom_tile(symbol: String, pos: Vector2) -> Control:
	var atom := AtomScene.instantiate()
	_board.add_child(atom)
	atom.set_symbol(symbol)
	atom.position = pos
	atom.add_to_group("atoms")
	atom.drag_started.connect(_on_atom_drag_started)
	atom.drag_ended.connect(_on_atom_drag_ended)
	atom.sell_requested.connect(_on_atom_sell_requested)
	atom.selected.connect(_inspect_atom)
	return atom


func _make_molecule_tile(recipe: Dictionary, pos: Vector2, tier: int,
		centred: bool) -> Control:
	var molecule := MoleculeScene.instantiate()
	_board.add_child(molecule)
	molecule.setup(recipe.formula, recipe.name, recipe.thai, recipe.kind, tier)
	molecule.position = pos - (molecule.custom_minimum_size / 2.0 if centred else Vector2.ZERO)
	molecule.add_to_group("molecules")
	molecule.drag_started.connect(_on_molecule_drag_started)
	molecule.drag_ended.connect(_on_molecule_drag_ended)
	molecule.selected.connect(_planning.show_unit)
	molecule.removed.connect(_on_molecule_sell_requested)
	return molecule


var _restoring_board := false

var _persist_queued := false


func _connect_board_persistence() -> void:
	for container in [_board, _front_row, _back_row]:
		container.child_entered_tree.connect(_on_board_children_changed)
		container.child_exiting_tree.connect(_on_board_children_changed)


func _on_board_children_changed(_child: Node) -> void:
	_queue_persist()
	_repack_row.call_deferred(_front_row)
	_repack_row.call_deferred(_back_row)


func _queue_persist() -> void:
	if _persist_queued or _restoring_board:
		return
	_persist_queued = true
	_persist_board.call_deferred()


func _persist_board() -> void:
	_persist_queued = false
	if _restoring_board:
		return
	var items: Array = []
	for source in [_board, _front_row, _back_row]:
		for child in source.get_children():
			if not (child is Control) or child.is_queued_for_deletion():
				continue
			if child.is_in_group("atoms"):
				items.append({
					"type": "atom", "key": child.symbol, "tier": 1,
					"x": child.position.x, "y": child.position.y,
				})
			elif child.is_in_group("molecules"):
				items.append({
					"type": "molecule", "key": child.formula, "tier": child.tier,
					"x": child.position.x, "y": child.position.y,
				})
	GameState.set_board_items(items)
	_planning.refresh()


func _restore_board() -> void:
	if GameState.board_items.is_empty():
		return
	for _i in 10:
		if _board.size.y > 200.0:
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return

	var saved: Array = GameState.board_items.duplicate(true)
	_restoring_board = true
	for entry in saved:
		var pos := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		var key := str(entry.get("key", ""))
		var tile: Control = null
		if str(entry.get("type", "")) == "atom":
			tile = _make_atom_tile(key, pos)
		else:
			var recipe = Recipes.find_by_formula(key)
			if recipe == null:
				continue  # Sanitised on load, but the table can change under us.
			tile = _make_molecule_tile(
				recipe, pos, int(entry.get("tier", 1)), false)
		_settle_into_row(tile)
	_restoring_board = false
	_queue_persist()
	_refresh_board_hint()


func _seed_opening_board() -> void:
	if not GameState.roster.is_empty() or GameState.wave != 1:
		return
	for _i in 10:
		if _board.size.y > 200.0:
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	for child in _board.get_children():
		if child.is_in_group("atoms") or child.is_in_group("molecules"):
			return

	var count := OPENING_ATOMS.size()
	for i in count:
		var span: float = maxf(_board.size.x - 160.0, 120.0)
		_make_atom_tile(OPENING_ATOMS[i], Vector2(
			40.0 + span * (float(i) + 0.5) / float(count),
			_board.size.y * OPENING_ROW_Y))

	_refresh_board_hint()


func _refresh_board_hint() -> void:
	if _board_hint == null:
		return
	if _bonding:
		_board_hint.visible = false
		return
	var atoms := 0
	for child in _board.get_children():
		if child.is_in_group("atoms"):
			atoms += 1

	if atoms > 0 and GameState.roster.is_empty():
		_board_hint.text = "ลากมาชนกัน"
		_board_hint.visible = true
	elif atoms == 0 and GameState.roster.is_empty():
		_board_hint.text = "ซื้อธาตุ → ลากมาผสม"
		_board_hint.visible = true
	else:
		_board_hint.visible = false


func _celebrate_recipe(label: Label) -> void:
	if _recipe_scroll == null or label == null:
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(label):
		return
	_recipe_scroll.ensure_control_visible(label)

	var tween := create_tween()
	for _i in 3:
		tween.tween_property(label, "modulate", Color(1.6, 1.6, 1.2), 0.14)
		tween.tween_property(label, "modulate", Color.WHITE, 0.14)


func _why_no_reaction(parts: Array) -> String:
	var near: Dictionary = Recipes.nearest_reaction(parts)
	if near.get("kind", "") == "missing":
		var bits: Array = []
		for sym in near.missing.keys():
			bits.append("%s อีก %d" % [sym, int(near.missing[sym])])
		var times: String = " ×%d" % int(near.count) if int(near.count) > 1 else ""
		return "ใกล้แล้ว! ขาด %s -- เติมแล้วจะได้ %s (%s)%s" % [
			" และ ".join(bits), near.formula, near.thai, times]
	if near.get("kind", "") == "noop":
		return "รวม%sเข้าด้วยกันก็ยังเป็น%s ไม่เกิดสารใหม่" % [near.thai, near.thai]

	var loose: Array = []
	for p in parts:
		if str(p.get("formula", "")) == "":
			loose.append_array(p.get("atoms", []))

	var readings: Array = []
	var need := 0
	for s in loose:
		var v: int = Recipes.valence_of(s)
		if v < 0:
			continue
		readings.append("%s เวเลนซ์ %d" % [s, v])
		need += (8 - v) if v > 4 else v
	if readings.is_empty():
		return "ยังไม่เกิดปฏิกิริยา ลองจับคู่ธาตุอื่นดู"

	var head: String = " · ".join(readings)
	if need > 0:
		return "%s — พันธะยังไม่ลงตัว ขาดอีก %d อิเล็กตรอน" % [head, need]
	return "%s — ยังไม่ใช่สูตรที่ถูกต้อง" % head


func _intent(cluster: Array, anchor: Control) -> Array:
	if anchor == null:
		return []
	var anchor_index: int = cluster.find(anchor)
	if anchor_index < 0:
		return []

	var partner := -1
	var most := 0.0
	var mine: Rect2 = anchor.get_global_rect()
	for i in cluster.size():
		if i == anchor_index:
			continue
		var overlap: Rect2 = mine.intersection(cluster[i].get_global_rect())
		var area: float = overlap.size.x * overlap.size.y
		if area > most:
			most = area
			partner = i

	if partner < 0:
		return [anchor_index]
	return [anchor_index, partner]


func _why_blocked(parts: Array, cluster: Array, intent: Array) -> String:
	if intent.is_empty():
		return _why_no_reaction(parts)

	var loose: Dictionary = Recipes.match_cluster(parts)
	if loose.is_empty():
		return _why_no_reaction(parts)

	var pair: Array = []
	for i in loose.get("used", []):
		pair.append(_part_name(parts[i]))
	var moved: String = _part_name(parts[intent[0]])
	return "%s ที่คุณลากไม่เข้าปฏิกิริยานี้ — แต่ %s เข้ากันได้ ลองลากสองตัวนั้นชนกันตรง ๆ" % [
		moved, " กับ ".join(pair)]


func _part_name(part: Dictionary) -> String:
	var f: String = str(part.get("formula", ""))
	if f != "":
		return f
	return " + ".join(part.get("atoms", []))


var _lit: Array = []
var _dragging: Control = null
var _preview_key := ""


func _refresh_preview(dragged: Control) -> void:
	if dragged == null or not is_instance_valid(dragged):
		_clear_preview()
		return

	var cluster: Array = _get_cluster(dragged)
	if cluster.size() <= 1:
		_clear_preview()
		return

	var signature := ""
	for node in cluster:
		signature += str(node.get_instance_id()) + ","
	if signature == _preview_key:
		return
	_preview_key = signature
	_unlight()

	var parts: Array = []
	for node in cluster:
		if node.is_in_group("molecules"):
			parts.append({"formula": node.formula, "atoms": Recipes.atoms_of(node.formula)})
		else:
			parts.append({"formula": "", "atoms": [node.symbol]})

	var result: Dictionary = Recipes.match_cluster(parts, _intent(cluster, dragged))
	if result.is_empty():
		var near: Dictionary = Recipes.nearest_reaction(parts)
		if near.get("kind", "") == "missing":
			var bits: Array = []
			for sym in near.missing.keys():
				bits.append("%s อีก %d" % [sym, int(near.missing[sym])])
			_bond_preview.text = "ยังไม่ลงตัว — ขาด %s" % " และ ".join(bits)
		else:
			_bond_preview.text = "ยังไม่เข้าสูตร"
		_bond_preview.add_theme_color_override("font_color", Color(0.62, 0.66, 0.78))
		_bond_preview.visible = true
		return

	var made: int = int(result.get("count", 1))
	var times: String = "  ×%d" % made if made > 1 else ""
	_bond_preview.text = "ปล่อยเพื่อสร้าง %s (%s)%s" % [
		result.recipe.formula, result.recipe.thai, times]
	_bond_preview.text += "\n%s · %s" % [UnitAbilities.role_label(result.recipe.formula),
		UnitAbilities.row_label(result.recipe.formula)]
	_bond_preview.add_theme_color_override("font_color", STATUS_OK)
	_bond_preview.visible = true

	for i in result.get("used", []):
		if i < cluster.size():
			cluster[i].modulate = Color(0.72, 1.25, 0.78)
			_lit.append(cluster[i])


func _unlight() -> void:
	for node in _lit:
		if is_instance_valid(node):
			node.modulate = Color.WHITE
	_lit.clear()


func _clear_preview() -> void:
	_preview_key = ""
	_unlight()
	if _bond_preview != null:
		_bond_preview.visible = false


func _process(_delta: float) -> void:
	if _dragging != null:
		_refresh_preview(_dragging)
		_planning.preview_drop(_dragging)


func _set_drag_visuals(tile: Control, active: bool) -> void:
	tile.z_index = 100 if active else 0
	_board.clip_contents = not active
	for row in [_front_row, _back_row]:
		row.get_parent().clip_contents = not active
	if not active and _planning != null:
		_planning.clear_drop_preview()


func _toggle_book() -> void:
	Audio.play("click")
	_close_shop()
	_recipe_book.visible = not _recipe_book.visible


func _close_book() -> void:
	if not _recipe_book.visible:
		return
	Audio.play("click")
	_recipe_book.visible = false


func _toggle_shop() -> void:
	Audio.play("click")
	_close_book()
	_shop_popup.visible = not _shop_popup.visible


func _close_shop() -> void:
	if not _shop_popup.visible:
		return
	Audio.play("click")
	_shop_popup.visible = false


func _refresh_recipe_strip() -> void:
	if _recipe_strip == null:
		return
	var lines: Array = []
	for key in STARTER_HINTS:
		if lines.size() >= 2:
			break
		if not GameState.discovered.has(key) and _recipe_labels.has(key):
			lines.append("• %s -> ???" % " + ".join(key.split(",")))

	if lines.size() < 2:
		for key in _recipe_labels.keys():
			if lines.size() >= 2:
				break
			if GameState.discovered.has(key) or Recipes.TIER2_RECIPES.has(key):
				continue
			lines.append("• %s -> ???" % " + ".join(key.split(",")))

	if lines.is_empty():
		_recipe_strip.text = "ค้นพบครบทุกสูตรแล้ว 🎉"
	else:
		_recipe_strip.text = "\n".join(lines)


func _refund_for(symbol: String) -> int:
	return maxi(1, int(Recipes.cost_of(symbol) / 2))


func _on_atom_sell_requested(atom: Control) -> void:
	if _dragging != null:
		return
	var symbol: String = atom.symbol
	var refund := _refund_for(symbol)
	atom.remove_from_group("atoms")
	atom.queue_free()
	GameState.add_gold(refund)
	Audio.play("buy")
	show_status("ขาย %s คืน 💰%d (คลิกขวาเพื่อขาย)" % [symbol, refund], STATUS_OK)
	_refresh_board_hint()


func _in_sell_zone(tile: Control) -> bool:
	var sz: float = Traits.SELL_ZONE_SIZE
	var global_centre: Vector2 = tile.global_position + tile.size * 0.5
	var corner := Rect2(_board.get_global_rect().end - Vector2(sz, sz), Vector2(sz, sz))
	return corner.has_point(global_centre)


func _try_sell_drop(tile: Control) -> bool:
	if not _in_sell_zone(tile):
		return false
	return _offer_sale(tile)


func _on_molecule_sell_requested(tile: Control) -> void:
	if _dragging != null or _sell_pending_tile != null:
		return
	_drag_origin = tile.position
	_offer_sale(tile)


func _offer_sale(tile: Control) -> bool:

	var is_atom := tile.is_in_group("atoms")
	var label: String
	var refund: int
	if is_atom:
		label = tile.symbol
		refund = _refund_for(tile.symbol)
	else:
		label = tile.formula
		refund = Recipes.sell_value(tile.formula)

	if refund <= 0:
		Audio.play("reject")
		tile.position = _drag_origin
		_queue_persist()
		return true

	_sell_pending_tile = tile
	_sell_dialog.dialog_text = "ขาย %s คืนเงิน 💰%d?" % [label, refund]
	_sell_dialog.popup_centered()
	return true


func _on_sell_confirmed() -> void:
	var tile := _sell_pending_tile
	_sell_pending_tile = null
	if tile == null or not is_instance_valid(tile):
		return
	if tile.is_in_group("atoms"):
		var symbol: String = tile.symbol
		var refund := _refund_for(symbol)
		tile.remove_from_group("atoms")
		tile.queue_free()
		GameState.add_gold(refund)
		Audio.play("buy")
		show_status("ขาย %s คืน 💰%d" % [symbol, refund], STATUS_OK)
	else:
		var formula: String = tile.formula
		tile.remove_from_group("molecules")
		tile.queue_free()
		var refund := GameState.sell_compound(formula)
		Audio.play("buy")
		show_status("ขาย %s คืนเงิน 💰%d" % [formula, refund], STATUS_INFO)
	_refresh_board_hint()


func _on_sell_canceled() -> void:
	var tile := _sell_pending_tile
	_sell_pending_tile = null
	if tile == null or not is_instance_valid(tile):
		return
	tile.position = _drag_origin
	_queue_persist()

func _inspect_atom(atom: Control) -> void:
	var dialog := ConfirmationDialog.new()
	add_child(dialog)
	dialog.title = str(atom.symbol)
	dialog.dialog_text = str(atom.tooltip_text) + "\nขายคืน %d ทอง" % _refund_for(atom.symbol)
	dialog.ok_button_text = "ขาย"
	dialog.cancel_button_text = "ปิด"
	dialog.confirmed.connect(func():
		_drag_origin = atom.position
		_sell_pending_tile = atom
		_on_sell_confirmed()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(360, 180))
