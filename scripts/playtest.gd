extends Node
## Optional local diagnostics. No network requests or changes to game saves.
const FILE := "user://web_playtest_metrics.json"
var stats: Dictionary = {}
func _ready() -> void:
	if not OS.has_feature("web"): return
	if FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary: stats = parsed
	_publish()
func begin() -> void:
	if not OS.has_feature("web"): return
	stats = {"version":"2026-10-06", "started":Time.get_unix_time_from_system(), "events":0, "skips":0, "battles":0, "bosses":0, "step":1, "compounds":{}, "result":"playing"}
	_save()
func event_selected() -> void:
	if stats.is_empty(): return
	stats.events = int(stats.events)+1
	_save()
func skipped() -> void:
	if stats.is_empty(): return
	stats.skips = int(stats.skips)+1
	_save()
func battle_finished(victory: bool, fighters: Array) -> void:
	if stats.is_empty(): return
	stats.battles = int(stats.battles)+1
	stats.step = GameState.wave
	stats.region = ceili(GameState.wave/5.0)
	if victory and GameState.is_boss_wave(): stats.bosses = int(stats.bosses)+1
	for fighter in fighters:
		stats.compounds[fighter.formula] = int(stats.compounds.get(fighter.formula,0))+1
	stats.elapsed_seconds = maxi(0,int(Time.get_unix_time_from_system()-float(stats.started)))
	if not victory: stats.result = "defeat"
	elif GameState.is_final_wave(): stats.result = "victory"
	_save()
func _save() -> void:
	var file := FileAccess.open(FILE,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(stats))
	_publish()
func _publish() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ucbSummary="+JSON.stringify(stats)+";",true)
