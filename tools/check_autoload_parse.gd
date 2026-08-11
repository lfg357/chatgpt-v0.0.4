extends SceneTree

## `--script` starts project autoloads without guaranteeing an editor-generated
## global-class cache. Load every registered core autoload explicitly and make a
## parse/load failure an unambiguous non-zero process result.
const REQUIRED_AUTOLOADS := [&"AppState", &"ContentDB", &"SaveService", &"AudioService", &"InputService", &"SceneRouter"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--selftest-failure" in OS.get_cmdline_user_args():
		push_error("Autoload parse gate deliberate failure")
		quit(1)
		return
	var failures: Array[String] = []
	for autoload_name in REQUIRED_AUTOLOADS:
		var configured := String(ProjectSettings.get_setting("autoload/" + autoload_name, ""))
		var path := configured.trim_prefix("*")
		if path.is_empty():
			failures.append("missing configuration for " + autoload_name)
			continue
		var script := load(path)
		if script == null or not script.can_instantiate():
			failures.append("cannot parse " + autoload_name + " at " + path)
			continue
		if script.get_instance_base_type() != "Node":
			failures.append("autoload is not a Node: " + autoload_name)
	if failures.is_empty():
		print("AUTOLOAD_PARSE passed count=%d" % REQUIRED_AUTOLOADS.size())
		quit(0)
		return
	for failure in failures:
		push_error("AUTOLOAD_PARSE " + failure)
	quit(1)
