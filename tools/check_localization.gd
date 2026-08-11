extends SceneTree
func _init() -> void:
	var file := FileAccess.open("res://content/localization/translations.csv", FileAccess.READ)
	var lines := file.get_as_text().strip_edges().split("\n")
	var keys: Array[String] = []
	for line in lines.slice(1):
		var fields := line.strip_edges().split(",")
		if fields.size() != 3 or fields[0].is_empty() or fields[1].is_empty() or fields[2].is_empty():
			push_error("Invalid localization row: " + line); quit(1); return
		keys.append(fields[0])
	if keys.size() == 0: push_error("No localization keys"); quit(1); return
	print("Localization key sets verified: ", keys.size())
	quit(0)
