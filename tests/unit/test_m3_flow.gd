extends "res://tests/test_case.gd"

const DiveScene = preload("res://scenes/dive/dive.tscn")
const RunConfigValue = preload("res://src/domain/run_config.gd")
const GeneratorValue = preload("res://src/domain/map_generator.gd")
const SnapshotValue = preload("res://src/core/save_snapshot.gd")

func _prepare_seed_with_room(room_id: StringName) -> void:
	AppState.current_run_config = null
	var layer = ContentDB.get_def(&"layer_industrial", &"LayerDef")
	var selected_seed := -1
	for seed in range(200):
		var map = GeneratorValue.new().generate(layer, seed)
		if map.room_instances.any(func(room): return room.module_id == room_id): selected_seed = seed; break
	assert_true(selected_seed >= 0, "expected a deterministic seed containing %s" % room_id)
	var config = RunConfigValue.new(); config.layer_id = &"layer_industrial"; config.seed = selected_seed
	AppState.start_run(config)

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
	controller.rig.state.shutdown_started.emit(); assert_equal(controller.run.overheat_count, 1)
	var supply = controller.generated_map.room_instances.filter(func(room): return room.tags.has(&"supply"))[0]
	rig.global_position = Vector2(supply.position + supply.size / 2) * terrain.cell_size; controller._update_room_interactions(.1); assert_true(controller.run.supply_claimed)
	controller.run.boiler.active = true
	for index in range(3): assert_true(controller.run.boiler.interact_valve(index, .8))
	assert_true(controller.run.boiler.completed)
	var result = controller.run.finish(true); assert_true(result.success); assert_equal(result.topology_hash, controller.generated_map.topology_hash)
	assert_true(not result.route_samples.is_empty())
	dive.queue_free(); AppState.current_run_config = null; return true

func test_production_hazards_and_mite_are_connected_to_map_state() -> bool:
	for room_id in [&"room_ind_cable_vault", &"room_ind_shaft", &"room_ind_mite_nest"]:
		_prepare_seed_with_room(room_id)
		var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
		var controller = dive.get_node("M3DiveController")
		var cell: Vector2i = Vector2i(controller._room_center(room_id) / controller.terrain.cell_size)
		controller.mark_blast_damage(cell)
		if room_id == &"room_ind_cable_vault": assert_true(not controller.cable.active)
		elif room_id == &"room_ind_shaft": assert_equal(controller.shale.state, controller.shale.State.WAITING)
		else: assert_equal(controller.mite.state, controller.mite.State.DISTURBED)
		dive.free(); AppState.current_run_config = null
	return true

func test_debug_panel_exposes_reachable_overlay() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
	var controller = dive.get_node("M3DiveController")
	var panel = dive.get_node("HudLayer/M3DebugPanel")
	assert_true(panel.has_node("Reachable"))
	panel.get_node("Reachable").button_pressed = true
	assert_true(controller.show_reachable)
	assert_true(not preload("res://src/domain/map_validator.gd").new().reachable_cells(controller.generated_map).is_empty())
	dive.queue_free(); AppState.current_run_config = null
	return true

func test_dive_controller_reports_nonnegative_current_depth() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive)
	var controller = dive.get_node("M3DiveController")
	assert_true(controller.current_depth_cells() >= 0)
	dive.queue_free(); AppState.current_run_config = null
	return true

func test_boiler_timeout_damage_reaches_live_rig_and_can_destroy() -> bool:
	var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive); var controller = dive.get_node("M3DiveController")
	controller.rig.state.durability = 20.0; controller.run.boiler.active = true; controller.run.boiler.remaining = 0.01
	controller._physics_process(.02)
	assert_equal(controller.run.damage_taken, 30); assert_equal(controller.rig.state.durability, 0.0)
	dive.queue_free(); AppState.current_run_config = null; return true

func test_flow_scene_cycle_has_no_growth() -> bool:
	timeout_seconds = 5.0
	var baseline := runner_tree.get_node_count()
	for _i in range(100):
		var dive = DiveScene.instantiate(); runner_tree.root.add_child(dive); dive.free(); AppState.current_run_config = null
	assert_true(runner_tree.get_node_count() <= baseline + 2)
	return true

func test_save_failure_does_not_bank_and_retry_settles_once() -> bool:
	var previous_snapshot = SaveService.active_snapshot
	var snapshot = SnapshotValue.new(); snapshot.profile_id = 2; snapshot.economy.scrap = 10
	SaveService.active_snapshot = snapshot; SaveService.fail_next_profile_save = true
	var run = preload("res://src/domain/industrial_run_state.gd").new(); var config = RunConfigValue.new(); config.layer_id = &"layer_industrial"; config.seed = 1
	run.start(config, "save-test"); run.run_id = "save-failure-retry"; run.collect(&"ore_ferrite")
	AppState.current_run_config = config; AppState.completed_run_ids.erase(run.run_id)
	var result = run.finish(true); var failed = AppState.complete_run(result)
	assert_true(not failed.committed); assert_equal(failed.error_code, &"save_failed"); assert_equal(SaveService.active_snapshot.economy.scrap, 10)
	var retried = AppState.complete_run(result); assert_true(retried.committed); assert_equal(SaveService.active_snapshot.economy.scrap, 13)
	var duplicate = AppState.complete_run(result); assert_true(duplicate == retried); assert_equal(SaveService.active_snapshot.economy.scrap, 13)
	AppState.completed_run_ids.erase(run.run_id); AppState.current_run_config = null; SaveService.active_snapshot = previous_snapshot
	return true
