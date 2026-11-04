extends Control

## A one-shot particle burst, drawn rather than using GPUParticles2D.
##
## Drawn by hand for the same reason the monster is: the colour comes from
## gameplay data (the compound's kind), the count is small, and keeping it in
## script means no .tres to keep in sync. It also sidesteps GPUParticles2D
## behaving differently under the gl_compatibility renderer this project is
## pinned to.

const LIFETIME := 0.7
const GRAVITY := 260.0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var radius: float

var _particles: Array[Particle] = []
var _color := Color.WHITE
var _age := 0.0


func setup(global_pos: Vector2, color: Color, count: int) -> void:
	_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-rect so _draw works in the host's coordinate space; the burst
	# positions its particles in global coordinates itself.
	set_anchors_preset(Control.PRESET_FULL_RECT)

	for i in count:
		var p := Particle.new()
		p.pos = global_pos
		var angle := randf_range(0.0, TAU)
		# Biased upward: sparks that only fall look like debris, not celebration.
		var speed := randf_range(70.0, 230.0)
		p.vel = Vector2(cos(angle), sin(angle) * 0.8 - 0.35) * speed
		p.radius = randf_range(2.0, 5.0)
		_particles.append(p)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for p in _particles:
		p.vel.y += GRAVITY * delta
		p.pos += p.vel * delta
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var alpha := 1.0 - t * t
	for p in _particles:
		draw_circle(p.pos - global_position, p.radius * (1.0 - t * 0.6),
			Color(_color.r, _color.g, _color.b, alpha))
