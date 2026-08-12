class_name CargoEntry extends Resource

var mineral_id: StringName
var count: int
var scrap_value: int
var data_value: int
var damaged_count: int

func duplicate_entry():
	var copy = load("res://src/domain/cargo_entry.gd").new()
	copy.mineral_id = mineral_id; copy.count = count; copy.scrap_value = scrap_value
	copy.data_value = data_value; copy.damaged_count = damaged_count
	return copy

