extends RefCounted

const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")


static func recipe_for(key: String) -> Dictionary:
	return Recipes.RECIPES.get(key, Recipes.TIER2_RECIPES.get(key, {}))


static func requirements(key: String, items: Array, roster: Dictionary) -> Dictionary:
	# Only loose atoms can be bought. Finished ingredients remain whole; never
	# pretend the player can recover the atoms locked inside another compound.
	var inventory := {}
	for item in items:
		var token := str(item.key)
		inventory[token] = int(inventory.get(token, 0)) + 1
	var result := {"components": [], "missing_atoms": {}, "fielded": [], "steps": []}
	if recipe_for(key).is_empty():
		return result
	var required := {}
	for token in key.split(","):
		required[token] = int(required.get(token, 0)) + 1
	if Recipes.RECIPES.has(key):
		# Reuse whole intermediates only when the actual crafting matcher accepts
		# them. Never split a molecule or consume the desired product itself.
		var chosen: Array = []
		for token in inventory:
			if Recipes.ELEMENTS.has(token) or token == recipe_for(key).formula:
				continue
			var atoms: Array = Recipes.atoms_of(token)
			if atoms.is_empty():
				continue
			var remaining: Dictionary = required.duplicate()
			var fits := true
			var useful := false
			for atom in atoms:
				if int(remaining.get(atom, 0)) <= 0:
					fits = false
					break
				if int(remaining[atom]) > int(inventory.get(atom, 0)):
					useful = true
				remaining[atom] -= 1
			if not fits or not useful:
				continue
			var candidate: Array = chosen.duplicate()
			candidate.append({"formula": token, "atoms": atoms})
			var parts: Array = candidate.duplicate()
			for atom in remaining:
				for _i in int(remaining[atom]):
					parts.append({"formula": "", "atoms": [atom]})
			if Recipes._match_whole(parts).get("key", "") != key:
				continue
			chosen = candidate
			required = remaining
			result.components.append("%s 1/1" % token)
			if roster.has(token) and roster[token].get("row", "bench") != "bench":
				result.fielded.append(token)
		for atom in required.keys():
			if required[atom] == 0:
				required.erase(atom)
	for token in required:
		var need: int = required[token]
		var have := mini(need, int(inventory.get(token, 0)))
		result.components.append("%s %d/%d" % [token, have, need])
		if have > 0 and roster.has(token) and roster[token].get("row", "bench") != "bench":
			result.fielded.append(token)
		inventory[token] = int(inventory.get(token, 0)) - have
		for _i in need - have:
			if Recipes.ELEMENTS.has(token):
				result.missing_atoms[token] = int(result.missing_atoms.get(token, 0)) + 1
			else:
				# All current tier-2 inputs have a direct tier-1 route.
				for route in Recipes.RECIPES:
					if Recipes.RECIPES[route].formula != token:
						continue
					result.steps.append("%s -> %s" % [" + ".join(route.split(",")), token])
					for atom in route.split(","):
						if int(inventory.get(atom, 0)) > 0:
							inventory[atom] -= 1
						else:
							result.missing_atoms[atom] = int(result.missing_atoms.get(atom, 0)) + 1
					break
	return result


static func synergy_change(roster: Dictionary, formula: String, row: String, bonus: Dictionary = {}) -> String:
	var before := {}
	for key in roster:
		if roster[key].get("row", "front") != Traits.ROW_BENCH:
			before[key] = roster[key]
	var after := before.duplicate(true)
	if row == Traits.ROW_BENCH:
		after.erase(formula)
	elif roster.has(formula):
		after[formula] = roster[formula]
	var a := Traits.trait_counts(before, bonus)
	var b := Traits.trait_counts(after, bonus)
	var lines: Array[String] = []
	for trait_id in Traits.ORDER:
		var old := int(a.get(trait_id, 0))
		var next := int(b.get(trait_id, 0))
		if old == next:
			continue
		var threshold := Traits.next_threshold(trait_id, mini(old, next))
		if threshold == 0:
			threshold = int(Traits.TRAITS[trait_id].tiers[-1].count)
		var marker := ""
		if Traits.tier_for_count(trait_id, next) > Traits.tier_for_count(trait_id, old):
			marker = " เปิดขั้นใหม่"
		elif Traits.tier_for_count(trait_id, next) < Traits.tier_for_count(trait_id, old):
			marker = " ลดขั้น"
		lines.append("%s %d/%d -> %d/%d%s" % [Traits.label_of(trait_id), old,
			threshold, next, threshold, marker])
	return "\n".join(lines) if not lines.is_empty() else "สายพลังเท่าเดิม (นับชนิด ไม่ใช่จำนวนซ้ำ)"
