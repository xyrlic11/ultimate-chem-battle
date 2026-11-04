extends Control

## Title screen. The game used to boot straight into the shop, which gave the
## player no idea what they had opened.
##
## "เล่นต่อ" only appears when there is actually a run to resume -- an always-on
## continue button that silently starts a fresh game is worse than no button.

const SHOP_SCENE := "res://scenes/Main.tscn"

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _buttons: VBoxContainer = %Buttons
@onready var _continue_button: Button = %ContinueButton
@onready var _new_button: Button = %NewButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_panel: Control = %SettingsPanel
@onready var _save_info: Label = %SaveInfo


func _ready() -> void:
	Audio.play_music("home")

	_new_button.pressed.connect(_on_new_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# reset_progress() clears the roster, so the continue button has to
	# disappear the moment the player wipes their save from the settings panel.
	GameState.progress_reset.connect(_refresh_continue)
	_refresh_continue()

	for b in [_continue_button, _new_button, _settings_button, _quit_button]:
		b.mouse_entered.connect(func(): Audio.play("click", 0.12))

	_animate_in()


func _refresh_continue() -> void:
	var has_run: bool = not GameState.roster.is_empty() or GameState.wave > 1
	_continue_button.visible = has_run
	if has_run:
		_save_info.text = "ด่านที่ %d · 💰%d · สารประกอบ %d ชนิด" % [
			GameState.wave, GameState.gold, GameState.roster.size()
		]
	_save_info.visible = has_run


## Title drops in, then the buttons stagger up behind it. Costs nothing and is
## the difference between "a menu" and "a game".
func _animate_in() -> void:
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_title.position.y -= 24.0

	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(_title, "position:y", _title.position.y + 24.0, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.35)

	for i in _buttons.get_child_count():
		var child: Control = _buttons.get_child(i)
		if not child.visible:
			continue
		child.modulate.a = 0.0
		var slide := create_tween()
		slide.tween_interval(0.45 + float(i) * 0.07)
		slide.tween_property(child, "modulate:a", 1.0, 0.28)


func _on_new_pressed() -> void:
	Audio.play("buy")
	# Starting a new run from the title has to actually start a new run;
	# leaving the old save in place made "เริ่มเกมใหม่" a lie.
	GameState.reset_progress()
	preload("res://scripts/run_flow.gd").begin(GameState)
	Transition.change_scene("res://scenes/Battle.tscn")


func _on_continue_pressed() -> void:
	Audio.play("buy")
	Transition.change_scene("res://scenes/Battle.tscn" if GameState.journey.get("phase", "") == "combat" else SHOP_SCENE)


func _on_settings_pressed() -> void:
	Audio.play("click")
	_settings_panel.open()


func _on_quit_pressed() -> void:
	Audio.play("click")
	Transition.fade_out_and_quit()
