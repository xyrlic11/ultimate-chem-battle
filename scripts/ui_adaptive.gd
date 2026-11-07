extends Node
## Presentation/input only. All game rules remain in the original controllers.
var _last_size := Vector2.ZERO
var _elapsed := 0.0
var _scene: Control
var _touch_scroll: ScrollContainer
var _touch_origin := Vector2.ZERO
var _scroll_origin := 0
var _touch_index := -1
var _touch_scrolling := false
var _ignore_mouse_release := false
var _hold_control: Control
var _hold_elapsed := 0.0
var _hold_tip: PanelContainer
var _hold_shown := false
var _mobile := false
var _window_size := Vector2i.ZERO
var ui_scale := 1.0
var _scale_path := "user://ui_preferences.cfg"
var _back_time := -1000

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _mobile:
		_open_back_settings()

func _open_back_settings() -> void:
	if Time.get_ticks_msec() - _back_time < 350: return
	_back_time = Time.get_ticks_msec()
	var scene := get_tree().current_scene
	if not is_instance_valid(scene): return
	var settings := scene.get_node_or_null("SettingsPanel")
	if settings != null and settings.visible:
		settings.close()
		return
	if scene.name == "Home":
		var existing := scene.get_node_or_null("ExitConfirmation")
		if existing != null: existing.queue_free()
		else: _show_exit_confirmation(scene)
		return
	if settings == null:
		settings = preload("res://scenes/SettingsPanel.tscn").instantiate()
		scene.add_child(settings)
		refresh_scene(scene)
	if settings.visible: settings.close()
	else: settings.open(scene.name != "Home")

func _show_exit_confirmation(scene: Control) -> void:
	var overlay := Control.new()
	overlay.name = "ExitConfirmation"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 220
	scene.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.8)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	center.add_child(panel)
	var padding := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: padding.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(padding)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	padding.add_child(column)
	var title := Label.new()
	title.text = "ต้องการออกจากเกมไหม?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	for answer in ["ไม่", "ใช่"]:
		var button := Button.new()
		button.name = "Cancel" if answer == "ไม่" else "Confirm"
		button.text = answer
		button.custom_minimum_size = Vector2(160, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		if answer == "ไม่": button.pressed.connect(overlay.queue_free)
		else: button.pressed.connect(func(): get_tree().quit())

func _stage_badge(scene: Control) -> void:
	if scene.name not in ["Main", "Event", "Battle"]: return
	var badge := scene.get_node_or_null("StageBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "StageBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.z_index = 10
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.07, 0.12, 0.92)
		style.set_corner_radius_all(8)
		badge.add_theme_stylebox_override("normal", style)
		badge.add_theme_font_size_override("font_size", 18)
		scene.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -106
		badge.offset_right = -12
		badge.offset_top = 8
		badge.offset_bottom = 42
	var stage: int = scene.battle_stage if scene.name == "Battle" else GameState.wave
	badge.text = "%d/%d" % [mini(stage, GameState.FINAL_WAVE), GameState.FINAL_WAVE]

func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.8, 1.25)
	_window_size = Vector2i.ZERO
	_configure_mobile_scale()
	var config := ConfigFile.new()
	config.set_value("display", "ui_scale", ui_scale)
	config.save(_scale_path)
	if is_instance_valid(_scene): refresh_scene.call_deferred(_scene)

func _configure_mobile_scale() -> void:
	var window := get_tree().root
	if window.size == _window_size: return
	_window_size = window.size
	# Use a logical canvas, not the phone's high-density hardware pixels.
	var aspect := float(window.size.x) / maxf(1.0, float(window.size.y))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var height := (540.0 if _mobile else float(window.size.y)) / ui_scale
	window.content_scale_size = Vector2i(roundi(height * aspect), roundi(height))
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _touch_target(control) -> void:
	if not is_instance_valid(control): return
	if control is Button:
		control.custom_minimum_size.y = maxf(60, control.custom_minimum_size.y)
		if control.get_parent() is GridContainer and control.get_parent().name == "ElementGrid":
			control.custom_minimum_size = Vector2(132, 108)
		control.add_theme_font_size_override("font_size", maxi(20, control.get_theme_font_size("font_size")))
	elif control is Label:
		if control.has_meta("small_caption"): return
		control.add_theme_font_size_override("font_size", maxi(16, control.get_theme_font_size("font_size")))
func _clear_hold() -> void:
	_hold_control = null
	_hold_elapsed = 0.0
	if is_instance_valid(_hold_tip): _hold_tip.queue_free()
	_hold_tip = null
func _find_tip_at(point: Vector2) -> Control:
	var best: Control
	var area := INF
	for control in _scene.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and not control.tooltip_text.is_empty() and control.get_global_rect().has_point(point):
			var candidate: float = control.size.x * control.size.y
			if candidate <= area:
				best = control
				area = candidate
	return best
func _show_hold_tip() -> void:
	_hold_shown = true
	_ignore_mouse_release = true
	if _hold_control is BaseButton: _hold_control.set_pressed_no_signal(false)
	_hold_tip = PanelContainer.new()
	_hold_tip.z_index = 200
	_hold_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = _hold_control.tooltip_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(360, _last_size.x - 48)
	label.add_theme_font_size_override("font_size", 18)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 12)
	margin.add_child(label)
	_hold_tip.add_child(margin)
	_scene.add_child(_hold_tip)
	_hold_tip.position = Vector2(16, 54)
func _input(event: InputEvent) -> void:
	if _ignore_mouse_release and event is InputEventMouseButton and event.device == -1:
		get_viewport().set_input_as_handled()
		if not event.pressed: _ignore_mouse_release = false
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if _dismiss_outside(event.position):
			_clear_hold()
			_ignore_mouse_release = true
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			_clear_hold()
			_hold_shown = false
			_touch_scroll = null
			_touch_index = event.index
			_touch_origin = event.position
			_touch_scrolling = false
			_ignore_mouse_release = false
			if not is_instance_valid(_scene): return
			_hold_control = _find_tip_at(event.position)
			for scroll in _scene.find_children("*", "ScrollContainer", true, false):
				if scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(event.position):
					var bar: VScrollBar = scroll.get_v_scroll_bar()
					if bar.max_value > bar.page:
						_touch_scroll = scroll
						_scroll_origin = scroll.scroll_vertical
			# A tile in the selected scroller keeps its formation drag. Tiles behind
			# modal windows do not disable scrolling of the foreground window.
			if is_instance_valid(_touch_scroll):
				for slider in _touch_scroll.find_children("*", "Slider", true, false):
					if slider.is_visible_in_tree() and slider.get_global_rect().grow(8).has_point(event.position):
						_touch_scroll = null
						return
				for tile in get_tree().get_nodes_in_group("molecules") + get_tree().get_nodes_in_group("atoms"):
					if tile is Control and _touch_scroll.is_ancestor_of(tile) and tile.is_visible_in_tree() and tile.get_global_rect().has_point(event.position):
						_touch_scroll = null
						return
		elif event.index == _touch_index:
			if _hold_shown:
				get_viewport().set_input_as_handled()
				_ignore_mouse_release = true
			_clear_hold()
			if _touch_scrolling:
				get_viewport().set_input_as_handled()
			_touch_scroll = null
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		if event.position.distance_to(_touch_origin) >= 12: _clear_hold()
		if not is_instance_valid(_touch_scroll): return
		if event.position.distance_to(_touch_origin) >= 12 or _touch_scrolling:
			_touch_scrolling = true
			_ignore_mouse_release = true
			_touch_scroll.scroll_vertical = _scroll_origin - roundi(event.position.y-_touch_origin.y)
			get_viewport().set_input_as_handled()
			for button in _touch_scroll.find_children("*", "BaseButton", true, false): button.set_pressed_no_signal(false)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _ignore_mouse_release:
		get_viewport().set_input_as_handled()
		_ignore_mouse_release = false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mobile = OS.has_feature("android") or OS.has_feature("ios") or "--mobile-ui" in OS.get_cmdline_user_args()
	if _mobile: get_tree().quit_on_go_back = false
	if "--test" in OS.get_cmdline_user_args(): _scale_path = "user://ui_preferences_test.cfg"
	var config := ConfigFile.new()
	if config.load(_scale_path) == OK:
		ui_scale = clampf(float(config.get_value("display", "ui_scale", 1.0)), 0.8, 1.25)
	_configure_mobile_scale()
	get_tree().node_added.connect(_added)
func _added(node: Node) -> void:
	if _mobile and node is Control: _touch_target.call_deferred(node)
	if node is Control and node.name in ["Home", "Main", "Battle", "Event"]:
		refresh_scene.call_deferred(node)
func _process(delta: float) -> void:
	_configure_mobile_scale()
	if is_instance_valid(_hold_control) and not _hold_shown:
		_hold_elapsed += delta
		if _hold_elapsed >= 0.55: _show_hold_tip()
	_elapsed += delta
	if _elapsed < 0.2: return
	_elapsed = 0
	if is_instance_valid(_scene): _stage_badge(_scene)
	var current := get_tree().current_scene
	if current is Control and current != _scene:
		refresh_scene(current)
	var bounds := get_viewport().get_visible_rect().size
	if bounds != _last_size and is_instance_valid(_scene):
		refresh_scene(_scene)
	if is_instance_valid(_scene) and _scene.name == "Main" and _scene.has_meta("mobile_nav"):
		var nav: HBoxContainer = _scene.get_meta("mobile_nav")
		var source: Button = _scene.get_node("Margins/Root/SidePanel/BattleRow/BattleButton")
		var fight: Button = nav.get_node("Fight")
		fight.disabled = source.disabled
		fight.text = source.text
func refresh_scene(scene) -> void:
	if not is_instance_valid(scene) or not scene.is_inside_tree(): return
	_scene = scene
	_last_size = get_viewport().get_visible_rect().size
	var compact := _mobile or _last_size.x < 1100 or _last_size.y < 600
	var banner: Control = scene.get_node_or_null("RegionBanner")
	if banner:
		banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		banner.offset_left = maxf(16, (_last_size.x-600)/2)
		banner.offset_right = -banner.offset_left
		banner.offset_top = 8
		banner.offset_bottom = 48
	match str(scene.name):
		"Event": _event(scene, compact)
		"Main": _main(scene, compact)
		"Battle": _battle(scene, compact)
		"Home":
			var center: Control = scene.get_node("Center")
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			center.offset_left = maxf(20, (_last_size.x-460)/2)
			center.offset_right = -center.offset_left
			center.offset_top = 8
			center.offset_bottom = -36
			scene.get_node("Center/Title").add_theme_font_size_override("font_size", 28 if compact else 52)
			scene.get_node("Center/Gap").custom_minimum_size.y = 0 if compact else 26
			scene.get_node("Center/Buttons/QuitButton").visible = not OS.has_feature("web") and not compact
	_fit_popups(scene, compact)
	if _mobile:
		for control in scene.find_children("*", "Control", true, false): _touch_target(control)
func _event(scene, compact: bool) -> void:
	var box: PanelContainer = scene.get_node("Center/Box") if not scene.has_meta("event_scroll") else scene.get_meta("event_box")
	if not scene.has_meta("event_scroll"):
		var center: Control = scene.get_node("Center")
		var scroll := ScrollContainer.new()
		center.remove_child(box)
		center.add_child(scroll)
		scroll.add_child(box)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scene.set_meta("event_scroll", scroll)
		scene.set_meta("event_box", box)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.offset_left = 16
		center.offset_right = -16
		center.offset_top = 54
		center.offset_bottom = -64
	box.custom_minimum_size = Vector2(minf(1100, _last_size.x-32), 0 if compact else minf(620,_last_size.y-118))
	var event_scroll: ScrollContainer = scene.get_meta("event_scroll")
	event_scroll.custom_minimum_size = Vector2(_last_size.x-32,maxf(120,_last_size.y-118))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout: VBoxContainer = scene._card_row.get_parent()
	layout.add_theme_constant_override("separation", 6 if compact else 8)
	scene._title.add_theme_font_size_override("font_size",22 if compact else 28)
	scene._desc.custom_minimum_size = Vector2(0, 60)
	scene._illustration.custom_minimum_size = Vector2(220 if compact else 360,130 if compact else 240)
	var columns := maxi(1, scene._card_row.get_child_count())
	if scene._card_row.get_child_count() > 0 and scene._card_row.get_child(0) is HBoxContainer:
		var row: HBoxContainer = scene._card_row.get_child(0)
		columns = row.get_child_count()
		row.add_theme_constant_override("separation", 10 if compact else 18)
		for card in row.get_children():
			card.custom_minimum_size = Vector2((_last_size.x-70)/maxi(columns,1)-12,240 if compact else 420)
			var content = card.get_child(0)
			content.offset_top = 10
			content.offset_bottom = -10
			content.get_child(0).custom_minimum_size.y = 115 if compact else 250
			for label in content.get_children():
				if label is Label:
					label.add_theme_font_size_override("font_size",16 if compact else 20)
	elif scene._card_row.get_child_count() > 0 and scene._card_row.get_child(0) is GridContainer:
		var grid: GridContainer = scene._card_row.get_child(0)
		for button in grid.get_children():
			button.custom_minimum_size = Vector2((_last_size.x-80)/2,68 if compact else 86)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size",17 if compact else 20)
func _main(scene, compact: bool) -> void:
	var team: Control = scene.get_node("Margins/Root/TeamPanel")
	var side: Control = scene.get_node("Margins/Root/SidePanel")
	if not scene.has_meta("mobile_nav"):
		var nav := HBoxContainer.new()
		scene.add_child(nav)
		nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		nav.offset_left = 16
		nav.offset_right = -16
		nav.offset_top = -60
		nav.offset_bottom = -12
		nav.add_theme_constant_override("separation",8)
		for item in [["ร้าน", "Shop"],["ทีม", "Team"],["สูตร", "Recipes"],["สายพลัง", "Traits"],["เดินทาง", "Fight"]]:
			var b := Button.new()
			b.name = item[1]
			b.text = item[0]
			b.custom_minimum_size.y = 48
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav.add_child(b)
			b.pressed.connect(_nav.bind(scene,item[1]))
		scene.set_meta("mobile_nav",nav)
	var nav: HBoxContainer = scene.get_meta("mobile_nav")
	if _mobile:
		nav.offset_top = -76
		for button in nav.get_children(): _touch_target(button)
		scene.get_node("Margins").add_theme_constant_override("margin_bottom",88)
	nav.visible = compact
	team.visible = not compact
	side.visible = not compact
	scene.get_node("Margins").add_theme_constant_override("margin_top",54 if compact else 66)
	# Drawers retain the original panels/controllers and still accept formation drops.
	if compact:
		for panel in [team, side]:
			panel.custom_minimum_size.x = 270
	else:
		for panel in [team, side]: panel.custom_minimum_size.x = 280
	if scene.has_meta("mobile_drawer"):
		var drawer: Control = scene.get_meta("mobile_drawer")
		drawer.visible = false
func _nav(scene: Control, key: String) -> void:
	match key:
		"Settings": scene.get_node("%SettingsPanel").open(true)
		"Shop": scene._toggle_shop()
		"Recipes": scene._toggle_book()
		"Fight": scene._battle_button.pressed.emit()
		"Team", "Traits":
			var panel: Control = scene.get_node("Margins/Root/TeamPanel" if key == "Team" else "Margins/Root/SidePanel")
			panel.visible = not panel.visible
			var other: Control = scene.get_node("Margins/Root/SidePanel" if key == "Team" else "Margins/Root/TeamPanel")
			other.visible = false
func _battle(scene, compact: bool) -> void:
	scene.get_node("Margins").add_theme_constant_override("margin_top",12)
	scene.get_node("Margins").add_theme_constant_override("margin_bottom",16)
	var log: Control = scene.get_node("Margins/Root/LogScroll")
	log.visible = not compact
	scene.get_node("Margins/Root").add_theme_constant_override("separation", 4 if compact else 10)
	scene.get_node("Margins/Root/TraitBar").visible = not compact
	scene.get_node("Margins/Root/TurnQueue").custom_minimum_size.y = 20 if compact else 26
	var art: Control = scene.get_node("Margins/Root/Field/MonsterSide/MonsterArt")
	art.custom_minimum_size.y = 80 if compact else 150
	for path in ["Margins/Root/Field/TeamSide/FrontScroll","Margins/Root/Field/TeamSide/BackScroll"]:
		scene.get_node(path).custom_minimum_size.y = 80 if compact else 120
		if compact:
			for chip in scene.get_node(path).get_child(0).get_children():
				if chip is PanelContainer:
					chip.custom_minimum_size.y = 76
					for child in chip.find_children("*", "Control", true, false):
						if child.custom_minimum_size.y == 54: child.custom_minimum_size.y = 34
						if child is Label: child.add_theme_font_size_override("font_size",12)
	var bar: Control = scene.get_node("Margins/Root/ActionBar")
	for child in bar.find_children("*","Button",true,false): child.custom_minimum_size.y = 48
	if compact:
		for child in bar.find_children("*","Button",true,false): child.add_theme_font_size_override("font_size",15)
func _fit_popups(root: Node, compact: bool) -> void:
	for settings in root.find_children("SettingsPanel", "Control", true, false):
		settings.z_index = 100
		if compact and not settings.has_meta("adaptive_scroll"):
			var box: Control = settings.get_node("Center/Box")
			var center: Control = settings.get_node("Center")
			center.remove_child(box)
			var scroll := ScrollContainer.new()
			center.add_child(scroll)
			scroll.custom_minimum_size = Vector2(minf(500,_last_size.x-32),maxf(200,_last_size.y-32))
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.add_child(box)
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			settings.set_meta("adaptive_scroll",scroll)
		if settings.has_meta("adaptive_scroll"):
			var scroll: ScrollContainer = settings.get_meta("adaptive_scroll")
			scroll.custom_minimum_size = Vector2(minf(520, _last_size.x-64), maxf(160, _last_size.y-48))
	for panel in root.find_children("*","PanelContainer",true,false):
		if panel.name == "CoachBubble":
			panel.offset_top = 64 if compact else 22
			panel.offset_bottom = 118 if compact else 76
			continue
		if panel.name == "BattleCoach":
			panel.offset_top = 54
			panel.offset_bottom = 110
			continue
		if panel.get_parent() is Control and not panel.get_parent() is Container and panel.anchor_left == 0.5 and panel.anchor_right == 0.5:
			# Modal content must remain above the mobile navigation, including Close.
			panel.get_parent().z_index = 20
			# GUI hit testing follows tree order, not CanvasItem z_index.
			var modal := panel.get_parent()
			modal.get_parent().move_child(modal, -1)
			var width := minf(_last_size.x-64, 540.0 if compact or panel.get_parent().name == "ShopPopup" else 720.0)
			panel.offset_left = -width/2
			panel.offset_right = width/2
			panel.anchor_top = 0.5
			panel.anchor_bottom = 0.5
			panel.offset_top = -minf(_last_size.y-32,560)/2
			panel.offset_bottom = -panel.offset_top
			if compact and panel.get_child_count() == 1 and panel.get_child(0) is VBoxContainer:
				var col: Control = panel.get_child(0)
				var scroll := ScrollContainer.new()
				panel.remove_child(col)
				panel.add_child(scroll)
				scroll.add_child(col)
				scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
				scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				for nested in col.find_children("*", "ScrollContainer", true, false):
					if nested.get_child_count() == 0: continue
					# One vertical scroll owner: avoid nested scissor/scroll surfaces on WebKit.
					nested.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
					nested.clip_contents = false
					nested.custom_minimum_size.y = maxf(80 if nested.name == "ProfileBodyScroll" else 200,nested.get_child(0).get_combined_minimum_size().y)
				for button in col.find_children("*", "Button", true, false):
					button.custom_minimum_size.y = maxf(48, button.custom_minimum_size.y)

func _dismiss_outside(point: Vector2) -> bool:
	if not is_instance_valid(_scene): return false
	# Only optional overlays can be dismissed; event choices and battle results cannot.
	var overlays := _scene.find_children("*", "Control", true, false)
	overlays.reverse()
	for overlay in overlays:
		if not overlay.is_visible_in_tree(): continue
		if overlay.has_meta("dismiss_panel"):
			var panel: Control = overlay.get_meta("dismiss_panel")
			if panel.get_global_rect().has_point(point): return false
			overlay.queue_free()
			return true
		if overlay.name == "SettingsPanel":
			if not overlay._box.get_global_rect().has_point(point):
				overlay.close()
				return true
			return false
		if overlay.name in ["ShopPopup", "RecipeBook"]:
			var box: Control = overlay.get_node("Box")
			if box.get_global_rect().has_point(point): return false
			if overlay.name == "ShopPopup": _scene._close_shop()
			else: _scene._close_book()
			return true
	return false
