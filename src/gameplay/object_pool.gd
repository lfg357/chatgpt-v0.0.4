class_name ObjectPool extends RefCounted

var available: Array[Dictionary] = []
var active: Array[Dictionary] = []
var total_created: int = 0

func warm(count: int) -> void:
	for _i in count: available.append({"active": false})
	total_created += count

func acquire() -> Dictionary:
	var item: Dictionary
	if available.is_empty():
		item = {"active": false}; total_created += 1
	else: item = available.pop_back()
	item["active"] = true; active.append(item)
	return item

func release(item: Dictionary) -> void:
	if active.has(item):
		active.erase(item)
		item["active"] = false; available.append(item)
