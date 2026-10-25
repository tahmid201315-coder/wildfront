extends Node
## Versioned, crash-safe local saves (autoload "Save").
## Write path: serialize -> write save.tmp -> read back & validate -> rotate current to save.bak -> rename tmp to save.json.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const BAK_PATH := "user://save.bak"
const SETTINGS_PATH := "user://settings.json"

const REQUIRED_KEYS := {"save_version": TYPE_INT, "game": TYPE_DICTIONARY, "inventory": TYPE_ARRAY,
	"quests": TYPE_DICTIONARY, "world": TYPE_DICTIONARY}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BAK_PATH)


## Returns "" when valid, otherwise the reason.
func validate(d: Variant) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return "root is not a dictionary"
	for k in REQUIRED_KEYS:
		if not d.has(k):
			return "missing key " + k
		var want: int = REQUIRED_KEYS[k]
		var got := typeof(d[k])
		if want == TYPE_INT and got == TYPE_FLOAT:
			continue
		if got != want:
			return "wrong type for " + k
	if int(d["save_version"]) < 1 or int(d["save_version"]) > Data.SAVE_VERSION:
		return "unsupported save_version %s" % str(d["save_version"])
	return ""


## Upgrade older save layouts. Version 1 is current; add steps here for future versions.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("save_version", 1))
	# Example for future: if v < 2: d["world"]["new_key"] = ...; v = 2
	d["save_version"] = maxi(v, 1)
	return d


func _read_file(path: String) -> Dictionary:
	## returns {ok: bool, data: Dictionary, error: String}
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "data": {}, "error": "cannot open (%s)" % error_string(FileAccess.get_open_error())}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	var why := validate(parsed)
	if why != "":
		return {"ok": false, "data": {}, "error": why}
	return {"ok": true, "data": migrate(parsed), "error": ""}


## Load the best available save. result: {ok, data, restored_backup, message}
func load_game() -> Dictionary:
	var main := _read_file(SAVE_PATH)
	if main["ok"]:
		return {"ok": true, "data": main["data"], "restored_backup": false, "message": ""}
	var bak := _read_file(BAK_PATH)
	if bak["ok"]:
		push_warning("Main save invalid (%s); restored backup." % main["error"])
		return {"ok": true, "data": bak["data"], "restored_backup": true,
			"message": "Your latest save was damaged, so the previous backup was loaded."}
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BAK_PATH):
		return {"ok": false, "data": {}, "restored_backup": false,
			"message": "Save data is damaged and no backup could be read (%s). Start a New Game to continue." % main["error"]}
	return {"ok": false, "data": {}, "restored_backup": false, "message": "No saved game found."}


func write_game(payload: Dictionary) -> bool:
	payload["save_version"] = Data.SAVE_VERSION
	payload["saved_unix"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(payload)
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Save: cannot open temp file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	# Verify the temp file before it replaces anything valid.
	var check := _read_file(TMP_PATH)
	if not check["ok"]:
		push_error("Save: temp file failed validation (%s); keeping old save." % check["error"])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BAK_PATH):
			dir.remove("save.bak")
		dir.rename("save.json", "save.bak")
	var err := dir.rename("save.tmp", "save.json")
	if err != OK:
		push_error("Save: rename failed (%s)" % error_string(err))
		# Try to put the backup back so a valid save still exists.
		if not FileAccess.file_exists(SAVE_PATH) and FileAccess.file_exists(BAK_PATH):
			dir.rename("save.bak", "save.json")
		return false
	return true


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for f in ["save.json", "save.bak", "save.tmp"]:
		if dir.file_exists(f):
			dir.remove(f)


func save_settings(s: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write settings")
		return
	f.store_string(JSON.stringify(s))
	f.close()


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
