class_name TerrainService extends RefCounted

const CHUNK_SIZE := 32
const MAX_EXPLOSION_CELLS := 128
const MAX_COLLISION_REBUILDS_PER_TICK := 2
const TILE_DURABILITY := 18
var width: int
var height: int
var cells: PackedByteArray
var pending_damage: Dictionary[Vector2i, int] = {}
var accumulated_damage: Dictionary[Vector2i, int] = {}
var dirty_chunks: Dictionary[Vector2i, bool] = {}
var collision_chunks: Dictionary[Vector2i, Dictionary] = {}
var rebuilt_this_tick: int = 0
var total_rebuilds: int = 0

func setup(grid_width: int, grid_height: int) -> void:
	width = grid_width; height = grid_height
	cells.resize(width * height); cells.fill(1)

func set_initial_empty(cell: Vector2i) -> bool:
	if not _in_bounds(cell) or not is_solid(cell): return false
	cells[_index(cell)] = 0
	dirty_chunks[_chunk_for(cell)] = true
	return true

func request_damage(cell: Vector2i, amount: int = TILE_DURABILITY) -> bool:
	if not _in_bounds(cell) or not is_solid(cell): return false
	pending_damage[cell] = int(pending_damage.get(cell, 0)) + maxi(1, amount)
	return true

func request_explosion(center: Vector2i, radius: int) -> int:
	var queued := 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if queued >= MAX_EXPLOSION_CELLS: return queued
			var cell := Vector2i(x, y)
			if cell.distance_squared_to(center) <= radius * radius and request_damage(cell): queued += 1
	return queued

func restore_solid(cell: Vector2i) -> bool:
	if not _in_bounds(cell) or is_solid(cell): return false
	cells[_index(cell)] = 1
	dirty_chunks[_chunk_for(cell)] = true
	return true

func commit_damage() -> int:
	var changed := 0
	for cell in pending_damage:
		if is_solid(cell):
			var total := int(accumulated_damage.get(cell, 0)) + int(pending_damage[cell])
			if total < TILE_DURABILITY:
				accumulated_damage[cell] = total
				continue
			cells[_index(cell)] = 0
			accumulated_damage.erase(cell)
			dirty_chunks[_chunk_for(cell)] = true
			changed += 1
	pending_damage.clear()
	return changed

func damage_ratio(cell: Vector2i) -> float:
	if not is_solid(cell): return 0.0
	return clampf(float(accumulated_damage.get(cell, 0)) / float(TILE_DURABILITY), 0.0, 1.0)

func physics_tick() -> int:
	rebuilt_this_tick = 0
	var chunks := dirty_chunks.keys()
	chunks.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x if a.y == b.y else a.y < b.y)
	for chunk in chunks:
		if rebuilt_this_tick >= MAX_COLLISION_REBUILDS_PER_TICK: break
		_rebuild_collision(chunk)
		dirty_chunks.erase(chunk)
		collision_chunks[chunk] = {"rebuilt": total_rebuilds}
		rebuilt_this_tick += 1; total_rebuilds += 1
	return rebuilt_this_tick

func is_solid(cell: Vector2i) -> bool:
	return _in_bounds(cell) and cells[_index(cell)] != 0

func has_collision(cell: Vector2i) -> bool:
	# Removed tiles consult the integer source of truth immediately; no ghost wall.
	return is_solid(cell)

func _rebuild_collision(_chunk: Vector2i) -> void: pass
func _chunk_for(cell: Vector2i) -> Vector2i: return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))
func _index(cell: Vector2i) -> int: return cell.y * width + cell.x
func _in_bounds(cell: Vector2i) -> bool: return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height
