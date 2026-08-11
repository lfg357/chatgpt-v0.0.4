class_name SaveSnapshot extends RefCounted

var schema_version: int = 1
var content_version: int = 1
var profile_id: int = 0
var created_unix: int = 0
var updated_unix: int = 0
var economy: Dictionary = {"scrap": 0, "core": 0, "data": 0, "chronoshard": 0}
var unlocks: Dictionary = {"layer_ids": [], "blueprint_ids": [], "relic_ids": [], "law_ids": []}
var facilities: Dictionary = {}
var modules: Dictionary = {}
var echoes: Array[Dictionary] = []
var timeline: Dictionary = {"index": 0, "active_law_id": "", "pending_law_choice": false, "pending_law_options": [], "pinned_echo_ids": [], "total_resets": 0}
var archives: Array[StringName] = []
var tutorial: Dictionary = {"completed_step_ids": [], "skipped": false}
var statistics: Dictionary = {"total_runs": 0, "successful_runs": 0, "failed_runs": 0, "total_dive_seconds": 0, "deepest_layer_id": "", "resources_mined": {}, "archives_found": 0}

func to_dict() -> Dictionary:
	return {"schema_version": schema_version, "content_version": content_version, "profile_id": profile_id, "created_unix": created_unix, "updated_unix": updated_unix, "economy": economy, "unlocks": unlocks, "facilities": facilities, "modules": modules, "echoes": echoes, "timeline": timeline, "archives": archives, "tutorial": tutorial, "statistics": statistics}

static func from_dict(value: Dictionary) -> SaveSnapshot:
	var snapshot := SaveSnapshot.new()
	for key in snapshot.to_dict().keys():
		if value.has(key): snapshot.set(key, value[key])
	return snapshot
