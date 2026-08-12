class_name DrillRig extends CharacterBody2D

const RunState = preload("res://src/domain/m2_run_state.gd")
const ControlFrameValue = preload("res://src/domain/control_frame.gd")
const Tools = preload("res://src/domain/m2_tools.gd")
@export var terrain_path: NodePath
var state := RunState.new()
var tools := Tools.new()
var terrain: Node
var paused := false

func _ready() -> void:
	terrain = get_node_or_null(terrain_path)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func set_paused(value: bool) -> void:
	paused = value
	if not paused:
		InputService.clear_after_focus_loss()
		InputService.suppress_gameplay_for_frames()

func _physics_process(delta: float) -> void:
	var mouse_aim := get_global_mouse_position() - global_position
	var frame = InputService.frame_from_actions(mouse_aim, Engine.get_physics_frames())
	if frame.has_pressed(64): set_paused(not paused)
	var result := state.tick(delta, frame, paused)
	if paused: velocity = Vector2.ZERO; return
	var desired: Vector2 = frame.move.normalized() * RunState.MAX_SPEED * float(result.move_scale)
	if state.energy <= 0.0 and not bool(result.boosting): desired = Vector2.ZERO
	velocity = velocity.move_toward(desired, RunState.THRUST_ACCEL * delta)
	velocity.y = minf(velocity.y + RunState.GRAVITY * delta, RunState.MAX_FALL_SPEED)
	move_and_slide()
	if result.drilling: _request_drill(state.last_aim)
	if frame.has_pressed(2):
		var cell := _cell_at(global_position + state.last_aim * 18.0)
		if tools.blast_pins.is_empty(): tools.place_pin(cell)
		else:
			if tools.detonate(terrain) > 0 and has_node("M2Camera"): $M2Camera.add_trauma(0.35)
	if frame.has_pressed(8): tools.activate_sonar()
	if frame.has_pressed(16): tools.place_beacon(global_position)
	if tools.tick(delta, frame.has_held(32), paused):
		SceneRouter.go_to(4)
		return
	if has_node("M2Camera"):
		$M2Camera.update_target(global_position, state.last_aim, velocity, delta)
	_update_sprite(bool(result.drilling))

func _update_sprite(drilling: bool) -> void:
	if not has_node("Sprite"): return
	var sprite: AnimatedSprite2D = $Sprite
	var wanted := &"idle"
	if state.shutdown_seconds > 0.0: wanted = &"overheat"
	elif drilling: wanted = &"drill"
	elif velocity.length() > 5.0: wanted = &"thrust"
	if sprite.animation != wanted: sprite.play(wanted)
	sprite.rotation = state.last_aim.angle()

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

func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / terrain.cell_size), floori(point.y / terrain.cell_size))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_paused(true)
		InputService.clear_after_focus_loss()

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		set_paused(true)
		InputService.clear_after_focus_loss()
