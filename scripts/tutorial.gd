extends Control

## First-run coach for the shop screen.
##
## Deliberately NOT a wall of text on a modal. It reads the game's actual state
## and points at whatever the player should touch next, so it teaches by
## getting out of the way rather than by being read. Nothing is blocked -- a
## player who ignores it entirely can still play, and the coach simply notices
## they moved on and advances.
##
## Steps are derived, not counted. Deriving them from state means the coach
## cannot desync if the player does things out of order (buys three atoms
## before dragging, bonds before the hint appears, etc.), which a step counter
## incremented from signals absolutely would.

const Recipes := preload("res://scripts/recipes.gd")

## NONE is the opening state now: the board hint owns the first fifteen seconds
## on its own, so this says nothing until there is a compound to fight with.
enum Step { NONE, BATTLE, DONE }

@onready var _bubble: PanelContainer = %CoachBubble
@onready var _text: Label = %CoachText
@onready var _skip: Button = %CoachSkip
@onready var _board: Control = %Board
@onready var _element_scroll: Control = %ElementScroll
@onready var _battle_button: Button = %BattleButton

var _step: int = Step.NONE
var _target: Control
var _time := 0.0
var _poll := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if GameState.tutorial_done:
		queue_free()
		return

	_skip.pressed.connect(_on_skip)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	# Polled rather than signal-driven: the interesting conditions are "is there
	# an atom on the board" and "is the roster non-empty", and there is no one
	# signal that covers both plus the player dragging things around. Four times
	# a second is imperceptible and costs nothing.
	_poll += delta
	if _poll >= 0.25:
		_poll = 0.0
		_refresh()
	if _target != null:
		queue_redraw()


func _atoms_on_board() -> int:
	var n := 0
	for child in _board.get_children():
		if child.is_in_group("atoms"):
			n += 1
	return n


## Silent until the player owns a compound.
##
## The opening screen used to carry the same instruction three times in three
## wordings -- this coach at the top, the status bar at the bottom, and the
## board in the middle -- and a newcomer with one question got three differently
## worded answers to it. The board now owns the first fifteen seconds, because
## the board is where the hand is going. This picks up afterwards, when there is
## something to say that the board cannot: where to go next.
func _derive_step() -> int:
	if not GameState.roster.is_empty():
		return Step.BATTLE
	return Step.NONE


func _refresh() -> void:
	var next := _derive_step()
	if next != _step:
		_step = next
		Audio.play("click", 0.15)

	# Hidden outright, not merely blanked. Leaving the panel up with no text
	# drew an empty rounded box and a "ข้าม" button across the top of the board,
	# directly over the three atoms the opening lesson had just placed there.
	#
	# Also stands down mid-drag. It sits along the top of the board, which is
	# where the bond preview appears, and "go and fight" matters less than what
	# is under the player's hand right now -- especially during a tier-2
	# reaction, which can only happen once this step is already showing.
	var shop = get_node_or_null("%ShopPopup")
	visible = _step == Step.BATTLE and not _dragging() and not (shop and shop.visible)

	match _step:
		Step.BATTLE:
			var main := owner
			var nav = main.get_meta("mobile_nav") if main != null and main.has_meta("mobile_nav") else null
			_target = nav.get_node("Fight") if nav != null and nav.visible else _battle_button
			if GameState.discovered.is_empty():
				var mix_hint := "ซื้อธาตุตามสูตร แล้วลากอะตอมมาซ้อนกันบนกระดาน"
				if GameState.shop_offer.has("H"):
					mix_hint = "เปิดร้านซื้อ H สองตัว แล้วลากมาซ้อนกันให้เป็น H₂"
				_text.text = mix_hint + "\nตรวจทีม แล้วกด «เดินทาง» เพื่อไปเลือกเหตุการณ์"
			else:
				_text.text = "สารที่ผสมจะลงทีมอัตโนมัติถ้ามีที่ว่าง\nถ้าอยู่สำรอง ลากลงแถวหน้า/หลัง แล้วกด «เดินทาง»"
		_:
			_target = null

	queue_redraw()


func _on_skip() -> void:
	Audio.play("click")
	GameState.set_tutorial_done()
	queue_free()


## Called by main.gd once the player reaches the battle, which is the point the
## loop has been demonstrated end to end.
func finish() -> void:
	GameState.set_tutorial_done()
	queue_free()


func _draw() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Pulsing ring around whatever comes next. An outline rather than a dimming
	# mask over everything else: the player still needs to read their gold, the
	# recipe book and the synergy panel while being pointed somewhere.
	var rect := Rect2(_target.global_position, _target.size).grow(6.0)
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	var color := Color(1.0, 0.85, 0.4, 0.35 + pulse * 0.5)
	draw_rect(rect, color, false, 3.0)
	draw_rect(rect.grow(4.0), Color(1.0, 0.85, 0.4, 0.10 + pulse * 0.12), false, 2.0)


## True while a piece is in hand. Read off the shop controller rather than
## duplicated here, so there is one answer to the question.
func _dragging() -> bool:
	var main := owner
	if main == null or not ("_dragging" in main):
		return false
	return main._dragging != null
