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
	assert(game.COINS_PER_LOOT_VALUE == 1)

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
					and int(content.get("value", 0)) == 2
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
		"contents": [{"kind": "treasure", "value": 10}],
	}
	game._refresh_furniture_durability(valuable_furniture)
	assert(int(valuable_furniture["durability"]) == 13)

	game._begin_hunt_countdown()
	game._enter_hunt()
	assert(game.phase == "hunt")
	assert(game._monster_treasure_value() == 20)
	game.loot_value = 0
	var prospective_values: Dictionary = game._prospective_round_values()
	assert(int(prospective_values["A"]) == 20)
	assert(int(prospective_values["B"]) == 0)
	var stolen_treasure: Dictionary = {}
	var source_room: Dictionary = {}
	for room in game.rooms:
		for furniture in room["furniture"]:
			for content_index in range((furniture["contents"] as Array).size()):
				var content: Dictionary = furniture["contents"][content_index]
				if str(content.get("id", "")) != "treasure-2":
					continue
				stolen_treasure = content
				source_room = room
				(furniture["contents"] as Array).remove_at(content_index)
				break
			if not stolen_treasure.is_empty():
				break
		if not stolen_treasure.is_empty():
			break
	assert(not stolen_treasure.is_empty())
	stolen_treasure["pos"] = Vector2(2.5, 2.5)
	stolen_treasure["collected"] = false
	(source_room["items"] as Array).append(stolen_treasure)
	game.thief["room"] = source_room["coord"]
	game.thief["pos"] = stolen_treasure["pos"]
	game._pick_up_nearby("thief")
	assert(game.stolen_monster_value == 4)
	assert(game.loot_value == 4)
	assert(game._monster_treasure_value() == 16)
	assert(int(game._prospective_round_values()["A"]) == 16)
	assert(int(game._prospective_round_values()["B"]) == 4)
	assert(int(game._projected_player_coins()["A"]) == 16)
	assert(int(game._projected_player_coins()["B"]) == 4)
	game._end_round("测试撤离", true)
	assert(game.phase == "ended")
	assert(int(game.round_awards["A"]) == 16)
	assert(int(game.round_awards["B"]) == 4)
	assert(int(game.player_coins["A"]) == 16)
	assert(int(game.player_coins["B"]) == 4)

	game._advance_from_result()
	assert(game.phase == "shop")
	game.shop_focus["B"] = "products"
	game._handle_shop_input(KEY_RIGHT, KEY_NONE)
	assert(str(game.shop_focus["B"]) == "warehouse")
	game._handle_shop_input(KEY_LEFT, KEY_NONE)
	assert(str(game.shop_focus["B"]) == "products")
	game._handle_shop_input(KEY_KP_6, KEY_NONE)
	assert(str(game.shop_focus["B"]) == "products")
	game.shop_selected["A"] = game.SHOP_TOOL_TYPES.find("adrenaline")
	game._buy_selected_shop_tool("A")
	assert(int(game.player_coins["A"]) == 14)
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
	game.attack_until = 0.0
	game.elapsed = 2.0
	game.monster["room"] = Vector2i(2, 2)
	game.monster["pos"] = Vector2(2.0, 2.5)
	game.monster["dir"] = "right"
	game.monster["facing"] = Vector2.RIGHT
	game.thief["room"] = Vector2i(2, 2)
	game.thief["pos"] = Vector2(3.0, 2.5)
	game.thief["hp"] = 2
	game._attack()
	assert(int(game.thief["hp"]) == 1)
	assert(is_equal_approx(float(game.thief["hit_reaction_started_at"]), game.elapsed))
	assert((game.thief["hit_reaction_direction"] as Vector2).is_equal_approx(Vector2.RIGHT))
	assert(not game._role_can_act("thief"))
	game.elapsed = float(game.status_effects["thief"]["stunned_until"])
	game.pills = 1
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

	game.current_round = game.MATCH_ROUNDS
	game.phase = "hunt"
	game.gm_console_open = true
	game._end_round("GM结束了本局", false, true)
	assert(not bool(game.gm_console_open))
	game.match_end_selected = 0
	var select_menu := InputEventKey.new()
	select_menu.pressed = true
	select_menu.keycode = KEY_RIGHT
	game._input(select_menu)
	assert(int(game.match_end_selected) == 1)
	var final_confirm := InputEventKey.new()
	final_confirm.pressed = true
	final_confirm.keycode = KEY_SPACE
	final_confirm.physical_keycode = KEY_SPACE
	game._input(final_confirm)
	assert(bool(game.main_menu_open))

	game.main_menu_open = false
	game.current_round = game.MATCH_ROUNDS
	game.phase = "ended"
	game.match_end_selected = 0
	game._input(final_confirm)
	assert(game.current_round == 1)
	assert(game.phase == "hide")

	print("Four-round economy test passed: durability, role swap, timeout, inherited loadouts, and space confirmation.")
	game.free()
	quit(0)
