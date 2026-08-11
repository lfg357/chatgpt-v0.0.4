extends SceneTree

const TestCase = preload("res://tests/test_case.gd")
var passed := 0
var failed := 0
var discovered := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if "--selftest-failure" in args:
		print("SELFTEST deliberate failure"); quit(1); return
	if "--selftest-zero" in args:
		print("SELFTEST zero cases"); quit(1); return
	run_tests()
	print("TEST SUMMARY cases=%d passed=%d failed=%d" % [discovered, passed, failed])
	quit(0 if failed == 0 and discovered > 0 else 1)

func run_tests() -> void:
	var files: Array[String] = []
	_collect("res://tests/unit", files)
	for path in files:
		var script := load(path)
		if script == null:
			discovered += 1
			failed += 1
			print("FAIL unable to load test script: ", path)
			continue
		var instance = script.new()
		if instance.has_method("before_all"): instance.before_all()
		for method in instance.get_method_list():
			var method_name: String = method.name
			if method_name.begins_with("test_"):
				discovered += 1
				if instance.has_method("before_each"): instance.before_each()
				var before: int = instance.failures.size()
				var returned: Variant = instance.call(method_name)
				if instance.has_method("after_each"): instance.after_each()
				if instance.failures.size() == before and returned == true: passed += 1
				else: failed += 1; print("FAIL ", path, "::", method_name, " ", instance.failures.back())
		if instance.has_method("after_all"): instance.after_all()

func _collect(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin(); var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".gd") and entry.begins_with("test_"): files.append(path + "/" + entry)
		entry = dir.get_next()
