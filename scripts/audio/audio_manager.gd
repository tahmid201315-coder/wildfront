extends Node
## Procedural audio (autoload "Sfx"). All sounds are synthesized at startup from math,
## so there are no third-party audio assets or licences to track. Replace any entry in
## `sounds` / `music` with a real AudioStream to upgrade the audio without touching gameplay.

const RATE := 11025
const MUSIC_LEN := 12.0

var sounds: Dictionary = {}     # name -> AudioStreamWAV
var music: Dictionary = {}      # name -> AudioStreamWAV (looping)
var ready_to_play: bool = false

var _sfx_players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _last_played: Dictionary = {}
var _current_music: String = ""
var _thread: Thread
var _gen_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_amb = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
	_amb.bus = "SFX"
	_amb.volume_db = -22.0
	add_child(_amb)


func _ensure_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_bus("Master", float(s["vol_master"]))
	_set_bus("Music", float(s["vol_music"]))
	_set_bus("SFX", float(s["vol_sfx"]))


func _set_bus(name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


# ------------------------------------------------------------ generation (threaded)
func generate_async() -> void:
	if ready_to_play:
		return
	_thread = Thread.new()
	_thread.start(_generate_all)
	while _thread.is_alive():
		await get_tree().process_frame
	var res: Dictionary = _thread.wait_to_finish()
	sounds = res["sounds"]
	music = res["music"]
	ready_to_play = true


func generate_sync() -> void:
	var res := _generate_all()
	sounds = res["sounds"]
	music = res["music"]
	ready_to_play = true


func _generate_all() -> Dictionary:
	var s := {}
	s["click"] = _wav(_env_tone(660.0, 880.0, 0.07, 0.35, 0))
	s["back"] = _wav(_env_tone(520.0, 330.0, 0.09, 0.35, 0))
	s["pickup"] = _wav(_env_tone(700.0, 1300.0, 0.14, 0.4, 0))
	s["gather"] = _wav(_noise_burst(0.16, 0.5, 0.25))
	s["chop"] = _wav(_mix([_noise_burst(0.12, 0.55, 0.3), _env_tone(120.0, 70.0, 0.12, 0.5, 0)]))
	s["craft"] = _wav(_arp([523.0, 659.0, 784.0], 0.09, 0.4))
	s["build"] = _wav(_mix([_env_tone(90.0, 50.0, 0.22, 0.7, 0), _noise_burst(0.12, 0.3, 0.1)]))
	s["invalid"] = _wav(_env_tone(180.0, 140.0, 0.16, 0.45, 1))
	s["discover"] = _wav(_arp([392.0, 494.0, 587.0, 784.0], 0.11, 0.4))
	s["levelup"] = _wav(_arp([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.1, 0.45))
	s["quest"] = _wav(_arp([440.0, 554.0, 659.0, 880.0], 0.12, 0.4))
	s["eat"] = _wav(_mix([_noise_burst(0.1, 0.4, 0.5), _env_tone(300.0, 200.0, 0.1, 0.25, 0)]))
	s["hit"] = _wav(_mix([_noise_burst(0.12, 0.6, 0.2), _env_tone(150.0, 60.0, 0.14, 0.6, 1)]))
	s["hurt"] = _wav(_env_tone(260.0, 120.0, 0.25, 0.6, 1))
	s["warn"] = _wav(_arp([330.0, 330.0], 0.13, 0.5))
	s["step"] = _wav(_noise_burst(0.07, 0.25, 0.7))
	s["jump"] = _wav(_env_tone(300.0, 520.0, 0.12, 0.3, 0))
	s["land"] = _wav(_noise_burst(0.1, 0.35, 0.8))
	s["ability"] = _wav(_arp([440.0, 660.0, 880.0], 0.08, 0.4))
	s["boss_phase"] = _wav(_arp([220.0, 196.0, 147.0], 0.18, 0.6))
	s["telegraph"] = _wav(_env_tone(200.0, 600.0, 0.5, 0.3, 1))
	# Creature vocalizations (one per tameable species, distinct pitch / shape)
	var voices := {"mossbun": [700.0, 900.0, 0], "bramblehog": [180.0, 140.0, 1], "glimmerwing": [1200.0, 1700.0, 0],
		"lumifox": [520.0, 780.0, 0], "pondling": [240.0, 200.0, 0], "snailbell": [880.0, 880.0, 0],
		"thistlefinch": [1500.0, 2000.0, 0], "cinderstag": [320.0, 240.0, 1], "rustmaw": [110.0, 70.0, 1]}
	for sp in voices:
		var v: Array = voices[sp]
		s["voice_" + sp] = _wav(_env_tone(v[0], v[1], 0.22, 0.4, int(v[2])))
	var m := {}
	m["menu"] = _music_loop([0.0, 3.0, 7.0, 10.0, 12.0], [[0, 4, 7], [-3, 0, 4], [-5, -1, 2], [-3, 0, 4]], 220.0)
	m["explore"] = _music_loop([0.0, 2.0, 4.0, 7.0, 9.0], [[0, 7, 9], [-3, 4, 7], [-5, 2, 7], [-7, 0, 4]], 196.0)
	m["ember"] = _music_loop([0.0, 3.0, 5.0, 7.0, 10.0], [[0, 3, 7], [-2, 3, 5], [-4, 0, 3], [-2, 3, 7]], 174.6)
	m["boss"] = _music_loop([0.0, 1.0, 5.0, 7.0, 8.0], [[0, 1, 7], [-2, 1, 5], [0, 3, 7], [-4, 1, 5]], 130.8)
	m["wind"] = _ambient_noise(8.0, 0.18)
	return {"sounds": s, "music": m}


# ---- synthesis helpers (return PackedFloat32Array)
func _env_tone(f0: float, f1: float, dur: float, vol: float, wave: int) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var s := sin(phase) if wave == 0 else signf(sin(phase)) * 0.6 + sin(phase) * 0.4
		var env := minf(t * 20.0, 1.0) * pow(1.0 - t, 1.6)
		out[i] = s * env * vol
	return out


func _noise_burst(dur: float, vol: float, smooth: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + n
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var raw := rng.randf_range(-1.0, 1.0)
		prev = lerpf(raw, prev, smooth)
		out[i] = prev * vol * pow(1.0 - t, 2.0)
	return out


func _arp(freqs: Array, note_len: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_env_tone(float(f), float(f), note_len * 1.4, vol, 0))
	# overlap-free simple concatenation keeps it cheap
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


func _music_loop(scale: Array, chords: Array, root: float) -> AudioStreamWAV:
	# Slow pad chords + a sparse melody. Frequencies snap to whole cycles per loop so it loops seamlessly.
	var n := int(RATE * MUSIC_LEN)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chord_len := n / chords.size()
	for ci in chords.size():
		var chord: Array = chords[ci]
		for semitone in chord:
			var f := root * pow(2.0, float(semitone) / 12.0)
			f = roundf(f * MUSIC_LEN) / MUSIC_LEN
			var start := ci * chord_len
			for i in chord_len:
				var t := float(i) / chord_len
				var env := sin(PI * t)
				env = env * env
				var ph := TAU * f * float(start + i) / RATE
				buf[start + i] += (sin(ph) + 0.3 * sin(ph * 2.0)) * 0.07 * env
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root * 10.0)
	var note_len := int(RATE * 1.5)
	for k in 6:
		var semitone: float = scale[rng.randi() % scale.size()] + 12.0
		var f := roundf(root * pow(2.0, semitone / 12.0) * MUSIC_LEN) / MUSIC_LEN
		var start := int(float(k) / 6.0 * n)
		for i in note_len:
			var t := float(i) / note_len
			var idx := (start + i) % n
			buf[idx] += sin(TAU * f * float(start + i) / RATE) * 0.09 * pow(1.0 - t, 2.5) * minf(t * 40.0, 1.0)
	return _wav(buf, true)


func _ambient_noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var prev := 0.0
	for i in n:
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, 0.93)
		var swell := 0.6 + 0.4 * sin(TAU * 2.0 * float(i) / n)
		buf[i] = prev * vol * swell
	# crossfade ends so the loop has no click
	var fade := 400
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[n - fade + i] * (1.0 - a) * 0.0
	return _wav(buf, true)


func _wav(samples: Variant, loop: bool = false) -> AudioStreamWAV:
	var arr: PackedFloat32Array = samples
	var bytes := PackedByteArray()
	bytes.resize(arr.size() * 2)
	for i in arr.size():
		bytes.encode_s16(i * 2, int(clampf(arr[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = arr.size()
	return w


# ------------------------------------------------------------ playback
func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not ready_to_play or not sounds.has(name):
		return  # missing audio must never break gameplay
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 70:
		return  # avoid stacking identical sounds
	_last_played[name] = now
	for p in _sfx_players:
		if not p.playing:
			p.stream = sounds[name]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return
	# all busy: steal the first one (oldest)
	var p0: AudioStreamPlayer = _sfx_players[0]
	p0.stream = sounds[name]
	p0.pitch_scale = pitch
	p0.volume_db = vol_db
	p0.play()


func play_voice(species: String) -> void:
	play("voice_" + species, randf_range(0.92, 1.08), -4.0)


func play_music(name: String) -> void:
	if not ready_to_play or not music.has(name) or name == _current_music:
		return
	_current_music = name
	var incoming: AudioStreamPlayer = _music_b if _music_a.playing and _music_a.volume_db > -60.0 else _music_a
	var outgoing: AudioStreamPlayer = _music_a if incoming == _music_b else _music_b
	incoming.stream = music[name]
	incoming.volume_db = -60.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", -6.0, 2.0)
	tw.tween_property(outgoing, "volume_db", -60.0, 2.0)
	tw.chain().tween_callback(func(): if outgoing.volume_db <= -59.0: outgoing.stop())


func stop_music() -> void:
	_current_music = ""
	for m in [_music_a, _music_b]:
		var tw := create_tween()
		tw.tween_property(m, "volume_db", -60.0, 0.8)
		tw.tween_callback(m.stop)


func play_ambience(on: bool) -> void:
	if not ready_to_play:
		return
	if on and not _amb.playing and music.has("wind"):
		_amb.stream = music["wind"]
		_amb.play()
	elif not on:
		_amb.stop()
