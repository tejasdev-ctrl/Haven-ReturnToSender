extends Node
## Tiny procedural synthesiser. Every sound in the game is generated here, so
## the project ships with zero audio files.
##
## Six voices max, mixed straight into an AudioStreamGenerator. If the platform
## refuses the generator the game simply runs silent instead of crashing.

const RATE := 11025.0
const MAX_VOICES := 6

var _playback: AudioStreamGeneratorPlayback = null
var _voices: Array = []


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.volume_db = -6.0
	add_child(p)
	p.play()
	_playback = p.get_stream_playback()


func play(kind: String, pitch := 1.0) -> void:
	if _playback == null:
		return
	var freq := 440.0
	var dur := 0.10
	var amp := 0.18
	var drop := 0.7
	var square := 0.0

	match kind:
		"wall":
			freq = 210.0 * pitch
			dur = 0.07
			amp = 0.15
			drop = 0.55
		"throw":
			freq = 540.0 * pitch
			dur = 0.09
			amp = 0.16
			drop = 1.5
			square = 0.3
		"catch":
			freq = 780.0 * pitch
			dur = 0.11
			amp = 0.18
			drop = 1.7
			square = 0.5
		"kill":
			freq = 95.0
			dur = 0.42
			amp = 0.32
			drop = 0.3
			square = 0.65
		"dash":
			freq = 340.0 * pitch
			dur = 0.11
			amp = 0.11
			drop = 2.4
		"serve":
			freq = 660.0
			dur = 0.13
			amp = 0.16
			drop = 1.2
		"ui":
			freq = 900.0
			dur = 0.05
			amp = 0.10
			drop = 1.0
		"win":
			freq = 300.0
			dur = 0.55
			amp = 0.20
			drop = 1.6
		"near":
			freq = 1300.0
			dur = 0.05
			amp = 0.09
			drop = 0.9

	if _voices.size() >= MAX_VOICES:
		_voices.remove_at(0)
	_voices.append({
		"t": 0.0, "freq": freq, "dur": dur, "amp": amp,
		"drop": drop, "square": square,
	})


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var dt := 1.0 / RATE

	for _i in frames:
		var s := 0.0
		for v in _voices:
			var t: float = v["t"]
			var dur: float = v["dur"]
			if t >= dur:
				continue
			var k: float = t / dur
			var env: float = (1.0 - k) * (1.0 - k)
			var f: float = float(v["freq"]) * lerpf(1.0, float(v["drop"]), k)
			var w: float = sin(t * f * TAU)
			if float(v["square"]) > 0.0:
				w = lerpf(w, signf(w) * 0.9, float(v["square"]))
			s += w * env * float(v["amp"])
			v["t"] = t + dt
		s = clampf(s, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))

	for i in range(_voices.size() - 1, -1, -1):
		if float(_voices[i]["t"]) >= float(_voices[i]["dur"]):
			_voices.remove_at(i)
