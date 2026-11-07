extends VBoxContainer

const Plans := preload("res://scripts/reaction_plan.gd")
const IDS := ["", "oxide", "neutralize"]
var selector: OptionButton
var preview: Label
var note: Label
var note_button: Button

func _ready() -> void:
	selector = OptionButton.new()
	selector.name = "ReactionChoice"
	selector.custom_minimum_size.y = 44
	selector.add_item("ปฏิกิริยา · ไม่เลือก")
	for id in IDS.slice(1):
		selector.add_item("ปฏิกิริยา · " + Plans.PLANS[id].title)
	var row := HBoxContainer.new()
	add_child(row)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	note_button = Button.new()
	note_button.text = "เคมี"
	note_button.custom_minimum_size = Vector2(52, 44)
	row.add_child(note_button)
	preview = Label.new()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 14)
	add_child(preview)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.hide()
	add_child(note)
	note_button.pressed.connect(func(): note.visible = not note.visible)
	selector.item_selected.connect(func(index):
		GameState.commit_reaction(IDS[index])
		refresh())
	GameState.roster_changed.connect(refresh)
	refresh()

func refresh() -> void:
	visible = GameState.reaction_unlocked
	if not visible: return
	for i in range(1, IDS.size()):
		var available := Plans.available(IDS[i], GameState.fielded_formulas())
		selector.set_item_disabled(i, not available)
		selector.get_popup().set_item_tooltip(i, "" if available else
			"ต้องจัด %s ลงทีมก่อน" % Plans.PLANS[IDS[i]].source)
	var id: String = GameState.reaction_plan
	note_button.disabled = not Plans.PLANS.has(id)
	if note_button.disabled: note.hide()
	selector.select(maxi(0, IDS.find(id)))
	preview.text = "เลือกได้ 1 แผน · ต้องมีผู้ใช้ในทีม · ใช้อัตโนมัติเมื่อเจอคู่สารตรงกัน"
	if Plans.PLANS.has(id):
		var lines: PackedStringArray = str(Plans.PLANS[id].preview).split("\n")
		preview.text = "กติกาเกม · " + lines[0]
		note.text = lines[1] + "\nผลต่อสู้เป็นกติกาเกม ไม่ใช่ผลทดลองจริง"
		if not Plans.available(id, GameState.fielded_formulas()):
			preview.text = "แผนพักอยู่: ไม่มีผู้ใช้ในทีม จึงไม่เกิดปฏิกิริยา\n" + preview.text
