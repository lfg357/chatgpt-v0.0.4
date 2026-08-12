class_name ScrapMiteState extends RefCounted

enum State { CALM, ALERT, DISTURBED, RETREAT }
var state := State.CALM
var steal_clock := 0.0
var retreat_remaining := 0.0
var disturbed_remaining := 0.0
var carried_ids: Array[String] = []
func tick(delta: float, available_ids: Array[String], paused := false) -> String:
	if paused: return ""
	if state == State.DISTURBED:
		disturbed_remaining = maxf(0.0, disturbed_remaining - delta)
		if disturbed_remaining == 0.0: state = State.RETREAT
		return ""
	if state == State.RETREAT:
		retreat_remaining = maxf(0.0, retreat_remaining - delta)
		if retreat_remaining == 0.0: state = State.CALM
		return ""
	steal_clock += delta
	if steal_clock >= 2.0 and carried_ids.size() < 3 and not available_ids.is_empty():
		steal_clock -= 2.0; var id := available_ids[0]; carried_ids.append(id); state = State.ALERT; return id
	return ""
func disturb() -> void: state = State.DISTURBED; disturbed_remaining = 0.2; retreat_remaining = 6.0
func release_all() -> Array[String]: var result := carried_ids.duplicate(); carried_ids.clear(); return result
