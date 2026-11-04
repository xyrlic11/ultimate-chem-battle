extends PanelContainer

const Worlds := preload("res://scripts/worlds.gd")

@onready var _region_name: Label = %RegionName
@onready var _region_progress: Label = %RegionProgress


var _last_wave := -1

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null and int(state.wave) != _last_wave:
		_refresh()

func _refresh() -> void:
	var state := get_node_or_null("/root/GameState")
	var wave := int(state.get("wave")) if state != null else 1
	_last_wave = wave
	var region := Worlds.region_for_wave(wave)
	_region_name.text = str(region.name)
	_region_name.add_theme_color_override("font_color", region.accent)
	_region_progress.text = "ช่วง %d/%d · เดินทาง %d" % [
		Worlds.wave_in_region(wave), Worlds.WAVES_PER_REGION, wave]
	tooltip_text = str(region.subtitle)
