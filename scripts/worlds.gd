class_name AdventureWorlds
extends RefCounted

## Adventure regions layered over the existing 25-stage run.
##
## Five stages per region ends at each boss checkpoint (5/10/15/20/25), so the
## fantasy journey adds identity and navigation without changing combat or
## economy balance.  Keep gameplay colours in recipes.gd; these palettes are
## scenery/chrome only.

const WAVES_PER_REGION := preload("res://scripts/campaign.gd").STAGES_PER_REGION
const EVENT_CAMPFIRE_BACKGROUND := "res://assets/backgrounds/pixel/prep_02_expedition_camp.png"

const REGIONS: Array[Dictionary] = [
	{
		"id": "luminous_forest",
		"name": "พงไพรเรืองแสง",
		"subtitle": "รากไม้โบราณปลุกธาตุแรกให้ตื่นขึ้น",
		"sky_top": Color("10142b"),
		"sky_bottom": Color("16363a"),
		"silhouette": Color("091a20"),
		"accent": Color("63e6be"),
		"battle_background": "res://assets/backgrounds/bg_01_luminous_forest.png",
		"prep_background": "res://assets/backgrounds/bg_01_luminous_forest.png",
	},
	{
		"id": "abandoned_village",
		"name": "หมู่บ้านที่ถูกลืม",
		"subtitle": "ตามรอยพลังปริศนาผ่านบ้านเรือนที่ไร้ผู้คน",
		"sky_top": Color("151525"),
		"sky_bottom": Color("3a3347"),
		"silhouette": Color("111018"),
		"accent": Color("d29a67"),
		"battle_background": "res://assets/backgrounds/bg_02_abandoned_village.png",
		"prep_background": "res://assets/backgrounds/bg_02_abandoned_village.png",
	},
	{
		"id": "floating_castle",
		"name": "ปราสาทลอยฟ้า",
		"subtitle": "หอคอยนักเล่นแร่แปรธาตุเหนือหมู่เมฆ",
		"sky_top": Color("171636"),
		"sky_bottom": Color("3c3b70"),
		"silhouette": Color("15162b"),
		"accent": Color("a8c7ff"),
		"battle_background": "res://assets/backgrounds/bg_03_floating_castle.png",
		"prep_background": "res://assets/backgrounds/bg_03_floating_castle.png",
	},
	{
		"id": "dragon_cavern",
		"name": "ถ้ำมังกรเพลิง",
		"subtitle": "โลหะหลอมเหลวและออกไซด์คำรามใต้ภูผา",
		"sky_top": Color("1c0d16"),
		"sky_bottom": Color("54231d"),
		"silhouette": Color("10090c"),
		"accent": Color("ff9f43"),
		"battle_background": "res://assets/backgrounds/bg_04_dragon_cavern.png",
		"prep_background": "res://assets/backgrounds/bg_04_dragon_cavern.png",
	},
	{
		"id": "astral_sanctuary",
		"name": "วิหารดารานิรันดร์",
		"subtitle": "บททดสอบสุดท้าย ณ ต้นกำเนิดเวทแห่งธาตุ",
		"sky_top": Color("090d24"),
		"sky_bottom": Color("25235a"),
		"silhouette": Color("080a18"),
		"accent": Color("ffe08a"),
		"battle_background": "res://assets/backgrounds/bg_05_astral_sanctuary.png",
		"prep_background": "res://assets/backgrounds/bg_05_astral_sanctuary.png",
	},
]


static func region_index_for_wave(wave: int) -> int:
	var safe_wave := maxi(wave, 1)
	return mini(int(float(safe_wave - 1) / float(WAVES_PER_REGION)), REGIONS.size() - 1)


static func region_for_wave(wave: int) -> Dictionary:
	return REGIONS[region_index_for_wave(wave)]


static func wave_in_region(wave: int) -> int:
	return posmod(maxi(wave, 1) - 1, WAVES_PER_REGION) + 1


static func journey_label(wave: int) -> String:
	var region := region_for_wave(wave)
	return "%s · ด่าน %d/%d" % [region.name, wave_in_region(wave), WAVES_PER_REGION]
