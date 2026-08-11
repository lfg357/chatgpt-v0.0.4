extends TestCase
func test_app_mode_rejects_illegal_transition() -> bool:
	var state := preload("res://src/core/app_state.gd").new()
	assert_true(not state.request_transition(state.AppMode.DIVE).ok)
	return true
func test_save_snapshot_defaults_are_non_negative() -> bool:
	var snapshot := preload("res://src/core/save_snapshot.gd").new()
	assert_equal(snapshot.economy["scrap"], 0)
	return true
