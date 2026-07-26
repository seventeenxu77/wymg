extends SceneTree


func _initialize() -> void:
	var game_script: Script = load("res://scripts/main.gd")
	var game: Node = game_script.new()
	game.rng.seed = 20260726
	game.new_game()

	assert(game.current_round == 1)
	assert(game._player_for_role("monster") == "A")
	assert(game._player_for_role("thief") == "B")
	assert(game.HUNT_SECONDS == 480)
	assert(game.COINS_PER_LOOT_VALUE == 5)

	var ground_pills := 0
	var ground_tools := 0
	var hidden_adrenaline := 0
	var wild_treasure_ids: Dictionary = {}
	for room in game.rooms:
		for item in room["items"]:
			if str(item.get("kind", "")) == "pill":
				ground_pills += 1
			elif str(item.get("kind", "")) == "tool":
				ground_tools += 1
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content.get("kind", "")) == "tool":
					assert(str(content.get("tool_type", "")) == "adrenaline")
					hidden_adrenaline += 1
				elif (
					str(content.get("kind", "")) == "treasure"
					and int(content.get("value", 0)) == 1
				):
					var wild_id := str(content.get("id", ""))
					assert(wild_id.begins_with("wild-treasure-"))
					assert(not wild_treasure_ids.has(wild_id))
					wild_treasure_ids[wild_id] = true
			assert(int(furniture["durability"]) == game._effective_furniture_durability(furniture))
	assert(ground_pills == game.PILL_SPAWN_COUNT)
	assert(ground_tools == 0)
	assert(hidden_adrenaline == game.HIDDEN_ADRENALINE_COUNT)
	assert(wild_treasure_ids.size() == game.WILD_TREASURE_COUNT)

	var valuable_furniture := {
		"base_durability": 3,
		"durability": 3,
		"contents": [{"kind": "treasure", "value": 5}],
	}
	game._refresh_furniture_durability(valuable_furniture)
	assert(int(valuable_furniture["durability"]) == 8)

	game.phase = "hunt"
	game.loot_value = 7
	game._end_round("测试撤离", true)
	assert(game.phase == "ended")
	assert(int(game.round_awards["A"]) == 50)
	assert(int(game.round_awards["B"]) == 35)
	assert(int(game.player_coins["A"]) == 50)
	assert(int(game.player_coins["B"]) == 35)

	game._advance_from_result()
	assert(game.phase == "shop")
	game.shop_selected["A"] = game.SHOP_TOOL_TYPES.find("adrenaline")
	game._buy_selected_shop_tool("A")
	assert(int(game.player_coins["A"]) == 48)
	assert((game.player_stashes["A"] as Array).size() == 1)
	assert((game.player_loadouts["A"] as Array).is_empty())
	assert((game._shop_warehouse_items("A") as Array).size() == 1)
	game.shop_focus["A"] = "warehouse"
	game.warehouse_selected["A"] = 0
	game._equip_selected_warehouse_item("A")
	assert((game.player_loadouts["A"] as Array).size() == 1)
	assert((game._shop_warehouse_items("A") as Array).is_empty())
	assert((game._shop_equipped_items("A") as Array).size() == 1)

	game.shop_focus["A"] = "loadout"
	game.loadout_selected["A"] = 0
	game._unequip_selected_loadout_item("A")
	assert((game.player_loadouts["A"] as Array).is_empty())
	assert((game._shop_warehouse_items("A") as Array).size() == 1)
	game._equip_selected_warehouse_item("A")
	assert((game.player_loadouts["A"] as Array).size() == 1)

	game.shop_ready = {"A": true, "B": true}
	game.current_round += 1
	game._start_round()
	assert(game.current_round == 2)
	assert(game._player_for_role("monster") == "B")
	assert(game._player_for_role("thief") == "A")
	assert((game.tool_inventories["thief"] as Array).size() == 1)
	assert(str(game.tool_inventories["thief"][0]["tool_type"]) == "adrenaline")
	game.phase = "hunt"
	game.elapsed = 1.0
	game.attack_until = 0.0
	var right_attack := InputEventKey.new()
	right_attack.keycode = KEY_KP_2
	right_attack.pressed = true
	game._input(right_attack)
	assert(game.attack_until > game.elapsed)
	game.pills = 1
	game.thief["hp"] = 1
	var left_pill := InputEventKey.new()
	left_pill.physical_keycode = KEY_C
	left_pill.pressed = true
	game._input(left_pill)
	assert(int(game.thief["hp"]) == 2)
	assert(game.pills == 0)

	game._end_round("测试第二局", false, true)
	game._advance_from_result()
	game.current_round += 1
	game._start_round()
	assert(game.current_round == 3)
	assert(game._player_for_role("monster") == "A")
	assert((game.tool_inventories["monster"] as Array).size() == 1)
	assert(str(game.tool_inventories["monster"][0]["tool_type"]) == "adrenaline")

	game.phase = "hunt"
	game.seconds_left = 1
	game.phase_clock = 1.0
	game._update_phase(0.0)
	assert(game.phase == "ended")
	assert(game.extracted_value == 0)

	print("Four-round economy test passed: durability bonus, shop purchases, role swap, timeout, and inherited loadouts.")
	game.free()
	quit(0)
