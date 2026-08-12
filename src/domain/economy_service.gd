class_name EconomyService extends RefCounted

const SettlementValue = preload("res://src/domain/settlement.gd")
var snapshot: Variant
var applied_run_ids: Dictionary = {}

func _init(profile_snapshot: Variant = null) -> void: snapshot = profile_snapshot

func apply_run_result(result: Variant):
	var settlement = SettlementValue.new()
	if result == null or result.run_id.is_empty(): settlement.error_code = &"invalid_result"; return settlement
	if applied_run_ids.has(result.run_id): settlement.error_code = &"already_settled"; return settlement
	var totals := {"scrap": 0, "data": 0, "core": 0}
	for entry in result.cargo:
		totals.scrap += entry.scrap_value; totals.data += entry.data_value
	if result.success:
		settlement.outcome = &"success"; settlement.banked_resources = totals.duplicate()
	elif result.failure_reason == &"destroyed":
		settlement.outcome = &"destroyed"
		settlement.banked_resources.scrap = floori(totals.scrap * 0.5)
		settlement.banked_resources.data = floori(totals.data * 0.5)
		settlement.lost_resources.scrap = totals.scrap - settlement.banked_resources.scrap
		settlement.lost_resources.data = totals.data - settlement.banked_resources.data
		settlement.lost_resources.core = totals.core
	elif result.failure_reason == &"abandoned":
		settlement.outcome = &"abandoned"; settlement.lost_resources = totals.duplicate()
	else: settlement.error_code = &"invalid_outcome"; return settlement
	if snapshot != null:
		var economy_copy: Dictionary = snapshot.economy.duplicate(true)
		for resource_id in settlement.banked_resources:
			economy_copy[resource_id] = int(economy_copy.get(resource_id, 0)) + int(settlement.banked_resources[resource_id])
			if economy_copy[resource_id] < 0: settlement.error_code = &"negative_resource"; return settlement
		snapshot.economy = economy_copy
	applied_run_ids[result.run_id] = true; settlement.committed = true
	return settlement

