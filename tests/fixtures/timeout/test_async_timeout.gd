extends "res://tests/test_case.gd"

func before_all() -> bool: timeout_seconds = 0.001; return true

func test_async_timeout_is_detected() -> Signal:
	return runner_tree.create_timer(0.05).timeout
