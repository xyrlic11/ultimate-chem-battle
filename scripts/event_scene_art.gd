extends Control
## A small pixel diorama, distinct for each forest encounter.
var event_id := ""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func block(x: float, y: float, w: float, h: float, color: String) -> void:
	var scale_px := floorf(minf(size.x / 160.0, size.y / 38.0))
	var origin := (size - Vector2(160,38) * scale_px) * 0.5
	draw_rect(Rect2(origin + Vector2(x,y) * scale_px, Vector2(w,h) * scale_px), Color(color))
func _draw() -> void:
	block(0,0,160,38,"182f32")
	block(0,27,160,11,"34473b")
	block(45,30,75,8,"675943")
	for x in [5,23,135,151]:
		block(x,7,4,24,"453e37")
		block(x-7,2,18,12,"27463e")
		block(x-5,1,14,5,"3c5b45")
	match event_id:
		"mushrooms":
			for x in [63,80,96]:
				block(x,23,3,8,"b8c4a2")
				block(x-5,20,13,4,"59a88f")
				block(x-2,18,7,3,"9de8b9")
				block(x,20,2,2,"e6f2ca")
			block(55,12,43,2,"58756d")
			block(63,9,33,2,"3b5b55")
		"deer", "deer_trail":
			block(72,22,19,8,"7ea6af")
			block(76,23,13,4,"a6d9dc")
			block(75,29,2,6,"91becb")
			block(86,29,2,6,"91becb")
			block(87,15,4,11,"a6d9dc")
			block(87,14,9,5,"cce8df")
			block(93,15,1,1,"223a44")
			block(88,8,2,7,"b8d8cd")
			block(85,8,3,2,"b8d8cd")
			block(91,10,3,2,"b8d8cd")
		"red_button":
			block(68,21,24,11,"575a59")
			block(65,19,30,4,"899391")
			block(76,17,9,3,"dd5d5a")
			block(78,16,5,2,"ffb89a")
			block(92,10,3,17,"688a50")
			block(87,12,12,2,"688a50")
			block(57,11,2,13,"968b65")
			block(53,9,12,6,"b7a479")
		"hollow":
			block(67,10,28,22,"72523b")
			block(71,12,20,18,"916c47")
			block(76,18,10,14,"18272a")
			block(74,21,14,10,"18272a")
		"rock":
			block(65,26,33,7,"505964")
			block(70,21,23,6,"818b91")
			block(75,19,14,3,"adb5ad")
			block(73,23,9,3,"c5cabc")
		"roots", "cache":
			block(66,20,28,13,"593f34")
			block(68,21,24,4,"b3915f")
			block(68,26,24,6,"8e6445")
			block(79,24,3,5,"e7c989")
			if event_id == "roots":
				block(60,26,38,3,"6b7953")
				block(72,14,3,19,"6b7953")
				block(86,17,3,19,"6b7953")
		_:
			block(76,12,9,8,"b4a58c")
			block(74,10,13,4,"696476")
			block(72,20,17,12,"797086")
			block(74,31,4,4,"494554")
			block(83,31,4,4,"494554")
			block(78,15,1,2,"263036")
			block(83,15,1,2,"263036")
			block(96,24,8,8,"987a55")
