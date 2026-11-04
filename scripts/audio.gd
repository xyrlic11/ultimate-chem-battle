extends Node

## Autoload `Audio`. Every sound in the game is synthesised here at startup --
## there is not a single audio file in the repo.
##
## WHY SYNTHESISE: the project ships no assets and cannot pull any in (no
## generated-art budget, and bundling third-party audio drags licensing into a
## repo that already refuses to ship a non-redistributable font). Rendering
## PCM in GDScript keeps the whole soundtrack as readable text in git, costs
## nothing to distribute, and cannot break a Web export.
##
## Everything is mono 22050 Hz. That is deliberately modest: it is plenty for
## square-wave chiptune, and it keeps the startup render and the memory
## footprint of two eight-second loops small.

const SAMPLE_RATE := 22050
const SETTINGS_PATH := "user://settings.cfg"

enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }

## Simultaneous SFX voices. Bonding a cluster can fire a chime, a pop and a
## coin within a few frames of each other, so a single player would cut itself
## off mid-sound.
const SFX_VOICES := 8

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx: Dictionary = {}
var _tracks: Dictionary = {}
var _current_track := ""
## Two overlapping fades both write volume_db; the loser can leave the track
## parked at -40 dB, i.e. silent. Killed before each new fade.
var _music_tween: Tween

## Flips on the first input of the session. See play_music().
var _audio_unlocked := false
var _pending_music := ""

var music_volume: float = 0.7
var sfx_volume: float = 0.8


func _ready() -> void:
	# Music must keep playing and the UI must keep clicking while the pause menu
	# is open -- that is where the volume sliders live.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	# Synthesis is deferred off the first frame. It takes about a second here and
	# an estimated three to five in a browser -- one thread, no SIMD -- and doing
	# it inside _ready() means that whole time is a blank window before the title
	# screen has drawn even once. The first thing a new player would see is
	# nothing at all.
	_build_sfx.call_deferred()
	_build_tracks.call_deferred()
	set_process_input(true)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	load_settings()


# --- buses -------------------------------------------------------------------

## Created in code rather than shipped as a default_bus_layout.tres, so the
## layout cannot drift away from the names this script and the settings screen
## both hardcode.
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	save_settings()


## Slider position maps to decibels logarithmically, not linearly -- a linear
## dB slider spends most of its travel in a range the ear reads as silence.
func _apply_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))


# --- settings persistence ----------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(cfg.get_value("audio", "music", 0.7)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.8)), 0.0, 1.0)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)


# --- playback ----------------------------------------------------------------

func play(sfx_name: String, pitch_jitter := 0.06) -> void:
	var stream: AudioStreamWAV = _sfx.get(sfx_name)
	if stream == null:
		return
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_VOICES
	player.stream = stream
	# A touch of pitch variance so a burst of identical sounds does not turn
	# into a machine-gun artefact.
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Cross-fades to a track. Calling it with the track already playing is a no-op,
## so scenes can request their theme in _ready() without restarting it on every
## transition.
## Browsers refuse to start audio until the page has seen a real user gesture,
## and Home._ready() calls this before the player has touched anything -- so on
## the web the title music was simply rejected and never recovered. The request
## is remembered instead and honoured on the first click, key or tap.
##
## Desktop is unaffected in practice: nothing reaches a title screen without
## pressing something, and _audio_unlocked flips on the very first input.
func play_music(track: String) -> void:
	_pending_music = track
	if not _audio_unlocked:
		return
	if track == _current_track and _music_player.playing:
		return
	var stream: AudioStreamWAV = _tracks.get(track)
	if stream == null:
		# Deferred synthesis may not have finished yet on a slow first frame.
		return
	_current_track = track

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var tween := create_tween()
	_music_tween = tween
	if _music_player.playing:
		tween.tween_property(_music_player, "volume_db", -40.0, 0.35)
		tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.play())
	else:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		_music_player.play()
	tween.tween_property(_music_player, "volume_db", 0.0, 0.6)


func stop_music() -> void:
	_current_track = ""
	_music_player.stop()


# --- synthesis ---------------------------------------------------------------

func _osc(kind: int, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		Wave.SQUARE:
			return 1.0 if p < 0.5 else -1.0
		Wave.TRIANGLE:
			return 4.0 * absf(p - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * p - 1.0
		Wave.NOISE:
			return randf_range(-1.0, 1.0)
		_:
			return sin(p * TAU)


## Renders one note into `buf` (additively, so notes can overlap into chords).
## `curve` shapes the decay: 1.0 is a linear fade, higher values are pluckier.
func _render(buf: PackedFloat32Array, start: float, freq: float, dur: float,
		kind: int, vol: float, curve := 2.5, freq_end := -1.0) -> void:
	var first := int(start * SAMPLE_RATE)
	var count := int(dur * SAMPLE_RATE)
	# 4ms fade-in kills the click that a hard note onset otherwise produces.
	var attack := maxi(1, int(0.004 * SAMPLE_RATE))
	var phase := 0.0

	for i in count:
		var idx := first + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / float(count)
		# Sliding pitch drives the whole character of the zap/whoosh effects.
		var f: float = freq if freq_end < 0.0 else lerpf(freq, freq_end, t)
		phase += f / float(SAMPLE_RATE)

		var env := pow(1.0 - t, curve)
		if i < attack:
			env *= float(i) / float(attack)
		buf[idx] += _osc(kind, phase) * vol * env


## Float buffer -> 16-bit PCM. Soft-clips with tanh rather than hard-clamping,
## because summed notes routinely exceed 1.0 and hard clipping buzzes.
func _to_stream(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v: float = tanh(buf[i])
		var s := int(clampf(v, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * SAMPLE_RATE))
	buf.fill(0.0)
	return buf


## Equal temperament, A4 = 440. `semi` counts semitones from A4.
func _hz(semi: float) -> float:
	return 440.0 * pow(2.0, semi / 12.0)


# --- sound effects -----------------------------------------------------------
#
# Fantasy-flavoured: steel, magic and brass rather than arcade blips. Still the
# same five oscillators -- the character comes from how they are combined.
#
# The vocabulary used below:
#   metal ring  = two slightly detuned high squares, long-ish decay (beating
#                 between the two detuned partials is what "rings")
#   impact      = short pitched noise burst
#   magic       = ascending sine arpeggio plus a high sweep
#   brass       = saw with a moderate decay

func _build_sfx() -> void:
	_sfx["click"] = _sfx_click()
	_sfx["buy"] = _sfx_buy()
	_sfx["bond"] = _sfx_bond()
	_sfx["reject"] = _sfx_reject()
	_sfx["hit"] = _sfx_hit()
	_sfx["crit"] = _sfx_crit()
	_sfx["victory"] = _sfx_victory()
	_sfx["defeat"] = _sfx_defeat()
	_sfx["pickup"] = _sfx_pickup()


## Harp pluck. Triangle with a fast decay reads as a plucked string.
func _sfx_click() -> AudioStreamWAV:
	var b := _buffer(0.18)
	_render(b, 0.0, _hz(12.0), 0.16, Wave.TRIANGLE, 0.20, 3.0)
	_render(b, 0.0, _hz(19.0), 0.12, Wave.SINE, 0.09, 3.6)
	return _to_stream(b)


## Picking a rune up off the table.
func _sfx_pickup() -> AudioStreamWAV:
	var b := _buffer(0.16)
	_render(b, 0.0, _hz(7.0), 0.13, Wave.TRIANGLE, 0.24, 2.8, _hz(14.0))
	_render(b, 0.02, _hz(19.0), 0.10, Wave.SINE, 0.10, 3.4)
	return _to_stream(b)


## Coin on stone: a bright metal ring over a tiny click.
func _sfx_buy() -> AudioStreamWAV:
	var b := _buffer(0.42)
	_render(b, 0.0, 1400.0, 0.02, Wave.NOISE, 0.14, 6.0)
	_render(b, 0.0, _hz(24.0), 0.34, Wave.SQUARE, 0.13, 1.8)
	_render(b, 0.0, _hz(24.3), 0.34, Wave.SQUARE, 0.11, 1.8)
	_render(b, 0.05, _hz(31.0), 0.26, Wave.SINE, 0.09, 2.2)
	return _to_stream(b)


## A successful bond is the best moment in the game, so it gets the full spell:
## a rising arpeggio, a shimmer an octave up, and a sweep over the top.
func _sfx_bond() -> AudioStreamWAV:
	var b := _buffer(0.95)
	var root := 3.0
	for i in 5:
		var semi: float = root + [0.0, 4.0, 7.0, 12.0, 16.0][i]
		_render(b, float(i) * 0.05, _hz(semi), 0.55, Wave.TRIANGLE, 0.22, 2.0)
	_render(b, 0.25, _hz(root + 19.0), 0.6, Wave.SINE, 0.13, 1.4)
	# The sweep is what makes it read as magic rather than as a chord.
	_render(b, 0.10, _hz(root + 12.0), 0.5, Wave.SINE, 0.10, 1.6, _hz(root + 31.0))
	return _to_stream(b)


## Wrong mixture. A muffled thud and a falling minor second -- clearly negative,
## deliberately not harsh. The board exists for experimenting and punishing a
## student for trying would defeat the point.
func _sfx_reject() -> AudioStreamWAV:
	var b := _buffer(0.36)
	_render(b, 0.0, 150.0, 0.09, Wave.NOISE, 0.13, 4.0)
	_render(b, 0.0, _hz(-8.0), 0.20, Wave.TRIANGLE, 0.20, 2.2)
	_render(b, 0.11, _hz(-11.0), 0.24, Wave.TRIANGLE, 0.18, 2.2)
	return _to_stream(b)


## Sword on shield: impact plus a short metal ring.
func _sfx_hit() -> AudioStreamWAV:
	var b := _buffer(0.30)
	_render(b, 0.0, 900.0, 0.05, Wave.NOISE, 0.22, 5.0)
	_render(b, 0.0, _hz(-14.0), 0.13, Wave.SQUARE, 0.16, 3.0, _hz(-26.0))
	_render(b, 0.01, _hz(26.0), 0.22, Wave.SQUARE, 0.09, 2.6)
	_render(b, 0.01, _hz(26.4), 0.22, Wave.SQUARE, 0.08, 2.6)
	return _to_stream(b)


## A type-advantage hit. Heavier impact, a low boom underneath, and a shimmer
## on top so the payoff is audible without reading the log.
func _sfx_crit() -> AudioStreamWAV:
	var b := _buffer(0.55)
	_render(b, 0.0, 1200.0, 0.09, Wave.NOISE, 0.28, 4.0)
	_render(b, 0.0, _hz(-19.0), 0.34, Wave.SAW, 0.22, 1.8, _hz(-33.0))
	_render(b, 0.02, _hz(28.0), 0.30, Wave.SQUARE, 0.11, 2.2)
	_render(b, 0.02, _hz(28.5), 0.30, Wave.SQUARE, 0.10, 2.2)
	_render(b, 0.08, _hz(19.0), 0.36, Wave.SINE, 0.10, 1.6, _hz(35.0))
	return _to_stream(b)


## Brass fanfare, dotted rhythm, landing on a major triad. Written in C major --
## the relative major of the A-minor the soundtrack lives in -- so victory
## sounds like a resolution of the battle theme rather than a different key.
func _sfx_victory() -> AudioStreamWAV:
	var b := _buffer(1.9)
	var notes := [3.0, 3.0, 7.0, 10.0, 15.0]
	var times := [0.0, 0.17, 0.26, 0.40, 0.58]
	for i in notes.size():
		_render(b, times[i], _hz(notes[i]), 0.55, Wave.SAW, 0.17, 2.0)
		_render(b, times[i], _hz(notes[i] - 12.0), 0.55, Wave.SQUARE, 0.09, 2.0)
	# Held triad to finish.
	for semi in [3.0, 7.0, 10.0, 15.0]:
		_render(b, 0.72, _hz(semi), 1.05, Wave.SAW, 0.11, 0.9)
	_render(b, 0.72, 70.0, 0.35, Wave.NOISE, 0.12, 3.0)
	return _to_stream(b)


## Descending natural minor over a low drone.
func _sfx_defeat() -> AudioStreamWAV:
	var b := _buffer(1.7)
	var notes := [0.0, -2.0, -4.0, -9.0]
	for i in notes.size():
		_render(b, float(i) * 0.17, _hz(notes[i]), 0.75, Wave.TRIANGLE, 0.20, 1.5)
	_render(b, 0.0, _hz(-24.0), 1.5, Wave.SAW, 0.13, 0.7)
	_render(b, 0.62, _hz(-29.0), 0.9, Wave.SQUARE, 0.10, 1.2)
	return _to_stream(b)


# --- music -------------------------------------------------------------------
#
# All three tracks are in A natural minor (Aeolian), which is the workhorse
# fantasy mode -- minor enough to feel old and dangerous without the leading
# tone that would make it sound classical. Sharing one key means the crossfade
# between screens never clashes.
#
# Semitone offsets below are relative to A4. The scale is 0 2 3 5 7 8 10.

func _build_tracks() -> void:
	_tracks["home"] = _track_home()
	_tracks["shop"] = _track_shop()
	_tracks["battle"] = _track_battle()


## Title: 3/4, harp arpeggios over a sustained pad. Slow and open -- the first
## thing a player hears should invite them in, not hurry them.
func _track_home() -> AudioStreamWAV:
	var beat := 0.55
	var bars := 8
	var b := _buffer(float(bars) * 3.0 * beat)

	var bass := [-24.0, -28.0, -21.0, -26.0, -24.0, -28.0, -21.0, -26.0]
	var arps := [
		[0.0, 3.0, 7.0, 12.0],
		[-4.0, 0.0, 3.0, 8.0],
		[3.0, 7.0, 10.0, 15.0],
		[-2.0, 2.0, 5.0, 10.0],
	]

	for bar in bars:
		var t0 := float(bar) * 3.0 * beat
		var root: float = bass[bar]
		# Pad: a decay curve below 1.0 barely fades, which is how a sustaining
		# instrument is faked without a real envelope generator.
		_render(b, t0, _hz(root), beat * 3.2, Wave.TRIANGLE, 0.20, 0.7)
		_render(b, t0, _hz(root + 7.0), beat * 3.2, Wave.SINE, 0.09, 0.7)

		var arp: Array = arps[bar % 4]
		for i in 6:
			_render(b, t0 + float(i) * beat * 0.5, _hz(arp[i % 4]),
				beat * 0.9, Wave.SINE, 0.13, 2.0)
	return _to_stream(b, true)


## Shop: 6/8 lute. The compound triple metre is the single strongest "tavern"
## signal available, and a plucked triangle carries it without drawing focus
## away from the thinking the shop is for.
func _track_shop() -> AudioStreamWAV:
	var eighth := 0.21
	var bars := 8
	var b := _buffer(float(bars) * 6.0 * eighth)

	var roots := [-24.0, -24.0, -19.0, -19.0, -26.0, -26.0, -21.0, -17.0]
	var pattern := [0.0, 7.0, 12.0, 7.0, 15.0, 12.0]

	for bar in bars:
		var t0 := float(bar) * 6.0 * eighth
		var root: float = roots[bar]
		_render(b, t0, _hz(root), eighth * 2.6, Wave.TRIANGLE, 0.22, 1.1)
		_render(b, t0 + eighth * 3.0, _hz(root + 7.0), eighth * 2.6, Wave.TRIANGLE, 0.15, 1.1)
		for i in 6:
			_render(b, t0 + float(i) * eighth, _hz(root + 24.0 + pattern[i]),
				eighth * 0.85, Wave.TRIANGLE, 0.08, 2.4)
	return _to_stream(b, true)


## Battle: 6/8 again but twice the speed, with a saw lead over a square drone
## and timpani on the two strong beats. Keeping the metre from the shop makes
## entering a fight feel like the same world speeding up rather than a cut to
## somewhere else.
func _track_battle() -> AudioStreamWAV:
	var eighth := 0.17
	var bars := 8
	var b := _buffer(float(bars) * 6.0 * eighth)

	var roots := [0.0, 0.0, -4.0, -4.0, -2.0, -2.0, 3.0, -2.0]
	var lead := [0.0, 7.0, 12.0, 10.0, 7.0, 3.0]

	for bar in bars:
		var t0 := float(bar) * 6.0 * eighth
		var root: float = roots[bar]

		# Timpani on beats 1 and 4 -- the two accents that define 6/8.
		_render(b, t0, 70.0, eighth * 1.4, Wave.NOISE, 0.13, 3.2)
		_render(b, t0 + eighth * 3.0, 60.0, eighth * 1.2, Wave.NOISE, 0.10, 3.4)

		_render(b, t0, _hz(root - 24.0), eighth * 5.6, Wave.SQUARE, 0.16, 0.9)

		for i in 6:
			var semi: float = root + 12.0 + lead[(bar + i) % 6]
			_render(b, t0 + float(i) * eighth, _hz(semi), eighth * 0.95, Wave.SAW, 0.09, 2.0)
	return _to_stream(b, true)


## The gesture a browser is waiting for. Deliberately _input rather than
## _unhandled_input: a click that lands on a button is consumed before it ever
## reaches unhandled, and "press เริ่มเกม" is exactly the gesture that should
## unlock the audio.
func _input(event: InputEvent) -> void:
	if _audio_unlocked:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	_audio_unlocked = true
	set_process_input(false)
	if _pending_music != "":
		play_music(_pending_music)
