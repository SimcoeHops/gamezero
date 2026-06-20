## Settings — Autoload for persisted user preferences.
##
## Owns SFX/Music volume + on-off, and the chosen character skin. Applies the
## audio settings to the Music/SFX buses (created at runtime by AudioManager)
## and saves to disk.

extends Node

const SAVE_PATH := "user://settings.cfg"

const DEFAULT_SKIN := "res://assets/kenney_animated-characters-protagonists/Skins/skaterMaleA.png"

var music_volume: float = 0.6
var sfx_volume: float = 0.9
var music_on: bool = true
var sfx_on: bool = true
var selected_skin: String = DEFAULT_SKIN

# Accessibility — one knob each, read live by Juice so a single setting governs
# every shake/flash/haptic caller in the game (see Juice.gd).
var shake_scale: float = 1.0   # 0..1 multiplier on all camera trauma + FOV kicks
var haptics_on: bool = true    # gates all Input.vibrate_handheld calls
var reduce_flashes: bool = false  # dampens full-screen flashes + impact pulse

# Onboarding — true once the player has been taught the core controls (move/jump)
# on their first run, so the first-run TutorialOverlay never shows again.
var tutorial_seen: bool = false

var _cfg := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func _load() -> void:
	if _cfg.load(SAVE_PATH) != OK:
		return
	music_volume = _cfg.get_value("audio", "music_volume", music_volume)
	sfx_volume = _cfg.get_value("audio", "sfx_volume", sfx_volume)
	music_on = _cfg.get_value("audio", "music_on", music_on)
	sfx_on = _cfg.get_value("audio", "sfx_on", sfx_on)
	selected_skin = _cfg.get_value("game", "skin", selected_skin)
	shake_scale = _cfg.get_value("accessibility", "shake_scale", shake_scale)
	haptics_on = _cfg.get_value("accessibility", "haptics_on", haptics_on)
	reduce_flashes = _cfg.get_value("accessibility", "reduce_flashes", reduce_flashes)
	tutorial_seen = _cfg.get_value("game", "tutorial_seen", tutorial_seen)


func _save() -> void:
	_cfg.set_value("audio", "music_volume", music_volume)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.set_value("audio", "music_on", music_on)
	_cfg.set_value("audio", "sfx_on", sfx_on)
	_cfg.set_value("game", "skin", selected_skin)
	_cfg.set_value("accessibility", "shake_scale", shake_scale)
	_cfg.set_value("accessibility", "haptics_on", haptics_on)
	_cfg.set_value("accessibility", "reduce_flashes", reduce_flashes)
	_cfg.set_value("game", "tutorial_seen", tutorial_seen)
	_cfg.save(SAVE_PATH)


## Pushes the current volumes/mutes onto the audio buses. Safe to call before
## the buses exist (it no-ops for any missing bus).
func apply_audio() -> void:
	_apply_bus(&"Music", music_on, music_volume)
	_apply_bus(&"SFX", sfx_on, sfx_volume)


func _apply_bus(bus_name: StringName, on: bool, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, not on)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(vol, 0.0001, 1.0)))


func set_music_volume(v: float) -> void:
	music_volume = v
	apply_audio()
	_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	apply_audio()
	_save()


func set_music_on(b: bool) -> void:
	music_on = b
	apply_audio()
	_save()


func set_sfx_on(b: bool) -> void:
	sfx_on = b
	apply_audio()
	_save()


func set_skin(path: String) -> void:
	selected_skin = path
	_save()


func set_shake_scale(v: float) -> void:
	shake_scale = clampf(v, 0.0, 1.0)
	_save()


func set_haptics_on(b: bool) -> void:
	haptics_on = b
	_save()


func set_reduce_flashes(b: bool) -> void:
	reduce_flashes = b
	_save()


## Persists the onboarding flag (called by the TutorialOverlay once the player has
## been taught). Kept as its own entry point so the overlay doesn't depend on the
## private _save().
func save_tutorial_seen() -> void:
	_save()
