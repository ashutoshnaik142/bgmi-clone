class_name Player
extends CharacterBody3D

signal health_changed(current_hp: float, max_hp: float)
signal ammo_changed(current: int, reserve: int)
signal state_changed(new_state: String)

@export_group("Locomotion")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.8
@export var jump_velocity: float = 4.8
@export var acceleration: float = 10.0
@export var friction: float = 12.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-80.0)
@export var max_pitch: float = deg_to_rad(60.0)

@export_group("Health & Damage")
@export var max_health: float = 100.0
@export var safe_fall_speed: float = 11.0
@export var fall_damage_multiplier: float = 7.5

@export_group("Weapon Stats")
@export var damage: float = 35.0
@export var fire_rate: float = 0.12
@export var max_ammo: int = 30
@export var max_reserve_ammo: int = 90
@export var reload_time: float = 1.8
@export var recoil_amount: float = 0.025

# Node refs
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Bodymesh
@onready var raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/RayCast3D
@onready var gun_holder: Node3D = $gun
@onready var muzzle: Marker3D = $gun/muzzle
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var sfx_gunshot := preload("res://audio/gunshot.wav")
var sfx_empty := preload("res://audio/empty_click.wav")
var sfx_hit := preload("res://audio/hit.wav")
var sfx_footstep := preload("res://audio/footstep.wav")
var sfx_reload := preload("res://audio/reload.wav")
var footstep_timer: float = 0.0

# State
var current_health: float = 100.0
var current_ammo: int = 30
var reserve_ammo: int = 90
var is_dead: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var is_reloading: bool = false
var current_state: String = "IDLE"
var was_in_air: bool = false
var shoot_timer: float = 0.0
var original_gun_pos: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

const STANDING_HEIGHT: float = 1.8
const CROUCHING_HEIGHT: float = 1.1
const STANDING_PIVOT_Y: float = 1.5
const CROUCHING_PIVOT_Y: float = 1.0

func _ready() -> void:
	current_health = max_health
	current_ammo = max_ammo
	reserve_ammo = max_reserve_ammo

	if gun_holder:
		original_gun_pos = gun_holder.position

	_setup_animations()
	emit_signal("health_changed", current_health, max_health)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)

	if raycast:
		raycast.add_exception(self)

	call_deferred("_capture_mouse")

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if is_dead:
			return
		var hud = get_node_or_null("/root/main/HUD")
		if hud and hud.has_node("EndScreen") and hud.get_node("EndScreen").visible:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if is_dead:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, min_pitch, max_pitch)

func play_sfx(stream: AudioStream, pitch_variation := 0.0) -> void:
	audio.stream = stream
	audio.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	audio.play()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_handle_crouch(delta)
	_handle_gravity_and_jump(delta)
	_handle_movement(delta)
	_handle_footsteps(delta)

	var vy_before_landing: float = velocity.y
	move_and_slide()

	_check_fall_damage(vy_before_landing)
	_update_state()
	_handle_weapon(delta)

	# Animation switching
	if anim_player:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if is_crouching:
			anim_player.speed_scale = 0.95
			if horizontal_speed > 0.5:
				if anim_player.has_animation("crouch_run") and anim_player.current_animation != "crouch_run":
					anim_player.play("crouch_run")
			else:
				if anim_player.has_animation("crouch_idle") and anim_player.current_animation != "crouch_idle":
					anim_player.play("crouch_idle")
				elif anim_player.has_animation("crouch") and anim_player.current_animation != "crouch":
					anim_player.play("crouch")
		elif horizontal_speed > 0.5:
			anim_player.speed_scale = 1.4 if is_sprinting else 1.0
			if anim_player.has_animation("run") and anim_player.current_animation != "run":
				anim_player.play("run")
		else:
			anim_player.speed_scale = 1.0
			var idle_anim = "mixamo.com"
			if not anim_player.has_animation(idle_anim):
				for a in anim_player.get_animation_list():
					if a != "run" and a != "crouch_idle" and a != "crouch_run" and a != "crouch" and a != "RESET":
						idle_anim = a
						break
			if anim_player.current_animation != idle_anim:
				anim_player.play(idle_anim)

# ─── LOCOMOTION ───────────────────────────────────────────────────────────────

func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true
	else:
		if Input.is_action_just_pressed("jump"):
			if is_crouching:
				is_crouching = false
			velocity.y = jump_velocity

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	var speed: float = walk_speed
	if is_crouching:
		speed = crouch_speed
		is_sprinting = false
	elif Input.is_action_pressed("sprint") and input_dir.y < 0:
		speed = sprint_speed
		is_sprinting = true
	else:
		is_sprinting = false

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var target_vx = direction.x * speed
	var target_vz = direction.z * speed
	var accel = acceleration if direction.length_squared() > 0.0 else friction

	velocity.x = lerp(velocity.x, target_vx, accel * delta)
	velocity.z = lerp(velocity.z, target_vz, accel * delta)

func _handle_crouch(delta: float) -> void:
	if Input.is_action_just_pressed("crouch"):
		is_crouching = !is_crouching

	var target_h := CROUCHING_HEIGHT if is_crouching else STANDING_HEIGHT
	var target_cam_y := CROUCHING_PIVOT_Y if is_crouching else STANDING_PIVOT_Y

	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = lerp(capsule.height, target_h, 10.0 * delta)
		collision_shape.position.y = capsule.height / 2.0

	if body_mesh:
		body_mesh.position.y = collision_shape.position.y
		body_mesh.scale.y = lerp(body_mesh.scale.y, target_h / STANDING_HEIGHT, 10.0 * delta)

	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_y, 10.0 * delta)

func _check_fall_damage(vy: float) -> void:
	if was_in_air and is_on_floor():
		var impact_speed: float = abs(vy)
		if impact_speed > safe_fall_speed:
			var fall_dmg: float = (impact_speed - safe_fall_speed) * fall_damage_multiplier
			take_damage(fall_dmg, "Fall")
		was_in_air = false

func _update_state() -> void:
	var new_state := "IDLE"
	if not is_on_floor():
		new_state = "AIRBORNE"
	elif is_crouching:
		new_state = "CROUCHING"
	elif is_sprinting and velocity.length() > 0.5:
		new_state = "SPRINTING"
	elif velocity.length() > 0.5:
		new_state = "WALKING"

	if new_state != current_state:
		current_state = new_state
		emit_signal("state_changed", current_state)

# ─── COMBAT & WEAPON ──────────────────────────────────────────────────────────

func _handle_weapon(delta: float) -> void:
	if shoot_timer > 0.0:
		shoot_timer -= delta

	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < max_ammo and reserve_ammo > 0:
		reload()

	if Input.is_action_pressed("shoot") and not is_reloading and shoot_timer <= 0.0:
		if current_ammo > 0:
			shoot()
		else:
			if reserve_ammo > 0:
				reload()
			else:
				play_sfx(sfx_empty, 0.05)
				shoot_timer = 0.3

func shoot() -> void:
	shoot_timer = fire_rate
	current_ammo -= 1
	play_sfx(sfx_gunshot, 0.08)
	_emit_sound(55.0, true)

	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0 and huds[0].has_method("update_ammo_ui"):
		huds[0].update_ammo_ui(current_ammo, reserve_ammo)
	elif owner and owner.has_node("HUD"):
		owner.get_node("HUD").update_ammo_ui(current_ammo, reserve_ammo)

	if gun_holder:
		var tween = create_tween()
		tween.tween_property(gun_holder, "position:z", original_gun_pos.z + 0.06, 0.03)
		tween.tween_property(gun_holder, "position:z", original_gun_pos.z, 0.07)

	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x + recoil_amount, min_pitch, max_pitch)

	if raycast and raycast.is_colliding():
		var hit_target = raycast.get_collider()
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(damage)
			play_sfx(sfx_hit, 0.1)

func reload() -> void:
	if is_reloading or current_ammo == max_ammo or reserve_ammo <= 0:
		return

	is_reloading = true
	play_sfx(sfx_reload, 0.05)
	if gun_holder:
		var tween = create_tween()
		tween.tween_property(gun_holder, "position:y", original_gun_pos.y - 0.2, 0.3)
		tween.tween_property(gun_holder, "rotation:z", deg_to_rad(-25.0), 0.3)

		await get_tree().create_timer(reload_time).timeout

		var tween_return = create_tween().set_parallel(true)
		tween_return.tween_property(gun_holder, "position:y", original_gun_pos.y, 0.2)
		tween_return.tween_property(gun_holder, "rotation:z", 0.0, 0.2)
	else:
		await get_tree().create_timer(reload_time).timeout

	var needed_bullets: int = max_ammo - current_ammo
	var bullets_to_add: int = mini(needed_bullets, reserve_ammo)
	current_ammo += bullets_to_add
	reserve_ammo -= bullets_to_add
	is_reloading = false

	emit_signal("ammo_changed", current_ammo, reserve_ammo)

# ─── FOOTSTEPS & SOUND ────────────────────────────────────────────────────────

func _handle_footsteps(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		var step_interval := 0.28 if is_sprinting else (0.65 if is_crouching else 0.42)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = step_interval
			_play_footstep()
	else:
		footstep_timer = 0.05

func _play_footstep() -> void:
	if not audio or not sfx_footstep:
		return

	var sound_radius := 10.0
	if is_crouching:
		audio.volume_db = -18.0
		audio.pitch_scale = 0.85
		sound_radius = 2.5
	elif is_sprinting:
		audio.volume_db = 0.0
		audio.pitch_scale = randf_range(1.05, 1.15)
		sound_radius = 22.0
	else:
		audio.volume_db = -6.0
		audio.pitch_scale = randf_range(0.95, 1.05)
		sound_radius = 10.0

	audio.stream = sfx_footstep
	audio.play()
	_emit_sound(sound_radius, false)

func _emit_sound(radius: float, is_gunshot: bool) -> void:
	var bots = get_tree().get_nodes_in_group("bots")
	for b in bots:
		if is_instance_valid(b) and b.has_method("hear_sound"):
			if global_position.distance_to(b.global_position) <= radius:
				b.hear_sound(global_position, is_gunshot)

# ─── LOOT HELPERS ─────────────────────────────────────────────────────────────

func heal(amount: float) -> bool:
	if current_health >= max_health:
		return false
	current_health = clamp(current_health + amount, 0.0, max_health)
	emit_signal("health_changed", current_health, max_health)
	return true

func add_ammo(amount: int) -> bool:
	if reserve_ammo >= max_reserve_ammo:
		return false
	reserve_ammo = clamp(reserve_ammo + amount, 0, max_reserve_ammo)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	return true

# ─── HEALTH & DAMAGE ──────────────────────────────────────────────────────────

func take_damage(amount: float, source: String = "Enemy") -> void:
	if is_dead:
		return

	current_health = clamp(current_health - amount, 0.0, max_health)
	emit_signal("health_changed", current_health, max_health)

	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	remove_from_group("player")

	var match_mgr = get_node_or_null("/root/main/MatchManager")
	if match_mgr:
		match_mgr.notify_participant_eliminated("Player", true)

	queue_free()

var anim_player: AnimationPlayer = null

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

	_import_anim_from_fbx(["res://Idle Crouching.fbx", "res://Rifle_Crouch.fbx", "res://Crouch_Idle.fbx", "res://Crouch.fbx"], "crouch_idle")
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
