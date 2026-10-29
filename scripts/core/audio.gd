extends Node
## Fully procedural audio: SFX synthesised from small recipes, music rendered per track as a looping stream.
## Separate buses for Music and SFX; master/music/sfx sliders and mute come from Game.settings.

const RATE := 22050
const MRATE := 16000
const POOL := 14

var _sfx_cache: Dictionary = {}
var _players: Array = []
var _next: int = 0
var _music: AudioStreamPlayer = null
var _music_cache: Dictionary = {}
var current_music: String = ""
var play_count: int = 0          # for tests
var last_played: String = ""

# name: [wave, f0, f1, dur, vol, extra]  wave: sine square saw noise tri
const RECIPES := {
	"jump": ["square", 330.0, 620.0, 0.12, 0.25], "land": ["noise", 160.0, 60.0, 0.08, 0.3],
	"dash": ["noise", 900.0, 200.0, 0.18, 0.3], "swing": ["noise", 1400.0, 500.0, 0.1, 0.22],
	"swing_heavy": ["noise", 900.0, 150.0, 0.2, 0.32], "hit": ["saw", 220.0, 90.0, 0.11, 0.35],
	"block": ["square", 800.0, 600.0, 0.07, 0.25], "hurt": ["saw", 300.0, 80.0, 0.3, 0.4],
	"enemy_die": ["noise", 500.0, 60.0, 0.3, 0.35], "shard": ["sine", 988.0, 1480.0, 0.14, 0.3],
	"pickup": ["sine", 660.0, 1320.0, 0.2, 0.3], "heal": ["sine", 440.0, 880.0, 0.5, 0.3],
	"magic_hit": ["tri", 700.0, 200.0, 0.2, 0.35], "bolt": ["tri", 600.0, 1100.0, 0.16, 0.28],
	"arrow": ["noise", 2000.0, 1200.0, 0.09, 0.2], "shot": ["saw", 500.0, 250.0, 0.14, 0.25],
	"wave": ["noise", 200.0, 80.0, 0.35, 0.35], "erupt": ["noise", 120.0, 50.0, 0.3, 0.4],
	"beam": ["saw", 110.0, 120.0, 0.6, 0.3], "telegraph": ["sine", 440.0, 440.0, 0.12, 0.22],
	"boss_roar": ["saw", 110.0, 40.0, 0.9, 0.5], "void": ["tri", 400.0, 60.0, 0.45, 0.35],
	"checkpoint": ["sine", 523.0, 1046.0, 0.7, 0.3], "chest": ["square", 440.0, 880.0, 0.3, 0.25],
	"door": ["noise", 100.0, 40.0, 0.4, 0.3], "switch": ["square", 300.0, 200.0, 0.08, 0.25],
	"puzzle": ["sine", 523.0, 1568.0, 0.8, 0.3], "wrong": ["square", 200.0, 120.0, 0.25, 0.25],
	"deny": ["square", 180.0, 150.0, 0.12, 0.22], "break": ["noise", 600.0, 100.0, 0.25, 0.35],
	"splash": ["noise", 700.0, 300.0, 0.2, 0.25], "stasis": ["sine", 200.0, 1600.0, 0.5, 0.3],
	"ability": ["sine", 330.0, 1320.0, 1.0, 0.35], "defeat": ["saw", 330.0, 55.0, 1.2, 0.4],
	"step_": ["noise", 300.0, 200.0, 0.04, 0.1], "ui_move": ["tri", 600.0, 640.0, 0.04, 0.18],
	"ui_ok": ["square", 520.0, 780.0, 0.09, 0.2], "ui_back": ["square", 420.0, 300.0, 0.08, 0.2],
}

# music: scale intervals, root midi, bpm, bass pattern style, lead density, timbre
const TRACKS := {
	"title": {"scale": [0, 2, 4, 7, 9], "root": 57, "bpm": 84, "lead": 0.5, "wave": "sine", "bass": 1},
	"meadows": {"scale": [0, 2, 4, 7, 9], "root": 60, "bpm": 96, "lead": 0.55, "wave": "tri", "bass": 1},
	"ember": {"scale": [0, 1, 4, 5, 7, 8], "root": 50, "bpm": 112, "lead": 0.5, "wave": "saw", "bass": 2},
	"observatory": {"scale": [0, 2, 3, 7, 8], "root": 57, "bpm": 76, "lead": 0.4, "wave": "sine", "bass": 0},
	"thornwild": {"scale": [0, 2, 3, 5, 7, 9, 10], "root": 52, "bpm": 100, "lead": 0.5, "wave": "tri", "bass": 1},
	"frostfall": {"scale": [0, 2, 3, 7, 10], "root": 66, "bpm": 72, "lead": 0.35, "wave": "sine", "bass": 0},
	"clockwork": {"scale": [0, 2, 3, 5, 7, 8, 10], "root": 55, "bpm": 120, "lead": 0.6, "wave": "square", "bass": 2},
	"eclipse": {"scale": [0, 1, 3, 6, 7, 10], "root": 49, "bpm": 88, "lead": 0.45, "wave": "saw", "bass": 1},
	"combat": {"scale": [0, 2, 3, 5, 7, 8], "root": 52, "bpm": 132, "lead": 0.65, "wave": "square", "bass": 2},
	"boss": {"scale": [0, 2, 3, 5, 7, 8, 10], "root": 50, "bpm": 148, "lead": 0.75, "wave": "saw", "bass": 2},
	"victory": {"scale": [0, 2, 4, 7, 9], "root": 62, "bpm": 110, "lead": 0.8, "wave": "tri", "bass": 1},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()
	_thread = Thread.new()
	_thread.start(_prewarm)


var _thread: Thread = null


func _prewarm() -> void:
	for n in TRACKS.keys():
		if _music_cache.has(n):
			continue
		call_deferred("_store_track", n, _render_track(n))


func _store_track(n: String, w: AudioStreamWAV) -> void:
	if not _music_cache.has(n):
		_music_cache[n] = w


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _ensure_bus(n: String) -> void:
	if AudioServer.get_bus_index(n) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, n)
		AudioServer.set_bus_send(i, "Master")


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	var mute: bool = s.get("mute", false)
	var m := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(m, mute)
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(float(s.get("master", 1.0)), 0.0001)))
	var mu := AudioServer.get_bus_index("Music")
	var sf := AudioServer.get_bus_index("SFX")
	if mu >= 0:
		AudioServer.set_bus_volume_db(mu, linear_to_db(maxf(float(s.get("music", 0.7)), 0.0001)))
	if sf >= 0:
		AudioServer.set_bus_volume_db(sf, linear_to_db(maxf(float(s.get("sfx", 0.9)), 0.0001)))


# ------------------------------------------------------------------ SFX
func play(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	last_played = n
	play_count += 1
	if _players.is_empty():
		return
	var key := n
	if n == "step_":
		key = "step_"
	if not RECIPES.has(key):
		return
	if not _sfx_cache.has(key):
		_sfx_cache[key] = _render_sfx(RECIPES[key])
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _sfx_cache[key]
	p.pitch_scale = pitch * (0.97 + randf() * 0.06)
	p.volume_db = vol_db
	p.play()


func _osc(wave: String, ph: float) -> float:
	match wave:
		"sine": return sin(ph * TAU)
		"square": return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		"saw": return fmod(ph, 1.0) * 2.0 - 1.0
		"tri": return absf(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
	return 0.0


func _render_sfx(r: Array) -> AudioStreamWAV:
	var wave: String = r[0]
	var n := int(float(r[3]) * RATE)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var ph := 0.0
	var seed_v := 12345
	var lp := 0.0
	for i in n:
		var u := float(i) / float(n)
		var f: float = lerpf(float(r[1]), float(r[2]), u)
		var env := minf(u * 40.0, 1.0) * pow(1.0 - u, 1.6)
		var v: float
		if wave == "noise":
			seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
			var nz := float(seed_v) / 1073741824.0 - 1.0
			var a := clampf(f / float(RATE) * 6.0, 0.02, 0.9)
			lp += (nz - lp) * a
			v = lp * 2.0
		else:
			ph += f / float(RATE)
			v = _osc(wave, ph)
		var s := int(clampf(v * env * float(r[4]), -1.0, 1.0) * 32000.0)
		buf.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = buf
	return w


# ------------------------------------------------------------------ music
func play_music(n: String) -> void:
	if n == current_music and _music != null and _music.playing:
		return
	current_music = n
	if _music == null or not TRACKS.has(n):
		return
	if not _music_cache.has(n):
		_music_cache[n] = _render_track(n)
	_music.stream = _music_cache[n]
	_music.play()


func stop_music() -> void:
	current_music = ""
	if _music != null:
		_music.stop()


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _render_track(n: String) -> AudioStreamWAV:
	var t: Dictionary = TRACKS[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(n)
	var bpm: float = float(t["bpm"])
	var beat := 60.0 / bpm
	var bars := 8
	var total := int(bars * 4.0 * beat * MRATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var scale: Array = t["scale"]
	var root: int = t["root"]
	var wave: String = t["wave"]
	var prog := [0, 3, 4, 2, 0, 3, 5, 4]   # scale degrees per bar (index into scale, wrapped)
	var sl := scale.size()
	var step_len := beat * 0.5
	for bar in bars:
		var deg: int = prog[bar] % sl
		var base := root - 12 + int(scale[deg])
		for s8 in 8:
			var tpos := (bar * 8 + s8) * step_len
			# bass
			var bs: int = t["bass"]
			if bs == 2 or (bs == 1 and s8 % 2 == 0) or (bs == 0 and s8 == 0):
				_note(mix, tpos, step_len * (0.9 if bs == 2 else 1.8), _midi(base), "tri" if bs != 2 else "saw", 0.16)
			# lead
			if rng.randf() < float(t["lead"]):
				var di := (deg + rng.randi_range(0, 4) * 1) % sl
				var oct := 12 if rng.randf() < 0.6 else 0
				_note(mix, tpos, step_len * rng.randf_range(0.8, 1.8), _midi(root + oct + int(scale[di])), wave, 0.09)
		# pad chord (root, third-ish, fifth-ish)
		var ptime := bar * 4.0 * beat
		for k in [0, 2, 4]:
			_note(mix, ptime, 4.0 * beat, _midi(root + int(scale[(deg + k) % sl])), "sine", 0.045)
	var buf := PackedByteArray()
	buf.resize(total * 2)
	for i in total:
		buf.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MRATE
	w.data = buf
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w


func _note(mix: PackedFloat32Array, t0: float, dur: float, f: float, wave: String, vol: float) -> void:
	var s0 := int(t0 * MRATE)
	var cnt := int(dur * MRATE)
	var total := mix.size()
	var ph := 0.0
	var inc := f / float(MRATE)
	for i in cnt:
		var idx := s0 + i
		if idx >= total:
			idx -= total   # wrap so the loop is seamless
		var u := float(i) / float(cnt)
		var env := minf(u * 30.0, 1.0) * (1.0 - u)
		ph += inc
		mix[idx] += _osc(wave, ph) * env * vol
