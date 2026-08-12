class_name M2Tools extends RefCounted

const BLAST_RADIUS_CELLS := 4
const BLAST_CELL_CAP := 48
const SONAR_DURATION := 2.0
const SONAR_COOLDOWN := 5.0
const BEACON_LIMIT := 3
const RECALL_SECONDS := 1.5

var blast_pins: Array[Vector2i] = []
var ammo := 2
var sonar_seconds := 0.0
var sonar_cooldown := 0.0
var beacons: Array[Vector2] = []
var recall_seconds := 0.0

func tick(delta: float, recalling: bool, paused: bool) -> bool:
	if paused: return false
	sonar_seconds = maxf(0.0, sonar_seconds - delta)
	sonar_cooldown = maxf(0.0, sonar_cooldown - delta)
	recall_seconds = recall_seconds + delta if recalling else 0.0
	return recall_seconds >= RECALL_SECONDS

func place_pin(cell: Vector2i) -> bool:
	if ammo <= 0: return false
	blast_pins.append(cell); ammo -= 1; return true

func detonate(terrain: Variant) -> int:
	var changed := 0
	var candidates: Array[Dictionary] = []
	for pin in blast_pins:
		for y in range(pin.y - BLAST_RADIUS_CELLS, pin.y + BLAST_RADIUS_CELLS + 1):
			for x in range(pin.x - BLAST_RADIUS_CELLS, pin.x + BLAST_RADIUS_CELLS + 1):
				var cell := Vector2i(x, y)
				var distance := cell.distance_squared_to(pin)
				if distance <= BLAST_RADIUS_CELLS * BLAST_RADIUS_CELLS: candidates.append({"cell": cell, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.distance < b.distance)
	var requested: Dictionary = {}
	for candidate in candidates:
		if changed >= BLAST_CELL_CAP: break
		var cell: Vector2i = candidate.cell
		if not requested.has(cell) and terrain.request_damage(cell): requested[cell] = true; changed += 1
	blast_pins.clear()
	return changed

func activate_sonar() -> bool:
	if sonar_cooldown > 0.0: return false
	sonar_seconds = SONAR_DURATION; sonar_cooldown = SONAR_COOLDOWN; return true

func place_beacon(position: Vector2) -> void:
	if beacons.size() >= BEACON_LIMIT: beacons.pop_front()
	beacons.append(position)
