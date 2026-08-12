class_name DrillRig extends CharacterBody2D

const RunState = preload("res://src/domain/m2_run_state.gd")
const ControlFrameValue = preload("res://src/domain/control_frame.gd")
@export var terrain_path: NodePath
var state := RunState.new()
var terrain: Node
var paused := false

func _ready() -> void:
	terrain = get_node_or_null(terrain_path)

func _physics_process(delta: float) -> void:
	var mouse_aim := get_global_mouse_position() - global_position
	var frame = InputService.frame_from_actions(mouse_aim, Engine.get_physics_frames())
	if frame.has_pressed(64): paused = not paused
	var result := state.tick(delta, frame, paused)
	if paused: velocity = Vector2.ZERO; return
	var desired: Vector2 = frame.move.normalized() * RunState.MAX_SPEED * float(result.move_scale)
	velocity = velocity.move_toward(desired, RunState.THRUST_ACCEL * delta)
	velocity.y = minf(velocity.y + RunState.GRAVITY * delta, RunState.MAX_FALL_SPEED)
	move_and_slide()
	if result.drilling: _request_drill(state.last_aim)

func _request_drill(aim: Vector2) -> void:
	if terrain == null: return
	var origin := global_position + aim * 18.0
	var center := Vector2i(floori(origin.x / terrain.cell_size), floori(origin.y / terrain.cell_size))
	var queued := 0
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			if queued >= 4: return
			var delta := Vector2(x - center.x, y - center.y)
			if delta == Vector2.ZERO or aim.dot(delta.normalized()) >= cos(deg_to_rad(30.0)):
				if terrain.request_damage(Vector2i(x, y)): queued += 1
