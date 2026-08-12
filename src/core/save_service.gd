extends Node

const AppSettingsValue = preload("res://src/core/app_settings.gd")
const ResultValue = preload("res://src/core/result.gd")
const SaveSnapshotValue = preload("res://src/core/save_snapshot.gd")

const ROOT := "user://profiles/"
const SETTINGS_ROOT := "user://settings/"
var active_snapshot: SaveSnapshotValue
var settings := AppSettingsValue.new()
var fail_next_profile_save := false

func _ready() -> void:
	load_settings()

func load_profile(slot: int) -> ResultValue:
	if slot < 0 or slot > 2: return ResultValue.failure(&"invalid_slot")
	var path := ROOT + "slot_%d/save.json" % slot
	var loaded := _load_envelope(path)
	if loaded.ok:
		active_snapshot = SaveSnapshotValue.from_dict(loaded.data)
		return loaded
	var backup := _load_envelope(ROOT + "slot_%d/save.bak.json" % slot)
	if backup.ok:
		active_snapshot = SaveSnapshotValue.from_dict(backup.data)
		return backup
	active_snapshot = SaveSnapshotValue.new(); active_snapshot.profile_id = slot; active_snapshot.created_unix = Time.get_unix_time_from_system()
	return ResultValue.success(active_snapshot)

func save_profile(slot: int, _reason: StringName) -> ResultValue:
	if fail_next_profile_save:
		fail_next_profile_save = false
		return ResultValue.failure(&"injected_save_failure")
	if active_snapshot == null or active_snapshot.profile_id != slot: return ResultValue.failure(&"no_active_profile")
	active_snapshot.updated_unix = Time.get_unix_time_from_system()
	return _atomic_write(ROOT + "slot_%d/save.json" % slot, active_snapshot.to_dict())

func load_settings() -> ResultValue:
	var loaded := _load_envelope(SETTINGS_ROOT + "settings.json")
	if loaded.ok:
		for key in settings.to_dict().keys(): if loaded.data.has(key): settings.set(key, loaded.data[key])
	return loaded

func save_settings() -> ResultValue: return _atomic_write(SETTINGS_ROOT + "settings.json", settings.to_dict())

func _load_envelope(path: String) -> ResultValue:
	if not FileAccess.file_exists(path): return ResultValue.failure(&"not_found")
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("payload") or not parsed.has("payload_sha256"): return ResultValue.failure(&"corrupt")
	var payload_text := _canonical_payload_text(parsed.payload)
	var legacy_text := JSON.stringify(parsed.payload)
	if payload_text.sha256_text() != parsed.payload_sha256 and legacy_text.sha256_text() != parsed.payload_sha256: return ResultValue.failure(&"checksum_mismatch")
	return ResultValue.success(parsed.payload)

func _atomic_write(path: String, payload: Dictionary) -> ResultValue:
	var directory := path.get_base_dir(); DirAccess.make_dir_recursive_absolute(directory)
	var tmp := path.replace(".json", ".tmp.json")
	var backup := path.replace(".json", ".bak.json")
	var directory_access := DirAccess.open(directory)
	if directory_access == null: return ResultValue.failure(&"directory_open_failed")
	var target_name := path.get_file(); var tmp_name := tmp.get_file(); var backup_name := backup.get_file()
	var normalized_payload: Variant = JSON.parse_string(JSON.stringify(payload))
	var envelope := {"schema_version": 1, "content_version": 1, "payload": normalized_payload, "payload_sha256": _canonical_payload_text(normalized_payload).sha256_text()}
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null: return ResultValue.failure(&"write_failed")
	file.store_string(JSON.stringify(envelope)); file.close()
	if not _load_envelope(tmp).ok: return ResultValue.failure(&"temp_validation_failed")
	var moved_previous := false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup): directory_access.remove(backup_name)
		if directory_access.rename(target_name, backup_name) != OK: return ResultValue.failure(&"backup_failed")
		moved_previous = true
	var err := directory_access.rename(tmp_name, target_name)
	if err != OK:
		if moved_previous: directory_access.rename(backup_name, target_name)
		return ResultValue.failure(&"replace_failed")
	return ResultValue.success()

func _canonical_payload_text(payload: Variant) -> String:
	# JSON parsing normalizes all numbers. Hashing the normalized representation
	# makes write/read checks stable for integer-valued resource dictionaries.
	return JSON.stringify(JSON.parse_string(JSON.stringify(payload)), "", true)
