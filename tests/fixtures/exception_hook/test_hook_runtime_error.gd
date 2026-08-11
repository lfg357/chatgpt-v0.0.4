extends "res://tests/test_case.gd"

var cleanup_ran := false

func before_each() -> bool:
	var invalid: Variant = null
	invalid.not_a_method()
	return true

func after_each() -> bool:
	cleanup_ran = true
	return true

func after_all() -> bool:
	assert_true(cleanup_ran, "cleanup must run after a hook runtime error")
	return cleanup_ran

func test_never_runs_after_broken_hook() -> bool:
	return true
