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
