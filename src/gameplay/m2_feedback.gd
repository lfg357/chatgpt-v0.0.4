class_name M2Feedback extends Node2D

@export var rig_path: NodePath
var rig: Node
var sonar_phase := 0.0
var drill_hits: Array[Dictionary] = []
var _sprite_recovery := 0.0
var drill_contact_active := false
var drill_contact_point := Vector2.ZERO
var drill_contact_direction := Vector2.RIGHT

const HIT_LIFETIME := 0.22
const MAX_DRILL_HITS := 12

func _ready() -> void:
	rig = get_node_or_null(rig_path)
	queue_redraw()

func _process(delta: float) -> void:
	if rig == null: return
	sonar_phase += delta
	for hit in drill_hits:
		hit.age += delta
	drill_hits = drill_hits.filter(func(hit: Dictionary) -> bool: return hit.age < HIT_LIFETIME)
	_sprite_recovery = minf(1.0, _sprite_recovery + delta * 18.0)
	if rig.has_node("Sprite"):
		rig.get_node("Sprite").position = rig.get_node("Sprite").position.lerp(Vector2.ZERO, _sprite_recovery)
	queue_redraw()

func on_drill_hit(point: Vector2, direction: Vector2, strength: int = 1) -> void:
	if drill_hits.size() >= MAX_DRILL_HITS: drill_hits.pop_front()
	drill_hits.append({"point": point, "direction": direction.normalized(), "strength": strength, "age": 0.0})
	_sprite_recovery = 0.0

func set_drill_contact(point: Vector2, direction: Vector2, active: bool) -> void:
	drill_contact_point = point
	drill_contact_direction = direction.normalized()
	drill_contact_active = active

func _draw() -> void:
	if rig == null: return
	var aim: Vector2 = rig.state.last_aim.normalized()
	var tip: Vector2 = rig.global_position + aim * 22.0
	draw_line(rig.global_position + aim * 10.0, tip, Color("f2d36b"), 1.0)
	draw_circle(tip, 2.0, Color("fff2bd"), false, 1.0)
	for beacon in rig.tools.beacons:
		draw_colored_polygon(PackedVector2Array([beacon + Vector2(0, -7), beacon + Vector2(5, 0), beacon + Vector2(0, 7), beacon + Vector2(-5, 0)]), Color("73d1c8"))
	for pin in rig.tools.blast_pins:
		var point: Vector2 = rig.terrain.to_global(Vector2(pin) * float(rig.terrain.cell_size) + Vector2.ONE * float(rig.terrain.cell_size) * 0.5)
		draw_circle(point, 4.0, Color("d85b6a"))
	if rig.tools.sonar_seconds > 0.0:
		var radius := fmod(sonar_phase * 100.0, 96.0)
		draw_arc(rig.global_position, radius, 0.0, TAU, 48, Color("73d1c8", rig.tools.sonar_seconds * 0.45), 1.5)
	for hit in drill_hits:
		_draw_drill_hit(hit)
	if drill_contact_active:
		_draw_active_drill_contact()

func _draw_active_drill_contact() -> void:
	var direction := drill_contact_direction
	var side := Vector2(-direction.y, direction.x)
	var pulse := 0.55 + sin(sonar_phase * 42.0) * 0.25
	var point := drill_contact_point
	# This is deliberately larger than a single tile: it remains readable at 720p
	# while the player holds the drill against a wall.
	draw_line(point - direction * 18.0, point + direction * 2.0, Color("f7b85b", 0.78), 2.5)
	draw_circle(point, 7.0 + pulse * 3.0, Color("ffcb6d", 0.16))
	draw_arc(point, 12.0, direction.angle() - 1.05, direction.angle() + 1.05, 12, Color("fff0b6", 0.95), 2.0)
	for i in range(6):
		var angle := direction.angle() + PI + (float(i) - 2.5) * 0.30 + sin(sonar_phase * 18.0 + i) * 0.12
		var ray := Vector2.RIGHT.rotated(angle)
		var start := point + ray * 3.0
		var end := start + ray * (7.0 + fmod(sonar_phase * 20.0 + i * 3.0, 7.0))
		draw_line(start, end, Color("ffd776", 0.9), 1.5)
		draw_circle(end, 1.7, Color("fff1b3", 0.95))
	# Dense dust cone makes continuous removal of rock legible even between commits.
	for i in range(4):
		var dust := point - direction * (9.0 + i * 4.0) + side * sin(sonar_phase * 9.0 + i) * (2.0 + i)
		draw_circle(dust, 2.5 + i, Color("7f94a1", 0.28 - i * 0.04))

func _draw_drill_hit(hit: Dictionary) -> void:
	var progress: float = clampf(float(hit.age) / HIT_LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - progress
	var point: Vector2 = hit.point
	var direction: Vector2 = hit.direction
	var side := Vector2(-direction.y, direction.x)
	# Bright contact flash is the immediate confirmation that the drill bit found rock.
	draw_circle(point, lerpf(8.0, 2.0, progress), Color("fff1a8", alpha * 0.95))
	draw_arc(point, 12.0 + progress * 10.0, direction.angle() - 0.85, direction.angle() + 0.85, 10, Color("f2a75e", alpha), 2.0)
	# Four deterministic fragments and a dust puff: readable at pixel scale without allocating nodes.
	for i in range(4):
		var spread := (float(i) - 1.5) * 0.45
		var fragment := point - direction * (7.0 + progress * (15.0 + i * 2.0)) + side.rotated(spread) * (float(i) - 1.5) * (3.0 + progress * 5.0)
		draw_rect(Rect2(fragment - Vector2(2, 2), Vector2(4.0, 4.0)), Color("a8bac8", alpha * 0.9))
	var dust := point - direction * (3.0 + progress * 13.0)
	draw_circle(dust, 3.0 + progress * 5.0, Color("8fa0ab", alpha * 0.22))
