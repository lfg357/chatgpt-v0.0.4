extends TestCase

func before_all() -> void: timeout_seconds = 0.001

func test_async_timeout_is_detected() -> Signal:
	return runner_tree.create_timer(0.05).timeout
