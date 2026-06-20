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

## Emitted each time a coin is collected, carrying the current rapid-collect streak
## (1, 2, 3, …). Drives the rising-pitch chime + HUD "+1" floater juice.
signal coin_collected(streak: int)

## Emitted when the world enters a new biome (for the HUD banner).
signal biome_changed(biome_name: String)

## Emitted when the run level increases (drives the "choose a weapon" card screen).
signal level_up(level: int)

## Emitted when the player dies but can pay to continue.
signal continue_offered(cost: int)

## Emitted when a continue is purchased (revive the run).
signal continued()

enum GameState { MENU, PLAYING, GAME_OVER, REVIVE_OFFER }

## Cost of the first continue; doubles each use.
const BASE_CONTINUE_COST := 50
const MAX_CONTINUES := 3

## Emitted when a meta upgrade is purchased (so the shop UI can refresh).
signal upgrade_purchased(id: String, level: int)

## Permanent, coin-bought upgrades that apply at [method start_game]. Each is a
## tiered unlock persisted in the save file. Next-level cost = base + step·level.
##   STARTGUN — begin armed with a Pistol (one extra level per tier).
##   AIRJUMP  — start with a mid-air double jump.
##   MAGNET   — always-on coin magnet for the whole run.
##   REVIVE   — start each run with N free (no-coin) revives.
##   COINMULT — +25% coins earned per run, per level.
const UPGRADES := {
	"STARTGUN": {
		"name": "SIDEARM", "desc": "Start each run armed with a Pistol (+1 level/tier)",
		"max": 3, "cost": 120, "step": 140, "color": Color(1.0, 0.85, 0.25),
	},
	"AIRJUMP": {
		"name": "AIR DASH", "desc": "Begin every run with a mid-air double jump",
		"max": 1, "cost": 200, "step": 0, "color": Color(0.4, 0.85, 1.0),
	},
	"MAGNET": {
		"name": "COIN MAGNET", "desc": "Always pull in nearby coins — no orb needed",
		"max": 1, "cost": 180, "step": 0, "color": Color(1.0, 0.78, 0.2),
	},
	"REVIVE": {
		"name": "GUARDIAN", "desc": "Start with a free revive (no coin cost)",
		"max": 2, "cost": 260, "step": 320, "color": Color(0.5, 1.0, 0.6),
	},
	"COINMULT": {
		"name": "LUCKY CHARM", "desc": "+25% coins earned per run, per level",
		"max": 4, "cost": 150, "step": 130, "color": Color(1.0, 0.5, 0.85),
	},
}

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

## The high score as it stood at the START of the run that just ended — captured
## in [method end_game] before [member high_score] is overwritten, so the recap
## can show "previous best" and reliably know whether this run beat it.
var prev_high_score: int = 0

## All-time furthest distance (metres), persisted — a second personal best to chase.
var best_distance: float = 0.0
var prev_best_distance: float = 0.0

## Whether the run that just ended set a new best score / distance. Read by the
## game-over recap to fire the celebration. Set in [method end_game].
var last_run_best_score: bool = false
var last_run_best_distance: bool = false

## Persistent soft currency (earned from score each run).
var coins: int = 0
## Coins earned in the most recent run (for the game-over readout).
var last_coins_earned: int = 0

## Rapid-collect coin streak: grabbing coins in quick succession ramps a Mario-style
## rising-pitch "coin run". Resets after COIN_STREAK_WINDOW with no pickup.
const COIN_STREAK_WINDOW := 0.7
const COIN_STREAK_MAX := 16
var coin_streak: int = 0
var _coin_streak_timer: float = 0.0

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

## --- Flow-state "heat" (0..1) ---
## The longer the player survives WITHOUT crashing, the hotter the world gets:
## music swells, the screen edges glow warm, the grade pushes warmer, and coin /
## gantry density rises. A crash cools it instantly. A hot greed combo heats it
## faster, so greedy lane-threading literally turns up the temperature. Read live
## by AudioManager, HUD (shader), Main (grade), and the coin/gantry spawners.
const FLOW_RAMP := 1.0 / 70.0          ## base seconds-to-max of clean survival
const FLOW_COMBO_GAIN := 0.004         ## extra heat/sec per combo tier above ×1
var flow_heat: float = 0.0

## --- Dynamic difficulty assist (light, bounded rubber-banding) ---
## A single signed bias in [-1, +1]; 0 leaves the open-loop time ramp untouched.
## It climbs as the player demonstrates control (dodges, near-misses) so an expert
## in flow gets packed a hair tighter, and it drops hard on a crash so a struggling
## player gets a little breathing room. Always SUBTLE, and CarSpawner's
## dodgeable-gap guarantee is never violated regardless of this value. Read live by
## CarSpawner via [method difficulty_pressure]; kept separate from flow_heat so the
## music/visual feel that consumes flow_heat is unaffected.
const DDA_DODGE_GAIN := 0.018          ## per dodge — steady control nudges pressure up
const DDA_NEARMISS_GAIN := 0.05        ## per near-miss — a skill flex presses harder
const DDA_CRASH_DROP := 0.65           ## a crash yanks toward "give me a break"
const DDA_CONTINUE_RELIEF := -0.6      ## a revived run resumes with breathing room
const DDA_DECAY := 0.06                ## per-sec pull back toward neutral (0)
var difficulty_bias: float = 0.0

## --- Run level / XP (Vampire-Survivors "level up, pick a weapon") ---
## Dodges are XP. Filling the bar triggers a level-up card pick. Each level costs
## a little more than the last so the cadence stretches as the run gets deeper.
const LEVEL_XP_BASE := 7
const LEVEL_XP_STEP := 3
## Current run level (starts at 1).
var run_level: int = 1
## Dodges accumulated toward the next level.
var level_xp: int = 0
## Dodges required to reach the next level.
var level_xp_needed: int = LEVEL_XP_BASE

## Continue economy for the current run.
var continue_cost: int = BASE_CONTINUE_COST
var continues_used: int = 0
## Free revives remaining this run (from the GUARDIAN upgrade) — spent before coins.
var free_continues: int = 0

## Owned meta-upgrade levels: id -> level (0 = not bought). Persisted.
var _upgrades: Dictionary = {}

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
		# Heat creeps up the longer this run stays clean; a hot combo stokes it.
		var rate := FLOW_RAMP + FLOW_COMBO_GAIN * float(combo - 1)
		flow_heat = minf(flow_heat + rate * delta, 1.0)
		# DDA bias relaxes back toward neutral when nothing notable happens, so a
		# quiet stretch settles to the plain time ramp rather than staying biased.
		difficulty_bias = move_toward(difficulty_bias, 0.0, DDA_DECAY * delta)
		# Cool the rapid-collect coin streak once the player stops grabbing.
		if _coin_streak_timer > 0.0:
			_coin_streak_timer -= delta
			if _coin_streak_timer <= 0.0:
				coin_streak = 0


## Transition to the PLAYING state and reset all run data.
func start_game() -> void:
	score = 0
	time_elapsed = 0.0
	highway_speed = 15.0
	combo = 1
	_combo_timer = 0.0
	flow_heat = 0.0
	difficulty_bias = 0.0
	coin_streak = 0
	_coin_streak_timer = 0.0
	run_level = 1
	level_xp = 0
	level_xp_needed = LEVEL_XP_BASE
	continue_cost = BASE_CONTINUE_COST
	continues_used = 0
	ProgressionManager.reset()
	PowerUpManager.reset()
	GunManager.reset()
	_apply_meta_upgrades()
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

	last_coins_earned = maxi(int(score / 10.0 * coin_multiplier()), 0)
	coins += last_coins_earned

	# Capture the bests as they stood BEFORE this run so the recap can celebrate
	# (and show the previous mark) without racing the overwrite below.
	prev_high_score = high_score
	prev_best_distance = best_distance
	last_run_best_score = score > high_score and score > 0
	last_run_best_distance = run_distance > best_distance and run_distance > 1.0

	if last_run_best_score:
		high_score = score
		new_high_score.emit(high_score)
		print("[GameManager] New high score: ", high_score)
	if last_run_best_distance:
		best_distance = run_distance

	_save_progress()
	print("[GameManager] Game over — Score: ", score, " | Coins +", last_coins_earned, " | Time: %.1f" % time_elapsed, "s")


## Collect a road coin (persistent currency + a little score).
func collect_coin() -> void:
	coins += 1
	# Ramp the rapid-collect streak (or start a fresh one if the window lapsed).
	if _coin_streak_timer > 0.0:
		coin_streak = mini(coin_streak + 1, COIN_STREAK_MAX)
	else:
		coin_streak = 1
	_coin_streak_timer = COIN_STREAK_WINDOW
	coins_changed.emit(coins)
	coin_collected.emit(coin_streak)
	add_points(2)


## Whether the player can revive again this run — a free GUARDIAN revive counts even
## if coins are short.
func can_continue() -> bool:
	if continues_used >= MAX_CONTINUES:
		return false
	return free_continues > 0 or coins >= continue_cost


## Called from the player when the death animation settles. Offers a paid
## continue if affordable, otherwise ends the run.
func player_died() -> void:
	if can_continue():
		current_state = GameState.REVIVE_OFFER
		state_changed.emit(current_state)
		continue_offered.emit(continue_cost)
	else:
		end_game()


## Purchase a continue: spend a free GUARDIAN revive if available, else coins, then
## revive and resume play.
func do_continue() -> void:
	if free_continues > 0:
		free_continues -= 1
	else:
		coins -= continue_cost
		continue_cost *= 2
	continues_used += 1
	# A crash you survived still cools the greed meter — the run resumes at ×1.
	combo = 1
	_combo_timer = 0.0
	flow_heat = 0.0
	# Resume a revived run with real breathing room — the crash already dropped the
	# bias; clamp it to a firm relief floor so the comeback isn't instantly brutal.
	difficulty_bias = minf(difficulty_bias, DDA_CONTINUE_RELIEF)
	combo_changed.emit(combo)
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


func _on_dodge_registered(_total: int) -> void:
	add_points(DODGE_POINTS)
	# Steady dodging is evidence of control — nudge the difficulty assist up.
	difficulty_bias = minf(difficulty_bias + DDA_DODGE_GAIN, 1.0)
	_advance_level_progress()


## Counts a dodge toward the level bar; fires [signal level_up] each time it fills
## (a while-loop in case a single frame pushes past a threshold).
func _advance_level_progress() -> void:
	if current_state != GameState.PLAYING:
		return
	level_xp += 1
	while level_xp >= level_xp_needed:
		level_xp -= level_xp_needed
		run_level += 1
		level_xp_needed += LEVEL_XP_STEP
		level_up.emit(run_level)


## Fraction (0..1) of the way to the next level, for the HUD XP bar.
func level_progress() -> float:
	return clampf(float(level_xp) / float(maxi(level_xp_needed, 1)), 0.0, 1.0)


func _on_near_miss(closeness: float = 0.5) -> void:
	combo = mini(combo + 1, MAX_COMBO)
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)
	# Threading the needle pays: base near-miss points plus up to +100% for a true
	# graze (both combo-scaled in add_points), so greedy tight passes are worth the risk.
	add_points(NEAR_MISS_POINTS + int(round(NEAR_MISS_POINTS * closeness)))
	# A near-miss is a deliberate skill flex — press the difficulty a touch harder,
	# and a closer pass is a louder flex.
	difficulty_bias = minf(difficulty_bias + DDA_NEARMISS_GAIN * (0.6 + 0.8 * closeness), 1.0)


## Snuffs the flow-state heat — called the instant the player crashes so the world
## visibly cools (music, glow, grade, density all drop back). Survival re-earns it.
func cool_flow() -> void:
	flow_heat = 0.0
	# The clearest "struggling" signal there is: a crash yanks the difficulty assist
	# toward relief so a recovering player (after a continue) gets a little more room.
	difficulty_bias = maxf(difficulty_bias - DDA_CRASH_DROP, -1.0)


## DDA pressure mapped to a clean 0..1 (0 = max relief, 0.5 = neutral / plain time
## ramp, 1 = max pressure). Read by CarSpawner to nudge wave size + spawn cadence.
func difficulty_pressure() -> float:
	return clampf(difficulty_bias * 0.5 + 0.5, 0.0, 1.0)


## Fraction (0..1) of the combo "heat" remaining before it cools back to ×1 — the
## near-miss timer normalized over [constant COMBO_WINDOW]. Drives the HUD heat bar.
## 0 while no combo is active.
func combo_fraction() -> float:
	if combo <= 1:
		return 0.0
	return clampf(_combo_timer / COMBO_WINDOW, 0.0, 1.0)


## --- Meta-progression shop API ---

## Current owned level of a permanent upgrade (0 = not bought).
func upgrade_level(id: String) -> int:
	return int(_upgrades.get(id, 0))


## Highest purchasable level of an upgrade.
func upgrade_max(id: String) -> int:
	return int(UPGRADES[id]["max"]) if UPGRADES.has(id) else 0


## Whether the upgrade is fully purchased (no further tiers).
func upgrade_is_maxed(id: String) -> bool:
	return upgrade_level(id) >= upgrade_max(id)


## Coin cost of the NEXT tier of an upgrade (base + step·current_level).
func upgrade_cost(id: String) -> int:
	if not UPGRADES.has(id):
		return 0
	var u: Dictionary = UPGRADES[id]
	return int(u["cost"]) + int(u["step"]) * upgrade_level(id)


## Whether the player can afford and isn't maxed on this upgrade.
func can_buy_upgrade(id: String) -> bool:
	if not UPGRADES.has(id) or upgrade_is_maxed(id):
		return false
	return coins >= upgrade_cost(id)


## Spend coins to buy the next tier of an upgrade. Persists immediately. Returns
## true on success.
func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	coins -= upgrade_cost(id)
	var new_level := upgrade_level(id) + 1
	_upgrades[id] = new_level
	coins_changed.emit(coins)
	upgrade_purchased.emit(id, new_level)
	_save_progress()
	return true


## Coin payout multiplier from the LUCKY CHARM upgrade.
func coin_multiplier() -> float:
	return 1.0 + 0.25 * float(upgrade_level("COINMULT"))


## Applies all purchased upgrades to a fresh run. Called from [method start_game]
## AFTER the per-run managers reset, so it layers on top of a clean slate.
func _apply_meta_upgrades() -> void:
	PowerUpManager.air_jumps = maxi(PowerUpManager.air_jumps, upgrade_level("AIRJUMP"))
	PowerUpManager.permanent_magnet = upgrade_level("MAGNET") > 0
	free_continues = upgrade_level("REVIVE")
	for _i in upgrade_level("STARTGUN"):
		GunManager.add_gun("PISTOL")


func _load_high_score() -> void:
	if _config.load(SAVE_PATH) == OK:
		high_score = _config.get_value("score", "high", 0)
		best_distance = _config.get_value("score", "best_distance", 0.0)
		coins = _config.get_value("meta", "coins", 0)
		for id in UPGRADES.keys():
			var lvl: int = int(_config.get_value("upgrades", id, 0))
			if lvl > 0:
				_upgrades[id] = clampi(lvl, 0, upgrade_max(id))


func _save_progress() -> void:
	_config.set_value("score", "high", high_score)
	_config.set_value("score", "best_distance", best_distance)
	_config.set_value("meta", "coins", coins)
	for id in UPGRADES.keys():
		_config.set_value("upgrades", id, upgrade_level(id))
	_config.save(SAVE_PATH)
