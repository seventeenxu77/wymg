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
	assert(ground_pills == game.PILL_SPAWN_COUNT)
	assert(ground_tools == 0)
	assert(hidden_adrenaline == game.HIDDEN_ADRENALINE_COUNT)

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
	assert((game.player_loadouts["A"] as Array).size() == 1)

	game.shop_ready = {"A": true, "B": true}
	game.current_round += 1
	game._start_round()
	assert(game.current_round == 2)
	assert(game._player_for_role("monster") == "B")
	assert(game._player_for_role("thief") == "A")
	assert((game.tool_inventories["thief"] as Array).size() == 1)
	assert(str(game.tool_inventories["thief"][0]["tool_type"]) == "adrenaline")

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
