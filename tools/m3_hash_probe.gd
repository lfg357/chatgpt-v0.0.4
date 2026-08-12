extends SceneTree

const Generator = preload("res://src/domain/map_generator.gd")
const ContentDBValue = preload("res://src/core/content_db.gd")

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var database = ContentDBValue.new(); root.add_child(database)
	if not database.load_all().ok: push_error("content_load_failed"); quit(1); return
	var inputs := [[&"layer_industrial", 170101], [&"layer_bio", 240203], [&"layer_mech", 310307]]
	var hashes := {}
	for input in inputs:
		var generator = Generator.new(); generator.content_db = database
		var map = generator.generate(database.get_def(input[0], &"LayerDef"), input[1])
		hashes[String(input[0])] = map.topology_hash
	print("M3_HASH_PROBE " + JSON.stringify(hashes))
	quit(0)

