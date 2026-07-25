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
	assert(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")))
	assert(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")) == 60)
	assert(game.is_physics_processing())
	assert(is_equal_approx(World25D.ROOM_SPACING, World25D.ROOM_EXTENT * 2.0))
	assert(is_equal_approx(game.ACTOR_SPEED, 4.0))
	assert(renderer.monster_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(renderer.thief_camera.projection == Camera3D.PROJECTION_PERSPECTIVE)
	assert(is_equal_approx(renderer.monster_camera.fov, World25D.CAMERA_FOV))
	assert(is_equal_approx(renderer.thief_camera.fov, World25D.CAMERA_FOV))
	assert(renderer.monster_viewport.size == World25D.VIEWPORT_SIZE)
	assert(renderer.thief_viewport.size == World25D.VIEWPORT_SIZE)
	assert(renderer.monster_viewport.msaa_3d == Viewport.MSAA_4X)
	assert(renderer.thief_viewport.msaa_3d == Viewport.MSAA_4X)
	assert(renderer.monster_viewport.use_taa)
	assert(renderer.thief_viewport.use_taa)
	assert(World25D.FLOOR_TEXTURES.size() == 12)
	assert(renderer.monster_node.has_node("SwayPivot/OutlineSprite"))
	assert(renderer.thief_node.has_node("SwayPivot/OutlineSprite"))
	assert((renderer.monster_node.get_node("SwayPivot/PaperSprite") as Sprite3D).texture != null)
	assert((renderer.thief_node.get_node("SwayPivot/PaperSprite") as Sprite3D).texture != null)
	assert((renderer.monster_camera.cull_mask & World25D.LAYER_MONSTER) != 0)
	assert((renderer.monster_camera.cull_mask & World25D.LAYER_THIEF) == 0)
	assert((renderer.monster_camera.cull_mask & World25D.LAYER_SHARED_ACTORS) != 0)
	assert((renderer.thief_camera.cull_mask & World25D.LAYER_THIEF) != 0)
	assert((renderer.thief_camera.cull_mask & World25D.LAYER_MONSTER) == 0)
	assert((renderer.thief_camera.cull_mask & World25D.LAYER_SHARED_ACTORS) != 0)
	var monster_sprite := renderer.monster_node.get_node("SwayPivot/PaperSprite") as Sprite3D
	var thief_sprite := renderer.thief_node.get_node("SwayPivot/PaperSprite") as Sprite3D
	assert((monster_sprite.layers & World25D.LAYER_SHARED_ACTORS) == 0)
	assert((thief_sprite.layers & World25D.LAYER_SHARED_ACTORS) == 0)
	var original_thief_room: Vector2i = game.thief["room"]
	var original_thief_pos: Vector2 = game.thief["pos"]
	game.thief["room"] = game.monster["room"]
	game.thief["pos"] = game.monster["pos"]
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	assert((monster_sprite.layers & World25D.LAYER_SHARED_ACTORS) != 0)
	assert((thief_sprite.layers & World25D.LAYER_SHARED_ACTORS) != 0)
	game.thief["room"] = original_thief_room
	game.thief["pos"] = original_thief_pos
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	assert((monster_sprite.layers & World25D.LAYER_SHARED_ACTORS) == 0)
	assert((thief_sprite.layers & World25D.LAYER_SHARED_ACTORS) == 0)
	var visibility_afterimage := [{
		"created": 1234.0,
		"room": game.monster["room"],
		"pos": game.monster["pos"],
	}]
	renderer._sync_afterimages(visibility_afterimage, game.monster["room"], game.thief["room"])
	var visibility_afterimage_node: Node3D = renderer.afterimage_nodes["1234.0000"]
	assert(not visibility_afterimage_node.visible)
	renderer._sync_afterimages(visibility_afterimage, game.monster["room"], game.monster["room"])
	assert(visibility_afterimage_node.visible)
	renderer._sync_afterimages([], game.monster["room"], game.thief["room"])
	assert(not renderer.afterimage_nodes.has("1234.0000"))
	for floor_path in World25D.FLOOR_TEXTURES:
		assert(ResourceLoader.exists(floor_path))
	for furniture_kind in ["床", "衣柜", "书柜", "木桶", "木箱", "花瓶"]:
		var visual_info: Dictionary = renderer._furniture_info(furniture_kind)
		assert(ResourceLoader.exists(visual_info["path"]))
	assert(game._furniture_durability("花瓶") == 1)
	assert(game._furniture_durability("木桶") == 2)
	assert(game._furniture_durability("木箱") == 3)
	assert(game._furniture_durability("衣柜") == 4)
	var ui_layout: Dictionary = game._calculate_layout(Vector2(1440, 810))
	assert(not ui_layout.has("center"))
	assert(is_equal_approx(ui_layout["monster_panel"].size.x, ui_layout["thief_panel"].size.x))
	assert(ui_layout["thief_panel"].position.x - ui_layout["monster_panel"].end.x <= 10.0)
	assert(ui_layout["monster_room"].size.x >= 640.0)
	assert(ui_layout["thief_room"].size == ui_layout["monster_room"].size)
	game.queue_redraw()
	await process_frame
	assert(game.early_rect.has_area())
	var actual_ui_layout: Dictionary = game._calculate_layout(game.get_viewport_rect().size)
	assert(actual_ui_layout["monster_panel"].encloses(game.early_rect))
	_press_key(game, KEY_F1, KEY_F1)
	assert(bool(game.help_open["monster"]))
	assert(not bool(game.help_open["thief"]))
	assert(game._help_blocks_key(KEY_W, KEY_W))
	_press_key(game, KEY_ESCAPE, KEY_ESCAPE)
	assert(not bool(game.help_open["monster"]))
	_press_key(game, KEY_KP_ADD, KEY_KP_ADD)
	assert(bool(game.help_open["thief"]))
	assert(game._help_blocks_key(KEY_KP_0, KEY_KP_0))
	_press_key(game, KEY_ESCAPE, KEY_ESCAPE)
	assert(not bool(game.help_open["thief"]))
	var elapsed_before_render: float = game.elapsed
	game._process(0.5)
	assert(is_equal_approx(game.elapsed, elapsed_before_render))
	game._physics_process(1.0 / 60.0)
	assert(is_equal_approx(game.elapsed, elapsed_before_render + 1.0 / 60.0))
	var seam_left := renderer.world_position(Vector2i(2, 2), Vector2(5.0, 2.5))
	var seam_right := renderer.world_position(Vector2i(3, 2), Vector2(0.0, 2.5))
	assert(seam_left.is_equal_approx(seam_right))

	var monster_before: Vector3 = renderer.monster_camera.position
	var thief_before: Vector3 = renderer.thief_camera.position
	var test_room: Vector2i = game.monster["room"]
	var test_actor_pos: Vector2 = game.monster["pos"]
	var screen_center: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, test_actor_pos, 0.2))
	var screen_up: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, test_actor_pos + Vector2(0.0, -0.5), 0.2))
	assert(absf(screen_up.x - screen_center.x) < 0.01)
	assert(screen_up.y < screen_center.y)
	var near_left: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(2.0, 4.5), 0.2))
	var near_right: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(3.0, 4.5), 0.2))
	var far_left: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(2.0, 0.5), 0.2))
	var far_right: Vector2 = renderer.monster_camera.unproject_position(renderer.world_position(test_room, Vector2(3.0, 0.5), 0.2))
	assert(near_left.distance_to(near_right) > far_left.distance_to(far_right))
	renderer.rotate_camera("monster", 1)
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var monster_after: Vector3 = renderer.monster_camera.position
	var thief_after_left_rotation: Vector3 = renderer.thief_camera.position
	assert(monster_before.distance_to(monster_after) > 1.0)
	assert(thief_before.is_equal_approx(thief_after_left_rotation))
	assert(is_equal_approx(game._minimap_rotation("monster"), deg_to_rad(45.0)))
	assert(is_equal_approx(game._minimap_rotation("thief"), 0.0))

	renderer.rotate_camera("thief", -1)
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var monster_after_right_rotation: Vector3 = renderer.monster_camera.position
	var thief_after: Vector3 = renderer.thief_camera.position
	assert(monster_after.is_equal_approx(monster_after_right_rotation))
	assert(thief_before.distance_to(thief_after) > 1.0)
	assert(is_equal_approx(game._minimap_rotation("monster"), deg_to_rad(45.0)))
	assert(is_equal_approx(game._minimap_rotation("thief"), deg_to_rad(315.0)))
	game.queue_redraw()
	await process_frame

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
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var follow_camera_before: Vector3 = renderer.monster_camera.position
	var follow_actor_before: Vector3 = renderer.world_position(game.monster["room"], game.monster["pos"], 0.86)
	game._move_actor_continuous("monster", Vector2.RIGHT, 0.1)
	assert((game.monster["pos"] as Vector2).is_equal_approx(Vector2(2.9, 2.5)))
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var follow_camera_after: Vector3 = renderer.monster_camera.position
	var follow_actor_after: Vector3 = renderer.world_position(game.monster["room"], game.monster["pos"], 0.86)
	assert((follow_camera_after - follow_camera_before).is_equal_approx(follow_actor_after - follow_actor_before))
	assert((follow_camera_before - follow_actor_before).is_equal_approx(follow_camera_after - follow_actor_after))

	var monster_key: String = renderer._room_key(game.monster["room"])
	var thief_key: String = renderer._room_key(game.thief["room"])
	assert(renderer.active_monster_room == game.monster["room"])
	assert(renderer.active_thief_room == game.thief["room"])
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
	var dynamic_visual := MeshInstance3D.new()
	renderer._register_room_visual(game.monster["room"], dynamic_visual)
	assert((dynamic_visual.layers & World25D.LAYER_MONSTER_WORLD) != 0)
	dynamic_visual.free()
	var alternate_room := World25D.INVALID_ROOM
	for candidate in game.rooms:
		var candidate_coord: Vector2i = candidate["coord"]
		if candidate_coord != game.monster["room"] and candidate_coord != game.thief["room"]:
			alternate_room = candidate_coord
			break
	assert(alternate_room != World25D.INVALID_ROOM)
	renderer._sync_room_layers(alternate_room, game.thief["room"])
	assert(renderer.active_monster_room == alternate_room)
	for visual in renderer.room_visuals[renderer._room_key(alternate_room)]:
		assert(((visual as VisualInstance3D).layers & World25D.LAYER_MONSTER_WORLD) != 0)
	renderer._sync_room_layers(game.monster["room"], game.thief["room"])
	assert(renderer.active_monster_room == game.monster["room"])

	assert(is_equal_approx(game.TRINKET_SPAWN_CHANCE, 0.5))
	for generated_room in game.rooms:
		for generated_furniture in generated_room["furniture"]:
			assert(generated_furniture.has("contents"))
			assert(generated_furniture.has("durability"))
			for generated_content in generated_furniture["contents"]:
				assert(generated_content["kind"] == "trinket")
				assert(int(generated_content["value"]) == 1)

	game.new_game()
	var storage_room: Dictionary = game._room_at(game.monster["room"])
	storage_room["furniture"].clear()
	storage_room["items"].clear()
	game.monster["pos"] = Vector2(2.5, 2.5)
	game.monster["dir"] = "right"
	game.monster["facing"] = Vector2.RIGHT
	var test_storage := {
		"id": "test-storage",
		"kind": "木箱",
		"pos": Vector2(3.2, 2.5),
		"rotation": 0.0,
		"opened": false,
		"destroyed": false,
		"damage": 0,
		"durability": 3,
		"contents": [],
		"last_hit_time": -10.0,
	}
	storage_room["furniture"].append(test_storage)
	game._hit_furniture("monster")
	assert(not (game.furniture_hit_actions["monster"] as Dictionary).is_empty())
	assert(not bool(test_storage["opened"]))
	game._update_furniture_hit_actions(game.HIT_WINDUP_TIME * 0.5)
	assert((game.monster["impact_visual_offset"] as Vector2).dot(Vector2.RIGHT) < 0.0)
	assert(not bool(test_storage["opened"]))
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var animated_actor_position := renderer.world_position(
		game.monster["room"],
		(game.monster["pos"] as Vector2) + (game.monster["impact_visual_offset"] as Vector2)
	)
	assert(renderer.monster_node.position.is_equal_approx(animated_actor_position))
	game._update_furniture_hit_actions(game.HIT_WINDUP_TIME * 0.5 + game.HIT_LUNGE_TIME + 0.001)
	assert(bool(test_storage["opened"]))
	assert(game.active_storage_id == "test-storage")
	assert(game._active_storage_furniture()["id"] == "test-storage")
	assert(int(test_storage["damage"]) == 0)
	assert(is_equal_approx(float(test_storage["last_hit_time"]), game.elapsed))
	game._update_furniture_hit_actions(game.HIT_RECOVER_TIME)
	assert((game.monster["impact_visual_offset"] as Vector2).is_zero_approx())
	var panel_locked_position: Vector2 = game.monster["pos"]
	game._apply_view_relative_input("monster", Vector2.RIGHT, 0.1)
	assert((game.monster["pos"] as Vector2).is_equal_approx(panel_locked_position))
	game.selected_treasure = 0
	_press_key(game, KEY_S, KEY_S)
	assert(game.selected_treasure == 1)
	_press_key(game, KEY_W, KEY_W)
	assert(game.selected_treasure == 0)
	_press_key(game, KEY_R, KEY_R)
	assert(test_storage["contents"].size() == 1)
	assert(test_storage["contents"][0]["id"] == "treasure-2")
	assert(renderer._furniture_content_value(test_storage) == 2)
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed)
	var storage_rotation_before: float = (renderer.furniture_nodes["test-storage"] as Node3D).rotation.y
	renderer.sync(game.rooms, game.monster, game.thief, game.afterimages, game.dragging, false, game.elapsed + 0.07)
	var storage_rotation_after: float = (renderer.furniture_nodes["test-storage"] as Node3D).rotation.y
	assert(not is_equal_approx(storage_rotation_before, storage_rotation_after))
	assert(game.selected_treasure == 0)
	_press_key(game, KEY_R, KEY_R)
	assert(test_storage["contents"].is_empty())
	_press_key(game, KEY_R, KEY_R)
	assert(test_storage["contents"].size() == 1)
	assert(test_storage["contents"][0]["id"] == "treasure-2")
	_press_key(game, KEY_S, KEY_S)
	assert(game.selected_treasure == 1)
	_press_key(game, KEY_R, KEY_R)
	assert(test_storage["contents"].size() == 1)
	assert(test_storage["contents"][0]["id"] == "treasure-2")
	game.queue_redraw()
	await process_frame
	_press_key(game, KEY_ESCAPE, KEY_ESCAPE)
	assert(game.active_storage_id == "")
	test_storage["contents"].append({
		"id": "test-trinket",
		"kind": "trinket",
		"label": "旧怀表",
		"value": 1,
	})
	assert(renderer._furniture_content_value(test_storage) == 3)

	game.phase = "hunt"
	game.thief["room"] = game.monster["room"]
	game.thief["pos"] = Vector2(2.5, 2.5)
	game.thief["dir"] = "right"
	game.thief["facing"] = Vector2.RIGHT
	game._hit_furniture("thief")
	game._update_furniture_hit_actions(game.HIT_WINDUP_TIME + game.HIT_LUNGE_TIME + game.HIT_RECOVER_TIME)
	game._hit_furniture("thief")
	game._update_furniture_hit_actions(game.HIT_WINDUP_TIME + game.HIT_LUNGE_TIME + game.HIT_RECOVER_TIME)
	assert(not bool(test_storage["destroyed"]))
	assert(int(test_storage["damage"]) == 2)
	game._hit_furniture("thief")
	game._update_furniture_hit_actions(game.HIT_WINDUP_TIME + game.HIT_LUNGE_TIME + game.HIT_RECOVER_TIME)
	assert(bool(test_storage["destroyed"]))
	assert(test_storage["contents"].is_empty())
	assert(storage_room["items"].size() == 2)
	for released_item in storage_room["items"]:
		game.thief["pos"] = released_item["pos"]
		game._thief_search()
	assert(game.loot_value == 3)
	assert(game.extracted_value == 0)

	game.thief["room"] = game.ENTRANCE_ROOM
	game.thief["pos"] = game.ENTRANCE_POS
	game._thief_exit()
	assert(game.has_extracted)
	assert(game.extracted_value == 3)
	assert(game.phase == "ended")
	game.loot_value = 99
	game._thief_exit()
	assert(game.extracted_value == 3)

	print("2.5D smoke test passed: movement, room visibility, storage damage, loot carrying, and one-time extraction.")
	quit(0)


func _press_key(game: Node, key: Key, physical: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = physical
	game._input(event)
