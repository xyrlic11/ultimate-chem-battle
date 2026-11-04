extends Control
signal finished
const Rewards := preload("res://scripts/boss_rewards.gd")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.04, 0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 340)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "พิชิตบอส! · เลือกบัฟ 1 ใบ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var gift: Dictionary = Rewards.CARDS[GameState.pending_reward.automatic]
	var automatic := Label.new()
	automatic.text = "ได้รับอัตโนมัติ · %s · %s" % [gift.name, gift.tag]
	automatic.tooltip_text = gift.tip
	automatic.add_theme_color_override("font_color", Color("82e3b0"))
	automatic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(automatic)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for id in GameState.pending_reward.offers:
		var card: Dictionary = Rewards.CARDS[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(236, 160)
		button.text = "%s\n\n%s" % [card.name, card.tag]
		button.tooltip_text = card.tip + "\nใช้ได้ตลอดรันนี้ บัฟซ้ำสะสมกันได้"
		button.add_theme_font_size_override("font_size", 22)
		row.add_child(button)
		button.pressed.connect(func():
			if GameState.choose_boss_reward(id):
				Audio.play("buy")
				finished.emit()
				queue_free())
	var note := Label.new()
	note.text = "บัฟใช้ตลอดรัน · ชี้การ์ดเพื่อดูรายละเอียด"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
