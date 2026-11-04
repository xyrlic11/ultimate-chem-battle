extends Control

## Draws the moment a bond forms.
##
## The game explains bonding in labels, tooltips and log lines and had never
## once SHOWN it: atoms touched, a burst played, a formula floated up, and 0.3
## seconds later it was over. This is the best moment in the game and a whole
## lesson in itself, so it gets the time and the drawing.
##
## Three animations, because there are three kinds of bond and showing the wrong
## one would teach something false:
##
##   ionic     an electron LEAVES the metal and arrives on the non-metal, both
##             flash to + and -, then the ions pull together
##   covalent  an electron comes in from every atom and orbits the middle as a
##             shared pair -- nobody gives anything away
##   metallic  no transfer and no pairing: a sea of electrons drifts across all
##             the atoms at once
##
## Parented to the board so the positions handed in are already in its space.
## Purely decorative: it never touches the roster. main.gd does the real work in
## the `finished` callback, so a bond still completes even if this is skipped.

signal finished

const Recipes := preload("res://scripts/recipes.gd")

const FULL_SECONDS := 1.1
## Repeat crafts of a recipe already in the book run short. The animation is a
## lesson the first time and an interruption the twentieth.
const QUICK_SECONDS := 0.5

## Tripled from the first pass. At the original size the whole animation
## occupied roughly 100x70 of a 1280x720 screen -- about one percent -- so the
## best thing in the game read as a flicker. It is the lesson, so it gets the
## middle of the board.
const DOT_RADIUS := 9.0
const ORBIT_RADIUS := 42.0
const TRAIL_WIDTH := 3.0

var _progress := 0.0:
	set(value):
		_progress = value
		queue_redraw()

var _points: Array = []
## Parallel to _points, one per tile. Anything that needs to know WHERE to draw
## must index this, never _symbols.
var _parts: Array = []
var _symbols: Array = []
var _kind := "covalent"
var _tint := Color.WHITE
var _centre := Vector2.ZERO
var _tween: Tween

## Composed by Recipes.bond_lesson() from the same flags the drawing reads, so
## the words and the picture cannot disagree.
var _lesson := ""


func _ready() -> void:
	# Never eat a click: the board underneath still owns input, and the player
	# can carry on dragging the moment this is done.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## `points` and `symbols` are parallel and in board space. Returns immediately;
## listen on `finished`.
## `parts` is parallel to `points`: one entry per TILE, each carrying the atoms
## that tile is made of. They were separate arrays of different lengths for a
## while -- points per tile, symbols per atom -- and _draw_ionic() indexed one
## with the other. HCl + KOH is five atoms across two tiles, so the potassium
## sat at symbol index 3 and _points[3] crashed every frame the animation drew.
func play(points: Array, parts: Array, tint: Color, quick: bool) -> void:
	assert(points.size() == parts.size(), "one point per part, or the draw code lies")
	_points = points
	_parts = parts
	var symbols: Array = []
	for p in parts:
		symbols.append_array(p.get("atoms", []))
	_symbols = symbols
	_tint = tint
	_kind = Recipes.bond_type(symbols)
	_lesson = Recipes.bond_lesson(symbols)

	_centre = Vector2.ZERO
	for p in points:
		_centre += p
	if not points.is_empty():
		_centre /= float(points.size())

	visible = true
	_progress = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_progress", 1.0,
		QUICK_SECONDS if quick else FULL_SECONDS)
	_tween.finished.connect(_on_done)


## Lets a player who has seen it a hundred times get on with the game.
func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_on_done()


func _on_done() -> void:
	visible = false
	_progress = 0.0
	finished.emit()


## Killed explicitly rather than left to the tween's own node tracking: leaving
## the shop mid-animation frees the board out from under it, and a tween still
## writing to a freed Control is a crash rather than a dropped frame.
func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _draw() -> void:
	if _points.is_empty():
		return
	match _kind:
		"ionic":
			_draw_ionic()
		"metallic":
			_draw_metallic()
		_:
			_draw_covalent()
	_draw_lesson()


## The electron crosses, and only then do the charges appear. Order matters:
## showing Na+ before the electron has left would put the effect first.
func _draw_ionic() -> void:
	var ends: Array = ionic_endpoints()
	var from: Vector2 = _points[ends[0]]
	var to: Vector2 = _points[ends[1]]
	var travel: float = minf(_progress / 0.55, 1.0)

	# Arcs rather than a straight line: a straight dot reads as a UI transition,
	# a curved one reads as something being thrown.
	var mid: Vector2 = (from + to) * 0.5 + Vector2(0.0, -34.0)
	var a: Vector2 = from.lerp(mid, travel)
	var b: Vector2 = mid.lerp(to, travel)
	var dot: Vector2 = a.lerp(b, travel)

	draw_line(from, dot, Color(_tint, 0.30), TRAIL_WIDTH)
	draw_circle(dot, DOT_RADIUS + 5.0, Color(1, 1, 1, 0.35))
	draw_circle(dot, DOT_RADIUS, Color(0.95, 0.95, 1.0))

	if _progress > 0.55:
		var fade: float = minf((_progress - 0.55) / 0.2, 1.0)
		_draw_charge(from, "+", Color(1.0, 0.72, 0.35, fade))
		_draw_charge(to, "-", Color(0.45, 0.78, 1.0, fade))
		# ...and only once they are ions do they attract.
		var pull: float = maxf(_progress - 0.75, 0.0) / 0.25 * 0.22
		draw_line(from.lerp(to, pull), to.lerp(from, pull),
			Color(_tint, 0.55 * fade), 3.0)


## Nobody gives anything away: one electron from each atom, meeting in the
## middle and orbiting there.
func _draw_covalent() -> void:
	var travel: float = minf(_progress / 0.6, 1.0)
	var angle: float = _progress * TAU * 1.5
	for i in _points.size():
		var start: Vector2 = _points[i]
		var offset: float = TAU * float(i) / float(_points.size()) + angle
		var seat: Vector2 = _centre + Vector2(ORBIT_RADIUS, 0.0).rotated(offset)
		var dot: Vector2 = start.lerp(seat, ease(travel, 0.4))
		draw_line(start, dot, Color(_tint, 0.28), TRAIL_WIDTH)
		draw_circle(dot, DOT_RADIUS + 5.0, Color(1, 1, 1, 0.30))
		draw_circle(dot, DOT_RADIUS, Color(0.95, 0.98, 1.0))

	if _progress > 0.6:
		var fade: float = minf((_progress - 0.6) / 0.4, 1.0)
		draw_arc(_centre, ORBIT_RADIUS + 6.0, 0.0, TAU, 32,
			Color(_tint, 0.5 * fade), TRAIL_WIDTH)


## A sea, not a pair. Electrons belong to no particular atom, so they drift
## across the whole group rather than settling anywhere.
func _draw_metallic() -> void:
	var fade: float = sin(_progress * PI)
	var spread: float = 26.0
	for i in 10:
		var phase: float = _progress * TAU + TAU * float(i) / 10.0
		var host: Vector2 = _points[i % _points.size()]
		var drift: Vector2 = host.lerp(_centre, 0.5 + 0.5 * sin(phase))
		drift += Vector2(cos(phase * 1.7), sin(phase * 1.3)) * spread
		draw_circle(drift, DOT_RADIUS, Color(0.95, 0.95, 1.0, 0.75 * fade))
	for p in _points:
		draw_arc(p, 22.0, 0.0, TAU, 24, Color(_tint, 0.45 * fade), TRAIL_WIDTH)


func _draw_charge(at: Vector2, sign_text: String, colour: Color) -> void:
	# Theme font, not ThemeDB.fallback_font -- see _draw_lesson().
	var font := get_theme_default_font()
	if font == null:
		return
	var pos: Vector2 = at + Vector2(22.0, -22.0)
	draw_circle(pos, 11.0, Color(colour.r, colour.g, colour.b, colour.a * 0.25))
	draw_string(font, pos + Vector2(-5.0, 6.0), sign_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, colour)


## Any click or key skips ahead. Unhandled input only, so it never steals a
## press from a button underneath.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		skip()
		get_viewport().set_input_as_handled()


## The line that turns an effect into a lesson.
##
## Without it a player sees dots move and learns nothing; the game was already
## able to say "covalent" and simply never did at the one moment the word would
## have meant something.
##
## The font comes from the theme, never ThemeDB.fallback_font: the project
## bundles its own Thai face now, and Godot's built-in fallback has no Thai at
## all, so this whole line would render as boxes.
func _draw_lesson() -> void:
	if _lesson == "":
		return
	# Fades in once the electrons have arrived, so the picture lands first and
	# the words name what was just seen.
	var fade: float = clampf((_progress - 0.45) / 0.25, 0.0, 1.0)
	if fade <= 0.0:
		return

	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := 17
	var width: float = font.get_string_size(_lesson, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size).x
	var pos := Vector2((size.x - width) * 0.5, size.y - 34.0)

	# A plate behind it: the arena backdrop and the board dots both run under
	# this text, and thin Thai glyphs disappear against them.
	draw_rect(Rect2(pos.x - 14.0, pos.y - 22.0, width + 28.0, 32.0),
		Color(0.05, 0.05, 0.08, 0.72 * fade), true)
	draw_string(font, pos, _lesson, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(0.92, 0.95, 1.0, fade))


## Which TILE gives the electron and which receives it, as indices into _points.
##
## Separated out so it can be tested without a drawing context, because the way
## it broke was silent everywhere except on screen. It used to scan _symbols --
## one entry per ATOM -- and index _points with the result. That was fine while
## every cluster was loose atoms and the two arrays matched one for one. Phase
## 2.1 let compounds into clusters, HCl + KOH became five atoms across two
## tiles, potassium landed at symbol index 3, and _points[3] crashed the game
## every frame it tried to draw.
func ionic_endpoints() -> Array:
	var donor := 0
	var acceptor := 0
	for i in _parts.size():
		var holds_metal := false
		for s in _parts[i].get("atoms", []):
			if Recipes.is_metal(s):
				holds_metal = true
				break
		if holds_metal:
			donor = i
		else:
			acceptor = i
	# Never off the end, whatever _parts turns out to hold.
	var last: int = maxi(_points.size() - 1, 0)
	return [mini(donor, last), mini(acceptor, last)]
