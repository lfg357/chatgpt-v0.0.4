extends Control

func _ready() -> void:
	var result: Resource = AppState.last_run_result
	var settlement: RefCounted = AppState.last_settlement
	$Panel/Title.text = tr("results.title")
	$Panel/Continue.text = tr("results.continue")
	$Panel/Continue.pressed.connect(func(): SceneRouter.go_to(AppState.AppMode.HUB))
	if result == null or settlement == null: $Panel/Details.text = tr("results.empty"); return
	var cargo_lines: Array[String] = []
	for entry in result.cargo: cargo_lines.append("%s x%d  S%d D%d" % [entry.mineral_id, entry.count, entry.scrap_value, entry.data_value])
	var outcome := tr("results.success") if result.success else tr("results.destroyed") if result.failure_reason == &"destroyed" else tr("results.abandoned")
	$Panel/Details.text = tr("results.summary") % [outcome, result.duration_ms / 1000.0, "\n".join(cargo_lines), settlement.banked_resources.scrap, settlement.banked_resources.data, settlement.lost_resources.scrap, settlement.lost_resources.data, result.damage_taken, result.config.seed, result.topology_hash]
