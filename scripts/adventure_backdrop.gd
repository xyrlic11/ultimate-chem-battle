extends Control

## Low-contrast procedural scenery shared by Home, Main and Event.
## The battle scene already owns a dedicated animated alchemy arena.

const Worlds := preload("res://scripts/worlds.gd")

enum Context { BATTLE, PREPARATION, EVENT, HOME }

@export_range(-1, 4) var region_override := -1
@export_range(0.0, 1.0) var scenery_opacity := 1.0
@export_file("*.png") var background_path := ""
@export var context: Context = Context.BATTLE

var _time := 0.0
var _region_index := 0
var _background_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_region()

func _refresh_region() -> void:
	_background_texture = null
	_region_index = region_override if region_override >= 0 else Worlds.region_index_for_wave(_current_wave())
	var region: Dictionary = Worlds.REGIONS[_region_index]
	var selected_path := background_path
	if selected_path.is_empty():
		match context:
			Context.PREPARATION:
				selected_path = str(region.get("prep_background", ""))
			Context.EVENT:
				selected_path = str(region.get("event_background", region.get("battle_background", "")))
			_:
				selected_path = str(region.get("battle_background", ""))
	if not selected_path.is_empty():
		var loaded = load(selected_path)
		if loaded is Texture2D:
			_background_texture = loaded
			if "/pixel/" in selected_path:
				texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _process(delta: float) -> void:
	if region_override < 0 and _region_index != Worlds.region_index_for_wave(_current_wave()):
		_refresh_region()
	_time += delta
	# Only the tiny magic motes move.  Ten redraws per second is enough for calm
	# ambience and avoids turning a menu background into a rendering cost.
	if int(_time * 10.0) != int((_time - delta) * 10.0):
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _current_wave() -> int:
	var state := get_node_or_null("/root/GameState")
	return int(state.get("wave")) if state != null else 1


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var region: Dictionary = Worlds.REGIONS[_region_index]
	if _background_texture != null:
		draw_texture_rect(_background_texture, Rect2(Vector2.ZERO, size), false)
		# UI wins the contrast fight.  The art remains visible, but text and
		# draggable pieces sit on a stable dark value regardless of the region.
		var wash_alpha := 0.40 if context == Context.PREPARATION else 0.28
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.018, 0.04, wash_alpha))
		_draw_arcane_ring(region.accent)
		_draw_vignette()
		return
	_draw_gradient(region.sky_top, region.sky_bottom)
	_draw_stars(region.accent)
	_draw_arcane_ring(region.accent)
	match str(region.id):
		"luminous_forest":
			_draw_forest(region.silhouette, region.accent)
		"abandoned_village":
			_draw_forest(region.silhouette, region.accent)
		"floating_castle":
			_draw_floating_castle(region.silhouette, region.accent)
		"dragon_cavern":
			_draw_dragon_cavern(region.silhouette, region.accent)
		_:
			_draw_astral_ruins(region.silhouette, region.accent)
	_draw_vignette()


func _draw_gradient(top: Color, bottom: Color) -> void:
	const BANDS := 32
	var band_h := size.y / float(BANDS)
	for i in BANDS:
		var t := float(i) / float(BANDS - 1)
		var color := top.lerp(bottom, t)
		color.a = scenery_opacity
		draw_rect(Rect2(0.0, i * band_h, size.x, band_h + 1.0), color)


func _draw_stars(accent: Color) -> void:
	for i in 34:
		var x := fmod(float(i * 193 + 71), maxf(size.x, 1.0))
		var base_y := fmod(float(i * 89 + 37), maxf(size.y * 0.72, 1.0))
		var y := base_y + sin(_time * 0.55 + i * 1.7) * 3.0
		var pulse := 0.12 + (sin(_time * 1.2 + i) + 1.0) * 0.07
		draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.45,
			Color(accent.r, accent.g, accent.b, pulse * scenery_opacity))


func _draw_arcane_ring(accent: Color) -> void:
	var center := Vector2(size.x * 0.52, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.30
	var alpha := 0.055 * scenery_opacity
	draw_arc(center, radius, 0.0, TAU, 72, Color(accent, alpha), 2.0, true)
	draw_arc(center, radius * 0.76, 0.0, TAU, 64, Color(accent, alpha * 0.8), 1.0, true)
	for i in 8:
		var a := TAU * float(i) / 8.0 + _time * 0.015
		var p1 := center + Vector2.from_angle(a) * radius * 0.76
		var p2 := center + Vector2.from_angle(a) * radius
		draw_line(p1, p2, Color(accent, alpha), 1.0)


func _draw_forest(ink: Color, accent: Color) -> void:
	var ground_y := size.y * 0.78
	draw_rect(Rect2(0.0, ground_y, size.x, size.y - ground_y), Color(ink, scenery_opacity))
	for side in [-1, 1]:
		for i in 5:
			var x := (55.0 + i * 88.0) if side < 0 else (size.x - 55.0 - i * 88.0)
			var trunk_h := 170.0 + float((i * 47) % 100)
			draw_rect(Rect2(x - 12.0, ground_y - trunk_h, 24.0, trunk_h), Color(ink, scenery_opacity))
			for crown in 3:
				var c := Vector2(x + (crown - 1) * 28.0, ground_y - trunk_h + crown * 14.0)
				draw_circle(c, 52.0 - crown * 5.0, Color(ink.lightened(0.035), scenery_opacity))
	for i in 12:
		var p := Vector2(30.0 + i * size.x / 12.0, ground_y - 12.0 - float((i * 17) % 34))
		draw_circle(p, 3.0, Color(accent, (0.22 + 0.08 * sin(_time + i)) * scenery_opacity))


func _draw_floating_castle(ink: Color, accent: Color) -> void:
	for i in 5:
		var cx := size.x * (0.12 + i * 0.205)
		var cy := size.y * (0.64 + float(i % 2) * 0.08)
		var island := PackedVector2Array([
			Vector2(cx - 100.0, cy), Vector2(cx + 100.0, cy),
			Vector2(cx + 45.0, cy + 70.0), Vector2(cx, cy + 120.0),
			Vector2(cx - 50.0, cy + 62.0),
		])
		draw_colored_polygon(island, Color(ink, scenery_opacity))
		if i == 2:
			_draw_castle(Vector2(cx, cy), ink, accent)
	for i in 7:
		var cloud_y := size.y * (0.2 + i * 0.075)
		draw_line(Vector2(0.0, cloud_y), Vector2(size.x, cloud_y + 18.0),
			Color(accent, 0.035 * scenery_opacity), 18.0)


func _draw_castle(base: Vector2, ink: Color, accent: Color) -> void:
	for offset in [-72.0, 0.0, 72.0]:
		var h := 145.0 if offset == 0.0 else 105.0
		draw_rect(Rect2(base.x + offset - 24.0, base.y - h, 48.0, h), Color(ink.lightened(0.04), scenery_opacity))
		var roof := PackedVector2Array([
			Vector2(base.x + offset - 34.0, base.y - h),
			Vector2(base.x + offset, base.y - h - 48.0),
			Vector2(base.x + offset + 34.0, base.y - h),
		])
		draw_colored_polygon(roof, Color(ink, scenery_opacity))
		draw_circle(Vector2(base.x + offset, base.y - h * 0.52), 4.0,
			Color(accent, 0.42 * scenery_opacity))


func _draw_crystal_cave(ink: Color, accent: Color) -> void:
	draw_rect(Rect2(0.0, size.y * 0.82, size.x, size.y * 0.18), Color(ink, scenery_opacity))
	for i in 13:
		var x := float(i) * size.x / 12.0
		var top_len := 55.0 + float((i * 31) % 120)
		var stalactite := PackedVector2Array([Vector2(x - 28.0, 0.0), Vector2(x + 28.0, 0.0), Vector2(x, top_len)])
		draw_colored_polygon(stalactite, Color(ink, scenery_opacity))
	for i in 10:
		var x := 30.0 + float(i) * (size.x - 60.0) / 9.0
		var h := 30.0 + float((i * 29) % 90)
		var crystal := PackedVector2Array([
			Vector2(x - 16.0, size.y), Vector2(x - 10.0, size.y - h * 0.62),
			Vector2(x, size.y - h), Vector2(x + 13.0, size.y - h * 0.55), Vector2(x + 18.0, size.y),
		])
		draw_colored_polygon(crystal, Color(accent, (0.10 + float(i % 3) * 0.035) * scenery_opacity))


func _draw_dragon_cavern(ink: Color, accent: Color) -> void:
	draw_rect(Rect2(0.0, size.y * 0.76, size.x, size.y * 0.24), Color(ink, scenery_opacity))
	for side in [-1, 1]:
		var x := 0.0 if side < 0 else size.x
		for i in 7:
			var center := Vector2(x + side * (20.0 + i * 21.0), size.y * (0.12 + i * 0.12))
			draw_circle(center, 90.0, Color(ink, scenery_opacity))
	# The distant eye is intentionally abstract: atmosphere, not a second boss.
	var eye := Vector2(size.x * 0.5, size.y * 0.33)
	draw_arc(eye, 36.0, 0.15, PI - 0.15, 28, Color(accent, 0.18 * scenery_opacity), 5.0)
	draw_line(Vector2(0.0, size.y * 0.9), Vector2(size.x, size.y * 0.84),
		Color(accent, 0.14 * scenery_opacity), 8.0)


func _draw_astral_ruins(ink: Color, accent: Color) -> void:
	var floor_y := size.y * 0.80
	draw_rect(Rect2(0.0, floor_y, size.x, size.y - floor_y), Color(ink, scenery_opacity))
	for i in 7:
		var x := size.x * (0.08 + i * 0.14)
		var h := 110.0 + float((i % 3) * 48)
		draw_rect(Rect2(x - 18.0, floor_y - h, 36.0, h), Color(ink.lightened(0.04), scenery_opacity))
		draw_rect(Rect2(x - 28.0, floor_y - h - 10.0, 56.0, 12.0), Color(ink, scenery_opacity))
		draw_circle(Vector2(x, floor_y - h * 0.55), 3.0, Color(accent, 0.35 * scenery_opacity))


func _draw_vignette() -> void:
	for i in 10:
		var inset := float(i) * 10.0
		var alpha := (0.018 + float(i) * 0.006) * scenery_opacity
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(0.015, 0.012, 0.025, alpha), false, 12.0)
