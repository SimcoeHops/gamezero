## CoinSpawner — emits trails of collectible coins in patterns (lines, weaving
## arcs, double rows) that encourage lateral movement. Wired by Main.gd.

extends Node3D

@export var interval_min: float = 2.2
@export var interval_max: float = 4.0
@export var spawn_z: float = -70.0
@export var coin_spacing: float = 2.0

var player_ref: Node3D = null
var highway_ref: Node3D = null

var _lanes: Array[float] = [-5.5, -2.75, 0.0, 2.75, 5.5]
var _coin_scene: PackedScene = preload("res://scenes/coin/Coin.tscn")
var _timer: Timer = null


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	GameManager.state_changed.connect(_on_game_state_changed)


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PLAYING:
		_reschedule()
	else:
		_timer.stop()


func _reschedule() -> void:
	_timer.wait_time = randf_range(interval_min, interval_max)
	_timer.start()


func _on_timeout() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		_spawn_trail()
		_reschedule()


func _spawn_trail() -> void:
	var count := randi_range(6, 10)
	match randi() % 3:
		0:  # straight line in one lane
			var lane: float = _lanes.pick_random()
			for i in count:
				_make_coin(lane, spawn_z - i * coin_spacing)
		1:  # weaving arc across lanes
			var idx := randi_range(0, _lanes.size() - 1)
			var dir: int = 1 if idx == 0 else (-1 if idx == _lanes.size() - 1 else ([-1, 1].pick_random()))
			for i in count:
				_make_coin(_lanes[idx], spawn_z - i * coin_spacing)
				if i % 2 == 1:
					idx = clampi(idx + dir, 0, _lanes.size() - 1)
					if idx == 0 or idx == _lanes.size() - 1:
						dir = -dir
		2:  # two adjacent lanes
			var a := randi_range(0, _lanes.size() - 2)
			for i in count:
				_make_coin(_lanes[a], spawn_z - i * coin_spacing)
				_make_coin(_lanes[a + 1], spawn_z - i * coin_spacing)


func _make_coin(x: float, z: float) -> void:
	var coin := _coin_scene.instantiate()
	coin.position = Vector3(x, 1.0, z)
	coin.approach_speed = GameManager.highway_speed
	coin.highway_ref = highway_ref
	coin.player_ref = player_ref
	add_child(coin)
