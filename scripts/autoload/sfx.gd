extends Node
## Sound effects and a looping background track, synthesized at startup so the project ships
## without audio files. Buses: Master > Music and Master > SFX, set from the settings menu.

const RATE := 22050
const POOL_SIZE := 12

## name -> [duration, start Hz, end Hz, noise amount, decay, wave]
const DEFINITIONS := {
	"kick": [0.09, 260.0, 90.0, 0.25, 22.0, "square"],
	"kick_heavy": [0.16, 220.0, 60.0, 0.35, 16.0, "square"],
	"charge_release": [0.22, 140.0, 480.0, 0.2, 9.0, "sine"],
	"charge_ready": [0.12, 520.0, 980.0, 0.0, 14.0, "sine"],
	"magic": [0.14, 700.0, 1200.0, 0.05, 18.0, "sine"],
	"blast": [0.26, 300.0, 900.0, 0.1, 9.0, "sine"],
	"burst": [0.4, 180.0, 60.0, 0.5, 6.0, "sine"],
	"explosion": [0.5, 120.0, 30.0, 0.8, 5.0, "sine"],
	"hit": [0.07, 420.0, 180.0, 0.4, 30.0, "square"],
	"hurt": [0.22, 320.0, 110.0, 0.3, 9.0, "square"],
	"enemy_die": [0.3, 380.0, 90.0, 0.3, 8.0, "square"],
	"pickup": [0.18, 660.0, 1320.0, 0.0, 12.0, "sine"],
	"heal": [0.35, 440.0, 880.0, 0.0, 6.0, "sine"],
	"switch": [0.2, 300.0, 700.0, 0.0, 12.0, "triangle"],
	"door": [0.25, 180.0, 360.0, 0.1, 8.0, "square"],
	"shockwave": [0.3, 120.0, 60.0, 0.6, 7.0, "sine"],
	"breakable": [0.22, 200.0, 80.0, 0.7, 12.0, "sine"],
	"spike": [0.1, 900.0, 300.0, 0.6, 25.0, "square"],
	"treasure": [0.45, 523.0, 1046.0, 0.0, 4.0, "triangle"],
	"achievement": [0.5, 660.0, 990.0, 0.0, 5.0, "triangle"],
	"roar": [0.7, 110.0, 70.0, 0.5, 2.5, "square"],
	"ui": [0.06, 700.0, 700.0, 0.0, 35.0, "square"],
	"death": [0.9, 300.0, 40.0, 0.2, 2.5, "triangle"],
	"swing": [0.16, 260.0, 120.0, 0.35, 16.0, "sine"],
}

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next: int = 0


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for sound_name in DEFINITIONS.keys():
		var d: Array = DEFINITIONS[sound_name]
		_streams[sound_name] = _synth(float(d[0]), float(d[1]), float(d[2]), float(d[3]), float(d[4]), str(d[5]))
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _make_loop()
	add_child(_music)
	apply_volumes()


func play(sound: String) -> void:
	if not _streams.has(sound):
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.pitch_scale = randf_range(0.94, 1.08)
	player.volume_db = -3.0
	player.play()


func start_music() -> void:
	if not _music.playing:
		_music.play()


func stop_music() -> void:
	_music.stop()


func stop_all() -> void:
	_music.stop()
	for player in _pool:
		player.stop()


func apply_volumes() -> void:
	_set_bus_linear("Master", float(Save.get_setting("master")))
	_set_bus_linear("Music", float(Save.get_setting("music")))
	_set_bus_linear("SFX", float(Save.get_setting("sfx")))


func _set_bus_linear(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


static func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, TAU) < PI else -1.0
		"triangle":
			var p := fmod(phase / TAU, 1.0)
			return 4.0 * absf(p - 0.5) - 1.0
	return sin(phase)


static func _synth(duration: float, f0: float, f1: float, noise: float, decay: float, kind: String) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / RATE
		var k := t / duration
		phase += TAU * lerpf(f0, f1, k) / RATE
		var env := exp(-t * decay) * (1.0 - k * 0.6)
		var s := _wave(kind, phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		s *= env * 0.42
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32768, 32767))
	return _to_stream(data, false, 0)


static func _make_loop() -> AudioStreamWAV:
	var steps := 16
	var step_len := 0.25
	var count := int(steps * step_len * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var chords := [
		[110.0, 130.8, 164.8],
		[87.3, 110.0, 130.8],
		[130.8, 164.8, 196.0],
		[98.0, 123.5, 146.8],
	]
	for step in range(steps):
		var chord: Array = chords[(step / 4) % chords.size()]
		var start := int(step * step_len * RATE)
		var length := int(step_len * RATE)
		if step % 2 == 0:
			_add_tone(samples, start, int(length * 1.9), float(chord[0]) * 0.5, 0.11, "square", 7.0)
		_add_tone(samples, start, length, float(chord[step % 3]) * 2.0, 0.06, "triangle", 6.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		data.encode_s16(i * 2, clampi(int(samples[i] * 32767.0), -32768, 32767))
	return _to_stream(data, true, count)


static func _add_tone(samples: PackedFloat32Array, start: int, length: int, freq: float, amp: float, kind: String, decay: float) -> void:
	var phase := 0.0
	for j in range(length):
		var idx := start + j
		if idx >= samples.size():
			break
		var t := float(j) / RATE
		phase += TAU * freq / RATE
		samples[idx] += _wave(kind, phase) * amp * exp(-t * decay)


static func _to_stream(data: PackedByteArray, loop: bool, loop_end: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = loop_end
	return stream
