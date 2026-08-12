class_name TerrainWorld extends Node2D

signal cells_removed(cells: Array[Vector2i])

const TerrainServiceValue = preload("res://src/gameplay/terrain_service.gd")

## Presentation and collision adapter for TerrainService.
## TerrainService remains the only terrain truth; dirty chunks disable old collision
## immediately, then rebuild under the service's per-tick budget.
@export var cell_size: int = 8
@export var grid_size := Vector2i(64, 32)
@export var initially_solid := true
@export var m2_graybox := false
var terrain := TerrainServiceValue.new()
var chunk_bodies: Dictionary[Vector2i, StaticBody2D] = {}

func _ready() -> void:
	terrain.setup(grid_size.x, grid_size.y)
	if not initially_solid: terrain.cells.fill(0)
	if m2_graybox: _carve_m2_graybox()
	else:
		for y in range(0, grid_size.y, TerrainServiceValue.CHUNK_SIZE):
			for x in range(0, grid_size.x, TerrainServiceValue.CHUNK_SIZE):
				terrain.dirty_chunks[Vector2i(x / TerrainServiceValue.CHUNK_SIZE, y / TerrainServiceValue.CHUNK_SIZE)] = true
	queue_redraw()

func _carve_m2_graybox() -> void:
	# Launch chamber opens into one continuous rock mass. The player follows the
	# stratum and its mineral vein rather than drilling disconnected rectangles.
	for y in range(7, grid_size.y - 7):
		for x in range(2, 28):
			terrain.set_initial_empty(Vector2i(x, y))
	for y in range(7, 15):
		for x in range(28, grid_size.x - 2):
			terrain.set_initial_empty(Vector2i(x, y))
	for center in [Vector2i(43, 21), Vector2i(59, 25), Vector2i(70, 18)]:
		for y in range(center.y - 2, center.y + 3):
			for x in range(center.x - 3, center.x + 4):
				if Vector2i(x, y).distance_squared_to(center) <= 8:
					terrain.set_initial_empty(Vector2i(x, y))

func request_damage(cell: Vector2i, amount: int = TerrainServiceValue.TILE_DURABILITY) -> bool:
	return terrain.request_damage(cell, amount)

func request_explosion(center: Vector2i, radius: int) -> int:
	return terrain.request_explosion(center, radius)

func restore_solid(cell: Vector2i) -> bool:
	return terrain.restore_solid(cell)

func _physics_process(_delta: float) -> void:
	var had_pending_damage := not terrain.pending_damage.is_empty()
	var changed := terrain.commit_damage()
	if changed > 0: cells_removed.emit(terrain.last_removed_cells.duplicate())
	if changed > 0:
		_disable_dirty_chunk_collision()
	if had_pending_damage: queue_redraw()
	var dirty_before := terrain.dirty_chunks.duplicate()
	terrain.physics_tick()
	for chunk in dirty_before:
		if not terrain.dirty_chunks.has(chunk): _rebuild_chunk_collision(chunk)

func apply_generated_map(map: Variant) -> void:
	for body in chunk_bodies.values(): body.queue_free()
	chunk_bodies.clear()
	grid_size = Vector2i(map.grid_width, map.grid_height)
	terrain = TerrainServiceValue.new(); terrain.setup(grid_size.x, grid_size.y)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if map.cell_value(Vector2i(x, y)) == 0: terrain.set_initial_empty(Vector2i(x, y))
	for y in range(0, grid_size.y, TerrainServiceValue.CHUNK_SIZE):
		for x in range(0, grid_size.x, TerrainServiceValue.CHUNK_SIZE): terrain.dirty_chunks[Vector2i(x / TerrainServiceValue.CHUNK_SIZE, y / TerrainServiceValue.CHUNK_SIZE)] = true
	queue_redraw()

func _disable_dirty_chunk_collision() -> void:
	for chunk in terrain.dirty_chunks:
		if chunk_bodies.has(chunk): chunk_bodies[chunk].process_mode = Node.PROCESS_MODE_DISABLED

func _rebuild_chunk_collision(chunk: Vector2i) -> void:
	var old_body: StaticBody2D = chunk_bodies.get(chunk)
	if old_body != null:
		old_body.queue_free()
	var body := StaticBody2D.new()
	body.name = "TerrainChunk_%d_%d" % [chunk.x, chunk.y]
	body.collision_layer = 1
	add_child(body)
	chunk_bodies[chunk] = body
	var start := chunk * TerrainServiceValue.CHUNK_SIZE
	var end := Vector2i(mini(start.x + TerrainServiceValue.CHUNK_SIZE, grid_size.x), mini(start.y + TerrainServiceValue.CHUNK_SIZE, grid_size.y))
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			var cell := Vector2i(x, y)
			if terrain.is_solid(cell):
				var collider := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2(cell_size, cell_size)
				collider.shape = shape
				collider.position = Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)
				body.add_child(collider)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(grid_size * cell_size))
	draw_rect(bounds, Color("09111d"))
	_draw_industrial_backdrop(bounds)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if terrain.is_solid(Vector2i(x, y)):
				var pattern := posmod(x * 17 + y * 29, 37)
				var tile_rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
				var base := Color("26384c")
				if _is_ore_cell(Vector2i(x, y)):
					base = Color("315d69") if pattern % 3 else Color("5fae9a")
				elif y >= grid_size.y - 12:
					base = Color("3f4551") if pattern % 4 else Color("68727d")
				elif pattern % 11 == 0:
					base = Color("8c633f")
				elif pattern % 7 == 0:
					base = Color("465a70")
				draw_rect(tile_rect, base)
				draw_line(tile_rect.position + Vector2(1, 1), tile_rect.end - Vector2(2, 2), Color("a4b8c8", 0.30), 1.0)
				if pattern % 5 == 0:
					draw_rect(Rect2(tile_rect.position + Vector2(2, 2), Vector2(2, 2)), Color("d3e1e7", 0.45))
				_draw_damage_cracks(Vector2i(x, y), tile_rect)

func _is_ore_cell(cell: Vector2i) -> bool:
	if cell.x < 30 or cell.x > grid_size.x - 4: return false
	var vein_y := 23 + roundi(sin(float(cell.x) * 0.31) * 2.0)
	return absi(cell.y - vein_y) <= (1 if posmod(cell.x, 5) else 2)

func _draw_damage_cracks(cell: Vector2i, tile_rect: Rect2) -> void:
	var ratio := terrain.damage_ratio(cell)
	if ratio <= 0.0: return
	var center := tile_rect.get_center()
	var crack := Color("eef3e4", 0.55 + ratio * 0.35)
	var branches := clampi(ceili(ratio * 4.0), 1, 4)
	for i in range(branches):
		var angle := float(posmod(cell.x * 13 + cell.y * 7 + i * 11, 32)) / 32.0 * TAU
		var mid := center + Vector2.RIGHT.rotated(angle) * (2.0 + i * 0.45)
		var edge := center + Vector2.RIGHT.rotated(angle + 0.35 * sin(i + cell.x)) * (3.5 + ratio * 1.5)
		draw_line(center, mid, crack, 1.0)
		draw_line(mid, edge, crack, 1.0)
	if ratio >= 0.65:
		draw_circle(center, 2.0 + ratio * 2.0, Color("0b1017", 0.34))

func _draw_industrial_backdrop(bounds: Rect2) -> void:
	# Ceiling rail and repeated machine housings provide scale before the player
	# reaches the rock face; this is the visual language of the golden sample.
	draw_rect(Rect2(0, 0, bounds.size.x, 42), Color("13263a"))
	draw_rect(Rect2(0, 40, bounds.size.x, 5), Color("426781"))
	draw_rect(Rect2(0, 45, bounds.size.x, 3), Color("c5d0d1"))
	for x in range(4, grid_size.x - 3, 9):
		var px := float(x * cell_size)
		draw_rect(Rect2(px, 8, 42, 28), Color("1b2f46"))
		draw_rect(Rect2(px + 5, 13, 32, 18), Color("294f6b"))
		draw_rect(Rect2(px + 7, 15, 28, 3), Color("416e8d"))
		draw_rect(Rect2(px + 18, 20, 3, 3), Color("8d9ba8"))
	for x in [14, 46, 70]:
		var px := float(x * cell_size)
		draw_rect(Rect2(px, 47, 6, 112), Color("7d8c95"))
		draw_rect(Rect2(px - 15, 47, 36, 7), Color("c78b4b"))
		draw_rect(Rect2(px - 2, 54, 10, 6), Color("354452"))
		draw_circle(Vector2(px + 3, 61), 2.5, Color("f0d36d"))
	# Warm work lamps lead the eye toward the first drillable face.
	for point in [Vector2(164, 94), Vector2(224, 138), Vector2(382, 106), Vector2(498, 155)]:
		draw_circle(point, 8, Color("e8b158", 0.10))
		draw_circle(point, 2, Color("ffe29a"))
