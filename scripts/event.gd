extends Control
const Expedition := preload("res://scripts/expedition.gd")
const Campaign := preload("res://scripts/campaign.gd")
@onready var _title: Label = %EventTitle
@onready var _desc: Label = %EventDesc
@onready var _card_row: Container = %CardRow
@onready var _continue_button: Button = %ContinueButton
var _skip_button: Button
var _illustration: TextureRect
var _stats: Label
var _navigating := false

func _ready() -> void:
	Audio.play_music("shop")
	if not GameState.pending_reward.is_empty():
		Transition.change_scene("res://scenes/Main.tscn")
		return
	Expedition.ensure(GameState)
	var layout := _card_row.get_parent()
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_color_override("font_color", Color("e8c37b"))
	layout.add_child(_stats)
	layout.move_child(_stats, 0)
	_desc.add_theme_font_size_override("font_size", 20)
	var effects := Label.new()
	effects.name = "ActiveConsequences"
	effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effects.add_theme_color_override("font_color", Color("efae87"))
	effects.add_theme_font_size_override("font_size", 16)
	layout.add_child(effects)
	layout.move_child(effects, 3)
	_continue_button.pressed.connect(_on_continue_pressed)
	_illustration = TextureRect.new()
	_illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illustration.mouse_filter = Control.MOUSE_FILTER_STOP
	_illustration.gui_input.connect(_read_click)
	_illustration.custom_minimum_size = Vector2(360, 240)
	layout.add_child(_illustration)
	layout.move_child(_illustration, 2)
	var narrative := PanelContainer.new()
	narrative.name = "NarrativeBlock"
	narrative.mouse_filter = Control.MOUSE_FILTER_STOP
	narrative.gui_input.connect(_read_click)
	var narrative_index := _desc.get_index()
	layout.remove_child(_desc)
	layout.add_child(narrative)
	layout.move_child(narrative, narrative_index)
	var scene_row := HBoxContainer.new()
	scene_row.add_theme_constant_override("separation", 20)
	narrative.add_child(scene_row)
	layout.remove_child(_illustration)
	scene_row.add_child(_illustration)
	scene_row.add_child(_desc)
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(560, 76)
	_desc.mouse_filter = Control.MOUSE_FILTER_STOP
	_desc.gui_input.connect(_read_click)
	_card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_row.alignment = BoxContainer.ALIGNMENT_END
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "Skip →"
	_skip_button.tooltip_text = "ข้ามเหตุการณ์ · เข้าสู้มอนสเตอร์ประจำด่าน"
	add_child(_skip_button)
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_button.offset_left = -150
	_skip_button.offset_top = -56
	_skip_button.offset_right = -24
	_skip_button.offset_bottom = -14
	_skip_button.pressed.connect(_skip)
	_render()

func _clear_cards() -> void:
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()

func _render() -> void:
	UiAdaptive.refresh_scene.call_deferred(self)
	_clear_cards()
	var phase: String = GameState.journey.get("phase", "routes")
	_stats.text = "เดินทาง %d/%d · บอส %d/%d · ทอง %d" % [GameState.wave, Campaign.FINAL_WAVE,
		GameState.rewarded_bosses.size(), Campaign.BOSS_COUNT, GameState.gold]
	_stats.tooltip_text = preload("res://scripts/run_risk.gd").summary(GameState)
	if not GameState.run_modifiers.is_empty():
		_stats.text += " · ผลต่อเนื่อง %d" % GameState.run_modifiers.size()
	var effects: Label = _card_row.get_parent().get_node("ActiveConsequences")
	effects.tooltip_text = preload("res://scripts/run_risk.gd").summary(GameState)
	var effect_lines := effects.tooltip_text.split("\n")
	effects.text = "\n".join(effect_lines.slice(0, 2))
	if effect_lines.size() > 2:
		effects.text += "\nอีก %d ผลต่อเนื่อง · ชี้เพื่ออ่าน" % (effect_lines.size() - 2)
	effects.visible = not effects.text.is_empty()
	_continue_button.visible = phase == "result"
	_continue_button.disabled = false
	_continue_button.text = "ออกเดินทางต่อ →"
	_skip_button.visible = phase == "routes" and not GameState.is_boss_wave()
	_illustration.texture = _narrative_texture()
	_illustration.visible = phase != "routes" and _illustration.texture != null
	_desc.get_parent().get_parent().visible = phase != "routes"
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER if phase == "routes" else BoxContainer.ALIGNMENT_END
	if GameState.is_boss_wave():
		_render_boss()
		return
	match phase:
		"routes": _render_routes()
		"story": _render_story()
		"result":
			_title.text = "ผลการตัดสินใจ"
			_desc.text = GameState.journey.outcome
			_continue_button.text = "ไปจุดต่อสู้ →"
		"combat": _render_combat()

func _render_routes() -> void:
	_title.text = "เลือกเส้นทางของคุณ"
	_desc.text = ""
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	_card_row.add_child(row)
	for id in GameState.journey.offers:
		var data: Dictionary = Expedition.ENCOUNTERS[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(304, 420)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_top = 18
		content.offset_right = -12
		content.offset_bottom = -18
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_BEGIN
		content.add_theme_constant_override("separation", 12)
		var art := TextureRect.new()
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.texture = _event_texture(id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size = Vector2(0, 250)
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var teaser: String = data.get("teaser", "มีบางอย่างอยู่ข้างทาง")
		var clue: String = data.get("clue", "แสงกับเสียงจากทางนี้ชวนให้หยุดดู")
		for text in [teaser, clue]:
			var label := Label.new()
			label.text = text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 22 if text == teaser else 17)
			label.add_theme_color_override("font_color", Color(data.color))
			content.add_child(label)
		button.pressed.connect(func():
			if Expedition.select(GameState, id):
				Audio.play("click")
				_render())

func _render_story() -> void:
	var data: Dictionary = Expedition.ENCOUNTERS[GameState.journey.selected]
	_title.text = data.title
	_desc.text = data.story
	if not GameState.journey.get("stage", "").is_empty():
		_desc.text = GameState.journey.outcome
	if not GameState.journey.get("entered", false):
		_add_action("เข้าไปดู →", func():
			Expedition.enter(GameState)
			_render())
		_add_action("ถอยออกมา", func():
			Expedition.retreat(GameState)
			_render())
		return
	if GameState.journey.get("reading", true):
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	_card_row.add_child(grid)
	for action in Expedition.choices(GameState):
		var button := Button.new()
		button.custom_minimum_size = Vector2(476, 86)
		button.text = "%s\n%s" % [action.label, action.get("preview", "")]
		button.tooltip_text = ""
		button.add_theme_font_size_override("font_size", 20)
		button.disabled = not Expedition.available(GameState, action)
		if button.disabled:
			button.tooltip_text += "\n" + Expedition.blocked_reason(GameState, action)
		grid.add_child(button)
		button.pressed.connect(_choose.bind(action.id))

func _choose(id: String) -> void:
	if Expedition.resolve(GameState, id):
		Audio.play("click")
		_render()

func _render_boss() -> void:
	var enemy := Campaign.enemy(GameState.wave, GameState.next_monster_kind)
	_title.text = "จุดบอส %d/%d · %s" % [int(GameState.wave / Campaign.STAGES_PER_REGION), Campaign.BOSS_COUNT, enemy.formula]
	_desc.text = "%sขวางทาง คุณต้องเอาชนะเพื่อเดินทางต่อ\nอัลติ: %s · ชนะรับบัฟอัตโนมัติและเลือกบัฟเพิ่ม" % [enemy.name, enemy.ultimate]
	_continue_button.visible = false
	var art = preload("res://scripts/monster_art.gd").new()
	art.custom_minimum_size = Vector2(110, 130)
	art.kind = enemy.kind
	art.formula = enemy.formula
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_row.add_child(art)
	var fight := Button.new()
	fight.text = "ท้าบอส →"
	fight.custom_minimum_size.y = 52
	_card_row.add_child(fight)
	fight.pressed.connect(func():
		if GameState.journey.get("phase", "") == "boss":
			Expedition.resolve(GameState, "fight")
		_launch_battle())

func _render_combat() -> void:
	var enemy := GameState.encounter_enemy()
	_title.text = str(enemy.get("encounter", "เตรียมต่อสู้"))
	_desc.text = "คู่ต่อสู้ · %s · %s\nทีมพร้อม %d ชนิด" % [enemy.formula, enemy.name, GameState.fielded_formulas().size()]
	var fight := Button.new()
	fight.text = "เข้าต่อสู้ →"
	fight.custom_minimum_size.y = 64
	_card_row.add_child(fight)
	fight.pressed.connect(_launch_battle)

func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	_card_row.add_child(button)
	button.pressed.connect(callback)

func _read_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameState.journey.get("phase", "") == "result":
			_on_continue_pressed()
		elif GameState.journey.get("entered", false):
			_read_next()
		accept_event()

func _read_next() -> void:
	if GameState.journey.get("phase", "") != "story" or not GameState.journey.get("reading", false):
		return
	GameState.journey.reading = false
	GameState.save_game()
	_render()

func _skip() -> void:
	if preload("res://scripts/run_flow.gd").skip(GameState):
		_on_continue_pressed()

func _on_continue_pressed() -> void:
	if Expedition.followup(GameState):
		_render()

func _launch_battle() -> void:
	_navigate("res://scenes/Battle.tscn")

func _navigate(path: String) -> void:
	if _navigating:
		return
	_navigating = true
	Audio.play("click")
	Transition.change_scene(path)

func _event_texture(id: String) -> Texture2D:
	var artwork := {"deer_trail":"deer", "roots":"cache", "merchant":"wanderer", "trainer":"wanderer", "rescue":"wanderer", "funding":"wanderer", "camp":"wanderer", "ruins":"lab", "researcher":"lab", "reactor":"lab", "distiller":"lab", "vault":"cache"}
	var key: String = Expedition.ENCOUNTERS.get(id, {}).get("artwork", artwork.get(id,id))
	var path := "res://assets/events/%s.png" % key
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	var focus: Array = Expedition.ENCOUNTERS.get(id, {}).get("art_focus", [])
	if focus.size() == 4:
		var framed := AtlasTexture.new()
		framed.atlas = texture
		framed.region = Rect2(Vector2(focus[0], focus[1]) * texture.get_size(), Vector2(focus[2], focus[3]) * texture.get_size())
		return framed
	return texture

# Derive artwork from persisted choices, so dialogue and results survive reload.
func _narrative_texture() -> Texture2D:
	var id: String = GameState.journey.get("selected", "")
	var action: String = GameState.journey.get("choice", "")
	if action.is_empty():
		return _event_texture(id)
	var data: Dictionary = Expedition.ENCOUNTERS.get(id, {})
	if data.has("interaction_artwork"):
		var selected_action := Expedition.choice(id, action)
		if action in ["leave", "retreat"] or selected_action.get("artwork", "") == "departure":
			return load(preload("res://scripts/worlds.gd").region_for_wave(GameState.wave).prep_background)
		var interaction_path := "res://assets/events/%s.png" % data.interaction_artwork
		return load(interaction_path) if ResourceLoader.exists(interaction_path) else _event_texture(id)
	var variant: String
	if action in ["leave", "retreat", "stop2", "stop3", "answer"]:
		variant = "departure"
	else:
		var variants := {
			"mushrooms":"mushrooms_sample", "deer":"deer_feed", "deer_trail":"deer_feed",
			"wanderer":"wanderer_deal", "merchant":"wanderer_deal", "trainer":"wanderer_deal",
			"rescue":"wanderer_deal", "funding":"wanderer_deal", "camp":"wanderer_deal",
			"cache":"cache_open", "roots":"cache_open", "vault":"cache_open",
			"hollow":"hollow_inside", "rock":"rock_touch", "red_button":"red_button_pressed",
			"lab":"lab_active", "ruins":"lab_active", "researcher":"lab_active",
			"reactor":"lab_active", "distiller":"lab_active", "monster":"monster_alert"}
		variant = variants.get(id, "departure")
	var path := "res://assets/events/%s.png" % variant
	return load(path) if ResourceLoader.exists(path) else _event_texture(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]:
		if GameState.journey.get("phase", "") == "story" and GameState.journey.get("entered", false) and GameState.journey.get("reading", false):
			_read_next()
			get_viewport().set_input_as_handled()
