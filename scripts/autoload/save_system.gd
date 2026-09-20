## Versioned save/load to user:// as a single JSON blob.
extends Node

const SAVE_PATH := "user://bnnuy_save.json"
const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 15.0

var _autosave_accum := 0.0
var _loaded_at_least_once := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	# Covers desktop window close and browser tab close alike.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": Game.to_save(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: could not open %s for writing (%s)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(payload))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_loaded_at_least_once = true
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("SaveSystem: could not read %s" % SAVE_PATH)
		return
	var text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_error("SaveSystem: save file is corrupt, ignoring it")
		return

	var data: Dictionary = parsed
	data = _migrate(data)
	Game.from_save(data.get("game", {}))

	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at > 0.0:
		var elapsed := Time.get_unix_time_from_system() - saved_at
		# Backwards clock must not grant time.
		if elapsed > 0.0:
			Game.queue_offline(elapsed)

	_loaded_at_least_once = true
	Events.game_loaded.emit()


## Upgrades old saves in place; each version bump adds a step.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v > SAVE_VERSION:
		push_warning("SaveSystem: save is from a newer build (v%d > v%d)" % [v, SAVE_VERSION])
	# v0 -> v1: nothing to do yet.
	data["version"] = SAVE_VERSION
	return data


func wipe() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
