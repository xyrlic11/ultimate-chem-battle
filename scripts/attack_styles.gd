extends RefCounted

## Presentation only: visual range never changes targeting or combat stats.
const STYLES := {
	"Fe2": ["melee", "hammer", "a7b5c8", "ทุบเหล็ก"],
	"NaCl": ["melee", "cube", "fff0c9", "หมัดผลึก"],
	"H2O": ["ranged", "wave", "63d9ff", "ซัดคลื่น"],
	"CH4": ["ranged", "fire", "ff9a42", "ยิงลูกไฟ"],
	"HCl": ["ranged", "drop", "ff8a47", "สาดกรด"],
	"H2S": ["ranged", "mist", "b790e8", "พ่นไอพิษ"],
	"SO2": ["ranged", "rain", "f2d56c", "ฝนกรด"],
	"H2CO3": ["ranged", "bubble", "82e9e1", "ยิงฟองฟู่"],
	"H2SO3": ["ranged", "spiral", "c0a0ef", "วังวนกรด"],
	"NaOH": ["ranged", "foam", "98d7ff", "ยิงฟองสะเทิน"],
	"KOH": ["ranged", "bolt", "a5c7ff", "ประจุไอออน"],
	"NH3": ["ranged", "gust", "8ce7c9", "พ่นไอฉุน"],
	"CaO": ["melee", "eruption", "ffb65c", "กระแทกความร้อน"],
	"CaOH2": ["melee", "wall", "eee5cc", "กระแทกปูน"],
	"KCl": ["ranged", "crystal", "c6a4fa", "ยิงผลึกเกลือแร่"],
	"CaCl2": ["ranged", "shard", "ffd4a5", "กระจายผลึก"],
	"NH4Cl": ["ranged", "cross", "88e3c0", "ยิงฟลักซ์"],
	"Cu2": ["melee", "slash", "e9a06f", "ฟันทองแดง"],
	"FeS": ["melee", "cleave", "e1d269", "งัดก้อนเหล็ก"],
	"MgO": ["melee", "ring", "ded6f3", "กระแทกวงป้องกัน"],
	"CuO": ["melee", "sweep", "61c2c6", "กวาดออกไซด์"],
	"Fe2O3": ["melee", "stomp", "db8060", "ทุบสนิม"],
	"H2": ["ranged", "dart", "f1b1d8", "ยิงประจุเบา"],
	"O2": ["ranged", "twin", "89eaf3", "ยิงคู่เสริมไฟ"],
	"N2": ["melee", "shell", "b59bea", "กระแทกพันธะ"],
	"CO2": ["ranged", "cloud", "b2c6d5", "พ่นหมอกดับไฟ"],
}

static func profile(formula: String) -> Dictionary:
	var entry: Array = STYLES.get(formula, ["melee", "hammer", "dfb877", "กระแทก"])
	return {"range": entry[0], "effect": entry[1], "color": Color(entry[2]), "label": entry[3]}

static func label(formula: String) -> String:
	var style := profile(formula)
	return ("ประชิด · " if style.range == "melee" else "ระยะไกล · ") + str(style.label)
