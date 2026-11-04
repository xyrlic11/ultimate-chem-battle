extends RefCounted
const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")


static func combat_stats(formula: String, info: Dictionary, row: String, active: Dictionary) -> Dictionary:
	var base: Dictionary = Recipes.KIND_STATS.get(info.kind, Recipes.KIND_STATS.neutral)
	var count := int(info.get("count", 1))
	var hp := float(base.hp) * Recipes.stack_hp_multiplier(count) * stat_multiplier(formula, "hp")
	var atk := float(base.atk) * Recipes.stack_atk_multiplier(count) * stat_multiplier(formula, "atk")
	if int(info.get("tier", 1)) >= 2:
		hp *= Recipes.TIER2_STAT_BONUS
		atk *= Recipes.TIER2_STAT_BONUS
	if info.get("traits", []).has("oxide"):
		hp *= 1.0 + Traits.value(active, "oxide", "hp_bonus")
	if row == Traits.ROW_FRONT:
		hp *= 1.0 + Traits.FRONT_HP_BONUS
	elif row == Traits.ROW_BACK:
		atk *= 1.0 + Traits.BACK_ATK_BONUS
	return {"hp": hp, "atk": atk}

## One signature ability for every craftable compound.
##
## Design rule: abilities reinforce a normal attack instead of adding a second
## action outside the turn queue.  That keeps a seven-unit board readable and
## makes position/team selection -- not button mashing -- the player's agency.
## Every number for Phase D lives in this table so balance never leaks into
## battle.gd.

const ROLE_LABEL := {
	"tank": "แนวรับ",
	"fighter": "แนวหน้า",
	"striker": "ตัวทำดาเมจ",
	"support": "สนับสนุน",
	"controller": "ควบคุม",
}

## Small identity multipliers layered on top of Recipes.KIND_STATS.  Kind is
## still the main source of stats/type-counter balance; role only pushes a unit
## toward the job its ability and suggested row already communicate.
const ROLE_STATS := {
	"tank": {"hp": 1.25, "atk": 0.85},
	"fighter": {"hp": 1.10, "atk": 1.05},
	"striker": {"hp": 0.85, "atk": 1.25},
	"support": {"hp": 1.00, "atk": 0.90},
	"controller": {"hp": 0.95, "atk": 1.00},
}

const ROW_LABEL := {
	"front": "แนะนำแถวหน้า",
	"back": "แนะนำแถวหลัง",
}

## effect values are ratios unless their key explicitly says otherwise.
## `power` scales from the caster's ATK; `hp_ratio` scales from the target's
## max HP.  Durations and cooldowns are measured in complete battle rounds.
const ABILITIES := {
	# Acids -----------------------------------------------------------------
	"HCl": {
		"name": "กัดกร่อน", "role": "controller", "row": "back", "cooldown": 4,
		"effect": "armor_break", "value": 0.15, "duration": 2,
		"description": "ลดเกราะมอนสเตอร์ 15% นาน 2 ตา",
		"chemistry": "กรดไฮโดรคลอริกกัดกร่อนโลหะและทำลายผิวป้องกัน",
	},
	"H2S": {
		"name": "ไอพิษ", "role": "controller", "row": "back", "cooldown": 5,
		"effect": "dot", "power": 0.32, "duration": 3,
		"description": "วางพิษ สร้างดาเมจ 32% ATK ต่อรอบ นาน 3 ตา",
		"chemistry": "ไฮโดรเจนซัลไฟด์เป็นแก๊สพิษที่เป็นอันตรายเมื่อสูดดม",
	},
	"SO2": {
		"name": "ฝนกรด", "role": "controller", "row": "back", "cooldown": 5,
		"effect": "stacking_armor_break", "value": 0.08, "max_stacks": 2,
		"description": "ลดเกราะ 8% แบบสะสมได้ 2 ชั้น",
		"chemistry": "ซัลเฟอร์ไดออกไซด์ในอากาศเป็นสารตั้งต้นของฝนกรด",
	},
	"H2CO3": {
		"name": "ฟองฟู่", "role": "striker", "row": "back", "cooldown": 5,
		"effect": "bonus_damage", "power": 0.65,
		"description": "โจมตีเพิ่มอีก 65% ATK",
		"chemistry": "กรดคาร์บอนิกไม่เสถียรและสลายตัวปล่อยคาร์บอนไดออกไซด์เป็นฟอง",
	},
	"H2SO3": {
		"name": "กรดสะสม", "role": "controller", "row": "back", "cooldown": 6,
		"effect": "stacking_armor_break", "value": 0.06, "max_stacks": 3,
		"description": "ลดเกราะ 6% แบบสะสมได้ 3 ชั้น",
		"chemistry": "กรดซัลฟิวรัสค่อย ๆ ทำให้สภาพแวดล้อมมีความเป็นกรดมากขึ้น",
	},

	# Bases ----------------------------------------------------------------
	"NaOH": {
		"name": "สะเทิน", "role": "support", "row": "back", "cooldown": 4,
		"effect": "cleanse_shield", "hp_ratio": 0.12,
		"description": "ล้างสถานะลบและมอบโล่ 12% HP ให้เพื่อนที่อ่อนแอที่สุด",
		"chemistry": "โซเดียมไฮดรอกไซด์เป็นเบสแก่ที่ใช้สะเทินกรด",
	},
	"KOH": {
		"name": "อิเล็กโทรไลต์", "role": "support", "row": "back", "cooldown": 5,
		"effect": "cooldown_reduce", "rounds": 1,
		"description": "ลดคูลดาวน์ของเพื่อนที่รอนานที่สุด 1 ตา",
		"chemistry": "โพแทสเซียมไฮดรอกไซด์นำไอออนได้ดีและใช้เป็นอิเล็กโทรไลต์",
	},
	"NH3": {
		"name": "กลิ่นฉุน", "role": "controller", "row": "back", "cooldown": 4,
		"effect": "attack_down", "value": 0.12, "duration": 2,
		"description": "ลด ATK มอนสเตอร์ 12% นาน 2 ตา",
		"chemistry": "ไอแอมโมเนียมีกลิ่นฉุนและระคายเคืองอย่างรุนแรง",
	},
	"CaO": {
		"name": "คายความร้อน", "role": "fighter", "row": "front", "cooldown": 5,
		"effect": "bonus_damage", "power": 0.75,
		"description": "โจมตีเพิ่มอีก 75% ATK",
		"chemistry": "ปูนดิบทำปฏิกิริยากับน้ำและคายความร้อนสูง",
	},
	"CaOH2": {
		"name": "ฉาบผิว", "role": "tank", "row": "front", "cooldown": 5,
		"effect": "shield", "hp_ratio": 0.18,
		"description": "มอบโล่ 18% HP ให้เพื่อนที่อ่อนแอที่สุด",
		"chemistry": "ปูนขาวใช้ฉาบและสร้างชั้นผิวแข็งปกป้องโครงสร้าง",
	},

	# Salts ----------------------------------------------------------------
	"NaCl": {
		"name": "ถนอม", "role": "tank", "row": "front", "cooldown": 5,
		"effect": "guard", "value": 0.15, "duration": 2,
		"description": "ลดดาเมจ 15% ให้เพื่อนที่อ่อนแอที่สุดนาน 2 ตา",
		"chemistry": "เกลือแกงใช้ถนอมอาหารและชะลอการเสื่อมสภาพ",
	},
	"KCl": {
		"name": "เกลือแร่", "role": "support", "row": "back", "cooldown": 6,
		"effect": "heal", "hp_ratio": 0.18,
		"description": "ฟื้น HP 18% ให้เพื่อนที่เลือดน้อยที่สุด",
		"chemistry": "โพแทสเซียมเป็นอิเล็กโทรไลต์สำคัญต่อกล้ามเนื้อและหัวใจ",
	},
	"CaCl2": {
		"name": "ดูดความชื้น", "role": "support", "row": "back", "cooldown": 5,
		"effect": "cleanse_shield", "hp_ratio": 0.08,
		"description": "ล้างสถานะลบและมอบโล่ 8% HP",
		"chemistry": "แคลเซียมคลอไรด์ดูดความชื้นจากสิ่งแวดล้อมได้ดีมาก",
	},
	"NH4Cl": {
		"name": "ฟลักซ์", "role": "controller", "row": "back", "cooldown": 5,
		"effect": "armor_break", "value": 0.12, "duration": 2,
		"description": "ลดเกราะมอนสเตอร์ 12% นาน 2 ตา",
		"chemistry": "แอมโมเนียมคลอไรด์ใช้เป็นฟลักซ์ช่วยขจัดชั้นออกไซด์ก่อนบัดกรี",
	},

	# Metals and metal oxides ---------------------------------------------
	"Fe2": {
		"name": "กำบังเหล็ก", "role": "tank", "row": "front", "cooldown": 4,
		"effect": "self_guard", "value": 0.25, "duration": 2,
		"description": "ลดดาเมจที่ตัวเองได้รับ 25% นาน 2 ตา",
		"chemistry": "เหล็กมีความแข็งแรงและใช้รับแรงในโครงสร้าง",
	},
	"Cu2": {
		"name": "นำกระแส", "role": "support", "row": "back", "cooldown": 4,
		"effect": "next_attack", "value": 0.22,
		"description": "เพิ่มดาเมจการโจมตีครั้งถัดไปของเพื่อน ATK สูงสุด 22%",
		"chemistry": "ทองแดงนำไฟฟ้าได้ดี จึงส่งพลังงานต่อไปยังพันธมิตร",
	},
	"FeS": {
		"name": "ซัลไฟด์แตกตัว", "role": "fighter", "row": "front", "cooldown": 5,
		"effect": "dot", "power": 0.22, "duration": 2,
		"description": "วางพิษ สร้างดาเมจ 22% ATK ต่อรอบ นาน 2 ตา",
		"chemistry": "ไอร์ออนซัลไฟด์เมื่อสัมผัสกรดสามารถปล่อยแก๊ส H2S ที่เป็นพิษ",
	},
	"MgO": {
		"name": "แสงจ้า", "role": "controller", "row": "back", "cooldown": 4,
		"effect": "attack_down", "value": 0.10, "duration": 2,
		"description": "ลด ATK มอนสเตอร์ 10% นาน 2 ตา",
		"chemistry": "แมกนีเซียมให้แสงสีขาวสว่างมากเมื่อเผาไหม้",
	},
	"CuO": {
		"name": "ชั้นออกไซด์", "role": "tank", "row": "front", "cooldown": 4,
		"effect": "self_guard", "value": 0.18, "duration": 3,
		"description": "ลดดาเมจที่ตัวเองได้รับ 18% นาน 3 ตา",
		"chemistry": "ชั้นออกไซด์บนผิวโลหะช่วยกั้นการสัมผัสกับสิ่งแวดล้อม",
	},
	"Fe2O3": {
		"name": "สนิมลาม", "role": "fighter", "row": "front", "cooldown": 5,
		"effect": "rust", "power": 0.24, "value": 0.06, "duration": 2,
		"description": "สร้างดาเมจ 24% ATK ต่อรอบและลดเกราะ 6% นาน 2 ตา",
		"chemistry": "สนิมค่อย ๆ ลุกลามและทำให้โครงสร้างเหล็กอ่อนแอลง",
	},

	# Neutral compounds and gases ----------------------------------------
	"H2O": {
		"name": "ชะล้าง", "role": "support", "row": "back", "cooldown": 4,
		"effect": "cleanse_heal", "hp_ratio": 0.10,
		"description": "ล้างสถานะลบและฟื้น HP 10% ให้เพื่อนที่อ่อนแอที่สุด",
		"chemistry": "น้ำเป็นตัวทำละลายที่ใช้ชะล้างสารและเจือจางสารละลาย",
	},
	"H2": {
		"name": "มวลเบา", "role": "striker", "row": "back", "cooldown": 4,
		"effect": "self_guard", "value": 0.20, "duration": 2,
		"description": "ลดดาเมจที่ตัวเองได้รับ 20% นาน 2 ตา",
		"chemistry": "ไฮโดรเจนมีมวลโมเลกุลต่ำและแพร่กระจายได้รวดเร็ว",
	},
	"O2": {
		"name": "ช่วยเผาไหม้", "role": "support", "row": "back", "cooldown": 4,
		"effect": "next_attack", "value": 0.25,
		"description": "เพิ่มดาเมจการโจมตีครั้งถัดไปของเพื่อน ATK สูงสุด 25%",
		"chemistry": "ออกซิเจนช่วยให้เชื้อเพลิงเกิดการเผาไหม้ได้รุนแรงขึ้น",
	},
	"N2": {
		"name": "เฉื่อย", "role": "tank", "row": "front", "cooldown": 5,
		"effect": "self_guard", "value": 0.30, "duration": 2,
		"description": "ลดดาเมจที่ตัวเองได้รับ 30% นาน 2 ตา",
		"chemistry": "พันธะสามของไนโตรเจนทำให้ N2 เสถียรและไม่ค่อยเกิดปฏิกิริยา",
	},
	"CH4": {
		"name": "จุดระเบิด", "role": "striker", "row": "back", "cooldown": 5,
		"effect": "ignite", "power": 0.70, "dot_power": 0.18, "duration": 2,
		"description": "โจมตีเพิ่ม 70% ATK และเผาไหม้ 18% ATK นาน 2 ตา",
		"chemistry": "มีเทนเป็นเชื้อเพลิงไวไฟและเผาไหม้ได้เมื่อมีออกซิเจน",
	},
	"CO2": {
		"name": "ดับเพลิง", "role": "controller", "row": "back", "cooldown": 4,
		"effect": "attack_down", "value": 0.12, "duration": 2,
		"description": "ลด ATK มอนสเตอร์ 12% นาน 2 ตา",
		"chemistry": "คาร์บอนไดออกไซด์ไม่ช่วยการเผาไหม้และใช้ในถังดับเพลิง",
	},
}


static func skill_of(formula: String) -> Dictionary:
	return ABILITIES.get(formula, {})


static func role_label(formula: String) -> String:
	var skill: Dictionary = skill_of(formula)
	return ROLE_LABEL.get(str(skill.get("role", "")), "")


static func row_label(formula: String) -> String:
	var skill: Dictionary = skill_of(formula)
	return ROW_LABEL.get(str(skill.get("row", "")), "")


static func stat_multiplier(formula: String, stat: String) -> float:
	var skill: Dictionary = skill_of(formula)
	var profile: Dictionary = ROLE_STATS.get(str(skill.get("role", "")), {})
	return float(profile.get(stat, 1.0))


static func stat_text(formula: String) -> String:
	var hp_delta := roundi((stat_multiplier(formula, "hp") - 1.0) * 100.0)
	var atk_delta := roundi((stat_multiplier(formula, "atk") - 1.0) * 100.0)
	return "แนวโน้มค่าสถานะ: HP %s%d%% · ATK %s%d%%" % [
		"+" if hp_delta >= 0 else "", hp_delta,
		"+" if atk_delta >= 0 else "", atk_delta,
	]


static func tooltip(formula: String) -> String:
	var skill: Dictionary = skill_of(formula)
	if skill.is_empty():
		return ""
	return "%s · %s · CD %d ตา\n%s\n%s\nเหตุผลทางเคมี: %s" % [
		ROLE_LABEL.get(str(skill.role), str(skill.role)),
		ROW_LABEL.get(str(skill.row), str(skill.row)),
		int(skill.cooldown),
		stat_text(formula),
		str(skill.description),
		str(skill.chemistry),
	]
