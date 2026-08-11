class_name TerrainWorld extends Node2D

## Presentation and collision adapter for TerrainService.
## TerrainService remains the only terrain truth; dirty chunks disable old collision
## immediately, then rebuild under the service's per-tick budget.
@export var cell_size: int = 8
@export var grid_size := Vector2i(64, 32)
var terrain := TerrainService.new()
var chunk_bodies: Dictionary[Vector2i, StaticBody2D] = {}

func _ready() -> void:
	terrain.setup(grid_size.x, grid_size.y)
	queue_redraw()

func request_damage(cell: Vector2i, amount: int = 1) -> bool:
	return terrain.request_damage(cell, amount)

func request_explosion(center: Vector2i, radius: int) -> int:
	return terrain.request_explosion(center, radius)

func _physics_process(_delta: float) -> void:
	var changed := terrain.commit_damage()
	if changed > 0:
		_disable_dirty_chunk_collision()
		queue_redraw()
	var dirty_before := terrain.dirty_chunks.duplicate()
	terrain.physics_tick()
	for chunk in dirty_before:
		if not terrain.dirty_chunks.has(chunk): _rebuild_chunk_collision(chunk)

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
	var start := chunk * TerrainService.CHUNK_SIZE
	var end := Vector2i(mini(start.x + TerrainService.CHUNK_SIZE, grid_size.x), mini(start.y + TerrainService.CHUNK_SIZE, grid_size.y))
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
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if terrain.is_solid(Vector2i(x, y)):
				draw_rect(Rect2(x * cell_size, y * cell_size, cell_size - 1, cell_size - 1), Color("53606f"))
