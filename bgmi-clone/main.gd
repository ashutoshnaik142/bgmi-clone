extends Node3D

func _ready() -> void:
	# Generate collisions for every mesh in the arena
	var arena = get_node_or_null("NavigationRegion3D/Sketchfab_Scene")
	if arena:
		for mesh_node in arena.find_children("*", "MeshInstance3D", true, false):
			mesh_node.create_trimesh_collision()

	_spawn_initial_loot()

func _spawn_initial_loot() -> void:
	if not ResourceLoader.exists("res://pickup.tscn"):
		return

	var pickup_scene = load("res://pickup.tscn")
	var loot_spawns := [
		{"pos": Vector3(0, 1.5, 4),    "type": 0, "amt": 50.0},
		{"pos": Vector3(-6, 1.5, -4),  "type": 1, "amt": 60.0},
		{"pos": Vector3(7, 1.5, -8),   "type": 0, "amt": 50.0},
		{"pos": Vector3(-8, 1.5, 8),   "type": 1, "amt": 60.0},
		{"pos": Vector3(12, 1.5, 12),  "type": 1, "amt": 60.0}
	]

	for item in loot_spawns:
		var loot = pickup_scene.instantiate()
		loot.pickup_type = item["type"]
		loot.amount = item["amt"]
		loot.position = item["pos"]
		add_child(loot)
