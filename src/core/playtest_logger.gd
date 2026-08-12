class_name PlaytestLogger extends RefCounted

const PATH := "user://playtest_events.jsonl"
static func record(kind: StringName, data: Dictionary = {}) -> bool:
	var event := {"event_version": 1, "event": String(kind), "unix": Time.get_unix_time_from_system(), "game_version": "0.0.4", "data": _sanitize(data)}
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if file == null: file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null: return false
	file.seek_end(); file.store_line(JSON.stringify(event)); file.close(); return true
static func _sanitize(data: Dictionary) -> Dictionary:
	var result := {}
	for key in data:
		if String(key) in ["username", "system_path", "network_id"]: continue
		result[key] = data[key]
	return result
