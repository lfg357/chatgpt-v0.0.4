class_name M3DiveController extends Node2D

const GeneratorValue = preload("res://src/domain/map_generator.gd")
const RunValue = preload("res://src/domain/industrial_run_state.gd")
const HazardsValue = preload("res://src/domain/industrial_hazards.gd")
const ConfigValue = preload("res://src/domain/run_config.gd")
const AppStateDefinition = preload("res://src/core/app_state.gd")
const LoggerValue = preload("res://src/core/playtest_logger.gd")
var generated_map: Variant
var run := RunValue.new()
var mineral_cells: Dictionary = {}
var entered_rooms: Dictionary = {}
var steam := HazardsValue.SteamVent.new()
var cable := HazardsValue.LiveCable.new()
var shale := HazardsValue.CollapseShale.new()
var completed := false
@onready var terrain: Node = $"../TerrainWorld"
@onready var rig: Node = $"../DrillRig"

func _ready() -> void:
	ContentDB.load_all()
	var config: Resource = AppState.current_run_config
	if config == null:
		config = ConfigValue.new(); config.layer_id = &"layer_industrial"; config.seed = 170101; config.generator_version = 1; config.content_version = 1
		AppState.start_run(config)
	var generator = GeneratorValue.new(); generated_map = generator.generate(ContentDB.get_def(config.layer_id, &"LayerDef"), config.seed)
	terrain.apply_generated_map(generated_map)
	rig.global_position = Vector2(generated_map.spawn_cell * terrain.cell_size) + Vector2(terrain.cell_size * .5, terrain.cell_size * .5)
	rig.get_node("M2Camera").map_bounds = Rect2(Vector2.ZERO, Vector2(generated_map.grid_width * terrain.cell_size, generated_map.grid_height * terrain.cell_size))
	run.start(config, generated_map.topology_hash)
	_seed_minerals()
	terrain.cells_removed.connect(_on_cells_removed)
	run.domain_event.connect(_on_domain_event)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if completed: return
	run.tick(delta, rig.paused)
	if rig.paused: return
	steam.tick(delta)
	var steam_damage := steam.try_hit(rig.get_instance_id()) if _near_tag(&"risk", 64.0) else 0
	if steam_damage > 0: _damage(steam_damage, &"hazard_steam")
	var cable_damage := cable.tick(delta, _near_module(&"room_ind_cable_vault", 20.0))
	if cable_damage > 0: _damage(cable_damage, &"hazard_cable")
	_update_room_interactions(delta)

func _seed_minerals() -> void:
	var mineral_ids: Array[StringName] = [&"ore_ferrite", &"ore_copper_thread", &"ore_lumen"]
	for room in generated_map.room_instances:
		var budget := mini(8, int(room.mineral_budget))
		for index in range(budget):
			var cell := Vector2i(room.position.x + 3 + index % maxi(1, int(room.size.x) - 6), room.position.y + int(room.size.y) - 3 - index / maxi(1, int(room.size.x) - 6))
			terrain.restore_solid(cell); mineral_cells[cell] = {"id": mineral_ids[posmod(index + int(room.index), 3)], "damaged": false, "near_cable": room.module_id == &"room_ind_cable_vault"}

func mark_blast_damage(center: Vector2i, radius: int = 4) -> void:
	for cell in mineral_cells:
		if cell.distance_squared_to(center) <= radius * radius: mineral_cells[cell].damaged = true

func _on_cells_removed(cells: Array[Vector2i]) -> void:
	var minerals_changed := false
	for cell in cells:
		if mineral_cells.has(cell):
			var mineral: Dictionary = mineral_cells[cell]
			if run.collect(mineral.id, mineral.damaged, mineral.near_cable):
				mineral_cells.erase(cell)
				minerals_changed = true
			else: terrain.restore_solid(cell)
	if minerals_changed: queue_redraw()

func _update_room_interactions(delta: float) -> void:
	for room in generated_map.room_instances:
		var center: Vector2 = Vector2(room.position + room.size / 2) * terrain.cell_size
		if rig.global_position.distance_to(center) > 28.0: continue
		if not entered_rooms.has(room.index): entered_rooms[room.index] = true; run.domain_event.emit(&"room_enter", {"module_id": room.module_id})
		if room.tags.has(&"supply"): run.claim_supply(rig.state, rig.tools)
		if room.tags.has(&"relic"): run.discover(&"log_03")
		if room.tags.has(&"core"):
			if not run.boiler.active and not run.boiler.completed and run.boiler.reset_wait <= 0.0: run.boiler.active = true
			if Input.is_action_pressed(&"drill"):
				var valve: int = mini(2, run.boiler.valves.count(true)); run.boiler.interact_valve(valve, delta)
			if run.boiler.completed and rig.global_position.distance_to(center) < 18.0: request_extract()

func _damage(amount: int, source: StringName) -> void:
	run.damage(amount, source); rig.state.damage(amount)

func request_extract() -> void: _finish(true, &"")
func request_destroyed() -> void: _finish(false, &"destroyed")
func request_abandon() -> void: _finish(false, &"abandoned")
func force_boiler_timeout() -> void: run.boiler.active = true; run.boiler.remaining = 0.01
func _finish(success: bool, reason: StringName) -> void:
	if completed: return
	var result = run.finish(success, reason)
	if result == null: return
	var settlement = AppState.complete_run(result)
	if settlement == null or not settlement.committed: return
	completed = true; SceneRouter.go_to(AppStateDefinition.AppMode.RESULTS, {"result": result, "settlement": settlement})

func _near_module(id: StringName, distance: float) -> bool:
	for room in generated_map.room_instances:
		if room.module_id == id and rig.global_position.distance_to(Vector2(room.position + room.size / 2) * terrain.cell_size) <= distance: return true
	return false
func _near_tag(tag: StringName, distance: float) -> bool:
	for room in generated_map.room_instances:
		if room.tags.has(tag) and rig.global_position.distance_to(Vector2(room.position + room.size / 2) * terrain.cell_size) <= distance: return true
	return false
func _on_domain_event(kind: StringName, data: Dictionary) -> void: LoggerValue.record(kind, data)
func _draw() -> void:
	if generated_map == null: return
	for room in generated_map.room_instances:
		var color := Color("d85b6a40") if room.route == &"risk" else Color("73d1c828")
		draw_rect(Rect2(Vector2(room.position * terrain.cell_size), Vector2(room.size * terrain.cell_size)), color, false, 2.0)
	for cell in mineral_cells:
		var mineral: Dictionary = mineral_cells[cell]
		var color := Color("f0d77a") if mineral.id == &"ore_lumen" else Color("c98c55") if mineral.id == &"ore_copper_thread" else Color("7a8791")
		draw_rect(Rect2(Vector2(cell * terrain.cell_size), Vector2.ONE * terrain.cell_size), color)
