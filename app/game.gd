class_name Game
extends RefCounted
## Root-script-owned container over the sim state instances, mirroring
## the Rust StasisScenePlugin contract: the frozen pod registry, the wake
## phase machine, the power grid, the wake timeline state, the authored
## player exit path, and the static collider set are inserted at their
## spawn state and ticked at the fixed 60 Hz physics rate. The sim is
## authoritative: this container reads it and never writes phases ahead
## of the controllers that own them (the wake driver is a later chunk).

var registry: Pods.PodRegistry
var colliders: ColliderSet
var phase: Phase.Machine
var power: Power.Grid
var wake_state: Wake.WakeState
var exit_path: Exit.ExitPath
## The doorway into the hallway opens on act with the rod carried and
## the hallway's fixtures light on the switch beside the doorway; both
## are authored with the hallway (issue #59's prerequisite milestone)
## and owned here, on the container. Issue #59 adds the emergency power
## room behind the corridor's last right-hand door: its doorway opens
## on act (no rod gate — it is a crew door, not a pry-bar hatch), and
## its working console walks the secondary power's state machine — one
## press activates the generator, and the hallway plus the power room
## hand their red emergency light over to dim regular white while the
## stasis bay keeps its red.
var door_open: bool = false
var hallway_lit: bool = false
var power_door_open: bool = false
var console_state: int = ConsoleState.STANDBY
var power_active: bool = false

## The survivor wakes poisoned in the leaking stasis bay. The countdown
## begins once the wake presentation reaches AwakeInPod; crossing the
## opened hatch into the hallway ends the exposure, while running out
## of ticks makes death terminal.
const POISON_LIMIT_TICKS: int = 45 * 60
var poison_state: int = PoisonState.POISONED
var poison_ticks_remaining: int = POISON_LIMIT_TICKS

enum PoisonState { POISONED, ESCAPED, DEAD }

## The working console's Spanish label state machine: standby identifies
## the action, and the single press activates and shows Activado.
enum ConsoleState { STANDBY, ACTIVE }

func _init() -> void:
	registry = Pods.PodRegistry.frozen()
	colliders = PowerRoom.scene_collider_set(registry, false, false)
	phase = Phase.Machine.new()
	power = Power.Grid.new()
	wake_state = Wake.WakeState.new(Wake.WakeTimeline.authored())
	exit_path = PlacementTruth.player_exit_path()

## Open the stasis doorway into the hallway: idempotent (called by the
## body motion the tick the door's opening animation completes), and
## the only writer of the doorway's collider state — the rebuilt set
## drops the closed doorway block and the slid-aside door slab so the
## walk sim can cross.
func open_doorway() -> void:
	if door_open:
		return
	door_open = true
	colliders = PowerRoom.scene_collider_set(registry, true, power_door_open)

## Open the power room's doorway: idempotent, same contract as the
## stasis doorway — the rebuilt set drops the power door's slid-aside
## leaf.
func open_power_doorway() -> void:
	if power_door_open:
		return
	power_door_open = true
	colliders = PowerRoom.scene_collider_set(registry, door_open, true)

## Light the hallway's emergency circuit: the switch flip's single
## authority. Render-side consumers (the hallway's fixture bridge) read
## this and never write it.
func light_hallway() -> void:
	hallway_lit = true

## Advance the working console's state machine exactly one step:
## standby → active (the generator lights, the corridor and the power
## room go regular white). Returns true when a step landed — the
## caller consumes a press only then.
func press_console() -> bool:
	match console_state:
		ConsoleState.STANDBY:
			console_state = ConsoleState.ACTIVE
			power_active = true
			return true
		_:
			return false

## The emergency circuit's target fixture level: 1.0 while the grid
## carries the emergency cells, 0.0 once they are dead. Render-side
## consumers read this; they never write the grid.
func emergency_circuit_target() -> float:
	return 1.0 if Power.emergency_fixtures_lit(power.state()) else 0.0

## End the toxic exposure after the player has physically crossed the
## opened stasis-room hatch. Death is terminal, so a late escape cannot
## resurrect the survivor.
func escape_poison_zone() -> void:
	if poison_state == PoisonState.POISONED:
		poison_state = PoisonState.ESCAPED

func is_poisoned() -> bool:
	return poison_state == PoisonState.POISONED

func is_dead() -> bool:
	return poison_state == PoisonState.DEAD

func poison_seconds_remaining() -> int:
	return ceili(float(poison_ticks_remaining) / float(Sim.LOGICAL_TICKS_PER_SECOND))

## One fixed logical tick, called from _physics_process at the project's
## 60 Hz physics rate. The poison clock waits through the wake sequence
## so the player receives its full budget after opening their eyes.
func tick() -> void:
	wake_state.tick()
	if phase.current() == Phase.Wake.WAKING or poison_state != PoisonState.POISONED:
		return
	poison_ticks_remaining = maxi(poison_ticks_remaining - 1, 0)
	if poison_ticks_remaining == 0:
		poison_state = PoisonState.DEAD
