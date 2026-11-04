extends Control

## Fantasy arena backdrop for the battle screen, drawn rather than shipped.
##
## THE ALCHEMY CIRCLE IS THE POINT. It reads as a fantasy summoning ring and as
## a real alchemical diagram at the same time, which is exactly where this game
## sits: a chemistry lesson wearing an auto-battler. It is the one motif that
## belongs to both halves, rather than a fantasy skin bolted onto a science
## game.
##
## EVERYTHING HERE LOSES THE CONTRAST FIGHT ON PURPOSE. The battle log is drawn
## straight onto this background with no panel behind it, so every alpha below
## is deliberately low and the vignette darkens the lower third where that text
## sits. A prettier backdrop that cost legibility would be a downgrade.
##
## TWO LAYERS, ONE SCRIPT. The sky gradient, the ridges, the ground and the
## vignette are about 110 draw calls that never change, and re-emitting them 60
## times a second made this the most expensive thing in the project for no
## reason. Godot keeps a node's draw list until queue_redraw() is called, so
## the static half now redraws only on resize.
##
## The animated half (sigil, braziers, embers) lives in a child created in
## _ready() carrying this same script with `animated = true`. A child draws
## AFTER its parent, which is exactly the ordering wanted: motion on top of
## scenery. Keeping it in one file avoids a second script whose constants would
## have to be kept in sync with these.

const SKY_TOP := Color(0.045, 0.035, 0.085)
const SKY_BOTTOM := Color(0.13, 0.075, 0.135)
const RIDGE_FAR := Color(0.085, 0.075, 0.155)
const RIDGE_NEAR := Color(0.055, 0.045, 0.10)
const GROUND := Color(0.075, 0.055, 0.095)
const RUNE := Color(0.55, 0.78, 1.0)
const EMBER := Color(1.0, 0.72, 0.38)
const BRAZIER := Color(1.0, 0.62, 0.28)

const SKY_BANDS := 44
const EMBER_COUNT := 26
const VIGNETTE_STEPS := 16

class Ember:
	var pos: Vector2
	var speed: float
	var radius: float
	var phase: float
	var drift: float

## false = the static scenery layer (the node placed in Battle.tscn).
## true  = the moving layer, a child this script creates for itself.
@export var animated := false
## When generated region art sits underneath, keep only the animated alchemy
## sigil/braziers/embers and do not repaint an opaque procedural landscape.
@export var overlay_only := false

var _embers: Array[Ember] = []
var _time := 0.0
## Skyline offsets, generated once from a fixed seed. Regenerating per frame
## would make the mountains crawl.
var _far_seed: Array[float] = []
var _near_seed: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if animated:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		for i in EMBER_COUNT:
			var e := Ember.new()
			e.pos = Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0))
			e.speed = rng.randf_range(12.0, 34.0)
			e.radius = rng.randf_range(1.0, 2.6)
			e.phase = rng.randf_range(0.0, TAU)
			e.drift = rng.randf_range(6.0, 18.0)
			_embers.append(e)
		return

	# Static layer: build the skyline once, then stop processing entirely.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 20260810
	for i in 13:
		_far_seed.append(rng2.randf_range(0.35, 1.0))
	for i in 11:
		_near_seed.append(rng2.randf_range(0.4, 1.0))
	set_process(false)

	var moving := Control.new()
	moving.set_script(get_script())
	moving.animated = true
	moving.set_anchors_preset(Control.PRESET_FULL_RECT)
	moving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(moving)


func _process(delta: float) -> void:
	# Only the animated child ever reaches here; the static layer disabled
	# processing in _ready().
	_time += delta
	for e in _embers:
		e.pos.y -= e.speed * delta
		e.pos.x += sin(_time * 0.7 + e.phase) * e.drift * delta
		if e.pos.y < -8.0:
			e.pos.y = size.y + 8.0
			# Ambient animation must not change combat rolls when x1 runs longer.
			e.pos.x = fmod(absf(e.phase * 137.0 + e.pos.x + 71.0), maxf(size.x, 1.0))
	queue_redraw()


func _notification(what: int) -> void:
	# The static layer holds its draw list until the window changes shape.
	if what == NOTIFICATION_RESIZED and not animated:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var horizon := h * 0.50

	if animated:
		_draw_sigil(Vector2(w * 0.5, h * 0.52), minf(w, h) * 0.36)
		_draw_brazier(Vector2(w * 0.09, horizon + h * 0.04))
		_draw_brazier(Vector2(w * 0.91, horizon + h * 0.04))
		_draw_embers()
		return
	if overlay_only:
		return

	_draw_sky(w, horizon)
	_draw_ridge(w, horizon, h * 0.10, _far_seed, RIDGE_FAR)
	_draw_ridge(w, horizon + h * 0.05, h * 0.13, _near_seed, RIDGE_NEAR)
	draw_rect(Rect2(0.0, horizon + h * 0.05, w, h), GROUND)
	_draw_vignette(w, h)


## Banded rather than a shader: gl_compatibility is the pinned renderer, and now
## that this runs once instead of every frame the band count costs nothing.
func _draw_sky(w: float, horizon: float) -> void:
	var band := horizon / float(SKY_BANDS)
	for i in SKY_BANDS:
		var t := float(i) / float(SKY_BANDS - 1)
		draw_rect(Rect2(0.0, float(i) * band, w, band + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))


func _draw_ridge(w: float, base_y: float, height: float, seed_values: Array[float],
		color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0.0, base_y + height))
	var count := seed_values.size()
	for i in count:
		points.append(Vector2(w * float(i) / float(count - 1),
			base_y - seed_values[i] * height))
	points.append(Vector2(w, base_y + height))
	draw_colored_polygon(points, color)


## Two concentric rings, a hexagram and twelve rune ticks, turning slowly in
## opposite directions.
func _draw_sigil(centre: Vector2, radius: float) -> void:
	var spin := _time * 0.07
	var faint := Color(RUNE.r, RUNE.g, RUNE.b, 0.10)
	var fainter := Color(RUNE.r, RUNE.g, RUNE.b, 0.06)

	draw_arc(centre, radius, 0.0, TAU, 96, faint, 1.6, true)
	draw_arc(centre, radius * 0.82, 0.0, TAU, 96, fainter, 1.2, true)
	draw_arc(centre, radius * 0.34, 0.0, TAU, 64, fainter, 1.2, true)

	for tri in 2:
		var offset := spin * (1.0 if tri == 0 else -1.0) + (PI if tri == 1 else 0.0)
		var pts := PackedVector2Array()
		for i in 3:
			var a := offset + TAU * float(i) / 3.0
			pts.append(centre + Vector2(cos(a), sin(a)) * radius * 0.82)
		pts.append(pts[0])
		draw_polyline(pts, faint, 1.4, true)

	for i in 12:
		var a := -spin + TAU * float(i) / 12.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(centre + dir * radius * 0.88, centre + dir * radius * 0.97, faint, 1.4, true)


## No solid base. The fighter rows sit right on top of these, and an opaque
## rectangle behind a chip reads as a stray box rather than as scenery. Pure
## light cannot be mistaken for an object.
func _draw_brazier(base: Vector2) -> void:
	var flicker := 0.75 + 0.25 * sin(_time * 7.3 + base.x)
	for i in 5:
		var r := (34.0 - float(i) * 5.0) * flicker
		draw_circle(base, r, Color(BRAZIER.r, BRAZIER.g, BRAZIER.b, 0.030 + float(i) * 0.012))

	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-7.0, 4.0),
		base + Vector2(0.0, -18.0 * flicker),
		base + Vector2(7.0, 4.0),
	]), Color(BRAZIER.r, BRAZIER.g, BRAZIER.b, 0.30))


func _draw_embers() -> void:
	for e in _embers:
		var twinkle := 0.45 + 0.35 * sin(_time * 2.1 + e.phase)
		draw_circle(e.pos, e.radius, Color(EMBER.r, EMBER.g, EMBER.b, 0.22 * twinkle))


## Darkens the edges, and the bottom hardest -- the battle log is plain text on
## this background and needs the quietest area under it.
func _draw_vignette(w: float, h: float) -> void:
	var band := h * 0.30 / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var a := 0.05 * (1.0 - float(i) / float(VIGNETTE_STEPS))
		draw_rect(Rect2(0.0, h - band * float(i + 1), w, band), Color(0.02, 0.015, 0.03, a * 2.2))
		draw_rect(Rect2(0.0, band * float(i) * 0.5, w, band * 0.5), Color(0.02, 0.015, 0.03, a))

	var side := w * 0.16 / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var a := 0.045 * (1.0 - float(i) / float(VIGNETTE_STEPS))
		draw_rect(Rect2(side * float(i), 0.0, side, h), Color(0.02, 0.015, 0.03, a))
		draw_rect(Rect2(w - side * float(i + 1), 0.0, side, h), Color(0.02, 0.015, 0.03, a))
