class_name AppSettings extends RefCounted

var schema_version: int = 1
var locale: String = "auto"
var display: Dictionary = {"fullscreen": false, "vsync": true}
var audio: Dictionary = {"master": 80, "music": 70, "sfx": 85}
var accessibility: Dictionary = {"screen_shake": 70, "flash": 60, "gamepad_vibration": true, "deadzone": 0.18, "drill_hold": true}
var input_bindings: Dictionary = {}
var local_playtest_logging: bool = true

func to_dict() -> Dictionary:
	return {"schema_version": schema_version, "locale": locale, "display": display, "audio": audio, "accessibility": accessibility, "input_bindings": input_bindings, "local_playtest_logging": local_playtest_logging}
