extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame

	var toggle := InputEventKey.new()
	toggle.pressed = true
	toggle.keycode = KEY_QUOTELEFT
	toggle.physical_keycode = KEY_QUOTELEFT
	toggle.unicode = 96
	game._input(toggle)
	assert(bool(game.gm_console_open))

	game._execute_gm_command("next")
	assert(game.phase == "hunt")
	assert(game.seconds_left == game.HUNT_SECONDS)
	assert(game._treasure_is_in_world("treasure-2"))

	game._execute_gm_command("gold B 25")
	assert(int(game.player_coins["B"]) == 25)
	game._execute_gm_command("next")
	assert(game.phase == "shop")
	assert(game.current_round == 1)
	assert(int(game.player_coins["A"]) == 50)

	game._execute_gm_command("give A adrenaline")
	assert((game.player_stashes["A"] as Array).size() == 1)
	assert((game.player_loadouts["A"] as Array).size() == 1)
	game._execute_gm_command("add robot")
	assert((game.player_stashes["A"] as Array).size() == 2)
	assert((game.player_loadouts["A"] as Array).size() == 2)
	assert(str(game._shop_equipped_items("A").back()["tool_type"]) == "robot")
	game._execute_gm_command("add B 机器人")
	assert((game.player_stashes["B"] as Array).size() == 1)
	assert((game.player_loadouts["B"] as Array).size() == 1)
	assert(str(game._shop_equipped_items("B")[0]["tool_type"]) == "robot")
	game._execute_gm_command("next")
	assert(game.phase == "hide")
	assert(game.current_round == 2)
	assert(game._player_for_role("thief") == "A")
	assert((game.tool_inventories["thief"] as Array).size() == 2)
	assert(str(game.tool_inventories["thief"][0]["tool_type"]) == "adrenaline")
	assert(str(game.tool_inventories["thief"][1]["tool_type"]) == "robot")
	assert((game.tool_inventories["monster"] as Array).size() == 1)
	assert(str(game.tool_inventories["monster"][0]["tool_type"]) == "robot")
	game._execute_gm_command("add detector")
	assert((game.tool_inventories["thief"] as Array).size() == 3)
	assert(str(game.tool_inventories["thief"][2]["tool_type"]) == "detector")
	game._execute_gm_command("add alarm")
	assert((game.tool_inventories["thief"] as Array).size() == 3)
	assert("已满" in str(game.gm_output))

	game._execute_gm_command("help")
	assert("gold A 50" in str(game.gm_output))
	assert("add robot" in str(game.gm_output))
	assert("menu" in str(game.gm_output))
	game._execute_gm_command("menu off")
	assert(not bool(game.main_menu_open))
	game._execute_gm_command("menu on")
	assert(bool(game.main_menu_open))
	assert(not bool(game.gm_console_open))
	game._execute_gm_command("menu off")
	assert(not bool(game.main_menu_open))
	game._execute_gm_command("unknown")
	assert("未知命令" in str(game.gm_output))

	for expected_round in [2, 3]:
		assert(game.current_round == expected_round)
		game._execute_gm_command("next")
		assert(game.phase == "hunt")
		game._execute_gm_command("next")
		assert(game.phase == "shop")
		game._execute_gm_command("next")
		assert(game.current_round == expected_round + 1)
		assert(game.phase == "hide")
	assert(game.current_round == 4)
	game._execute_gm_command("next")
	assert(game.phase == "hunt")
	game._execute_gm_command("next")
	assert(game.phase == "ended")
	game._execute_gm_command("next")
	assert(game.phase == "ended")
	assert("四局比赛已经结束" in str(game.gm_output))

	print("GM console test passed: toggle, next-stage flow, gold, give, add, and help.")
	game.free()
	quit(0)
