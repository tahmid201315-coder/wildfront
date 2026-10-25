extends Node
## Procedural audio (autoload "Sfx"). Every sound and music loop is synthesised at startup, so there
## are no third-party audio files or licences. Ambience is layered and faded by region and weather.

const RATE := 22050          # one-shot effects
const MRATE := 11025         # music and ambience loops (soft, low-passed material)
const MUSIC_LEN := 20.0
const AMB_LEN := 8.0

var sounds: Dictionary = {}
var music: Dictionary = {}
var ambience: Dictionary = {}
var ready_to_play: bool = false

var _sfx_players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _amb_players: Dictionary = {}
var _amb_target: Dictionary = {}
var _last_played: Dictionary = {}
var _current_music: String = ""
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)


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


func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0, 1.0)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


func _process(delta: float) -> void:
	for k in _amb_players:
		var p: AudioStreamPlayer = _amb_players[k]
		var target: float = _amb_target.get(k, -60.0)
		p.volume_db = move_toward(p.volume_db, target, delta * 14.0)
		if p.volume_db <= -58.0 and p.playing:
			p.stop()
		elif p.volume_db > -58.0 and not p.playing and ambience.has(k):
			p.play()


# ------------------------------------------------------------ generation (threaded)
func generate_async() -> void:
	if ready_to_play:
		return
	_thread = Thread.new()
	_thread.start(_generate_all)
	while _thread.is_alive():
		await get_tree().process_frame
	_finish(_thread.wait_to_finish())


func generate_sync() -> void:
	if ready_to_play:
		return
	_finish(_generate_all())


func _finish(res: Dictionary) -> void:
	sounds = res["sounds"]
	music = res["music"]
	ambience = res["ambience"]
	for k in ambience:
		if not _amb_players.has(k):
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			p.volume_db = -60.0
			p.stream = ambience[k]
			add_child(p)
			_amb_players[k] = p
	ready_to_play = true


func _generate_all() -> Dictionary:
	var s := {}
	# --- UI
	s["click"] = _wav(_tone(700.0, 900.0, 0.07, 0.3, 0))
	s["back"] = _wav(_tone(520.0, 330.0, 0.09, 0.3, 0))
	s["open"] = _wav(_arp([440.0, 660.0], 0.06, 0.3))
	s["close"] = _wav(_arp([660.0, 440.0], 0.06, 0.3))
	s["invalid"] = _wav(_tone(190.0, 140.0, 0.16, 0.4, 1))
	s["pickup"] = _wav(_tone(700.0, 1400.0, 0.14, 0.35, 0))
	s["quest"] = _wav(_arp([440.0, 554.0, 659.0, 880.0], 0.12, 0.35))
	s["levelup"] = _wav(_arp([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.1, 0.4))
	s["discover"] = _wav(_arp([392.0, 494.0, 587.0, 784.0], 0.11, 0.35))
	s["warn"] = _wav(_arp([330.0, 330.0], 0.13, 0.4))
	s["log"] = _wav(_arp([300.0, 400.0, 300.0, 520.0], 0.09, 0.3))
	# --- gathering & building
	s["chop"] = _wav(_mix([_noise(0.12, 0.55, 0.3), _tone(130.0, 70.0, 0.14, 0.5, 0)]))
	s["mine"] = _wav(_mix([_noise(0.08, 0.6, 0.1), _tone(900.0, 500.0, 0.1, 0.25, 1), _tone(110.0, 60.0, 0.12, 0.4, 0)]))
	s["pluck"] = _wav(_mix([_noise(0.12, 0.35, 0.5), _tone(500.0, 800.0, 0.08, 0.2, 0)]))
	s["craft"] = _wav(_arp([523.0, 659.0, 784.0], 0.09, 0.35))
	s["craft_tick"] = _wav(_mix([_noise(0.05, 0.45, 0.2), _tone(240.0, 200.0, 0.05, 0.3, 1)]))
	s["build"] = _wav(_mix([_tone(100.0, 55.0, 0.22, 0.6, 0), _noise(0.12, 0.3, 0.1)]))
	s["door"] = _wav(_mix([_tone(160.0, 110.0, 0.25, 0.35, 0), _noise(0.2, 0.2, 0.6)]))
	s["chest"] = _wav(_mix([_tone(220.0, 180.0, 0.2, 0.35, 0), _noise(0.15, 0.25, 0.5), _arp([660.0, 880.0], 0.07, 0.2)]))
	s["eat"] = _wav(_mix([_noise(0.1, 0.4, 0.5), _tone(300.0, 200.0, 0.1, 0.25, 0)]))
	s["heal"] = _wav(_arp([523.0, 659.0, 880.0], 0.08, 0.3))
	s["fire"] = _wav(_mix([_noise(0.3, 0.3, 0.7), _tone(80.0, 60.0, 0.3, 0.2, 0)]))
	# --- movement
	s["step_grass"] = _wav(_noise(0.07, 0.22, 0.6))
	s["step_sand"] = _wav(_noise(0.09, 0.2, 0.8))
	s["step_stone"] = _wav(_mix([_noise(0.05, 0.3, 0.2), _tone(300.0, 200.0, 0.05, 0.12, 1)]))
	s["step_metal"] = _wav(_mix([_noise(0.04, 0.2, 0.1), _tone(700.0, 400.0, 0.08, 0.15, 1)]))
	s["step_water"] = _wav(_noise(0.14, 0.3, 0.9))
	s["jump"] = _wav(_tone(300.0, 520.0, 0.12, 0.25, 0))
	s["land"] = _wav(_noise(0.12, 0.4, 0.8))
	s["dodge"] = _wav(_noise(0.2, 0.3, 0.92))
	s["splash"] = _wav(_noise(0.3, 0.45, 0.85))
	# --- combat
	s["swing"] = _wav(_noise(0.18, 0.28, 0.93))
	s["swing_heavy"] = _wav(_mix([_noise(0.3, 0.35, 0.95), _tone(200.0, 90.0, 0.3, 0.2, 0)]))
	s["hit"] = _wav(_mix([_noise(0.12, 0.6, 0.2), _tone(150.0, 60.0, 0.14, 0.6, 1)]))
	s["hit_metal"] = _wav(_mix([_noise(0.08, 0.5, 0.05), _tone(1200.0, 600.0, 0.18, 0.3, 1)]))
	s["hurt"] = _wav(_tone(260.0, 120.0, 0.25, 0.55, 1))
	s["death"] = _wav(_mix([_tone(220.0, 40.0, 0.9, 0.5, 1), _noise(0.5, 0.3, 0.9)]))
	s["shot"] = _wav(_mix([_tone(1200.0, 300.0, 0.18, 0.35, 0), _noise(0.06, 0.4, 0.1)]))
	s["bolt"] = _wav(_tone(520.0, 880.0, 0.22, 0.3, 0))
	s["explode"] = _wav(_mix([_noise(0.5, 0.7, 0.8), _tone(90.0, 30.0, 0.5, 0.7, 0)]))
	s["block"] = _wav(_mix([_noise(0.08, 0.4, 0.1), _tone(500.0, 300.0, 0.12, 0.3, 1)]))
	# --- creatures
	s["growl_stalker"] = _wav(_mix([_tone(160.0, 90.0, 0.45, 0.4, 1), _noise(0.4, 0.15, 0.85)]))
	s["growl_brute"] = _wav(_mix([_tone(70.0, 45.0, 0.7, 0.55, 1), _noise(0.6, 0.2, 0.9)]))
	s["hum_wraith"] = _wav(_mix([_tone(520.0, 700.0, 0.7, 0.2, 0), _tone(525.0, 705.0, 0.7, 0.2, 0)]))
	s["whir_sentinel"] = _wav(_mix([_tone(220.0, 340.0, 0.5, 0.25, 1), _noise(0.4, 0.1, 0.4)]))
	s["telegraph"] = _wav(_tone(200.0, 650.0, 0.55, 0.25, 1))
	s["boss_roar"] = _wav(_mix([_tone(90.0, 40.0, 1.3, 0.7, 1), _noise(1.1, 0.35, 0.9)]))
	s["boss_slam"] = _wav(_mix([_tone(70.0, 25.0, 0.6, 0.8, 0), _noise(0.5, 0.6, 0.9)]))
	s["boss_phase"] = _wav(_arp([220.0, 196.0, 147.0, 110.0], 0.18, 0.55))
	s["boss_down"] = _wav(_mix([_arp([392.0, 330.0, 262.0, 196.0, 131.0], 0.22, 0.4), _noise(1.0, 0.25, 0.9)]))
	s["animal_squeak"] = _wav(_tone(900.0, 1300.0, 0.12, 0.2, 0))
	s["animal_call"] = _wav(_tone(380.0, 300.0, 0.2, 0.25, 0))
	# --- ambient one-shots
	s["bird1"] = _wav(_arp([1800.0, 2200.0, 1900.0], 0.05, 0.12))
	s["bird2"] = _wav(_arp([2400.0, 2100.0, 2600.0, 2300.0], 0.04, 0.1))
	s["insect"] = _wav(_tone(3800.0, 3900.0, 0.5, 0.05, 0))
	s["thunder"] = _wav(_mix([_noise(2.2, 0.6, 0.97), _tone(60.0, 30.0, 2.0, 0.3, 0)]))
	s["drip"] = _wav(_tone(1400.0, 700.0, 0.1, 0.2, 0))
	s["steam"] = _wav(_noise(0.9, 0.3, 0.6))
	s["pylon"] = _wav(_arp([330.0, 440.0, 660.0, 990.0], 0.1, 0.35))
	s["gate"] = _wav(_mix([_tone(60.0, 90.0, 1.2, 0.5, 0), _noise(1.0, 0.25, 0.9)]))
	s["ending"] = _wav(_arp([262.0, 330.0, 392.0, 523.0, 659.0, 784.0], 0.28, 0.35))
	var m := {}
	m["menu"] = _music([0.0, 3.0, 7.0, 10.0, 12.0], [[0, 7, 10], [-4, 3, 7], [-5, 2, 7], [-7, 0, 7]], 196.0, 0.8, 1)
	m["day"] = _music([0.0, 2.0, 4.0, 7.0, 9.0], [[0, 7, 9], [-3, 4, 7], [-5, 2, 7], [-7, 0, 4]], 220.0, 1.0, 2)
	m["night"] = _music([0.0, 3.0, 7.0, 10.0], [[0, 7, 10], [-4, 3, 7], [-2, 5, 9], [-7, 0, 7]], 164.8, 0.5, 0)
	m["combat"] = _music([0.0, 1.0, 5.0, 7.0, 8.0], [[0, 7, 12], [-2, 5, 10], [-4, 3, 8], [-5, 2, 7]], 146.8, 1.0, 4)
	m["boss"] = _music([0.0, 1.0, 3.0, 6.0, 7.0], [[0, 7, 13], [-1, 6, 11], [-4, 3, 8], [-6, 1, 6]], 110.0, 1.0, 4)
	m["ashen"] = _music([0.0, 1.0, 5.0, 8.0], [[0, 6, 10], [-1, 5, 9], [-3, 4, 8], [-6, 1, 5]], 130.8, 0.7, 1)
	m["core"] = _music([0.0, 2.0, 7.0, 11.0, 14.0], [[0, 7, 14], [2, 9, 14], [-2, 5, 12], [-5, 2, 9]], 246.9, 0.6, 3)
	m["ending"] = _music([0.0, 4.0, 7.0, 12.0], [[0, 4, 7], [-3, 4, 9], [-5, 2, 7], [0, 7, 12]], 261.6, 0.8, 1)
	var a := {}
	a["wind"] = _amb_noise(AMB_LEN, 0.5, 0.95, 2.0)
	a["waves"] = _amb_noise(AMB_LEN, 0.55, 0.9, 4.0)
	a["rain"] = _amb_noise(AMB_LEN, 0.4, 0.55, 40.0)
	a["fire"] = _amb_crackle(AMB_LEN)
	a["steam"] = _amb_noise(AMB_LEN, 0.4, 0.4, 3.0)
	a["rumble"] = _amb_noise(AMB_LEN, 0.6, 0.985, 1.0)
	a["hum"] = _amb_hum(AMB_LEN, 82.0)
	a["crickets"] = _amb_crickets(AMB_LEN)
	return {"sounds": s, "music": m, "ambience": a}


# ---- synthesis helpers (PackedFloat32Array)
func _tone(f0: float, f1: float, dur: float, vol: float, wave: int) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(f0, f1, t) / RATE
		var s := sin(phase) if wave == 0 else signf(sin(phase)) * 0.55 + sin(phase) * 0.45
		out[i] = s * minf(t * 24.0, 1.0) * pow(1.0 - t, 1.6) * vol
	return out


func _noise(dur: float, vol: float, smooth: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + n
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, smooth)
		out[i] = prev * vol * pow(1.0 - t, 2.0) * minf(t * 40.0, 1.0)
	return out


func _arp(freqs: Array, note_len: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(_tone(float(f), float(f), note_len * 1.4, vol, 0))
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


## Pad chords + plucked melody + optional soft pulse. density 0..4 sets how busy the melody/pulse is.
func _music(scale: Array, chords: Array, root: float, vol: float, density: int) -> AudioStreamWAV:
	var n := int(MRATE * MUSIC_LEN)
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
				var ph := TAU * f * float(start + i) / MRATE
				buf[start + i] += (sin(ph) + 0.25 * sin(ph * 2.0) + 0.1 * sin(ph * 3.0)) * 0.06 * env * vol
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root * 10.0)
	var notes := 6 + density * 4
	var note_len := int(MRATE * (2.2 - density * 0.25))
	for k in notes:
		var semitone: float = float(scale[rng.randi() % scale.size()]) + (12.0 if rng.randf() < 0.7 else 0.0)
		var f := roundf(root * pow(2.0, semitone / 12.0) * MUSIC_LEN) / MUSIC_LEN
		var start := int(float(k) / notes * n)
		for i in note_len:
			var t := float(i) / note_len
			var idx := (start + i) % n
			var ph := TAU * f * float(start + i) / MRATE
			buf[idx] += (sin(ph) + 0.35 * sin(ph * 2.0) + 0.12 * sin(ph * 3.0)) * 0.08 * vol * pow(1.0 - t, 2.4) * minf(t * 60.0, 1.0)
	if density >= 3:
		# soft bass pulse
		var beat := int(MRATE * 0.5)
		var bf := roundf(root * 0.5 * MUSIC_LEN) / MUSIC_LEN
		var k := 0
		while k * beat < n:
			var start := k * beat
			for i in int(beat * 0.9):
				var t := float(i) / (beat * 0.9)
				var idx := (start + i) % n
				buf[idx] += sin(TAU * bf * float(start + i) / MRATE) * 0.1 * pow(1.0 - t, 2.0) * vol
			k += 1
	return _wav(buf, true, MRATE)


func _amb_noise(dur: float, vol: float, smooth: float, swell_cycles: float) -> AudioStreamWAV:
	var n := int(MRATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + int(smooth * 100)
	var prev := 0.0
	for i in n:
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, smooth)
		var swell := 0.65 + 0.35 * sin(TAU * swell_cycles * float(i) / n)
		buf[i] = prev * vol * swell * (1.0 - smooth * 0.35)
	_loop_fade(buf, 600)
	return _wav(buf, true, MRATE)


func _amb_crackle(dur: float) -> AudioStreamWAV:
	var n := int(MRATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var prev := 0.0
	for i in n:
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, 0.97)
		buf[i] = prev * 0.07
	for k in 70:
		var start := rng.randi() % (n - 400)
		var amp := rng.randf_range(0.15, 0.5)
		for i in 300:
			buf[start + i] += rng.randf_range(-1.0, 1.0) * amp * pow(1.0 - float(i) / 300.0, 3.0)
	_loop_fade(buf, 400)
	return _wav(buf, true, MRATE)


func _amb_hum(dur: float, f: float) -> AudioStreamWAV:
	var n := int(MRATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var fr := roundf(f * dur) / dur
	for i in n:
		var ph := TAU * fr * float(i) / MRATE
		var wob := 0.7 + 0.3 * sin(TAU * 3.0 * float(i) / n)
		buf[i] = (sin(ph) * 0.3 + sin(ph * 2.0) * 0.12 + sin(ph * 3.01) * 0.05) * wob * 0.5
	return _wav(buf, true, MRATE)


func _amb_crickets(dur: float) -> AudioStreamWAV:
	var n := int(MRATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for k in 14:
		var start := rng.randi() % (n - 2000)
		var f := rng.randf_range(2600.0, 3600.0)
		for c in 4:
			for i in 160:
				var idx := start + c * 220 + i
				if idx < n:
					buf[idx] += sin(TAU * f * float(i) / MRATE) * 0.05 * sin(PI * float(i) / 160.0)
	return _wav(buf, true, MRATE)


func _loop_fade(buf: PackedFloat32Array, fade: int) -> void:
	var n := buf.size()
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[n - fade + i] * (1.0 - a)


func _wav(samples: Variant, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var arr: PackedFloat32Array = samples
	var bytes := PackedByteArray()
	bytes.resize(arr.size() * 2)
	for i in arr.size():
		bytes.encode_s16(i * 2, int(clampf(arr[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = arr.size()
	return w


# ------------------------------------------------------------ playback
func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not ready_to_play or not sounds.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 60:
		return
	_last_played[sound] = now
	for p in _sfx_players:
		if not p.playing:
			p.stream = sounds[sound]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return
	var p0: AudioStreamPlayer = _sfx_players[0]
	p0.stream = sounds[sound]
	p0.pitch_scale = pitch
	p0.volume_db = vol_db
	p0.play()


## Plays a sound with distance attenuation relative to the listener (camera or player).
func play_at(sound: String, pos: Vector3, pitch: float = 1.0, max_dist: float = 40.0) -> void:
	var listener: Vector3 = Vector3.ZERO
	var vp := get_viewport()
	if vp and vp.get_camera_3d():
		listener = vp.get_camera_3d().global_position
	var d := pos.distance_to(listener)
	if d > max_dist:
		return
	play(sound, pitch * randf_range(0.95, 1.05), linear_to_db(clampf(1.0 - d / max_dist, 0.02, 1.0)) - 2.0)


func play_music(track: String) -> void:
	if not ready_to_play or not music.has(track) or track == _current_music:
		return
	_current_music = track
	var incoming: AudioStreamPlayer = _music_b if _music_a.playing and _music_a.volume_db > -60.0 else _music_a
	var outgoing: AudioStreamPlayer = _music_a if incoming == _music_b else _music_b
	incoming.stream = music[track]
	incoming.volume_db = -60.0
	incoming.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", -4.0, 2.5)
	tw.tween_property(outgoing, "volume_db", -60.0, 2.5)
	tw.chain().tween_callback(func(): if outgoing.volume_db <= -59.0: outgoing.stop())


func current_music() -> String:
	return _current_music


func stop_music() -> void:
	_current_music = ""
	for m in [_music_a, _music_b]:
		var tw := create_tween()
		tw.tween_property(m, "volume_db", -60.0, 1.0)
		tw.tween_callback(m.stop)


## layers: {name: linear_volume 0..1}. Anything not listed fades out.
func set_ambience(layers: Dictionary) -> void:
	for k in _amb_players:
		var v: float = float(layers.get(k, 0.0))
		_amb_target[k] = -60.0 if v <= 0.01 else linear_to_db(clampf(v, 0.0, 1.0)) - 6.0
