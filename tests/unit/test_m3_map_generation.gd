extends "res://tests/test_case.gd"

const Generator = preload("res://src/domain/map_generator.gd")
const Validator = preload("res://src/domain/map_validator.gd")

func before_all() -> bool:
	return ContentDB.load_all().ok

func _layer(id: StringName):
	return ContentDB.get_def(id, &"LayerDef")

func test_generation_same_seed_same_hash() -> bool:
	var generator = Generator.new(); var layer = _layer(&"layer_industrial")
	var first = generator.generate(layer, 170101); var second = generator.generate(layer, 170101)
	assert_equal(first.topology_hash, second.topology_hash)
	assert_equal(first.generator_version, 1)
	return true

func test_generation_all_required_nodes_reachable() -> bool:
	var map = Generator.new().generate(_layer(&"layer_industrial"), 14)
	var report = Validator.new().validate(map)
	assert_true(report.valid, str(report.error_codes))
	assert_equal(report.reachable_required_nodes, report.required_nodes)
	return true

func test_safe_spawn_has_no_damage_hazard() -> bool:
	var map = Generator.new().generate(_layer(&"layer_industrial"), 44)
	assert_true(Validator.new().validate(map).valid)
	for y in range(map.spawn_cell.y - 4, map.spawn_cell.y + 5):
		for x in range(map.spawn_cell.x - 4, map.spawn_cell.x + 5): assert_true(map.cell_value(Vector2i(x, y)) < 2)
	return true

func test_generator_falls_back_after_three_failures() -> bool:
	var generator = Generator.new(); generator.force_fail_attempts = 3
	var map = generator.generate(_layer(&"layer_industrial"), 9)
	assert_true(map.used_fallback); assert_equal(map.retry_count, 3); assert_equal(generator.fallback_load_count, 1)
	assert_true(Validator.new().validate(map).valid)
	return true

func test_different_seeds_produce_legal_variation() -> bool:
	var generator = Generator.new(); var layer = _layer(&"layer_bio")
	var a = generator.generate(layer, 1); var b = generator.generate(layer, 2)
	assert_true(Validator.new().validate(a).valid and Validator.new().validate(b).valid)
	assert_true(a.topology_hash != b.topology_hash)
	return true

func test_all_content_ids_unique_and_references_valid() -> bool:
	assert_equal(ContentDB.definitions.size(), 37)
	for layer_id in [&"layer_industrial", &"layer_bio", &"layer_mech"]:
		var layer = _layer(layer_id); assert_true(layer != null)
		for id in [layer.entry_room_id, layer.supply_room_id, layer.relic_room_id, layer.core_room_id] + layer.normal_room_ids + layer.risk_room_ids:
			var room = ContentDB.get_def(id, &"RoomModuleDef")
			assert_true(room != null, String(id)); assert_equal(room.layer_id, layer.id)
	return true

func test_industrial_content_definitions_match_bible() -> bool:
	var ferrite = ContentDB.get_def(&"ore_ferrite", &"MineralDef"); var copper = ContentDB.get_def(&"ore_copper_thread", &"MineralDef"); var lumen = ContentDB.get_def(&"ore_lumen", &"MineralDef")
	assert_equal(ferrite.hardness, 1.0); assert_equal(ferrite.scrap_value, 3)
	assert_equal(copper.hardness, 1.2); assert_equal(copper.scrap_value, 5)
	assert_equal(lumen.hardness, 1.8); assert_equal(lumen.data_value, 2)
	assert_equal(ContentDB.get_def(&"hazard_steam", &"HazardDef").damage, 15)
	assert_equal(ContentDB.get_def(&"creature_scrap_mite", &"CreatureDef").carry_limit, 3)
	return true
