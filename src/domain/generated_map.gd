class_name GeneratedMap extends RefCounted

var layer_id: StringName
var seed: int
var generator_version: int = 1
var content_version: int = 1
var grid: PackedInt32Array
var grid_width: int
var grid_height: int
var room_instances: Array[Dictionary] = []
var corridors: Array[Dictionary] = []
var spawn_cell: Vector2i
var exit_cell: Vector2i
var objective_cells: Array[Vector2i] = []
var required_cells: Array[Vector2i] = []
var topology_hash: String
var used_fallback: bool = false
var retry_count: int = 0

func cell_value(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height: return 1
	return grid[cell.y * grid_width + cell.x]
