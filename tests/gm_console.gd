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
	game._execute_gm_command("next")
	assert(game.phase == "hide")
	assert(game.current_round == 2)
	assert(game._player_for_role("thief") == "A")
	assert((game.tool_inventories["thief"] as Array).size() == 1)
	assert(str(game.tool_inventories["thief"][0]["tool_type"]) == "adrenaline")

	game._execute_gm_command("help")
	assert("gold A 50" in str(game.gm_output))
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

	print("GM console test passed: toggle, next-stage flow, gold, give, and help.")
	game.free()
	quit(0)
