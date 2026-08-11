extends SceneTree

var passed := 0
var failed := 0
var discovered := 0

class AwaitRace extends RefCounted:
	signal done(success: bool)
	var resolved := false
	func resolve(success: bool) -> void:
		if resolved: return
		resolved = true
		done.emit(success)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--selftest-failure" in args:
		print("SELFTEST deliberate failure"); quit(1); return
	if "--selftest-zero" in args:
		print("SELFTEST zero cases"); quit(1); return
	var root := "res://tests/unit"
	for arg in args:
		if arg.begins_with("--test-root="): root = arg.trim_prefix("--test-root=")
	await run_tests(root)
	print("TEST SUMMARY cases=%d passed=%d failed=%d" % [discovered, passed, failed])
	quit(0 if failed == 0 and discovered > 0 else 1)

func run_tests(root: String) -> void:
	var files: Array[String] = []
	_collect(root, files)
	files.sort()
	for path in files: await _run_file(path)

func _run_file(path: String) -> void:
	var script := load(path)
	if script == null:
		discovered += 1; failed += 1; print("FAIL unable to load test script: ", path); return
	var instance = script.new()
	if not instance.has_method("assert_true"):
		discovered += 1; failed += 1; print("FAIL not a TestCase: ", path); return
	instance.runner_tree = self
	if instance.has_method("before_all"): instance.before_all()
	for method in instance.get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			discovered += 1
			if instance.has_method("before_each"): instance.before_each()
			var before: int = instance.failures.size()
			var started := Time.get_ticks_usec()
			var returned: Variant = instance.call(method_name)
			if returned is Signal:
				if not await _await_signal(returned, instance.timeout_seconds):
					instance.failures.append("async timeout after %.3fs" % instance.timeout_seconds)
				returned = instance.failures.size() == before
			var elapsed := float(Time.get_ticks_usec() - started) / 1_000_000.0
			if not (returned is Signal) and elapsed > instance.timeout_seconds:
				instance.failures.append("timeout after %.3fs (limit %.3fs)" % [elapsed, instance.timeout_seconds])
			if instance.has_method("after_each"): instance.after_each()
			if instance.failures.size() == before and returned == true:
				passed += 1
			else:
				failed += 1
				var reason: String = instance.failures.back() if instance.failures.size() > before else "test did not return true"
				print("FAIL ", path, "::", method_name, " ", reason)
	var after_before: int = instance.failures.size()
	if instance.has_method("after_all"): instance.after_all()
	if instance.failures.size() > after_before:
		failed += 1
		print("FAIL ", path, "::after_all ", instance.failures.back())

func _await_signal(input_signal: Signal, timeout_seconds: float) -> bool:
	var race := AwaitRace.new()
	input_signal.connect(func(): race.resolve(true), CONNECT_ONE_SHOT)
	create_timer(timeout_seconds).timeout.connect(func(): race.resolve(false), CONNECT_ONE_SHOT)
	return await race.done

func _collect(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := path.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_collect(full_path, files)
		elif entry.ends_with(".gd") and entry.begins_with("test_"):
			files.append(full_path)
		entry = dir.get_next()
