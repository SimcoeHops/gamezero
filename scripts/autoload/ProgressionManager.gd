## ProgressionManager — Autoload Singleton
##
## Tracks successful car dodges and emits signals when milestone thresholds
## are reached to unlock player abilities.
##
## Milestones:
##   10 dodges → Jump (vertical impulse)
##   25 dodges → Bullet Time (engine time-scale reduction)
##   50 dodges → Weapon (forward-firing projectile)

extends Node

## Emitted when a new ability is unlocked. [param ability_name] is one of:
## &"jump", &"bullet_time", &"weapon"
signal ability_unlocked(ability_name: StringName)

## Emitted every time the player successfully dodges a car.
signal dodge_registered(total: int)

## Emitted when a milestone dodge count is reached.
signal milestone_reached(dodge_count: int)

## Emitted when a car is dodged at very close range (juice + combo bonus).
signal near_miss()

## Maps dodge-count thresholds to ability StringNames.
const MILESTONES: Dictionary = {
	10: &"jump",
	25: &"bullet_time",
	50: &"weapon",
}

## Current number of cars successfully dodged this run.
var dodge_count: int = 0

## Set of abilities already unlocked this run (prevents duplicate signals).
var _unlocked: Dictionary = {}


## Call this from [CarController] when its [DodgeDetector] fires.
func register_dodge() -> void:
	dodge_count += 1
	dodge_registered.emit(dodge_count)

	if dodge_count in MILESTONES and not (dodge_count in _unlocked):
		var ability := MILESTONES[dodge_count] as StringName
		_unlocked[dodge_count] = true
		ability_unlocked.emit(ability)
		milestone_reached.emit(dodge_count)
		print("[ProgressionManager] Unlocked ability: ", ability, " at ", dodge_count, " dodges")


## Called by [CarController] when a car is dodged at close range.
func register_near_miss() -> void:
	near_miss.emit()


## Resets all progression state for a new run.
func reset() -> void:
	dodge_count = 0
	_unlocked.clear()
