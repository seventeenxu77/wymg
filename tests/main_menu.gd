extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame

	assert(bool(game.main_menu_open))
	for _frame in range(4):
		await process_frame
	assert((game.main_menu_rects as Dictionary).size() == 4)
	game._activate_main_menu_action("settings")
	assert(str(game.main_menu_panel) == "settings")
	await process_frame
	assert((game.main_menu_rects as Dictionary).has("volume_down"))
	assert((game.main_menu_rects as Dictionary).has("fullscreen"))
	assert((game.main_menu_rects as Dictionary).has("settings_back"))
	game._activate_main_menu_action("settings_back")
	assert(str(game.main_menu_panel) == "root")
	game._activate_main_menu_action("exit")
	await process_frame
	assert((game.main_menu_rects as Dictionary).has("exit_cancel"))
	assert((game.main_menu_rects as Dictionary).has("exit_confirm"))
	game._activate_main_menu_action("exit_cancel")
	assert(str(game.main_menu_panel) == "root")

	game._activate_main_menu_action("tutorial")
	assert(not bool(game.main_menu_open))
	assert(bool(game.tutorial_system.active))
	game._close_tutorial_mode(false)
	game._open_main_menu()
	game._activate_main_menu_action("start")
	assert(not bool(game.main_menu_open))
	assert(game.current_round == 1)
	assert(game.phase == "hide")

	print("Main menu test passed: launch gate, four hit regions, settings, tutorial, and match start.")
	game.free()
	quit(0)
