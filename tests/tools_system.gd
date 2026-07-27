extends SceneTree


func _initialize() -> void:
	var game_script: Script = load("res://scripts/main.gd")
	var game: Node = game_script.new()
	game.rng.seed = 20260726
	game.new_game()
	game.phase = "hunt"
	game.elapsed = 0.0

	assert(game.TOOL_INVENTORY_CAPACITY == 3)
	assert(game.TRAP_ESCAPE_PRESSES == 20)
	assert(game.TREASURES.map(func(treasure): return int(treasure["value"])) == [4, 6, 10])
	assert(int(game.WILD_TREASURE["value"]) == 2)
	assert(str(game.WILD_TREASURE["label"]) == "古钱币")
	assert(game.TREASURES.all(func(treasure): return not str(treasure.get("description", "")).is_empty()))
	assert(int(game.TOOL_DEFS["robot"]["price"]) == 5)
	assert(game.SHOP_TOOL_TYPES.has("robot"))
	assert(is_equal_approx(game.ROBOT_SPEED, game.ACTOR_SPEED * 0.5))
	for definition in game.TOOL_DEFS.values():
		assert(not str(definition.get("description", "")).is_empty())
	var tool_count := 0
	var visible_tool_count := 0
	var hidden_tool_count := 0
	var visible_pickup_coords: Array[Vector2i] = []
	for room in game.rooms:
		var room_has_visible_pickup := false
		for item in room["items"]:
			if str(item.get("kind", "")) in ["tool", "pill"]:
				assert(not room_has_visible_pickup)
				room_has_visible_pickup = true
				visible_pickup_coords.append(room["coord"])
			if str(item.get("kind", "")) == "tool":
				tool_count += 1
				visible_tool_count += 1
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content.get("kind", "")) == "tool":
					assert(str(content.get("tool_type", "")) == "adrenaline")
					tool_count += 1
					hidden_tool_count += 1
	assert(tool_count == game._total_tool_spawn_count())
	assert(tool_count == game.HIDDEN_ADRENALINE_COUNT)
	assert(visible_tool_count == 0)
	assert(hidden_tool_count == game.HIDDEN_ADRENALINE_COUNT)
	assert(visible_pickup_coords.size() == game.PILL_SPAWN_COUNT)
	for first in range(visible_pickup_coords.size()):
		for second in range(first + 1, visible_pickup_coords.size()):
			var delta: Vector2i = visible_pickup_coords[first] - visible_pickup_coords[second]
			assert(abs(delta.x) + abs(delta.y) >= 2)

	var test_room: Dictionary = game._room_at(game.monster["room"])
	test_room["furniture"].clear()
	test_room["items"].clear()
	game.monster["pos"] = Vector2(2.5, 2.5)
	game.monster["facing"] = Vector2.RIGHT
	game.monster["dir"] = "right"
	var storage := {
		"id": "tool-test-storage",
		"kind": "木箱",
		"pos": Vector2(3.25, 2.5),
		"rotation": 0.0,
		"opened": false,
		"destroyed": false,
		"damage": 0,
		"base_durability": 3,
		"durability": 3,
		"contents": [{"id": "treasure-test", "kind": "treasure", "label": "测试藏品", "value": 5}],
		"last_hit_time": -10.0,
	}
	test_room["furniture"].append(storage)

	var detector: Dictionary = game._make_tool_instance("detector", "detector-test")
	assert(is_equal_approx(float(detector["charge"]), 54.0))
	detector["active"] = true
	detector["next_noise"] = 0.0
	game.tool_inventories["monster"].append(detector)
	game._update_tool_states(1.0)
	assert(bool(storage["detector_active"]))
	assert(is_equal_approx(float(detector["charge"]), game.DETECTOR_BATTERY_SECONDS - 1.0))
	assert(not game.noises.is_empty())
	assert(bool(game.noises.back()["global"]))
	assert(str(game.noises.back().get("follow_role", "")) == "monster")
	var detector_noise: Dictionary = game.noises.back()
	var detector_origin: Dictionary = game._noise_location(detector_noise)
	game.monster["pos"] = (game.monster["pos"] as Vector2) + Vector2(0.25, 0.0)
	var moved_detector_origin: Dictionary = game._noise_location(detector_noise)
	assert((moved_detector_origin["pos"] as Vector2).is_equal_approx(game.monster["pos"]))
	assert(not (moved_detector_origin["pos"] as Vector2).is_equal_approx(detector_origin["pos"]))
	var charge_before_manual_close := float(detector["charge"])
	game.phase = "ended"
	game.trapped_by["monster"] = "test-trap"
	game._use_selected_tool("monster")
	assert(not bool(detector["active"]))
	assert(is_equal_approx(float(detector["charge"]), charge_before_manual_close))
	game.phase = "hunt"
	game.trapped_by["monster"] = ""
	game._use_selected_tool("monster")
	assert(bool(detector["active"]))
	var detector_trinket := {
		"id": "detector-trinket",
		"kind": "trinket",
		"label": "银汤匙",
		"value": 2,
	}
	storage["contents"].append(detector_trinket)
	var renderer_script: Script = load("res://scripts/world_25d.gd")
	var value_renderer: World25D = renderer_script.new()
	assert(value_renderer._furniture_content_value(storage) == 7)
	assert(value_renderer._item_visual_info(detector_trinket)["path"] == "res://assets/25d/items/silver_spoon.png")
	assert(value_renderer._item_visual_info({
		"id": "wild-treasure-test",
		"kind": "treasure",
		"label": "古钱币",
		"value": 2,
	})["path"] == "res://GJGamejam素材/2.5D物品/copper_coin.png")
	value_renderer.free()
	storage["contents"].resize(1)

	storage["contents"].clear()
	game.tool_inventories["monster"] = [game._make_tool_instance("alarm", "alarm-test")]
	game.tool_selected["monster"] = 0
	game.monster["pos"] = Vector2(0.5, 0.5)
	game._place_alarm("monster")
	assert(game.tool_inventories["monster"].size() == 1)
	assert(storage["contents"].is_empty())
	game.monster["pos"] = Vector2(2.5, 2.5)
	game._place_alarm("monster")
	assert(storage["contents"].size() == 1)
	assert(storage["contents"][0]["kind"] == "alarm")
	assert(game.tool_inventories["monster"].is_empty())
	assert(game._trigger_furniture_alarm(game.monster["room"], storage))
	assert(storage["contents"].is_empty())
	assert(bool(game.noises.back()["global"]))
	assert(is_equal_approx(float(game.noises.back()["duration"]), 5.0))
	storage["contents"].append(game._make_tool_instance("detector", "hidden-tool-test"))
	assert(game._release_furniture_tools(test_room, storage) == 1)
	assert(test_room["items"].back()["tool_type"] == "detector")
	test_room["items"].back()["pos"] = game.monster["pos"] + Vector2(0.8, 0.0)
	var nearby_panel: Dictionary = game._nearby_tool_for_panel("monster")
	assert(not nearby_panel.is_empty())
	assert(nearby_panel["item"]["tool_type"] == "detector")
	assert(float(nearby_panel["distance"]) > game.PICKUP_DISTANCE)
	test_room["items"].back()["pos"] = game.monster["pos"] + Vector2(1.2, 0.0)
	assert(game._nearby_tool_for_panel("monster").is_empty())
	test_room["items"].back()["collected"] = true

	game.tool_inventories["monster"] = [game._make_tool_instance("trap", "trap-test")]
	game.tool_selected["monster"] = 0
	game._place_trap("monster")
	var trap: Dictionary = test_room["items"].back()
	trap["pos"] = game.monster["pos"]
	game.thief["room"] = game.monster["room"]
	game.thief["pos"] = trap["pos"]
	game._pick_up_nearby("thief")
	assert(not bool(trap["collected"]))
	trap["armed_at"] = 0.0
	game._update_devices()
	assert(game.trapped_by["monster"] == trap["id"])
	assert(trap["state"] == "sprung")
	assert(bool(game.monster["trapped"]))
	assert(game.monster["trap_prompt"] == "A")
	game._handle_trap_escape_input("monster", KEY_NONE, KEY_A)
	assert(game.monster["trap_prompt"] == "D")
	for index in range(1, game.TRAP_ESCAPE_PRESSES):
		var left := index % 2 == 0
		game._handle_trap_escape_input(
			"monster",
			KEY_NONE,
			KEY_A if left else KEY_D,
		)
	assert(game.trapped_by["monster"] == "")
	assert(trap["state"] == "recoverable")
	assert(not bool(game.monster["trapped"]))
	assert(game.monster["trap_prompt"] == "")

	game.tool_inventories["monster"] = [game._make_tool_instance("adrenaline", "adrenaline-test")]
	game.tool_selected["monster"] = 0
	game.elapsed = 10.0
	game._use_adrenaline("monster")
	assert(is_equal_approx(game._movement_multiplier("monster"), 2.0))
	game.elapsed = 16.1
	assert(is_equal_approx(game._movement_multiplier("monster"), 0.5))
	game.elapsed = 19.1
	assert(is_equal_approx(game._movement_multiplier("monster"), 1.0))

	game.tool_inventories["monster"] = [game._make_tool_instance("decoy", "decoy-test")]
	game.tool_selected["monster"] = 0
	var before_dash: Vector2 = game.monster["pos"]
	var decoy_started_at: float = game.elapsed
	game._use_decoy("monster")
	assert((game.monster["pos"] as Vector2).x > before_dash.x)
	assert(test_room["items"].any(func(item): return str(item.get("device_type", "")) == "decoy"))
	var decoy: Dictionary = test_room["items"].back()
	assert(is_equal_approx(float(decoy["expires"]), decoy_started_at + 10.0))
	assert((decoy["move_direction"] as Vector2).is_equal_approx(Vector2.LEFT))
	var decoy_before_run: Vector2 = decoy["pos"]
	game._update_devices(0.25)
	assert((decoy["pos"] as Vector2).x < decoy_before_run.x)

	game.tool_inventories["monster"] = [game._make_tool_instance("phonograph", "phonograph-test")]
	game.tool_selected["monster"] = 0
	game._place_phonograph("monster")
	var phonograph: Dictionary = test_room["items"].back()
	assert(phonograph["state"] == "idle")
	game.monster["pos"] = phonograph["pos"]
	assert(game._activate_nearby_phonograph("monster"))
	assert(phonograph["state"] == "playing")
	game.elapsed = float(phonograph["starts_at"])
	var noise_count: int = game.noises.size()
	game._update_devices()
	assert(game.noises.size() > noise_count)
	game.elapsed = float(phonograph["expires"])
	game._update_devices()
	assert(bool(phonograph["collected"]))

	game.phase = "hunt"
	game.has_extracted = false
	game.loot_value = 7
	game.elapsed = 30.0
	game.tool_inventories["thief"] = [game._make_tool_instance("teleporter", "teleporter-test")]
	game.tool_selected["thief"] = 0
	game._start_teleporter("thief")
	assert(is_equal_approx(
		float(game.status_effects["thief"]["teleport_ends"]),
		35.0,
	))
	game.elapsed = 35.0
	game._update_tool_states(0.0)
	assert(game.has_extracted)
	assert(game.extracted_value == 7)
	assert(game.phase == "ended")

	game.phase = "hunt"
	game.has_extracted = false
	game.elapsed = 40.0
	game.monster["room"] = Vector2i(2, 2)
	game.thief["room"] = Vector2i(2, 2)
	game.monster["pos"] = Vector2(2.0, 2.5)
	game.thief["pos"] = Vector2(2.8, 2.5)
	game.monster["facing"] = Vector2.RIGHT
	game.tool_inventories["monster"] = [game._make_tool_instance("spring_glove", "glove-test")]
	game.tool_selected["monster"] = 0
	game._use_spring_glove("monster")
	assert(float(game.status_effects["thief"]["stunned_until"]) == 41.0)
	assert(game.tool_inventories["monster"].is_empty())

	var robot_room: Dictionary = game._room_at(Vector2i(2, 2))
	robot_room["furniture"].clear()
	robot_room["items"].clear()
	game.monster["room"] = Vector2i(2, 2)
	game.monster["pos"] = Vector2(2.0, 2.5)
	game.monster["facing"] = Vector2.RIGHT
	game.monster["dir"] = "right"
	game.thief["room"] = Vector2i(2, 2)
	game.thief["pos"] = Vector2(4.2, 4.2)
	game.status_effects["thief"]["stunned_until"] = 0.0
	var robot_tool: Dictionary = game._make_tool_instance("robot", "robot-test")
	game.tool_inventories["monster"] = [robot_tool]
	game.tool_selected["monster"] = 0
	game._use_selected_tool("monster")
	assert(bool(robot_tool["deployed"]))
	assert(game.tool_inventories["monster"].size() == 1)
	var robot_entry: Dictionary = game._find_device_entry(str(robot_tool["robot_id"]))
	assert(not robot_entry.is_empty())
	var robot: Dictionary = robot_entry["item"]
	var patrol_rooms: Array = robot["patrol_rooms"]
	assert(not patrol_rooms.is_empty())
	for patrol_room_value in patrol_rooms:
		var patrol_room: Vector2i = patrol_room_value
		assert(absi(patrol_room.x - 2) <= 1)
		assert(absi(patrol_room.y - 2) <= 1)
	var robot_room_before: Vector2i = (robot_entry["room"] as Dictionary)["coord"]
	var planned_waypoints: Array = game._make_robot_waypoints(robot, robot_room_before)
	assert(planned_waypoints.size() >= game.ROBOT_ROOM_WANDER_POINTS)
	for index in range(game.ROBOT_ROOM_WANDER_POINTS):
		var local_waypoint: Vector2 = planned_waypoints[index]
		var waypoint_room := Vector2i(
			floori(local_waypoint.x / game.ROOM_SIZE),
			floori(local_waypoint.y / game.ROOM_SIZE),
		)
		assert(waypoint_room == robot_room_before)
	if planned_waypoints.size() > game.ROBOT_ROOM_WANDER_POINTS:
		var exit_waypoint: Vector2 = planned_waypoints.back()
		var exit_room := Vector2i(
			floori(exit_waypoint.x / game.ROOM_SIZE),
			floori(exit_waypoint.y / game.ROOM_SIZE),
		)
		assert(exit_room != robot_room_before)
	var robot_global_before: Vector2 = game._robot_global_position(robot_room_before, robot["pos"])
	var robot_noise_count: int = game.noises.size()
	game._update_devices(0.1)
	robot_entry = game._find_device_entry(str(robot_tool["robot_id"]))
	robot = robot_entry["item"]
	var robot_room_after: Vector2i = (robot_entry["room"] as Dictionary)["coord"]
	var robot_global_after: Vector2 = game._robot_global_position(robot_room_after, robot["pos"])
	var robot_distance: float = robot_global_before.distance_to(robot_global_after)
	assert(robot_distance > 0.0)
	assert(robot_distance <= game.ACTOR_SPEED * 0.5 * 0.1 + 0.001)
	assert(game.noises.size() > robot_noise_count)
	assert(bool(game.noises.back()["global"]))
	assert(str(game.noises.back()["label"]) == "巡夜偶警报")
	assert(str(game.noises.back().get("follow_device_id", "")) == str(robot["id"]))
	var robot_noise_location: Dictionary = game._noise_location(game.noises.back())
	assert((robot_noise_location["room"] as Vector2i) == robot_room_after)
	assert((robot_noise_location["pos"] as Vector2).is_equal_approx(robot["pos"]))

	var transition_delta := Vector2i.ZERO
	var transition_motion := Vector2.ZERO
	for edge in game.DIRECTIONS:
		var candidate_delta: Vector2i = edge["delta"]
		if not patrol_rooms.has(robot_room_after + candidate_delta):
			continue
		transition_delta = candidate_delta
		match str(edge["name"]):
			"up":
				robot["pos"] = Vector2(2.5, 0.02)
				transition_motion = Vector2(0.0, -0.05)
			"right":
				robot["pos"] = Vector2(game.ROOM_SIZE - 0.02, 2.5)
				transition_motion = Vector2(0.05, 0.0)
			"down":
				robot["pos"] = Vector2(2.5, game.ROOM_SIZE - 0.02)
				transition_motion = Vector2(0.0, 0.05)
			"left":
				robot["pos"] = Vector2(0.02, 2.5)
				transition_motion = Vector2(-0.05, 0.0)
		break
	assert(transition_delta != Vector2i.ZERO)
	var transitioned_room: Vector2i = game._move_robot_axis(
		robot,
		robot_room_after,
		transition_motion,
	)
	assert(transitioned_room == robot_room_after + transition_delta)
	assert(not (game._room_at(robot_room_after)["items"] as Array).has(robot))
	assert((game._room_at(transitioned_room)["items"] as Array).has(robot))
	robot_room_after = transitioned_room

	var robot_pos: Vector2 = robot["pos"]
	game.thief["room"] = robot_room_after
	if robot_pos.x >= 1.0:
		game.thief["pos"] = robot_pos - Vector2(0.75, 0.0)
		game.thief["facing"] = Vector2.RIGHT
		game.thief["dir"] = "right"
	else:
		game.thief["pos"] = robot_pos + Vector2(0.75, 0.0)
		game.thief["facing"] = Vector2.LEFT
		game.thief["dir"] = "left"
	game._hit_furniture("thief")
	game._update_furniture_hit_actions(
		game.HIT_WINDUP_TIME + game.HIT_LUNGE_TIME + game.HIT_RECOVER_TIME + 0.01
	)
	assert(is_equal_approx(float(robot["stunned_until"]), game.elapsed + 10.0))
	game.elapsed += 2.0
	game._hit_furniture("thief")
	game._update_furniture_hit_actions(
		game.HIT_WINDUP_TIME + game.HIT_LUNGE_TIME + game.HIT_RECOVER_TIME + 0.01
	)
	assert(is_equal_approx(float(robot["stunned_until"]), game.elapsed + 10.0))
	var monster_before_failed_swap: Vector2 = game.monster["pos"]
	game._use_selected_tool("monster")
	assert(game.monster["pos"] == monster_before_failed_swap)
	assert(game.tool_inventories["monster"].size() == 1)

	game.elapsed = float(robot["stunned_until"])
	robot_entry = game._find_device_entry(str(robot_tool["robot_id"]))
	var swap_room: Vector2i = (robot_entry["room"] as Dictionary)["coord"]
	var swap_pos: Vector2 = (robot_entry["item"] as Dictionary)["pos"]
	game._use_selected_tool("monster")
	assert(game.monster["room"] == swap_room)
	assert(game.monster["pos"] == swap_pos)
	assert(game.tool_inventories["monster"].is_empty())
	assert(bool((robot_entry["item"] as Dictionary)["collected"]))

	var renderer := World25D.new()
	var shake_id := "shake-cycle-test"
	var shake_phase := float(abs(shake_id.hash()) % 1000) / 1000.0 * renderer.ITEM_SHAKE_CYCLE
	var burst_time := renderer.ITEM_SHAKE_CYCLE * 2.0 - shake_phase + renderer.ITEM_SHAKE_BURST * 0.5
	var pause_time := renderer.ITEM_SHAKE_CYCLE * 2.0 - shake_phase + renderer.ITEM_SHAKE_BURST + 0.25
	assert(renderer._pickup_item_shake_offset(shake_id, burst_time).length() > 0.01)
	assert(renderer._pickup_item_shake_offset(shake_id, pause_time).is_zero_approx())

	print("Tool system test passed: detector, alarm, trap, adrenaline, decoy, phonograph, teleporter, spring glove, and patrol robot.")
	game.free()
	renderer.free()
	quit(0)
