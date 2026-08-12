class_name Settlement extends RefCounted

var banked_resources: Dictionary = {"scrap": 0, "core": 0, "data": 0}
var lost_resources: Dictionary = {"scrap": 0, "core": 0, "data": 0}
var contract_rewards: Dictionary = {}
var new_unlock_ids: Array[StringName] = []
var archive_ids: Array[StringName] = []
var outcome: StringName
var committed: bool = false
var error_code: StringName

