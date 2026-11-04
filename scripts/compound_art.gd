extends Control

## Fantasy mascots, not literal molecular geometry. Formula and recipe remain
## authoritative; this view never changes stats or the player's inventory.
const Recipes := preload("res://scripts/recipes.gd")
const Abilities := preload("res://scripts/unit_abilities.gd")
const Timing := preload("res://scripts/combat_timing.gd")
const FORMS := {
	"H2O": "droplet", "CH4": "flame", "H2CO3": "bubble",
	"Fe2": "golem", "Cu2": "golem", "FeO": "golem", "CuO": "golem", "Fe2O3": "golem", "FeS": "golem", "MgO": "shell",
	"NaCl": "crystal", "KCl": "crystal", "CaCl2": "crystal", "NH4Cl": "crystal",
	"H2": "wing", "O2": "wing", "N2": "shell", "CO2": "cloud",
	"H2S": "cloud", "SO2": "cloud", "H2SO3": "cauldron",
	"HCl": "serpent", "NH3": "serpent", "NaOH": "sprout", "KOH": "sprout",
	"CaO": "flame", "CaOH2": "shell",
}

var formula := "H2O"
var tier := 1
var _time := 0.0
var _phase := 0.0
var _form := "droplet"
var _role := "support"
var _color := Color(0.25, 0.75, 1.0)
var _atoms: Array = []
var _sprite: Texture2D
static var _sprite_cache: Dictionary = {}
const COMBAT_ROWS := {"H2O": 0, "NaCl": 1, "Fe2": 2, "CH4": 3}
var pose := "idle"
var pose_age := 0.0
var motion_speed := 1.0
var motion_direction := 1.0
var _combat_frames: Array[Texture2D] = []

func setup(value: String, compound_tier := 1) -> void:
	formula = value
	tier = compound_tier
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite_path := "res://assets/compounds/pixel/%s.png" % formula
	if not _sprite_cache.has(formula) and ResourceLoader.exists(sprite_path):
		_sprite_cache[formula] = load(sprite_path)
	_sprite = _sprite_cache.get(formula)
	_combat_frames.clear()
	if COMBAT_ROWS.has(formula):
		var atlas: Texture2D = load("res://assets/compounds/combat/mini-substance-atlas-v1.png")
		var cell := atlas.get_size() / 4.0
		var row: int = COMBAT_ROWS[formula]
		for column in 4:
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(Vector2(column, row) * cell, cell)
			_combat_frames.append(frame)
		_sprite = _combat_frames[0]
	var recipe = Recipes.find_by_formula(formula)
	var kind: String = recipe.kind if recipe != null else "neutral"
	_form = FORMS.get(formula, "crystal" if kind == "salt" else "cauldron")
	_role = str(Abilities.skill_of(formula).get("role", "support"))
	_color = Recipes.KIND_COLOR.get(kind, Color(0.4, 0.8, 1.0))
	if formula == "H2O":
		_color = Color(0.25, 0.75, 1.0)
	elif formula == "CH4":
		_color = Color(1.0, 0.45, 0.15)
	_atoms = Recipes.atoms_of(formula)
	if _atoms.is_empty():
		for key in Recipes.TIER2_RECIPES:
			if Recipes.TIER2_RECIPES[key].formula == formula:
				for ingredient in key.split(","):
					_atoms.append_array(Recipes.atoms_of(ingredient))
	_phase = float(abs(formula.hash()) % 100) * 0.06
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if pose != "idle":
		pose_age += delta * motion_speed * Timing.VISUAL_RATE
		if pose_age >= 0.42:
			pose = "idle"
		if not _combat_frames.is_empty():
			_update_pose_frame()
	pivot_offset = size * 0.5
	rotation = sin(pose_age * 35) * 0.10 * (1.0 - minf(pose_age / 0.42, 1.0)) if pose == "hurt" else 0.0
	scale = Vector2(1.12, 0.88) if pose == "hurt" and pose_age < 0.10 else Vector2.ONE
	queue_redraw()

func play_pose(value: String, direction := 1.0, rate := 1.0) -> void:
	pose = value
	pose_age = 0.0
	motion_direction = direction
	motion_speed = rate
	_update_pose_frame()
	queue_redraw()

func set_attack_phase(age: float) -> void:
	pose_age = age
	pose = "attack" if age < 0.35 else "idle"
	_update_pose_frame()
	queue_redraw()

func _update_pose_frame() -> void:
	if not _combat_frames.is_empty():
		var index := 0
		if pose == "attack":
			index = 1 if pose_age < 0.12 else 2
		elif pose == "hurt":
			index = 3
		_sprite = _combat_frames[index]

func _poly(points: Array, fill: Color, rim: Color) -> void:
	var vertices := PackedVector2Array()
	for p in points:
		vertices.append(Vector2(p[0], p[1]))
	draw_colored_polygon(vertices, fill)
	vertices.append(vertices[0])
	draw_polyline(vertices, rim, 1.4, true)

func _orb(at: Vector2, radius: float, color: Color) -> void:
	draw_circle(at, radius, color.darkened(0.25))
	draw_arc(at, radius, 0, TAU, 24, color.lightened(0.35), 1.2, true)
	draw_circle(at + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.22, Color(1, 1, 1, 0.7))

func _draw() -> void:
	if _sprite != null:
		_draw_sprite()
		return
	var unit := minf(size.x / 100.0, size.y / 76.0)
	if unit <= 0:
		return
	var bob := sin(_time * 2.1 + _phase) * 2.0
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0, Vector2.ONE * unit)
	draw_circle(Vector2(0, 29), 23, Color(0, 0, 0, 0.24))
	if tier >= 2:
		draw_arc(Vector2.ZERO, 31, 0, TAU, 40, Color(1, 0.8, 0.3, 0.7), 1.5, true)
		for i in 3:
			var at := Vector2(31, 0).rotated(_time * 0.5 + i * TAU / 3.0)
			draw_circle(at, 2.5, Color(1, 0.85, 0.45))
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5 + bob * unit), 0, Vector2.ONE * unit)
	var ink := _color.lightened(0.3)
	var body := _color.darkened(0.28)
	# Metal species keep their element tint; iron and copper should not be twins.
	if _form == "golem" and not _atoms.is_empty():
		var metal: Color = Recipes.ELEMENTS.get(_atoms[0], {}).get("color", _color)
		body = body.lerp(metal, 0.45)
		ink = ink.lerp(metal.lightened(0.3), 0.45)
	match _form:
		"droplet", "bubble":
			_poly([[-23, 12], [-22, -2], [-9, -18], [0, -30], [11, -15], [23, 1], [23, 13], [12, 23], [-12, 23]], body, ink)
			if _form == "bubble":
				for i in 3:
					_orb(Vector2(-26 + i * 25, -23 - sin(_time + i) * 3), 4 + i, ink)
		"flame":
			_poly([[-24, 17], [-27, 0], [-15, -17], [-13, -1], [2, -32], [12, -12], [18, -22], [26, 3], [20, 20], [0, 26]], body, ink)
			_poly([[-10, 20], [0, -5], [13, 20], [0, 25]], Color(1, 0.8, 0.3), ink)
		"golem":
			_poly([[-19, -20], [15, -24], [25, -7], [20, 19], [-19, 22], [-25, 1]], body, ink)
			_poly([[-25, -6], [-36, -3], [-32, 20], [-23, 17]], body.darkened(0.15), ink)
			_poly([[25, -6], [36, -3], [32, 20], [23, 17]], body.darkened(0.15), ink)
			draw_line(Vector2(-12, -18), Vector2(-2, -6), ink, 2)
			_poly([[-19, 19], [-5, 19], [-7, 29], [-23, 29]], body, ink)
			_poly([[5, 19], [19, 19], [23, 29], [7, 29]], body, ink)
		"crystal":
			_poly([[-24, 7], [-17, -20], [0, -30], [20, -15], [25, 10], [0, 26]], body, ink)
			draw_line(Vector2(0, -30), Vector2(0, 26), Color(ink, 0.5), 1.5)
			draw_line(Vector2(-17, -20), Vector2(25, 10), Color(ink, 0.5), 1.5)
		"wing":
			var lift := sin(_time * 4 + _phase) * 4
			_poly([[-10, 0], [-36, -20 - lift], [-28, 9], [-13, 18]], body, ink)
			_poly([[10, 0], [36, -20 - lift], [28, 9], [13, 18]], body, ink)
			_orb(Vector2.ZERO, 18, _color)
		"cloud":
			for i in 4:
				_orb(Vector2(-21 + i * 14, sin(i * 2.0) * 7), 14, _color)
			draw_arc(Vector2(0, -4), 26, PI * 1.15, PI * 1.85, 24, Color(ink, 0.6), 2, true)
		"serpent":
			_poly([[-26, 22], [-10, 11], [-15, -1], [-11, -20], [8, -28], [22, -13], [15, 3], [5, 11], [17, 22]], body, ink)
			_orb(Vector2(-26, 22), 5, _color)
		"sprout":
			_orb(Vector2(0, 8), 20, _color)
			draw_line(Vector2(0, -6), Vector2(0, -26), ink, 3)
			_poly([[0, -23], [-23, -29], [-15, -12], [0, -16]], body, ink)
			_poly([[0, -23], [23, -29], [15, -12], [0, -16]], body, ink)
		"shell":
			_poly([[-27, 10], [-24, -14], [0, -28], [24, -14], [27, 10], [0, 27]], body, ink)
			for x in [-12, 0, 12]:
				draw_line(Vector2(x, -13), Vector2(x, 15), Color(ink, 0.45), 2)
		_:
			_poly([[-24, -13], [24, -13], [21, 19], [0, 26], [-21, 19]], body, ink)
			for i in 3:
				_orb(Vector2(-13 + i * 13, -22 + sin(_time * 2 + i) * 3), 5, ink)
	# Element beads give same-family compounds a stable composition signature.
	var unique: Array = []
	for atom in _atoms:
		if not unique.has(atom):
			unique.append(atom)
	for i in mini(unique.size(), 4):
		var color: Color = Recipes.ELEMENTS.get(unique[i], {}).get("color", ink)
		_orb(Vector2((i - (mini(unique.size(), 4) - 1) * 0.5) * 10, 22), 3.5, color)
	# Eyes stay readable on the smallest preparation tile.
	for x in [-7, 7]:
		draw_circle(Vector2(x, 1), 4, Color(0.04, 0.06, 0.12))
		draw_circle(Vector2(x - 1, -0.8), 1.3, Color.WHITE)
	if _role == "tank":
		_poly([[18, 7], [31, 7], [30, 20], [24, 26], [18, 20]], Color(0.17, 0.23, 0.32), Color(1, 0.84, 0.45))
	elif _role == "striker" or _role == "fighter":
		_poly([[24, 18], [29, -6], [34, 18]], Color(1, 0.85, 0.45), ink)
	elif _role == "support":
		draw_line(Vector2(29, -3), Vector2(29, 9), Color(0.55, 1, 0.75), 3)
		draw_line(Vector2(23, 3), Vector2(35, 3), Color(0.55, 1, 0.75), 3)
	else:
		draw_arc(Vector2(29, 3), 6, 0, TAU, 20, ink, 2, true)
	draw_set_transform(Vector2.ZERO)


func _draw_sprite() -> void:
	# Integer-aligned placement and nearest filtering preserve pixel clusters.
	var span := minf(size.x, size.y)
	var sprite_size := Vector2.ONE * floorf(span)
	var origin := ((size - sprite_size) * 0.5).floor()
	origin.y += roundf(sin(_time * 2.1 + _phase) * 1.5)
	var tint := Color.WHITE
	if pose == "hurt":
		origin.x -= roundf(sin(pose_age * 42) * 4 * (1.0 - pose_age / 0.42) * motion_direction)
		tint = Color(1.4, 1.1, 1.1) if pose_age < 0.12 else Color.WHITE
	if tier >= 2:
		var gold := Color(1.0, 0.83, 0.35, 0.8)
		for i in 3:
			var at := size * 0.5 + Vector2(span * 0.45, 0).rotated(_time * 0.5 + i * TAU / 3.0)
			draw_rect(Rect2(at.round(), Vector2(3, 3)), gold)
	draw_texture_rect(_sprite, Rect2(origin, sprite_size), false, tint)
