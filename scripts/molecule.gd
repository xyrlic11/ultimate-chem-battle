extends Control

## A bonded compound sitting on the board.
##
## Draggable, like an atom: dropping one onto another attempts a TIER-2
## reaction (see Recipes.TIER2_RECIPES). It used to delete itself on a single
## left-click, which is now right-click -- a left-click that destroys the thing
## you just spent two atoms making is a trap once dragging is the main verb.

signal removed(molecule)
signal drag_started(molecule)
signal drag_ended(molecule)
signal selected(molecule)

const Recipes := preload("res://scripts/recipes.gd")
const UnitAbilities := preload("res://scripts/unit_abilities.gd")
const CompoundArt := preload("res://scripts/compound_art.gd")

var formula: String = ""
var tier: int = 1

var _dragging := false
var _drag_offset := Vector2.ZERO
var _pressed := false
var _press_at := Vector2.ZERO

@onready var _bg: Panel = $Background
@onready var _label: Label = $Background/Text/Label
@onready var _role_label: Label = $Background/Text/RoleLabel


func setup(compound_formula: String, display_name: String, thai: String,
		kind: String, compound_tier := 1) -> void:
	formula = compound_formula
	tier = compound_tier
	_label.text = compound_formula
	_role_label.text = UnitAbilities.role_label(compound_formula)
	var art := get_node_or_null("Art")
	if art == null:
		art = CompoundArt.new()
		art.name = "Art"
		add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		art.offset_bottom = 62
	art.setup(compound_formula, compound_tier)
	if get_node_or_null("ConditionBar") == null:
		var condition = preload("res://scripts/unit_condition_bar.gd").new()
		condition.name = "ConditionBar"
		condition.formula = compound_formula
		add_child(condition)
		condition.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		condition.offset_left = 12
		condition.offset_right = -12
		condition.offset_top = -5

	# Let the creature silhouette, not another rectangular card, own the tile.
	_bg.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var hint := "คลิกเพื่อดูรายละเอียด · ลากเพื่อจัดทีม/ผสม\nคลิกขวาเพื่อขาย (ถามยืนยันก่อน)"
	var ability_hint := UnitAbilities.tooltip(compound_formula)
	ability_hint += "\n" + preload("res://scripts/attack_styles.gd").label(compound_formula)
	tooltip_text = "%s (%s)\n%s%s" % [
		display_name, thai,
		"%s\n" % ability_hint if ability_hint != "" else "",
		hint,
	]


func pop_in() -> void:
	scale = Vector2(0.2, 0.2)
	pivot_offset = size / 2.0
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35)


func flash(color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", color, 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)


func shake() -> void:
	var start_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", start_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", start_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(self, "position", start_pos + Vector2(6, 0), 0.05)
	tween.tween_property(self, "position", start_pos, 0.05)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		removed.emit(self)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_at = get_global_mouse_position()
			_drag_offset = get_global_mouse_position() - global_position
			get_viewport().set_input_as_handled()
		elif _pressed:
			_pressed = false
			if not _dragging:
				selected.emit(self)
				return
			_dragging = false
			drag_ended.emit(self)
	elif event is InputEventMouseMotion and _pressed:
		if not _dragging and get_global_mouse_position().distance_to(_press_at) >= 12.0:
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			global_position = get_global_mouse_position() - _drag_offset
