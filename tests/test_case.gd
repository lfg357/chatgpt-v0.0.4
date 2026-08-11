class_name TestCase extends RefCounted
var failures: Array[String] = []
var timeout_seconds: float = 1.0
var runner_tree: SceneTree
func assert_true(value: bool, message: String = "") -> void: if not value: failures.append("assert_true: " + message)
func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void: if actual != expected: failures.append("assert_equal expected %s got %s %s" % [str(expected), str(actual), message])
func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void: if absf(actual - expected) > tolerance: failures.append("assert_near: " + message)
func assert_contains(value: Variant, needle: Variant, message: String = "") -> void: if not (needle in value): failures.append("assert_contains: " + message)
