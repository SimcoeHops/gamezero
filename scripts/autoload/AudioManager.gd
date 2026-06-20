## AudioManager — Autoload for all game audio.
##
## - Sets up the Music / SFX buses at runtime (the project ships no bus layout).
## - Plays one-shot SFX from a round-robin pool with pitch/volume variation,
##   pulling whatever files exist in the Kenney audio kits.
## - Synthesizes a speed-reactive engine drone and a mellow pentatonic music
##   bed procedurally (no music asset shipped), via AudioStreamGenerator.

extends Node

const DIGITAL := "res://assets/kenney_digital-audio/Audio"
const IMPACTS := "res://assets/kenney_impact-sounds/Audio"

const MIX_RATE := 22050.0

## Toggle the procedural music bed.
@export var music_enabled: bool = true

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
const POOL_SIZE := 14

# SFX banks (filled from whatever files exist).
var _crash: Array[AudioStream] = []
var _smash: Array[AudioStream] = []   ## metal crunch for car destruction
var _glass: Array[AudioStream] = []   ## glass shatter layer
var _footsteps: Array[AudioStream] = []  ## running pitter-patter (speed-scaled)
var _step_timer: float = 0.0
var _laser: Array[AudioStream] = []
# Per-gun shot voices — each gun pattern gets its own recipe so a stacked loadout
# reads as a chord of different weapons firing, not one repeated laser.
var _g_low: Array[AudioStream] = []     ## low descending tones (mortar thunk, big-gun body)
var _g_zap: Array[AudioStream] = []     ## sharp electric zaps (laser, railgun crack)
var _g_three: Array[AudioStream] = []   ## tonal triple-beeps (spread volley)
var _g_trash: Array[AudioStream] = []   ## noisy fizz/spray (shotgun, net)
var _pickup: Array[AudioStream] = []
var _unlock: Array[AudioStream] = []
var _whoosh: Array[AudioStream] = []
var _drain: Array[AudioStream] = []
var _ui: Array[AudioStream] = []

# Procedural engine drone.
var _engine: AudioStreamPlayer
var _engine_pb: AudioStreamGeneratorPlayback
var _engine_phase: float = 0.0
var _engine_lp: float = 0.0
var _engine_target_vol: float = -80.0

# Procedural music.
var _music: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback
var _music_phase_arp: float = 0.0
var _music_phase_bass: float = 0.0
var _music_sample: int = 0
var _music_step: int = 0
## Real music tracks (res://music/*.mp3). When present they replace the
## procedural bed and play back-to-back on repeat.
var _music_tracks: Array[AudioStream] = []
var _track_index: int = 0
## Shuffled playback order (a "shuffle bag") so songs never play in folder order
## and get reshuffled each pass. _order_pos walks through _play_order.
var _play_order: Array[int] = []
var _order_pos: int = 0
## True once real tracks are driving the Music player (vs. the procedural bed).
var _real_tracks_active: bool = false
## Smoothed volume target for the real-track player (fade-in + menu ducking).
var _music_target_db: float = 0.0
## Previous GameManager state, to tell a fresh run from a paid continue.
var _prev_state: int = GameManager.GameState.MENU
# A minor pentatonic (Hz): A2 C3 D3 E3 G3 A3 C4 D4
const PENTA := [110.0, 130.81, 146.83, 164.81, 196.0, 220.0, 261.63, 293.66]
const ARP_PATTERN := [0, 2, 4, 5, 4, 2, 6, 4]
const BASS_PATTERN := [110.0, 110.0, 146.83, 130.81]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_banks()
	_setup_pool()
	_setup_music()
	GameManager.state_changed.connect(_on_state_changed)
	# Apply the user's saved volumes now that the buses exist.
	Settings.apply_audio()


func _process(delta: float) -> void:
	_process_footsteps(delta)
	_fill_music()
	_update_music_dynamics()


## Pitter-patter of running feet, paced by speed (faster = quicker steps) — the
## audible-speed cue that replaces the old engine buzz.
func _process_footsteps(delta: float) -> void:
	if _footsteps.is_empty():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		# As the flow-state heats up, the stride gets a touch quicker, higher and
		# louder — an "in the zone, sprinting hard" cue that rides the hot streak.
		var flow: float = GameManager.flow_heat
		_play(_footsteps, 0.92 + flow * 0.12, 1.12 + flow * 0.12, -9.0 + flow * 2.0)
		# Step interval shrinks as the highway speeds up (and a little more when hot).
		var spd: float = GameManager.highway_speed
		_step_timer = clampf((0.42 - (spd - 15.0) * 0.0045) * (1.0 - flow * 0.18), 0.1, 0.5)


# ---------------------------------------------------------------- buses

func _setup_buses() -> void:
	_ensure_bus(&"Music", -10.0)
	_ensure_bus(&"SFX", -3.0)


func _ensure_bus(bus_name: StringName, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(idx, volume_db)


# ---------------------------------------------------------------- SFX banks

func _load_banks() -> void:
	# Crash: heavy punches, metal, and bells layered into one bank.
	_crash = _scan(IMPACTS, "impactPunch_heavy") + _scan(IMPACTS, "impactMetal_heavy") + _scan(IMPACTS, "impactBell_heavy")
	if _crash.is_empty():
		_crash = _scan(IMPACTS, "impact")
	# Metal crunch (all weights) + plate/tin for a meaty car-on-car wreck, with a
	# separate glass bank layered on top for the shatter.
	_smash = _scan(IMPACTS, "impactMetal_heavy") + _scan(IMPACTS, "impactMetal_medium") \
		+ _scan(IMPACTS, "impactPlate_heavy") + _scan(IMPACTS, "impactTin_medium")
	if _smash.is_empty():
		_smash = _crash
	_glass = _scan(IMPACTS, "impactGlass_heavy") + _scan(IMPACTS, "impactGlass_medium")
	_laser = _scan(DIGITAL, "laser")
	# Per-gun shot voices (fall back to _laser later if a kit is missing).
	_g_low = _scan(DIGITAL, "lowDown") + _scan(DIGITAL, "lowRandom") + _scan(DIGITAL, "lowThreeTone")
	_g_zap = _scan(DIGITAL, "zap") + _scan(DIGITAL, "zapTwoTone") \
		+ _scan(DIGITAL, "zapThreeToneDown") + _scan(DIGITAL, "zapThreeToneUp")
	_g_three = _scan(DIGITAL, "threeTone")
	_g_trash = _scan(DIGITAL, "spaceTrash")
	_pickup = _scan(DIGITAL, "pepSound")
	_unlock = _scan(DIGITAL, "phaseJump")
	_whoosh = _scan(DIGITAL, "phaserUp")
	_drain = _scan(DIGITAL, "lowDown") + _scan(DIGITAL, "phaserDown")
	_ui = _scan(DIGITAL, "highUp")
	_footsteps = _scan(IMPACTS, "footstep_concrete")


## Loads every sound matching [param prefix] in [param folder] by probing explicit
## paths with ResourceLoader. This is export-safe — DirAccess directory listing
## does NOT reliably enumerate imported assets in an exported (iOS) build, which
## left every SFX bank empty and silent on device.
##
## Covers the kits' two naming styles: a lone "prefix.ogg", the digital kit's
## "prefix1.ogg, prefix2.ogg, …", and the impact kit's "prefix_000.ogg, …".
func _scan(folder: String, prefix: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	var single := "%s/%s.ogg" % [folder, prefix]
	if ResourceLoader.exists(single):
		out.append(load(single))
	for i in range(1, 31):
		var p := "%s/%s%d.ogg" % [folder, prefix, i]
		if ResourceLoader.exists(p):
			out.append(load(p) as AudioStream)
	for i in range(0, 31):
		var p := "%s/%s_%03d.ogg" % [folder, prefix, i]
		if ResourceLoader.exists(p):
			out.append(load(p) as AudioStream)
	return out


func _setup_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)


func _play(bank: Array[AudioStream], pitch_min: float, pitch_max: float, vol_db: float) -> void:
	if bank.is_empty():
		return
	var p := _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % POOL_SIZE
	p.stream = bank.pick_random()
	p.pitch_scale = randf_range(pitch_min, pitch_max)
	p.volume_db = vol_db
	p.play()


func play_crash() -> void:
	# Layered impact: heavy metal crush + impact crack + a pitched-down sub-boom
	# for low-end body + glass shatter on top.
	_play(_smash, 0.7, 0.9, 3.0)
	_play(_crash, 0.85, 1.05, 2.0)
	_play(_crash, 0.5, 0.62, 0.0)
	if not _glass.is_empty():
		_play(_glass, 1.0, 1.3, -2.0)
	# Delayed tumble crunch as the ragdoll hits the ground.
	get_tree().create_timer(0.34).timeout.connect(_play_crash_tumble)


func _play_crash_tumble() -> void:
	_play(_smash, 0.9, 1.2, -6.0)
	if not _glass.is_empty():
		_play(_glass, 1.4, 1.8, -11.0)


## A satisfying car-destruction crunch: metal body hit + glass shatter layer.
## Used when a car is shot, stomped, or detonated.
func play_car_hit() -> void:
	_play(_smash, 0.85, 1.1, 0.0)
	if not _glass.is_empty() and randf() < 0.85:
		_play(_glass, 0.95, 1.3, -5.0)


func play_laser() -> void:
	_play(_laser, 0.95, 1.15, -6.0)


## Distinct firing voice per gun. [param pattern] is a GunManager.Pattern value.
## Each gun gets its own pitch/layer recipe so stacking guns sounds like a band of
## weapons, not one repeated zap — big guns thump via low-end layers. Every branch
## falls back to the laser bank if a particular Kenney sound kit is missing.
func play_gun_shot(pattern: int) -> void:
	var zap := _g_zap if not _g_zap.is_empty() else _laser
	var trash := _g_trash if not _g_trash.is_empty() else _smash
	match pattern:
		GunManager.Pattern.SINGLE:
			# PISTOL — a crisp, bright aimed pop.
			_play(_laser, 1.12, 1.28, -7.0)
		GunManager.Pattern.BURST:
			# RAPID — light, fast, higher & quieter so the stream doesn't fatigue.
			_play(_laser, 1.42, 1.62, -12.0)
		GunManager.Pattern.MINIGUN:
			# MINIGUN — a relentless high hose; very short, quiet pops.
			_play(_laser, 1.55, 1.9, -13.0)
		GunManager.Pattern.SHOTGUN:
			# SHOTGUN — a meaty BOOM: sub-thump + noisy buckshot spray.
			_play(_crash, 0.55, 0.7, -1.0)
			_play(trash, 0.7, 0.95, -4.0)
		GunManager.Pattern.LASER:
			# LASER — an electric sci-fi zap over a low body layer.
			_play(zap, 0.8, 1.0, -6.0)
			_play(_laser, 0.55, 0.7, -13.0)
		GunManager.Pattern.SPREAD:
			# SPREAD — a tonal three-way volley.
			_play(_g_three if not _g_three.is_empty() else _laser, 1.0, 1.2, -7.0)
		GunManager.Pattern.MORTAR:
			# MORTAR — a hollow launch THOOMP (its explosion has its own boom).
			_play(_g_low if not _g_low.is_empty() else _crash, 0.7, 0.85, -3.0)
		GunManager.Pattern.RAIL:
			# RAILGUN — a heavy CRACK: deep electric snap + sub-boom + metal tail.
			_play(zap, 0.5, 0.65, 1.0)
			_play(_crash, 0.45, 0.58, -2.0)
			_play(_smash, 0.8, 0.95, -7.0)
		GunManager.Pattern.NET:
			# NET — a wide whoosh throw with a soft fizzy spread.
			_play(_whoosh, 0.85, 1.05, -6.0)
			_play(trash, 0.9, 1.1, -11.0)
		_:
			_play(_laser, 0.95, 1.15, -6.0)


func play_pickup() -> void:
	_play(_pickup, 1.0, 1.25, -2.0)


## Coin pickup chime. The pitch climbs with the rapid-collect streak so a "coin run"
## reads as a rising, satisfying Mario-style scale (streak 1 = base).
func play_coin(streak: int = 1) -> void:
	var bump := 0.075 * float(mini(streak - 1, 14))
	_play(_pickup, 1.5 + bump, 1.66 + bump, -8.0)


func play_unlock() -> void:
	_play(_unlock, 0.95, 1.05, 0.0)


## Near-miss whoosh. Pitch climbs with the greed combo so threading a hot streak
## reads as an escalating, rising "tighter and tighter" tension cue (combo 1 = base).
func play_nearmiss(combo: int = 1) -> void:
	var bump := 0.085 * float(maxi(combo - 1, 0))
	_play(_whoosh, 1.1 + bump, 1.4 + bump, -4.0)


## Deep doppler whoosh as the player passes under an overhead gantry — pitched
## well below the near-miss whoosh and layered with a soft low impact for body.
func play_gantry_whoosh() -> void:
	_play(_whoosh, 0.5, 0.68, -2.0)
	if not _crash.is_empty():
		_play(_crash, 0.4, 0.5, -16.0)


func play_drain() -> void:
	_play(_drain, 0.9, 1.1, -1.0)


func play_ui() -> void:
	_play(_ui, 0.95, 1.1, -4.0)


## A short rising blip for animated count-ups on the recap. [param t] (0..1) walks
## the pitch up so a ticking number sounds like it's climbing.
func play_count_tick(t: float = 0.0) -> void:
	var pitch := lerpf(1.1, 2.1, clampf(t, 0.0, 1.0))
	_play(_pickup, pitch, pitch + 0.06, -12.0)


## A triumphant rising arpeggio for a NEW BEST. Fires four ascending notes from
## the unlock/pickup banks with small real-time delays — a little fanfare.
func play_fanfare() -> void:
	var bank := _unlock if not _unlock.is_empty() else _pickup
	if bank.is_empty():
		return
	var pitches := [1.0, 1.26, 1.5, 2.0]  # root, third, fifth, octave
	for i in pitches.size():
		var pitch: float = pitches[i]
		var delay := i * 0.11
		if delay <= 0.0:
			_play(bank, pitch, pitch + 0.02, -1.0)
		else:
			get_tree().create_timer(delay, true, false, true).timeout.connect(
				func() -> void: _play(bank, pitch, pitch + 0.02, -1.0)
			)


# ---------------------------------------------------------------- engine drone

func _setup_engine() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.bus = &"SFX"
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_engine.stream = gen
	_engine.volume_db = -80.0
	add_child(_engine)
	_engine.play()
	_engine_pb = _engine.get_stream_playback()


func _fill_engine() -> void:
	if _engine_pb == null:
		return
	var playing := GameManager.current_state == GameManager.GameState.PLAYING
	_engine_target_vol = -13.0 if playing else -80.0
	_engine.volume_db = lerpf(_engine.volume_db, _engine_target_vol, 0.05)

	var speed: float = GameManager.highway_speed
	var freq := 55.0 + clampf(speed, 0.0, 140.0) * 2.2
	var inc := freq / MIX_RATE
	var frames := _engine_pb.get_frames_available()
	for i in frames:
		_engine_phase = fmod(_engine_phase + inc, 1.0)
		# Sawtooth + sub-octave for a meaty rumble, then a 1-pole low-pass.
		var saw := _engine_phase * 2.0 - 1.0
		var sub := sin(_engine_phase * TAU) * 0.4
		var raw := saw * 0.5 + sub
		_engine_lp += (raw - _engine_lp) * 0.18
		var v: float = _engine_lp * 0.5
		_engine_pb.push_frame(Vector2(v, v))


# ---------------------------------------------------------------- music bed

func _setup_music() -> void:
	if not music_enabled:
		return

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)

	# Prefer real tracks in res://music/ (shuffled, back-to-back on repeat).
	_music_tracks = _load_music_tracks()
	if not _music_tracks.is_empty():
		_real_tracks_active = true
		_music.finished.connect(_advance_track)
		_build_play_order()
		_play_order_current(true)
		return

	# Fallback: synthesized pentatonic bed.
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	_music.stream = gen
	_music.volume_db = -14.0
	_music.play()
	_music_pb = _music.get_stream_playback()


func _load_music_tracks() -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	# Numbered tracks first (1.mp3, 2.mp3, ...), then anything else in the folder.
	for i in range(1, 21):
		var p := "res://music/%d.mp3" % i
		if ResourceLoader.exists(p):
			out.append(load(p) as AudioStream)
	var d := DirAccess.open("res://music")
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".mp3") and not (f.substr(0, f.length() - 4)).is_valid_int():
				var p := "res://music/" + f
				if ResourceLoader.exists(p):
					out.append(load(p) as AudioStream)
			f = d.get_next()
		d.list_dir_end()
	return out


## Builds a fresh shuffled order over all tracks. If [param avoid_first] is a
## valid index, we make sure the new order doesn't open on it — so a reshuffle
## (or a restart) never replays the song you just heard.
func _build_play_order(avoid_first: int = -1) -> void:
	_play_order.clear()
	for i in _music_tracks.size():
		_play_order.append(i)
	_play_order.shuffle()
	if avoid_first >= 0 and _play_order.size() > 1 and _play_order[0] == avoid_first:
		var swap_with := 1 + (randi() % (_play_order.size() - 1))
		var tmp: int = _play_order[0]
		_play_order[0] = _play_order[swap_with]
		_play_order[swap_with] = tmp
	_order_pos = 0


## Plays the track at the current position in the shuffle order. When
## [param fade_in] is true the player starts quiet and rises in _process.
func _play_order_current(fade_in: bool = false) -> void:
	if _play_order.is_empty():
		return
	_track_index = _play_order[_order_pos]
	var track := _music_tracks[_track_index]
	if track is AudioStreamMP3:
		(track as AudioStreamMP3).loop = false  # we cycle the playlist ourselves
	_music.stream = track
	_music_target_db = 0.0
	_music.volume_db = -24.0 if fade_in else _music_target_db
	_music.play()


func _advance_track() -> void:
	if _music_tracks.is_empty():
		return
	_order_pos += 1
	# Exhausted the bag — reshuffle for the next pass (no immediate repeat).
	if _order_pos >= _play_order.size():
		_build_play_order(_track_index)
	_play_order_current(true)


## Starts a fresh, random song from the top — called when a new run begins.
## Skips when a run resumes via a paid continue (music should keep playing).
func _start_run_music() -> void:
	if not _real_tracks_active or _music_tracks.is_empty():
		return
	_build_play_order(_track_index)
	_play_order_current(true)


func _fill_music() -> void:
	if _music_pb == null:
		return
	var playing := GameManager.current_state == GameManager.GameState.PLAYING
	_music.volume_db = lerpf(_music.volume_db, (-14.0 if playing else -24.0), 0.03)

	# Tempo nudges up with speed for intensity.
	var speed: float = GameManager.highway_speed
	var bpm := 96.0 + clampf(speed - 15.0, 0.0, 60.0) * 0.7
	var samples_per_step := int(MIX_RATE * 60.0 / bpm / 4.0)  # 16th notes

	var frames := _music_pb.get_frames_available()
	for i in frames:
		if _music_sample <= 0:
			_music_step = (_music_step + 1) % ARP_PATTERN.size()
			_music_sample = samples_per_step
		_music_sample -= 1

		var step_pos := 1.0 - float(_music_sample) / float(maxi(samples_per_step, 1))
		# Plucky arpeggio (triangle) with a fast decay envelope.
		var arp_freq: float = PENTA[ARP_PATTERN[_music_step]]
		_music_phase_arp = fmod(_music_phase_arp + arp_freq / MIX_RATE, 1.0)
		var tri := absf(_music_phase_arp * 2.0 - 1.0) * 2.0 - 1.0
		var arp_env := pow(1.0 - step_pos, 2.2)
		var arp := tri * arp_env * 0.28

		# Bass (sine), changes each bar.
		var bass_freq: float = BASS_PATTERN[(_music_step / 4) % BASS_PATTERN.size()] * 0.5
		_music_phase_bass = fmod(_music_phase_bass + bass_freq / MIX_RATE, 1.0)
		var bass := sin(_music_phase_bass * TAU) * 0.22

		var v := arp + bass
		_music_pb.push_frame(Vector2(v, v))


func _on_state_changed(new_state: int) -> void:
	# A fresh run shuffles in a new song from the top. A paid continue
	# (REVIVE_OFFER -> PLAYING) keeps the current song going.
	if new_state == GameManager.GameState.PLAYING and _prev_state != GameManager.GameState.REVIVE_OFFER:
		_start_run_music()
	_prev_state = new_state


## Smoothly fades the real-track player in after a (re)start and ducks it a
## touch outside of active play — standard menu/gameplay music dynamics.
func _update_music_dynamics() -> void:
	if not _real_tracks_active or _music == null:
		return
	var playing := GameManager.current_state == GameManager.GameState.PLAYING
	# The music lifts as the flow-state heats up: a cold start sits a touch ducked
	# and swells to full as a clean streak builds — a hot run literally sounds
	# bigger. Cooling on a crash lets it settle back.
	_music_target_db = lerpf(-3.0, 0.0, GameManager.flow_heat) if playing else -7.0
	_music.volume_db = lerpf(_music.volume_db, _music_target_db, 0.04)
