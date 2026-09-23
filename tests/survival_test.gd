extends SimTestCase
## Pins the poisoned opening as logical game state: wake time is free,
## leaving the stasis bay is terminal safety, and an expired clock kills.

func test_poison_clock_waits_until_the_survivor_is_awake() -> void:
	var game := Game.new()
	for _tick: int in range(120):
		game.tick()
	assert_int_equal(game.poison_ticks_remaining, Game.POISON_LIMIT_TICKS, "the wake presentation spends none of the escape budget")
	assert_true(game.is_poisoned(), "the survivor wakes poisoned")

func test_poison_kills_when_the_escape_clock_expires() -> void:
	var game := Game.new()
	game.phase.wake_complete()
	for _tick: int in range(Game.POISON_LIMIT_TICKS - 1):
		game.tick()
	assert_true(game.is_poisoned(), "the last playable tick is still alive")
	assert_int_equal(game.poison_seconds_remaining(), 1, "the display rounds the final partial second up")
	game.tick()
	assert_true(game.is_dead(), "the deadline makes death terminal")
	assert_int_equal(game.poison_seconds_remaining(), 0, "the dead clock lands on zero")
	game.escape_poison_zone()
	assert_true(game.is_dead(), "escaping after the deadline cannot resurrect the survivor")

func test_leaving_the_stasis_bay_ends_the_poison_clock() -> void:
	var game := Game.new()
	game.phase.wake_complete()
	for _tick: int in range(90):
		game.tick()
	var remaining := game.poison_ticks_remaining
	game.escape_poison_zone()
	assert_false(game.is_poisoned(), "crossing the hatch clears the poisoned state")
	assert_false(game.is_dead(), "a timely escape survives")
	for _tick: int in range(Game.POISON_LIMIT_TICKS):
		game.tick()
	assert_int_equal(game.poison_ticks_remaining, remaining, "safe state freezes the deadline")
