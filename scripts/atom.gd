extends Control

## Draggable "atom" chip. Drop it overlapping other atoms to attempt a bond
## (see main.gd for the bonding check).

const Recipes := preload("res://scripts/recipes.gd")

signal drag_started(atom)
signal drag_ended(atom)

## Right-click. Handled by main.gd, which owns the gold.
signal sell_requested(atom)
signal selected(atom)

## Must match the Background panel's offsets in Atom.tscn -- the dots are drawn
## in the margin that inset creates.
const ATOM_INSET := 10.0
const DOT_RADIUS := 2.6
## Distance from the circle's edge out to a dot's centre.
const DOT_GAP := 6.0
## Half the distance between the two dots of a lone pair.
const PAIR_SPREAD := 5.0

@export var symbol: String = "H"

var _dragging := false
var _pressed := false
var _press_at := Vector2.ZERO
var _drag_offset := Vector2.ZERO

@onready var _bg: Panel = $Background
@onready var _label: Label = $Background/Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_symbol(symbol)

func set_symbol(s: String) -> void:
	symbol = s
	var info: Dictionary = Recipes.ELEMENTS.get(s, {"name": s, "color": Color.WHITE, "group": 0})
	_label.text = s

	var style := StyleBoxFlat.new()
	style.bg_color = info.color
	# Half the inset circle's width, so it stays a circle rather than a rounded
	# square now that the panel is 52px and not the full 72.
	var radius := int((72.0 - ATOM_INSET * 2.0) / 2.0)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 0.35)
	_bg.add_theme_stylebox_override("panel", style)

	var valence := Recipes.valence_of(s)
	var detail: String
	if valence < 0:
		# Fe and Cu. Saying "8 valence electrons" because iron sits in group 8
		# would be flatly wrong, so the atom says so instead of drawing dots.
		detail = "โลหะแทรนซิชัน — เวเลนซ์ไม่คงที่"
	elif Recipes.shell_is_full(s):
		detail = "เวเลนซ์อิเล็กตรอน %d — ครบแล้ว จึงไม่สร้างพันธะ" % valence
	else:
		detail = "เวเลนซ์อิเล็กตรอน %d" % valence
	tooltip_text = "%s — %s\n%s" % [s, info.get("thai", info.get("name", s)), detail]

	queue_redraw()


## Lewis dot structure: the notation students are actually taught. Electrons go
## one to each of the four sides first, then pair up -- which is why oxygen
## (6) draws two lone pairs plus two singles, and carbon (4) draws four singles.
##
## Nothing is drawn when valence_of() returns -1. That is the transition-metal
## case, where there is no single correct number; inventing one would teach
## chemistry that is false, which matters more here than a uniform look.
func _draw() -> void:
	var valence := Recipes.valence_of(symbol)
	if valence <= 0:
		return

	var info: Dictionary = Recipes.ELEMENTS.get(symbol, {})
	var dot_color: Color = info.get("color", Color.WHITE)
	# Carbon and the darker elements would vanish against the near-black board.
	if dot_color.get_luminance() < 0.45:
		dot_color = dot_color.lightened(0.5)

	var center := size * 0.5
	var ring := minf(size.x, size.y) * 0.5 - ATOM_INSET + DOT_GAP

	# Side order matters: top, right, bottom, left is the conventional fill order.
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var per_side := [0, 0, 0, 0]
	var total := mini(valence, 8)

	if Recipes.shell_is_full(symbol):
		# A full shell has no unpaired electrons, so its dots must be drawn as
		# pairs. This only bites helium: the one-per-side rule below gave it two
		# lone dots on separate sides, which reads as "two electrons free to
		# bond" -- the exact opposite of the truth, and a direct contradiction of
		# the game's own rejection message for noble gases.
		# A full octet lands on 4 pairs either way, so nothing else changes.
		for i in total:
			per_side[i / 2] += 1
	else:
		for i in total:
			per_side[i % 4] += 1

	for s in 4:
		var count: int = per_side[s]
		if count == 0:
			continue
		var dir: Vector2 = dirs[s]
		var perp := Vector2(-dir.y, dir.x)
		var base: Vector2 = center + dir * ring
		if count == 1:
			draw_circle(base, DOT_RADIUS, dot_color)
		else:
			draw_circle(base + perp * PAIR_SPREAD, DOT_RADIUS, dot_color)
			draw_circle(base - perp * PAIR_SPREAD, DOT_RADIUS, dot_color)

func _gui_input(event: InputEvent) -> void:
	# Right-click sells this atom back. Buying the wrong element used to be a
	# dead loss -- it sat on the board forever and the gold was gone -- which is
	# what turned experimenting into spending until broke.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		sell_requested.emit(self)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_at = get_global_mouse_position()
			_drag_offset = _press_at - global_position
			accept_event()
		elif _pressed:
			_pressed = false
			if _dragging:
				_dragging = false
				drag_ended.emit(self)
			else:
				selected.emit(self)
	elif event is InputEventMouseMotion and _pressed:
		if not _dragging and get_global_mouse_position().distance_to(_press_at) >= 12.0:
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			global_position = get_global_mouse_position() - _drag_offset

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
