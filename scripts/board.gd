extends Panel

## The bonding board's backdrop.
##
## WHY THIS EXISTS: the board is the single biggest element on the shop screen
## and the only one the player is meant to interact with, but as a plain filled
## Panel it read as empty space -- the eye skipped it and went to the gold
## counter instead. A faint dot grid is the cheapest way to say "this is a
## surface you put things on"; the same trick every diagram and design tool
## uses for the same reason.
##
## Kept deliberately far below the atoms in contrast. The atoms are saturated
## element colours on a near-black panel, and anything stronger than a barely
## visible dot starts competing with them for attention.

const Traits := preload("res://scripts/traits.gd")

const SPACING := 34.0
const DOT_RADIUS := 1.5
const DOT_COLOR := Color(1.0, 1.0, 1.0, 0.05)

## Bottom-right sell corner. Drawn as a quarter-circle wedge fanning out of the
## actual corner point, not a rectangle -- and drawn only while a drag is in
## progress, not dimly at rest. A rectangle in a corner reads as a panel; a
## wedge reads as something that opens out of the corner specifically. And a
## corner visible 100% of the time to be useful 2% of the time is exactly the
## "รกตา" (visual clutter) complaint that keeps coming up -- nobody needs to
## see the sell target except while they are already dragging toward it.
const SELL_COLOR := Color(1.0, 0.55, 0.4, 0.9)
const SELL_FILL := Color(1.0, 0.55, 0.4, 0.16)
const SELL_ICON_SIZE := 30

## Set by main.gd for the duration of a drag. Not derived from mouse position
## here -- the board has no idea a drag is happening at all, only main.gd does.
var sell_zone_active := false


func _draw() -> void:
	# Half-spacing inset so the grid does not collide with the panel's rounded
	# border on either edge.
	var x := SPACING * 0.5
	while x < size.x:
		var y := SPACING * 0.5
		while y < size.y:
			draw_circle(Vector2(x, y), DOT_RADIUS, DOT_COLOR)
			y += SPACING
		x += SPACING

	# The front/back divider lines and zone labels that used to live here
	# (A3-b) are gone -- 2026-09-01's relayout moved fielding off the board
	# entirely, into TeamPanel's own FrontRow/BackRow containers in
	# Main.tscn. The board is craft/bench only now, which is one zone, and
	# one zone has nothing to divide.
	if sell_zone_active:
		var font := get_theme_default_font()
		if font != null:
			_draw_sell_wedge(font)


## A quarter-disc fanning out of the bottom-right corner: the two straight
## edges run along the board's own right and bottom edges, the arc bulges up
## and left into the board. Built as a triangle-fan polygon (corner + points
## walking the arc) rather than a Rect2, which can only ever be a rectangle.
func _draw_sell_wedge(font: Font) -> void:
	var r := Traits.SELL_ZONE_SIZE
	var corner := Vector2(size.x, size.y)
	var angle_from := deg_to_rad(180.0)
	var angle_to := deg_to_rad(270.0)
	var steps := 24

	var fill := PackedVector2Array()
	fill.append(corner)
	for i in steps + 1:
		var a: float = lerpf(angle_from, angle_to, float(i) / steps)
		fill.append(corner + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(fill, SELL_FILL)

	draw_line(corner, corner + Vector2(-r, 0.0), SELL_COLOR, 2.0)
	draw_line(corner, corner + Vector2(0.0, -r), SELL_COLOR, 2.0)
	draw_arc(corner, r, angle_from, angle_to, steps, SELL_COLOR, 2.0)

	# Icon only, no "ลากมาขาย" label -- the wedge only exists while a drag is
	# already happening, so the player's attention is already on it; the text
	# was for a corner that had to explain itself while sitting idle, and this
	# one no longer does.
	var bisector := deg_to_rad(225.0)
	var icon_pos := corner + Vector2(cos(bisector), sin(bisector)) * r * 0.55
	var icon_width: float = font.get_string_size(
		"🗑", HORIZONTAL_ALIGNMENT_LEFT, -1, SELL_ICON_SIZE).x
	draw_string(font, icon_pos + Vector2(-icon_width * 0.5, SELL_ICON_SIZE * 0.36),
		"🗑", HORIZONTAL_ALIGNMENT_LEFT, -1, SELL_ICON_SIZE, SELL_COLOR)


func _notification(what: int) -> void:
	# The board stretches with the window, and _draw() is not re-run on resize
	# by itself -- without this the grid stays sized to the first layout pass.
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
