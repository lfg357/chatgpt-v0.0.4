class_name Result extends RefCounted

var ok: bool = false
var code: StringName = &"unknown"
var message_key: StringName = &""
var data: Variant

static func success(value: Variant = null):
	# Do not refer to this script's class_name: --script cold starts do not have
	# the editor-generated global class cache yet.
	var result = load("res://src/core/result.gd").new()
	result.ok = true
	result.code = &"ok"
	result.data = value
	return result

static func failure(error_code: StringName, key: StringName = &""):
	var result = load("res://src/core/result.gd").new()
	result.code = error_code
	result.message_key = key
	return result
