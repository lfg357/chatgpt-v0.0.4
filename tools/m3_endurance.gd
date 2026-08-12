extends SceneTree

func _init() -> void: call_deferred("_run")
func _run() -> void:
	var app_state = root.get_node("AppState")
	var DiveScene = load("res://scenes/dive/dive.tscn") as PackedScene
	if DiveScene == null: push_error("M3 endurance could not load production dive scene"); quit(1); return
	var dive = DiveScene.instantiate(); root.add_child(dive); await process_frame
	var controller = dive.get_node("M3DiveController"); var rig = dive.get_node("DrillRig"); var terrain = dive.get_node("TerrainWorld")
	controller.suppress_scene_transition = true
	var start_memory := OS.get_static_memory_usage()
	var cell: Vector2i = controller.mineral_cells.keys()[0]; rig.global_position = Vector2(cell * terrain.cell_size) - Vector2(12, -4)
	for _i in range(terrain.terrain.TILE_DURABILITY + 1): rig._request_drill(Vector2.RIGHT); terrain._physics_process(1.0 / 60.0)
	rig.tools.place_pin(cell); controller.mark_blast_damage(cell); rig.tools.detonate(terrain)
	rig.tools.activate_sonar(); rig.tools.place_beacon(rig.global_position)
	controller._damage(15, &"hazard_steam")
	var supply = controller.generated_map.room_instances.filter(func(room): return room.tags.has(&"supply"))[0]
	rig.global_position = Vector2(supply.position + supply.size / 2) * terrain.cell_size; controller._update_room_interactions(.1)
	controller.run.boiler.active = true
	for index in range(3): controller.run.boiler.interact_valve(index, .8)
	var success_ok: bool = controller.request_extract(); var result = app_state.last_run_result
	var passed: bool = success_ok and result.success and controller.run.cargo_used > 0 and controller.run.supply_claimed and controller.run.boiler.completed and controller.run.damage_taken > 0
	var memory_growth := OS.get_static_memory_usage() - start_memory
	var cargo_used: int = controller.run.cargo_used; var damage_taken: int = controller.run.damage_taken
	var supply_claimed: bool = controller.run.supply_claimed; var boiler_completed: bool = controller.run.boiler.completed
	dive.free(); await process_frame
	var destroyed = DiveScene.instantiate(); root.add_child(destroyed); await process_frame
	var destroyed_controller = destroyed.get_node("M3DiveController"); destroyed_controller.suppress_scene_transition = true; destroyed_controller.run.run_id = "m3-endurance-destroyed"
	var destroyed_ok: bool = destroyed_controller.request_destroyed() and app_state.last_run_result.failure_reason == &"destroyed"
	destroyed.free(); await process_frame
	var abandoned = DiveScene.instantiate(); root.add_child(abandoned); await process_frame
	var abandoned_controller = abandoned.get_node("M3DiveController"); abandoned_controller.suppress_scene_transition = true; abandoned_controller.run.run_id = "m3-endurance-abandoned"
	var abandoned_ok: bool = abandoned_controller.request_abandon() and app_state.last_run_result.failure_reason == &"abandoned"
	abandoned.free(); passed = passed and destroyed_ok and abandoned_ok
	print("M3_ENDURANCE passed=%s cargo=%d damage=%d supply=%s boiler=%s destroyed=%s abandoned=%s memory_delta=%d" % [passed, cargo_used, damage_taken, supply_claimed, boiler_completed, destroyed_ok, abandoned_ok, memory_growth])
	quit(0 if passed else 1)
