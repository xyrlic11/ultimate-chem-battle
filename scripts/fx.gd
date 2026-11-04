extends Node

## Autoload `Fx`. Shared visual feedback: floating numbers, particle bursts and
## impact punches.
##
## NO SCREEN SHAKE, deliberately. Almost every node in this game lives inside a
## container -- HBoxContainer rows, VBoxContainer panels -- and a container
## rewrites its children's positions every layout pass, so a position-based
## shake either fights the layout or gets snapped back mid-tween. Scale punches
## work inside containers and read just as clearly.

const FloatingLabel := preload("res://scripts/fx_floating_label.gd")
const Burst := preload("res://scripts/fx_burst.gd")
const Strike := preload("res://scripts/fx_strike.gd")
const Skill := preload("res://scripts/fx_skill.gd")


func skill_link(host: Control, from_global: Vector2, to_global: Vector2,
		kind: String, color: Color, speed := 1.0) -> Control:
	var node := Control.new()
	node.set_script(Skill)
	host.add_child(node)
	node.setup(from_global, to_global, kind, color, speed)
	return node


## A number that rises and fades. `host` should be a full-rect Control near the
## top of the scene -- parenting into a chip would clip the label to the chip
## and hide it behind the next row.
func float_text(host: Control, global_pos: Vector2, text: String,
		color: Color, font_size := 20) -> void:
	if host == null or not is_instance_valid(host):
		return
	var label := Label.new()
	label.set_script(FloatingLabel)
	host.add_child(label)
	label.setup(global_pos, text, color, font_size)


## Particles thrown outward from a point. Used when a bond succeeds -- the best
## moment in the game deserves more than a tile appearing.
func burst(host: Control, global_pos: Vector2, color: Color, count := 18) -> void:
	if host == null or not is_instance_valid(host):
		return
	var node := Control.new()
	node.set_script(Burst)
	host.add_child(node)
	node.setup(global_pos, color, count)


## Quick scale pop. Safe inside containers, unlike moving a node.
func punch(control: Control, amount := 0.14, duration := 0.22) -> void:
	if control == null or not is_instance_valid(control):
		return
	# Pivot must be re-centred each time: the control may have been resized by
	# its container since the last punch.
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * (1.0 + amount)
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Centre of a control in global space -- where a damage number or burst should
## appear for it.
func centre_of(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5


## A quick colored streak from one point to another (Phase C's per-turn
## attack cue). See fx_strike.gd for why this exists instead of moving the
## attacker itself -- every fighter lives inside a layout Container that would
## silently undo a position tween.
func strike_streak(host: Control, from_global: Vector2, to_global: Vector2, color: Color) -> void:
	if host == null or not is_instance_valid(host):
		return
	var node := Control.new()
	node.set_script(Strike)
	host.add_child(node)
	node.setup(from_global, to_global, color)
