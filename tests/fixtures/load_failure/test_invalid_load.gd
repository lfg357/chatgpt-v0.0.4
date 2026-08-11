extends TestCase

func test_invalid_load() -> bool:
	this is intentionally invalid syntax
*** Add File: tests/fixtures/exception/test_runtime_error.gd
extends TestCase

var cleanup_ran := false

func test_runtime_error_is_counted() -> bool:
	var invalid: Variant = null
	invalid.not_a_method()
	return true

func after_each() -> bool:
	cleanup_ran = true
	return true

func after_all() -> bool:
	assert_true(cleanup_ran, "cleanup must run after a runtime error")
	return failures.is_empty()
