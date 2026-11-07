extends Control

## Reusable settings overlay. Instanced by Home and by the in-game pause menu,
## so the two can never drift apart.
##
## Starts hidden and is opened with `open()`. Swallows input while visible
## (mouse_filter STOP on the dimmer) so clicks cannot reach the screen behind.

signal closed

## Doubles as the in-game pause menu. `open(true)` shows a "back to the title"
## button and pauses the tree; the title screen calls plain `open()`.
const HOME_SCENE := "res://scenes/Home.tscn"

@onready var _menu_button: Button = %MenuButton
@onready var _dim: ColorRect = %Dim
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _reset_button: Button = %ResetButton
@onready var _close_button: Button = %CloseButton
@onready var _box: PanelContainer = %Box

## Reset wipes a whole run, so it is a two-click confirm rather than a dialog --
## a modal on top of a modal is worse, and this cannot be dismissed by accident.
var _reset_armed := false


var _pauses := false
var _ui_slider: HSlider
var _ui_value: Label


func _ready() -> void:
	visible = false
	# Must keep processing while the tree is paused, or the pause menu freezes
	# itself the moment it opens.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_slider.value = Audio.music_volume
	_sfx_slider.value = Audio.sfx_volume
	var rows := _box.get_node("Pad/Rows")
	var row := HBoxContainer.new()
	row.name = "UIScaleRow"
	row.add_theme_constant_override("separation", 12)
	rows.add_child(row)
	rows.move_child(row, 2)
	var credit := LinkButton.new()
	credit.text = "Heart art: Vecteezy.com"
	credit.uri = "https://www.vecteezy.com/"
	credit.add_theme_font_size_override("font_size", 14)
	rows.add_child(credit)
	var title := Label.new()
	title.text = "UI / HUD"
	title.custom_minimum_size.x = 110
	row.add_child(title)
	_ui_slider = HSlider.new()
	_ui_slider.name = "UIScaleSlider"
	_ui_slider.min_value = 80
	_ui_slider.max_value = 125
	_ui_slider.step = 5
	_ui_slider.value = UiAdaptive.ui_scale * 100
	_ui_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_slider.custom_minimum_size = Vector2(160, 48)
	row.add_child(_ui_slider)
	_ui_value = Label.new()
	_ui_value.custom_minimum_size.x = 64
	row.add_child(_ui_value)
	_ui_value.text = "%d%%" % _ui_slider.value
	_ui_slider.value_changed.connect(func(value: float): _ui_value.text = "%d%%" % value)
	_ui_slider.drag_ended.connect(func(_changed: bool): UiAdaptive.set_ui_scale(_ui_slider.value / 100.0))
	_ui_slider.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and not event.pressed: UiAdaptive.set_ui_scale(_ui_slider.value / 100.0))
	_refresh_labels()

	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(close)
	_menu_button.pressed.connect(_on_menu_pressed)


## `as_pause` shows the "back to the title" button and freezes the game behind
## the panel -- otherwise the battle keeps ticking while the player is adjusting
## the volume.
func open(as_pause := false) -> void:
	get_parent().move_child(self, -1)
	_ui_slider.set_value_no_signal(UiAdaptive.ui_scale * 100)
	_ui_value.text = "%d%%" % _ui_slider.value
	_disarm_reset()
	_pauses = as_pause
	_menu_button.visible = as_pause
	if as_pause:
		get_tree().paused = true
	visible = true
	_music_slider.value = Audio.music_volume
	_sfx_slider.value = Audio.sfx_volume
	_refresh_labels()

	# Scale-and-fade in. Pivot has to be set after the container has a size or
	# the panel grows out of its top-left corner.
	_dim.modulate.a = 0.0
	_box.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	_box.pivot_offset = _box.size * 0.5

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(_box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	Audio.play("click")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.15)
	tween.tween_property(_box, "scale", Vector2(0.92, 0.92), 0.15)
	await tween.finished
	visible = false
	if _pauses:
		get_tree().paused = false
		_pauses = false
	closed.emit()


func _on_menu_pressed() -> void:
	Audio.play("click")
	# Unpause BEFORE leaving. A paused tree stays paused across a scene change,
	# so the title screen would come up frozen.
	get_tree().paused = false
	_pauses = false
	visible = false
	Transition.change_scene(HOME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_music_changed(v: float) -> void:
	Audio.set_music_volume(v)
	_refresh_labels()


func _on_sfx_changed(v: float) -> void:
	Audio.set_sfx_volume(v)
	_refresh_labels()
	# Play a sample so the slider has immediate meaning -- a volume control you
	# cannot hear while dragging is guesswork.
	Audio.play("click")


func _refresh_labels() -> void:
	_music_value.text = "%d%%" % roundi(Audio.music_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(Audio.sfx_volume * 100.0)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "แน่ใจนะ? กดอีกครั้งเพื่อลบ"
		_reset_button.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
		return
	Audio.play("reject")
	GameState.reset_progress()
	_disarm_reset()
	# Wiping mid-run leaves battle.gd holding Fighter objects for a roster that
	# no longer exists -- the fight kept going and still paid out. Leaving to
	# the title is the only coherent thing to do next anyway.
	if _pauses:
		get_tree().paused = false
		_pauses = false
		visible = false
		Transition.change_scene(HOME_SCENE)
		return
	_reset_button.text = "ลบข้อมูลแล้ว เริ่มใหม่ได้เลย"


func _disarm_reset() -> void:
	_reset_armed = false
	_reset_button.text = "🗑 ลบข้อมูลแล้วเริ่มใหม่"
	_reset_button.remove_theme_color_override("font_color")
