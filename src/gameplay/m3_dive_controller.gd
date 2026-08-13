class_name M3DiveController extends Node2D

const GeneratorValue = preload("res://src/domain/map_generator.gd")
const RunValue = preload("res://src/domain/industrial_run_state.gd")
const HazardsValue = preload("res://src/domain/industrial_hazards.gd")
const ConfigValue = preload("res://src/domain/run_config.gd")
const AppStateDefinition = preload("res://src/core/app_state.gd")
const LoggerValue = preload("res://src/core/playtest_logger.gd")
const MiteValue = preload("res://src/domain/scrap_mite_state.gd")
const ValidatorValue = preload("res://src/domain/map_validator.gd")
var generated_map: Variant
var run := RunValue.new()
var mineral_cells: Dictionary = {}
var entered_rooms: Dictionary = {}
var steam := HazardsValue.SteamVent.new()
var cable := HazardsValue.LiveCable.new()
var shale := HazardsValue.CollapseShale.new()
var mite := MiteValue.new()
var mite_carried: Dictionary = {}
var mite_position := Vector2.ZERO
var shale_position := Vector2.ZERO
var shale_hit := false
var frame_count := 0
var frame_total_ms := 0.0
var frame_peak_ms := 0.0
var show_routes := false
var show_anchors := false
var show_budgets := false
var show_reachable := false
var show_chunks := false
var completed := false
var suppress_scene_transition := false
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
	run.domain_event.connect(_on_domain_event)
	run.start(config, generated_map.topology_hash)
	_seed_minerals()
	terrain.cells_removed.connect(_on_cells_removed)
	rig.state.shutdown_started.connect(_on_overheat)
	shale_position = _room_center(&"room_ind_shaft")
	mite_position = _room_center(&"room_ind_mite_nest") + Vector2(24, 0)
	run.record_route(rig.global_position, rig.state.last_aim.angle())
	queue_redraw()

func _physics_process(delta: float) -> void:
	if completed: return
	var started_usec := Time.get_ticks_usec()
	var timeout_pulses_before: int = run.boiler.timeout_pulses
	run.tick(delta, rig.paused)
	if run.boiler.timeout_pulses > timeout_pulses_before: rig.state.damage(30)
	if rig.paused: return
	steam.cycle_seconds = 4.0 + run.boiler.valves.count(true)
	steam.tick(delta)
	var steam_damage := steam.try_hit(rig.get_instance_id()) if _near_module(&"room_ind_steam_cross", 64.0) else 0
	if steam_damage > 0: _damage(steam_damage, &"hazard_steam")
	var cable_damage := cable.tick(delta, _near_module(&"room_ind_cable_vault", 20.0))
	if cable_damage > 0: _damage(cable_damage, &"hazard_cable")
	_update_shale(delta)
	_update_mite(delta)
	_update_room_interactions(delta)
	var frame_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	frame_count += 1; frame_total_ms += frame_ms; frame_peak_ms = maxf(frame_peak_ms, frame_ms)

func _seed_minerals() -> void:
	var mineral_ids: Array[StringName] = [&"ore_ferrite", &"ore_copper_thread", &"ore_lumen"]
	for room in generated_map.room_instances:
		var budget := mini(8, int(room.mineral_budget))
		for index in range(budget):
			var cell := Vector2i(room.position.x + 3 + index % maxi(1, int(room.size.x) - 6), room.position.y + int(room.size.y) - 3 - index / maxi(1, int(room.size.x) - 6))
			var mineral_id: StringName = mineral_ids[posmod(index + int(room.index), 3)]
			terrain.restore_solid(cell); terrain.drill_hardness[cell] = float(ContentDB.get_def(mineral_id, &"MineralDef").hardness)
			mineral_cells[cell] = {"id": mineral_id, "damaged": false, "near_cable": room.module_id == &"room_ind_cable_vault"}

func mark_blast_damage(center: Vector2i, radius: int = 4) -> void:
	for cell in mineral_cells:
		if cell.distance_squared_to(center) <= radius * radius: mineral_cells[cell].damaged = true
	if _cell_in_room(center, &"room_ind_cable_vault"): cable.blast_power()
	if _cell_in_room(center, &"room_ind_shaft"): shale.remove_support()
	if _cell_in_room(center, &"room_ind_mite_nest"): mite.disturb()
	queue_redraw()

func _on_cells_removed(cells: Array[Vector2i]) -> void:
	var minerals_changed := false
	for cell in cells:
		if mineral_cells.has(cell):
			var mineral: Dictionary = mineral_cells[cell]
			if run.collect(mineral.id, mineral.damaged, mineral.near_cable):
				mineral_cells.erase(cell)
				minerals_changed = true
			else: terrain.restore_solid(cell)
		if _cell_in_room(cell, &"room_ind_shaft"): shale.remove_support()
	if minerals_changed: queue_redraw()

func _update_room_interactions(delta: float) -> void:
	for room in generated_map.room_instances:
		var center: Vector2 = Vector2(room.position + room.size / 2) * terrain.cell_size
		if rig.global_position.distance_to(center) > 28.0: continue
		if not entered_rooms.has(room.index): entered_rooms[room.index] = true; run.domain_event.emit(&"room_enter", {"module_id": room.module_id})
		if room.tags.has(&"supply"): run.claim_supply(rig.state, rig.tools)
		if room.tags.has(&"relic"): run.discover(&"log_03")
		if room.module_id == &"room_ind_cable_vault" and cable.active and Input.is_action_pressed(&"drill"):
			cable.drill_power(delta)
		if room.tags.has(&"core"):
			if not run.boiler.active and not run.boiler.completed and run.boiler.reset_wait <= 0.0: run.boiler.active = true
			if Input.is_action_pressed(&"drill"):
				var valve: int = mini(2, run.boiler.valves.count(true)); run.boiler.interact_valve(valve, delta)
			if run.boiler.completed and rig.global_position.distance_to(center) < 18.0: request_extract()

func _damage(amount: int, source: StringName) -> void:
	run.damage(amount, source); rig.state.damage(amount)

func request_extract() -> bool: return _finish(true, &"")
func request_destroyed() -> bool: return _finish(false, &"destroyed")
func request_abandon() -> bool: return _finish(false, &"abandoned")
func force_boiler_timeout() -> void: run.boiler.active = true; run.boiler.remaining = 0.01
func debug_restart(layer_id: StringName, seed: int) -> void:
	if not OS.is_debug_build(): return
	var config = ConfigValue.new(); config.layer_id = layer_id; config.seed = seed; config.generator_version = GeneratorValue.GENERATOR_VERSION; config.content_version = GeneratorValue.CONTENT_VERSION
	AppState.current_run_config = null
	AppState.start_run(config)
	get_tree().reload_current_scene()
func debug_teleport(tag_or_id: StringName) -> bool:
	if not OS.is_debug_build(): return false
	for room in generated_map.room_instances:
		if room.module_id == tag_or_id or room.tags.has(tag_or_id):
			rig.global_position = Vector2(room.position + room.size / 2) * terrain.cell_size
			return true
	return false
func debug_export() -> bool:
	if not OS.is_debug_build(): return false
	var report = preload("res://src/domain/map_validator.gd").new().validate(generated_map)
	var result_data := {}
	if run.terminated_result != null:
		var result: Resource = run.terminated_result
		result_data = {"run_id": result.run_id, "success": result.success, "failure_reason": String(result.failure_reason), "duration_ms": result.duration_ms, "damage_taken": result.damage_taken, "overheat_count": result.overheat_count, "route_samples": result.route_samples.size()}
	var payload := {"layer_id": String(generated_map.layer_id), "seed": generated_map.seed, "generator_version": generated_map.generator_version, "content_version": generated_map.content_version, "topology_hash": generated_map.topology_hash, "generation_report": {"valid": report.valid, "errors": report.error_codes, "reachable": report.reachable_required_nodes, "required": report.required_nodes, "fallback": report.used_fallback}, "performance_summary": run.performance_summary, "run_result": result_data}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/m3_debug_export.json", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(payload, "\t")); file.close(); return true
func _finish(success: bool, reason: StringName) -> bool:
	if completed: return false
	run.performance_summary = {"frames": frame_count, "average_update_ms": frame_total_ms / maxi(1, frame_count), "peak_update_ms": frame_peak_ms, "dirty_chunks": terrain.terrain.dirty_chunks.size()}
	LoggerValue.record(&"performance_summary", run.performance_summary)
	run.record_route(rig.global_position, rig.state.last_aim.angle(), _route_flags())
	var result = run.finish(success, reason)
	if result == null: return false
	var settlement = AppState.complete_run(result)
	if settlement == null or not settlement.committed: return false
	completed = true
	if not suppress_scene_transition: SceneRouter.go_to(AppStateDefinition.AppMode.RESULTS, {"result": result, "settlement": settlement})
	return true

func _near_module(id: StringName, distance: float) -> bool:
	for room in generated_map.room_instances:
		if room.module_id == id and rig.global_position.distance_to(Vector2(room.position + room.size / 2) * terrain.cell_size) <= distance: return true
	return false
func _near_tag(tag: StringName, distance: float) -> bool:
	for room in generated_map.room_instances:
		if room.tags.has(tag) and rig.global_position.distance_to(Vector2(room.position + room.size / 2) * terrain.cell_size) <= distance: return true
	return false
func current_room_id() -> StringName:
	for room in generated_map.room_instances:
		if Rect2(Vector2(room.position * terrain.cell_size), Vector2(room.size * terrain.cell_size)).has_point(rig.global_position): return room.module_id
	return &"corridor"
func current_warning() -> StringName:
	if steam.state == steam.State.WARNING and _near_module(&"room_ind_steam_cross", 96.0): return &"steam"
	if steam.state == steam.State.FIRING and _near_module(&"room_ind_steam_cross", 96.0): return &"steam_firing"
	if cable.active and _near_module(&"room_ind_cable_vault", 48.0): return &"cable"
	if shale.state == shale.State.WAITING or shale.state == shale.State.FALLING: return &"shale"
	return &""
func extraction_direction() -> String:
	var target := Vector2(generated_map.spawn_cell * terrain.cell_size)
	var delta: Vector2 = target - rig.global_position
	return "←" if absf(delta.x) >= absf(delta.y) and delta.x < 0.0 else "→" if absf(delta.x) >= absf(delta.y) else "↑" if delta.y < 0.0 else "↓"
func _room_center(id: StringName) -> Vector2:
	for room in generated_map.room_instances:
		if room.module_id == id: return Vector2(room.position + room.size / 2) * terrain.cell_size
	return Vector2.ZERO
func _cell_in_room(cell: Vector2i, id: StringName) -> bool:
	for room in generated_map.room_instances:
		if room.module_id == id and Rect2i(room.position, room.size).has_point(cell): return true
	return false
func _update_shale(delta: float) -> void:
	var old_state: int = shale.state
	shale.tick(delta)
	if shale.state == shale.State.FALLING:
		shale_position.y += shale.velocity * delta
		if not shale_hit and rig.global_position.distance_to(shale_position) <= 18.0:
			shale_hit = true; _damage(20, &"hazard_shale")
		var room_bottom := _room_center(&"room_ind_shaft").y + 36.0
		if shale_position.y >= room_bottom:
			shale.land()
			terrain.restore_solid(Vector2i(floori(shale_position.x / terrain.cell_size), floori(room_bottom / terrain.cell_size)))
	if old_state != shale.state: queue_redraw()
func _update_mite(delta: float) -> void:
	var nest := _room_center(&"room_ind_mite_nest")
	if nest == Vector2.ZERO: return
	if mite.state == mite.State.RETREAT:
		var speed: float = float(ContentDB.get_def(&"creature_scrap_mite", &"CreatureDef").move_speed)
		mite_position = mite_position.move_toward(nest, speed * delta)
	var available: Array[String] = []
	for cell in mineral_cells:
		if Vector2(cell * terrain.cell_size).distance_to(mite_position) <= 96.0: available.append("%d,%d" % [cell.x, cell.y])
	available.sort()
	var old_state: int = mite.state
	var stolen := mite.tick(delta, available)
	if not stolen.is_empty():
		var parts := stolen.split(","); var cell := Vector2i(int(parts[0]), int(parts[1]))
		if mineral_cells.has(cell): mite_carried[stolen] = {"cell": cell, "mineral": mineral_cells[cell]}; mineral_cells.erase(cell); terrain.terrain.set_initial_empty(cell)
	if old_state == mite.State.RETREAT and mite.state == mite.State.CALM:
		for key in mite.release_all():
			if mite_carried.has(key):
				var held: Dictionary = mite_carried[key]; mineral_cells[held.cell] = held.mineral; terrain.restore_solid(held.cell)
		mite_carried.clear()
	if (mite.state == mite.State.ALERT or mite.state == mite.State.RETREAT) and rig.global_position.distance_to(mite_position) <= 48.0: run.discover(&"log_05")
	if old_state != mite.state or not stolen.is_empty(): queue_redraw()
func _exit_tree() -> void:
	# The creature owns stolen mineral records while the scene is alive. Clearing
	# both containers together prevents duplicated or orphaned ownership on exit.
	mite.release_all(); mite_carried.clear()
func _route_flags() -> int:
	var flags := 0
	if Input.is_action_pressed(&"drill"): flags |= 1
	if rig.state.shutdown_seconds > 0.0: flags |= 8
	return flags
func _on_overheat() -> void:
	run.overheat_count += 1; LoggerValue.record(&"overheat", {"count": run.overheat_count})
func _on_domain_event(kind: StringName, data: Dictionary) -> void: LoggerValue.record(kind, data)
func _draw() -> void:
	if generated_map == null: return
	if show_reachable:
		for cell in ValidatorValue.new().reachable_cells(generated_map):
			draw_rect(Rect2(Vector2(cell * terrain.cell_size), Vector2.ONE * terrain.cell_size), Color("4ee6ab20"))
	for room in generated_map.room_instances:
		var color := Color("d85b6a40") if room.route == &"risk" else Color("73d1c828")
		draw_rect(Rect2(Vector2(room.position * terrain.cell_size), Vector2(room.size * terrain.cell_size)), color, false, 2.0)
		if show_budgets: draw_string(ThemeDB.fallback_font, Vector2(room.position * terrain.cell_size) + Vector2(2, 10), "M%d H%d C%d" % [room.mineral_budget, room.hazard_budget, room.creature_budget], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		if show_anchors:
			for direction in room.connectors: draw_circle(_anchor_position(room, direction), 3.0, Color("fff0a0"))
		if show_routes: draw_line(Vector2(room.position * terrain.cell_size), Vector2((room.position + room.size) * terrain.cell_size), color, 2.0)
	for cell in mineral_cells:
		var mineral: Dictionary = mineral_cells[cell]
		var color := Color("f0d77a") if mineral.id == &"ore_lumen" else Color("c98c55") if mineral.id == &"ore_copper_thread" else Color("7a8791")
		draw_rect(Rect2(Vector2(cell * terrain.cell_size), Vector2.ONE * terrain.cell_size), color)
	if steam.state != steam.State.IDLE: draw_circle(_room_center(&"room_ind_steam_cross"), 18.0 if steam.state == steam.State.WARNING else 32.0, Color("ffd06050") if steam.state == steam.State.WARNING else Color("ff604080"), false, 3.0)
	if cable.active: draw_circle(_room_center(&"room_ind_cable_vault"), 20.0, Color("67d9ff90"), false, 2.0)
	if shale.state != shale.State.SUPPORTED: draw_rect(Rect2(shale_position - Vector2(8, 5), Vector2(16, 10)), Color("c7a579"))
	var mite_colors: Array[Color] = [Color("9bb8a5"), Color("f0cc67"), Color("e67b63"), Color("8cb5df")]
	var mite_color: Color = mite_colors[mite.state]
	draw_circle(mite_position, 6.0, mite_color)
	if rig.tools.sonar_seconds > 0.0:
		for id in [&"room_ind_steam_cross", &"room_ind_cable_vault", &"room_ind_shaft", &"room_ind_supply", &"room_ind_relic", &"room_ind_core"]: draw_circle(_room_center(id), 8.0, Color("73d1c8"), false, 2.0)
	if show_chunks:
		for y in range(0, generated_map.grid_height, terrain.terrain.CHUNK_SIZE):
			for x in range(0, generated_map.grid_width, terrain.terrain.CHUNK_SIZE): draw_rect(Rect2(x * terrain.cell_size, y * terrain.cell_size, terrain.terrain.CHUNK_SIZE * terrain.cell_size, terrain.terrain.CHUNK_SIZE * terrain.cell_size), Color("ff80c060"), false, 1.0)

func _anchor_position(room: Dictionary, direction: StringName) -> Vector2:
	var center: Vector2 = Vector2(room.position + room.size / 2) * terrain.cell_size
	if direction == &"N": return Vector2(center.x, room.position.y * terrain.cell_size)
	if direction == &"S": return Vector2(center.x, (room.position.y + room.size.y) * terrain.cell_size)
	if direction == &"W": return Vector2(room.position.x * terrain.cell_size, center.y)
	return Vector2((room.position.x + room.size.x) * terrain.cell_size, center.y)
