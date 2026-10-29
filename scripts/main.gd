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
	menus.quit_app.connect(func() -> void: get_tree().quit())
	stage.player_died.connect(_on_player_died)
	stage.boss_defeated.connect(_on_boss_defeated)
	stage.request_cutscene.connect(func(id: String) -> void: cutscene.play(id))
	cutscene.finished.connect(_on_cutscene_finished)
	Game.apply_setting("master", Game.settings["master"])
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
	if Game.state != Game.State.TITLE and stage.data != null:
		stage.autosave()
	_to_title()


func _on_player_died() -> void:
	Game.deaths += 1
	death_timer = 1.6
	Game.toast.emit("Kael falls...", "bad")
	Sfx.play("defeat")


func _process(dt: float) -> void:
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
