extends Node

signal match_ended(result_message: String)

@export var match_duration_seconds: float = 300.0
@export var spawn_points: Array[Marker3D] = []
@export var bot_scene: PackedScene

var current_timer: float = 0.0
var is_match_active: bool = false
var hud: CanvasLayer = null

func _ready() -> void:
	current_timer = match_duration_seconds
	
	# Wait for scene tree to stabilize
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Locate HUD node safely
	hud = get_node_or_null("/root/main/HUD")
	if not hud:
		var huds = get_tree().get_nodes_in_group("hud")
		if huds.size() > 0:
			hud = huds[0]

	start_match()

func _process(delta: float) -> void:
	if not is_match_active:
		return

	current_timer -= delta
	if hud and hud.has_method("update_timer_ui"):
		hud.update_timer_ui(current_timer)

	if current_timer <= 0.0:
		_on_timer_expired()

func start_match() -> void:
	is_match_active = true
	
	# Safely handle spawning only if markers are assigned
	if spawn_points.size() > 0 and bot_scene != null:
		_spawn_all_participants()
		
	_update_alive_count()

func _spawn_all_participants() -> void:
	var available_spawns = spawn_points.duplicate()
	available_spawns.shuffle()

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and available_spawns.size() > 0:
		players[0].global_position = available_spawns.pop_back().global_position

	for spawn_marker in available_spawns:
		if bot_scene:
			var bot_instance = bot_scene.instantiate()
			get_parent().add_child(bot_instance)
			bot_instance.global_position = spawn_marker.global_position

func notify_participant_eliminated(unit_name: String, is_player: bool) -> void:
	if not is_match_active:
		return

	await get_tree().process_frame
	_update_alive_count()

	if is_player:
		end_match("DEFEAT! You were eliminated.")
	else:
		var bots = get_tree().get_nodes_in_group("bots")
		if bots.size() == 0:
			end_match("WINNER WINNER CHICKEN DINNER!")

func _update_alive_count() -> void:
	var bots = get_tree().get_nodes_in_group("bots")
	var players = get_tree().get_nodes_in_group("player")
	var total_alive = bots.size() + players.size()
	
	if hud and hud.has_method("update_alive_ui"):
		hud.update_alive_ui(total_alive)

func _on_timer_expired() -> void:
	end_match("TIME UP! Match Draw.")

func end_match(result_message: String) -> void:
	if not is_match_active:
		return

	is_match_active = false
	
	# Unlock mouse cursor so restart button can be clicked
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if hud and hud.has_method("show_match_end_screen"):
		hud.show_match_end_screen(result_message)
	
	match_ended.emit(result_message)

func restart_match() -> void:
	get_tree().reload_current_scene()
