class_name Result extends RefCounted

var ok: bool = false
var code: StringName = &"unknown"
var message_key: StringName = &""
var data: Variant

static func success(value: Variant = null) -> Result:
	var result := Result.new()
	result.ok = true
	result.code = &"ok"
	result.data = value
	return result

static func failure(error_code: StringName, key: StringName = &"") -> Result:
	var result := Result.new()
	result.code = error_code
	result.message_key = key
	return result
