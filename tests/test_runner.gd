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
	if script == null or not script.can_instantiate():
		discovered += 1; failed += 1; print("FAIL unable to load test script: ", path); return
	var instance = script.new()
	if not instance.has_method("assert_true"):
		discovered += 1; failed += 1; print("FAIL not a TestCase: ", path); return
	instance.runner_tree = self
	var before_all_ok := await _invoke_hook(instance, "before_all")
	for method in instance.get_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			discovered += 1
			if not before_all_ok:
				failed += 1
				continue
			if not await _invoke_hook(instance, "before_each"):
				failed += 1
				await _invoke_hook(instance, "after_each")
				continue
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
			var after_each_ok := await _invoke_hook(instance, "after_each")
			if instance.failures.size() == before and returned == true and after_each_ok:
				passed += 1
			else:
				failed += 1
				var reason: String = instance.failures.back() if instance.failures.size() > before else "test did not return true"
				print("FAIL ", path, "::", method_name, " ", reason)
	if not await _invoke_hook(instance, "after_all"):
		failed += 1
	instance.runner_tree = null
	instance = null

func _invoke_hook(instance: Variant, hook_name: String) -> bool:
	if not instance.has_method(hook_name): return true
	var before: int = instance.failures.size()
	var returned: Variant = instance.call(hook_name)
	if returned is Signal:
		if not await _await_signal(returned, instance.timeout_seconds):
			instance.failures.append("hook %s async timeout" % hook_name)
			return false
	if returned != true:
		instance.failures.append("hook %s did not return true" % hook_name)
	if instance.failures.size() > before:
		print("FAIL hook ", hook_name, ": ", instance.failures.back())
		return false
	return true

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
