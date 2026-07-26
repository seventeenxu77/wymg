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
	detector["active"] = true
	detector["next_noise"] = 0.0
	game.tool_inventories["monster"].append(detector)
	game._update_tool_states(1.0)
	assert(bool(storage["detector_active"]))
	assert(is_equal_approx(float(detector["charge"]), game.DETECTOR_BATTERY_SECONDS - 1.0))
	assert(not game.noises.is_empty())
	assert(bool(game.noises.back()["global"]))

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
	for index in range(game.TRAP_ESCAPE_PRESSES):
		var left := index % 2 == 0
		game._handle_trap_escape_input(
			"monster",
			KEY_NONE,
			KEY_A if left else KEY_D,
		)
	assert(game.trapped_by["monster"] == "")
	assert(trap["state"] == "recoverable")

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
	game._use_decoy("monster")
	assert((game.monster["pos"] as Vector2).x > before_dash.x)
	assert(test_room["items"].any(func(item): return str(item.get("device_type", "")) == "decoy"))

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

	var renderer := World25D.new()
	var shake_id := "shake-cycle-test"
	var shake_phase := float(abs(shake_id.hash()) % 1000) / 1000.0 * renderer.ITEM_SHAKE_CYCLE
	var burst_time := renderer.ITEM_SHAKE_CYCLE * 2.0 - shake_phase + renderer.ITEM_SHAKE_BURST * 0.5
	var pause_time := renderer.ITEM_SHAKE_CYCLE * 2.0 - shake_phase + renderer.ITEM_SHAKE_BURST + 0.25
	assert(renderer._pickup_item_shake_offset(shake_id, burst_time).length() > 0.01)
	assert(renderer._pickup_item_shake_offset(shake_id, pause_time).is_zero_approx())

	print("Tool system test passed: detector, alarm, trap, adrenaline, decoy, phonograph, teleporter, and spring glove.")
	game.free()
	renderer.free()
	quit(0)
