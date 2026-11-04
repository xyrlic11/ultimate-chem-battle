extends Control

## Mini pixel villains. Chemical kind supplies palette and silhouette;
## expression, windup and hurt are presentation only.
const Recipes := preload("res://scripts/recipes.gd")
@export var kind: String = "acid":
	set(value):
		kind = value
		queue_redraw()
@export var charging: bool = false:
	set(value):
		charging = value
		queue_redraw()
var _time := 0.0
var formula := "H2O"
var boss_mode := true
var ultimate := false
var motion_speed := 1.0
var _flash := 0.0
var _charge := 0.0
var _origin := Vector2.ZERO
var _unit := 1.0

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var step := delta * motion_speed * preload("res://scripts/combat_timing.gd").VISUAL_RATE
	_time += step
	_flash = maxf(0.0, _flash - step * 3.5)
	_charge = move_toward(_charge, 1.0 if charging else 0.0, delta * 3.0)
	queue_redraw()

func hit() -> void:
	_flash = 1.0

func _px(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(_origin + Vector2(x, y) * _unit, Vector2(w, h) * _unit), color.lerp(Color.WHITE, _flash * 0.8))

func _draw() -> void:
	_unit = maxf(1.0, floorf(minf(size.x, size.y) / 34.0))
	var bob := roundf(sin(_time * 1.8) * _unit)
	_origin = (size * 0.5 - Vector2(12, 12) * _unit).round() + Vector2(roundf(sin(_time * 38) * _flash * _unit), bob - _charge * _unit)
	var ink := Color("211c30")
	var body: Color = Recipes.KIND_COLOR.get(kind, Color("85baca"))
	body = body.lerp(Color("b78fd4"), 0.25)
	var shade := body.darkened(0.35)
	var light := body.lightened(0.28)
	# Ground shadow, feet and outlined body remain chunky at thumbnail size.
	_px(5, 23, 14, 1, Color(0.03, 0.02, 0.07, 0.35))
	_px(6, 20, 4, 3, ink)
	_px(15, 20, 4, 3, ink)
	match kind:
		"acid":
			# Toxic droplet, asymmetric tail and two dark horn nubs.
			_px(9, 4, 8, 3, ink)
			_px(6, 7, 13, 14, ink)
			_px(4, 12, 17, 6, ink)
			_px(7, 8, 11, 12, body)
			_px(5, 13, 15, 4, body)
			if boss_mode:
				_px(8, 2, 3, 6, ink)
				_px(16, 4, 3, 5, ink)
			_px(17, 15, 3, 4, shade)
		"base":
			# Caustic foam hood with a wide mask and one bubbling crest.
			_px(7, 3, 5, 5, ink)
			_px(8, 4, 3, 3, light)
			_px(5, 7, 15, 13, ink)
			_px(3, 9, 19, 8, ink)
			_px(6, 8, 13, 11, body)
			_px(4, 10, 17, 6, body)
			_px(17, 11, 3, 7, shade)
		"metal":
			# Square armored bruiser: shoulder plates and a split helmet.
			_px(5, 5, 15, 16, ink)
			_px(2, 10, 4, 9, ink)
			_px(20, 10, 3, 9, ink)
			_px(6, 6, 13, 14, body)
			_px(3, 11, 3, 6, shade)
			_px(20, 11, 2, 6, shade)
			_px(12, 6, 1, 5, shade)
			_px(17, 7, 2, 12, shade)
		"salt":
			# Jagged crystal crown instead of round horns.
			_px(5, 5, 3, 6, ink)
			_px(11, 2, 3, 7, ink)
			_px(17, 5, 3, 6, ink)
			_px(5, 9, 15, 12, ink)
			_px(6, 10, 13, 10, body)
			_px(6, 6, 1, 5, light)
			_px(12, 3, 1, 8, light)
			_px(17, 13, 2, 7, shade)
		_:
			# Training dummy remains quieter and has no horns or fangs.
			_px(6, 6, 13, 15, ink)
			_px(5, 9, 15, 9, ink)
			_px(7, 7, 11, 13, body)
			_px(6, 10, 13, 7, body)
	_px(7, 9, 3, 2, light)
	_px(7, 18, 10, 2, shade)
	# Slanted brow + pale eyes = mischievous villain, not a cute animal.
	var eye := Color("ffe6a0").lerp(Color("ff625b"), _charge)
	_px(7, 12, 4, 3, ink)
	_px(14, 12, 4, 3, ink)
	_px(8, 13, 2, 1, eye)
	_px(15, 13, 2, 1, eye)
	if boss_mode and kind != "neutral":
		_px(7, 11, 2, 1, ink)
		_px(9, 12, 2, 1, ink)
		_px(16, 11, 2, 1, ink)
		_px(14, 12, 2, 1, ink)
		_px(10, 17, 6, 1, ink)
		_px(15, 16, 2, 1, ink)
		_px(11, 17, 1, 1, Color("fff1d4"))
	else:
		_px(11, 17, 3, 1, ink)
	if _charge > 0.05:
		var glow := Color("ff8069")
		glow.a = _charge
		_px(1, 6, 1, 4, glow)
		_px(22, 3, 1, 4, glow)
		_px(3, 3, 2, 1, glow)
