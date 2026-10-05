class_name Pickup
extends Area3D

enum Type { HEALTH, AMMO }

@export var pickup_type: Type = Type.HEALTH
@export var amount: float = 50.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D
@onready var light: OmniLight3D = $OmniLight3D

var time_passed: float = 0.0
var base_y: float = 0.0

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _process(delta: float) -> void:
	time_passed += delta
	rotate_y(delta * 2.0)
	position.y = base_y + sin(time_passed * 3.0) * 0.12

func _setup_visuals() -> void:
	var mat = StandardMaterial3D.new()
	if pickup_type == Type.HEALTH:
		mat.albedo_color = Color(0.1, 0.9, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.9, 0.3)
		mat.emission_energy_multiplier = 0.6
		if label:
			label.text = "+%d HP MEDKIT" % int(amount)
			label.modulate = Color(0.2, 1.0, 0.4)
		if light:
			light.light_color = Color(0.1, 0.9, 0.3)
	else:
		mat.albedo_color = Color(1.0, 0.75, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.1)
		mat.emission_energy_multiplier = 0.6
		if label:
			label.text = "+%d AMMO" % int(amount)
			label.modulate = Color(1.0, 0.85, 0.2)
		if light:
			light.light_color = Color(1.0, 0.75, 0.1)

	if mesh:
		mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	var picked_up := false
	if pickup_type == Type.HEALTH:
		if body.has_method("heal"):
			picked_up = body.heal(amount)
	elif pickup_type == Type.AMMO:
		if body.has_method("add_ammo"):
			picked_up = body.add_ammo(int(amount))

	if picked_up:
		if body.has_method("play_sfx") and body.get("sfx_reload"):
			body.play_sfx(body.get("sfx_reload"), 0.1)
		queue_free()
