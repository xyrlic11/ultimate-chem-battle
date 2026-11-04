extends RefCounted
## Run-only rewards. An automatic gift plus a choice of three after every boss.
const CARDS := {
	"power": {"name": "พลังเข้มข้น", "tag": "ATK +10%", "tip": "ทุกตัวในทีมโจมตีแรงขึ้น 10% ตลอดรันนี้", "atk": 0.10},
	"vitality": {"name": "โครงสร้างแน่น", "tag": "HP +12%", "tip": "ทุกตัวในทีมมี HP สูงสุดเพิ่ม 12% ตลอดรันนี้", "hp": 0.12},
	"shield": {"name": "เคลือบป้องกัน", "tag": "โล่เริ่มต้น", "tip": "เริ่มทุกการต่อสู้ด้วยโล่ 10% ของ HP สูงสุด", "shield": 0.10},
	"haste": {"name": "เร่งสกิล", "tag": "คูลดาวน์ −1", "tip": "สกิลประจำตัวใช้เวลาน้อยลง 1 ตา คูลดาวน์ต่ำสุด 2 ตา", "cooldown": 1},
	"acid": {"name": "ตรากรด", "tag": "กรด +1", "tip": "ถ้ามีสารสายกรดลงสนามอย่างน้อย 1 ชนิด นับสายกรดเพิ่ม 1", "trait": "acid"},
	"base": {"name": "ตราเบส", "tag": "เบส +1", "tip": "ถ้ามีสารสายเบสลงสนามอย่างน้อย 1 ชนิด นับสายเบสเพิ่ม 1", "trait": "base"},
	"metal": {"name": "ตราโลหะ", "tag": "โลหะ +1", "tip": "ถ้ามีสารสายโลหะลงสนามอย่างน้อย 1 ชนิด นับสายโลหะเพิ่ม 1", "trait": "metal"},
	"salt": {"name": "ตราเกลือ", "tag": "เกลือ +1", "tip": "ถ้ามีสารสายเกลือลงสนามอย่างน้อย 1 ชนิด นับสายเกลือเพิ่ม 1", "trait": "salt"},
}
static func bonus(ids: Array, key: String) -> float:
	var total := 0.0
	for id in ids:
		total += float(CARDS.get(id, {}).get(key, 0))
	return total
static func trait_bonus(ids: Array) -> Dictionary:
	var result := {}
	for id in ids:
		var trait_key: String = CARDS.get(id, {}).get("trait", "")
		if not trait_key.is_empty():
			result[trait_key] = int(result.get(trait_key, 0)) + 1
	return result
static func roll(wave: int) -> Dictionary:
	var pool := CARDS.keys()
	pool.shuffle()
	return {"wave": wave, "automatic": pool[0], "offers": pool.slice(1, 4)}

