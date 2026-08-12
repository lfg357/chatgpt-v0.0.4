class_name M2Feedback extends Node2D

@export var rig_path: NodePath
var rig: Node
var sonar_phase := 0.0
var drill_hits: Array[Dictionary] = []
var _sprite_recovery := 0.0

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

func _draw_drill_hit(hit: Dictionary) -> void:
	var progress: float = clampf(float(hit.age) / HIT_LIFETIME, 0.0, 1.0)
	var alpha := 1.0 - progress
	var point: Vector2 = hit.point
	var direction: Vector2 = hit.direction
	var side := Vector2(-direction.y, direction.x)
	# Bright contact flash is the immediate confirmation that the drill bit found rock.
	draw_circle(point, lerpf(4.0, 1.0, progress), Color("fff1a8", alpha * 0.9))
	draw_arc(point, 7.0 + progress * 7.0, direction.angle() - 0.75, direction.angle() + 0.75, 8, Color("f2a75e", alpha), 1.4)
	# Four deterministic fragments and a dust puff: readable at pixel scale without allocating nodes.
	for i in range(4):
		var spread := (float(i) - 1.5) * 0.45
		var fragment := point - direction * (5.0 + progress * (8.0 + i)) + side.rotated(spread) * (float(i) - 1.5) * (2.0 + progress * 3.0)
		draw_rect(Rect2(fragment - Vector2.ONE, Vector2(2.0, 2.0)), Color("a8bac8", alpha * 0.9))
	var dust := point - direction * (3.0 + progress * 13.0)
	draw_circle(dust, 3.0 + progress * 5.0, Color("8fa0ab", alpha * 0.22))
