extends "res://tests/test_case.gd"

const DiveScene = preload("res://scenes/dive/dive.tscn")

func test_dive_scene_exposes_terrain_validation_sandbox() -> bool:
	var dive := DiveScene.instantiate()
	var terrain = dive.get_node("TerrainWorld")
	assert_equal(terrain.cell_size, 8)
	assert_equal(terrain.grid_size, Vector2i(64, 26))
	assert_true(dive.has_node("M2Hud"))
	assert_true(dive.has_node("M2Hud/PausePanel/Resume"))
	assert_true(dive.has_node("M2Hud/PausePanel/ReturnToHub"))
	assert_true(dive.has_node("M2Feedback"))
	assert_true(not dive.get_node("Title").visible, "dive title must not overlap the top HUD")
	assert_true(dive.get_node("Instruction").position.y >= 60.0, "instruction reserves the top HUD safety area")
	var panel: Panel = dive.get_node("M2Hud/PausePanel")
	var return_button: Button = dive.get_node("M2Hud/PausePanel/ReturnToHub")
	assert_true(return_button.position.y + return_button.size.y <= panel.size.y, "pause panel wraps all buttons")
	dive.free()
	return true

func test_dive_scene_routes_controls_to_the_rig() -> bool:
	var dive := DiveScene.instantiate()
	runner_tree.root.add_child(dive)
	assert_true(dive.drill_rig.terrain == dive.terrain_world)
	dive.queue_free()
	return true

func test_controller_disconnect_pauses_live_rig() -> bool:
	var dive := DiveScene.instantiate()
	runner_tree.root.add_child(dive)
	dive.drill_rig._on_joy_connection_changed(0, false)
	assert_true(dive.drill_rig.paused)
	dive.queue_free()
	return true
