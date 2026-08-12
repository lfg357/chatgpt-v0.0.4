class_name IndustrialRunState extends RefCounted

signal domain_event(kind: StringName, data: Dictionary)
enum RunPhase { ENTERING, ACTIVE, PAUSED, EXTRACTING, COMPLETED, FAILED, ABANDONED }
const CargoEntryValue = preload("res://src/domain/cargo_entry.gd")
const RunResultValue = preload("res://src/domain/run_result.gd")
const RouteSampleValue = preload("res://src/domain/route_sample.gd")
const COMBO_WINDOW := 2.5
const CARGO_CAPACITY := 100
const MINERALS := {
	&"ore_ferrite": {"hardness": 1.0, "scrap": 3, "data": 0},
	&"ore_copper_thread": {"hardness": 1.2, "scrap": 5, "data": 0},
	&"ore_lumen": {"hardness": 1.8, "scrap": 4, "data": 2}
}
var phase := RunPhase.ENTERING
var config: Resource
var topology_hash := ""
var run_id := ""
var elapsed := 0.0
var cargo_used := 0
var cargo: Dictionary = {}
var combo_id: StringName
var combo_streak := 0
var combo_remaining := 0.0
var damage_taken := 0
var overheat_count := 0
var emergency_collision_count := 0
var route_samples: Array[Resource] = []
var performance_summary: Dictionary = {}
var discoveries: Array[StringName] = []
var supply_claimed := false
var boiler := BoilerState.new()
var terminated_result: Resource

class BoilerState extends RefCounted:
	var active := false
	var completed := false
	var remaining := 45.0
	var reset_wait := 0.0
	var valves := [false, false, false]
	var valve_progress := [0.0, 0.0, 0.0]
	var timeout_pulses := 0
	func tick(delta: float) -> bool:
		if completed: return false
		if reset_wait > 0.0:
			reset_wait = maxf(0.0, reset_wait - delta)
			if reset_wait == 0.0: remaining = 45.0; valves = [false, false, false]; valve_progress = [0.0, 0.0, 0.0]; active = true
			return false
		if not active: return false
		remaining = maxf(0.0, remaining - delta)
		if remaining == 0.0: active = false; reset_wait = 5.0; timeout_pulses += 1; return true
		return false
	func interact_valve(index: int, delta: float) -> bool:
		if not active or completed or index < 0 or index >= 3 or valves[index]: return false
		valve_progress[index] += delta
		if valve_progress[index] >= 0.8:
			valves[index] = true
			if valves.all(func(value): return value): active = false; completed = true
			return true
		return false

func start(value: Resource, hash_value: String) -> void:
	config = value; topology_hash = hash_value
	run_id = "%d-%d-%s" % [Time.get_ticks_msec(), value.seed, hash_value.substr(0, 8)]
	phase = RunPhase.ACTIVE; domain_event.emit(&"run_start", {"seed": value.seed})

func tick(delta: float, paused: bool = false) -> void:
	if phase != RunPhase.ACTIVE or paused: return
	elapsed += delta; combo_remaining = maxf(0.0, combo_remaining - delta)
	if combo_remaining == 0.0: reset_combo()
	if boiler.tick(delta): damage(30, &"boiler_pulse")

func record_route(position: Vector2, aim_angle: float, flags: int = 0) -> void:
	var sample = RouteSampleValue.new()
	sample.time_ms = roundi(elapsed * 1000.0)
	sample.position = position
	sample.aim_angle = aim_angle
	sample.flags = flags
	route_samples.append(sample)

func collect(mineral_id: StringName, damaged: bool = false, near_live_cable: bool = false) -> bool:
	if phase != RunPhase.ACTIVE or not MINERALS.has(mineral_id) or cargo_used >= CARGO_CAPACITY: return false
	var value: Dictionary = MINERALS[mineral_id]
	var multiplier := 1.0
	if combo_id == mineral_id and combo_remaining > 0.0: combo_streak += 1; multiplier = 1.0 + minf(1.0, combo_streak * 0.1)
	else: combo_id = mineral_id; combo_streak = 0
	combo_remaining = COMBO_WINDOW
	var entry = cargo.get(mineral_id)
	if entry == null: entry = CargoEntryValue.new(); entry.mineral_id = mineral_id; cargo[mineral_id] = entry
	var scrap := int(round(float(value.scrap) * (1.2 if mineral_id == &"ore_copper_thread" and near_live_cable else 1.0) * multiplier))
	var data := int(value.data); data = floori(data * 0.5) if damaged and mineral_id == &"ore_lumen" else data
	entry.count += 1; entry.scrap_value += scrap; entry.data_value += data
	if damaged: entry.damaged_count += 1
	cargo_used += 1; domain_event.emit(&"mineral_mined", {"mineral_id": mineral_id, "damaged": damaged})
	return true

func combo_multiplier() -> float: return 1.0 + minf(1.0, combo_streak * 0.1)
func reset_combo() -> void: combo_id = &""; combo_streak = 0; combo_remaining = 0.0
func damage(amount: int, source: StringName = &"") -> void:
	if phase != RunPhase.ACTIVE: return
	damage_taken += amount; reset_combo(); domain_event.emit(&"damage_taken", {"amount": amount, "source": source})
func claim_supply(run_state: Variant, tools: Variant) -> bool:
	if supply_claimed: return false
	supply_claimed = true; run_state.durability = minf(100.0, run_state.durability + 30.0); tools.ammo = mini(2, tools.ammo + 1)
	tools.restore_beacon()
	return true
func discover(id: StringName) -> void:
	if not discoveries.has(id): discoveries.append(id); domain_event.emit(&"room_enter", {"discovery_id": id})
func finish(success: bool, reason: StringName = &""):
	if terminated_result != null: return terminated_result
	if not success and reason != &"destroyed" and reason != &"abandoned": return null
	phase = RunPhase.COMPLETED if success else RunPhase.FAILED if reason == &"destroyed" else RunPhase.ABANDONED
	var result = RunResultValue.new(); result.run_id = run_id; result.config = config; result.success = success; result.failure_reason = &"" if success else reason
	result.duration_ms = roundi(elapsed * 1000.0); result.damage_taken = damage_taken; result.overheat_count = overheat_count; result.emergency_collision_count = emergency_collision_count
	result.discovery_ids = discoveries.duplicate(); result.route_samples = route_samples.duplicate(); result.contract_progress = {}
	result.performance_summary = performance_summary.duplicate(true); result.performance_summary["cargo_used"] = cargo_used; result.topology_hash = topology_hash
	var ids := cargo.keys(); ids.sort()
	for id in ids: result.cargo.append(cargo[id].duplicate_entry())
	terminated_result = result; domain_event.emit(&"run_success" if success else &"run_failure" if reason == &"destroyed" else &"run_abandon", {})
	return result
