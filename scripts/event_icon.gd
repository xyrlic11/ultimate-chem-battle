extends Control
## Small code-native pixel props for journey cards, matching the mini sprites.
var kind := "camp"
var ink := Color("edc984")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _block(x: float, y: float, w: float, h: float, color: Color) -> void:
	var unit := floorf(minf(size.x, size.y) / 24.0)
	var origin := (size - Vector2(24,24) * unit) * 0.5
	draw_rect(Rect2(origin + Vector2(x,y) * unit, Vector2(w,h) * unit), color)
func _draw() -> void:
	var dark := Color("211c30")
	var shade := ink.darkened(0.35)
	match kind:
		"merchant":
			_block(3, 10, 18, 9, dark)
			_block(4, 11, 16, 6, ink)
			_block(3, 6, 18, 4, shade)
			_block(5, 4, 14, 3, ink)
			_block(5, 19, 4, 4, dark)
			_block(16, 19, 4, 4, dark)
			_block(7, 7, 3, 3, ink.lightened(0.35))
		"person":
			_block(8, 3, 8, 7, dark)
			_block(9, 4, 6, 5, ink.lightened(0.25))
			_block(5, 11, 14, 9, dark)
			_block(6, 12, 12, 7, ink)
			_block(8, 20, 3, 3, shade)
			_block(14, 20, 3, 3, shade)
			_block(10, 6, 1, 1, dark)
			_block(14, 6, 1, 1, dark)
		"chest":
			_block(3, 6, 18, 15, dark)
			_block(4, 7, 16, 12, shade)
			_block(4, 7, 16, 4, ink)
			_block(4, 14, 16, 1, dark)
			_block(10, 12, 4, 5, ink.lightened(0.3))
		"camp":
			_block(4, 19, 17, 3, shade)
			_block(9, 7, 7, 11, ink)
			_block(11, 4, 3, 4, ink)
			_block(7, 13, 11, 6, ink.darkened(0.1))
			_block(11, 12, 4, 6, Color("ffe0a4"))
		"ruins":
			_block(3, 4, 18, 3, dark)
			_block(4, 5, 16, 1, ink)
			_block(4, 8, 4, 12, shade)
			_block(16, 8, 4, 12, shade)
			_block(5, 8, 1, 12, ink)
			_block(17, 8, 1, 12, ink)
			_block(3, 21, 18, 2, ink)
		"lab":
			_block(9, 3, 7, 3, shade)
			_block(10, 6, 5, 7, ink)
			_block(6, 13, 13, 9, dark)
			_block(7, 14, 11, 7, ink)
			_block(8, 18, 9, 3, shade)
			_block(9, 14, 3, 2, ink.lightened(0.4))
		_:
			_block(5, 5, 14, 15, dark)
			_block(6, 6, 12, 13, ink)
			_block(4, 2, 3, 6, shade)
			_block(17, 2, 3, 6, shade)
			_block(8, 10, 2, 3, dark)
			_block(14, 10, 2, 3, dark)
			_block(10, 16, 5, 1, dark)
