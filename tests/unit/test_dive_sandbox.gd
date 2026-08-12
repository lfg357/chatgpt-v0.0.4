extends "res://tests/test_case.gd"

const DiveScene = preload("res://scenes/dive/dive.tscn")

func test_dive_scene_exposes_terrain_validation_sandbox() -> bool:
	var dive := DiveScene.instantiate()
	var terrain = dive.get_node("TerrainWorld")
	assert_equal(terrain.cell_size, 8)
	assert_equal(terrain.grid_size, Vector2i(80, 38))
	assert_true(dive.has_node("HudLayer/M2Hud"))
	assert_true(dive.has_node("HudLayer/M2Hud/PausePanel/Resume"))
	assert_true(dive.has_node("HudLayer/M2Hud/PausePanel/ReturnToHub"))
	assert_true(dive.has_node("HudLayer/M2Hud/BottomFrame/VitalsPanel"))
	assert_true(dive.has_node("HudLayer/M2Hud/BottomFrame/HeatPanel/HeatFill"))
	assert_true(dive.has_node("HudLayer/M2Hud/BottomFrame/ExtractionPanel"))
	assert_true(dive.has_node("M2Feedback"))
	assert_true(dive.get_node("HudLayer") is CanvasLayer, "HUD must remain fixed to the viewport")
	assert_true(not dive.get_node("Title").visible, "dive title must not overlap the top HUD")
	var panel: Panel = dive.get_node("HudLayer/M2Hud/PausePanel")
	var return_button: Button = dive.get_node("HudLayer/M2Hud/PausePanel/ReturnToHub")
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

func test_collision_trauma_only_fires_on_fast_contact_entry() -> bool:
	var dive := DiveScene.instantiate()
	var rig = dive.get_node("DrillRig")
	assert_true(rig._consume_collision_impact(true, 90.0))
	assert_true(not rig._consume_collision_impact(true, 90.0), "continued wall contact must not retrigger shake")
	assert_true(not rig._consume_collision_impact(false, 90.0))
	assert_true(not rig._consume_collision_impact(true, 30.0), "low-speed contact must not shake")
	dive.free()
	return true

func test_drill_breaks_the_first_solid_cell_at_the_visible_tip() -> bool:
	var dive := DiveScene.instantiate()
	runner_tree.root.add_child(dive)
	var rig = dive.drill_rig
	var terrain = dive.terrain_world
	# Seam begins at x=31; this puts the 6px rig against its left face.
	rig.global_position = Vector2(31 * terrain.cell_size - 6, 20 * terrain.cell_size + 4)
	var target := Vector2i(31, 20)
	assert_true(terrain.terrain.is_solid(target))
	assert_true(rig._request_drill(Vector2.RIGHT) > 0, "drilling at a touching wall must queue damage")
	terrain.terrain.commit_damage()
	assert_true(not terrain.terrain.is_solid(target), "the first contacted wall cell must be removed")
	dive.queue_free()
	return true

func test_extraction_routes_to_results_state() -> bool:
	var dive := DiveScene.instantiate()
	runner_tree.root.add_child(dive)
	AppState.mode = AppState.AppMode.DIVE
	var result = SceneRouter.go_to(AppState.AppMode.RESULTS)
	assert_true(result.ok, "extraction target transition is legal from dive")
	assert_equal(AppState.mode, AppState.AppMode.RESULTS)
	dive.queue_free()
	return true
