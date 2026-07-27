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
	var hud: GameHud = game.hud
	game._input(_key(KEY_D, KEY_D))
	hud._process(0.016)
	assert(int(game.main_menu_selected) == 1)
	assert(str(hud.main_menu_slam_action) == "start")
	assert(hud.main_menu_shake_started_at > hud.main_menu_slam_started_at)
	assert(hud._main_menu_slam_lift(hud.MAIN_MENU_SLAM_IMPACT_SECONDS) < 0.0)
	game._input(_key(KEY_A, KEY_A))
	hud._process(0.016)
	assert(int(game.main_menu_selected) == 0)
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
	var before_pause_elapsed := float(game.elapsed)
	game._input(_key(KEY_ESCAPE, KEY_ESCAPE))
	assert(bool(game.game_pause_open))
	game._physics_process(1.0)
	assert(is_equal_approx(float(game.elapsed), before_pause_elapsed))
	game._input(_key(KEY_ESCAPE, KEY_ESCAPE))
	assert(not bool(game.game_pause_open))
	game._input(_key(KEY_ESCAPE, KEY_ESCAPE))
	game._input(_key(KEY_D, KEY_D))
	assert(int(game.game_pause_selected) == 1)
	game._input(_key(KEY_R, KEY_R))
	assert(bool(game.main_menu_open))
	assert(not bool(game.game_pause_open))

	print("Main menu test passed: launch gate, settings, tutorial, match start, and in-game exit menu.")
	game.free()
	quit(0)


func _key(key: Key, physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = physical
	return event
