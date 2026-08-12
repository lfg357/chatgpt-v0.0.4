extends "res://tests/test_case.gd"

const Run = preload("res://src/domain/industrial_run_state.gd")
const Config = preload("res://src/domain/run_config.gd")
const Hazards = preload("res://src/domain/industrial_hazards.gd")
const Mite = preload("res://src/domain/scrap_mite_state.gd")
const Economy = preload("res://src/domain/economy_service.gd")
const Snapshot = preload("res://src/core/save_snapshot.gd")
const M2State = preload("res://src/domain/m2_run_state.gd")
const Tools = preload("res://src/domain/m2_tools.gd")

func _run() -> Variant:
	var value = Run.new(); var config = Config.new(); config.layer_id = &"layer_industrial"; config.seed = 170101
	value.start(config, "hash"); return value

func test_combo_window_and_cap() -> bool:
	var run = _run(); assert_true(run.collect(&"ore_ferrite")); assert_equal(run.combo_multiplier(), 1.0)
	for _i in range(12): assert_true(run.collect(&"ore_ferrite"))
	assert_equal(run.combo_multiplier(), 2.0); run.tick(2.6); assert_equal(run.combo_multiplier(), 1.0)
	return true

func test_combo_pause_damage_and_family_switch_reset() -> bool:
	var run = _run(); run.collect(&"ore_ferrite"); run.collect(&"ore_ferrite"); run.tick(3.0, true)
	assert_true(run.combo_remaining > 0.0); run.damage(1); assert_equal(run.combo_multiplier(), 1.0)
	run.collect(&"ore_ferrite"); run.collect(&"ore_copper_thread"); assert_equal(run.combo_multiplier(), 1.0)
	return true

func test_cargo_exact_full_and_overflow_preserves_source() -> bool:
	var run = _run()
	for _i in range(100): assert_true(run.collect(&"ore_ferrite"))
	assert_equal(run.cargo_used, 100); assert_true(not run.collect(&"ore_ferrite")); assert_equal(run.cargo[&"ore_ferrite"].count, 100)
	return true

func test_three_industrial_mineral_values_and_damage() -> bool:
	var run = _run(); run.collect(&"ore_ferrite"); run.collect(&"ore_copper_thread", false, true); run.collect(&"ore_lumen", true)
	assert_equal(run.cargo[&"ore_ferrite"].scrap_value, 3)
	assert_equal(run.cargo[&"ore_copper_thread"].scrap_value, 6)
	assert_equal(run.cargo[&"ore_lumen"].data_value, 1); assert_equal(run.cargo[&"ore_lumen"].damaged_count, 1)
	return true

func test_failure_loses_half_flooring() -> bool:
	var run = _run(); run.collect(&"ore_ferrite"); var result = run.finish(false, &"destroyed")
	var settlement = Economy.new().apply_run_result(result)
	assert_equal(settlement.banked_resources.scrap, 1); assert_equal(settlement.lost_resources.scrap, 2)
	return true

func test_failure_loses_all_unbanked_cores() -> bool:
	var run = _run(); var result = run.finish(false, &"destroyed"); var settlement = Economy.new().apply_run_result(result)
	assert_equal(settlement.banked_resources.core, 0); assert_equal(settlement.lost_resources.core, 0)
	return true

func test_terminal_result_is_mutually_exclusive_and_idempotent() -> bool:
	var run = _run(); var result = run.finish(true); assert_true(result.success)
	assert_true(run.finish(false, &"destroyed") == result); assert_equal(run.phase, run.RunPhase.COMPLETED)
	var economy = Economy.new(); assert_true(economy.apply_run_result(result).committed); assert_equal(economy.apply_run_result(result).error_code, &"already_settled")
	return true

func test_abandon_discards_only_run_state() -> bool:
	var snapshot = Snapshot.new(); snapshot.economy.scrap = 50
	var run = _run(); run.collect(&"ore_ferrite"); var settlement = Economy.new(snapshot).apply_run_result(run.finish(false, &"abandoned"))
	assert_equal(snapshot.economy.scrap, 50); assert_equal(settlement.lost_resources.scrap, 3)
	return true

func test_supply_claim_once_and_clamps() -> bool:
	var run = _run(); var m2 = M2State.new(); m2.durability = 80; var tools = Tools.new(); tools.ammo = 1
	assert_true(run.claim_supply(m2, tools)); assert_equal(m2.durability, 100.0); assert_equal(tools.ammo, 2); assert_true(not run.claim_supply(m2, tools))
	return true

func test_steam_warning_firing_and_single_hit() -> bool:
	var steam = Hazards.SteamVent.new(); steam.tick(1.6); assert_equal(steam.state, steam.State.WARNING); steam.tick(1.5); assert_equal(steam.state, steam.State.FIRING)
	assert_equal(steam.try_hit(1), 15); assert_equal(steam.try_hit(1), 0); steam.tick(1.0, true); assert_equal(steam.state, steam.State.FIRING)
	return true

func test_cable_half_second_damage_and_shutdown() -> bool:
	var cable = Hazards.LiveCable.new(); assert_equal(cable.tick(1.1, true), 8); assert_equal(cable.tick(.4, true), 4)
	assert_true(not cable.drill_power(1.4)); assert_true(cable.drill_power(.1)); assert_equal(cable.tick(1.0, true), 0)
	return true

func test_shale_delay_fall_and_land() -> bool:
	var shale = Hazards.CollapseShale.new(); shale.remove_support(); shale.tick(.59); assert_equal(shale.state, shale.State.WAITING); shale.tick(.01); assert_equal(shale.state, shale.State.FALLING)
	shale.tick(1.0); assert_equal(shale.velocity, 180.0); shale.land(); assert_equal(shale.state, shale.State.LANDED)
	return true

func test_scrap_mite_state_steal_cap_retreat_and_ownership() -> bool:
	var mite = Mite.new(); var available: Array[String] = ["a", "b", "c", "d"]
	for _i in range(4): var stolen := mite.tick(2.0, available); if not stolen.is_empty(): available.erase(stolen)
	assert_equal(mite.carried_ids.size(), 3); assert_equal(available.size(), 1)
	mite.disturb(); mite.tick(5.9, []); assert_equal(mite.state, mite.State.RETREAT); mite.tick(.1, []); assert_equal(mite.state, mite.State.CALM)
	var released := mite.release_all(); assert_equal(released.size(), 3); assert_equal(mite.carried_ids.size(), 0)
	return true

func test_boiler_timeout_retries_and_completion_stops_hazard() -> bool:
	var run = _run(); run.boiler.active = true; run.tick(45.0); assert_equal(run.damage_taken, 30); assert_equal(run.boiler.timeout_pulses, 1)
	run.tick(5.0); assert_true(run.boiler.active)
	for index in range(3): assert_true(run.boiler.interact_valve(index, .8))
	assert_true(run.boiler.completed); var damage: int = run.damage_taken; run.tick(50.0); assert_equal(run.damage_taken, damage)
	return true
