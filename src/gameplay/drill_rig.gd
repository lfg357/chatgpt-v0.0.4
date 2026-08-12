class_name DrillRig extends CharacterBody2D

const RunState = preload("res://src/domain/m2_run_state.gd")
const ControlFrameValue = preload("res://src/domain/control_frame.gd")
const Tools = preload("res://src/domain/m2_tools.gd")
const AppStateDefinition = preload("res://src/core/app_state.gd")
@export var terrain_path: NodePath
@export var run_controller_path: NodePath
var state := RunState.new()
var tools := Tools.new()
var terrain: Node
var paused := false
var _was_colliding := false
var _drill_feedback_cooldown := 0.0
var drill_contact_active := false
var drill_contact_point := Vector2.ZERO

const DRILL_CONTACT_REACH := 7.0
const DRILL_MAX_REACH := 26.0
const DRILL_SAMPLE_STEP := 4.0
const DRILL_DAMAGE_PER_TICK := 1
const DRILL_BITE_SPEED := 34.0

func _ready() -> void:
	terrain = get_node_or_null(terrain_path)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	state.run_failed.connect(_on_run_failed)

func set_paused(value: bool) -> void:
	paused = value
	if not paused:
		InputService.clear_after_focus_loss()
		InputService.suppress_gameplay_for_frames()

func _physics_process(delta: float) -> void:
	_drill_feedback_cooldown = maxf(0.0, _drill_feedback_cooldown - delta)
	var mouse_aim := get_global_mouse_position() - global_position
	var frame = InputService.frame_from_actions(mouse_aim, Engine.get_physics_frames())
	if frame.has_pressed(64): set_paused(not paused)
	var result := state.tick(delta, frame, paused)
	if paused: velocity = Vector2.ZERO; return
	var desired: Vector2 = frame.move.normalized() * RunState.MAX_SPEED * float(result.move_scale)
	if state.energy <= 0.0 and not bool(result.boosting): desired = Vector2.ZERO
	velocity = velocity.move_toward(desired, RunState.THRUST_ACCEL * delta)
	velocity.y = minf(velocity.y + RunState.GRAVITY * delta, RunState.MAX_FALL_SPEED)
	var impact_speed := velocity.length()
	move_and_slide()
	var is_colliding := get_slide_collision_count() > 0
	if _consume_collision_impact(is_colliding, impact_speed):
		_add_camera_trauma(0.2)
	drill_contact_active = false
	_set_feedback_contact(global_position, state.last_aim, false)
	if result.drilling: _request_drill(state.last_aim)
	if frame.has_pressed(2):
		var cell := _cell_at(global_position + state.last_aim * 18.0)
		if tools.blast_pins.is_empty(): tools.place_pin(cell)
		else:
			var controller := get_node_or_null(run_controller_path)
			if controller != null and controller.has_method("mark_blast_damage"):
				for pin in tools.blast_pins: controller.mark_blast_damage(pin)
			if tools.detonate(terrain) > 0: _add_camera_trauma(0.35)
	if frame.has_pressed(8): tools.activate_sonar()
	if frame.has_pressed(16): tools.place_beacon(global_position)
	if tools.tick(delta, frame.has_held(32), paused):
		var controller := get_node_or_null(run_controller_path)
		if controller != null and controller.has_method("request_extract"): controller.request_extract()
		else: SceneRouter.go_to(AppStateDefinition.AppMode.RESULTS)
		return
	if has_node("M2Camera"):
		$M2Camera.update_target(global_position, state.last_aim, velocity, delta)
	_update_sprite(bool(result.drilling))

func _update_sprite(drilling: bool) -> void:
	if not has_node("Sprite"): return
	var sprite: AnimatedSprite2D = $Sprite
	var wanted := &"idle"
	if state.failed: wanted = &"overheat"
	elif state.shutdown_seconds > 0.0: wanted = &"overheat"
	elif drilling: wanted = &"drill"
	elif velocity.length() > 5.0: wanted = &"thrust"
	if sprite.animation != wanted: sprite.play(wanted)
	# The whole rig pitches toward the active drill axis. Rotation is clamped so
	# the chassis remains readable while movement, pose and rock face agree.
	var aim_angle := state.last_aim.angle()
	if state.last_aim.x < 0.0: aim_angle = wrapf(aim_angle + PI, -PI, PI)
	sprite.rotation = clampf(aim_angle, -0.72, 0.72)
	sprite.flip_h = state.last_aim.x < -0.1

func _request_drill(aim: Vector2) -> int:
	if terrain == null or aim.length_squared() < 0.001: return 0
	# Test the visible drill tip first, then march outward. This makes a wall
	# directly touching the rig reliably break instead of sampling past thin seams.
	var direction := aim.normalized()
	var queued := 0
	var distance := DRILL_CONTACT_REACH
	while distance <= DRILL_MAX_REACH:
		var center := _cell_at(global_position + direction * distance)
		for cell in _drill_cells(center, direction):
			if terrain.request_damage(cell, DRILL_DAMAGE_PER_TICK):
				queued = 1
				break
		if queued > 0: break
		distance += DRILL_SAMPLE_STEP
	drill_contact_point = global_position + direction * DRILL_CONTACT_REACH
	drill_contact_active = queued > 0
	_set_feedback_contact(drill_contact_point, direction, drill_contact_active)
	if queued > 0:
		velocity = velocity.lerp(direction * DRILL_BITE_SPEED, 0.16)
	if queued > 0: _add_camera_trauma(0.025)
	if queued > 0 and _drill_feedback_cooldown <= 0.0:
		_emit_drill_feedback(global_position + direction * DRILL_CONTACT_REACH, direction, queued)
		_drill_feedback_cooldown = 0.055
	return queued

func _drill_cells(center: Vector2i, direction: Vector2) -> Array[Vector2i]:
	var side := Vector2i(-signi(direction.y), signi(direction.x))
	if side == Vector2i.ZERO: side = Vector2i.UP
	return [center, center + side, center - side, center + Vector2i(signi(direction.x), signi(direction.y))]

func _add_camera_trauma(amount: float) -> void:
	if has_node("M2Camera"): $M2Camera.add_trauma(amount)

func _emit_drill_feedback(hit_point: Vector2, direction: Vector2, strength: int) -> void:
	var feedback := get_node_or_null("../M2Feedback")
	if feedback != null and feedback.has_method("on_drill_hit"):
		feedback.call("on_drill_hit", hit_point, direction, strength)
	if has_node("Sprite"):
		$Sprite.position = -direction * 2.5

func _set_feedback_contact(point: Vector2, direction: Vector2, active: bool) -> void:
	var feedback := get_node_or_null("../M2Feedback")
	if feedback != null and feedback.has_method("set_drill_contact"):
		feedback.call("set_drill_contact", point, direction, active)

func _consume_collision_impact(is_colliding: bool, impact_speed: float) -> bool:
	var should_shake := is_colliding and not _was_colliding and impact_speed >= 70.0
	_was_colliding = is_colliding
	return should_shake

func _on_run_failed() -> void:
	velocity = Vector2.ZERO
	_add_camera_trauma(1.0)
	_update_sprite(false)
	var controller := get_node_or_null(run_controller_path)
	if controller != null and controller.has_method("request_destroyed"): controller.request_destroyed()

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
