class_name MapGenerator extends RefCounted

const GeneratedMapValue = preload("res://src/domain/generated_map.gd")
const ValidatorValue = preload("res://src/domain/map_validator.gd")
const GENERATOR_VERSION := 2
const CONTENT_VERSION := 1
const MAX_ATTEMPTS := 3
var validator := ValidatorValue.new()
var content_db: Variant
var force_fail_attempts: int = 0
var fallback_load_count: int = 0
var generator_version: int = GENERATOR_VERSION
var content_version: int = CONTENT_VERSION

func generate(layer: Variant, seed: int):
	for attempt in range(MAX_ATTEMPTS):
		var generated = _build(layer, seed, attempt, false)
		generated.retry_count = attempt
		if attempt >= force_fail_attempts and validator.validate(generated).valid: return generated
	fallback_load_count += 1
	var fallback = _build(layer, seed, MAX_ATTEMPTS, true)
	fallback.retry_count = MAX_ATTEMPTS
	fallback.used_fallback = true
	return fallback

func _build(layer: Variant, seed: int, attempt: int, fallback: bool):
	var result = GeneratedMapValue.new()
	result.layer_id = layer.id; result.seed = seed
	result.generator_version = generator_version; result.content_version = content_version
	var rng := RandomNumberGenerator.new()
	rng.seed = _context_seed(layer.id, seed, attempt)
	var main_ids: Array[StringName] = []
	var branch_count: int = 0 if fallback else rng.randi_range(layer.min_risk_branches, layer.max_risk_branches)
	var extra_relic_count: int = 0 if fallback else int(layer.extra_relic_rooms)
	if fallback:
		main_ids = [layer.entry_room_id, layer.normal_room_ids[0], layer.normal_room_ids[0], layer.supply_room_id, layer.relic_room_id, layer.core_room_id]
	else:
		var node_count := rng.randi_range(layer.min_main_nodes, layer.max_main_nodes)
		main_ids.append(layer.entry_room_id)
		for _i in range(node_count - 4): main_ids.append(layer.normal_room_ids[rng.randi_range(0, layer.normal_room_ids.size() - 1)])
		var required_branch_hosts: int = branch_count + extra_relic_count
		for host_index in range(1, mini(main_ids.size(), required_branch_hosts + 1)):
			main_ids[host_index] = _first_with_connector(layer.normal_room_ids, &"S")
		var supply_at := rng.randi_range(1, maxi(1, main_ids.size() - 1))
		main_ids.insert(supply_at, layer.supply_room_id)
		main_ids.insert(main_ids.size(), layer.relic_room_id)
		main_ids.append(layer.core_room_id)
	_layout(layer, result, main_ids, branch_count, extra_relic_count, rng)
	result.topology_hash = _hash(result)
	return result

func _layout(layer: Variant, result: Variant, main_ids: Array[StringName], branch_count: int, extra_relic_count: int, rng: RandomNumberGenerator) -> void:
	var modules := _module_lookup(layer)
	var x := 4
	var main_center_y := 16
	var main_centers: Array[Vector2i] = []
	for index in range(main_ids.size()):
		var module: Variant = modules[main_ids[index]]
		var room_y: int = main_center_y - int(module.size_cells.y) / 2
		var instance := _instance(module, Vector2i(x, room_y), index, -1, &"main")
		result.room_instances.append(instance)
		var center := Vector2i(x + module.size_cells.x / 2, room_y + module.size_cells.y / 2)
		main_centers.append(center)
		if index > 0:
			result.corridors.append({"from": index - 1, "to": index, "from_dir": &"E", "to_dir": &"W", "width": 3})
		x += module.size_cells.x + 4
	var total_width := x + 4
	var branch_y := 38
	var used_parents: Dictionary = {}
	for branch_index in range(branch_count):
		var parent_candidates: Array[int] = []
		for candidate_index in range(1, main_ids.size() - 1):
			if modules[main_ids[candidate_index]].connectors.has(&"S"): parent_candidates.append(candidate_index)
		if parent_candidates.is_empty(): break
		var parent_index: int = parent_candidates[branch_index % parent_candidates.size()]
		used_parents[parent_index] = true
		var module: Variant = modules[layer.risk_room_ids[rng.randi_range(0, layer.risk_room_ids.size() - 1)]]
		var bx: int = main_centers[parent_index].x - int(module.size_cells.x) / 2
		var instance := _instance(module, Vector2i(bx, branch_y + branch_index * 28), result.room_instances.size(), parent_index, &"risk")
		result.room_instances.append(instance)
		result.corridors.append({"from": parent_index, "to": instance.index, "from_dir": &"S", "to_dir": &"N", "width": 3})
		total_width = maxi(total_width, bx + module.size_cells.x + 4)
	for extra_index in range(extra_relic_count):
		var parent_index := -1
		for candidate_index in range(1, main_ids.size() - 1):
			if modules[main_ids[candidate_index]].connectors.has(&"S") and not used_parents.has(candidate_index): parent_index = candidate_index; break
		if parent_index < 0: break
		used_parents[parent_index] = true
		var module: Variant = modules[layer.relic_room_id]
		var bx: int = main_centers[parent_index].x - int(module.size_cells.x) / 2
		var instance := _instance(module, Vector2i(bx, branch_y + (branch_count + extra_index) * 28), result.room_instances.size(), parent_index, &"relic_branch")
		result.room_instances.append(instance)
		result.corridors.append({"from": parent_index, "to": instance.index, "from_dir": &"S", "to_dir": &"N", "width": 3})
		total_width = maxi(total_width, bx + module.size_cells.x + 4)
	var total_height := maxi(34, branch_y + (branch_count + extra_relic_count) * 28 + 4)
	result.grid_width = total_width; result.grid_height = total_height
	result.grid.resize(total_width * total_height); result.grid.fill(1)
	for room in result.room_instances: _carve_rect(result, Rect2i(room.position + Vector2i.ONE, room.size - Vector2i(2, 2)))
	for corridor in result.corridors: _carve_connection(result, corridor)
	result.spawn_cell = main_centers[0]
	result.exit_cell = main_centers[main_centers.size() - 1]
	for room in result.room_instances:
		if room.tags.has(&"supply") or room.tags.has(&"relic") or room.tags.has(&"core"):
			var cell := Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)
			result.required_cells.append(cell); result.objective_cells.append(cell)
	result.required_cells.append(result.exit_cell)

func _instance(module: Variant, position: Vector2i, index: int, parent: int, route: StringName) -> Dictionary:
	return {"index": index, "module_id": module.id, "position": position, "size": module.size_cells, "connectors": module.connectors.duplicate(), "tags": module.tags.duplicate(), "risk": module.risk, "mineral_budget": module.mineral_budget, "hazard_budget": module.hazard_budget, "creature_budget": module.creature_budget, "parent": parent, "route": route}

func _carve_rect(result: Variant, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): result.grid[y * result.grid_width + x] = 0

func _carve_connection(result: Variant, corridor: Dictionary) -> void:
	var from: Dictionary = result.room_instances[corridor.from]
	var to: Dictionary = result.room_instances[corridor.to]
	if corridor.from_dir == &"E":
		var y: int = int(from.position.y) + int(from.size.y) / 2
		_carve_rect(result, Rect2i(Vector2i(from.position.x + from.size.x - 1, y - 1), Vector2i(to.position.x - (from.position.x + from.size.x) + 2, 3)))
	else:
		var x: int = int(from.position.x) + int(from.size.x) / 2
		var end_y: int = int(to.position.y) + 2
		_carve_rect(result, Rect2i(Vector2i(x - 1, from.position.y + from.size.y - 1), Vector2i(3, end_y - (from.position.y + from.size.y) + 1)))

func _module_lookup(layer: Variant) -> Dictionary:
	var lookup := {}
	var database: Variant = content_db if content_db != null else get_node_content_db()
	for id in [layer.entry_room_id, layer.supply_room_id, layer.relic_room_id, layer.core_room_id] + layer.normal_room_ids + layer.risk_room_ids:
		lookup[id] = database.get_def(id, &"RoomModuleDef")
	return lookup

func _has_connector(ids: Array[StringName], layer: Variant, direction: StringName) -> bool:
	for id in ids:
		var room = Engine.get_main_loop().root.get_node("ContentDB").get_def(id, &"RoomModuleDef") if content_db == null else content_db.get_def(id, &"RoomModuleDef")
		if room != null and room.connectors.has(direction): return true
	return false

func _first_with_connector(ids: Array[StringName], direction: StringName) -> StringName:
	var database: Variant = content_db if content_db != null else get_node_content_db()
	for id in ids:
		if database.get_def(id, &"RoomModuleDef").connectors.has(direction): return id
	return ids[0]

func get_node_content_db() -> Variant:
	return Engine.get_main_loop().root.get_node("ContentDB")

func _context_seed(layer_id: StringName, seed: int, attempt: int) -> int:
	var context := "%s|%d|%d|%d|%d" % [String(layer_id), seed, generator_version, content_version, attempt]
	return int("0x" + context.sha256_text().substr(0, 15))

func _hash(result: Variant) -> String:
	var parts: Array[String] = [String(result.layer_id), str(result.seed), str(result.generator_version), str(result.content_version)]
	for room in result.room_instances:
		parts.append("%d:%s:%d:%d:%s:%d" % [room.index, String(room.module_id), room.position.x, room.position.y, String(room.route), room.parent])
	for corridor in result.corridors:
		parts.append("c:%d:%d:%s:%s:%d" % [corridor.from, corridor.to, String(corridor.from_dir), String(corridor.to_dir), corridor.width])
	return "|".join(parts).sha256_text()
