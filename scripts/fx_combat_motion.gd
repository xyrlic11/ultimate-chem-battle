extends Control
const Timing := preload("res://scripts/combat_timing.gd")
const Styles := preload("res://scripts/attack_styles.gd")

## Independent overlay: layout containers cannot snap the attack back in place.
var source: Control
var visual: Control
var from_global := Vector2.ZERO
var to_global := Vector2.ZERO
var age := 0.0
var speed := 1.0
var duration := 0.62
var profile: Dictionary
var start_point := Vector2.ZERO
var impact_point := Vector2.ZERO

func setup(origin: Control, target: Control, rate: float) -> void:
	source = origin
	speed = rate
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	from_global = origin.global_position
	to_global = target.global_position + target.size * 0.5 - origin.size * 0.5
	start_point = from_global + origin.size * 0.5
	impact_point = target.global_position + target.size * 0.5
	profile = Styles.profile(str(origin.get("formula")) if origin.get_script() == preload("res://scripts/compound_art.gd") else "")
	if origin.get_script() == preload("res://scripts/monster_art.gd"):
		profile = preload("res://scripts/enemy_attacks.gd").profile(origin.kind, origin.ultimate, origin.formula) if origin.boss_mode else Styles.profile(origin.formula)
	if profile.range == "melee":
		impact_point.x -= signf(impact_point.x - start_point.x) * target.size.x * 0.32
		to_global = impact_point - origin.size * 0.5
	visual = Control.new()
	visual.show_behind_parent = true
	visual.set_script(origin.get_script())
	add_child(visual)
	visual.size = origin.size
	if origin.get_script() == preload("res://scripts/compound_art.gd"):
		visual.setup(origin.formula, origin.tier)
		visual.play_pose("attack", signf(to_global.x - from_global.x), rate)
	else:
		visual.set("kind", origin.get("kind"))
		visual.formula = origin.formula
		visual.boss_mode = origin.boss_mode
		visual.ultimate = origin.ultimate
		visual.charging = origin.ultimate
		visual._charge = 1.0 if origin.ultimate else 0.0
	visual.set_process(false)
	source.self_modulate.a = 0.0
	position = from_global - get_parent().global_position
	tree_exiting.connect(func():
		if is_instance_valid(source):
			source.self_modulate.a = 1.0)

func _process(delta: float) -> void:
	age += delta * speed * Timing.VISUAL_RATE
	if not is_instance_valid(source) or age >= duration:
		queue_free()
		return
	if visual.has_method("set_attack_phase"):
		visual.set_attack_phase(age)
	var travel: float
	if age < 0.10:
		travel = -0.04 * sin(age / 0.10 * PI * 0.5)
	elif age < 0.35:
		travel = lerpf(-0.04, 1.0, pow((age - 0.10) / 0.25, 2.0))
	else:
		travel = pow(1.0 - (age - 0.35) / 0.27, 2.0)
	if profile.range == "ranged":
		travel = -0.015 * sin(clampf(age / 0.35, 0, 1) * PI)
	position = from_global.lerp(to_global, travel) - get_parent().global_position
	visual.pivot_offset = visual.size * 0.5
	var swing: float = 0.28 if profile.effect in ["slash", "sweep", "cleave"] else 0.10
	visual.rotation = sin(clampf(age / 0.35, 0, 1) * PI) * swing * signf(to_global.x - from_global.x)
	if profile.effect in ["wave", "foam", "mist", "cloud"]:
		visual.scale = Vector2(1.0 + sin(age * 9) * 0.09, 1.0 - sin(age * 9) * 0.09)
	elif profile.effect in ["hammer", "stomp", "eruption"]:
		visual.position.y = -sin(clampf(age / 0.35, 0, 1) * PI) * 14
	visual.queue_redraw()
	queue_redraw()

func _pixel(at: Vector2, extent: Vector2, color: Color) -> void:
	draw_rect(Rect2((at / 3.0).round() * 3.0, extent), color)

func _draw() -> void:
	if profile.get("ultimate", false):
		_draw_ultimate()
	if profile.is_empty() or age < 0.12:
		return
	var color: Color = profile.color
	var effect: String = profile.effect
	var direction := (impact_point - start_point).normalized()
	var cross := Vector2(-direction.y, direction.x)
	var t := clampf((age - 0.12) / 0.23, 0, 1)
	var head := start_point.lerp(impact_point, t) - global_position
	if profile.range == "ranged" and age < 0.35:
		match effect:
			"wave", "gust", "mist", "cloud":
				for i in 5:
					var width := 5.0 if effect == "gust" else 9.0
					var at := head + cross * (i - 2) * 7 - direction * absf(i - 2) * 4
					_pixel(at, Vector2(width, 8), color)
					_pixel(at - direction * 12, Vector2(5, 5), Color(color, 0.45))
			"fire", "drop", "dart":
				for i in 4:
					_pixel(head - direction * i * 7 + cross * sin(i * 2 + age * 12) * 3,
						Vector2(9 - i, 9 - i), color.darkened(i * 0.12))
				_pixel(head + Vector2(2, 2), Vector2(4, 4), color.lightened(0.6))
			"bubble", "foam", "twin":
				for i in (2 if effect == "twin" else 3):
					var at := head + cross * (i - 1) * 13 - direction * i * 8
					_pixel(at, Vector2(10, 10), color.darkened(0.25))
					_pixel(at + Vector2(1, 1), Vector2(5, 5), color.lightened(0.3))
			"bolt":
				var tail := start_point.lerp(impact_point, maxf(0, t - 0.2)) - global_position
				for i in 7:
					_pixel(tail.lerp(head, i / 6.0) + cross * (5 if i % 2 == 0 else -5), Vector2(5, 5), color)
			"spiral":
				for i in 7:
					_pixel(head + Vector2(12, 0).rotated(age * 12 + i * TAU / 7), Vector2(5, 5), color)
			"rain":
				for i in 3:
					_pixel(head + Vector2((i - 1) * 10, -sin(t * PI) * 35 + i * 8), Vector2(4, 11), color)
			_:
				var count := 3 if effect == "shard" else 1
				for i in count:
					var at := head + cross * (i - (count - 1) * 0.5) * 14
					_pixel(at, Vector2(9, 9), color)
					_pixel(at + Vector2(2, 2), Vector2(3, 3), color.lightened(0.4))
		return
	if age < 0.35:
		return
	var at := impact_point - global_position
	var fade := clampf(1.0 - (age - 0.35) / 0.27, 0, 1)
	color.a = fade
	match effect:
		"hammer", "stomp", "eruption":
			for i in 7:
				_pixel(at + Vector2((i - 3) * 7 * (2 - fade), 12 - absf(i - 3) * 2), Vector2(6, 4), color)
			_pixel(at + Vector2(-4, -22 * fade), Vector2(8, 20 * fade + 3), color.lightened(0.25))
		"ring", "shell":
			for i in 12:
				_pixel(at + Vector2(14 + (1 - fade) * 20, 0).rotated(i * TAU / 12), Vector2(4, 4), color)
		"slash", "cleave", "sweep":
			for i in 8:
				_pixel(at + Vector2((i - 4) * 4, (i - 4) * (-4 if effect == "slash" else 3)), Vector2(6, 6), color)
		"cube", "wall", "crystal", "shard", "cross":
			if effect in ["cube", "wall"]:
				_pixel(at - Vector2(9, 9) * fade, Vector2(18, 18) * fade, color.darkened(0.15))
				_pixel(at - Vector2(6, 6) * fade, Vector2(7, 5) * fade, color.lightened(0.4))
			for i in 5:
				_pixel(at + Vector2(12 + (1 - fade) * 15, 0).rotated(i * TAU / 5), Vector2(7, 7), color)
		"wave", "bubble", "foam", "drop", "rain":
			for i in 6:
				_pixel(at + Vector2((i - 3) * 8, -sin(i * 1.7) * 14 * (2 - fade)), Vector2(6, 6), color)
		_:
			for i in 8:
				_pixel(at + Vector2(12 + (1 - fade) * 18, 0).rotated(i * TAU / 8), Vector2(5, 5), color)

func _draw_ultimate() -> void:
	var at := impact_point - global_position
	var color: Color = profile.color
	var progress := clampf(age / 0.35, 0, 1)
	var impact := age >= 0.35
	var fade := 1.0 if not impact else clampf(1.0 - (age - 0.35) / 0.27, 0, 1)
	color.a = fade * (0.45 + progress * 0.55)
	# A stable target marker makes the intended recipient legible during windup.
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		_pixel(at + corner * 32, Vector2(7, 4), color)
	match str(profile.get("variant", profile.boss_kind)):
		"astral_storm":
			for ring in 3:
				for i in 9:
					var radius := (20 + ring * 13) * (1.2 - progress * 0.35) if not impact else (18 + ring * 13) * (2 - fade)
					var point := at + Vector2(radius, 0).rotated(-age * 9 + i * TAU / 9 + ring * 0.7)
					_pixel(point, Vector2(6, 9), color.lightened(ring * 0.12))
		"acid":
			# Telegraph above the victim, then a curtain of descending acid.
			for i in 7:
				var y := -55 + progress * 45 if not impact else -20 + (1 - fade) * 55
				_pixel(at + Vector2((i - 3) * 12, y - (i % 2) * 10), Vector2(5, 14), color)
		"base":
			# Three rotating bands contract into a neutralising vortex.
			for ring in 3:
				for i in 8:
					var radius := (18 + ring * 12) * (1.0 - progress * 0.3) if not impact else (20 + ring * 12) * (2 - fade)
					_pixel(at + Vector2(radius, 0).rotated(age * 7 + i * TAU / 8 + ring), Vector2(5, 5), color)
		"metal":
			# An overhead hammer falls; the ground cracks outward after contact.
			var hammer := at + Vector2(0, -70 * (1 - progress))
			_pixel(hammer + Vector2(-18, -9), Vector2(36, 16), color)
			_pixel(hammer + Vector2(-3, 7), Vector2(6, 20), color.darkened(0.2))
			if impact:
				for i in 10:
					_pixel(at + Vector2((i - 5) * 10 * (2 - fade), 28 + (i % 2) * 5), Vector2(7, 4), color)
		"salt":
			# Four growing crystal pillars close into a cage around the target.
			for i in 4:
				var p := at + Vector2((i - 1.5) * 18, 30)
				var h := 12 + progress * 58
				_pixel(p - Vector2(0, h), Vector2(7, h), color)
				_pixel(p - Vector2(-2, h + 4), Vector2(3, 6), color.lightened(0.4))
