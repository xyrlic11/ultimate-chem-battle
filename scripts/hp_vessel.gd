extends Control

## An HP bar drawn as an actual blood vessel (2026-09-01 feedback: "ทำหลอด
## เลือดเป็นหลอดเลือดจริงๆ จะได้ดูง่ายๆ"), instead of a stock ProgressBar.
##
## Drawn by hand, same reasoning as monster_art.gd/fx_burst.gd/fx_strike.gd:
## no image assets exist in this repo and shouldn't. `value`/`max_value` are
## named and behave exactly like ProgressBar's own properties, so this is a
## drop-in replacement -- every existing `hp_bar.value = f.hp` call site in
## battle.gd needed zero changes, just a different node type underneath.

var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()

var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.001)
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	var frac := clampf(value / max_value, 0.0, 1.0)
	var r := h * 0.5

	# Vessel wall: a dim, mostly-empty tube, so the "how much is left" reading
	# comes from how much of it is actually full of blood, not from a filled
	# rect shrinking against a bare background.
	_draw_pill(Vector2(0, 0), w, h, Color(0.35, 0.08, 0.09, 0.55))

	if frac > 0.001:
		# Duller and darker at low HP -- reads as distressed tissue rather
		# than a bar that is merely short, without needing a separate colour
		# state machine.
		var pulse := 0.85 + 0.15 * sin(_time * 3.0)
		var low := 1.0 - frac
		var base_color := Color(0.75, 0.12, 0.14).lerp(Color(0.45, 0.10, 0.14), low)
		var fill_color := Color(base_color * pulse, 1.0)
		_draw_pill(Vector2(0, 0), w * frac, h, fill_color)

		# A thin lighter line near the top of the fill -- the specular
		# highlight that makes a flat shape read as a rounded tube.
		var hi_y := h * 0.28
		draw_line(Vector2(r * 0.6, hi_y), Vector2(maxf(r * 0.6, w * frac - r * 0.6), hi_y),
			Color(1.0, 0.55, 0.55, 0.35 * frac), maxf(h * 0.12, 1.0))

	# Outer wall rim, drawn last so it stays crisp over the fill.
	_draw_pill_outline(Vector2(0, 0), w, h, Color(0.15, 0.03, 0.04, 0.9), maxf(h * 0.12, 1.5))


## A horizontal rounded-rect ("pill") filled solid -- draw_rect can't round
## just the two ends at less than the full corner set it's given, so this
## builds the shape from a rect plus two end-caps instead.
func _draw_pill(at: Vector2, w: float, h: float, color: Color) -> void:
	if w <= 0.0:
		return
	var r := h * 0.5
	if w <= h:
		draw_circle(at + Vector2(w * 0.5, r), minf(r, w * 0.5), color)
		return
	draw_rect(Rect2(at + Vector2(r, 0), Vector2(maxf(w - h, 0.0), h)), color)
	draw_circle(at + Vector2(r, r), r, color)
	draw_circle(at + Vector2(w - r, r), r, color)


func _draw_pill_outline(at: Vector2, w: float, h: float, color: Color, width: float) -> void:
	var r := h * 0.5
	var points: PackedVector2Array = []
	var segs := 16
	# Right cap.
	for i in segs + 1:
		var a := -PI * 0.5 + PI * float(i) / float(segs)
		points.append(at + Vector2(w - r + cos(a) * r, r + sin(a) * r))
	# Left cap.
	for i in segs + 1:
		var a := PI * 0.5 + PI * float(i) / float(segs)
		points.append(at + Vector2(r + cos(a) * r, r + sin(a) * r))
	points.append(points[0])
	draw_polyline(points, color, width, true)
