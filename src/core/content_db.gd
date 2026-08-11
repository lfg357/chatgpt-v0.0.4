extends Node

var definitions: Dictionary[StringName, ContentDef] = {}

func load_all() -> Result:
	definitions.clear()
	var dir := DirAccess.open("res://content/definitions")
	if dir == null: return Result.success()
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tres"):
			var definition := load("res://content/definitions/" + name) as ContentDef
			if definition != null and definition.id != &"": definitions[definition.id] = definition
		name = dir.get_next()
	return Result.success(definitions.size())

func get_def(id: StringName, expected_type: StringName = &"") -> ContentDef:
	var definition: ContentDef = definitions.get(id)
	if definition == null: return null
	if expected_type != &"" and definition.get_class() != expected_type: return null
	return definition
