extends "res://tests/test_case.gd"

const DiveScene = preload("res://scenes/dive/dive.tscn")

func test_dive_scene_exposes_terrain_validation_sandbox() -> bool:
	var dive := DiveScene.instantiate()
	var terrain = dive.get_node("TerrainWorld")
	assert_equal(terrain.cell_size, 8)
	assert_equal(terrain.grid_size, Vector2i(64, 26))
	assert_true(dive.has_node("Status"))
	assert_true(dive.has_node("BackToHub"))
	dive.free()
	return true

func test_dive_sandbox_receives_clicks_before_control_gui_consumption() -> bool:
	var dive := DiveScene.instantiate()
	runner_tree.root.add_child(dive)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = dive.terrain_world.global_position + Vector2(4, 4)
	dive._input(event)
	assert_true(dive.terrain_world.terrain.pending_damage.has(Vector2i.ZERO), "left click queues tile damage")
	dive.queue_free()
	return true
