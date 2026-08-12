class_name MapValidator extends RefCounted

const ReportValue = preload("res://src/domain/generation_report.gd")

func validate(map: Variant):
	var report = ReportValue.new()
	if map == null or map.grid_width <= 0 or map.grid_height <= 0 or map.grid.size() != map.grid_width * map.grid_height:
		report.error_codes.append(&"invalid_grid")
		return report
	report.required_nodes = map.required_cells.size()
	_check_rooms(map, report)
	_check_corridors(map, report)
	var reachable := _flood(map, map.spawn_cell)
	for cell in map.required_cells:
		if reachable.has(cell): report.reachable_required_nodes += 1
	if report.reachable_required_nodes != report.required_nodes: report.error_codes.append(&"required_unreachable")
	if map.spawn_cell == map.exit_cell or not reachable.has(map.exit_cell): report.error_codes.append(&"exit_unreachable")
	for y in range(map.spawn_cell.y - 4, map.spawn_cell.y + 5):
		for x in range(map.spawn_cell.x - 4, map.spawn_cell.x + 5):
			if Vector2i(x, y).distance_squared_to(map.spawn_cell) <= 16 and map.cell_value(Vector2i(x, y)) >= 2:
				report.error_codes.append(&"unsafe_spawn")
				break
	for room in map.room_instances: report.hazard_budget += int(room.get("hazard_budget", 0))
	if map.topology_hash.is_empty(): report.error_codes.append(&"missing_topology_hash")
	report.retry_count = map.retry_count
	report.used_fallback = map.used_fallback
	report.valid = report.error_codes.is_empty()
	return report

func _check_rooms(map: Variant, report: Variant) -> void:
	for index in range(map.room_instances.size()):
		var room: Dictionary = map.room_instances[index]
		var rect := Rect2i(room.position, room.size)
		if rect.position.x < 2 or rect.position.y < 2 or rect.end.x > map.grid_width - 2 or rect.end.y > map.grid_height - 2:
			report.error_codes.append(&"room_out_of_bounds")
		for other_index in range(index):
			var other: Dictionary = map.room_instances[other_index]
			if rect.intersects(Rect2i(other.position, other.size)):
				report.error_codes.append(&"room_overlap")

func _check_corridors(map: Variant, report: Variant) -> void:
	for corridor in map.corridors:
		if int(corridor.get("width", 0)) < 2: report.error_codes.append(&"corridor_too_narrow")
		var from_dir: StringName = corridor.get("from_dir", &"")
		var to_dir: StringName = corridor.get("to_dir", &"")
		if not ((from_dir == &"E" and to_dir == &"W") or (from_dir == &"S" and to_dir == &"N")):
			report.error_codes.append(&"anchor_mismatch")

func _flood(map: Variant, start: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	if map.cell_value(start) != 0: return reached
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]; cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not reached.has(next) and map.cell_value(next) == 0:
				reached[next] = true; queue.append(next)
	return reached
