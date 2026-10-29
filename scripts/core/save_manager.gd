extends Node
## Three save slots with atomic writes, a rolling backup, validation and versioning.
## Files: user://save_N.json, user://save_N.bak, user://save_N.tmp. Settings: user://settings.json.

const SLOTS := 3
const SETTINGS_PATH := "user://settings.json"
const REQUIRED := {"save_version": TYPE_INT, "game": TYPE_DICTIONARY}

var base_dir: String = "user://"   # tests may point this elsewhere


func path(slot: int, ext: String) -> String:
	return "%ssave_%d.%s" % [base_dir, slot, ext]


func validate(d: Variant) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "root is not a dictionary"
	for k in REQUIRED:
		if not d.has(k):
			return "missing key " + k
		var got := typeof(d[k])
		if got == TYPE_FLOAT and REQUIRED[k] == TYPE_INT:
			continue
		if got != REQUIRED[k]:
			return "wrong type for " + k
	if int(d["save_version"]) < 1 or int(d["save_version"]) > Game.SAVE_VERSION:
		return "unsupported save_version %s" % str(d["save_version"])
	return ""


func migrate(d: Dictionary) -> Dictionary:
	# Version 1 is current. Future layouts get an upgrade step here.
	d["save_version"] = maxi(int(d.get("save_version", 1)), 1)
	return d


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"ok": false, "error": "missing"}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "cannot open"}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	var why := validate(parsed)
	if why != "":
		return {"ok": false, "error": why}
	return {"ok": true, "data": migrate(parsed)}


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot, "json")) or FileAccess.file_exists(path(slot, "bak"))


## Returns {ok, data, message, restored_backup}
func load_slot(slot: int) -> Dictionary:
	var main := _read(path(slot, "json"))
	if main["ok"]:
		return {"ok": true, "data": main["data"], "message": "", "restored_backup": false}
	var bak := _read(path(slot, "bak"))
	if bak["ok"]:
		return {"ok": true, "data": bak["data"], "message": "Your latest save was damaged; the previous backup was loaded.", "restored_backup": true}
	if slot_exists(slot):
		return {"ok": false, "data": {}, "message": "This save is damaged and no backup could be read (%s)." % main["error"], "restored_backup": false}
	return {"ok": false, "data": {}, "message": "Empty slot.", "restored_backup": false}


func write_slot(slot: int, game_data: Dictionary) -> bool:
	var payload := {"save_version": Game.SAVE_VERSION, "saved_unix": Time.get_unix_time_from_system(), "game": game_data}
	var f := FileAccess.open(path(slot, "tmp"), FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot open temp file")
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	var check := _read(path(slot, "tmp"))
	if not check["ok"]:
		push_error("Save: temp file failed validation (%s); keeping old save." % check["error"])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot, "tmp")))
		return false
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return false
	var jn := "save_%d.json" % slot
	var bn := "save_%d.bak" % slot
	if FileAccess.file_exists(path(slot, "json")):
		if FileAccess.file_exists(path(slot, "bak")):
			dir.remove(bn)
		dir.rename(jn, bn)
	var err := dir.rename("save_%d.tmp" % slot, jn)
	if err != OK:
		if not FileAccess.file_exists(path(slot, "json")) and FileAccess.file_exists(path(slot, "bak")):
			dir.rename(bn, jn)
		return false
	return true


func delete_slot(slot: int) -> void:
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return
	for ext in ["json", "bak", "tmp"]:
		var n := "save_%d.%s" % [slot, ext]
		if dir.file_exists(n):
			dir.remove(n)


## Short description for the slot picker: {exists, summary}
func slot_info(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"exists": false, "summary": "Empty"}
	var r := load_slot(slot)
	if not r["ok"]:
		return {"exists": true, "summary": "Damaged save"}
	var g: Dictionary = r["data"]["game"]
	var secs := int(float(g.get("play_time", 0.0)))
	return {"exists": true, "completed": bool(g.get("completed", false)), "ngp": int(g.get("ngp", 0)), "summary": "%s%d/7 fragments   %dh %02dm%s" % [("NG+%d  " % int(g.get("ngp", 0)) if int(g.get("ngp", 0)) > 0 else ""), int(g.get("fragments", 0)), secs / 3600, (secs % 3600) / 60, "   Completed" if bool(g.get("completed", false)) else ""]}


func save_settings(s: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(s))
	f.close()


func load_settings(defaults: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return out
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return out
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		for k in defaults:
			if parsed.has(k) and typeof(parsed[k]) == typeof(defaults[k]):
				out[k] = parsed[k]
			elif parsed.has(k) and typeof(defaults[k]) == TYPE_FLOAT and typeof(parsed[k]) == TYPE_INT:
				out[k] = float(parsed[k])
	return out


## Save sharing: a slot as one line of text (for the clipboard) and the reverse, fully validated.
func export_text(slot: int) -> String:
	var r := load_slot(slot)
	if not r["ok"]:
		return ""
	return "STARFALL1:" + Marshalls.utf8_to_base64(JSON.stringify(r["data"]))


## Returns {ok, message}. Never writes anything unless the text is a valid save.
func import_text(slot: int, text: String) -> Dictionary:
	var t := text.strip_edges()
	if not t.begins_with("STARFALL1:"):
		return {"ok": false, "message": "That is not a Starfall save code."}
	var raw := Marshalls.base64_to_utf8(t.substr(10))
	if raw == "":
		return {"ok": false, "message": "The save code is damaged."}
	var json := JSON.new()
	if json.parse(raw) != OK:
		return {"ok": false, "message": "The save code is damaged."}
	var err := validate(json.data)
	if err != "":
		return {"ok": false, "message": "The save code is invalid (%s)." % err}
	if not write_slot(slot, json.data["game"]):
		return {"ok": false, "message": "Could not write the save."}
	return {"ok": true, "message": "Save imported into slot %d." % (slot + 1)}
