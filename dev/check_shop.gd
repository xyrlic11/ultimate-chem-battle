extends SceneTree
func _initialize():
	call_deferred("check")
func check():
	root.size = Vector2i(1024, 768)
	change_scene_to_file("res://scenes/Main.tscn")
	for i in range(20): await process_frame
	current_scene._toggle_shop()
	for i in range(20): await process_frame
	for n in current_scene.find_children("*", "Control", true, false):
		if "ShopPopup" in str(n.get_path()): print(n.get_path(), " rect=",n.get_global_rect()," min=",n.get_combined_minimum_size()," visible=",n.is_visible_in_tree())
	quit()
