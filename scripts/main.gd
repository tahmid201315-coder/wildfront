extends Node
## Entry point: owns the Stage and UI layers and routes game flow (title -> play -> pause -> game over -> ending).

var stage: Stage
var hud: Hud
var touch: TouchControls
var menus: Menus
var cutscene: Cutscene
var death_timer := -1.0
var booted := false
var ending_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Menus.apply_saved_keys()
	stage = Stage.new()
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	hud = Hud.new()
	add_child(hud)
	hud.attach(stage)
	touch = TouchControls.new()
	add_child(touch)
	menus = Menus.new()
	add_child(menus)
	cutscene = Cutscene.new()
	add_child(cutscene)
	menus.new_game.connect(_on_new_game)
	menus.continue_game.connect(_on_continue)
	menus.resume.connect(_on_resume)
	menus.quit_to_title.connect(_on_quit_to_title)
	menus.retry.connect(_on_retry)
	menus.ngp_game.connect(_on_ngp)
	menus.daily_trial.connect(_on_daily)
	menus.quit_app.connect(func() -> void: get_tree().quit())
	stage.player_died.connect(_on_player_died)
	stage.boss_defeated.connect(_on_boss_defeated)
	stage.request_cutscene.connect(func(id: String) -> void: cutscene.play(id))
	cutscene.finished.connect(_on_cutscene_finished)
	Game.apply_setting("master", Game.settings["master"])
	Game.apply_battery()
	_to_title()


func _to_title() -> void:
	death_timer = -1.0
	ending_started = false
	Game.clear_state_stack()
	Game.set_state(Game.State.TITLE)
	stage.visible = false
	Sfx.play_music("title")
	menus.show_title()


func _start_play() -> void:
	menus.close_all()
	stage.visible = true
	Game.clear_state_stack()
	Game.set_state(Game.State.PLAY)
	var cp: Dictionary = Game.checkpoint
	var rid := str(cp.get("level", "meadows_1"))
	if World.get_room(rid) == null:
		rid = "meadows_1"
		Game.checkpoint = {"region": "meadows", "level": rid, "id": "start"}
	stage.change_room(rid, str(cp.get("id", "start")))
	stage.player.invuln_t = 1.0
	if not Game.trial and not Game.flag("tut_done") and rid == "meadows_1" and Game.settings.get("hints", true):
		_tutorial()


func _on_new_game(slot: int, diff: int) -> void:
	Save.delete_slot(slot)
	Game.new_progress()
	Game.slot = slot
	Game.apply_setting("difficulty", diff)
	Game.full_restore()
	menus.close_all()
	stage.visible = true
	Game.checkpoint = {"region": "meadows", "level": "meadows_1", "id": "start"}
	Save.write_slot(slot, Game.serialize())
	Game.seen_intro = true
	cutscene.play("intro")
	cutscene.finished.connect(_after_intro, CONNECT_ONE_SHOT)


func _after_intro(_id: String) -> void:
	_start_play()
	stage.autosave()


func _on_continue(slot: int) -> void:
	var r := Save.load_slot(slot)
	if not r["ok"]:
		Game.toast.emit("That save could not be loaded: " + str(r.get("message", "")), "bad")
		menus.show_title()
		return
	Game.deserialize(r["data"]["game"] if r["data"].has("game") else r["data"])
	Game.slot = slot
	_start_play()


func _unhandled_input(e: InputEvent) -> void:
	if Game.state == Game.State.PLAY:
		if e.is_action_pressed("pause"):
			Game.push_state(Game.State.PAUSE)
			menus.show_pause()
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("map"):
			Game.push_state(Game.State.PAUSE)
			menus.open_direct(menus.show_map)
			get_viewport().set_input_as_handled()


func _on_resume() -> void:
	Game.pop_state()
	Game.set_state(Game.State.PLAY)


func _on_quit_to_title() -> void:
	if Game.state != Game.State.TITLE and stage.data != null and not Game.trial:
		stage.autosave()
	_to_title()


func _on_player_died() -> void:
	Game.deaths += 1
	death_timer = 1.6
	Game.toast.emit("Kael falls...", "bad")
	Sfx.play("defeat")


var _music_check := 0.0
var _combat := false


func _update_music(dt: float) -> void:
	_music_check -= dt
	if _music_check > 0.0 or Game.state != Game.State.PLAY or stage.data == null:
		return
	_music_check = 0.5
	if Game.in_boss_fight:
		return
	var engaged := false
	for e in stage.enemies:
		if is_instance_valid(e) and e.alive and e.state not in ["idle", "patrol", "hide"] and e.position.distance_to(stage.player.position) < 420.0:
			engaged = true
			break
	if engaged != _combat and (engaged or _combat_hold <= 0.0):
		_combat = engaged
		_combat_hold = 4.0
		Sfx.play_music("combat" if engaged else (stage.data.music if stage.data.music != "" else Defs.REGIONS[stage.data.region]["music"]))
	_combat_hold = maxf(_combat_hold - 0.5, 0.0)


var _combat_hold := 0.0


func _process(dt: float) -> void:
	_update_music(dt)
	if death_timer > 0.0 and Game.state == Game.State.PLAY:
		death_timer -= dt
		if death_timer <= 0.0:
			death_timer = -1.0
			Game.push_state(Game.State.GAMEOVER)
			menus.show_gameover()


func _on_retry() -> void:
	Game.pop_state()
	Game.set_state(Game.State.PLAY)
	stage.respawn_at_checkpoint()


func _on_boss_defeated(bid: String) -> void:
	if Game.trial:
		_finish_trial(bid)
		return
	var cut := ""
	match bid:
		"thorn_queen": cut = "reveal1"
		"clockwork_sovereign": cut = "reveal2"
		"eclipse_architect": cut = "finale"
	if cut != "":
		# let the defeat lines finish first, then the story beat
		await get_tree().create_timer(2.5, true).timeout
		if Game.state == Game.State.PLAY or Game.state == Game.State.DIALOGUE:
			cutscene.play(cut)


func _on_cutscene_finished(id: String) -> void:
	if id == "finale":
		cutscene.play("ending")
	elif id == "ending":
		_finish_game()


func _finish_game() -> void:
	Game.completed = true
	stage.autosave()
	var secs := int(Game.play_time)
	menus.show_victory("Time %dh %02dm    Deaths %d    Level %d    Quests %d" % [secs / 3600, (secs % 3600) / 60, Game.deaths, Game.level, Quests.count_done()])
	Game.set_state(Game.State.TITLE)


# ------------------------------------------------------------------ extras: New Game+, daily trial, tutorial, auto-pause
func _on_ngp(slot: int) -> void:
	var r := Save.load_slot(slot)
	if not r["ok"]:
		menus.show_title()
		return
	Game.deserialize(r["data"]["game"])
	Game.slot = slot
	Game.start_new_game_plus()
	Game.toast.emit("New Game+ %d: guardians and enemies are stronger." % Game.ngp, "good")
	Achievements.check()
	Save.write_slot(slot, Game.serialize())
	_start_play()


## Region and RNG seed for a given date; the same for every player on that day.
static func daily_seed(date: Dictionary) -> Dictionary:
	var day := int(date["year"]) * 400 + int(date["month"]) * 31 + int(date["day"])
	return {"region": Defs.REGION_ORDER[day % Defs.REGION_ORDER.size()], "seed": day, "key": "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]}


var trial_info: Dictionary = {}


func _on_daily() -> void:
	trial_info = daily_seed(Time.get_date_dict_from_system())
	var ri: int = Defs.REGION_ORDER.find(trial_info["region"])
	Game.new_progress()
	Game.trial = true
	for a in Game.ABILITY_NAMES:
		Game.unlock_ability(a)
	Game.level = 4 + ri * 2
	Game.skills = {"vitality": mini(ri, 4), "edge": mini(ri, 3), "crusher": mini(ri, 3)}
	Game.fragments = ri
	Game.full_restore()
	Game.play_time = 0.0
	Game.checkpoint = {"region": trial_info["region"], "level": str(trial_info["region"]) + "_boss", "id": "start"}
	menus.close_all()
	stage.visible = true
	Game.clear_state_stack()
	Game.set_state(Game.State.PLAY)
	stage.change_room(str(trial_info["region"]) + "_boss", "start")
	stage.rng.seed = int(trial_info["seed"])
	var best: Dictionary = Game.settings.get("daily", {})
	var line := "Daily Trial %s: %s" % [trial_info["key"], Defs.REGIONS[trial_info["region"]]["name"]]
	if best.get("date", "") == trial_info["key"]:
		line += "  (best %.1fs)" % float(best["best"])
	Game.toast.emit(line, "info")


func _finish_trial(bid: String) -> void:
	var secs := Game.play_time
	var best: Dictionary = Game.settings.get("daily", {})
	var prev: float = float(best["best"]) if best.get("date", "") == trial_info.get("key", "") else 1.0e9
	var text := "Time %.1fs, hits taken %d" % [secs, Game.run_hits]
	if secs < prev:
		Game.apply_setting("daily", {"date": trial_info["key"], "best": secs})
		text += "\nNew best for today!"
	else:
		text += "\nBest today: %.1fs" % prev
	Game.trial = false
	Game.flags["ach_daily"] = true
	Game.toast.emit("Achievement: Trial by Starlight", "good")
	await get_tree().create_timer(3.0, true).timeout
	menus.show_trial_result(text)


var _tut_running := false


func _tutorial() -> void:
	if _tut_running:
		return
	_tut_running = true
	var steps := [
		"Drag the left side of the screen to move. Tap JUMP; hold it to jump higher.",
		"Tap ATK three times in a row for a combo. HVY is a slow, strong swing.",
		"DODGE rolls through attacks. Watch enemies flash before they strike.",
		"MAGIC fires a bolt that aims at the nearest enemy. HEAL restores health.",
		"Touch a glowing Starshrine with USE to save and restore your health.",
	]
	for t in steps:
		await get_tree().create_timer(5.0, true).timeout
		if Game.state != Game.State.PLAY or Game.trial:
			break
		Game.toast.emit(t, "info")
	Game.set_flag("tut_done")
	_tut_running = false


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		auto_pause()


func auto_pause() -> void:
	if Game.state == Game.State.PLAY and not cutscene.active:
		Game.push_state(Game.State.PAUSE)
		menus.show_pause()
