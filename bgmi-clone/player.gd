class_name Player
extends CharacterBody3D

## Signals for UI / HUD
signal health_changed(current_hp: float, max_hp: float)
signal state_changed(new_state: String)

## Movement Speeds (m/s)
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.8
@export var jump_velocity: float = 4.8
@export var acceleration: float = 10.0
@export var friction: float = 12.0

## Camera Look
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-80.0)
@export var max_pitch: float = deg_to_rad(60.0)

## Fall Damage Parameters
@export var max_health: float = 100.0
@export var safe_fall_speed: float = 11.0 # Fall velocity threshold before taking damage
@export var fall_damage_multiplier: float = 7.5

## Node References (Must match your Scene tree names!)
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Bodymesh

## State Variables
var current_health: float = 100.0
var is_dead: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var current_state: String = "IDLE"

var was_in_air: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Heights for smooth crouching
const STANDING_HEIGHT: float = 1.8
const CROUCHING_HEIGHT: float = 1.1
const STANDING_PIVOT_Y: float = 1.5
const CROUCHING_PIVOT_Y: float = 1.0

#adding weapon variables

## Signals
signal ammo_changed(current: int, reserve: int)

## Weapon Parameters
@export_group("Weapon Stats")
@export var damage: float = 35.0
@export var fire_rate: float = 0.12 # Seconds between shots (Auto-rifle)
@export var max_ammo: int = 30
@export var reload_time: float = 1.8
@export var recoil_amount: float = 0.025 # Camera kick (radians)

## Weapon Nodes
@onready var raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/RayCast3D
@onready var gun_holder: Node3D = $gun
@onready var muzzle: Marker3D = $gun/muzzle

## Ammo Runtime State
var current_ammo: int = 30
var reserve_ammo: int = 90
var shoot_timer: float = 0.0
var is_reloading: bool = false
var original_gun_pos: Vector3

func _ready() -> void:
	current_health = max_health
	current_ammo = max_ammo
	if gun_holder:
		original_gun_pos = gun_holder.position
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	# Defer mouse capture so the OS window is fully focused before locking
	call_deferred("_capture_mouse")

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# _input() fires BEFORE any UI node gets a chance to consume the event.
	# This is why mouse look must live here, NOT in _unhandled_input.
	# HUD CanvasLayer/Control nodes would swallow MouseMotion events otherwise.

	# Re-capture mouse on any click (fixes embedded window focus)
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return

	# Escape = release cursor
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# 3rd Person Mouse Look
	if is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, min_pitch, max_pitch)

func _unhandled_input(_event: InputEvent) -> void:
	pass # All input now handled in _input() above


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_handle_crouch(delta)
	_handle_gravity_and_jump(delta)
	_handle_movement(delta)

	# Store vertical speed right before move_and_slide resets it on floor collision
	var vy_before_landing: float = velocity.y

	# Built-in Godot solver handles collision with ground, walls, and slopes
	move_and_slide()

	_check_fall_damage(vy_before_landing)
	_update_state()
	_handle_weapon(delta)

func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true
	else:
		if Input.is_action_just_pressed("jump"):
			if is_crouching:
				is_crouching = false # Stand up when jumping
			velocity.y = jump_velocity

func _handle_movement(delta: float) -> void:
	# Read WASD vector (-1 to 1)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Determine speed based on state
	var speed: float = walk_speed
	if is_crouching:
		speed = crouch_speed
		is_sprinting = false
	elif Input.is_action_pressed("sprint") and input_dir.y < 0: # Sprint only when moving forward
		speed = sprint_speed
		is_sprinting = true
	else:
		is_sprinting = false

	# Transform local input direction to match where character is facing
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Smooth acceleration and deceleration (lerp)
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

	# Smoothly resize capsule collider
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = lerp(capsule.height, target_h, 10.0 * delta)
		collision_shape.position.y = capsule.height / 2.0

	# Smoothly scale visual mesh
	if body_mesh:
		body_mesh.position.y = collision_shape.position.y
		body_mesh.scale.y = lerp(body_mesh.scale.y, target_h / STANDING_HEIGHT, 10.0 * delta)

	# Lower camera smoothly
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_cam_y, 10.0 * delta)

func _check_fall_damage(vy: float) -> void:
	if was_in_air and is_on_floor():
		var impact_speed: float = abs(vy)
		if impact_speed > safe_fall_speed:
			var damage: float = (impact_speed - safe_fall_speed) * fall_damage_multiplier
			take_damage(damage, "Fall Damage (Impact: %.1f m/s)" % impact_speed)
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

func take_damage(amount: float, source: String = "Damage") -> void:
	if is_dead:
		return
	current_health = clamp(current_health - amount, 0.0, max_health)
	print("[Player] -%.1f HP from %s. (Current HP: %.1f/%.1f)" % [amount, source, current_health, max_health])
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0.0:
		die()

func die() -> void:
	is_dead = true
	current_state = "DEAD"
	emit_signal("state_changed", current_state)
	print("[Player] ELIMINATED! Game Over.")

func _handle_weapon(delta: float) -> void:
	# Decrement shot cooldown timer
	if shoot_timer > 0.0:
		shoot_timer -= delta

	# Reload input (R)
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < max_ammo and reserve_ammo > 0:
		reload()

	# Shoot input (Hold Left Click for automatic fire)
	if Input.is_action_pressed("shoot") and not is_reloading and shoot_timer <= 0.0:
		if current_ammo > 0:
			shoot()
		else:
			# Auto-reload if magazine is empty
			if reserve_ammo > 0:
				reload()
			else:
				print("[Gun] CLICK! Empty magazine and zero reserve ammo.")
				shoot_timer = 0.3 # Small delay so it doesn't spam click sound

func shoot() -> void:
	shoot_timer = fire_rate
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, reserve_ammo)

	# 1. Gun Visual Kickback (Tween)
	if gun_holder:
		var tween = create_tween()
		tween.tween_property(gun_holder, "position:z", original_gun_pos.z + 0.06, 0.03)
		tween.tween_property(gun_holder, "position:z", original_gun_pos.z, 0.07)

	# 2. Camera Vertical Recoil Kick
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x + recoil_amount, min_pitch, max_pitch)

	# 3. Physics Raycast Hit Detection
	if raycast and raycast.is_colliding():
		var hit_target = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()

		print("[Gun] 💥 HIT: %s at %s" % [hit_target.name, hit_point])

		# If the object we hit has health / can take damage, hurt it!
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(damage, "Player Rifle")
	else:
		print("[Gun] Missed (Bullet flew into distance). Remaining Ammo: %d/%d" % [current_ammo, reserve_ammo])

func reload() -> void:
	if is_reloading or current_ammo == max_ammo or reserve_ammo <= 0:
		return

	is_reloading = true
	print("[Gun] 🔄 Reloading...")

	# Gun dip animation during reload
	if gun_holder:
		var tween = create_tween()
		tween.tween_property(gun_holder, "position:y", original_gun_pos.y - 0.2, 0.3)
		tween.tween_property(gun_holder, "rotation:z", deg_to_rad(-25.0), 0.3)
		await get_tree().create_timer(reload_time).timeout
		var tween_return = create_tween().set_parallel(true)
		tween_return.tween_property(gun_holder, "position:y", original_gun_pos.y, 0.2)
		tween_return.tween_property(gun_holder, "rotation:z", 0.0, 0.2)

	# Refill magazine from reserve
	var needed_bullets: int = max_ammo - current_ammo
	var bullets_to_add: int = mini(needed_bullets, reserve_ammo)
	current_ammo += bullets_to_add
	reserve_ammo -= bullets_to_add
	is_reloading = false

	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	print("[Gun] ✅ Reload Complete! Ammo: %d/%d" % [current_ammo, reserve_ammo])
