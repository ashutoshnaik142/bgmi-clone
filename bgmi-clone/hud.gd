extends CanvasLayer

@onready var timer_label: Label = $TopBar/TimerLabel
@onready var alive_label: Label = $TopBar/AliveLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/Label
@onready var ammo_label: Label = $"Ammo Label"

@onready var end_screen: PanelContainer = $EndScreen
@onready var result_label: Label = $EndScreen/VBoxContainer/Label
@onready var restart_button: Button = $EndScreen/VBoxContainer/RestartButton

func _ready() -> void:
	add_to_group("hud")
	if end_screen:
		end_screen.hide()

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

	await get_tree().process_frame

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_node = players[0]
		if not player_node.health_changed.is_connected(update_health_ui):
			player_node.health_changed.connect(update_health_ui)
		if not player_node.ammo_changed.is_connected(update_ammo_ui):
			player_node.ammo_changed.connect(update_ammo_ui)

		update_health_ui(player_node.current_health, player_node.max_health)
		update_ammo_ui(player_node.current_ammo, player_node.reserve_ammo)

func update_timer_ui(time_left: float) -> void:
	var minutes: int = int(time_left) / 60
	var seconds: int = int(time_left) % 60
	if timer_label:
		timer_label.text = "TIME: %02d:%02d" % [minutes, seconds]

func update_alive_ui(count: int) -> void:
	if alive_label:
		alive_label.text = "ALIVE: %d" % count

func update_health_ui(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label:
		health_label.text = "HP: %d/%d" % [int(current), int(max_hp)]

func update_ammo_ui(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current, reserve]

func show_match_end_screen(message: String) -> void:
	if result_label:
		result_label.text = message
	if end_screen:
		end_screen.show()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
