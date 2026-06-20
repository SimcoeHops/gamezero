## GameManager — Autoload Singleton
##
## Manages the global game state, score tracking, high-score persistence,
## and restart flow.

extends Node

## Emitted when the game state changes.
signal state_changed(new_state: GameState)

## Emitted when the score updates (for HUD binding).
signal score_updated(score: int)

## Emitted when a new high score is achieved.
signal new_high_score(score: int)

## Emitted when the near-miss combo multiplier changes.
signal combo_changed(combo: int)

## Emitted when the coin total changes.
signal coins_changed(coins: int)

## Emitted when the world enters a new biome (for the HUD banner).
signal biome_changed(biome_name: String)

## Emitted when the player dies but can pay to continue.
signal continue_offered(cost: int)

## Emitted when a continue is purchased (revive the run).
signal continued()

## Emitted when a level-up offers a choice of guns. [param choices] is an array of
## gun-description dicts (see GunManager.describe). The LevelUpScreen renders these.
signal level_up_offered(choices: Array, level: int)

## Emitted when the level-up choice resolves and play resumes.
signal level_up_resolved()

enum GameState { MENU, PLAYING, GAME_OVER, REVIVE_OFFER, LEVEL_UP }

## Cost of the first continue; doubles each use.
const BASE_CONTINUE_COST := 50
const MAX_CONTINUES := 3

## Points awarded per dodge and per close-call near-miss.
const DODGE_POINTS := 10
const NEAR_MISS_POINTS := 25
## Seconds a combo survives without another near-miss.
const COMBO_WINDOW := 3.0
const MAX_COMBO := 9

## Current game state.
var current_state: GameState = GameState.MENU

## Time elapsed since the current run started (in seconds).
var time_elapsed: float = 0.0

## Current score (mirrors ProgressionManager.dodge_count but owned here for display).
var score: int = 0

## All-time best score, persisted to disk.
var high_score: int = 0

## Persistent soft currency (earned from score each run).
var coins: int = 0
## Coins earned in the most recent run (for the game-over readout).
var last_coins_earned: int = 0

## Current highway speed — updated by CarSpawner, read by Highway for scroll.
var highway_speed: float = 15.0

## --- Run recap data (for the end-of-run journey map) ---
## Total distance travelled this run (world units ≈ metres).
var run_distance: float = 0.0
## Fastest speed reached this run (m/s).
var top_speed: float = 0.0
## Ordered log of biomes entered: [{name, start}] where start is run_distance.
var biome_log: Array = []

## Near-miss combo multiplier (1 = no combo).
var combo: int = 1
var _combo_timer: float = 0.0

## --- Level-up "choose a weapon" cadence ---
## Current loadout level (1 at run start; +1 each level-up choice taken).
var level: int = 1
## Dodge count at which the next level-up triggers.
var _next_level_at: int = FIRST_LEVEL_DODGES
## Dodges before the first level-up; gaps widen after each (see _offer_level_up).
const FIRST_LEVEL_DODGES := 7
## How deeply time slows while the player picks a weapon (cinematic slow-mo).
const LEVELUP_TIME_SCALE := 0.08

## Continue economy for the current run.
var continue_cost: int = BASE_CONTINUE_COST
var continues_used: int = 0

const SAVE_PATH := "user://highscore.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	_load_high_score()
	ProgressionManager.dodge_registered.connect(_on_dodge_registered)
	ProgressionManager.near_miss.connect(_on_near_miss)


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		time_elapsed += delta
		run_distance += highway_speed * delta
		if highway_speed > top_speed:
			top_speed = highway_speed
		if combo > 1:
			_combo_timer -= delta
			if _combo_timer <= 0.0:
				combo = 1
				combo_changed.emit(combo)


## Transition to the PLAYING state and reset all run data.
func start_game() -> void:
	score = 0
	time_elapsed = 0.0
	highway_speed = 15.0
	combo = 1
	_combo_timer = 0.0
	level = 1
	_next_level_at = FIRST_LEVEL_DODGES
	continue_cost = BASE_CONTINUE_COST
	continues_used = 0
	ProgressionManager.reset()
	PowerUpManager.reset()
	GunManager.reset()
	run_distance = 0.0
	top_speed = 0.0
	# Seed with the opening biome (Highway starts on THEMES[0] = DOWNTOWN).
	biome_log = [{"name": "DOWNTOWN", "start": 0.0}]
	Engine.time_scale = 1.0
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	score_updated.emit(score)
	combo_changed.emit(combo)
	print("[GameManager] Game started")


## Transition to GAME_OVER. Saves high score if beaten.
func end_game() -> void:
	current_state = GameState.GAME_OVER
	state_changed.emit(current_state)

	last_coins_earned = maxi(int(score / 10.0), 0)
	coins += last_coins_earned

	if score > high_score:
		high_score = score
		new_high_score.emit(high_score)
		print("[GameManager] New high score: ", high_score)

	_save_progress()
	print("[GameManager] Game over — Score: ", score, " | Coins +", last_coins_earned, " | Time: %.1f" % time_elapsed, "s")


## Collect a road coin (persistent currency + a little score).
func collect_coin() -> void:
	coins += 1
	coins_changed.emit(coins)
	add_points(2)


## Whether the player can afford another continue this run.
func can_continue() -> bool:
	return coins >= continue_cost and continues_used < MAX_CONTINUES


## Called from the player when the death animation settles. Offers a paid
## continue if affordable, otherwise ends the run.
func player_died() -> void:
	if can_continue():
		current_state = GameState.REVIVE_OFFER
		state_changed.emit(current_state)
		continue_offered.emit(continue_cost)
	else:
		end_game()


## Purchase a continue: spend coins, revive, and resume play.
func do_continue() -> void:
	coins -= continue_cost
	continues_used += 1
	continue_cost *= 2
	coins_changed.emit(coins)
	_save_progress()
	Engine.time_scale = 1.0
	current_state = GameState.PLAYING
	continued.emit()
	state_changed.emit(current_state)
	print("[GameManager] Continued (used ", continues_used, ")")


## Decline the continue offer and finalize the run.
func decline_continue() -> void:
	end_game()


## Return to the title/menu state (used by Quit To Menu before a scene reload).
func go_to_menu() -> void:
	current_state = GameState.MENU
	Engine.time_scale = 1.0


## Reload the main scene to restart.
func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	# start_game() will be called by Main._ready()


## Records entering a new biome at the current distance (for the recap map).
func log_biome(biome_name: String) -> void:
	if biome_name == "":
		return
	biome_log.append({"name": biome_name, "start": run_distance})


## Adds points scaled by the current combo multiplier.
func add_points(base: int) -> void:
	score += base * combo
	score_updated.emit(score)


func _on_dodge_registered(total: int) -> void:
	add_points(DODGE_POINTS)
	# Vampire-Survivors style level-up: every so many dodges, slow time and let the
	# player pick a weapon to add/upgrade. Only fires during live play (never mid
	# ragdoll / revive offer / an already-open choice).
	if current_state == GameState.PLAYING and total >= _next_level_at:
		_offer_level_up()


## Slows time and presents a 3-gun choice. The LevelUpScreen draws the cards and
## calls [method resolve_level_up] when the player picks.
func _offer_level_up() -> void:
	level += 1
	# Gaps widen as the run goes on so level-ups stay special: 7, 19, 33, 49, 67...
	_next_level_at += 8 + level * 2
	var choices: Array = GunManager.roll_level_up_choices(3)
	if choices.is_empty():
		return
	Engine.time_scale = LEVELUP_TIME_SCALE
	current_state = GameState.LEVEL_UP
	state_changed.emit(current_state)
	level_up_offered.emit(choices, level)
	print("[GameManager] Level up ", level, " — choose a weapon")


## Applies the chosen gun (empty id = skip) and resumes play at full speed.
func resolve_level_up(gun_id: String) -> void:
	if current_state != GameState.LEVEL_UP:
		return
	if gun_id != "":
		GunManager.add_gun(gun_id)
	Engine.time_scale = 1.0
	current_state = GameState.PLAYING
	level_up_resolved.emit()
	state_changed.emit(current_state)


func _on_near_miss() -> void:
	combo = mini(combo + 1, MAX_COMBO)
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	add_points(NEAR_MISS_POINTS)


func _load_high_score() -> void:
	if _config.load(SAVE_PATH) == OK:
		high_score = _config.get_value("score", "high", 0)
		coins = _config.get_value("meta", "coins", 0)


func _save_progress() -> void:
	_config.set_value("score", "high", high_score)
	_config.set_value("meta", "coins", coins)
	_config.save(SAVE_PATH)
