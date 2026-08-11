extends Node

const ROOT := "user://profiles/"
const SETTINGS_ROOT := "user://settings/"
var active_snapshot: SaveSnapshot
var settings := AppSettings.new()

func _ready() -> void:
	load_settings()

func load_profile(slot: int) -> Result:
	if slot < 0 or slot > 2: return Result.failure(&"invalid_slot")
	var path := ROOT + "slot_%d/save.json" % slot
	var loaded := _load_envelope(path)
	if loaded.ok:
		active_snapshot = SaveSnapshot.from_dict(loaded.data)
		return loaded
	var backup := _load_envelope(ROOT + "slot_%d/save.bak.json" % slot)
	if backup.ok:
		active_snapshot = SaveSnapshot.from_dict(backup.data)
		return backup
	active_snapshot = SaveSnapshot.new(); active_snapshot.profile_id = slot; active_snapshot.created_unix = Time.get_unix_time_from_system()
	return Result.success(active_snapshot)

func save_profile(slot: int, _reason: StringName) -> Result:
	if active_snapshot == null or active_snapshot.profile_id != slot: return Result.failure(&"no_active_profile")
	active_snapshot.updated_unix = Time.get_unix_time_from_system()
	return _atomic_write(ROOT + "slot_%d/save.json" % slot, active_snapshot.to_dict())

func load_settings() -> Result:
	var loaded := _load_envelope(SETTINGS_ROOT + "settings.json")
	if loaded.ok:
		for key in settings.to_dict().keys(): if loaded.data.has(key): settings.set(key, loaded.data[key])
	return loaded

func save_settings() -> Result: return _atomic_write(SETTINGS_ROOT + "settings.json", settings.to_dict())

func _load_envelope(path: String) -> Result:
	if not FileAccess.file_exists(path): return Result.failure(&"not_found")
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("payload") or not parsed.has("payload_sha256"): return Result.failure(&"corrupt")
	var payload_text := JSON.stringify(parsed.payload)
	if payload_text.sha256_text() != parsed.payload_sha256: return Result.failure(&"checksum_mismatch")
	return Result.success(parsed.payload)

func _atomic_write(path: String, payload: Dictionary) -> Result:
	var directory := path.get_base_dir(); DirAccess.make_dir_recursive_absolute(directory)
	var tmp := path.replace(".json", ".tmp.json")
	var envelope := {"schema_version": 1, "content_version": 1, "payload": payload, "payload_sha256": JSON.stringify(payload).sha256_text()}
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null: return Result.failure(&"write_failed")
	file.store_string(JSON.stringify(envelope)); file.close()
	if not _load_envelope(tmp).ok: return Result.failure(&"temp_validation_failed")
	if FileAccess.file_exists(path): DirAccess.copy_absolute(path, path.replace(".json", ".bak.json"))
	var err := DirAccess.rename_absolute(tmp, path)
	return Result.success() if err == OK else Result.failure(&"replace_failed")
