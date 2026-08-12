extends "res://tests/test_case.gd"

const DiveScene = preload("res://scenes/dive/dive.tscn")

func test_flow_destroyed_run_settlement() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
	var controller = dive.get_node("M3DiveController"); controller.run.collect(&"ore_ferrite"); controller.run.run_id = "destroy-flow"
	var result = controller.run.finish(false, &"destroyed"); var settlement = preload("res://src/domain/economy_service.gd").new().apply_run_result(result)
	assert_true(not result.success); assert_equal(settlement.outcome, &"destroyed"); assert_equal(settlement.banked_resources.scrap, 1)
	dive.queue_free(); AppState.current_run_config = null; return true

func test_flow_abandon_run_discards_only_run_state() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
	var controller = dive.get_node("M3DiveController"); controller.run.collect(&"ore_lumen"); var result = controller.run.finish(false, &"abandoned")
	var settlement = preload("res://src/domain/economy_service.gd").new().apply_run_result(result)
	assert_equal(settlement.banked_resources.scrap, 0); assert_equal(settlement.lost_resources.scrap, 4)
	dive.queue_free(); AppState.current_run_config = null; return true

func test_production_map_drill_collect_supply_hazard_boiler_and_extract() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
	var controller = dive.get_node("M3DiveController"); var rig = dive.get_node("DrillRig"); var terrain = dive.get_node("TerrainWorld")
	assert_true(controller.generated_map != null); assert_true(not controller.mineral_cells.is_empty())
	var cell: Vector2i = controller.mineral_cells.keys()[0]; rig.global_position = Vector2(cell * terrain.cell_size) - Vector2(12, -4)
	for _i in range(terrain.terrain.TILE_DURABILITY): rig._request_drill(Vector2.RIGHT); terrain.terrain.commit_damage(); controller._on_cells_removed(terrain.terrain.last_removed_cells)
	assert_true(controller.run.cargo_used >= 1, "production terrain removal must reach cargo")
	controller._damage(15, &"hazard_steam"); assert_equal(controller.run.damage_taken, 15)
	var supply = controller.generated_map.room_instances.filter(func(room): return room.tags.has(&"supply"))[0]
	rig.global_position = Vector2(supply.position + supply.size / 2) * terrain.cell_size; controller._update_room_interactions(.1); assert_true(controller.run.supply_claimed)
	controller.run.boiler.active = true
	for index in range(3): assert_true(controller.run.boiler.interact_valve(index, .8))
	assert_true(controller.run.boiler.completed)
	var result = controller.run.finish(true); assert_true(result.success); assert_equal(result.topology_hash, controller.generated_map.topology_hash)
	dive.queue_free(); AppState.current_run_config = null; return true

func test_flow_scene_cycle_has_no_growth() -> bool:
	timeout_seconds = 5.0
	var baseline := runner_tree.get_node_count()
	for _i in range(100):
		var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive); dive.free(); AppState.current_run_config = null
	assert_true(runner_tree.get_node_count() <= baseline + 2)
	return true
