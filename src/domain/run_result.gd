class_name RunResult extends Resource

var run_id: String
var config: Resource
var success: bool
var failure_reason: StringName
var duration_ms: int
var cargo: Array[Resource] = []
var damage_taken: int
var overheat_count: int
var emergency_collision_count: int
var discovery_ids: Array[StringName] = []
var route_samples: Array[Resource] = []
var contract_progress: Dictionary = {}
var performance_summary: Dictionary = {}
var topology_hash: String

