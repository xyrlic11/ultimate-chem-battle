extends RefCounted

## Synergy ("สายพลัง") system -- the strategy layer, modelled on auto-battler
## trait systems like TFT's.
##
## A compound's traits come from `Recipes.traits_of()`: its primary kind plus
## any extra tags. Owning enough DIFFERENT compounds sharing a trait activates
## a team-wide bonus.
##
## COUNTING RULE: a trait counts UNIQUE compounds, not stack level. Three
## copies of HCl is still 1 toward กรด. This is deliberate and it is the
## tension that makes the roster interesting -- `Recipes.stack_*_multiplier`
## rewards going tall on one compound, traits reward going wide across many.
## The player has to choose. If stacks counted here, going tall would win on
## both axes and there would be no decision.
##
## Every numeric effect lives in the tier dictionaries below, so balancing is
## a matter of editing this table and nothing else. battle.gd reads them
## through `value()` and never hardcodes a number.

const Recipes := preload("res://scripts/recipes.gd")

const ORDER := ["acid", "base", "metal", "salt", "gas", "oxide", "alkali", "halogen"]

const TRAITS := {
	"acid": {
		"thai": "กรด",
		"color": Color(1.0, 0.55, 0.35),
		"desc": "กัดกร่อนรุนแรง เพิ่มความแรงการโจมตีให้ตัวสายกรด",
		"tiers": [
			{"count": 2, "dmg_bonus": 0.18, "text": "ตัวสายกรดโจมตีแรงขึ้น 18%"},
			{"count": 4, "dmg_bonus": 0.40, "text": "ตัวสายกรดโจมตีแรงขึ้น 40%"},
		],
	},
	"base": {
		"thai": "เบส",
		"color": Color(0.4, 0.65, 1.0),
		"desc": "สะเทินความเสียหาย ฟื้น HP ให้ทั้งทีมเป็นระยะ",
		"tiers": [
			{"count": 2, "heal_pct": 0.05, "heal_every": 3, "text": "ทั้งทีมฟื้น 5% ของ HP สูงสุด ทุก 3 ตา"},
			{"count": 4, "heal_pct": 0.11, "heal_every": 3, "text": "ทั้งทีมฟื้น 11% ของ HP สูงสุด ทุก 3 ตา"},
		],
	},
	"metal": {
		"thai": "โลหะ",
		"color": Color(0.75, 0.78, 0.86),
		"desc": "เนื้อแน่นทนทาน ลดความเสียหายที่ตัวสายโลหะได้รับ",
		"tiers": [
			{"count": 2, "dmg_reduction": 0.18, "text": "ตัวสายโลหะรับความเสียหายน้อยลง 18%"},
			{"count": 4, "dmg_reduction": 0.35, "text": "ตัวสายโลหะรับความเสียหายน้อยลง 35%"},
		],
	},
	"salt": {
		"thai": "เกลือ",
		"color": Color(0.75, 0.85, 0.55),
		"desc": "มีมูลค่าทางการค้า ได้เงินเพิ่มเมื่อชนะ",
		"tiers": [
			{"count": 2, "gold_bonus": 25, "text": "ชนะแล้วได้เงินเพิ่ม 25"},
			{"count": 3, "gold_bonus": 60, "text": "ชนะแล้วได้เงินเพิ่ม 60"},
		],
	},
	"gas": {
		"thai": "แก๊ส",
		"color": Color(0.6, 0.95, 0.85),
		"desc": "เบาและว่องไว ตัวสายแก๊สมีโอกาสโจมตีสองครั้ง",
		"tiers": [
			{"count": 2, "double_chance": 0.35, "text": "ตัวสายแก๊สมีโอกาส 35% โจมตีสองครั้ง"},
			{"count": 4, "double_chance": 1.0, "text": "ตัวสายแก๊สโจมตีสองครั้งเสมอ"},
		],
	},
	"oxide": {
		"thai": "ออกไซด์",
		"color": Color(1.0, 0.75, 0.45),
		"desc": "โครงสร้างเสถียร เพิ่ม HP ให้ตัวสายออกไซด์",
		"tiers": [
			{"count": 2, "hp_bonus": 0.20, "text": "ตัวสายออกไซด์มี HP เพิ่ม 20%"},
			{"count": 4, "hp_bonus": 0.45, "text": "ตัวสายออกไซด์มี HP เพิ่ม 45%"},
		],
	},
	# โลหะแอลคาไลทำปฏิกิริยารุนแรงมากกับน้ำ -- ระเบิดตอนตายจึงเป็นเอฟเฟกต์ที่
	# ตรงกับเคมีจริง ไม่ใช่แค่ใส่มาให้เท่
	"alkali": {
		"thai": "แอลคาไล",
		"color": Color(0.8, 0.55, 0.95),
		"desc": "ว่องไวต่อปฏิกิริยามาก ระเบิดใส่มอนสเตอร์เมื่อถูกทำลาย",
		"tiers": [
			{"count": 2, "death_blast": 14.0, "text": "ตัวสายแอลคาไลระเบิดใส่มอนสเตอร์ 14 หน่วยเมื่อตาย"},
			{"count": 3, "death_blast": 32.0, "text": "ตัวสายแอลคาไลระเบิดใส่มอนสเตอร์ 32 หน่วยเมื่อตาย"},
		],
	},
	"halogen": {
		"thai": "แฮโลเจน",
		"color": Color(0.45, 0.90, 0.45),
		"desc": "ไวต่อปฏิกิริยาสูง ทำให้มอนสเตอร์ติดสถานะกัดกร่อนต่อเนื่อง",
		"tiers": [
			{"count": 2, "corrosion": 3.0, "text": "มอนสเตอร์เสีย HP 3 หน่วยทุกตา"},
			{"count": 3, "corrosion": 7.0, "text": "มอนสเตอร์เสีย HP 7 หน่วยทุกตา"},
		],
	},
}

# --- placement ---------------------------------------------------------------
# Front-line units brace and gain HP; back-line units have room to work and gain
# damage. The monster hits the front row while anyone is standing there, so
# fielding nobody in front is a real glass-cannon option, not a free win --
# an empty front line means the back row is hit for extra damage.

const ROW_FRONT := "front"
const ROW_BACK := "back"
## Owned but not fielded. See GameState.field_limit().
const ROW_BENCH := "bench"

const FRONT_HP_BONUS := 0.30
const BACK_ATK_BONUS := 0.25
const EXPOSED_BACK_DMG_MULT := 1.5

## Turn order (Phase C, 2026-09-01): kind sets a fighter's base speed, "gas"
## overrides it regardless of kind -- H2S/NH3/SO2 are gas-tagged acid/base
## compounds, and this is what makes the gas TAG mean something in combat
## pacing without inventing a new rule. `neutral` (H2O, and the training-dummy
## monster) is placed slowest: it is not named in the owner's own speed order
## (which only covers 4 kinds + the gas trait), so this is an extrapolation --
## chosen because "neutral" already carries the weakest KIND_STATS.
const KIND_SPEED := {
	"acid": 4,
	"base": 3,
	"salt": 2,
	"metal": 1,
	"neutral": 0,
}
const GAS_SPEED_TIER := 5

static func speed_tier(kind: String, unit_traits: Array) -> int:
	if unit_traits.has("gas"):
		return GAS_SPEED_TIER
	return int(KIND_SPEED.get(kind, 0))


## Per-kind boss skills (2026-09-01 feedback): a boss's periodic heavy hit
## (see battle.gd's CHARGE_EVERY/_charging) does something extra, distinct
## per kind, instead of only a flat damage multiplier. `neutral` -- the
## wave-1 training dummy -- deliberately has none, same reason it is a soft
## intro fight in the first place.
const BOSS_SKILLS := {
	"acid": {
		"name": "กัดกร่อน", "icon": "☣",
		"desc": "ลดพลังโจมตีเป้าหมาย %d%% นาน %d ตา", "atk_debuff": 0.25, "turns": 2,
	},
	"base": {
		"name": "สะเทินกลับ", "icon": "💧",
		"desc": "บอสฟื้น HP ตัวเอง %d%% ของ HP สูงสุด", "self_heal": 0.06,
	},
	"metal": {
		"name": "ทะลุเกราะ", "icon": "⚙",
		"desc": "เจาะเกราะ ไม่โดนลดดาเมจจากสายโลหะ",
	},
	"salt": {
		"name": "ตรึงประจุ", "icon": "🔄",
		"desc": "ตรึงลำดับการโจมตีเป้าหมายให้ช้าที่สุดนาน %d ตา", "turns": 2,
	},
}

static func boss_skill(kind: String) -> Dictionary:
	return BOSS_SKILLS.get(kind, {})


## Full Thai description for the skill icon's tooltip, filled with the
## skill's own numbers plus the shared heavy-hit multiplier every kind uses.
static func boss_skill_text(kind: String, charge_mult: float) -> String:
	var skill: Dictionary = boss_skill(kind)
	if skill.is_empty():
		return ""
	var desc: String = skill.desc
	if skill.has("atk_debuff"):
		desc = desc % [roundi(float(skill.atk_debuff) * 100.0), int(skill.turns)]
	elif skill.has("self_heal"):
		desc = desc % roundi(float(skill.self_heal) * 100.0)
	elif skill.has("turns") and not skill.has("atk_debuff"):
		desc = desc % int(skill.turns)
	return "สกิลของบอส: %s — โจมตีแรง ×%.1f พร้อม%s" % [skill.name, charge_mult, desc]

## Bottom-right sell corner, in board pixels. The player specifically asked
## for bottom-right over "any edge" (2026-09 feedback) -- it is the one corner
## nothing else in the layout claims. Read by both board.gd (draws it) and
## main.gd (hit-tests a drop against it), same reason the fractions above are
## shared rather than duplicated.
const SELL_ZONE_SIZE := 110.0

const ROW_LABEL := {
	ROW_FRONT: "แถวหน้า",
	ROW_BACK: "แถวหลัง",
	ROW_BENCH: "สำรอง",
}


## trait id -> number of DISTINCT compounds carrying it.
##
## Callers pass the FIELDED roster, not everything owned. That is what makes a
## synergy cost something: every slot spent on a compound that only completes a
## breakpoint is a slot not spent on raw power. Counting the whole roster made
## synergies free, and free bonuses are not decisions.
static func trait_counts(roster: Dictionary, bonus: Dictionary = {}) -> Dictionary:
	var counts := {}
	for formula in roster.keys():
		for t in _entry_traits(formula, roster[formula]):
			counts[t] = int(counts.get(t, 0)) + 1
	for trait_key in bonus:
		if counts.has(trait_key):
			counts[trait_key] += int(bonus[trait_key])
	return counts


## trait id -> highest tier reached, 1-based. Absent means inactive.
## Only traits that actually hit a breakpoint appear, so callers can treat a
## missing key as "off" without checking for zero.
static func active_tiers(roster: Dictionary, bonus: Dictionary = {}) -> Dictionary:
	var counts := trait_counts(roster, bonus)
	var active := {}
	for trait_id in counts.keys():
		var tier := tier_for_count(trait_id, int(counts[trait_id]))
		if tier > 0:
			active[trait_id] = tier
	return active


static func tier_for_count(trait_id: String, count: int) -> int:
	var info: Dictionary = TRAITS.get(trait_id, {})
	var tiers: Array = info.get("tiers", [])
	var reached := 0
	for i in tiers.size():
		if count >= int(tiers[i]["count"]):
			reached = i + 1
	return reached


## Read a balance number for a trait at its currently active tier.
## Returns `fallback` when the trait is inactive or that tier defines no such
## key, so battle.gd can call this unconditionally.
static func value(active: Dictionary, trait_id: String, key: String, fallback := 0.0) -> float:
	if not active.has(trait_id):
		return fallback
	var tier := int(active[trait_id])
	var tiers: Array = TRAITS.get(trait_id, {}).get("tiers", [])
	if tier < 1 or tier > tiers.size():
		return fallback
	return float(tiers[tier - 1].get(key, fallback))


## Count needed for the next breakpoint, or 0 when already maxed. Used by the
## synergy panel to show "อีก 1 ตัว" style progress.
static func next_threshold(trait_id: String, count: int) -> int:
	var tiers: Array = TRAITS.get(trait_id, {}).get("tiers", [])
	for t in tiers:
		if count < int(t["count"]):
			return int(t["count"])
	return 0


static func thresholds_text(trait_id: String) -> String:
	var tiers: Array = TRAITS.get(trait_id, {}).get("tiers", [])
	var parts: Array = []
	for t in tiers:
		parts.append(str(int(t["count"])))
	return "/".join(parts)


static func label_of(trait_id: String) -> String:
	return TRAITS.get(trait_id, {}).get("thai", trait_id)


static func color_of(trait_id: String) -> Color:
	return TRAITS.get(trait_id, {}).get("color", Color.WHITE)


## Human-readable description of the tier currently active (empty when off).
static func active_text(trait_id: String, tier: int) -> String:
	var tiers: Array = TRAITS.get(trait_id, {}).get("tiers", [])
	if tier < 1 or tier > tiers.size():
		return ""
	return str(tiers[tier - 1].get("text", ""))


## Traits stored on a roster entry. Older saves (and any entry written before
## traits existed) have no `traits` key, so fall back to deriving them from the
## recipe table by formula -- an entry should never silently count for nothing.
static func _entry_traits(formula: String, entry: Dictionary) -> Array:
	var stored = entry.get("traits", null)
	if stored is Array and not (stored as Array).is_empty():
		return stored
	# A REAL fallback, not a comment promising one. A roster dict built
	# outside GameState -- tools/sim_balance.gd does exactly that -- has no
	# traits on its entries, and returning [] made those compounds count
	# toward nothing with nothing raised anywhere.
	var recipe = Recipes.find_by_formula(formula)
	if recipe != null:
		return Recipes.traits_of_recipe(recipe)
	return []

