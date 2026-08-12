extends SceneTree

const Generator = preload("res://src/domain/map_generator.gd")
const Validator = preload("res://src/domain/map_validator.gd")
const ContentDBValue = preload("res://src/core/content_db.gd")
const LAYERS: Array[StringName] = [&"layer_industrial", &"layer_bio", &"layer_mech"]
const EXTRA_SEEDS := {&"layer_industrial": 170101, &"layer_bio": 240203, &"layer_mech": 310307}

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var quick := "--quick" in OS.get_cmdline_user_args()
	var seed_count := 20 if quick else 1000
	var database = ContentDBValue.new(); root.add_child(database)
	var loaded = database.load_all()
	if not loaded.ok: _fail("content_load_failed")
	var report := {"commit_sha": _commit_sha(), "godot_version": Engine.get_version_info().string, "generator_version": 1, "content_version": 1, "seed_range": [0, seed_count - 1], "system": OS.get_distribution_name(), "cpu": OS.get_processor_name(), "build_type": "debug" if OS.is_debug_build() else "release", "layers": {}}
	var failures: Array[Dictionary] = []
	for layer_id in LAYERS:
		var layer = database.get_def(layer_id, &"LayerDef")
		var times: Array[float] = []; var hashes: Array[String] = []; var fallback_count := 0
		for seed in range(seed_count):
			var generator = Generator.new(); generator.content_db = database; var started := Time.get_ticks_usec()
			var map = generator.generate(layer, seed); var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
			var validation = Validator.new().validate(map)
			var repeat_generator = Generator.new(); repeat_generator.content_db = database
			var repeated = repeat_generator.generate(layer, seed)
			if not validation.valid or repeated.topology_hash != map.topology_hash:
				failures.append({"layer_id": String(layer_id), "seed": seed, "errors": validation.error_codes, "hash": map.topology_hash, "repeat_hash": repeated.topology_hash})
			times.append(elapsed); hashes.append(map.topology_hash)
			if map.used_fallback: fallback_count += 1
		for special_seed in [int(EXTRA_SEEDS[layer_id])]:
			var special_generator = Generator.new(); special_generator.content_db = database
			var special = special_generator.generate(layer, special_seed)
			if not Validator.new().validate(special).valid: failures.append({"layer_id": String(layer_id), "seed": special_seed, "errors": ["special_seed_invalid"]})
		var forced = Generator.new(); forced.content_db = database; forced.force_fail_attempts = 3
		var fallback = forced.generate(layer, -1)
		if not fallback.used_fallback or not Validator.new().validate(fallback).valid: failures.append({"layer_id": String(layer_id), "seed": -1, "errors": ["fallback_invalid"]})
		times.sort(); hashes.sort()
		report.layers[String(layer_id)] = {"success_count": seed_count - _failure_count(failures, layer_id), "failure_count": _failure_count(failures, layer_id), "fallback_count": fallback_count, "average_ms": _average(times), "p95_ms": _percentile(times, .95), "p99_ms": _percentile(times, .99), "topology_hash_summary": "|".join(hashes).sha256_text(), "first_seed": EXTRA_SEEDS[layer_id], "fallback_valid": Validator.new().validate(fallback).valid}
	_write_json("res://reports/m3_seed_validation.json", report)
	_write_json("res://reports/m3_generation_performance.json", {"commit_sha": report.commit_sha, "godot_version": report.godot_version, "cpu": report.cpu, "system": report.system, "build_type": report.build_type, "layers": report.layers})
	if not failures.is_empty(): _write_json("res://reports/m3_seed_failures.json", failures)
	print("M3_SEED_VALIDATION layers=3 seeds_per_layer=%d failures=%d" % [seed_count, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _failure_count(failures: Array[Dictionary], layer_id: StringName) -> int:
	var count := 0
	for failure in failures:
		if failure.layer_id == String(layer_id) and int(failure.seed) >= 0 and int(failure.seed) < 1000: count += 1
	return count

func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values: total += value
	return total / maxi(1, values.size())

func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty(): return 0.0
	return values[clampi(ceili(values.size() * quantile) - 1, 0, values.size() - 1)]

func _write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: _fail("report_write_failed")
	file.store_string(JSON.stringify(data, "\t")); file.close()

func _commit_sha() -> String:
	var output: Array[String] = []; var code := OS.execute("git", ["rev-parse", "HEAD"], output, true)
	return output[0].strip_edges() if code == 0 and not output.is_empty() else "uncommitted"

func _fail(message: String) -> void:
	push_error(message); quit(1)
