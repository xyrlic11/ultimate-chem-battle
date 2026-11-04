extends RefCounted
static func profile(kind: String, ultimate: bool, formula := "") -> Dictionary:
	var effect: String = {"acid": "drop", "base": "bubble", "metal": "hammer", "salt": "crystal"}.get(kind, "wave")
	if ultimate:
		effect = {"acid": "rain", "base": "spiral", "metal": "eruption", "salt": "shard"}.get(kind, effect)
	var variant := "astral_storm" if formula == "H2SO3" and ultimate else kind
	return {"variant": variant, "range": "melee" if kind == "metal" and not ultimate else "ranged", "effect": effect,
		"color": preload("res://scripts/recipes.gd").KIND_COLOR.get(kind, Color.WHITE),
		"ultimate": ultimate, "boss_kind": kind}
