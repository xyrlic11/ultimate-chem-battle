extends RefCounted

## Phase F: event screens standing in for the shop at fixed points.
##
## Scoped down on purpose from the full "roguelike branching map" idea in
## PLAYER-FEEDBACK-SPEC.md §5 (ทิศ A there) -- that version changes `wave`
## from a difficulty index into map depth and touches save format, UI and
## every phase A-E at once. This version changes NONE of that: the 20 waves
## still run in a straight line, an event just replaces the shop screen at
## four fixed points, and every effect below is built from mechanics that
## already existed (GameState.add_gold/lose_gold, plus one new *unsaved*
## shop-price multiplier). Nothing here touches combat, the board, or the
## save file's format -- see game_state.gd's shop_price_mult for why that
## field specifically is never written to disk.
##
## The two cards that used to grant a catalyst were replaced 2026-09-01 when
## the catalyst mechanic itself was removed -- gold/shop-price effects only,
## same as everything else here.
##
## Because it shares no code path with phases A-E, this can ship independently
## and cannot regress anything they cover.

## Lands right after clearing wave 3/7/11/15 -- never the wave-20 boss, and
## spaced so an event is roughly a fifth of the run apart, not a screen every
## couple of waves.
const TRIGGER_WAVES := [4, 8, 12, 16]

## Player picks 1 of 3. Two safe, one a real gamble -- always in this order so
## a checker can assert on it, but pick_choice_cards() below still shuffles
## which three (of however many exist later) get OFFERED.
const CHOICE_CARDS := [
	{
		"id": "traveler_gift", "title": "💰 ของขวัญนักเดินทาง",
		"desc": "รับทองฟรีทันที",
		"kind": "gold_flat", "per_wave": 15,
	},
	{
		"id": "cheap_shop", "title": "🏪 ตลาดลดราคา",
		"desc": "ร้านค้ารอบนี้ราคาถูกลง 25%",
		"kind": "shop_mult", "mult": 0.75,
	},
	{
		"id": "gold_gamble", "title": "🔄 เสี่ยงดวงกับพ่อค้า",
		"desc": "เสี่ยงดวง: 50% ได้ทอง ×2 · 50% เสียทองครึ่งหนึ่ง",
		"kind": "gold_gamble",
	},
]

## No choice -- one of these lands, and the pool always has both a good and a
## bad half. Without that split this is just a free-reward screen, which is
## specifically NOT what was asked for.
const FORCED_EVENTS := [
	{
		"id": "bonus_reaction", "good": true, "title": "⚗ ปฏิกิริยาโบนัส",
		"desc": "นักเล่นแร่แปรธาตุใจดีข้างทางมอบทองให้",
		"kind": "gold_flat", "per_wave": 12,
	},
	{
		"id": "generous_merchant", "good": true, "title": "🏪 พ่อค้าใจดี",
		"desc": "ร้านค้ารอบนี้ราคาถูกลง 20%",
		"kind": "shop_mult", "mult": 0.8,
	},
	{
		"id": "factory_broken", "good": false, "title": "💥 โรงงานเสีย",
		"desc": "ร้านค้ารอบนี้ราคา +50%",
		"kind": "shop_mult", "mult": 1.5,
	},
	{
		"id": "spoiled_stock", "good": false, "title": "🧪 สินค้าเสียหาย",
		"desc": "ของเสียหายระหว่างขนส่ง เสียทองไป 15%",
		"kind": "gold_loss_pct", "pct": 0.15,
	},
]


static func is_trigger_wave(wave: int) -> bool:
	return TRIGGER_WAVES.has(wave)


## Alternates choice/forced by POSITION in TRIGGER_WAVES, not a coin flip --
## deterministic, so the same run always alternates the same way and a
## checker can assert on which type shows up at which wave.
static func is_choice_wave(wave: int) -> bool:
	var idx := TRIGGER_WAVES.find(wave)
	return idx >= 0 and idx % 2 == 0


static func pick_choice_cards(n: int) -> Array:
	var pool := CHOICE_CARDS.duplicate(true)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


## A coin flip between the GOOD pool and the BAD pool, not one flat roll over
## all four -- rolling over the flat list could hand a run three "good"
## trigger-waves in a row by chance, and it would stop reading as risk.
static func pick_forced_event() -> Dictionary:
	var goods: Array = FORCED_EVENTS.filter(func(e): return e.good)
	var bads: Array = FORCED_EVENTS.filter(func(e): return not e.good)
	var pool: Array = goods if randf() < 0.5 else bads
	return pool[randi() % pool.size()]


## Applies one card/event's effect against a live GameState. Returns the
## signed gold delta actually applied (0 for a non-gold effect), so the
## caller can show a truthful "+40" / "-12" rather than re-deriving it.
##
## Deliberately a short, closed list of `kind`s rather than a generic
## "eval this dictionary" mechanism -- every effect this file can produce is
## enumerated above, so there is no path to an effect nobody wrote.
static func apply(card: Dictionary, state) -> int:
	match str(card.get("kind", "")):
		"shop_mult":
			state.shop_price_mult = float(card.get("mult", 1.0))
			return 0
		"gold_gamble":
			if randf() < 0.5:
				# add_gold() adds ON TOP of the current total, so adding a
				# second copy of it is what makes the total exactly double.
				var gain: int = state.gold
				state.add_gold(gain)
				return gain
			var loss: int = state.lose_gold(int(state.gold / 2.0))
			return -loss
		"gold_flat":
			var amount: int = int(card.get("per_wave", 0)) * maxi(1, state.wave)
			state.add_gold(amount)
			return amount
		"gold_loss_pct":
			var lost: int = state.lose_gold(int(state.gold * float(card.get("pct", 0.0))))
			return -lost
	return 0
