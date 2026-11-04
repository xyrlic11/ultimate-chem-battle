extends Control

## Drifting atoms behind the title.
##
## Reuses the game's own visual language rather than inventing title art: these
## are the same coloured circles with element symbols the player will be
## dragging thirty seconds later, so the menu already teaches what the game
## looks like. Colours come from Recipes.ELEMENTS, so adding an element to the
## table adds it to the title screen for free.

const Recipes := preload("res://scripts/recipes.gd")

const COUNT := 14
const MIN_RADIUS := 16.0
const MAX_RADIUS := 34.0

class Drifter:
	var pos: Vector2
	var vel: Vector2
	var radius: float
	var color: Color
	var symbol: String
	var spin: float
	var phase: float

var _drifters: Array[Drifter] = []
var _font: Font
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var symbols := Recipes.ELEMENTS.keys()

	for i in COUNT:
		var d := Drifter.new()
		var symbol: String = symbols[i % symbols.size()]
		d.symbol = symbol
		d.color = Recipes.ELEMENTS[symbol].color
		d.radius = randf_range(MIN_RADIUS, MAX_RADIUS)
		d.pos = Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0))
		# Slow enough to read as ambient rather than as something to track.
		d.vel = Vector2(randf_range(-16.0, 16.0), randf_range(-11.0, 11.0))
		d.spin = randf_range(-0.5, 0.5)
		d.phase = randf_range(0.0, TAU)
		_drifters.append(d)


func _process(delta: float) -> void:
	_time += delta
	var bounds := size
	for d in _drifters:
		d.pos += d.vel * delta
		# Wrap with a margin equal to the radius so an atom slides off one edge
		# and back on the other without ever popping.
		if d.pos.x < -d.radius:
			d.pos.x = bounds.x + d.radius
		elif d.pos.x > bounds.x + d.radius:
			d.pos.x = -d.radius
		if d.pos.y < -d.radius:
			d.pos.y = bounds.y + d.radius
		elif d.pos.y > bounds.y + d.radius:
			d.pos.y = -d.radius
	queue_redraw()


## Radial clear zone around the middle of the screen. Without it an atom drifts
## straight through the title or a menu button and the text becomes hard to
## read -- the drifters are atmosphere and must lose every contrast fight with
## the UI. Fading by distance keeps that automatic instead of hand-placing them.
const CLEAR_RADIUS := 300.0
const FULL_RADIUS := 470.0


func _centre_fade(p: Vector2) -> float:
	var d := p.distance_to(size * 0.5)
	return smoothstep(CLEAR_RADIUS, FULL_RADIUS, d)


func _draw() -> void:
	for d in _drifters:
		var fade := _centre_fade(d.pos)
		if fade <= 0.01:
			continue

		# Faint even at full strength: this sits behind the title and the menu.
		var breathe := 1.0 + sin(_time * 0.9 + d.phase) * 0.05
		var r := d.radius * breathe
		draw_circle(d.pos, r, Color(d.color.r, d.color.g, d.color.b, 0.10 * fade))
		draw_arc(d.pos, r, 0.0, TAU, 32, Color(d.color.r, d.color.g, d.color.b, 0.22 * fade), 2.0, true)

		var fs := int(r * 0.8)
		var text_size := _font.get_string_size(d.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(_font, d.pos + Vector2(-text_size.x * 0.5, text_size.y * 0.32),
			d.symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(d.color.r, d.color.g, d.color.b, 0.28 * fade))
