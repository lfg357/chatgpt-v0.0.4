class_name M2Feedback extends Node2D

@export var rig_path: NodePath
var rig: Node
var sonar_phase := 0.0

func _ready() -> void:
	rig = get_node_or_null(rig_path)
	queue_redraw()

func _process(delta: float) -> void:
	if rig == null: return
	sonar_phase += delta
	queue_redraw()

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
