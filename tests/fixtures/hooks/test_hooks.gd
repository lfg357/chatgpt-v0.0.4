extends TestCase
var trace: Array[String] = []
func before_all() -> void: trace.append("before_all")
func before_each() -> void: trace.append("before_each")
func test_hooks_run_in_order() -> bool:
	assert_equal(trace, ["before_all", "before_each"])
	trace.append("test")
	return true
func after_each() -> void: trace.append("after_each")
func after_all() -> void:
	trace.append("after_all")
	assert_equal(trace, ["before_all", "before_each", "test", "after_each", "after_all"])
