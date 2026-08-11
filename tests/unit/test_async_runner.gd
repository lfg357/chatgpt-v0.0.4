extends TestCase

func test_runner_awaits_signal_test_case() -> Signal:
	return runner_tree.create_timer(0.001).timeout
