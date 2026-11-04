extends RefCounted
## Voluntary, persisted consequences; completed fights include losses.
const KEYS := ["enemy_atk", "team_hp", "start_hp", "gold_debt"]
static func sanitize(raw) -> Array:
	var result: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary and item.get("key", "") in KEYS and item.get("scope", "") in ["battles", "region"]:
				var copy: Dictionary = item.duplicate(true)
				copy.value = clampf(float(copy.get("value", 0)), 0, 100) if copy.key == "gold_debt" else clampf(float(copy.get("value", 0)), -0.8, 2.0)
				copy.remaining = clampi(int(copy.get("remaining", 1)), 0 if copy.key == "gold_debt" else 1, 8)
				copy.arrears = clampi(int(copy.get("arrears", 0)), 0, 1000)
				copy.row = str(copy.get("row", ""))
				copy.label = str(copy.get("label", copy.key))
				result.append(copy)
	return result
static func add(state, item: Dictionary) -> void:
	state.run_modifiers.append_array(sanitize([item]))
static func value(state, key: String, row := "") -> float:
	var total := 0.0
	for item in state.run_modifiers:
		if item.key == key and (item.row == "" or item.row == row):
			total += float(item.value)
	return maxf(-0.8, total)
static func finish_battle(state, boss_won: bool) -> void:
	var remaining: Array = []
	for item in state.run_modifiers:
		if item.key == "gold_debt":
			if item.remaining > 0:
				item.arrears += int(item.value)
				item.remaining -= 1
			var paid: int = mini(state.gold, item.arrears)
			state.gold -= paid
			state.gold_changed.emit(state.gold)
			item.arrears -= paid
			if item.remaining > 0 or item.arrears > 0:
				remaining.append(item)
		elif item.scope == "region":
			if not boss_won:
				remaining.append(item)
		else:
			item.remaining -= 1
			if item.remaining > 0:
				remaining.append(item)
	state.run_modifiers = remaining
static func summary(state) -> String:
	var lines: Array[String] = []
	for item in state.run_modifiers:
		if item.key == "gold_debt":
			lines.append("%s · อีก %d สู้ · ค้าง %d ทอง" % [item.label, item.remaining, item.arrears])
			continue
		lines.append("%s · %s" % [item.label, "จนชนะบอส" if item.scope == "region" else "อีก %d สู้" % item.remaining])
	return "\n".join(lines)
