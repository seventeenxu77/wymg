extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var renderer: World25D = game.world_25d
	assert(is_equal_approx(World25D.ROOM_SPACING, World25D.ROOM_EXTENT * 2.0))
	assert(is_equal_approx(game.ACTOR_SPEED, 4.0))
	var seam_left := renderer.world_position(Vector2i(2, 2), Vector2(5.0, 2.5))
	var seam_right := renderer.world_position(Vector2i(3, 2), Vector2(0.0, 2.5))
	assert(seam_left.is_equal_approx(seam_right))

	var monster_before: Vector3 = renderer.monster_camera.position
	var thief_before: Vector3 = renderer.thief_camera.position
	var test_room: Vector2i = game.monster["room"]
	var screen_center: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(2.5, 2.5), 0.2))
	var screen_up: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(2.5, 2.0), 0.2))
	assert(absf(screen_up.x - screen_center.x) < 0.01)
	assert(screen_up.y < screen_center.y)
	renderer.rotate_camera("monster", 1)
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var monster_after: Vector3 = renderer.monster_camera.position
	var thief_after_left_rotation: Vector3 = renderer.thief_camera.position
	assert(monster_before.distance_to(monster_after) > 1.0)
	assert(thief_before.is_equal_approx(thief_after_left_rotation))

	renderer.rotate_camera("thief", -1)
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var monster_after_right_rotation: Vector3 = renderer.monster_camera.position
	var thief_after: Vector3 = renderer.thief_camera.position
	assert(monster_after.is_equal_approx(monster_after_right_rotation))
	assert(thief_before.distance_to(thief_after) > 1.0)

	var monster_up: Vector2 = renderer.camera_relative_vector("monster", Vector2.UP)
	var thief_up: Vector2 = renderer.camera_relative_vector("thief", Vector2.UP)
	assert(monster_up.is_equal_approx(Vector2(-1, -1).normalized()))
	assert(thief_up.is_equal_approx(Vector2(1, -1).normalized()))
	renderer.rotate_camera("monster", -1)
	var monster_reset_up: Vector2 = renderer.camera_relative_vector("monster", Vector2.UP)
	var thief_unchanged_up: Vector2 = renderer.camera_relative_vector("thief", Vector2.UP)
	assert(monster_reset_up.is_equal_approx(Vector2.UP))
	assert(thief_unchanged_up.is_equal_approx(thief_up))

	game.monster["pos"] = Vector2(2.5, 2.5)
	var monster_room: Dictionary = game._room_at(game.monster["room"])
	monster_room["furniture"].clear()
	game._move_actor_continuous("monster", Vector2.RIGHT, 0.1)
	assert((game.monster["pos"] as Vector2).is_equal_approx(Vector2(2.9, 2.5)))

	var monster_key: String = renderer._room_key(game.monster["room"])
	var thief_key: String = renderer._room_key(game.thief["room"])
	for key in renderer.room_visuals.keys():
		for visual in renderer.room_visuals[key]:
			var layers: int = (visual as VisualInstance3D).layers
			if key == monster_key:
				assert((layers & World25D.LAYER_MONSTER_WORLD) != 0)
			else:
				assert((layers & World25D.LAYER_MONSTER_WORLD) == 0)
			if key == thief_key:
				assert((layers & World25D.LAYER_THIEF_WORLD) != 0)
			else:
				assert((layers & World25D.LAYER_THIEF_WORLD) == 0)

	print("2.5D smoke test passed: continuous room coordinates, seamless doors, delta movement, and independent view-relative input.")
	quit(0)
