extends TestCase
const BenchmarkScene = preload("res://scenes/benchmarks/m1_benchmark.tscn")

func test_benchmark_scene_declares_fixed_load() -> bool:
	var benchmark := BenchmarkScene.instantiate()
	assert_true(benchmark.get_script() != null, "benchmark root script must compile")
	var terrain_world: Node = benchmark.get_node("TerrainWorld")
	assert_equal(terrain_world.grid_size, Vector2i(64, 32))
	assert_true(not terrain_world.initially_solid)
	benchmark.free()
	return true
