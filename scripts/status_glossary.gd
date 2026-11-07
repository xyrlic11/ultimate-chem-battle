extends RichTextLabel
## Profile-only glossary: values and combat logic remain in UnitAbilities/Battle.
const TERMS := {
	"มอบโล่": ["82cfff", "โล่รับดาเมจจากการโจมตีก่อนพลังชีวิต\nตัวเลข % คิดจากพลังชีวิตสูงสุดของผู้รับโล่\nโล่ไม่ป้องกันดาเมจต่อเนื่อง"],
	"ลดดาเมจ": ["82cfff", "ลดความเสียหายจากการโจมตีตามเปอร์เซ็นต์ที่ระบุ\nเช่น 25%: ดาเมจ 100 เหลือ 75 ก่อนคิดผลอื่น\nมีผลตามจำนวนตาที่ระบุในสกิล"],
	"ล้างสถานะลบ": ["83e0b0", "ลบผลเสียที่ระบบล้างสถานะรองรับออกจากผู้รับ\nไม่ใช่การฟื้นพลังชีวิต เว้นแต่สกิลระบุว่าฟื้นด้วย"],
	"ฟื้น HP": ["83e0b0", "คืนพลังชีวิตให้เป้าหมายที่ยังมีชีวิต\nเปอร์เซ็นต์คิดจากพลังชีวิตสูงสุดของเป้าหมาย\nไม่ฟื้นเกินค่าสูงสุดและไม่ชุบชีวิต"],
	"ลดเกราะ": ["f2b175", "ทำให้ศัตรูรับความเสียหายจากการโจมตีมากขึ้น\nจำนวนชั้นและระยะเวลาขึ้นกับสกิล"],
	"วางพิษ": ["c2a1eb", "สร้างความเสียหายต่อเนื่องตามรอบ\nตัวเลข % ATK คิดจากพลังโจมตีของผู้ใช้สกิล\nทำงานตามจำนวนรอบที่ระบุ"],
	"เผาไหม้": ["ffac70", "สร้างความเสียหายต่อเนื่องจากสกิลไฟ\nส่วนดาเมจต่อเนื่องแยกจากการโจมตีทันที"],
	"ลด ATK": ["f2b175", "ลดพลังโจมตีของศัตรูตามเปอร์เซ็นต์\nมีผลตามจำนวนตาที่สกิลระบุ"],
	"คูลดาวน์": ["b8b4ff", "จำนวนตาที่ต้องรอก่อนใช้สกิลอีกครั้ง\nครั้งแรกใน X ตา คือเวลารอก่อนใช้ครั้งแรกของการต่อสู้"],
	"โจมตีเพิ่ม": ["ffac70", "เพิ่มดาเมจจากสกิลในการโจมตีครั้งนี้\nเปอร์เซ็นต์ ATK อ้างอิงพลังโจมตีของผู้ใช้"],
	"ครั้งถัดไป": ["ffac70", "เพิ่มพลังให้การโจมตีครั้งถัดไปของผู้รับ\nโบนัสนี้ถูกใช้เมื่อโจมตี ไม่ใช่การเพิ่มถาวร"]
}

func _ready() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_font_size_override("normal_font_size", 17)
	add_theme_font_size_override("bold_font_size", 17)
	meta_underlined = false
	meta_hover_started.connect(func(key): tooltip_text = str(TERMS[str(key)][1]))
	meta_hover_ended.connect(func(_key): tooltip_text = "")

func set_description(plain: String) -> void:
	tooltip_text = ""
	# Replace original text once; never re-process inserted BBCode or tooltip text.
	var output := ""
	var position := 0
	while position < plain.length():
		var matched := false
		for term in TERMS:
			if plain.substr(position).begins_with(term):
				output += "[url=%s][color=#%s][b]%s[/b][/color][/url]" % [term, TERMS[term][0], term]
				position += term.length()
				matched = true
				break
		if not matched:
			output += "[lb]" if plain[position] == "[" else plain[position]
			position += 1
	text = output

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty(): return null
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 320
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	return label
