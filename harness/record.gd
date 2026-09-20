extends SceneTree
## The gameplay-lane recorder: walks the routes the scenarios pin —
## pod to rod, rod to the jammed door, down the hallway, into the
## power room and back — at whatever speed the sim's controller
## currently walks, and writes a scenario JSON whose replay reproduces
## the walk tick for tick. Straight-line legs between discrete looks
## keep the geometry identical to the recorded lanes, so a walk-speed
## change means one re-record, not a re-authored route. Headless:
##   godot --headless --path . -s harness/record.gd -- <lane>
## The keyboard-turn lane steers the same route with held turn and
## pitch keys plus one remainder look, covering the keyboard's look
## channel the way its scenario always has.

const DT: float = 1.0 / 60.0
const TURN_PER_TICK: float = InputPlane.TURN_SPEED / 60.0
const PITCH_PER_TICK: float = InputPlane.PITCH_SPEED / 60.0
const GET_UP_PRESS_TICK: int = 284

const SEEDS := {
	"hallway": 1234,
	"rod-pickup": 1235,
	"power-room": 1236,
	"gameplay-full": 1234,
	"gameplay-keyboard-turn": 1234,
}

## Where the route turns inside the power room: the aperture centers
## on x = 27 while the console sits against the west wall, so the
## room is entered and left through one shared bend north of the
## generator's hull.
const POWER_ROOM_BEND := Vector2(26.9, -3.2)
const HALL_DEEP := Vector2(12.71, 0.29)
const HALL_DEEP_AGAIN := Vector2(12.61, 0.32)
const MID_ROOM := Vector2(-0.71, 1.49)
const POWER_DOORWAY_FLOOR := Vector2(27.0, -0.29)

var game: Game
var motion: PlayerMotion
var plane: InputPlane
var adapter: InputPlane.ScriptedAdapter
var lane := ""
var keyboard := false
var yaw: float
var pitch: float
var tick: int = 0
var failed := false
var _wake_delivered := false
var actions: Array = []
var beats: Array = []
var rod_center: Vector2
var hatch_center: Vector2
var switch_center: Vector2
var power_door_center: Vector2
var console_center: Vector2

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_bail("usage: godot --headless --path . -s harness/record.gd -- <lane>")
		return
	lane = args[0]
	if not SEEDS.has(lane):
		_bail("unknown lane `%s`" % lane)
		return
	keyboard = lane == "gameplay-keyboard-turn"
	game = Game.new()
	motion = PlayerMotion.new()
	plane = InputPlane.new()
	adapter = InputPlane.ScriptedAdapter.new()
	# The app's WakePresent opens the wake machine's readiness barrier
	# from its own _ready; headless, the recorder opens it itself so
	# the timeline starts at tick 0 exactly as the lane's first drive.
	game.wake_state.mark_ready()
	yaw = game.registry.player_pod().placement().yaw_radians
	pitch = InputPlane.PITCH_LIMIT
	rod_center = Rod.floor_center()
	hatch_center = game.registry.hatch().center
	switch_center = _xz(Hallway.switch_act_center())
	power_door_center = _xz(PowerRoom.door_act_center())
	console_center = _xz(PowerRoom.console_act_center())
	match lane:
		"hallway":
			_route_hallway()
		"rod-pickup":
			_route_rod_pickup()
		"power-room":
			_route_power_room()
		"gameplay-full", "gameplay-keyboard-turn":
			_route_gameplay_full()
	if not failed:
		_write()

## The hallway lane: rod, jammed door, deep into the dark hall, back
## to the switch, then deep again to see the lit corridor.
func _route_hallway() -> void:
	_wake(true)
	_pick_up_rod(false)
	_open_stasis_door(true)
	_walk_to_point(HALL_DEEP)
	_pin("hall-dark")
	_flip_switch()
	_walk_to_point(HALL_DEEP_AGAIN)
	_pin("hall-corridor")

## The rod-pickup lane: the earliest beats only — the rod coming into
## reach, the pickup itself, and the door opening on the carried rod.
func _route_rod_pickup() -> void:
	_wake(false)
	_pick_up_rod(true)
	_open_stasis_door(true)

## The power-room lane: the whole climb — rod, door, switch, the
## corridor's east end, the power room's console, and the walk back
## out to watch the hall turn white.
func _route_power_room() -> void:
	_wake(true)
	_pick_up_rod(false)
	_open_stasis_door(true)
	_flip_switch()
	_walk_toward(power_door_center, 1.5)
	_aim_at(power_door_center, -15.0)
	_press("interact")
	_wait_power_door_open()
	_settle(14)
	_pin("power-door-opened")
	_walk_to_point(POWER_DOORWAY_FLOOR)
	_walk_to_point(POWER_ROOM_BEND)
	_walk_toward(console_center, 1.4)
	_aim_at(console_center, -45.0)
	_press("interact")
	if motion.console_presses != 1:
		_bail("the console press did not land")
	# The generator's glow and the white strips retarget on the press
	# and settle over Lighting.FIXTURE_SETTLE_TICKS; the beat pins
	# after the settle so its capture and its generator-lit evidence
	# read the room already handed off to regular white.
	_settle(40)
	_pin("power-active")
	_walk_to_point(POWER_ROOM_BEND)
	_walk_to_point(POWER_DOORWAY_FLOOR)
	_snap_look(deg_to_rad(-90.0), 0.0)
	_settle(240)
	_pin("hall-white")

## The gameplay lane and its keyboard-steered twin: mid-room, rod,
## and the jammed door at the hallway's mouth.
func _route_gameplay_full() -> void:
	_wake(true)
	_walk_to_point(MID_ROOM)
	_pin("mid-room")
	_pick_up_rod(false)
	_walk_toward(hatch_center, 1.5)
	_pin("at-door")
	_aim_at(hatch_center, -15.0)
	_press("interact")
	_wait_door_open()
	_settle(14)
	_pin("door-opened")

## The opening: wake beats, the get-up press at its authored tick,
## and the standing hand-off to the walk.
func _wake(pins_standing: bool) -> void:
	if lane != "rod-pickup":
		_pin_at("eyes-closed", 31)
		_pin_at("first-blink", 131)
		_pin_at("shapes-resolving", 171)
	while tick < GET_UP_PRESS_TICK:
		_idle_tick()
	_press("activate")
	for _i: int in range(60):
		if motion.state() == PlayerMotion.BodyState.WALK:
			break
		_idle_tick()
	if motion.state() != PlayerMotion.BodyState.WALK:
		_bail("the get-up never completed")
	if pins_standing:
		_pin("standing")

## Walk to the rod stand, picking up the rod with one interact press.
func _pick_up_rod(pin_reach: bool) -> void:
	_walk_toward(rod_center, 0.85, pin_reach)
	_aim_at(rod_center, -55.0)
	_press("interact")
	if not motion.rod_carried:
		_bail("the rod press did not land")
	_settle(3)
	_pin("rod-picked-up")

## Open the stasis room's jammed door on the carried rod.
func _open_stasis_door(pin_opened: bool) -> void:
	_walk_toward(hatch_center, 1.5)
	_aim_at(hatch_center, -15.0)
	_press("interact")
	_wait_door_open()
	_settle(14)
	if pin_opened:
		_pin("door-opened")

## Walk back to the switch beside the doorway and flip the hall lit.
func _flip_switch() -> void:
	_walk_toward(switch_center, 1.2)
	_aim_at(switch_center, -25.0)
	_press("interact")
	if motion.hallway_switch_flips != 1:
		_bail("the switch press did not land")
	_settle(1)
	_pin("hall-lit")

## Walk a straight leg toward a floor point, stopping once the foot
## comes within `stop` meters of it. The heading snaps before the
## first step, so the leg is the same line at any walk speed.
func _walk_toward(target: Vector2, stop: float, watch_rod_reach := false) -> void:
	var foot := motion.capsule().foot
	_turn_toward(Vector2(target.x - foot.x, target.y - foot.z), 10.0)
	for _i: int in range(12000):
		foot = motion.capsule().foot
		var to_target := Vector2(target.x - foot.x, target.y - foot.z)
		if watch_rod_reach and not _has_beat("rod-in-reach") \
				and to_target.length() <= PlayerMotion.ROD_PICKUP_REACH + 0.6:
			_pin("rod-in-reach")
		if to_target.length() <= stop:
			_idle_tick()
			return
		_walk_tick()
	_bail("the walk toward %s never arrived" % [target])

## Walk a straight leg to an absolute waypoint, arriving on it.
func _walk_to_point(target: Vector2) -> void:
	_walk_toward(target, 0.2)

## Aim the camera at a floor target for a press or a capture.
func _aim_at(target: Vector2, pitch_deg: float) -> void:
	var foot := motion.capsule().foot
	_turn_toward(Vector2(target.x - foot.x, target.y - foot.z), pitch_deg)

## Turn the heading to face `to_target` and level the pitch to
## `pitch_deg`: one look on the mouse lanes, whole held-key ticks
## plus one remainder look on the keyboard lane.
func _turn_toward(to_target: Vector2, pitch_deg: float) -> void:
	var want_yaw := atan2(to_target.x, to_target.y)
	var dy := InputPlane.wrap_angle(want_yaw - yaw)
	var dp := deg_to_rad(pitch_deg) - pitch
	if keyboard:
		_key_turn(dy, dp)
	else:
		if dy == 0.0 and dp == 0.0:
			return
		_emit_look(dy, dp)
		_idle_tick()

func _key_turn(dy: float, dp: float) -> void:
	var yaw_ticks := int(abs(dy) / TURN_PER_TICK)
	var pitch_ticks := int(abs(dp) / PITCH_PER_TICK)
	var ticks := maxi(yaw_ticks, pitch_ticks)
	if ticks == 0 and dy == 0.0 and dp == 0.0:
		return
	var yaw_dir := "left" if dy > 0.0 else "right"
	var pitch_dir := "down" if dp < 0.0 else "up"
	for i: int in range(ticks):
		var key_dy := 0.0
		var key_dp := 0.0
		if i < yaw_ticks:
			key_dy = clampf(dy, -TURN_PER_TICK, TURN_PER_TICK)
			actions.append({"tick": tick, "type": "key_turn", "dir": yaw_dir})
			dy -= key_dy
		if i < pitch_ticks:
			key_dp = clampf(dp, -PITCH_PER_TICK, PITCH_PER_TICK)
			actions.append({"tick": tick, "type": "key_pitch", "dir": pitch_dir})
			dp -= key_dp
		_integrate(key_dy, key_dp)
		adapter.look(key_dy, key_dp)
		_idle_tick()
	# The keys stop at whole ticks; one small look closes the remainder.
	if abs(dy) > 1e-9 or abs(dp) > 1e-9:
		_emit_look(dy, dp)
		_idle_tick()

## One fixed tick with no movement: the turn ticks and the stops.
func _idle_tick() -> void:
	if failed:
		return
	adapter.release()
	_sim_tick()

## One fixed tick holding a forward step.
func _walk_tick() -> void:
	actions.append({"tick": tick, "type": "move", "forward": 1.0, "strafe": 0.0})
	adapter.hold(1.0, 0.0)
	_sim_tick()

## Emit and apply one look delta in radians.
func _emit_look(dy: float, dp: float) -> void:
	actions.append({
		"tick": tick,
		"type": "look",
		"yaw_deg": rad_to_deg(dy),
		"pitch_deg": rad_to_deg(dp),
	})
	_integrate(dy, dp)
	adapter.look(dy, dp)

func _integrate(dy: float, dp: float) -> void:
	var angles := InputPlane.integrate_look(yaw, pitch, Vector2(dy, dp))
	yaw = angles.x
	pitch = angles.y

## Offer the tick's scripted input, advance the body, run the
## interact consumers in the player scene's order, close the frame,
## and advance the wake — the app's physics tick, headless.
func _sim_tick() -> void:
	if failed:
		return
	adapter.offer_tick(plane)
	motion.advance(plane, game, yaw, DT)
	motion.pickup_rod(plane)
	motion.interact_with_door(plane, game)
	motion.flip_hallway_switch(plane, game)
	motion.interact_with_power_door(plane, game)
	motion.interact_with_console(plane, game)
	if not motion.failure().is_empty():
		_bail("motion failure: %s" % motion.failure())
	plane.end_frame()
	game.wake_state.tick()
	# The app's WakePresent hands the completed timeline to the phase
	# machine from a render frame; the recorder delivers the same
	# Waking -> AwakeInPod boundary as soon as the timeline completes.
	if not _wake_delivered and game.wake_state.is_complete():
		_wake_delivered = true
		game.phase.wake_complete()
	tick += 1

func _press(button: String) -> void:
	actions.append({"tick": tick, "type": "press", "button": button})
	adapter.press(InputPlane.Buttons.ACTIVATE if button == "activate"
			else InputPlane.Buttons.INTERACT)
	_sim_tick()

func _settle(ticks: int) -> void:
	for _i: int in range(ticks):
		_idle_tick()

func _wait_door_open() -> void:
	for _i: int in range(400):
		if motion.door_state == PlayerMotion.DoorState.OPEN:
			return
		_idle_tick()
	_bail("the stasis door never opened")

func _wait_power_door_open() -> void:
	for _i: int in range(400):
		if motion.power_door_state == PlayerMotion.PowerDoorState.OPEN:
			return
		_idle_tick()
	_bail("the power door never opened")

func _snap_look(want_yaw_deg: float, want_pitch_deg: float) -> void:
	var dy := InputPlane.wrap_angle(deg_to_rad(want_yaw_deg) - yaw)
	_emit_look(dy, deg_to_rad(want_pitch_deg) - pitch)
	_idle_tick()

func _pin(name: String) -> void:
	_pin_at(name, tick)

func _pin_at(name: String, at_tick: int) -> void:
	beats.append({"name": name, "tick": at_tick})

func _has_beat(name: String) -> bool:
	for beat: Dictionary in beats:
		if beat.name == name:
			return true
	return false

func _xz(center: Vector3) -> Vector2:
	return Vector2(center.x, center.z)

func _write() -> void:
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.tick < b.tick)
	var last_tick: int = beats[beats.size() - 1].tick
	var data := {
		"actions": actions,
		"beats": beats,
		"content": "gameplay",
		"max_frames": last_tick + 900,
		"mode": "capture",
		"name": lane,
		"seed": SEEDS[lane],
		"ticks_per_second": 60,
	}
	var path := "res://scenarios/%s.json" % lane
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_bail("cannot write %s" % path)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("recorded `%s`: %d actions, %d beats, last tick %d"
			% [lane, actions.size(), beats.size(), last_tick])
	quit(0)

func _bail(message: String) -> void:
	if failed:
		return
	failed = true
	push_error("record: " + message)
	print("RECORD_FAILED: " + message)
	quit(1)
