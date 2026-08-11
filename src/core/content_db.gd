extends Node

const ContentDefValue = preload("res://src/core/content_def.gd")
const ResultValue = preload("res://src/core/result.gd")

var definitions: Dictionary[StringName, ContentDefValue] = {}
var translations: Array[Translation] = []

func load_all() -> ResultValue:
	definitions.clear()
	_load_localization()
	var dir := DirAccess.open("res://content/definitions")
	if dir == null: return ResultValue.success()
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tres"):
			var definition := load("res://content/definitions/" + name) as ContentDefValue
			if definition != null and definition.id != &"": definitions[definition.id] = definition
		name = dir.get_next()
	return ResultValue.success(definitions.size())

func _load_localization() -> void:
	clear_localization()
	var file := FileAccess.open("res://content/localization/translations.csv", FileAccess.READ)
	if file == null: return
	var lines := file.get_as_text().strip_edges().split("\n")
	if lines.size() < 2: return
	var header := lines[0].strip_edges().split(",")
	if header.size() < 3 or header[0] != "keys": return
	for column in range(1, header.size()):
		var translation := Translation.new()
		translation.locale = header[column].strip_edges()
		for line in lines.slice(1):
			var fields := line.strip_edges().split(",")
			if fields.size() == header.size() and not fields[0].is_empty(): translation.add_message(fields[0], fields[column])
		TranslationServer.add_translation(translation)
		translations.append(translation)

func clear_localization() -> void:
	for translation in translations: TranslationServer.remove_translation(translation)
	translations.clear()

func _exit_tree() -> void:
	clear_localization()

func get_def(id: StringName, expected_type: StringName = &"") -> ContentDefValue:
	var definition: ContentDefValue = definitions.get(id)
	if definition == null: return null
	if expected_type != &"" and definition.get_class() != expected_type: return null
	return definition
