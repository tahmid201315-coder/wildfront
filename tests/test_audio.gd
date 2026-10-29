extends Node
var passed := 0
var failed := 0
func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  ok   ", name)
	else:
		failed += 1
		print("  FAIL ", name, "  ", detail)

func _ready() -> void:
	await get_tree().process_frame
	# every SFX name used in the code base has a recipe
	for n in Sfx.RECIPES.keys():
		Sfx.play(n)
		check("sfx " + n, Sfx._sfx_cache.has(n) and Sfx._sfx_cache[n].data.size() > 100)
	for t in Sfx.TRACKS.keys():
		var t0 := Time.get_ticks_msec()
		Sfx.play_music(t)
		var s: AudioStreamWAV = Sfx._music_cache[t]
		check("track %s renders (%d ms, %.1fs)" % [t, Time.get_ticks_msec() - t0, float(s.data.size()) / 2.0 / Sfx.MRATE], s.data.size() > 1000 and s.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	for r in Defs.REGION_ORDER:
		check("region music exists: " + r, Sfx.TRACKS.has(Defs.REGIONS[r]["music"]))
	# unique tracks are not identical
	check("tracks differ", Sfx._music_cache["meadows"].data != Sfx._music_cache["boss"].data)
	# volume + mute
	Game.settings["master"] = 0.5; Game.settings["music"] = 0.25; Game.settings["sfx"] = 0.8; Game.settings["mute"] = false
	Sfx.apply_volumes()
	check("master volume", absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01)
	check("music bus volume", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.25)) < 0.01)
	check("sfx bus volume", absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.8)) < 0.01)
	Game.settings["mute"] = true
	Sfx.apply_volumes()
	check("mute", AudioServer.is_bus_mute(0))
	Game.settings["mute"] = false
	Sfx.apply_volumes()
	Sfx.stop_music()
	check("stop music", Sfx.current_music == "")
	print("\n== %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
