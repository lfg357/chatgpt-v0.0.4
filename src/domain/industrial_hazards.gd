class_name IndustrialHazards extends RefCounted

class SteamVent extends RefCounted:
	enum State { IDLE, WARNING, FIRING }
	var state := State.IDLE; var clock := 0.0; var hit_targets: Dictionary = {}
	func tick(delta: float, paused := false) -> void:
		if paused: return
		clock = fmod(clock + delta, 4.0); state = State.WARNING if clock >= 1.5 and clock < 3.0 else State.FIRING if clock >= 3.0 else State.IDLE
		if state != State.FIRING: hit_targets.clear()
	func try_hit(target_id: int) -> int:
		if state != State.FIRING or hit_targets.has(target_id): return 0
		hit_targets[target_id] = true; return 15
class LiveCable extends RefCounted:
	var active := true; var damage_clock := 0.0; var drill_progress := 0.0
	func tick(delta: float, in_range: bool, paused := false) -> int:
		if paused or not active: return 0
		if not in_range: damage_clock = 0.0; return 0
		damage_clock += delta; var ticks := floori(damage_clock / 0.5); damage_clock -= ticks * 0.5; return ticks * 4
	func drill_power(delta: float) -> bool: drill_progress += delta; active = drill_progress < 1.5; return not active
	func blast_power() -> void: active = false
class CollapseShale extends RefCounted:
	enum State { SUPPORTED, WAITING, FALLING, LANDED }
	var state := State.SUPPORTED; var delay := 0.0; var velocity := 0.0
	func remove_support() -> void: if state == State.SUPPORTED: state = State.WAITING
	func tick(delta: float, paused := false) -> void:
		if paused: return
		if state == State.WAITING: delay += delta; state = State.FALLING if delay >= 0.6 else State.WAITING
		elif state == State.FALLING: velocity = minf(180.0, velocity + 360.0 * delta)
	func land() -> void: state = State.LANDED; velocity = 0.0

