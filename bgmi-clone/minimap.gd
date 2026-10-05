extends Control

@export var radar_range_meters: float = 65.0
@export var radar_color: Color = Color(0.08, 0.12, 0.16, 0.8)
@export var border_color: Color = Color(0.2, 0.7, 0.9, 0.8)

var player: CharacterBody3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Redraw radar every frame
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 4.0
	
	# 1. Draw Radar Background & Rings
	draw_circle(center, radius, radar_color)
	draw_arc(center, radius, 0, TAU, 48, border_color, 2.0, true)
	draw_arc(center, radius * 0.5, 0, TAU, 32, Color(border_color.r, border_color.g, border_color.b, 0.25), 1.0)
	
	# Crosshairs
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(border_color.r, border_color.g, border_color.b, 0.15), 1.0)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(border_color.r, border_color.g, border_color.b, 0.15), 1.0)
	
	if not is_instance_valid(player):
		return

	var player_rot_y: float = player.global_rotation.y
	var scale_factor: float = radius / radar_range_meters

	# 2. Draw Loot Pickups (Small cyan/yellow dots)
	var pickups = get_tree().get_nodes_in_group("pickups")
	for p in pickups:
		if is_instance_valid(p):
			var diff: Vector3 = p.global_position - player.global_position
			var blip_offset := _world_to_radar(diff, player_rot_y, scale_factor)
			if blip_offset.length() <= radius - 4.0:
				var p_color := Color(0.2, 1.0, 0.4) if p.get("pickup_type") == 0 else Color(1.0, 0.8, 0.2)
				draw_circle(center + blip_offset, 3.0, p_color)

	# 3. Draw Enemy Bots (Glowing Red Dots)
	var bots = get_tree().get_nodes_in_group("bots")
	for b in bots:
		if is_instance_valid(b) and b.get("current_state") != 3: # 3 = State.DEAD
			var diff: Vector3 = b.global_position - player.global_position
			var blip_offset := _world_to_radar(diff, player_rot_y, scale_factor)
			
			var is_outside := blip_offset.length() > (radius - 5.0)
			if is_outside:
				blip_offset = blip_offset.normalized() * (radius - 5.0)
				# Draw edge indicator (hollow red dot)
				draw_arc(center + blip_offset, 3.5, 0, TAU, 16, Color(1.0, 0.2, 0.2, 0.7), 1.5)
			else:
				# Inside radar range: solid red enemy blip with glowing ring
				draw_circle(center + blip_offset, 4.0, Color(1.0, 0.15, 0.15))
				draw_arc(center + blip_offset, 6.0, 0, TAU, 16, Color(1.0, 0.2, 0.2, 0.4), 1.0)

	# 4. Draw Center Player Icon (Green Arrow pointing forward)
	var arrow_tip := center + Vector2(0, -7.0)
	var arrow_left := center + Vector2(-4.5, 5.0)
	var arrow_right := center + Vector2(4.5, 5.0)
	var arrow_pts := PackedVector2Array([arrow_tip, arrow_left, center, arrow_right])
	draw_colored_polygon(arrow_pts, Color(0.2, 1.0, 0.4))
	draw_polyline(PackedVector2Array([arrow_tip, arrow_left, center, arrow_right, arrow_tip]), Color.WHITE, 1.0)

func _world_to_radar(world_diff: Vector3, player_yaw: float, scale_factor: float) -> Vector2:
	# Flat 2D vector relative to player facing direction
	var v2 := Vector2(world_diff.x, world_diff.z)
	v2 = v2.rotated(player_yaw)
	return v2 * scale_factor
