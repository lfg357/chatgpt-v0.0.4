extends SceneTree

const State = preload("res://src/domain/m2_run_state.gd")
const Frame = preload("res://src/domain/control_frame.gd")
const Tools = preload("res://src/domain/m2_tools.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = State.new()
	var tools = Tools.new()
	var seconds := 600.0
	if "--quick" in OS.get_cmdline_user_args(): seconds = 10.0
	var ticks := int(seconds * 60.0)
	for tick in range(ticks):
		var frame = Frame.new()
		frame.physics_frame = tick
		frame.move = Vector2.RIGHT.rotated(float(tick) * 0.01)
		frame.aim = Vector2.RIGHT.rotated(float(tick) * 0.02)
		if tick % 180 < 90: frame.held = 1
		if tick % 240 == 0: frame.pressed |= 4
		var paused := tick % 1200 >= 1140
		state.tick(1.0 / 60.0, frame, paused)
		tools.tick(1.0 / 60.0, tick % 500 < 100, paused)
		if tick % 300 == 0: tools.activate_sonar(); tools.place_beacon(Vector2(tick, 0))
		if is_nan(state.energy) or is_nan(state.heat) or state.energy < 0.0 or state.energy > 100.0 or state.heat < 0.0 or state.heat > 100.0:
			push_error("M2 endurance invariant failure at tick %d" % tick); quit(1); return
	print("M2_ENDURANCE passed seconds=%.1f beacons=%d heat=%.2f energy=%.2f" % [seconds, tools.beacons.size(), state.heat, state.energy])
	quit(0)
