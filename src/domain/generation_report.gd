class_name GenerationReport extends RefCounted

var valid: bool = false
var error_codes: Array[StringName] = []
var reachable_required_nodes: int = 0
var required_nodes: int = 0
var hazard_budget: int = 0
var retry_count: int = 0
var generation_time_ms: float = 0.0
var used_fallback: bool = false
