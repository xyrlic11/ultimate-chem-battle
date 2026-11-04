extends RefCounted
const VERSION := 2
const STAGES_PER_REGION := 5
const BOSS_COUNT := 5
const FINAL_WAVE := STAGES_PER_REGION * BOSS_COUNT
const BOSSES := {
	5: {"formula": "HCl", "name": "กรดไฮโดรคลอริก", "kind": "acid", "ultimate": "ฝนกัดกร่อน"},
	10: {"formula": "NaOH", "name": "โซเดียมไฮดรอกไซด์", "kind": "base", "ultimate": "วังวนสะเทิน"},
	15: {"formula": "Fe2O3", "name": "เหล็ก(III)ออกไซด์", "kind": "metal", "ultimate": "ค้อนทะลุเกราะ"},
	20: {"formula": "NaCl", "name": "โซเดียมคลอไรด์", "kind": "salt", "ultimate": "คุกผลึก"},
	25: {"formula": "H2SO3", "name": "กรดซัลฟิวรัส", "kind": "acid", "ultimate": "พายุดารากัดกร่อน"},
}
static func is_boss(wave: int) -> bool:
	return BOSSES.has(wave)
static func enemy(wave: int, kind: String) -> Dictionary:
	if BOSSES.has(wave):
		return BOSSES[wave].duplicate()
	var formula: String = {"acid": "H2S", "base": "NH3", "metal": "Cu2", "salt": "KCl", "neutral": "H2O"}.get(kind, "H2O")
	var recipe = preload("res://scripts/recipes.gd").find_by_formula(formula)
	return {"formula": formula, "name": recipe.thai, "kind": kind, "ultimate": ""}

static func migrate_stage(stage: int, version: int) -> int:
	if version >= VERSION:
		return clampi(stage, 1, FINAL_WAVE)
	var old := clampi(stage, 1, 16)
	var region := int((old - 1) / 4)
	var local := (old - 1) % 4 + 1
	return region * STAGES_PER_REGION + (STAGES_PER_REGION if local == 4 else local)
