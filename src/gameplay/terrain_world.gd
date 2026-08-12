class_name TerrainWorld extends Node2D

const TerrainServiceValue = preload("res://src/gameplay/terrain_service.gd")
const INDUSTRIAL_TILES = preload("res://assets/sprites/industrial_tiles.png")

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
	# Fixed M2 industrial tunnel: a readable horizontal chamber, drill seam,
	# lower destructible stratum, tool bay and extraction lane.
	for y in range(7, grid_size.y - 7):
		for x in range(2, grid_size.x - 2):
			terrain.set_initial_empty(Vector2i(x, y))
	# Breakable seam separating the safe spawn from the tool chamber.
	for y in range(16, grid_size.y - 7):
		for x in range(31, 36):
			terrain.restore_solid(Vector2i(x, y))
	# A low ledge gives collision and downward-drilling coverage without obscuring the chamber.
	for y in range(grid_size.y - 11, grid_size.y - 7):
		for x in range(52, 62):
			terrain.restore_solid(Vector2i(x, y))

func request_damage(cell: Vector2i, amount: int = 1) -> bool:
	return terrain.request_damage(cell, amount)

func request_explosion(center: Vector2i, radius: int) -> int:
	return terrain.request_explosion(center, radius)

func restore_solid(cell: Vector2i) -> bool:
	return terrain.restore_solid(cell)

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
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid_size * cell_size)), Color("0c1421"))
	# Industrial silhouettes establish ceiling machinery and a readable tunnel scale.
	for x in range(4, grid_size.x - 4, 12):
		draw_rect(Rect2(x * cell_size, 7 * cell_size, 2, 17 * cell_size), Color("788894"))
		draw_rect(Rect2(x * cell_size - 10, 7 * cell_size, 22, 5), Color("c78b4b"))
		draw_circle(Vector2(x * cell_size + 1, 12 * cell_size), 3.0, Color("f0d36d"))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if terrain.is_solid(Vector2i(x, y)):
				var pattern := posmod(x * 7 + y * 11, 29)
				var variant := 3
				if pattern == 0: variant = 0
				elif pattern == 7: variant = 1
				var source := Rect2(variant * 16, 0, 16, 16)
				draw_texture_rect_region(INDUSTRIAL_TILES, Rect2(x * cell_size, y * cell_size, cell_size, cell_size), source)
