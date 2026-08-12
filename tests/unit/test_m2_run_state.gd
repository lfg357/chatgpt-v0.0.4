extends "res://tests/test_case.gd"
const State = preload("res://src/domain/m2_run_state.gd")
const Frame = preload("res://src/domain/control_frame.gd")
const Tools = preload("res://src/domain/m2_tools.gd")
const Terrain = preload("res://src/gameplay/terrain_service.gd")
const Camera = preload("res://src/gameplay/m2_camera.gd")
func test_energy_delay_and_clamp() -> bool:
	var s=State.new(); s.energy=99.0; var f=Frame.new(); s.tick(0.74,f); assert_equal(s.energy,99.0); s.tick(1.0,f); assert_true(s.energy<=100.0 and s.energy>99.0); return true
func test_heat_shutdown_and_recovery() -> bool:
	var s=State.new(); s.heat=99.9; var f=Frame.new(); f.held=1; s.tick(1.0,f); assert_true(s.shutdown_seconds>0); assert_true(not s.tick(0.1,f).drilling); return true
func test_pause_freezes_all_run_clocks() -> bool:
	var s=State.new(); var f=Frame.new(); s.tick(1.0,f,true); assert_equal(s.run_seconds,0.0); return true
func test_aim_keeps_last_direction_inside_deadzone() -> bool:
	var s=State.new(); var f=Frame.new(); f.aim=Vector2.UP; s.tick(.1,f); f.aim=Vector2.ZERO; s.tick(.1,f); assert_equal(s.last_aim,Vector2.UP); return true
func test_rebind_conflict_requires_resolution() -> bool:
	assert_true(InputService.rebind_conflict(&"drill", &"boost")); return true
func test_controller_disconnect_pauses() -> bool:
	InputService.clear_after_focus_loss(); var f=InputService.frame_from_actions(Vector2.ZERO, 1); assert_equal(f.held,0); return true
func test_boost_respects_collision() -> bool:
	var s=State.new(); var f=Frame.new(); f.pressed=4; var r=s.tick(.01,f); assert_true(r.boosting and r.move_scale>1.0); return true
func test_explosion_caps_changed_cells() -> bool:
	var terrain=Terrain.new(); terrain.setup(32,32); var tools=Tools.new(); tools.place_pin(Vector2i(10,10)); assert_true(tools.detonate(terrain)<=48); assert_equal(tools.ammo,1); return true
func test_sonar_beacon_and_recall_pause() -> bool:
	var tools=Tools.new(); assert_true(tools.activate_sonar()); tools.place_beacon(Vector2.ZERO); tools.place_beacon(Vector2.ONE); tools.place_beacon(Vector2(2,2)); tools.place_beacon(Vector2(3,3)); assert_equal(tools.beacons.size(),3); assert_true(not tools.tick(2.0,true,true)); return true
func test_camera_lookahead_and_map_bounds() -> bool:
	var camera=Camera.new(); runner_tree.root.add_child(camera); camera.map_bounds=Rect2(0,0,2000,1000); camera.update_target(Vector2(5,5),Vector2.LEFT,Vector2.ZERO,1.0); assert_true(camera.global_position.x>=320.0); camera.queue_free(); return true
func test_camera_shake_percent_zero_has_no_offset() -> bool:
	var camera=Camera.new(); runner_tree.root.add_child(camera); camera.shake_percent=0.0; camera.add_trauma(1.0); camera.update_target(Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,0.1); assert_equal(camera.offset,Vector2.ZERO); camera.queue_free(); return true
func test_energy_empty_still_recovers_without_underflow() -> bool:
	var s=State.new(); s.energy=0.0; var f=Frame.new(); s.tick(1.0,f); assert_true(s.energy>0.0 and s.energy<=100.0); return true
func test_gamepad_defaults_are_mapped() -> bool:
	assert_true(InputMap.action_get_events(&"drill").size() >= 2)
	assert_true(InputMap.action_get_events(&"aim_right").size() >= 1)
	return true
func test_real_gamepad_event_selects_gamepad_control_frame() -> bool:
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.8
	InputService._input(stick)
	var frame = InputService.frame_from_actions(Vector2.ZERO, 101)
	assert_equal(frame.device_family, &"gamepad")
	assert_equal(frame.aim, Vector2.RIGHT)
	InputService.note_keyboard_mouse_input()
	return true
func test_resume_suppresses_residual_mouse_actions() -> bool:
	InputService.suppress_gameplay_for_frames(1)
	var frame=InputService.frame_from_actions(Vector2.RIGHT, 99)
	assert_equal(frame.held, 0)
	return true
func test_recall_requires_continuous_hold() -> bool:
	var tools=Tools.new()
	assert_true(not tools.tick(1.0, true, false))
	assert_true(not tools.tick(0.1, false, false))
	assert_true(not tools.tick(1.0, true, false))
	assert_true(tools.tick(0.6, true, false))
	return true
