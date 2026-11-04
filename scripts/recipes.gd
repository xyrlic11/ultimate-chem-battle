extends RefCounted

## Static data table for elements, bonding recipes, shop costs, and
## Auto-Battle type stats (proposal section 3.1 L5-1/L5-2, section 3.3 M1-M5).
##
## TWO LAYERS sit on top of every compound and it is important not to confuse
## them:
##
##   * `kind`  -- the PRIMARY class. Drives base stats and the acid/metal/base
##                type triangle. Exactly one per compound.
##   * traits  -- the SYNERGY tags (see traits.gd). A compound's full trait
##                list is `[kind] + extra_traits`, so the class tags are never
##                written twice and can never drift out of sync.
##
## Only declare `traits` in a recipe for tags BEYOND its kind (gas, oxide,
## alkali, halogen). Writing "acid" in the traits list of an acid is redundant
## and `traits_of()` would just dedupe it anyway.

const NOBLE_GROUP := 18

## `group` is the real periodic-table group. `alkali` is tracked separately and
## deliberately NOT derived from `group == 1`, because hydrogen sits in group 1
## but is emphatically not an alkali metal -- deriving it would teach students
## something false.
##
## `valence` (outer-shell electrons) is written out per element for the same
## reason, and it is the more dangerous of the two to compute. The obvious rule
## -- `group` for groups 1-2, `group - 10` above that -- gets two cases wrong
## in this very table:
##
##   * He is in group 18 but has **2** valence electrons, not 8. Its shell is
##     the K shell, which is full at two (the duet rule). The octet rule simply
##     does not apply to it.
##   * Fe and Cu are transition metals. Their valence is variable (Fe is
##     commonly 2 or 3, Cu 1 or 2), so there is no single honest number. They
##     carry NO `valence` key, and atom.gd draws no electron dots for them
##     rather than inventing a count. `valence_of()` returns -1 for these.
##
## Getting this wrong would not crash anything -- it would just quietly teach
## chemistry that is false, which for this game is the worse failure.
const ELEMENTS := {
	"H":  {"name": "Hydrogen",  "thai": "ไฮโดรเจน", "color": Color(0.90, 0.95, 1.00), "group": 1, "valence": 1},
	"O":  {"name": "Oxygen",    "thai": "ออกซิเจน", "color": Color(1.00, 0.35, 0.35), "group": 16, "valence": 6},
	"Na": {"name": "Sodium",    "thai": "โซเดียม",  "color": Color(0.65, 0.45, 1.00), "group": 1, "alkali": true, "metal": true, "valence": 1},
	"Cl": {"name": "Chlorine",  "thai": "คลอรีน",   "color": Color(0.45, 0.90, 0.45), "group": 17, "halogen": true, "valence": 7},
	"Fe": {"name": "Iron",      "thai": "เหล็ก",     "color": Color(0.75, 0.78, 0.86), "group": 8, "metal": true},
	"He": {"name": "Helium",    "thai": "ฮีเลียม",   "color": Color(0.75, 0.75, 0.80), "group": 18, "valence": 2},
	"C":  {"name": "Carbon",    "thai": "คาร์บอน",  "color": Color(0.35, 0.35, 0.40), "group": 14, "valence": 4},
	"N":  {"name": "Nitrogen",  "thai": "ไนโตรเจน", "color": Color(0.45, 0.60, 0.95), "group": 15, "valence": 5},
	"S":  {"name": "Sulfur",    "thai": "กำมะถัน",  "color": Color(0.95, 0.85, 0.30), "group": 16, "valence": 6},
	"Ca": {"name": "Calcium",   "thai": "แคลเซียม", "color": Color(0.95, 0.90, 0.80), "group": 2, "metal": true, "valence": 2},
	"Mg": {"name": "Magnesium", "thai": "แมกนีเซียม", "color": Color(0.80, 0.88, 0.75), "group": 2, "metal": true, "valence": 2},
	"K":  {"name": "Potassium", "thai": "โพแทสเซียม", "color": Color(0.80, 0.55, 0.95), "group": 1, "alkali": true, "metal": true, "valence": 1},
	"Cu": {"name": "Copper",    "thai": "ทองแดง",   "color": Color(0.85, 0.55, 0.35), "group": 11, "metal": true},
}

# Shop price per atom (gold). Mid/late-game elements (e.g. transition metals)
# cost more, per proposal A3 learning-progression scaffolding.
const COSTS := {
	"H": 5, "O": 6, "Na": 8, "Cl": 8, "Fe": 14, "He": 4,
	"C": 7, "N": 7, "S": 7, "Ca": 9, "Mg": 9, "K": 8, "Cu": 12,
}

# key = comma-joined, sorted element symbols. value = resulting compound.
#
# Atom counts are kept to 2-5 so a recipe stays draggable on the board. Where
# real stoichiometry would need more atoms than that, a compound with the same
# chemistry lesson but a smaller formula was chosen instead -- with two
# knowing exceptions, Fe2 and Cu2, which are plain metal ingots rather than
# real molecules and exist to populate the โลหะ synergy.
const RECIPES := {
	# --- กรด (acids) ---
	"Cl,H":       {"formula": "HCl",   "name": "Hydrochloric Acid",  "thai": "กรดไฮโดรคลอริก",  "kind": "acid",    "traits": ["halogen"]},
	"H,H,S":      {"formula": "H2S",   "name": "Hydrogen Sulfide",   "thai": "ไฮโดรเจนซัลไฟด์", "kind": "acid",    "traits": ["gas"]},

	# --- เบส (bases) ---
	"H,Na,O":     {"formula": "NaOH",  "name": "Sodium Hydroxide",   "thai": "โซดาไฟ",          "kind": "base",    "traits": ["alkali"]},
	"H,K,O":      {"formula": "KOH",   "name": "Potassium Hydroxide","thai": "โพแทสเซียมไฮดรอกไซด์", "kind": "base", "traits": ["alkali"]},
	"H,H,H,N":    {"formula": "NH3",   "name": "Ammonia",            "thai": "แอมโมเนีย",       "kind": "base",    "traits": ["gas"]},
	"Ca,O":       {"formula": "CaO",   "name": "Quicklime",          "thai": "ปูนดิบ",          "kind": "base",    "traits": ["oxide"]},

	# --- เกลือ (salts) ---
	"Cl,Na":      {"formula": "NaCl",  "name": "Sodium Chloride",    "thai": "เกลือแกง",        "kind": "salt",    "traits": ["alkali", "halogen"]},
	"Cl,K":       {"formula": "KCl",   "name": "Potassium Chloride", "thai": "โพแทสเซียมคลอไรด์", "kind": "salt",  "traits": ["alkali", "halogen"]},
	"Ca,Cl,Cl":   {"formula": "CaCl2", "name": "Calcium Chloride",   "thai": "แคลเซียมคลอไรด์", "kind": "salt",    "traits": ["halogen"]},

	# --- โลหะ (metals) ---
	"Fe,Fe":      {"formula": "Fe2",   "name": "Iron Bar",           "thai": "แท่งเหล็ก",       "kind": "metal",   "traits": []},
	"Cu,Cu":      {"formula": "Cu2",   "name": "Copper Bar",         "thai": "แท่งทองแดง",      "kind": "metal",   "traits": []},
	"Fe,S":       {"formula": "FeS",   "name": "Iron(II) Sulfide",   "thai": "ไอร์ออนซัลไฟด์",  "kind": "metal",   "traits": []},
	"Mg,O":       {"formula": "MgO",   "name": "Magnesium Oxide",    "thai": "แมกนีเซียมออกไซด์", "kind": "metal", "traits": ["oxide"]},
	"Cu,O":       {"formula": "CuO",   "name": "Copper(II) Oxide",   "thai": "คอปเปอร์ออกไซด์", "kind": "metal",   "traits": ["oxide"]},

	# --- เป็นกลาง / แก๊ส (neutral & gases) ---
	"H,H,O":      {"formula": "H2O",   "name": "Water",              "thai": "น้ำ",             "kind": "neutral", "traits": ["oxide"]},
	"H,H":        {"formula": "H2",    "name": "Hydrogen Gas",       "thai": "แก๊สไฮโดรเจน",    "kind": "neutral", "traits": ["gas"]},
	"O,O":        {"formula": "O2",    "name": "Oxygen Gas",         "thai": "แก๊สออกซิเจน",    "kind": "neutral", "traits": ["gas"]},
	"N,N":        {"formula": "N2",    "name": "Nitrogen Gas",       "thai": "แก๊สไนโตรเจน",    "kind": "neutral", "traits": ["gas"]},
	"C,H,H,H,H":  {"formula": "CH4",   "name": "Methane",            "thai": "มีเทน",           "kind": "neutral", "traits": ["gas"]},
	"C,O,O":      {"formula": "CO2",   "name": "Carbon Dioxide",     "thai": "คาร์บอนไดออกไซด์", "kind": "neutral","traits": ["gas", "oxide"]},
	"O,O,S":      {"formula": "SO2",   "name": "Sulfur Dioxide",     "thai": "ซัลเฟอร์ไดออกไซด์", "kind": "acid",  "traits": ["gas", "oxide"]},
}

# --- tier-2 reactions ---------------------------------------------------------
#
# Compound + compound, the "component -> completed item" half of the TFT
# fantasy. Key = the two source formulas, sorted and comma-joined.
#
# Every one of these is a reaction a chemistry student will actually meet:
# neutralisation, acid rain forming in the atmosphere, slaking lime, iron
# rusting. That is the point -- tier 2 is where the game stops being "match the
# symbols" and starts being "this is what those substances do to each other".
#
# Products carry `tier: 2`, which buys a flat stat multiplier in battle.gd.
# Without it a tier-2 compound would cost two finished compounds and field a
# unit no stronger than either, and nobody would ever make one.
## KNOWN CEILING, recorded rather than worked around: one reaction here produces
## exactly one product. Most reactions worth teaching produce two -- combustion,
## neutralisation, single displacement -- and this table papers over that by
## writing "+ น้ำ" into a `note` string that nothing reads back. Adding more
## recipe entries does not lift this; supporting multiple products does. Until
## then, prefer reactions whose second product can honestly be ignored.
const TIER2_RECIPES := {
	# กรด + เบส -> เกลือ + น้ำ. The single most-taught reaction in the syllabus.
	"HCl,NaOH":  {"formula": "NaCl", "name": "Sodium Chloride", "thai": "เกลือแกง (จากปฏิกิริยาสะเทิน)", "kind": "salt", "traits": ["alkali", "halogen"], "tier": 2, "note": "ปฏิกิริยาสะเทิน: กรด + เบส -> เกลือ + น้ำ"},
	"HCl,KOH":   {"formula": "KCl",  "name": "Potassium Chloride", "thai": "โพแทสเซียมคลอไรด์", "kind": "salt", "traits": ["alkali", "halogen"], "tier": 2, "note": "ปฏิกิริยาสะเทิน: กรด + เบส -> เกลือ + น้ำ"},

	# แก๊สละลายน้ำกลายเป็นกรด -- นี่คือกลไกของฝนกรด
	"CO2,H2O":   {"formula": "H2CO3", "name": "Carbonic Acid", "thai": "กรดคาร์บอนิก", "kind": "acid", "traits": ["oxide"], "tier": 2, "note": "CO₂ ละลายน้ำได้กรดคาร์บอนิก — กลไกเดียวกับฝนกรด"},
	"H2O,SO2":   {"formula": "H2SO3", "name": "Sulfurous Acid", "thai": "กรดซัลฟิวรัส", "kind": "acid", "traits": ["oxide"], "tier": 2, "note": "SO₂ จากการเผาไหม้ + น้ำ = ฝนกรด"},

	# ปูนดิบ + น้ำ -> ปูนขาว (คายความร้อนแรงมาก)
	"CaO,H2O":   {"formula": "CaOH2", "name": "Slaked Lime", "thai": "ปูนขาว", "kind": "base", "traits": ["alkali"], "tier": 2, "note": "ปูนดิบ + น้ำ -> ปูนขาว คายความร้อนสูง"},

	# แอมโมเนีย + กรดเกลือ -> ควันขาว
	"HCl,NH3":   {"formula": "NH4Cl", "name": "Ammonium Chloride", "thai": "แอมโมเนียมคลอไรด์", "kind": "salt", "traits": ["halogen"], "tier": 2, "note": "แก๊สสองชนิดพบกันเกิดควันสีขาว"},

	# เหล็กเป็นสนิม
	"Fe2,O2":    {"formula": "Fe2O3", "name": "Iron(III) Oxide", "thai": "สนิมเหล็ก", "kind": "metal", "traits": ["oxide"], "tier": 2, "note": "เหล็ก + ออกซิเจน -> สนิม"},
}

## Stat multiplier for a tier-2 compound. It costs two finished compounds, so it
## has to be worth clearly more than either of them alone.
const TIER2_STAT_BONUS := 1.6


## Looks up a compound-plus-compound reaction, or null.
static func find_tier2(formula_a: String, formula_b: String):
	var pair := [formula_a, formula_b]
	pair.sort()
	return TIER2_RECIPES.get(",".join(pair), null)


## True when `formula` can only be produced by a tier-2 reaction. Used by the
## recipe book, which otherwise has no way to show these.
static func is_tier2_product(formula: String) -> bool:
	for key in TIER2_RECIPES.keys():
		if TIER2_RECIPES[key].formula == formula:
			return true
	return false


# Auto-Battle (proposal 3.1 L5-2): each compound "kind" gets base HP/ATK.
# Type triangle -- Acid beats Metal, Metal beats Base, Base beats Acid.
# Salt/neutral compounds sit outside the triangle: no bonus given or taken.
## HP was multiplied by 2.5 after simulating a few hundred battles
## (tools/sim_balance.gd). At the old values a fight lasted 2-9 ticks -- two to
## eight seconds -- and a full board erased a wave-1 monster in barely two.
## The auto-battle is the payoff for everything decided in the shop, and it was
## over before the player could watch it.
##
## Only HP moved. Raising HP on both sides lengthens fights without touching
## who wins, because the monster's HP is derived from this same table; nudging
## ATK instead would have shifted every win rate at once.
const KIND_STATS := {
	"acid":    {"hp": 75, "atk": 11},
	"base":    {"hp": 85, "atk": 10},
	"metal":   {"hp": 105, "atk": 9},
	"salt":    {"hp": 70, "atk": 8},
	"neutral": {"hp": 60, "atk": 7},
}

const TYPE_ADVANTAGE := {
	"acid": "metal",
	"metal": "base",
	"base": "acid",
}

const KIND_LABEL := {
	"acid": "กรด",
	"base": "เบส",
	"metal": "โลหะ",
	"salt": "เกลือ",
	"neutral": "เป็นกลาง",
}

# Single source of truth for kind colors -- shared by molecule.gd (board
# tiles), battle.gd (fighter chips) and main.gd (team panel).
const KIND_COLOR := {
	"acid": Color(1.0, 0.55, 0.35),
	"base": Color(0.4, 0.65, 1.0),
	"metal": Color(0.75, 0.78, 0.86),
	"salt": Color(0.75, 0.85, 0.55),
	"neutral": Color(0.85, 0.85, 0.9),
}

# Re-crafting a compound you already own stacks/levels it up instead of
# piling on another separate fighter (keeps the roster from growing
# unbounded and rewards committing to a build).
static func stack_hp_multiplier(count: int) -> float:
	return 1.0 + 0.5 * float(count - 1)

static func stack_atk_multiplier(count: int) -> float:
	return 1.0 + 0.35 * float(count - 1)

static func make_key(symbols: Array) -> String:
	var arr := symbols.duplicate()
	arr.sort()
	return ",".join(arr)

## Explicit flag, never derived from `group` -- hydrogen sits in group 1 and is
## not a metal, and deriving it would teach that it is. Same reasoning as
## `alkali` and `halogen` (CLAUDE.md rule 4).
static func is_metal(symbol: String) -> bool:
	return bool(ELEMENTS.get(symbol, {}).get("metal", false))


## Which kind of bond a set of symbols forms. This is the real classification a
## student is taught, and it drives what the bonding animation shows:
##
##   metal + non-metal  -> ionic     (electrons are TRANSFERRED, ions form)
##   non-metal + non-metal -> covalent  (electrons are SHARED)
##   metal + metal      -> metallic  (a sea of delocalised electrons)
##
## The metallic case is not a technicality here: Fe2 and Cu2 are real entries in
## the recipe table, and calling them ionic or covalent would be wrong on screen
## in a game whose whole subject is bonding.
static func bond_type(symbols: Array) -> String:
	var has_metal := false
	var has_nonmetal := false
	for s in symbols:
		if is_metal(s):
			has_metal = true
		else:
			has_nonmetal = true
	if has_metal and has_nonmetal:
		return "ionic"
	if has_metal:
		return "metallic"
	return "covalent"


## Thai name of a bond type, for the label the bonding animation shows.
const BOND_LABEL := {
	"ionic": "พันธะไอออนิก",
	"covalent": "พันธะโคเวเลนต์",
	"metallic": "พันธะโลหะ",
}


## The one-line lesson shown while a bond forms, COMPOSED rather than stored.
##
## Writing 21 of these into the recipe table by hand would drift away from
## bond_type() the first time an element was reclassified, and a chemistry game
## that contradicts itself on screen is worse than one that says nothing. Built
## from the same flags the animation itself reads, so the two cannot disagree.
static func bond_lesson(symbols: Array) -> String:
	var kind := bond_type(symbols)
	var metals: Array = []
	var others: Array = []
	for s in symbols:
		var thai: String = str(ELEMENTS.get(s, {}).get("thai", s))
		var bucket: Array = metals if is_metal(s) else others
		if not bucket.has(thai):
			bucket.append(thai)

	var body := ""
	match kind:
		"ionic":
			body = "%sให้อิเล็กตรอนแก่%s กลายเป็นไอออน" % [
				"และ".join(metals), "และ".join(others)]
		"metallic":
			body = "%sใช้อิเล็กตรอนร่วมกันเป็นทะเลอิเล็กตรอน" % "และ".join(metals)
		_:
			# H + H is one distinct element bonding with itself, and "ไฮโดรเจนใช้
			# อิเล็กตรอนร่วมกัน" reads as though it shares with nobody.
			if others.size() == 1:
				body = "อะตอม%sใช้อิเล็กตรอนร่วมกัน" % others[0]
			else:
				body = "%sใช้อิเล็กตรอนร่วมกัน" % "กับ".join(others)
	return "%s · %s" % [BOND_LABEL.get(kind, kind), body]


static func is_noble(symbol: String) -> bool:
	return ELEMENTS.get(symbol, {}).get("group", 0) == NOBLE_GROUP


## Outer-shell electrons, or -1 when there is no single honest answer (the
## transition metals). Callers must handle -1 by drawing/saying nothing rather
## than falling back to a guess -- see the note above ELEMENTS.
static func valence_of(symbol: String) -> int:
	return int(ELEMENTS.get(symbol, {}).get("valence", -1))


## True when the outer shell is already full, so the atom will not bond.
## Helium is full at 2 (duet), everything else in this table at 8 (octet) --
## which is exactly why `valence` is stored rather than computed.
static func shell_is_full(symbol: String) -> bool:
	var v := valence_of(symbol)
	if v < 0:
		return false
	return v == (2 if symbol == "He" else 8)

## formula -> the sorted element list it is built from, e.g. "H2O" -> [H,H,O].
## Built once from RECIPES so it can never disagree with it.
static var _composition: Dictionary = {}


static func atoms_of(formula: String) -> Array:
	if _composition.is_empty():
		for key in RECIPES.keys():
			_composition[RECIPES[key].formula] = key.split(",")
	var found = _composition.get(formula, null)
	return (found as Array).duplicate() if found != null else []


## What a whole cluster makes, whatever it is made of.
##
## The board used to run two assembly systems that never met: atoms + atoms, and
## compound + compound. Nothing bridged them, so making H2 first was a permanent
## dead end for water -- the player had built the right atoms and the game had no
## way to express it. This is the bridge.
##
## `parts` is one entry per thing in the cluster: {"formula": String or "",
## "atoms": Array}. A loose atom carries an empty formula.
##
## Order of attempts matters:
##   1. tier-2, for the two compounds whose recipe is NOT atom-conserving in
##      this game's simplification (HCl + NaOH -> NaCl drops the water)
##   2. an exact atom match
##   3. a whole-number multiple -- 2H2 + O2 -> 2 H2O is the reaction every
##      chemistry course opens with, and it cannot be expressed any other way
##
## Returns {} for no reaction, else {key, recipe, count, tier}.
## What a cluster makes, and WHICH of its members are actually involved.
##
## A single stray atom used to kill every tier-2 reaction outright: HCl + NaOH
## works, HCl + NaOH + H is silence, and the player is told something about
## valence that has nothing to do with it. That matters more than it sounds,
## because _get_cluster() is transitive and grow(-16) is generous, and the
## opening lesson leaves three atoms lying on the board -- so a bystander tile
## joins the group constantly and invisibly. A bug that fires sometimes is worse
## than one that fires always: the consistent one can at least be learned.
##
## So when the whole group matches nothing, the largest subgroup that DOES match
## reacts and the rest stays on the board. That is not a leniency bolted on, it
## is excess reagent -- a real reaction consumes what it needs and leaves the
## surplus, which is on the syllabus already.
##
## Adds "used": the indices that reacted, so the caller consumes only those.
static func match_cluster(parts: Array, required: Array = []) -> Dictionary:
	var n: int = parts.size()
	if n == 0:
		return {}

	var whole: Dictionary = _match_whole(parts)
	if not whole.is_empty():
		var every: Array = []
		for i in n:
			every.append(i)
		whole["used"] = every
		return whole

	# 2^n over a cluster nobody can physically stack higher than a handful. The
	# cap is there so a pathological board cannot hang the frame.
	if n < 3 or n > 8:
		return {}

	# Every viable subgroup is scored, rather than taking the first big one that
	# happens to work. Counting tiles alone chose 2 x H2 over H2O for four
	# hydrogens and an oxygen, because four tiles beat three -- and nobody who
	# piles four H onto an O wants hydrogen gas.
	var best: Dictionary = {}
	var best_score: Array = []
	for mask in range(1, 1 << n):
		var idx: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
		if idx.size() < 2:
			continue

		# The pieces the player actually just put together are not optional. Left
		# out, dragging Na onto Cl beside a stray H and O produced NaOH: the
		# reaction they aimed at was not even in the running.
		var honours := true
		for r in required:
			if not idx.has(r):
				honours = false
				break
		if not honours:
			continue

		var sub: Array = []
		for i in idx:
			sub.append(parts[i])
		var hit: Dictionary = _match_whole(sub)
		if hit.is_empty():
			continue

		# More DISTINCT elements wins, then more pieces. "The reaction that brings
		# more different elements together happens first" is both the rule that
		# picks water over hydrogen gas and a sentence a student can be told.
		var kinds: Array = []
		for p in sub:
			for s in p.get("atoms", []):
				if not kinds.has(s):
					kinds.append(s)
		var score: Array = [kinds.size(), idx.size()]
		if best.is_empty() or score > best_score:
			best_score = score
			hit["used"] = idx
			best = hit
	return best


static func _match_whole(parts: Array) -> Dictionary:
	var formulas: Array = []
	var atoms: Array = []
	for p in parts:
		var f: String = str(p.get("formula", ""))
		if f != "":
			formulas.append(f)
		atoms.append_array(p.get("atoms", []))
	atoms.sort()
	if atoms.is_empty():
		return {}

	if formulas.size() == 2 and parts.size() == 2:
		var t2 = find_tier2(formulas[0], formulas[1])
		if t2 != null:
			var pair: Array = formulas.duplicate()
			pair.sort()
			return {"key": ",".join(pair), "recipe": t2, "count": 1, "tier": 2}

	var exact_key := make_key(atoms)
	if RECIPES.has(exact_key) and not formulas.has(str(RECIPES[exact_key].formula)):
		return {"key": exact_key, "recipe": RECIPES[exact_key], "count": 1, "tier": 1}

	for key in RECIPES.keys():
		var unit: Array = key.split(",")
		if unit.size() == 0 or atoms.size() % unit.size() != 0:
			continue
		var n: int = atoms.size() / unit.size()
		if n < 2:
			continue
		var want: Array = []
		for _i in n:
			want.append_array(unit)
		want.sort()
		if want != atoms:
			continue
		# Reject the no-ops. Without this, H2 + H2 -> 2 H2 "reacts", and so do
		# forty-odd other pairs that produce exactly what was put in.
		if formulas.has(str(RECIPES[key].formula)):
			continue
		return {"key": key, "recipe": RECIPES[key], "count": n, "tier": 1}

	return {}


## The closest reaction the player was reaching for, when nothing fired.
##
## "ผสมไม่ถูกสูตร ลองสูตรอื่นดูนะ" taught nothing and turned experimenting into
## buying elements at random until the gold ran out. Everything needed to do
## better was already here: expand to atoms, find the recipe whose Nx form the
## player's atoms are a SUBSET of, and name what is missing.
##
## Returns {"kind": "noop"|"missing"|"none", ...}:
##   noop     an exact Nx match whose product is already one of the inputs
##   missing  {key, count, missing: {symbol: n}} -- what to add and what it makes
##   none     no recipe uses these atoms at all
static func nearest_reaction(parts: Array) -> Dictionary:
	var formulas: Array = []
	var atoms: Array = []
	for p in parts:
		var f: String = str(p.get("formula", ""))
		if f != "":
			formulas.append(f)
		atoms.append_array(p.get("atoms", []))
	if atoms.is_empty():
		return {"kind": "none"}

	var have: Dictionary = _tally(atoms)
	var present: Array = have.keys()
	var best: Dictionary = {}
	var best_score: Array = []
	var noop: Dictionary = {}

	for key in RECIPES.keys():
		var unit: Dictionary = _tally(key.split(","))
		for n in range(1, 5):
			var missing: Dictionary = {}
			var short := 0
			var fits := true
			for sym in have.keys():
				if int(have[sym]) > int(unit.get(sym, 0)) * n:
					fits = false
					break
			if not fits:
				continue
			for sym in unit.keys():
				var gap: int = int(unit[sym]) * n - int(have.get(sym, 0))
				if gap > 0:
					missing[sym] = gap
					short += gap

			if short == 0:
				# An exact multiple that match_cluster() already refused, which it
				# only does when the product is one of the things put in.
				# Remembered, not returned. A no-op is a dead end, so it is only
				# worth saying when there is no reachable reaction to point at
				# instead: O2 + O2 is literally 2 x O2, but "add 2 carbon and you
				# get CO2" is the answer the player can act on.
				if formulas.has(str(RECIPES[key].formula)) and noop.is_empty():
					noop = {"kind": "noop", "key": key, "count": n,
						"formula": RECIPES[key].formula, "thai": RECIPES[key].thai}
				continue

			# Never suggest topping up toward something already on the board:
			# "add 2 more O and you get 3 x O2" is a no-op wearing the costume of
			# advice. Only the exact-match branch above may name such a recipe,
			# and only to say that nothing new happens.
			if formulas.has(str(RECIPES[key].formula)):
				continue

			# Penalise a suggestion that needs an element the player is not already
			# holding. Without this H2 + O2 answers "add 2 Na and you get NaOH" --
			# technically true, useless as teaching, and it walks them away from the
			# water they were obviously reaching for.
			var foreign := 0
			for sym in missing.keys():
				if not present.has(sym):
					foreign += 1
			# "You are close" has to mean close. Needing a lot of an element that is
			# not on the board at all is a different reaction, not a nudge: H2O +
			# H2O otherwise answered "add four sodium and two oxygen for NaOH".
			# A big shortfall in something already present is fine -- that is the
			# Haber case, N2 + H2 needing four more H.
			if foreign > 0 and short * 2 > atoms.size():
				continue

			var score: Array = [foreign, short, n]
			if best.is_empty() or score < best_score:
				best_score = score
				best = {"kind": "missing", "key": key, "count": n, "missing": missing,
					"formula": RECIPES[key].formula, "thai": RECIPES[key].thai}

	if not best.is_empty():
		return best
	if not noop.is_empty():
		return noop
	return {"kind": "none"}


static func _tally(symbols: Array) -> Dictionary:
	var out: Dictionary = {}
	for s in symbols:
		out[s] = int(out.get(s, 0)) + 1
	return out


static func find_recipe(symbols: Array):
	var key := make_key(symbols)
	return RECIPES.get(key, null)

static func cost_of(symbol: String) -> int:
	return COSTS.get(symbol, 10)

static func beats(attacker_kind: String, defender_kind: String) -> bool:
	return TYPE_ADVANTAGE.get(attacker_kind, "") == defender_kind


## Full synergy tag list for a compound: primary kind first, then extras.
## "neutral" is a stat class, not a synergy, so it never becomes a trait --
## otherwise every filler gas would count toward a bonus for being unremarkable.
static func traits_of(kind: String, extra_traits: Array) -> Array:
	var out: Array = []
	if kind != "neutral":
		out.append(kind)
	for t in extra_traits:
		if not out.has(t):
			out.append(t)
	return out


## Traits for a compound looked up by its recipe entry.
static func traits_of_recipe(recipe: Dictionary) -> Array:
	return traits_of(recipe.get("kind", "neutral"), recipe.get("traits", []))


## Reverse lookup by result formula ("HCl" -> the recipe dict), or null.
## Needed to migrate save files written before compounds carried their traits,
## and to re-derive traits if the recipe table is rebalanced under an existing
## save. RECIPES is small enough that a linear scan costs nothing.
static func find_by_formula(formula: String):
	for key in RECIPES.keys():
		if RECIPES[key].formula == formula:
			return RECIPES[key]
	# tier-2 products (H2CO3, H2SO3, CaOH2, NH4Cl, Fe2O3) exist ONLY in the
	# tier-2 table. Searching just RECIPES made this return null for them, so
	# _sanitize_roster() fell back to traits_of(kind, []) and every extra trait
	# was silently dropped on load -- a save-corrupting bug aimed squarely at
	# the best content in the game.
	#
	# NaCl and KCl are in both tables with matching traits, and RECIPES is
	# searched first, so their behaviour is unchanged.
	for key in TIER2_RECIPES.keys():
		if TIER2_RECIPES[key].formula == formula:
			return TIER2_RECIPES[key]
	return null


## Which kind beats `kind`, or "" for salt/neutral which sit outside the
## triangle. Used by the shop to tell the player what the next monster is weak
## to, so the triangle is something they can plan around instead of a coin
## flip they discover after committing.
static func counter_of(kind: String) -> String:
	for attacker in TYPE_ADVANTAGE.keys():
		if TYPE_ADVANTAGE[attacker] == kind:
			return attacker
	return ""


## Gold back for scrapping one copy of `formula`.
##
## Half the element cost of the tier-1 recipe that makes it, so selling is
## always a loss against crafting and can never be cycled for profit. A tier-2
## product is worth the sum of its two components, which keeps the harder
## reaction worth more than either half.
static func sell_value(formula: String) -> int:
	for key in RECIPES.keys():
		if RECIPES[key].formula == formula:
			var total := 0
			for symbol in key.split(","):
				total += cost_of(symbol)
			return maxi(1, int(total / 2))
	for key in TIER2_RECIPES.keys():
		if TIER2_RECIPES[key].formula == formula:
			var total := 0
			for part in key.split(","):
				total += sell_value(part)
			return maxi(1, total)
	return 1


## WHY each edge of the triangle exists, in one line the player can read.
##
## Two of the three are real chemistry the syllabus already teaches, and the
## mechanic was accidentally right about both:
##   acid beats metal  -- acids genuinely corrode metals, giving salt + H2
##   base beats acid   -- neutralisation, the single most-taught reaction
##
## The third is the honest weak link and is labelled as such. Metals do not
## generally consume bases; only the AMPHOTERIC ones (Al, Zn) dissolve in a
## strong base. The text says "บางชนิด" because overstating it would teach
## something false, which this project treats as worse than a tidier rule.
##
## Told rather than hidden because a triangle you memorise is a chore and a
## triangle you understand is chemistry. The game already had the right
## answers; it just never said why.
const TYPE_REASON := {
	"acid": "กรดกัดกร่อนโลหะ ได้เกลือกับแก๊สไฮโดรเจน",
	"base": "เบสสะเทินกรด ได้เกลือกับน้ำ",
	"metal": "โลหะบางชนิด (แอมโฟเทอริก เช่น Al, Zn) ละลายในเบสแก่ได้",
}


## Why `attacker_kind` beats `defender_kind`, or "" when it does not.
static func reason_beats(attacker_kind: String, defender_kind: String) -> String:
	if not beats(attacker_kind, defender_kind):
		return ""
	return TYPE_REASON.get(attacker_kind, "")
