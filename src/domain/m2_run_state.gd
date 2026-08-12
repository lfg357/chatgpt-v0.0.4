class_name M2RunState extends RefCounted

signal threshold_reached(level: int)
signal shutdown_started()
signal run_failed()

const MAX_VALUE := 100.0
const THRUST_ACCEL := 520.0
const MAX_SPEED := 150.0
const GRAVITY := 280.0
const MAX_FALL_SPEED := 220.0
const BOOST_SPEED := 260.0
const BOOST_DURATION := 0.35
const BOOST_COOLDOWN := 1.2
const BOOST_COST := 18.0
const THRUST_ENERGY_PER_SECOND := 6.0
const ENERGY_RECOVERY_DELAY := 0.75
const ENERGY_RECOVERY_PER_SECOND := 12.0
const DRILL_HEAT_PER_SECOND := 12.0
const BOOST_HEAT_PER_SECOND := 20.0
const COOL_PER_SECOND := 18.0
const SHUTDOWN_SECONDS := 2.0

var durability := MAX_VALUE
var energy := MAX_VALUE
var heat := 0.0
var run_seconds := 0.0
var no_energy_action_seconds := 0.0
var boost_seconds := 0.0
var boost_cooldown_seconds := 0.0
var shutdown_seconds := 0.0
var failed := false
var last_aim := Vector2.RIGHT

func tick(delta: float, frame: Variant, paused: bool = false) -> Dictionary:
	var result := {"drilling": false, "boosting": false, "move_scale": 1.0}
	if paused or failed:
		return result
	run_seconds += delta
	if frame.aim.length() >= 0.001:
		last_aim = frame.aim.normalized()
	boost_cooldown_seconds = maxf(0.0, boost_cooldown_seconds - delta)
	shutdown_seconds = maxf(0.0, shutdown_seconds - delta)
	if frame.has_pressed(4) and boost_cooldown_seconds <= 0.0 and energy >= BOOST_COST:
		energy -= BOOST_COST
		boost_seconds = BOOST_DURATION
		boost_cooldown_seconds = BOOST_COOLDOWN
	if boost_seconds > 0.0:
		boost_seconds = maxf(0.0, boost_seconds - delta)
		result.boosting = true
		result.move_scale = BOOST_SPEED / MAX_SPEED
		_heat(delta, BOOST_HEAT_PER_SECOND)
	var drilling: bool = frame.has_held(1) and shutdown_seconds <= 0.0
	result.drilling = drilling
	var consuming: bool = frame.move.length_squared() > 0.001 or bool(result.boosting)
	if consuming:
		energy = maxf(0.0, energy - THRUST_ENERGY_PER_SECOND * delta)
		no_energy_action_seconds = 0.0
	else:
		no_energy_action_seconds += delta
		if no_energy_action_seconds >= ENERGY_RECOVERY_DELAY:
			energy = minf(MAX_VALUE, energy + ENERGY_RECOVERY_PER_SECOND * delta)
	if drilling:
		_heat(delta, DRILL_HEAT_PER_SECOND)
	else:
		heat = maxf(0.0, heat - COOL_PER_SECOND * delta)
	if shutdown_seconds > 0.0:
		result.move_scale = minf(result.move_scale, 0.45)
	return result

func damage(amount: float) -> void:
	durability = clampf(durability - amount, 0.0, MAX_VALUE)
	if durability <= 0.0 and not failed:
		failed = true
		run_failed.emit()

func _heat(delta: float, rate: float) -> void:
	var old := heat
	heat = minf(MAX_VALUE, heat + rate * delta)
	for level in [70.0, 85.0, 100.0]:
		if old < level and heat >= level:
			threshold_reached.emit(int(level))
	if heat >= MAX_VALUE and shutdown_seconds <= 0.0:
		shutdown_seconds = SHUTDOWN_SECONDS
		shutdown_started.emit()
