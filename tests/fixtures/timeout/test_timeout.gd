extends TestCase
func before_all() -> void: timeout_seconds = 0.001
func test_timeout_is_detected() -> bool:
	var until := Time.get_ticks_usec() + 10_000
	while Time.get_ticks_usec() < until: pass
	return true
