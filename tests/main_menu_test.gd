extends SimTestCase
## Pins the menu eye tracking as bounded, deterministic presentation logic.

func test_pupil_stays_centered_when_pointer_is_centered() -> void:
	assert_true(MainMenu.pupil_offset(Vector2(40.0, 20.0), Vector2(40.0, 20.0)) == Vector2.ZERO, "a centered pointer centers the pupil")

func test_pupil_follows_the_pointer_without_leaving_the_eye() -> void:
	var right := MainMenu.pupil_offset(Vector2.ZERO, Vector2(1000.0, 0.0))
	assert_float_equal(right.x, MainMenu.PUPIL_TRAVEL, "far pointer reaches the horizontal travel limit")
	assert_float_equal(right.y, 0.0, "horizontal pointer has no vertical drift")
	var diagonal := MainMenu.pupil_offset(Vector2.ZERO, Vector2(1000.0, 1000.0))
	assert_true(absf(diagonal.length() - MainMenu.PUPIL_TRAVEL) < 1e-5, "diagonal tracking stays inside the eye")
	assert_true(diagonal.x > 0.0 and diagonal.y > 0.0, "the pupil follows the pointer quadrant")

func test_near_pointer_moves_the_pupil_proportionally() -> void:
	var offset := MainMenu.pupil_offset(Vector2.ZERO, Vector2(100.0, 0.0))
	assert_float_equal(offset.x, 5.5, "near tracking is proportional rather than snapping to its limit")
