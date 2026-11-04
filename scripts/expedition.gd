extends RefCounted
## Branching journey prototype. Wave is journey depth, not a forced fight.
const Recipes := preload("res://scripts/recipes.gd")
const Rewards := preload("res://scripts/boss_rewards.gd")
const Campaign := preload("res://scripts/campaign.gd")
const LEGACY_ENCOUNTERS := {
	"merchant": {"title": "รถเข็นพ่อค้า", "tag": "ซื้อขาย / ท้าสู้", "icon": "merchant", "color": "efc66d",
		"story": "พ่อค้าเข็นรถผ่านป่า เขาเสนอชุดธาตุสำหรับผสมน้ำ แต่กล่องใต้รถดูน่าสงสัย คุณจะคุยกับเขาแบบไหน?",
		"choices": [
			{"id": "buy", "label": "ซื้อชุดทดลอง", "hint": "จ่าย 25 ทอง · รับ H ×2 + O", "cost": 25, "atoms": ["H", "H", "O"], "ending": "พ่อค้าส่งชุดทดลองให้ คุณแยกย้ายกันอย่างเป็นมิตร"},
			{"id": "help", "label": "ช่วยขนของ", "hint": "รับ 20 ทอง · ไม่ต้องต่อสู้", "gold": 20, "ending": "คุณช่วยดันรถพ้นหลุม พ่อค้าแบ่งค่าจ้างให้"},
			{"id": "fight", "label": "ท้าสู้เพื่อชิงกล่อง", "hint": "ต่อสู้ Cu2 · ชนะรับเพิ่ม 60 ทอง + บัฟ ATK", "combat": "Cu2", "reward_gold": 60, "reward_buff": "power", "ending": "คุณชนะพ่อค้าและได้กล่องเสริมพลังเป็นเดิมพัน"},
			{"id": "leave", "label": "เดินผ่าน", "hint": "ไปต่อ · ไม่ได้รับของ", "ending": "คุณโบกมือลาและเดินต่อโดยไม่ซื้อของ"},
		]},
	"trainer": {"title": "นักฝึกคู่แข่ง", "tag": "พูดคุย / ประลอง", "icon": "person", "color": "9bbcff",
		"story": "นักฝึกสารประกอบกำลังซ้อมอยู่ริมทาง เขาอยากแลกประสบการณ์หรือประลองกับทีมของคุณ โดยไม่ต้องเดิมพันชีวิต",
		"choices": [
			{"id": "talk", "label": "แลกเคล็ดลับ", "hint": "รับ 25 ทอง", "gold": 25, "ending": "คุณแลกวิธีจัดแนวหน้า เขาฝากทุนเล็กน้อยไว้ให้เดินทางต่อ"},
			{"id": "duel", "label": "ประลองทีม", "hint": "ต่อสู้ NH3 · ชนะรับบัฟลดคูลดาวน์", "combat": "NH3", "reward_buff": "haste", "reward_gold": 35, "ending": "คู่แข่งยอมรับฝีมือและสอนจังหวะร่ายสกิลให้คุณ"},
			{"id": "trade", "label": "แลกสารสำรอง", "hint": "จ่าย 35 ทอง · รับ NaCl", "cost": 35, "compound": "NaCl", "ending": "คุณได้ NaCl จากทีมสำรองของเขา พร้อมนำไปจัดทีม"},
			{"id": "leave", "label": "ขอตัวเดินทาง", "hint": "ไปต่อ · ไม่รับรางวัล", "ending": "คุณนัดประลองกันครั้งหน้าและเดินต่อ"},
		]},
	"cache": {"title": "หีบข้างทาง", "tag": "เก็บของ / เสี่ยงโชค", "icon": "chest", "color": "e2b779",
		"story": "คุณพบหีบสองช่อง ช่องเล็กมีเหรียญ ส่วนช่องใหญ่มีแกนป้องกัน แต่รอบกล่องยังมีไอกรดลอยอยู่",
		"choices": [
			{"id": "coins", "label": "หยิบถุงเหรียญ", "hint": "รับ 40 ทอง · ปลอดภัย", "gold": 40, "ending": "คุณเก็บเหรียญแล้วปิดหีบอย่างระมัดระวัง"},
			{"id": "core", "label": "คว้าแกนป้องกัน", "hint": "เสีย 8 HP · รับบัฟโล่เริ่มต้น", "hp_cost": 8, "buff": "shield", "ending": "ไอกรดกัดมือเล็กน้อย แต่แกนป้องกันยังใช้งานได้"},
			{"id": "risk", "label": "เปิดช่องลับ", "hint": "50% รับ 80 ทอง · มิฉะนั้นเสีย 8 HP", "gamble": true, "ending": "คุณงัดช่องลับในหีบ"},
			{"id": "leave", "label": "ไม่แตะหีบ", "hint": "ไปต่อ · ไม่รับรางวัล", "ending": "คุณทิ้งหีบไว้และเลือกเส้นทางปลอดภัย"},
		]},
	"camp": {"title": "กองไฟนักเดินทาง", "tag": "พัก / เสริมพลัง", "icon": "camp", "color": "ffaf75",
		"story": "กองไฟยังอุ่นอยู่ คุณมีเวลาพักหนึ่งคืน จะดูแลตัวเอง ฝึกทีม หรือช่วยคนในค่ายก็ได้",
		"choices": [
			{"id": "rest", "label": "พักฟื้น", "hint": "ฟื้น 25 HP", "heal": 25, "ending": "คุณพักเต็มที่แล้วออกเดินทางพร้อมแรงที่กลับมา"},
			{"id": "train", "label": "ฝึกความทนทาน", "hint": "จ่าย 20 ทอง · รับบัฟ HP +12%", "cost": 20, "buff": "vitality", "ending": "ทีมของคุณฝึกจนโครงสร้างแน่นขึ้น"},
			{"id": "work", "label": "ช่วยเตรียมค่าย", "hint": "รับ 30 ทอง", "gold": 30, "ending": "คุณช่วยเตรียมฟืนและได้รับค่าจ้างจากคนในค่าย"},
		]},
	"ruins": {"title": "ห้องทดลองร้าง", "tag": "สำรวจ / ทดลอง", "icon": "ruins", "color": "b79adf",
		"story": "โต๊ะทดลองยังมีสารตกค้างอยู่ คุณเห็นทั้งแร่เหล็ก สมุดบันทึก และเสียงบางอย่างจากห้องด้านใน",
		"choices": [
			{"id": "ore", "label": "เก็บแร่บนโต๊ะ", "hint": "รับ Fe ×2", "atoms": ["Fe", "Fe"], "ending": "คุณเก็บแร่เหล็กที่ยังสะอาดไว้สำหรับผสมสาร"},
			{"id": "study", "label": "ศึกษาสมุดบันทึก", "hint": "จ่าย 30 ทอง · รับบัฟลดคูลดาวน์", "cost": 30, "buff": "haste", "ending": "คุณถอดรหัสบันทึกและเรียนรู้วิธีเร่งสกิลของทีม"},
			{"id": "fight", "label": "สำรวจห้องด้านใน", "hint": "ต่อสู้ H2S · ชนะรับเพิ่ม 80 ทอง", "combat": "H2S", "reward_gold": 80, "hp_mult": 1.1, "ending": "คุณกำจัดสารพิษที่เฝ้าห้องและเก็บทุนวิจัยที่ซ่อนอยู่"},
			{"id": "leave", "label": "กลับออกไป", "hint": "ไปต่อ · ไม่รับรางวัล", "ending": "คุณไม่เสี่ยงกับสารตกค้างและกลับออกทางเดิม"},
		]},
	"monster": {"title": "รอยเท้ามอน", "tag": "ต่อสู้ / หลบเลี่ยง", "icon": "monster", "color": "ef8f92",
		"story": "มอนสารประกอบเฝ้าสะพาน คุณจะท้าสู้ ล่อมันออกไป หรือใช้ทางอ้อมที่ปลอดภัย?",
		"choices": [
			{"id": "fight", "label": "ท้าสู้บนสะพาน", "hint": "ต่อสู้ KCl · ชนะรับเพิ่ม 50 ทอง", "combat": "KCl", "reward_gold": 50, "ending": "คุณเปิดทางข้ามสะพานและเก็บเหรียญที่มอนเฝ้าไว้"},
			{"id": "lure", "label": "ล่อมอนออกจากทาง", "hint": "จ่าย 15 ทอง · รับ O ×2", "cost": 15, "atoms": ["O", "O"], "ending": "มอนตามเหยื่อล่อไป คุณเก็บธาตุข้างสะพานแล้วผ่านไปได้"},
			{"id": "leave", "label": "ใช้ทางอ้อม", "hint": "ไปต่อ · ไม่ได้รับของ", "ending": "คุณอ้อมลำธารและผ่านสะพานโดยไม่ต้องต่อสู้"},
		]},
	"rescue": {"title": "นักเดินทางบาดเจ็บ", "tag": "ช่วยเหลือ / แลกเปลี่ยน", "icon": "person", "color": "8bd4af",
		"story": "นักเดินทางทำกระเป๋าธาตุหล่นและบาดเจ็บ เขาขอความช่วยเหลือ คุณเลือกได้ว่าจะสละอะไรเพื่อช่วยเขา",
		"choices": [
			{"id": "medicine", "label": "ซื้อยาให้เขา", "hint": "จ่าย 20 ทอง · รับตราเกลือ +1", "cost": 20, "buff": "salt", "ending": "เขาปลอดภัยและมอบตราสายเกลือเป็นคำขอบคุณ"},
			{"id": "carry", "label": "พาไปส่งค่าย", "hint": "เสีย 6 HP · รับ 45 ทอง", "hp_cost": 6, "gold": 45, "ending": "คุณเหนื่อยจากการพยุงเขา แต่ได้รับค่าตอบแทนจากคนในค่าย"},
			{"id": "leave", "label": "บอกทางไปค่าย", "hint": "ไปต่อ · ไม่รับรางวัล", "ending": "คุณบอกเส้นทางที่ปลอดภัยและเดินต่อ"},
		]},
	"researcher": {"title": "นักวิจัยภาคสนาม", "tag": "ร่วมทดลอง / ประลอง", "icon": "lab", "color": "87cee3",
		"story": "นักวิจัยอยากทดสอบสารใหม่กับทีมของคุณ การทดลองมีความเสี่ยง แต่คุณจะได้ความรู้ติดตัวไปด้วย",
		"choices": [
			{"id": "safe", "label": "ช่วยจดบันทึก", "hint": "รับ 30 ทอง · ไม่เสี่ยง", "gold": 30, "ending": "คุณช่วยเก็บข้อมูลและรับค่าจ้างวิจัย"},
			{"id": "experiment", "label": "ร่วมทดลองกับทีม", "hint": "เสีย 10 HP · รับบัฟสุ่ม 1 ใบ", "hp_cost": 10, "buff": "random", "ending": "การทดลองทำให้คุณเหนื่อย แต่ทีมได้คุณสมบัติใหม่"},
			{"id": "duel", "label": "ประลองสารต้นแบบ", "hint": "ต่อสู้ FeS · ชนะรับเพิ่ม 60 ทอง + ตราโลหะ", "combat": "FeS", "reward_gold": 60, "reward_buff": "metal", "ending": "คุณชนะสารต้นแบบและได้ตราโลหะเป็นรางวัล"},
		]},
}

const Flow := preload("res://scripts/run_flow.gd")
const Worlds := preload("res://scripts/worlds.gd")
const Risk := preload("res://scripts/run_risk.gd")
const Traits := preload("res://scripts/traits.gd")
static var ENCOUNTERS: Dictionary = _catalog()
static func _catalog() -> Dictionary:
	var data := LEGACY_ENCOUNTERS.duplicate(true)
	data.merge(preload("res://scripts/risk_nodes.gd").NODES.duplicate(true))
	data.merge(preload("res://scripts/forest_events.gd").NODES.duplicate(true))
	data.merge(preload("res://scripts/regional_events.gd").NODES.duplicate(true))
	var clues := {
		"merchant":["เสียงล้อจากทางแยก","รถขวดสารจอดอยู่ มีคนกำลังนับเหรียญ"],
		"trainer":["แสงกระแทกกันไกล ๆ","เงาคนสั่งสารสองตัวให้ถอย แล้วหันมามองคุณ"],
		"cache":["แสงใต้กล่องเก่า","โลหะสะท้อนจากช่องแคบ รอบกล่องยังมีไอลอย"],
		"camp":["ควันไฟที่ยังอุ่น","กลิ่นฟืนและเสียงคนเตรียมที่พักมาจากด้านหน้า"],
		"ruins":["เสียงจากห้องร้าง","ขวดแตกกับรอยสารนำไปสู่ห้องด้านใน"],
		"monster":["รอยหนักบนสะพาน","พื้นสั่นเบา ๆ มีผลึกอยู่ตามรอยเท้า"],
		"rescue":["เสียงเรียกริมทาง","กระเป๋าธาตุหล่นอยู่ข้างคนที่พยายามลุก"],
		"researcher":["ขวดที่ยังสั่น","คนถือสมุดยืนดูเครื่องมือและโบกมือเรียก"],
		"reactor":["เสียงเครื่องคราง","แสงรั่วออกจากเครื่อง สารรอบข้างขยับตาม"],
		"vault":["แสงหลังกลอนโลหะ","มีคราบสนิมและรอยแรงดันอยู่ตามบานปิด"],
		"distiller":["หยดแสงในท่อ","เครื่องเก่าสะสมพลังเป็นจังหวะ ยังไม่รู้ว่ารับได้แค่ไหน"],
		"funding":["ใบสัญญาที่วางรอ","มีถุงเหรียญกับข้อความเรื่องรายรับในอนาคต"]}
	for key in clues:
		data[key].teaser = clues[key][0]
		data[key].clue = clues[key][1]
	# Replace random punishment and random major reward with disclosed exchanges.
	data.cache.tag = "หีบยังปิดอยู่"
	data.cache.choices[0].preview = "หยิบของที่เข้าถึงง่าย แล้วเดินทางต่อ"
	data.cache.choices[1].preview = "แกนป้องกันอยู่ในไอกรด มือคงเลี่ยงสัมผัสไม่ได้"
	data.camp.choices[0].preview = "ใช้เวลาพักให้ร่างกายพร้อมเดินทาง"
	data.camp.choices[1].preview = "ลงทุนฝึกให้ทีมทนทานขึ้น"
	data.camp.choices[2].preview = "ทำงานแลกทุนสำหรับผสมสาร"
	data.monster.choices[0].preview = "มอนเกลือเฝ้าทรัพย์ไว้ ทีมคุณพร้อมแค่ไหน?"
	data.monster.choices[1].preview = "ใช้ของล่อ แล้วเก็บธาตุข้างสะพาน"
	data.monster.choices[2].preview = "อ้อมผ่านโดยเก็บแรงทีมไว้"
	data.cache.choices[2] = {"id":"risk","label":"เปิดช่องลับ","hint":"เสีย 8 HP ผู้เล่น · รับ 60 ทองแน่นอน","preview":"ช่องลึกมีของอยู่ กลไกอาจบาดมือเมื่อเปิด","hp_cost":8,"gold":60,"ending":"เปิดช่องลับตามต้นทุนที่ตกลง"}
	data.researcher.choices[1].buff = "power"
	data.researcher.choices[1].hint = "เสีย 10 HP ผู้เล่น · ATK ทีม +10% ตลอดรัน"
	return data

static func fresh(wave: int) -> Dictionary:
	return {"step": wave, "phase": "boss" if Campaign.is_boss(wave) else "routes", "offers": [], "selected": "boss" if Campaign.is_boss(wave) else "", "choice": "", "outcome": "", "stage": "", "entered": false, "reading": true, "fallback": false}

static func sanitize(raw, wave: int) -> Dictionary:
	var result := fresh(wave)
	if not raw is Dictionary or int(raw.get("step", 0)) != wave:
		return result
	if raw.get("offers", null) is Array:
		for id in raw.offers:
			if ENCOUNTERS.has(id) and not result.offers.has(id):
				result.offers.append(id)
				if result.offers.size() == 4:
					break
	var phase: String = str(raw.get("phase", "routes"))
	var selected: String = str(raw.get("selected", ""))
	if Campaign.is_boss(wave):
		result.phase = "combat" if phase == "combat" else "boss"
		result.selected = "boss"
		result.choice = "fight" if phase == "combat" else ""
		result.offers.clear()
		return result
	if wave == 1 and phase == "combat" and selected == "opening":
		result.phase = "combat"
		result.selected = "opening"
		result.choice = "fight"
		return result
	if phase == "result" and str(raw.get("choice", "")) == "skip":
		result.phase = "result"
		result.choice = "skip"
		result.outcome = str(raw.get("outcome", ""))
		return result
	if phase in ["story", "result", "combat"] and ENCOUNTERS.has(selected) and result.offers.has(selected):
		result.phase = phase
		result.entered = bool(raw.get("entered", not str(raw.get("choice", "")).is_empty()))
		result.reading = bool(raw.get("reading", true))
		result.fallback = bool(raw.get("fallback", false))
		result.selected = selected
		result.stage = str(raw.get("stage", ""))
		if not result.stage.is_empty() and not ENCOUNTERS[selected].get("stages", {}).has(result.stage):
			result.stage = ""
		result.choice = str(raw.get("choice", ""))
		result.outcome = str(raw.get("outcome", ""))
		if phase == "story" and not result.choice.is_empty():
			# Resume exactly after the last committed extraction, never grant its reward again.
			result.stage = str(choice(selected, result.choice).get("next_stage", ""))
			if result.stage.is_empty():
				result.phase = "result"
		if phase in ["result", "combat"] and result.choice != "retreat" and choice(selected, result.choice).is_empty():
			return fresh(wave)
		if phase == "combat" and not result.fallback and not choice(selected, result.choice).has("combat"):
			return fresh(wave)
	return result

static func choice(event_id: String, choice_id: String) -> Dictionary:
	var data: Dictionary = ENCOUNTERS.get(event_id, {})
	var all: Array = data.get("choices", []).duplicate()
	for stage in data.get("stages", {}).values():
		all.append_array(stage)
	for item in all:
		if item.id == choice_id:
			return item
	return {}

static func ensure(state) -> void:
	state.journey = sanitize(state.journey, state.wave)
	if Campaign.is_boss(state.wave):
		state.save_game()
		return
	if state.journey.offers.is_empty():
		build_plan(state)
		state.journey.offers = state.route_plan[str(state.wave)].offers.duplicate()

	state.save_game()

static func select(state, id: String) -> bool:
	ensure(state)
	if state.journey.phase != "routes" or not state.journey.offers.has(id) or Campaign.is_boss(state.wave):
		return false
	state.journey.selected = id
	var metrics = Engine.get_main_loop().root.get_node_or_null("Playtest")
	if metrics: metrics.event_selected()
	state.journey.phase = "story"
	state.save_game()
	return true

static func available(state, action: Dictionary) -> bool:
	return blocked_reason(state, action).is_empty()

static func blocked_reason(state, action: Dictionary) -> String:
	for key in action.get("requirements", {}).get("flags", {}):
		if state.event_flags.get(key, false) != action.requirements.flags[key]:
			return "ยังไม่มีสิ่งที่จำเป็นจากการเดินทาง"
	if state.gold < int(action.get("cost", 0)):
		return "ทองไม่พอ"
	var counts: Dictionary = Traits.trait_counts(state.fielded_roster(), state.trait_bonus())
	for key in action.get("requirements", {}).get("traits", {}):
		if int(counts.get(key, 0)) < int(action.requirements.traits[key]):
			return "ต้องมี " + Traits.label_of(key) + " ลงสนาม %d ชนิด" % action.requirements.traits[key]
	return ""

static func choices(state) -> Array:
	var data: Dictionary = ENCOUNTERS.get(state.journey.get("selected", ""), {})
	return data.get("stages", {}).get(state.journey.get("stage", ""), data.get("choices", []))

static func eligible(state, id: String) -> bool:
	var data: Dictionary = ENCOUNTERS[id]
	if not data.get("regions", [0, 1, 2, 3, 4]).has(Worlds.region_index_for_wave(state.wave)):
		return false
	for key in data.get("offer_flags", {}):
		if state.event_flags.get(key, false) != data.offer_flags[key]:
			return false
	return true

static func build_plan(state) -> void:
	# Only current opportunities are drawn. Persist before choice; future flags remain relevant.
	if state.route_plan.has(str(state.wave)):
		return
	var pools: Array = [
		["cache", "mushrooms", "deer", "wanderer", "rock", "hollow", "red_button", "roots", "deer_trail"],
		["village_well", "village_tinker", "village_store", "village_bell", "village_refuge"],
		["castle_archive", "castle_bridge", "castle_lens", "castle_courier", "castle_clock"],
		["cavern_smith", "cavern_ore", "cavern_steam", "cavern_seal", "cavern_crucible"],
		["sanctuary_caretaker", "sanctuary_prism", "sanctuary_scale", "sanctuary_star_map", "sanctuary_urn"]]
	var pool: Array = pools[Worlds.region_index_for_wave(state.wave)].duplicate()
	pool = pool.filter(func(id): return eligible(state, id))
	# Avoid repeating the last resolved event where the pool has enough alternatives.
	if not state.journey_history.is_empty() and pool.size() > 3:
		pool.erase(state.journey_history.back().get("event", ""))
	pool.shuffle()
	# Prefer new stories this region while retaining three options near its end.
	var seen: Array = []
	for entry in state.journey_history:
		seen.append(entry.get("event", ""))
	var unseen: Array = pool.filter(func(id): return not seen.has(id))
	var revisits: Array = pool.filter(func(id): return seen.has(id))
	pool = unseen + revisits
	var chains := {"village_tinker":["village_water", "village_mark"], "village_store":["village_mark", ""], "castle_clock":["castle_code", ""], "castle_courier":["village_mark", ""], "cavern_seal":["forge_mark", ""]}
	for id in chains:
		if pool.has(id) and not seen.has(id) and state.event_flags.get(chains[id][0], false) and not state.event_flags.get(chains[id][1], false):
			pool.erase(id)
			pool.push_front(id)
	var offers: Array = pool.slice(0, 3)
	if state.event_flags.get("fed_deer", false) and not state.event_flags.get("deer_followed", false) and eligible(state, "deer_trail"):
			# No duplicated chain cards.
		offers = []
		offers.append("deer_trail")
		for id in pool:
			if id != "deer_trail" and offers.size() < 3:
				offers.append(id)
	state.route_plan[str(state.wave)] = {"offers": offers}

static func future_text(state) -> String:
	var left: int = Campaign.STAGES_PER_REGION - state.wave % Campaign.STAGES_PER_REGION
	return "ทางข้างหน้าเริ่มเงียบลง ใกล้ถึงสิ่งที่ขวางทาง" if left <= 1 else "ชี้เบาะแสเพื่ออ่าน · ยังไม่รู้ว่าทางข้างหน้ามีอะไร"

static func grant_buff(state, id: String) -> String:
	if id == "random":
		var keys := Rewards.CARDS.keys()
		id = keys[randi() % keys.size()]
	if not Rewards.CARDS.has(id):
		return ""
	state.run_buffs.append(id)
	return "บัฟ · " + str(Rewards.CARDS[id].name)

static func resolve(state, id: String) -> bool:
	if Campaign.is_boss(state.wave):
		if id != "fight" or state.journey.get("phase", "") != "boss":
			return false
		state.journey.phase = "combat"
		state.journey.choice = "fight"
		state.save_game()
		return true
	if state.journey.get("phase", "") != "story":
		return false
	var action := choice(state.journey.selected, id)
	if action.is_empty() or not choices(state).any(func(item): return item.id == id) or not available(state, action):
		return false
	state.journey.entered = true
	state.journey.reading = true
	state.journey.choice = id
	if action.has("combat"):
		state.journey.phase = "combat"
		state.save_game()
		return true
	# Commit all effects as one save; result phase survives closing the game.
	state._loading = true
	var lines: Array[String] = [action.ending]
	var cost := int(action.get("cost", 0))
	if cost > 0:
		state.lose_gold(cost)
		lines.append("−%d ทอง" % cost)
	var gain := int(action.get("gold", 0))

	if gain > 0:
		state.add_gold(gain)
		lines.append("+%d ทอง" % gain)
	var hp_cost := int(action.get("hp_cost", 0))
	if hp_cost > 0:
		Flow.hurt(state, float(hp_cost) / 100.0)
		lines.append("ทีมบาดเจ็บ")
	var heal := int(action.get("heal", 0))
	if heal > 0:
		Flow.heal(state, float(heal) / 100.0)
		lines.append("ทีมฟื้นตัว")
	if action.has("buff"):
		lines.append(grant_buff(state, action.buff))
	if action.get("atoms", []) is Array and not action.get("atoms", []).is_empty():
		var n: int = state.board_items.size()
		for atom in action.atoms:
			state.board_items.append({"type": "atom", "key": atom, "x": 55 + (n % 4) * 135, "y": 110 + int(n / 4) * 90})
			n += 1
		lines.append("รับธาตุ " + " + ".join(action.atoms))
	if action.has("compound"):
		var recipe: Dictionary = Recipes.find_by_formula(action.compound).duplicate(true)
		recipe.tier = int(action.get("compound_tier", 1))
		recipe.traits = Recipes.traits_of_recipe(recipe)
		state.add_to_roster(recipe)
		# A roster entry alone is not a draggable tile; create the saved tile too.
		if not state.board_items.any(func(entry): return entry.get("key", "") == recipe.formula and entry.get("type", "") == "molecule"):
			state.board_items.append({"type": "molecule", "key": recipe.formula, "tier": recipe.tier, "x": 70, "y": 180})
		lines.append("รับ " + str(recipe.formula))
	if action.has("team_damage"):
		Flow.hurt(state, float(action.team_damage))
		lines.append("ทีมบาดเจ็บ")
	if action.has("team_heal"):
		Flow.heal(state, float(action.team_heal))
		lines.append("ทีมฟื้นตัว")
	for key in action.get("flags", {}):
		state.event_flags[key] = action.flags[key]
	if action.has("modifier"):
		Risk.add(state, action.modifier)
	state.journey.phase = "story" if action.has("next_stage") else "result"
	state.journey.stage = str(action.get("next_stage", ""))
	state.journey.outcome = "\n".join(lines)
	state._loading = false
	state.save_game()
	return true

static func enemy(state) -> Dictionary:
	if Campaign.is_boss(state.wave):
		return Campaign.enemy(state.wave, state.next_monster_kind)
	if state.journey.get("phase", "") != "combat":
		return Campaign.enemy(state.wave, state.next_monster_kind)
	if int(state.journey.get("step", 0)) != state.wave:
		return Campaign.enemy(state.wave, state.next_monster_kind)
	var action := choice(state.journey.get("selected", ""), state.journey.get("choice", ""))
	if not action.has("combat"):
		return Campaign.enemy(state.wave, state.next_monster_kind)
	var recipe: Dictionary = Recipes.find_by_formula(action.combat)
	return {"formula": recipe.formula, "name": recipe.thai, "kind": recipe.kind, "ultimate": "",
		"hp_mult": action.get("hp_mult", 1.0), "atk_mult": 1.0,
		"encounter": ENCOUNTERS[state.journey.selected].title, "reward_mode": action.get("reward_mode", "normal")}

static func battle_reward(state) -> String:
	if state.journey.get("phase", "") != "combat" or Campaign.is_boss(state.wave):
		return ""
	var action := choice(state.journey.get("selected", ""), state.journey.get("choice", ""))
	if not action.has("combat"):
		return ""
	var lines: Array[String] = [action.ending]
	var bonus := int(action.get("reward_gold", 0))
	state.add_gold(bonus)
	if bonus > 0:
		lines.append("รางวัลเหตุการณ์ +%d ทอง" % bonus)
	if action.has("reward_buff"):
		lines.append(grant_buff(state, action.reward_buff))
	state.journey.outcome = "\n".join(lines)
	return state.journey.outcome

static func advance(state, from_battle := false) -> bool:
	var phase: String = state.journey.get("phase", "")
	if phase == "result" and state.journey.get("choice", "") != "skip":
		return false
	if state.wave >= state.FINAL_WAVE or (phase != "result" and not (from_battle and phase == "combat")):
		return false
	Flow.recover(state, state.wave)
	state.journey_history.append({"step": state.wave, "event": state.journey.get("selected", ""),
		"choice": state.journey.get("choice", ""), "outcome": state.journey.get("outcome", "")})
	state._loading = true
	state.wave += 1
	state.roll_next_monster()
	state.journey = fresh(state.wave)
	state._loading = false
	state.save_game()
	return true

static func enter(state) -> bool:
	if state.journey.get("phase", "") != "story" or state.journey.get("entered", false):
		return false
	state.journey.entered = true
	state.journey.reading = true
	state.save_game()
	return true

static func retreat(state) -> bool:
	if state.journey.get("phase", "") != "story" or state.journey.get("entered", false):
		return false
	state.journey.phase = "result"
	state.journey.choice = "retreat"
	state.journey.outcome = "คุณถอยออกมาและเดินตามทางเดิม เสียงบางอย่างดังจากพุ่มไม้ข้างทาง"
	state.save_game()
	return true

static func followup(state) -> bool:
	if state.journey.get("phase", "") != "result" or state.journey.get("choice", "") == "skip":
		return false
	state.journey.phase = "combat"
	state.journey.fallback = true
	state.save_game()
	return true
