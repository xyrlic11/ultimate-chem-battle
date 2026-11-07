extends RefCounted

# Exact formula IDs, independent of crafting and the existing kind counters.
const PLANS := {
	"oxide": {"source": "HCl", "enemy": "Fe2O3", "title": "HCl → Fe2O3",
		"preview": "เปิดศึก: รับดาเมจเพิ่ม 15% นาน 2 รอบ · ครั้งเดียว\nเคมี: Fe2O3 ทำปฏิกิริยากับ HCl ในน้ำ ให้เกลือเหล็ก(III) และน้ำ"},
	"neutralize": {"source": "NaOH", "enemy": "HCl", "title": "NaOH → HCl",
		"preview": "ล้างกัดกร่อนจาก HCl ครั้งแรกให้เพื่อน 1 ตัว · ผู้ใช้ต้องยังอยู่\nเคมี: HCl + NaOH ในน้ำ สะเทินให้ NaCl และน้ำ; ปริมาณสารมีผล"}
}

static func sanitize(value: Variant) -> String:
	return value if value is String and PLANS.has(value) else ""

static func available(id: String, fielded: Array) -> bool:
	return id == "" or (PLANS.has(id) and fielded.has(PLANS[id].source))

static func matches(id: String, fielded: Array, enemy: String) -> bool:
	return PLANS.has(id) and available(id, fielded) and PLANS[id].enemy == enemy
