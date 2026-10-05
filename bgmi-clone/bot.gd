class_name Bot
extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK, DEAD }

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 3.5
@export var chase_speed: float = 5.0

@export_group("Combat")
@export var detection_range: float = 20.0
@export var attack_range: float = 12.0
@export var attack_damage: float = 10.0
@export var fire_rate: float = 0.8

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var shoot_ray: RayCast3D = $ShootRay
@onready var body_mesh: MeshInstance3D = $Bodymesh

var current_health: float
var current_state: State = State.PATROL
var player: Player = null

var shoot_timer: float = 0.0
var patrol_timer: float = 0.0
var spawn_position: Vector3
const PATROL_RADIUS: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var anim_player: AnimationPlayer = null
var is_crouching: bool = false
var audio_gun: AudioStreamPlayer3D = null
var sfx_gunshot: AudioStream = null

func _ready() -> void:
	add_to_group("bots")
	current_health = max_health
	spawn_position = global_position

	if shoot_ray:
		shoot_ray.add_exception(self)

	# Setup 3D audio for bot gunfire
	audio_gun = AudioStreamPlayer3D.new()
	audio_gun.name = "BotGunAudio"
	audio_gun.max_distance = 60.0
	add_child(audio_gun)
	if ResourceLoader.exists("res://audio/gunshot.wav"):
		sfx_gunshot = load("res://audio/gunshot.wav")

	_setup_animations()

	await get_tree().physics_frame

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Player

	_set_random_patrol_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD:
		move_and_slide()
		return

	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0] as Player

	match current_state:
		State.PATROL: _tick_patrol(delta)
		State.CHASE:  _tick_chase(delta)
		State.ATTACK: _tick_attack(delta)

	move_and_slide()
	_update_animations()

# ─── STATE LOGIC ──────────────────────────────────────────────────────────────

func _tick_patrol(delta: float) -> void:
	is_crouching = false
	patrol_timer -= delta
	if patrol_timer <= 0.0 or nav_agent.is_navigation_finished():
		_set_random_patrol_target()

	_move_along_nav_path(move_speed)

	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			current_state = State.CHASE

func _tick_chase(delta: float) -> void:
	if not is_instance_valid(player):
		current_state = State.PATROL
		return

	is_crouching = false
	nav_agent.target_position = player.global_position
	var dist = global_position.distance_to(player.global_position)

	if dist <= attack_range and _has_line_of_sight():
		current_state = State.ATTACK
		return
	elif dist > detection_range * 1.5:
		current_state = State.PATROL
		return

	_move_along_nav_path(chase_speed)

func _tick_attack(delta: float) -> void:
	if not is_instance_valid(player):
		current_state = State.PATROL
		return

	if not _has_line_of_sight():
		current_state = State.CHASE
		return

	velocity.x = 0.0
	velocity.z = 0.0

	_look_at_position(player.global_position)

	var dist = global_position.distance_to(player.global_position)
	if dist > attack_range:
		current_state = State.CHASE
		return

	is_crouching = dist > 4.0

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		_shoot()
		shoot_timer = fire_rate

# ─── LINE OF SIGHT ────────────────────────────────────────────────────────────

func _has_line_of_sight() -> bool:
	if not is_instance_valid(player) or not shoot_ray:
		return false

	var aim_target = player.global_position + Vector3(0, 1.0, 0)
	shoot_ray.target_position = shoot_ray.to_local(aim_target)
	shoot_ray.force_raycast_update()

	if shoot_ray.is_colliding():
		var collider = shoot_ray.get_collider()
		return collider == player or (collider and collider.is_in_group("player"))
	return false

# ─── MOVEMENT ─────────────────────────────────────────────────────────────────

func _move_along_nav_path(speed: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_point = nav_agent.get_next_path_position()
	var dir = (next_point - global_position)
	dir.y = 0.0

	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_look_at_position(global_position + dir)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _look_at_position(target_pos: Vector3) -> void:
	var look_target = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)

func _set_random_patrol_target() -> void:
	patrol_timer = randf_range(4.0, 8.0)
	var random_offset := Vector3(
		randf_range(-PATROL_RADIUS, PATROL_RADIUS),
		0.0,
		randf_range(-PATROL_RADIUS, PATROL_RADIUS)
	)
	var target = spawn_position + random_offset
	nav_agent.target_position = NavigationServer3D.map_get_closest_point(
		nav_agent.get_navigation_map(), target
	)

# ─── COMBAT & DAMAGE ──────────────────────────────────────────────────────────

func _shoot() -> void:
	if not is_instance_valid(player) or not shoot_ray:
		return

	if audio_gun and sfx_gunshot:
		audio_gun.stream = sfx_gunshot
		audio_gun.pitch_scale = randf_range(0.85, 0.95)
		audio_gun.volume_db = 0.0
		audio_gun.play()

	var aim_target = player.global_position + Vector3(0, 1.0, 0)
	shoot_ray.target_position = shoot_ray.to_local(aim_target)
	shoot_ray.force_raycast_update()

	if shoot_ray.is_colliding():
		var collider = shoot_ray.get_collider()
		if collider.has_method("take_damage"):
			collider.take_damage(attack_damage)

func hear_sound(source_pos: Vector3, is_gunshot: bool) -> void:
	if current_state == State.DEAD:
		return

	if current_state == State.ATTACK and _has_line_of_sight():
		return

	current_state = State.CHASE
	nav_agent.target_position = source_pos
	_look_at_position(source_pos)

func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return

	current_health -= amount

	if body_mesh and body_mesh.get_surface_override_material(0):
		var mat = body_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var original_color = mat.albedo_color
			mat.albedo_color = Color.RED
			await get_tree().create_timer(0.08).timeout
			if is_instance_valid(self) and current_state != State.DEAD:
				mat.albedo_color = original_color

	if current_health <= 0.0:
		die()

func die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	remove_from_group("bots")

	var tween = create_tween()
	tween.tween_property(self, "rotation:z", deg_to_rad(90.0), 0.25)

	# Drop loot on death
	if ResourceLoader.exists("res://pickup.tscn"):
		var pickup_scene = load("res://pickup.tscn")
		var drop = pickup_scene.instantiate()
		drop.pickup_type = 1 if randf() > 0.5 else 0
		drop.amount = 60.0 if drop.pickup_type == 1 else 50.0
		get_parent().add_child(drop)
		drop.global_position = global_position + Vector3(0, 0.4, 0)

	var match_mgr = get_node_or_null("/root/main/MatchManager")
	if match_mgr and match_mgr.has_method("notify_participant_eliminated"):
		match_mgr.notify_participant_eliminated(name, false)
	else:
		var match_mgrs = get_tree().get_nodes_in_group("match_manager")
		if match_mgrs.size() > 0:
			match_mgrs[0].notify_participant_eliminated(name, false)

	await get_tree().create_timer(3.0).timeout
	queue_free()

# ─── ANIMATIONS ───────────────────────────────────────────────────────────────

func _setup_animations() -> void:
	var ap_list = find_children("*", "AnimationPlayer", true, false)
	if ap_list.size() > 0:
		anim_player = ap_list[0] as AnimationPlayer

	if not anim_player:
		return

	var anim_list = anim_player.get_animation_list()
	for anim_name in anim_list:
		if anim_name != "RESET":
			var idle_anim = anim_player.get_animation(anim_name)
			if idle_anim:
				idle_anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
			break

	_import_anim_from_fbx(["res://Idle Crouching.fbx", "res://Rifle_Crouch.fbx", "res://Crouch_Idle.fbx"], "crouch_idle")
	_import_anim_from_fbx(["res://Crouched Run.fbx", "res://Crouch_Walk.fbx"], "crouch_run")
	_import_anim_from_fbx(["res://Rifle Run.fbx", "res://Run.fbx"], "run")

func _import_anim_from_fbx(candidate_paths: Array, target_anim_name: String) -> void:
	for path in candidate_paths:
		if ResourceLoader.exists(path):
			var scene = load(path).instantiate()
			var aps = scene.find_children("*", "AnimationPlayer", true, false)
			if aps.size() > 0:
				var anims = aps[0].get_animation_list()
				for a_name in anims:
					if a_name != "RESET":
						var anim = aps[0].get_animation(a_name)
						if anim:
							anim.loop_mode = Animation.LOOP_LINEAR
							var lib = anim_player.get_animation_library("")
							if lib and not lib.has_animation(target_anim_name):
								lib.add_animation(target_anim_name, anim)
						break
			scene.queue_free()
			break

func _update_animations() -> void:
	if not anim_player or current_state == State.DEAD:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_crouching:
		if horizontal_speed > 0.5:
			if anim_player.has_animation("crouch_run") and anim_player.current_animation != "crouch_run":
				anim_player.play("crouch_run")
		else:
			if anim_player.has_animation("crouch_idle") and anim_player.current_animation != "crouch_idle":
				anim_player.play("crouch_idle")
	elif horizontal_speed > 0.5:
		if anim_player.has_animation("run") and anim_player.current_animation != "run":
			anim_player.play("run")
	else:
		var idle_anim = "mixamo.com"
		if not anim_player.has_animation(idle_anim):
			for a in anim_player.get_animation_list():
				if a != "run" and a != "crouch_idle" and a != "crouch_run" and a != "RESET":
					idle_anim = a
					break
		if anim_player.current_animation != idle_anim:
			anim_player.play(idle_anim)
