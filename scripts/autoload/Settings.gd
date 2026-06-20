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


func _save() -> void:
	_cfg.set_value("audio", "music_volume", music_volume)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.set_value("audio", "music_on", music_on)
	_cfg.set_value("audio", "sfx_on", sfx_on)
	_cfg.set_value("game", "skin", selected_skin)
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
