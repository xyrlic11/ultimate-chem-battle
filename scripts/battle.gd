extends Control

## Auto-Battle board (proposal section 3.1 L5-2 / section 3.3 M5).
##
## All player agency lives in the shop phase -- which compounds you craft, which
## synergies you complete, and which row you put them in. Once the fight starts
## it resolves itself, which is the auto-battler convention this game follows.
##
## Two layers decide a fight:
##   1. The type triangle (acid > metal > base > acid) -- per-attack matchup.
##   2. Synergies (traits.gd) -- team-wide bonuses from owning enough distinct
##      compounds sharing a trait.
## Every synergy number is read from traits.gd through Traits.value(); none are
## hardcoded here, so balancing happens in one file.

const Recipes := preload("res://scripts/recipes.gd")
const Traits := preload("res://scripts/traits.gd")
const UnitAbilities := preload("res://scripts/unit_abilities.gd")
const Events := preload("res://scripts/events.gd")
const HpVessel := preload("res://scripts/hp_vessel.gd")
const BattleStatus := preload("res://scripts/battle_status.gd")

signal skill_presented(caster_formula: String, target_formula: String, effect: String)

const STATUS_OK := Color(0.55, 1.0, 0.55)
const STATUS_BAD := Color(1.0, 0.5, 0.5)
const STATUS_INFO := Color(0.85, 0.85, 0.95)
const STATUS_TRAIT := Color(0.95, 0.85, 0.45)

# Losing a battle costs the player's own HP, not gold or the wave number
# (2026-09-01 feedback). REPLACES the old system entirely -- that one charged
# Team defeat ends the run immediately. Team HP persists between victories.

## Monster scaling. See _spawn_monster() for why HP tracks team size and ATK
## does not. Tuned so wave 1 with a single compound is a narrow win -- losing
## the first fight straight out of the tutorial is a terrible first impression --
## and a full board around wave 10 is still a real fight.
const WAVE_SCALING := 0.30
const MONSTER_HP_BASE := 1.3
## Dropped from 0.75 once fights got longer, then left alone. NOTE: the win
## rates once quoted here were measured with an ACID opener only. A typed
## opening compound won 65-70% of first fights and an untyped one 100% -- the
## gap was the type triangle, not this constant. Wave 1 now always fields a
## neutral training dummy (GameState.roll_next_monster), so every opener wins.
## Numbers come from tools/sim_balance.gd; do not quote one without saying
## which board it was measured on.
##
## Original note: longer fights average out the
const MONSTER_ATK_BASE := 0.62
const TEAM_SCALE_BASE := 0.6
const TEAM_SCALE_PER_FIGHTER := 0.4
## Applied to waves 1-2 only. See _spawn_monster().
const EARLY_WAVE_RELIEF := 0.78

## The wave-20 boss. A boss that is merely "wave 20, but a bit more" is not a
## finale -- sim_run.gd showed a synergy-aware board clearing wave 20 without
## dropping a fighter, so an ordinary monster there would be a formality. These
## are sized against that measurement, not chosen for feel.
const BOSS_HP_MULT := 4.0
const BOSS_ATK_MULT := 1.8

## Base seconds between ticks. Lives here rather than inline so the 2x speed
## button has one number to divide.
const Timing := preload("res://scripts/combat_timing.gd")
const TICK_SECONDS := Timing.ROUND_SECONDS

## Pause after each individual turn's attack cue, Phase C (2026-09-01) -- long
## enough to read the strike streak + damage number before the next fighter's
## turn starts. Scaled by the same 2x toggle as TICK_SECONDS. Skipped entirely
## under _should_animate() == false, so it costs nothing in a headless test.
const BEAT_SECONDS := Timing.IMPACT_SECONDS

## The interactive layer. Energy accrues every tick and the three abilities
## spend it; the ceiling is low on purpose so banking is a real choice with a
## real limit rather than a savings account.
const ENERGY_MAX := 10
const ENERGY_PER_TICK := 1
const COST_CATALYSE := 4
const COST_HEAL := 5
const COST_BURST := 8
const HEAL_PCT := 0.25
const BURST_ATK_MULT := 2.0

## The monster winds up a heavy swing every CHARGE_EVERY ticks and lands it on
## the NEXT one. Announced a tick ahead deliberately: an unannounced spike is
## just bad luck, while one the player can see coming is the thing that makes
## the abilities a decision instead of a spam button.
const CHARGE_EVERY := 5
const CHARGE_MULT := 2.2

class Fighter:
	var formula: String
	var kind: String
	var count: int = 1
	var traits: Array = []
	## Literal rather than Traits.ROW_FRONT: inner classes resolving outer-script
	## constants at member-initialiser time is not worth relying on.
	var row: String = "front"
	var hp: float
	var max_hp: float
	var atk: float
	var hp_bar: HpVessel
	var chip: PanelContainer
	var is_monster: bool = false
	## Set once the death effects (fade, alkali blast) have fired, so a fighter
	## that dies cannot trigger them again on a later tick.
	var death_resolved: bool = false

	## A boss skill's lingering effect on a PLAYER fighter (2026-09-01).
	## "" | "corroded" (acid: attacks weaker) | "locked" (salt: acts last).
	## Metal's armor-pierce and base's self-heal are one-shot and never touch
	## this -- they resolve at the moment the heavy hit lands, nothing to track
	## between rounds.
	var status_kind: String = ""
	var status_turns := 0
	var status_applied_round := -1
	var status_value := 0.0

	## Phase D: one automatic signature ability per craftable compound.  These
	## fields are deliberately combat-only; cooldowns and temporary effects do
	## not belong in the persistent roster/save file.
	var ability: Dictionary = {}
	var ability_cd := 0
	var shield := 0.0
	var guard_value := 0.0
	var guard_turns := 0
	var next_attack_bonus := 0.0
	var armor_break_sources: Dictionary = {}
	var attack_down_sources: Dictionary = {}
	var dot_sources: Dictionary = {}
	var status_view: Control
	# Effective values, combat-only. Never serialize these into the roster.
	var damage_dealt := 0.0
	var damage_taken := 0.0
	var healing_done := 0.0
	var shield_absorbed := 0.0

	func has_trait(t: String) -> bool:
		return traits.has(t)

@onready var _wave_label: Label = %WaveLabel
@onready var _trait_bar: HBoxContainer = %TraitBar
@onready var _turn_queue: HBoxContainer = %TurnQueue
@onready var _battle_coach: PanelContainer = %BattleCoach
@onready var _battle_coach_skip: Button = %CoachSkip
@onready var _monster_art: Control = %MonsterArt
@onready var _monster_name: Label = %MonsterName
@onready var _monster_hp_bar: HpVessel = %MonsterHP
@onready var _monster_hp_label: Label = %MonsterHPLabel
@onready var _boss_skill_icon: Label = %BossSkillIcon
@onready var _front_row: HBoxContainer = %FrontRow
@onready var _back_row: HBoxContainer = %BackRow
@onready var _front_empty: Label = %FrontEmptyHint
@onready var _log_list: VBoxContainer = %LogList
## The whole overlay, dimmer included -- shown and hidden as one.
@onready var _result_panel: Control = %ResultPanel
## Just the banner. The scale-in plays on this, never on _result_panel: scaling
## the overlay would scale the dimmer with it and the screen would appear to
## zoom rather than the banner arriving.
@onready var _result_box: PanelContainer = %ResultBoxPanel
@onready var _result_label: Label = %ResultLabel
@onready var _result_reason: Label = %ResultReason
@onready var _next_wave_button: Button = %NextWaveButton
@onready var _shop_button: Button = %ShopButton
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _energy_label: Label = %EnergyLabel
@onready var _catalyse_button: Button = %CatalyseButton
@onready var _heal_button: Button = %HealButton
@onready var _burst_button: Button = %BurstButton
@onready var _speed_button: Button = %SpeedButton

## Set by tools/sim_balance.gd. Skips log lines and visual effects so a
## simulated run measures combat rather than node allocation -- a few hundred
## simulated battles otherwise spawn well over a million throwaway Labels and
## the simulator never finishes. Never set in normal play.
var silent := false

## Set when the wave-20 boss dies. Repoints the result panel's remaining button
## at the title screen: after complete_run() there is no shop to go back to,
## the run behind it is a brand new one.
var _run_won := false
## Set at the top of _finish(). Read by _on_shop_pressed() so a Phase F event
## only ever triggers off a WIN advancing forward into a trigger wave, never
## off a defeat's wave-setback coincidentally landing on the same number.
var _victory := false
## Team defeat ends the run. Same routing treatment as
## _run_won -- both send the player home rather than back to a shop whose
## state GameState has already reset out from under this scene.
var _run_lost := false

var _tick_timer: Timer
var _players: Array = []
var _monster: Fighter
var _turn := 0
var _tick_count := 0
var _battle_over := false
## True while a round's turns are still being animated (Phase C). Guards
## against _tick_timer firing again before the previous round's beats finish
## playing -- a round can now take longer in real time than TICK_SECONDS,
## since it plays out one turn at a time instead of all at once.
var _resolving := false

var _energy := 0
var _speed_fast := false
var _speed_multiplier := 1.0
var _reward_popup: Control
const Campaign := preload("res://scripts/campaign.gd")
const Flow := preload("res://scripts/run_flow.gd")
const Risk := preload("res://scripts/run_risk.gd")
const Rewards := preload("res://scripts/boss_rewards.gd")

## True for the one tick between the monster announcing a heavy swing and
## landing it. Read at the top of the tick so the multiplier applies to that
## tick's attack and nothing else.
var _charging := false
var _charge_mult := 1.0
## trait id -> active tier, computed once per wave from the roster.
var _active: Dictionary = {}
## Type-advantage explanations already shown this battle. The reason is worth
## reading once; repeated on every crit it becomes noise the player scrolls past.
var _reasons_shown: Dictionary = {}
var _shared := {"damage": 0.0, "heal": 0.0}
var _manual := {"damage": 0.0, "heal": 0.0}
var _skill_actor: Fighter


func _ready() -> void:
	Audio.play_music("battle")
	_next_wave_button.pressed.connect(_on_next_wave_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)

	_tick_timer = Timer.new()
	add_child(_tick_timer)
	_tick_timer.wait_time = 0.9
	_tick_timer.timeout.connect(_on_tick)

	_catalyse_button.pressed.connect(_on_catalyse_pressed)
	_heal_button.pressed.connect(_on_heal_pressed)
	_burst_button.pressed.connect(_on_burst_pressed)
	_speed_button.pressed.connect(_on_speed_pressed)
	_apply_speed()

	# One-time coach (2026-09-01): the type triangle used to live permanently
	# in TopLine and re-evaluate its own visibility every wave via
	# _refresh_type_legend(). It is gone -- this shows once, ever, across the
	# whole game, same shape as Main.tscn's shop coach.
	_battle_coach.visible = not GameState.battle_tutorial_done
	_battle_coach_skip.pressed.connect(_on_battle_coach_skip)

	_start_wave()
	_refresh_actions()


func _start_wave() -> void:
	_shared = {"damage": 0.0, "heal": 0.0}
	_manual = {"damage": 0.0, "heal": 0.0}
	_battle_over = false
	_turn = 0
	_tick_count = 0
	# Energy does not carry between waves. Banking a full bar during an easy
	# fight and opening the next one with it would let the player skip the
	# build-up that makes the abilities a decision at all.
	_energy = 0
	_charging = false
	_charge_mult = 1.0
	_result_panel.visible = false
	# The finale announces itself. A boss that looks like wave 19 with a bigger
	# health bar is a difficulty spike; a boss the player was told about is a
	# finale they get to prepare for.
	if GameState.is_final_wave():
		_wave_label.text = "บอส %d/%d · ด่าน %d/%d" % [Campaign.BOSS_COUNT, Campaign.BOSS_COUNT, Campaign.FINAL_WAVE, Campaign.FINAL_WAVE]
	elif GameState.is_boss_wave():
		_wave_label.text = "บอส %d/%d · ด่าน %d/%d" % [int(GameState.wave / Campaign.STAGES_PER_REGION), Campaign.BOSS_COUNT, GameState.wave, Campaign.FINAL_WAVE]
	else:
		_wave_label.text = "เผชิญหน้า · เดินทาง %d/%d" % [GameState.wave, GameState.FINAL_WAVE]

	_reasons_shown.clear()
	_active = Traits.active_tiers(GameState.fielded_roster(), GameState.trait_bonus())
	_build_trait_bar()
	if _turn_queue != null:
		for c in _turn_queue.get_children():
			c.queue_free()

	_spawn_players()
	_spawn_monster()

	_log("เริ่มการต่อสู้ด่านที่ %d!" % GameState.wave, STATUS_INFO)
	_announce_synergies()
	_tick_timer.start()


# --- setup -----------------------------------------------------------------

func _build_trait_bar() -> void:
	for c in _trait_bar.get_children():
		c.queue_free()

	if _active.is_empty():
		var none := Label.new()
		none.text = "สายพลัง —"
		none.tooltip_text = "ผสมสารต่างชนิดในสายเดียวกันเพื่อเปิดโบนัสสายพลัง"
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.58))
		_trait_bar.add_child(none)
		return

	for trait_id in Traits.ORDER:
		if not _active.has(trait_id):
			continue
		var tier := int(_active[trait_id])
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.16, 0.22, 0.9)
		style.border_color = Traits.color_of(trait_id)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = "%s %d" % [Traits.label_of(trait_id), tier]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Traits.color_of(trait_id))
		label.tooltip_text = Traits.active_text(trait_id, tier)
		chip.tooltip_text = label.tooltip_text
		chip.add_child(label)
		_trait_bar.add_child(chip)


func _announce_synergies() -> void:
	for trait_id in Traits.ORDER:
		if not _active.has(trait_id):
			continue
		var tier := int(_active[trait_id])
		_log("✨ %s %d: %s" % [
			Traits.label_of(trait_id), tier, Traits.active_text(trait_id, tier)
		], STATUS_TRAIT)


func _spawn_players() -> void:
	for c in _front_row.get_children():
		c.queue_free()
	for c in _back_row.get_children():
		c.queue_free()
	_players.clear()

	# Front row acts first each round: they are the ones in contact.
	for row in [Traits.ROW_FRONT, Traits.ROW_BACK]:
		for formula in GameState.formulas_in_row(row):
			var f := _make_fighter(formula, GameState.roster[formula], row)
			_players.append(f)
			(_front_row if row == Traits.ROW_FRONT else _back_row).add_child(f.chip)

	_front_empty.visible = _front_row.get_child_count() == 0

	# An empty back row held a fixed 114px of nothing. That was merely untidy
	# before; with the action bar taking 54px off the same 720px it squeezes the
	# battle log, and in the opening waves -- when the player has one or two
	# compounds and they are all in front -- the back row is empty every time.
	# The header above it stays, because it is what teaches that the row exists
	# and what it is for.
	var back_scroll: Control = _back_row.get_parent()
	back_scroll.visible = _back_row.get_child_count() > 0


func _make_fighter(formula: String, info: Dictionary, row: String) -> Fighter:
	var stats := UnitAbilities.combat_stats(formula, info, row, _active)

	var f := Fighter.new()
	f.formula = formula
	f.kind = info.kind
	f.count = int(info.get("count", 1))
	f.traits = info.get("traits", [])
	f.row = row
	f.ability = UnitAbilities.skill_of(formula)
	if not f.ability.is_empty():
		f.ability = f.ability.duplicate(true)
		f.ability.cooldown = maxi(2, int(f.ability.cooldown) - int(Rewards.bonus(GameState.run_buffs, "cooldown")))
	if not f.ability.is_empty():
		# Stagger the opening casts so a full seven-unit board does not cover the
		# screen with seven skill names on round one.
		f.ability_cd = maxi(1, ceili(float(f.ability.cooldown) * 0.5))

	f.max_hp = stats.hp * (1.0 + Rewards.bonus(GameState.run_buffs, "hp"))
	f.max_hp *= 1.0 + Risk.value(GameState, "team_hp", f.row)
	f.hp = f.max_hp * minf(Flow.condition(GameState, formula), 1.0 + Risk.value(GameState, "start_hp", f.row))
	f.shield = f.max_hp * Rewards.bonus(GameState.run_buffs, "shield")
	f.atk = stats.atk * (1.0 + Rewards.bonus(GameState.run_buffs, "atk"))
	f.chip = _make_chip(f)
	return f


func _make_chip(f: Fighter) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(104, 104)
	panel.custom_minimum_size.x = 150

	var style := StyleBoxFlat.new()
	style.bg_color = UiTokens.CARD_SURFACE
	style.border_color = Recipes.KIND_COLOR.get(f.kind, Color.WHITE)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 3
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.02, 0.015, 0.04, 0.45)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var portrait := preload("res://scripts/compound_art.gd").new()
	portrait.custom_minimum_size = Vector2(58, 54)
	portrait.setup(f.formula, int(GameState.roster.get(f.formula, {}).get("tier", 1)))
	heading.add_child(portrait)
	panel.set_meta("combat_portrait", portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(identity)

	var name_label := Label.new()
	name_label.text = "%s ×%d" % [f.formula, f.count] if f.count > 1 else f.formula
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	identity.add_child(name_label)

	# Roles and traits live in inspection text; during battle this vertical
	# space belongs to changing statuses, not repeated preparation metadata.

	if not f.ability.is_empty():
		var ability_label := Label.new()
		ability_label.text = {"Fe2": "กำบัง", "CH4": "ระเบิด", "CaOH2": "ปูน", "Fe2O3": "สนิม"}.get(f.formula, str(f.ability.name))
		ability_label.tooltip_text = UnitAbilities.tooltip(f.formula)
		ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ability_label.add_theme_font_size_override("font_size", 14)
		ability_label.add_theme_color_override("font_color", Recipes.KIND_COLOR.get(f.kind, Color.WHITE))
		identity.add_child(ability_label)

	var hp_bar := HpVessel.new()
	hp_bar.custom_minimum_size = Vector2(0, 12)
	hp_bar.max_value = f.max_hp
	hp_bar.value = f.hp
	box.add_child(hp_bar)
	f.hp_bar = hp_bar
	f.status_view = BattleStatus.new()
	box.add_child(f.status_view)

	f.chip = panel
	_refresh_chip_tooltip(f)
	return panel


## Refresh both the live status strip and detailed inspection text.
func _refresh_chip_tooltip(f: Fighter) -> void:
	_refresh_status(f)
	if f.chip == null or not is_instance_valid(f.chip):
		return
	var status := ""
	if f.status_kind == "corroded":
		status = "\n☣ กัดกร่อน: พลังโจมตีลดลง %d%% (อีก %d ตา)" % [
			roundi(f.status_value * 100.0), f.status_turns]
	elif f.status_kind == "locked":
		status = "\n🔄 ตรึงประจุ: ลำดับการโจมตีช้าลง (อีก %d ตา)" % f.status_turns
	var ability_text := ""
	var trait_names: Array[String] = []
	for trait_id in f.traits:
		trait_names.append(Traits.label_of(trait_id))
	if not f.ability.is_empty():
		ability_text = "\nสกิล: %s (พร้อมใน %d ตา)\n%s" % [
			str(f.ability.name), f.ability_cd, UnitAbilities.tooltip(f.formula)]
	f.chip.tooltip_text = "%s (%s)\nHP %d · ATK %d\n%s%s%s" % [
		f.formula,
		Traits.ROW_LABEL.get(f.row, f.row),
		roundi(f.max_hp), roundi(f.atk),
		Recipes.KIND_LABEL.get(f.kind, f.kind),
		status,
		ability_text + "\nสายพลัง: " + " · ".join(trait_names),
	]
	f.chip.tooltip_text += "\n" + preload("res://scripts/attack_styles.gd").label(f.formula)


func _spawn_monster() -> void:
	# Decided in GameState so the shop could show it before the player committed.
	var enemy := GameState.encounter_enemy()
	var kind: String = enemy.kind
	var stats: Dictionary = Recipes.KIND_STATS.get(kind, Recipes.KIND_STATS["neutral"])

	# Retuned when every fighter started swinging. The old numbers assumed one
	# attacker per tick, so team damage did not grow with the board and the
	# monster ran away with the fight by wave 6.
	#
	# HP now tracks BOTH the wave and how many fighters are actually fielded.
	# Wave alone cannot work once damage scales with team size: a big board
	# would delete a wave-10 monster in two ticks, and a small one would be
	# hopeless against the same number. Matching the board is what keeps a fight
	# tense at every size, and it is what the genre does.
	#
	# ATK is left on wave alone. Scaling incoming damage with team size too
	# would punish the player for building the board the game just asked them
	# to build.
	var wave_scale := 1.0 + float(GameState.wave - 1) * WAVE_SCALING
	# Soft landing on the opening waves. A player arrives at wave 1 straight
	# from the tutorial with exactly one compound, and at full strength that
	# fight was a 70% win -- three students in ten would lose the first battle
	# they ever played. The discount lapses by wave 3, once there has been time
	# to build a board.
	if GameState.wave <= 2:
		wave_scale *= EARLY_WAVE_RELIEF
	var team_scale := TEAM_SCALE_BASE + TEAM_SCALE_PER_FIGHTER * float(maxi(1, _players.size()))
	var scale_factor := wave_scale

	_monster = Fighter.new()
	_monster.is_monster = true
	_monster.kind = kind
	# Deliberately empty. Synergies belong to the player's roster only -- giving
	# the monster its kind as a trait would hand it the player's own acid/metal
	# bonuses whenever those happened to be active.
	_monster.traits = []
	var boss_hp := (2.2 if not GameState.is_final_wave() else BOSS_HP_MULT) if GameState.is_boss_wave() else 1.0
	var boss_atk := (1.35 if not GameState.is_final_wave() else BOSS_ATK_MULT) if GameState.is_boss_wave() else 1.0
	_monster.max_hp = stats.hp * MONSTER_HP_BASE * wave_scale * team_scale * boss_hp
	_monster.hp = _monster.max_hp
	_monster.atk = stats.atk * MONSTER_ATK_BASE * scale_factor * boss_atk
	_monster.atk *= 1.0 + Risk.value(GameState, "enemy_atk")
	_monster.max_hp *= float(enemy.get("hp_mult", 1.0))
	_monster.hp = _monster.max_hp
	_monster.atk *= float(enemy.get("atk_mult", 1.0))
	_monster.formula = "มอนสเตอร์"
	_monster.status_view = %MonsterStatus

	# No emoji prefix here any more -- monster_art.gd draws the portrait beside
	# the name and picks its own silhouette from the kind.
	_monster_art.kind = kind
	_monster_art.formula = enemy.formula
	_monster_art.boss_mode = GameState.is_boss_wave()
	_monster_name.text = ("บอส · " if GameState.is_boss_wave() else "") + enemy.formula + (" · " + enemy.name if GameState.is_boss_wave() else "")
	if enemy.has("encounter"):
		_monster_name.text = str(enemy.encounter) + " · " + str(enemy.formula)
	_monster_name.tooltip_text = "%s · %s\nสาย%s" % [enemy.formula, enemy.name, Recipes.KIND_LABEL.get(kind, kind)]
	if GameState.is_boss_wave():
		_monster_name.tooltip_text += "\nอัลติ: %s\n%s" % [enemy.ultimate, Traits.boss_skill_text(kind, CHARGE_MULT)]
	_monster_name.add_theme_color_override("font_color", Recipes.KIND_COLOR.get(kind, Color.WHITE))
	_monster_hp_bar.max_value = _monster.max_hp
	_monster_hp_bar.value = _monster.hp

	# Boss skill icon (2026-09-01): tells the player what the boss's periodic
	# heavy hit does and how strong, without reading the log. Hidden for a
	# kind with none -- the wave-1 training dummy is deliberately soft.
	var skill: Dictionary = Traits.boss_skill(kind)
	_boss_skill_icon.visible = GameState.is_boss_wave() and not skill.is_empty()
	if not skill.is_empty():
		_boss_skill_icon.text = str(skill.icon)
		_boss_skill_icon.tooltip_text = Traits.boss_skill_text(kind, CHARGE_MULT)
		_boss_skill_icon.modulate = Color(1, 1, 1, 1)

	_update_monster_label()


func _update_monster_label() -> void:
	var corrosion := Traits.value(_active, "halogen", "corrosion")
	var suffix := "  ☣ กัดกร่อน -%d/ตา" % roundi(corrosion) if corrosion > 0.0 else ""
	# The charge warning goes on the monster's own line rather than a new node:
	# it is where the player is already looking, and it costs no layout on a
	# screen that has none to spare.
	if _charging:
		suffix += "   ☣ กำลังชาร์จท่าหนัก!"
	# The monster itself shows the wind-up too: bonds brighten and stretch. A
	# telegraph that exists only as a line of log text is one the player has to
	# be reading the log to notice.
	if _monster_art != null:
		_monster_art.charging = _charging
	# The skill icon brightens on the same _charging flag rather than a
	# second state variable -- "about to fire" is already tracked once.
	if _boss_skill_icon != null and _boss_skill_icon.visible:
		_boss_skill_icon.modulate = Color(1.4, 1.3, 1.0) if _charging else Color(1, 1, 1, 1)
	_monster_hp_label.text = "HP %d/%d%s" % [ceili(_monster.hp), ceili(_monster.max_hp), suffix]
	_refresh_status(_monster)


func _effect_badge(kind: String, text: String, tip: String) -> Dictionary:
	return {"kind": kind, "text": text, "tip": tip}


func _sources_tip(sources: Dictionary) -> String:
	var lines: Array[String] = []
	for source in sources:
		var turns := int(sources[source].turns)
		lines.append("%s: %s" % [source, "จนจบศึก" if turns < 0 else "เหลือ %d รอบ" % turns])
	return "\n".join(lines)


func _refresh_status(f: Fighter) -> void:
	if f == null or not is_instance_valid(f.status_view):
		return
	var data := _status_snapshot(f)
	if f.status_view.is_node_ready():
		f.status_view.show_state(data)
	else:
		f.status_view.call_deferred("show_state", data)


func _status_snapshot(f: Fighter) -> Dictionary:
	var data := {"dead": f.hp <= 0, "effects": [], "total": 1, "progress": 0,
		"cooldown_text": "หมดสภาพ" if f.hp <= 0 else "ไม่มีสกิล", "cooldown_tip": ""}
	if f.hp <= 0:
		return data
	if f.is_monster and GameState.is_boss_wave():
		data.total = CHARGE_EVERY + 1
		var rounds := CHARGE_EVERY - (_tick_count % CHARGE_EVERY) + 1
		data.progress = data.total if _charging else data.total - rounds
		data.cooldown_text = "อัลติ!" if _charging else "อัลติ · %d" % rounds
		data.cooldown_tip = str(Campaign.enemy(GameState.wave, f.kind).ultimate) + "\n" + Traits.boss_skill_text(f.kind, CHARGE_MULT)
	elif not f.ability.is_empty():
		data.total = int(f.ability.cooldown)
		data.progress = data.total - f.ability_cd
		data.cooldown_text = "พร้อม!" if f.ability_cd <= 1 else "สกิล · %d" % f.ability_cd
		data.cooldown_tip = "%s\nนับเมื่อถึงตาของตัวนี้ ร่ายอัตโนมัติ ไม่ใช่วินาที\n%s" % [f.ability.name, UnitAbilities.tooltip(f.formula)]
	if f.shield > 0:
		data.effects.append(_effect_badge("shield", "โล่ %d" % ceili(f.shield), "โล่รับดาเมจจากการโจมตีก่อน HP ไม่กันดาเมจต่อเนื่อง"))
	var down := _source_total(f.attack_down_sources, 0.40)
	if not f.is_monster and f.status_kind == "corroded":
		down = 1.0 - (1.0 - down) * (1.0 - f.status_value)
	if down > 0:
		data.effects.append(_effect_badge("attack", "ATK -%d%%" % roundi(down*100),
			"พลังโจมตีลดลง\n" + _sources_tip(f.attack_down_sources) +
			("\nบอสกัดกร่อน: เหลือ %d รอบ" % f.status_turns if f.status_kind == "corroded" else "")))
	var armor := _source_total(f.armor_break_sources, 0.45)
	if armor > 0:
		data.effects.append(_effect_badge("armor", "เกราะ -%d%%" % roundi(armor*100), "รับดาเมจโจมตีเพิ่ม %d%%\n%s" % [roundi(armor*100), _sources_tip(f.armor_break_sources)]))
	# Keep poison, burning and rust distinct; they do not teach the same reaction.
	var dots := {}
	for source in f.dot_sources:
		var skill: Dictionary = UnitAbilities.skill_of(str(source))
		var effect := str(skill.get("effect", "dot"))
		var kind := "fire" if effect == "ignite" else ("rust" if effect == "rust" else "poison")
		if not dots.has(kind):
			dots[kind] = {"value": 0.0, "sources": {}}
		dots[kind].value += float(f.dot_sources[source].value)
		dots[kind].sources[source] = f.dot_sources[source]
	for kind in dots:
		var label: String = {"fire": "ไหม้", "rust": "สนิม", "poison": "พิษ"}[kind]
		data.effects.append(_effect_badge(kind, "%s %d/รอบ" % [label, ceili(dots[kind].value)],
			"เสีย HP ต้นรอบ\n" + _sources_tip(dots[kind].sources)))
	if f.guard_turns > 0:
		data.effects.append(_effect_badge("guard", "กัน %d%%" % roundi(f.guard_value*100), "ลดดาเมจโจมตี เหลือ %d รอบ" % f.guard_turns))
	if f.next_attack_bonus > 0:
		data.effects.append(_effect_badge("boost", "ตี +%d%%" % roundi(f.next_attack_bonus*100), "เพิ่มดาเมจโจมตีครั้งถัดไป แล้วหมดผล"))
	if f.status_kind == "locked":
		data.effects.append(_effect_badge("clock", "ตรึง %d รอบ" % f.status_turns, "อยู่ท้ายคิวโจมตี ไม่ได้หยุดโจมตี"))
	return data


# --- combat loop -----------------------------------------------------------

## Esc opens the shared settings panel as a pause menu. It freezes the tree, so
## the tick timer stops with it and the fight is genuinely paused rather than
## resolving behind the overlay.
func _input(event: InputEvent) -> void:
	if is_instance_valid(_speed_menu) and event is InputEventMouseButton and event.pressed:
		if not _speed_menu.get_global_rect().has_point(event.position) and not _speed_button.get_global_rect().has_point(event.position):
			_close_speed_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		var panel := get_node_or_null("%SettingsPanel")
		if panel != null and not panel.visible:
			Audio.play("click")
			panel.open(true)
			get_viewport().set_input_as_handled()


## Just above a chip's top edge -- where a floating number can be read without
## sitting on top of the chip's own text.
func _above(chip: Control) -> Vector2:
	return chip.global_position + Vector2(chip.size.x * 0.5, -6.0)


func _alive_players() -> Array:
	return _players.filter(func(f): return f.hp > 0)


func _alive_in_row(row: String) -> Array:
	return _players.filter(func(f): return f.hp > 0 and f.row == row)


func _on_tick() -> void:
	if _battle_over or _resolving:
		return
	_tick_count += 1
	_gain_energy(ENERGY_PER_TICK)

	# Phase D effects tick at the start of a round.  A DoT cast this round first
	# hurts on the next one; shields/debuffs are already active immediately.
	_tick_unit_effects()
	if _monster.hp <= 0:
		_finish(true)
		return
	if _alive_players().is_empty():
		_finish(false)
		return

	# The swing announced on the previous tick lands on this one. Captured in a
	# local because _charging is cleared below and the multiplier must survive
	# until after the monster has actually attacked.
	var heavy: bool = _charging
	_charge_mult = CHARGE_MULT if heavy else 1.0

	# แฮโลเจน: corrosion ticks before anyone swings, so it can finish a monster
	# off on its own -- a pure-halogen board is a viable if slow build.
	var corrosion := Traits.value(_active, "halogen", "corrosion")
	if corrosion > 0.0:
		_damage_monster(corrosion)
		if _monster.hp <= 0:
			_log("มอนสเตอร์ถูกกัดกร่อนจนสลาย ☣", STATUS_OK)
			_finish(true)
			return

	_apply_base_heal()

	var alive := _alive_players()
	if alive.is_empty():
		_finish(false)
		return

	_turn += 1
	_resolving = true
	await _resolve_round(heavy)
	_resolving = false


## True only in real play. Headless tools call _on_tick() directly in a tight
## synchronous loop and expect it to fully resolve one round before returning
## -- check_teaching.gd does this WITHOUT silent (it needs real log lines to
## inspect), so gating the per-turn pause on `silent` alone is not enough.
## DisplayServer.get_name() == "headless" is the same idiom rule 8 already
## uses to detect a tool context, and every existing caller of _on_tick() that
## is not the real _tick_timer runs under --headless.
func _should_animate() -> bool:
	return not silent and not _skipping_combat and DisplayServer.get_name() != "headless"


## One round: every alive fighter (players + monster) gets exactly one turn,
## ordered by Traits.speed_tier() with placement as the tie-break -- this is
## what the owner's own request meant by "การวางมีผลต่อลำดับการโจมตี". Total
## damage/energy/charge state per round is unchanged from the old
## everyone-at-once model; only the ORDER individual attacks land in changes,
## plus (in real play only) a per-turn visible beat between them.
func _resolve_round(heavy: bool) -> void:
	var queue := _build_round_queue()
	var player_count := 0
	for f in queue:
		if not f.is_monster:
			player_count += 1

	var round_damage := 0.0
	var round_crit := false
	var landed := 0
	var player_idx := 0

	for entry_i in queue.size():
		if _monster.hp <= 0 or _alive_players().is_empty():
			break
		var actor: Fighter = queue[entry_i]
		# Died earlier this same round -- to an earlier-in-queue monster hit,
		# most likely, now that the monster is not unconditionally last.
		if actor.hp <= 0:
			continue

		if _should_animate():
			var remaining: Array = queue.slice(entry_i).filter(func(f): return f.hp > 0)
			_refresh_turn_queue_ui(remaining)

		if actor == _monster:
			# Untyped on purpose: _pick_monster_target() returns Fighter *or*
			# null, which GDScript cannot express as a static return type, so
			# `:=` has nothing to infer from and fails to parse.
			var target = _pick_monster_target()
			if target == null:
				break
			if _should_animate():
				await _play_turn_beat(actor, target)
			_attack(_monster, target, true, false, 0, 1,
				heavy and _monster.kind == "metal")
			if heavy:
				_charging = false
				_charge_mult = 1.0
				_log("☣ ท่าหนักเข้าเต็มแรง!", STATUS_BAD)
				_apply_boss_skill(target)
			elif GameState.is_boss_wave() and _tick_count % CHARGE_EVERY == 0:
				_charging = true
				_log("☣ มอนสเตอร์กำลังชาร์จ! ตาหน้าแรง x%.1f — สะเทินรับ หรือสวนให้ตายก่อน"
					% CHARGE_MULT, STATUS_BAD)
			_update_monster_label()
		else:
			# A ready signature skill modifies this fighter's normal turn.  Support
			# skills still leave the ordinary attack intact; damage skills return an
			# extra multiplier for the first swing rather than inserting a surprise
			# out-of-turn action.
			var ability_damage_bonus := _try_cast_unit_ability(actor)
			var swings := 1
			# แก๊ส: light and fast -- a chance (or a certainty at tier 2) of a second swing.
			if actor.has_trait("gas"):
				var chance := Traits.value(_active, "gas", "double_chance")
				if chance > 0.0 and randf() < chance:
					swings = 2

			if _should_animate():
				await _play_turn_beat(actor, _monster)
			for swing_i in swings:
				if _monster.hp <= 0:
					break
				# Quiet: one line per fighter per tick would push six lines a
				# second through the log and nobody could read any of them.
				# Notable events still log individually inside _attack().
				var damage_mult := 1.0 + ability_damage_bonus if swing_i == 0 else 1.0
				round_damage += _attack(actor, _monster, false, true, player_idx,
					player_count, false, damage_mult)
				if Recipes.beats(actor.kind, _monster.kind):
					round_crit = true
				landed += 1
			player_idx += 1
		# Let recoil, damage numbers and the attacker's return read before
		# the next actor begins. Headless simulation stays synchronous.
		if _should_animate():
			await _wait_combat(Timing.RECOVERY_SECONDS)

	if landed > 0 and not silent:
		Audio.play("crit" if round_crit else "hit")
	if landed > 0:
		_log("ทีมของคุณโจมตีรวม -%d" % roundi(round_damage), STATUS_OK)

	_tick_down_statuses()
	_resolve_deaths()

	# An แอลคาไล death blast fired inside _resolve_deaths() can itself finish
	# the monster.
	if _monster.hp <= 0:
		_finish(true)
		return

	if _alive_players().is_empty():
		_finish(false)


## Every alive fighter (players first in row/position order, then the
## monster) sorted by speed. Rebuilt fresh each round: a death or a changed
## roster should not leave a stale order in play.
func _build_round_queue() -> Array:
	var queue: Array = _alive_players().duplicate()
	if _monster.hp > 0:
		queue.append(_monster)
	queue.sort_custom(_turn_order_less)
	return queue


func _turn_order_less(a: Fighter, b: Fighter) -> bool:
	var sa := _effective_speed_tier(a)
	var sb := _effective_speed_tier(b)
	if sa != sb:
		return sa > sb
	return _position_rank(a) < _position_rank(b)


## Boss "ตรึงประจุ" (salt) skill: a locked fighter acts as if slowest
## regardless of its own kind/gas -- below even `neutral`'s tier 0 -- for as
## long as status_turns lasts, decremented once per round in
## _resolve_round()'s tail.
func _effective_speed_tier(f: Fighter) -> int:
	if f.status_kind == "locked":
		return -1
	return Traits.speed_tier(f.kind, f.traits)


## Front row before back row, then left-to-right within that row -- the same
## "front row acts first, they're the ones in contact" logic _spawn_players()
## already used to order the old all-at-once loop. The monster ranks after
## every player position, since only a neutral-kind, non-gas player fighter
## (H2O) can ever tie its speed with a neutral-kind monster in the first place.
func _position_rank(f: Fighter) -> int:
	if f.is_monster:
		return 1 << 20
	var row: Array = _front_row.get_children() if f.row == Traits.ROW_FRONT else _back_row.get_children()
	var base := 0 if f.row == Traits.ROW_FRONT else 1 << 10
	for i in row.size():
		if row[i] == f.chip:
			return base + i
	return base


func _turn_control(f: Fighter) -> Control:
	return _monster_art if f.is_monster else f.chip

func _fighter_portrait(f: Fighter) -> Control:
	return _monster_art if f.is_monster else f.chip.get_meta("combat_portrait", f.chip)


## A separate portrait overlay travels while the real layout stays stable.
## Shared timing reaches impact before damage triggers recoil.
func _play_turn_beat(actor: Fighter, target: Fighter) -> void:
	_reveal_fighter(actor)
	var actor_ctrl := _fighter_portrait(actor)
	var target_ctrl := _fighter_portrait(target)
	if actor_ctrl != null and is_instance_valid(actor_ctrl):
		var motion := preload("res://scripts/fx_combat_motion.gd").new()
		add_child(motion)
		if actor.is_monster:
			actor_ctrl.ultimate = _charging and GameState.is_boss_wave()
			if actor_ctrl.ultimate:
				var banner := Label.new()
				banner.text = "อัลติ · " + str(Campaign.enemy(GameState.wave, actor.kind).ultimate)
				banner.add_theme_font_size_override("font_size", 28)
				banner.add_theme_color_override("font_color", Color("ffbc85"))
				banner.position = Vector2(420, 96)
				banner.z_index = 100
				add_child(banner)
				motion.tree_exiting.connect(func(): if is_instance_valid(banner): banner.queue_free())
		motion.setup(actor_ctrl, target_ctrl, _combat_speed())
	await _wait_combat(BEAT_SECONDS)
	_skill_actor = null

func _combat_speed() -> float:
	return _speed_multiplier if _speed_multiplier >= 4.0 else (2.0 if _speed_fast else 1.0)

func _wait_combat(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and is_inside_tree() and not _skipping_combat:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if not get_tree().paused:
			elapsed += get_process_delta_time() * _combat_speed()


## Up to 5 upcoming actors: the rest of this round, then (if that runs out) a
## preview of the next round's order -- best-effort only, since deaths this
## round can still change who is even alive to build that preview from.
## Leftmost is highlighted as "acting now".
func _refresh_turn_queue_ui(remaining: Array) -> void:
	if _turn_queue == null:
		return
	for c in _turn_queue.get_children():
		c.queue_free()

	var preview: Array = remaining.duplicate()
	if preview.size() < 5:
		for f in _build_round_queue():
			if preview.size() >= 5:
				break
			preview.append(f)
	preview = preview.slice(0, 5)

	for i in preview.size():
		var f: Fighter = preview[i]
		var color: Color = Recipes.KIND_COLOR.get(f.kind, Color.WHITE)
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.16, 0.22, 0.9)
		style.border_color = color
		var w := 3.0 if i == 0 else 1.5
		style.border_width_left = w
		style.border_width_right = w
		style.border_width_top = w
		style.border_width_bottom = w
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = "👾" if f.is_monster else f.formula
		label.add_theme_font_size_override("font_size", 13 if i == 0 else 11)
		label.add_theme_color_override("font_color", color if i == 0 else Color(color, 0.6))
		chip.add_child(label)
		_turn_queue.add_child(chip)


## The monster hits the front line while anyone is standing there. With the
## front line empty it reaches the back row, but that is not free for the
## player -- unprotected units take EXPOSED_BACK_DMG_MULT extra damage.
func _pick_monster_target():
	var front := _alive_in_row(Traits.ROW_FRONT)
	if not front.is_empty():
		return front[randi() % front.size()]
	var back := _alive_in_row(Traits.ROW_BACK)
	if not back.is_empty():
		return back[randi() % back.size()]
	return null


func _apply_base_heal() -> void:
	var pct := Traits.value(_active, "base", "heal_pct")
	if pct <= 0.0:
		return
	var every := int(Traits.value(_active, "base", "heal_every", 3.0))
	if every <= 0 or _tick_count % every != 0:
		return

	var healed := 0
	for f in _alive_players():
		if f.hp >= f.max_hp:
			continue
		# Typed explicitly: _alive_players() returns an untyped Array, so `f` has
		# no static type and `:=` has nothing to infer from.
		var before: float = f.hp
		f.hp = minf(f.max_hp, f.hp + f.max_hp * pct)
		_shared.heal += f.hp - before
		f.hp_bar.value = f.hp
		if not silent:
			Fx.float_text(self, _above(f.chip), "+%d" % roundi(f.hp - before),
				Color(0.5, 0.9, 1.0), 16)
		healed += 1
	if healed > 0:
		_log("เบสสะเทินความเสียหาย ฟื้น HP ให้ %d ตัว 💧" % healed, STATUS_OK)


## Applies the current boss's kind-specific skill (2026-09-01), on top of the
## flat CHARGE_MULT damage the heavy hit already dealt. `neutral` (the wave-1
## training dummy) has no entry in Traits.BOSS_SKILLS and this is a no-op for
## it. Acid/salt set a lingering status on `target`, decremented once per
## round in _resolve_round()'s tail; base/metal are one-shot -- metal's
## armor-pierce already happened via the ignore_metal_reduction flag on the
## _attack() call that preceded this.
func _apply_boss_skill(target: Fighter) -> void:
	var skill: Dictionary = Traits.boss_skill(_monster.kind)
	if skill.is_empty():
		return

	match _monster.kind:
		"acid":
			target.status_kind = "corroded"
			target.status_applied_round = _turn
			target.status_turns = int(skill.turns)
			target.status_value = float(skill.atk_debuff)
			_refresh_chip_tooltip(target)
			_log("☣ มอนสเตอร์กัดกร่อนเกราะ %s! พลังโจมตีลดลง %d%% นาน %d ตา" % [
				target.formula, roundi(target.status_value * 100.0), target.status_turns],
				STATUS_BAD)
			if not silent:
				Fx.float_text(self, _above(target.chip), "-ATK", Traits.color_of("acid"), 16)
		"base":
			var before: float = _monster.hp
			_monster.hp = minf(_monster.max_hp, _monster.hp + _monster.max_hp * float(skill.self_heal))
			_monster_hp_bar.value = _monster.hp
			_log("💧 มอนสเตอร์สะเทินกลับ ฟื้น HP %d หน่วย" % roundi(_monster.hp - before), STATUS_BAD)
			if not silent:
				Fx.float_text(self, Fx.centre_of(_monster_art), "+%d" % roundi(_monster.hp - before),
					Color(0.5, 0.9, 1.0), 20)
		"metal":
			_log("⚙ มอนสเตอร์ทะลุเกราะ! ดาเมจไม่ถูกลดจากสายโลหะ", STATUS_BAD)
		"salt":
			target.status_kind = "locked"
			target.status_applied_round = _turn
			target.status_turns = int(skill.turns)
			_refresh_chip_tooltip(target)
			_log("🔄 มอนสเตอร์ตรึงประจุ %s! ลำดับการโจมตีช้าลงนาน %d ตา" % [
				target.formula, target.status_turns], STATUS_BAD)
			if not silent:
				Fx.float_text(self, _above(target.chip), "🔄", Traits.color_of("salt"), 16)
	_skill_feedback(_monster, _monster if _monster.kind == "base" else target,
		"heal" if _monster.kind == "base" else "attack_down", str(skill.get("name", "ท่าหนัก")))


## Phase D -----------------------------------------------------------------

## Counts down the caster's own cooldown and resolves its one automatic skill
## when ready.  Returns an extra damage ratio for skills that empower the
## caster's ordinary attack; support/control skills return zero.
func _try_cast_unit_ability(caster: Fighter) -> float:
	if caster.ability.is_empty():
		return 0.0
	if caster.ability_cd > 0:
		caster.ability_cd -= 1
	if caster.ability_cd > 0:
		_refresh_chip_tooltip(caster)
		return 0.0

	var skill: Dictionary = caster.ability
	caster.ability_cd = int(skill.cooldown)
	_announce_unit_ability(caster, skill)
	var target: Fighter = _monster
	var bonus := 0.0

	match str(skill.effect):
		"armor_break":
			_set_timed_source(_monster.armor_break_sources, caster.formula,
				float(skill.value), int(skill.duration))
		"stacking_armor_break":
			_stack_source(_monster.armor_break_sources, caster.formula,
				float(skill.value), int(skill.max_stacks))
		"dot":
			_set_dot(_monster, caster.formula, caster.atk * float(skill.power),
				int(skill.duration))
		"bonus_damage":
			bonus = float(skill.power)
		"cleanse_shield":
			target = _weakest_ally()
			if target != null:
				_cleanse(target)
				_give_shield(target, target.max_hp * float(skill.hp_ratio))
		"cooldown_reduce":
			target = _longest_cooldown_ally(caster)
			if target != null:
				target.ability_cd = maxi(0, target.ability_cd - int(skill.rounds))
				_refresh_chip_tooltip(target)
		"attack_down":
			_set_timed_source(_monster.attack_down_sources, caster.formula,
				float(skill.value), int(skill.duration))
		"shield":
			target = _weakest_ally()
			if target != null:
				_give_shield(target, target.max_hp * float(skill.hp_ratio))
		"guard":
			target = _weakest_ally()
			if target != null:
				_set_guard(target, float(skill.value), int(skill.duration))
		"self_guard":
			target = caster
			_set_guard(caster, float(skill.value), int(skill.duration))
		"heal":
			target = _weakest_ally()
			if target != null:
				_heal_fighter(target, target.max_hp * float(skill.hp_ratio), caster)
		"next_attack":
			target = _highest_atk_ally(caster)
			if target != null:
				target.next_attack_bonus = maxf(target.next_attack_bonus, float(skill.value))
				_refresh_chip_tooltip(target)
		"cleanse_heal":
			target = _weakest_ally()
			if target != null:
				_cleanse(target)
				_heal_fighter(target, target.max_hp * float(skill.hp_ratio), caster)
		"rust":
			_set_dot(_monster, caster.formula, caster.atk * float(skill.power),
				int(skill.duration))
			_set_timed_source(_monster.armor_break_sources, caster.formula,
				float(skill.value), int(skill.duration))
		"ignite":
			_set_dot(_monster, caster.formula, caster.atk * float(skill.dot_power),
				int(skill.duration))
			bonus = float(skill.power)

	_refresh_chip_tooltip(caster)
	if target != null:
		_refresh_chip_tooltip(target)
		_skill_feedback(caster, target, str(skill.effect), str(skill.name))
	return bonus


func _announce_unit_ability(caster: Fighter, skill: Dictionary) -> void:
	_log("%s ใช้สกิล %s — %s" % [caster.formula, skill.name, skill.description],
		STATUS_TRAIT)
	if silent:
		return
	Fx.float_text(self, get_viewport_rect().size * 0.5, str(skill.name),
		Recipes.KIND_COLOR.get(caster.kind, STATUS_TRAIT), 24)
	# Retain the existing burst (and its RNG consumption); the new directed
	# overlay itself never draws from the combat RNG stream.
	Fx.burst(self, Fx.centre_of(caster.chip),
		Recipes.KIND_COLOR.get(caster.kind, STATUS_TRAIT), 14)


func _skill_feedback(caster: Fighter, target: Fighter, effect: String, title: String) -> void:
	_skill_actor = caster
	skill_presented.emit(caster.formula, target.formula, effect)
	if not _should_animate():
		return
	var kind := "attack"
	if effect in ["heal", "cleanse_heal"]:
		kind = "heal"
	elif effect in ["shield", "cleanse_shield", "guard", "self_guard"]:
		kind = "shield"
	elif effect == "cooldown_reduce":
		kind = "clock"
	elif effect == "dot":
		kind = "poison"
	var color: Color = {"heal": Color("87edb4"), "shield": Color("82cfff"),
		"clock": Color("d0b4ff"), "poison": Color("b0e778")}.get(kind, Color("ffd18a"))
	_reveal_fighter(target)
	Fx.skill_link(self, _fighter_point(caster), _fighter_point(target), kind, color,
		_combat_speed())
	# Player skills already announce centrally. A second drifting name over
	# the recipient obscures its formula/cooldown exactly when it matters.
	if caster.is_monster:
		Fx.float_text(self, get_viewport_rect().size * 0.5, title, color, 22)


func _reveal_fighter(f: Fighter) -> void:
	if not f.is_monster and is_instance_valid(f.chip):
		var scroll: ScrollContainer = f.chip.get_parent().get_parent()
		scroll.ensure_control_visible(f.chip)


func _fighter_point(f: Fighter) -> Vector2:
	var control := _turn_control(f)
	var point := Fx.centre_of(control)
	if not f.is_monster:
		# Offscreen allies originate at the visible row edge, never outside the
		# viewport. Revealing the target must not reroute the skill to someone else.
		var rect: Rect2 = f.chip.get_parent().get_parent().get_global_rect()
		point = point.clamp(rect.position + Vector2(8,8), rect.end - Vector2(8,8))
	return point


func _weakest_ally():
	var alive := _alive_players()
	if alive.is_empty():
		return null
	var result: Fighter = alive[0]
	var lowest := result.hp / maxf(result.max_hp, 1.0)
	for f in alive:
		var ratio: float = f.hp / maxf(f.max_hp, 1.0)
		if ratio < lowest:
			result = f
			lowest = ratio
	return result


func _highest_atk_ally(caster: Fighter):
	var candidates := _alive_players().filter(func(f): return f != caster)
	if candidates.is_empty():
		return caster
	var result: Fighter = candidates[0]
	for f in candidates:
		if f.atk > result.atk:
			result = f
	return result


func _longest_cooldown_ally(caster: Fighter):
	var candidates := _alive_players().filter(
		func(f): return f != caster and not f.ability.is_empty())
	if candidates.is_empty():
		return null
	var result: Fighter = candidates[0]
	for f in candidates:
		if f.ability_cd > result.ability_cd:
			result = f
	return result


func _give_shield(target: Fighter, amount: float) -> void:
	target.shield += amount
	if not silent:
		Fx.float_text(self, _above(target.chip), "+โล่ %d" % roundi(amount),
			Color(0.55, 0.8, 1.0), 16)
	_refresh_chip_tooltip(target)


func _heal_fighter(target: Fighter, amount: float, caster: Fighter = null) -> void:
	var before := target.hp
	target.hp = minf(target.max_hp, target.hp + amount)
	if caster != null:
		caster.healing_done += maxf(0.0, target.hp - before)
	else:
		_shared.heal += maxf(0.0, target.hp - before)
	target.hp_bar.value = target.hp
	_refresh_status(target)
	if not silent and target.hp > before:
		Fx.float_text(self, _above(target.chip), "+%d" % roundi(target.hp - before),
			Color(0.5, 0.9, 1.0), 16)


func _set_guard(target: Fighter, value: float, turns: int) -> void:
	target.guard_value = maxf(target.guard_value, value)
	target.guard_turns = maxi(target.guard_turns, turns)
	_refresh_chip_tooltip(target)


func _cleanse(target: Fighter) -> void:
	target.status_kind = ""
	target.status_turns = 0
	target.status_value = 0.0
	target.attack_down_sources.clear()
	target.armor_break_sources.clear()
	target.dot_sources.clear()
	_refresh_chip_tooltip(target)


func _set_timed_source(sources: Dictionary, source: String, value: float, turns: int) -> void:
	sources[source] = {"value": value, "turns": turns}


func _stack_source(sources: Dictionary, source: String, value: float, max_stacks: int) -> void:
	var current: Dictionary = sources.get(source, {"value": 0.0, "turns": -1})
	current.value = minf(float(current.value) + value, value * float(max_stacks))
	current.turns = -1
	sources[source] = current


func _set_dot(target: Fighter, source: String, amount: float, turns: int) -> void:
	target.dot_sources[source] = {"value": amount, "turns": turns}


func _source_total(sources: Dictionary, cap: float) -> float:
	var total := 0.0
	for source in sources.values():
		total += float(source.get("value", 0.0))
	return minf(total, cap)


## DoTs deal their first damage on the round after application.  Timed buffs
## and debuffs include the round in which they were cast, then remain for the
## requested number of complete turn-order rounds.
func _tick_unit_effects() -> void:
	var fighters: Array = _players.duplicate()
	if _monster != null:
		fighters.append(_monster)
	for fighter in fighters:
		var f: Fighter = fighter
		var dot_damage := _source_total(f.dot_sources, 1.0e9)
		if dot_damage > 0.0 and f.hp > 0.0:
			var actual := minf(f.hp, dot_damage)
			# Concurrent DoTs share the effective HP loss proportionally. This
			# avoids crediting all overkill to whichever dictionary key comes first.
			for source in f.dot_sources:
				_record_damage(f, actual * float(f.dot_sources[source].value) / dot_damage, str(source))
			if f.is_monster:
				_damage_monster(dot_damage, "", "recorded")
			else:
				f.hp = maxf(0.0, f.hp - dot_damage)
				f.hp_bar.value = f.hp
			if not silent:
				var at := Fx.centre_of(_monster_art) if f.is_monster else _above(f.chip)
				Fx.float_text(self, at, "-%d ต่อเนื่อง" % roundi(dot_damage),
					Traits.color_of("acid"), 16)

		_tick_source_dictionary(f.dot_sources)
		_tick_source_dictionary(f.armor_break_sources)
		_tick_source_dictionary(f.attack_down_sources)
		if f.guard_turns > 0:
			f.guard_turns -= 1
			if f.guard_turns <= 0:
				f.guard_value = 0.0
		_refresh_chip_tooltip(f)


func _tick_source_dictionary(sources: Dictionary) -> void:
	for key in sources.keys():
		var effect: Dictionary = sources[key]
		var turns := int(effect.get("turns", 0))
		if turns < 0:
			continue
		turns -= 1
		if turns <= 0:
			sources.erase(key)
		else:
			effect.turns = turns
			sources[key] = effect


## Returns the damage dealt. `quiet` suppresses the routine per-hit log line --
## a special hit (type advantage) still logs, because that is the part worth
## reading. `fan_index`/`fan_count` spread simultaneous damage numbers sideways
## so a whole team's volley does not stack into one unreadable blob.
func _attack(attacker: Fighter, defender: Fighter, monster_attacking: bool,
		quiet := false, fan_index := 0, fan_count := 1,
		ignore_metal_reduction := false, damage_mult := 1.0, manual := false) -> float:
	var dmg: float = attacker.atk * damage_mult * randf_range(0.85, 1.15)

	# Temporary debuffs from compound abilities combine additively but are
	# capped so a control-heavy team cannot reduce a boss to harmlessness.
	var attack_down := _source_total(attacker.attack_down_sources, 0.40)
	if attack_down > 0.0:
		dmg *= 1.0 - attack_down

	# A one-shot buff is consumed by the next normal/skill attack that actually
	# reaches damage calculation.
	if not attacker.is_monster and attacker.next_attack_bonus > 0.0:
		dmg *= 1.0 + attacker.next_attack_bonus
		attacker.next_attack_bonus = 0.0
		_refresh_chip_tooltip(attacker)
	# Only the monster ever charges, so this is read on its swings alone. Applied
	# before the type triangle so a telegraphed hit is scary regardless of match-up.
	if monster_attacking:
		dmg *= _charge_mult
	var verb := "โจมตี"

	var is_crit := false
	if Recipes.beats(attacker.kind, defender.kind):
		dmg *= 1.8
		verb = "เจาะจุดอ่อน โจมตีทะลวง"
		if not attacker.is_monster and not _reasons_shown.has(attacker.kind):
			_reasons_shown[attacker.kind] = true
			_log("⚗ %s" % Recipes.reason_beats(attacker.kind, defender.kind), STATUS_TRAIT)
		is_crit = true
	elif Recipes.beats(defender.kind, attacker.kind):
		dmg *= 0.55
		verb = "โจมตี (ถูกต้านทาน)"

	# A type-advantage hit is the payoff for building the right team, so it gets
	# its own heavier sound rather than sharing the generic one.
	# Gated on `quiet`: every living fighter swings each tick, so playing a sound
	# per hit churned the 8-voice pool and turned a seven-strong board into a
	# machine-gun. The volley fires ONE sound from _on_tick(); the monster's own
	# attack is not quiet and still plays here. `silent` keeps the simulator mute.

	if not silent and not quiet:
		Audio.play("crit" if is_crit else "hit")

	# Synergies are the player's alone -- the is_monster guards keep a metal
	# monster from picking up the player's own โลหะ damage reduction.
	# กรด: attacker-side synergy bonus.
	if not attacker.is_monster and attacker.has_trait("acid"):
		dmg *= 1.0 + Traits.value(_active, "acid", "dmg_bonus")

	# Boss "กัดกร่อน" skill (2026-09-01): a corroded attacker's own hits land
	# softer for a few rounds -- the boss-side counterpart to the player's
	# own halogen corrosion-on-the-monster effect.
	if not attacker.is_monster and attacker.status_kind == "corroded":
		dmg *= 1.0 - attacker.status_value

	# โลหะ: defender-side synergy reduction. Boss "ทะลุเกราะ" skill ignores
	# this on the one hit it fires on -- metal doesn't care about your armor.
	if not defender.is_monster and defender.has_trait("metal") and not ignore_metal_reduction:
		dmg *= 1.0 - Traits.value(_active, "metal", "dmg_reduction")

	var armor_break := _source_total(defender.armor_break_sources, 0.45)
	if armor_break > 0.0:
		dmg *= 1.0 + armor_break

	if not ignore_metal_reduction and defender.guard_turns > 0:
		dmg *= 1.0 - defender.guard_value

	# Nobody is guarding the front line.
	if monster_attacking and defender.row == Traits.ROW_BACK:
		dmg *= Traits.EXPOSED_BACK_DMG_MULT
		verb = "ทะลวงถึงแถวหลัง"

	if defender.is_monster:
		_damage_monster(dmg, "" if manual else attacker.formula, "manual" if manual else "shared")
		if not silent:
			# Gold and larger on a type advantage: the number itself should tell
			# the player their composition just paid off, without reading the log.
			# Fanned across the monster it is hitting, and stepped downward as well,
			# because a whole board swinging in one tick used to stack six numbers on
			# one line and none of them could be read. The horizontal spread is
			# derived from the art's actual width rather than a constant: it was
			# tuned to an 84px thumbnail, and the monster is now most of a column.
			var art_w: float = maxf(_monster_art.size.x, 120.0)
			var step: float = minf(art_w / float(maxi(fan_count, 1) + 1), 64.0)
			var spread := (float(fan_index) - float(fan_count - 1) * 0.5) * step
			var drop: float = float(fan_index) * 26.0 - float(fan_count - 1) * 13.0
			var at: Vector2 = Fx.centre_of(_monster_art) + Vector2(spread, drop)
			var bounds: Vector2 = get_viewport_rect().size
			at.x = clampf(at.x, 40.0, bounds.x - 40.0)
			at.y = clampf(at.y, 40.0, bounds.y - 40.0)
			Fx.float_text(self, at,
				"-%d" % roundi(dmg),
				STATUS_TRAIT if is_crit else STATUS_OK, 26 if is_crit else 20)
			Fx.punch(_monster_art, 0.18 if is_crit else 0.10)
	else:
		if defender.shield > 0.0:
			var absorbed := minf(defender.shield, dmg)
			defender.shield -= absorbed
			defender.shield_absorbed += absorbed
			dmg -= absorbed
			if not silent and absorbed > 0.0:
				Fx.float_text(self, _above(defender.chip), "โล่ -%d" % roundi(absorbed),
					Color(0.55, 0.8, 1.0), 15)
		_record_damage(defender, minf(defender.hp, dmg), attacker.formula)
		defender.hp = maxf(0.0, defender.hp - dmg)
		defender.hp_bar.value = defender.hp
		if not silent:
			_fighter_portrait(defender).play_pose("hurt", -1.0, _combat_speed())
			# Above the chip, not centred on it: a 104px chip already carries its
			# formula, trait list and HP bar, and a number dropped in the middle
			# collided with all three.
			Fx.float_text(self, _above(defender.chip), "-%d" % roundi(dmg), STATUS_BAD, 18)
			Fx.punch(defender.chip, 0.10)
	_refresh_status(defender)

	# A type-advantage hit always logs even in quiet mode: it is the moment the
	# player's team composition paid off, and burying it in a round total would
	# hide the one thing the log is there to teach.
	if not quiet or is_crit:
		var atk_name := "มอนสเตอร์" if attacker.is_monster else attacker.formula
		var def_name := "มอนสเตอร์" if defender.is_monster else defender.formula
		_log("%s %s %s (-%d)" % [atk_name, verb, def_name, roundi(dmg)],
			STATUS_BAD if monster_attacking else STATUS_OK)
	return dmg


func _record_damage(target: Fighter, amount: float, source := "", bucket := "shared") -> void:
	amount = maxf(0.0, amount)
	target.damage_taken += amount
	if not target.is_monster:
		return
	if source != "":
		for f in _players:
			if f.formula == source:
				f.damage_dealt += amount
				return
	if bucket == "manual":
		_manual.damage += amount
	else:
		_shared.damage += amount


func _damage_monster(amount: float, source := "", bucket := "shared") -> void:
	if bucket != "recorded":
		_record_damage(_monster, minf(_monster.hp, amount), source, bucket)
	_monster.hp = maxf(0.0, _monster.hp - amount)
	_monster_hp_bar.value = _monster.hp
	_update_monster_label()
	# Every damage source funnels through here -- attacks, halogen corrosion and
	# alkali death blasts all flash the portrait, so the hit always lands
	# visually even when nobody swung.
	_monster_art.hit()


## Counts down a boss skill's lingering effect once per round, clearing it
## when it runs out -- the same "once per round, not per turn" cadence
## CHARGE_EVERY/ENERGY_PER_TICK already count in.
func _tick_down_statuses() -> void:
	for f in _players:
		if f.status_kind == "":
			continue
		if f.status_applied_round == _turn:
			continue
		f.status_turns -= 1
		if f.status_turns <= 0:
			f.status_kind = ""
			f.status_turns = 0
			f.status_value = 0.0
		_refresh_chip_tooltip(f)


## Fade dead fighters and fire their on-death synergies exactly once.
func _resolve_deaths() -> void:
	for f in _players:
		if f.hp > 0 or f.death_resolved:
			continue
		f.death_resolved = true
		f.chip.modulate = Color(1, 1, 1, 0.35)
		_refresh_status(f)

		# แอลคาไล: group 1 metals react violently -- they go out with a bang.
		if f.has_trait("alkali"):
			var blast := Traits.value(_active, "alkali", "death_blast")
			if blast > 0.0:
				_damage_monster(blast)
				if not silent:
					Fx.burst(self, Fx.centre_of(f.chip), Traits.color_of("alkali"), 22)
					Fx.float_text(self, Fx.centre_of(_monster_art), "-%d" % roundi(blast),
						Traits.color_of("alkali"), 22)
				_log("%s ระเบิดใส่มอนสเตอร์ (-%d) 💥" % [f.formula, roundi(blast)], STATUS_OK)


func _finish(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	_close_speed_menu()
	_speed_button.disabled = true
	Playtest.battle_finished(victory, _players)
	Flow.record(GameState, _players)
	_victory = victory
	_tick_timer.stop()
	_refresh_actions()
	_build_result_report()
	_result_panel.visible = true
	_next_wave_button.visible = victory
	_next_wave_button.text = "กลับค่าย →"

	# Scale-in so the banner arrives rather than blinking into existence. Pivot
	# is set from the current size because the panel is anchored, not laid out
	# by a container, so its size is already final here.
	_result_box.pivot_offset = _result_box.size * 0.5
	_result_box.scale = Vector2(0.85, 0.85)
	_result_panel.modulate.a = 0.0
	var appear := create_tween().set_parallel(true)
	appear.tween_property(_result_box, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(_result_panel, "modulate:a", 1.0, 0.25)

	Audio.play("victory" if victory else "defeat", 0.0)

	if victory:
		if GameState.is_boss_wave():
			GameState.grant_boss_reward(GameState.wave)
		var reward := 40 + GameState.wave * 15
		var no_reward: bool = GameState.encounter_enemy().get("reward_mode", "normal") == "none"
		# เกลือ: salt was a trade good long before it was a seasoning.
		var salt_bonus := roundi(Traits.value(_active, "salt", "gold_bonus"))
		reward += salt_bonus

		# Interest is read BEFORE the reward lands, so it pays on what the
		# player chose to bank going into the fight rather than on winnings they
		# had no chance to spend.
		var interest: int = GameState.interest_earned()
		reward += interest

		if no_reward:
			reward = 0
		GameState.add_gold(reward)
		Risk.finish_battle(GameState, GameState.is_boss_wave())
		# A fresh shop each round, free. Charging for the between-round roll on
		# top of the in-shop reroll would just be a tax; the interesting cost is
		# rerolling again when you do not like what you got.
		GameState.roll_shop(false)

		var parts: Array = ["🎉 ชนะแล้ว! ได้รับ 💰%d" % reward]
		if interest > 0:
			parts.append("(ดอกเบี้ย +%d)" % interest)
		if salt_bonus > 0:
			parts.append("(โบนัสสายเกลือ +%d)" % salt_bonus)
		_result_label.text = " ".join(parts)
		_result_label.add_theme_color_override("font_color", STATUS_OK)
		_result_reason.text = ""
		var expedition_ending := ""
		if int(GameState.journey.get("step", 0)) == GameState.wave:
			expedition_ending = preload("res://scripts/expedition.gd").battle_reward(GameState)
			_result_reason.text = expedition_ending
		# Not on the final wave: complete_run() wipes that gold a line later, so
		# announcing it would be telling the player they earned something the
		# game is about to take away.
		if not GameState.is_final_wave():
			_log("ชนะการต่อสู้! ได้รับเงิน %d 💰" % reward, STATUS_OK)
		if GameState.is_final_wave():
			# The run is over and won. complete_run() starts a fresh run behind
			# the banner so the title screen's "เล่นต่อ" cannot drop the player
			# back onto the boss they just beat.
			_run_won = true
			_result_label.text = "พิชิตบอสครบ %d ตัว!" % Campaign.BOSS_COUNT
			_result_reason.text = "จบการผจญภัยแล้ว กดปุ่มด้านล่างเพื่อกลับหน้าแรกและเริ่มรันใหม่"
			_next_wave_button.visible = false
			_shop_button.text = "กลับหน้าแรก"
			_log("พิชิตจอมโจทย์ได้สำเร็จ จบเกมอย่างสมบูรณ์ ✨", STATUS_OK)
		else:
			if not preload("res://scripts/expedition.gd").advance(GameState, true):
				Flow.recover(GameState, GameState.wave)
				GameState.wave += 1
				GameState.roll_next_monster()
				GameState.journey.clear()
				GameState.save_game()
		if not silent and not GameState.pending_reward.is_empty():
			_show_reward.call_deferred()
	else:
		Risk.finish_battle(GameState, false)
		var wave_died_at: int = GameState.wave
		var reason := _defeat_reason()
		GameState.end_run_in_defeat()
		_run_lost = true
		_result_label.text = "ทีมพ่ายแพ้ · จบการผจญภัยที่ด่าน %d" % wave_died_at
		_result_label.add_theme_color_override("font_color", STATUS_BAD)
		_result_reason.text = reason + "\nสูตรที่ค้นพบยังอยู่ เริ่มการเดินทางใหม่ได้จากหน้าแรก"
		_next_wave_button.visible = false
		_shop_button.text = "กลับหน้าแรก"
		_log("ทีมพ่ายแพ้ จบการผจญภัย", STATUS_BAD)


func _report_leader(property: String, label: String) -> String:
	var best := 0.0
	var names: Array[String] = []
	for f in _players:
		var value := float(f.get(property))
		if value > best and not is_equal_approx(value, best):
			best = value
			names = [f.formula]
		elif best > 0 and is_equal_approx(value, best):
			names.append(f.formula)
	return "%s: %s" % [label, "ยังไม่มี" if best <= 0 else "%s (%d)" % [" / ".join(names), roundi(best)]]


func _build_result_report() -> void:
	var leaders: Label = %ReportLeaders
	leaders.text = "%s\n%s\n%s" % [_report_leader("damage_dealt", "ทำดาเมจสูงสุด"),
		_report_leader("damage_taken", "รับดาเมจ HP สูงสุด"), _report_leader("healing_done", "ฮีลสูงสุด")]
	var grid: GridContainer = %ReportGrid
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for text in ["ยูนิต", "ดาเมจ", "รับเข้า HP", "ฮีล", "โล่รับแทน"]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 15)
		grid.add_child(label)
	var properties := ["damage_dealt", "damage_taken", "healing_done", "shield_absorbed"]
	var colors := [Color("c58a4b"), Color("aa5963"), Color("427f64"), Color("477e9d")]
	var peaks := [1.0, 1.0, 1.0, 1.0]
	for f in _players:
		for i in properties.size():
			peaks[i] = maxf(peaks[i], float(f.get(properties[i])))
	for f in _players:
		var label := Label.new()
		label.text = f.formula + (" · ล้ม" if f.hp <= 0 else "")
		label.custom_minimum_size.x = 115
		label.add_theme_font_size_override("font_size", 16)
		label.tooltip_text = UnitAbilities.tooltip(f.formula)
		grid.add_child(label)
		for i in properties.size():
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(102, 28)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.show_percentage = false
			bar.max_value = peaks[i]
			bar.value = float(f.get(properties[i]))
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color("18232e")
			var fill := StyleBoxFlat.new()
			fill.bg_color = colors[i]
			bar.add_theme_stylebox_override("background", bg)
			bar.add_theme_stylebox_override("fill", fill)
			var number := Label.new()
			number.text = str(roundi(bar.value))
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			number.add_theme_font_size_override("font_size", 16)
			number.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(number)
			number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			grid.add_child(bar)
	var note: Label = %ReportNote
	note.text = "สายพลังร่วม: ดาเมจ %d · ฮีล %d | สกิลที่คุณกด: ดาเมจ %d · ฮีล %d\nนับเฉพาะ HP ที่เปลี่ยนจริง ไม่รวมตีเกินเลือด/ฮีลล้น\nโล่รับแทน = โล่บนตัวนั้นที่ใช้กันการโจมตี ไม่รวมในรับเข้า HP\nแถบเทียบภายในคอลัมน์เดียวกัน สกิลควบคุม/ล้างสถานะยังไม่คิดคะแนน" % [
		roundi(_shared.damage), roundi(_shared.heal), roundi(_manual.damage), roundi(_manual.heal)]


func _on_next_wave_pressed() -> void:
	if not GameState.pending_reward.is_empty():
		_show_reward()
		return
	Audio.play("buy")
	Transition.change_scene("res://scenes/Main.tscn")


## A pure decision, split out from _on_shop_pressed() so a checker can assert
## on it directly without going through Transition/scene-loading at all.
##
## Phase F: a win that just advanced INTO a trigger wave (4/8/12/16) shows an
## event screen instead of the shop, once. _run_won/_run_lost already override
## to Home.tscn -- GameState has been reset out from under this scene either
## way, so Main.tscn is the wrong destination for both -- and a defeat that
## did not end the run is excluded via _victory, same as before.
func _shop_destination() -> String:
	if _run_won or _run_lost:
		return "res://scenes/Home.tscn"
	return "res://scenes/Main.tscn"


func _on_shop_pressed() -> void:
	if not GameState.pending_reward.is_empty():
		_show_reward()
		return
	if _run_won:
		GameState.complete_run()
	Audio.play("click")
	Transition.change_scene(_shop_destination())

func _show_reward() -> void:
	if GameState.pending_reward.is_empty() or is_instance_valid(_reward_popup):
		return
	_reward_popup = preload("res://scripts/reward_panel.gd").new()
	add_child(_reward_popup)


## Repeats collapse into a counter instead of stacking.
##
## Every fighter swings every tick, so "ทีมของคุณโจมตีรวม -14" and the monster's
## reply scrolled past twice a second and pushed everything explanatory off the
## top. A player watching it called the log "ข้อความที่วิ่งซ้ำ ๆ" -- which is
## exactly right, and it meant the lines that DO teach something were the ones
## being lost.
func _log(message: String, color: Color) -> void:
	if silent:
		return

	var rows: Array = _log_list.get_children()
	if not rows.is_empty():
		var last: Label = rows[rows.size() - 1] as Label
		if last != null and last.get_meta("raw", last.text) == message:
			var seen: int = int(last.get_meta("seen", 1)) + 1
			last.set_meta("seen", seen)
			last.text = "%s  ×%d" % [message, seen]
			return

	var label := Label.new()
	label.text = message
	label.set_meta("raw", message)
	label.set_meta("seen", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", color)
	_log_list.add_child(label)
	await get_tree().process_frame
	# The player can press "back to shop" during this await, freeing the scene.
	if not is_instance_valid(_log_list) or not _log_list.is_inside_tree():
		return
	var scroll := _log_list.get_parent()
	if scroll is ScrollContainer:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## Why the run just ended. "You lost" teaches nothing; for a game whose whole
## job is teaching, the defeat screen is the highest-value place in it to say
## something true and specific.
##
## Ordered by how badly each factor decides a fight, so the player is told the
## one thing most worth changing rather than a list.
func _defeat_reason() -> String:
	if _front_empty.visible:
		return "ไม่มีใครยืนแถวหน้า มอนสเตอร์จึงทะลวงถึงแถวหลังโดยตรง (แรง ×1.5) — ย้ายสักตัวมาไว้แถวหน้า"

	var weak := 0
	for f in _players:
		if Recipes.beats(_monster.kind, f.kind):
			weak += 1
	if _players.size() > 0 and float(weak) / float(_players.size()) >= 0.5:
		var counter := Recipes.counter_of(_monster.kind)
		return "ทีมส่วนใหญ่เสียเปรียบมอนสเตอร์สาย%s — คราวหน้าลองใส่สาย%s ซึ่งได้เปรียบ" % [
			Recipes.KIND_LABEL.get(_monster.kind, _monster.kind),
			Recipes.KIND_LABEL.get(counter, counter)]

	if _active.is_empty():
		return "ยังไม่มีสายพลังทำงานเลย — สายพลังนับ \"ชนิด\" ของสารประกอบ ผสมให้หลากหลายขึ้น"

	if _players.size() < GameState.wave:
		return "ทีมมีแค่ %d ชนิด สำหรับด่านที่ %d — มอนสเตอร์แข็งขึ้นทุกด่าน ทีมต้องโตตาม" % [
			_players.size(), GameState.wave]

	return "ลองสลับแถวหน้า/หลัง หรือผสมสารประกอบชนิดใหม่เพิ่มสายพลังให้ครบขั้น"


# --- the player's half of the fight ----------------------------------------
#
# The battle used to be a cutscene. You pressed "start" and watched numbers
# move, and nothing you did between the shop and the result screen changed the
# outcome by one point of damage. Energy plus three abilities plus a telegraphed
# heavy attack turns those thirty seconds into a sequence of small decisions:
# spend now or bank for the incoming hit.

func _gain_energy(amount: int) -> void:
	_energy = clampi(_energy + amount, 0, ENERGY_MAX)
	_refresh_actions()


## Greys out what cannot be paid for. A button that looks live and then refuses
## is worse than one that plainly says "not yet".
func _refresh_actions() -> void:
	if silent or _energy_bar == null:
		return
	_energy_bar.value = float(_energy)
	_energy_label.text = "พลัง %d/%d" % [_energy, ENERGY_MAX]
	_energy_label.tooltip_text = "พลังปฏิกิริยาสะสมระหว่างต่อสู้ ใช้กดสกิลด้านข้าง ตัวเลขบนปุ่มคือค่าพลังที่ต้องใช้"
	var locked: bool = _battle_over or _skipping_combat
	_catalyse_button.tooltip_text = "เร่งปฏิกิริยา · ใช้พลัง %d\nสมาชิกทีมที่ยังมีชีวิตโจมตีศัตรูเพิ่มทันทีคนละ 1 ครั้ง โดยไม่ต้องรอตาตัวเอง\nดาเมจคิดตามการโจมตีของแต่ละตัวและการป้องกันของศัตรู" % COST_CATALYSE
	_heal_button.tooltip_text = "สะเทิน · ใช้พลัง %d\nฟื้น HP ให้สมาชิกทีมที่ยังมีชีวิตทุกตัว %d%% ของ HP สูงสุด\nไม่เกิน HP เต็ม และไม่ชุบชีวิตตัวที่แพ้ไปแล้ว" % [COST_HEAL, roundi(HEAL_PCT * 100.0)]
	_burst_button.tooltip_text = "คายความร้อน · ใช้พลัง %d\nสร้างดาเมจใส่ศัตรูทันที เท่ากับ ATK รวมของสมาชิกที่ยังมีชีวิตคูณ %d\nทีมเหลือหลายตัวและมี ATK สูง ยิ่งทำดาเมจได้มาก" % [COST_BURST, roundi(BURST_ATK_MULT)]
	_catalyse_button.disabled = locked or _energy < COST_CATALYSE
	_heal_button.disabled = locked or _energy < COST_HEAL
	_burst_button.disabled = locked or _energy < COST_BURST


## Returns false and spends nothing when the fight is over or the energy is not
## there, so each handler can bail on one line.
func _spend(cost: int) -> bool:
	if _battle_over or _energy < cost:
		if not silent:
			Audio.play("reject")
		return false
	_energy -= cost
	_refresh_actions()
	return true


## 🧪 An extra volley, out of turn. The straightforward damage option, and the
## one to hold when the monster is about to die anyway.
func _on_catalyse_pressed() -> void:
	if not _spend(COST_CATALYSE):
		return
	if not silent:
		Audio.play("bond")
	var alive: Array = _alive_players()
	var total := 0.0
	for i in alive.size():
		if _monster.hp <= 0:
			break
		total += _attack(alive[i], _monster, false, true, i, alive.size(), false, 1.0, true)
	_log("🧪 เร่งปฏิกิริยา! ทีมโจมตีนอกรอบรวม -%d" % roundi(total), STATUS_TRAIT)
	_update_monster_label()
	if _monster.hp <= 0:
		_finish(true)


## 💧 Neutralisation, the acid/base reaction the game teaches, used as a heal.
## Only living fighters: reviving the dead would undo the whole point of the
## front row.
func _on_heal_pressed() -> void:
	if not _spend(COST_HEAL):
		return
	if not silent:
		Audio.play("victory")
	var healed := 0
	for f in _alive_players():
		var before: float = f.hp
		f.hp = minf(f.max_hp, f.hp + f.max_hp * HEAL_PCT)
		_manual.heal += maxf(0.0, f.hp - before)
		if f.hp > before:
			healed += 1
			if f.hp_bar != null:
				f.hp_bar.value = f.hp
			if not silent and f.chip != null:
				Fx.float_text(self, _above(f.chip), "+%d" % roundi(f.hp - before),
					STATUS_OK, 18)
	_log("💧 สะเทิน! ฟื้นพลังชีวิต %d ตัว (+%d%%)" % [healed, roundi(HEAL_PCT * 100.0)], STATUS_OK)


## 💥 The burst. Scales off the team's own attack rather than a flat number, so
## it stays worth its cost at wave 20 without being a nuke at wave 2.
func _on_burst_pressed() -> void:
	if not _spend(COST_BURST):
		return
	if not silent:
		Audio.play("crit")
	var power := 0.0
	for f in _alive_players():
		power += f.atk
	var dmg: float = power * BURST_ATK_MULT
	_damage_monster(dmg, "", "manual")
	_log("💥 ปฏิกิริยาคายความร้อน! -%d ใส่มอนสเตอร์โดยตรง" % roundi(dmg), STATUS_TRAIT)
	_update_monster_label()
	if _monster.hp <= 0:
		_finish(true)


## Double speed. An auto-battler that only runs at one pace is slow exactly when
## the player already knows they have won.
var _speed_menu: PanelContainer
var _skipping_combat := false
func _close_speed_menu() -> void:
	if is_instance_valid(_speed_menu): _speed_menu.queue_free()
	_speed_menu = null
func _on_speed_pressed() -> void:
	if is_instance_valid(_speed_menu):
		_close_speed_menu()
		return
	if _battle_over or _skipping_combat: return
	Audio.play("click")
	_speed_menu = PanelContainer.new()
	_speed_menu.z_index = 120
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_speed_menu.add_child(column)
	for rate in [1, 2, 4, 8, 0]:
		var option := Button.new()
		option.text = "Skip" if rate == 0 else "x%d" % rate
		option.custom_minimum_size = Vector2(100, 44)
		option.add_theme_font_size_override("font_size", 18)
		if rate == 0: option.tooltip_text = "ข้ามแอนิเมชันและคำนวณผลต่อสู้ตามทีมจริง อาจชนะหรือแพ้"
		column.add_child(option)
		option.pressed.connect(_select_combat_rate.bind(rate))
	add_child(_speed_menu)
	await get_tree().process_frame
	if not is_instance_valid(_speed_menu): return
	var rect := _speed_button.get_global_rect()
	var target := Vector2(minf(rect.position.x, get_viewport_rect().size.x - _speed_menu.size.x - 8), maxf(8, rect.position.y - _speed_menu.size.y - 8))
	_speed_menu.position = target + Vector2(0, 14)
	_speed_menu.modulate.a = 0
	var slide := create_tween().set_parallel(true)
	slide.tween_property(_speed_menu, "position", target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(_speed_menu, "modulate:a", 1.0, 0.15)
func _select_combat_rate(rate: int) -> void:
	_close_speed_menu()
	Audio.play("click")
	if rate == 0:
		_skip_combat()
		return
	_speed_multiplier = float(rate)
	_speed_fast = rate > 1
	_apply_speed()
func _skip_combat() -> void:
	if _battle_over or _skipping_combat: return
	_skipping_combat = true
	_tick_timer.stop()
	_speed_button.disabled = true
	_speed_button.text = "Skip…"
	_refresh_actions()
	while _resolving and is_inside_tree(): await get_tree().process_frame
	while not _battle_over and is_inside_tree():
		for batch in 8:
			if _battle_over: break
			_on_tick()
		await get_tree().process_frame


func _apply_speed() -> void:
	if is_instance_valid(_monster_art):
		_monster_art.motion_speed = _combat_speed()
	for child in get_children():
		if child.get_script() == Fx.Skill or child.get_script() == preload("res://scripts/fx_combat_motion.gd"):
			child.speed = _combat_speed()
	for fighter in _players:
		_fighter_portrait(fighter).motion_speed = _combat_speed()
	if _tick_timer == null:
		return
	_tick_timer.wait_time = TICK_SECONDS / (_combat_speed())
	if _speed_button != null:
		_speed_button.text = "▶ %dx" % int(_combat_speed())


func _on_battle_coach_skip() -> void:
	Audio.play("click")
	_battle_coach.visible = false
	GameState.set_battle_tutorial_done()

