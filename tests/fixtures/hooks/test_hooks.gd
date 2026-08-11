extends TestCase
var trace: Array[String] = []
func before_all() -> bool: trace.append("before_all"); return true
func before_each() -> bool: trace.append("before_each"); return true
func test_hooks_run_in_order() -> bool:
	assert_equal(trace, ["before_all", "before_each"])
	trace.append("test")
	return true
func after_each() -> bool: trace.append("after_each"); return true
func after_all() -> bool:
	trace.append("after_all")
	assert_equal(trace, ["before_all", "before_each", "test", "after_each", "after_all"])
	return failures.is_empty()
