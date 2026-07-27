@tool
extends "res://scripts/systems/tool_system.gd"

const GAME_HUD_SCRIPT := preload("res://scripts/presentation/game_hud.gd")
const TUTORIAL_SYSTEM_SCRIPT := preload("res://scripts/tutorial/tutorial_system.gd")
const TUTORIAL_HUD_SCRIPT := preload("res://scripts/tutorial/tutorial_hud.gd")

var hud: Node2D
var tutorial_system: Node
var tutorial_hud: Node2D

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	_load_sound_streams()
	_setup_walk_players()
	world_25d = WORLD_25D_SCRIPT.new()
	world_25d.name = "World25DRenderer"
	add_child(world_25d)
	world_25d.setup(get_viewport().world_3d)
	hud = GAME_HUD_SCRIPT.new()
	hud.name = "GameHud"
	add_child(hud)
	hud.setup(self)
	tutorial_system = TUTORIAL_SYSTEM_SCRIPT.new()
	tutorial_system.name = "TutorialSystem"
	add_child(tutorial_system)
	tutorial_system.setup(self)
	tutorial_system.all_players_ready.connect(_on_tutorial_players_ready)
	tutorial_system.return_to_main_menu_requested.connect(_on_tutorial_return_to_main_menu)
	tutorial_hud = TUTORIAL_HUD_SCRIPT.new()
	tutorial_hud.name = "TutorialHud"
	add_child(tutorial_hud)
	tutorial_hud.setup(self, tutorial_system)
	new_game()
	_initialize_main_menu()
	set_process(true)
	set_physics_process(true)
	set_process_input(true)


func _initialize_main_menu() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var linear_volume := db_to_linear(AudioServer.get_bus_volume_db(master_bus))
		main_menu_volume_step = clampi(roundi(linear_volume * 10.0), 0, 10)
	_open_main_menu()


func _open_main_menu() -> void:
	if tutorial_system and tutorial_system.active:
		tutorial_system.close()
	tutorial_transition_active = false
	game_pause_open = false
	game_pause_rects.clear()
	match_end_selected = 0
	match_end_rects.clear()
	main_menu_open = true
	main_menu_panel = "root"
	main_menu_selected = 0
	main_menu_rects.clear()
	for audio_player in walk_players.values():
		if is_instance_valid(audio_player):
			(audio_player as AudioStreamPlayer).stop()


func new_game() -> void:
	game_pause_open = false
	game_pause_selected = 0
	game_pause_rects.clear()
	match_end_selected = 0
	match_end_rects.clear()
	current_round = 1
	player_coins = {"A": 0, "B": 0}
	player_stashes = {"A": [], "B": []}
	player_loadouts = {"A": [], "B": []}
	shop_selected = {"A": 0, "B": 0}
	shop_focus = {"A": "products", "B": "products"}
	warehouse_selected = {"A": 0, "B": 0}
	loadout_selected = {"A": 0, "B": 0}
	shop_ready = {"A": false, "B": false}
	round_awards = {"A": 0, "B": 0}
	match_totals = {"A": 0, "B": 0}
	next_device_id = 0
	gm_console_open = false
	gm_command = ""
	gm_output = "输入 help 查看命令。"
	gm_history.clear()
	_start_round()


func _start_round() -> void:
	rooms = _generate_rooms()
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	selected_treasure = 0
	loot_value = 0
	stolen_monster_value = 0
	extracted_value = 0
	has_extracted = false
	pills = 0
	phase = "hide"
	seconds_left = 180
	phase_clock = 0.0
	elapsed = 0.0
	stomach_clock = 15.0
	attack_until = 0.0
	noises.clear()
	afterimages.clear()
	last_afterimage_at = -10.0
	outcome = ""
	result_restart_rect = Rect2()
	help_open = {"monster": false, "thief": false}
	help_rects = {"monster": Rect2(), "thief": Rect2()}
	tool_inventories = {
		"monster": _take_loadout_for_round(_player_for_role("monster")),
		"thief": _take_loadout_for_round(_player_for_role("thief")),
	}
	tool_selected = {"monster": 0, "thief": 0}
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
	restart_rect = Rect2()
	early_rect = Rect2()
	result_restart_rect = Rect2()
	round_awards = {"A": 0, "B": 0}
	logs = [
		"第 %d / %d 局：玩家%s担任怪物，玩家%s担任盗贼。"
		% [current_round, MATCH_ROUNDS, _player_for_role("monster"), _player_for_role("thief")]
	]
	if world_25d:
		world_25d.rebuild(rooms)
		world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
		world_25d.reset_physics_interpolation()
	if hud:
		hud.queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if world_25d:
			world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
		if hud:
			hud.queue_redraw()
		return
	if hud:
		hud.queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if bool(main_menu_open):
		return
	if tutorial_system and tutorial_system.active:
		return
	if bool(tutorial_transition_active):
		return
	if bool(game_pause_open):
		return
	elapsed += delta
	_update_phase(delta)
	_update_temporary_events()
	_update_tool_states(delta)
	_update_devices(delta)
	_update_furniture_hit_actions(delta)
	_update_storage_panel()
	if phase == "hunt":
		stomach_clock -= delta
		if stomach_clock <= 0.0:
			stomach_clock += 15.0
			_add_noise("thief", "肚子叫")
			_push_log("盗贼的肚子叫了，怪物获得 2 秒方向提示。")
	if phase in ["hide", "hunt"]:
		monster["moving"] = false
		thief["moving"] = false
		_handle_continuous_input(delta)
	_update_thief_stealth()
	_update_walk_audio()
	if world_25d:
		var attack_active := (
			elapsed - float(monster.get("attack_started_at", -10.0))
			< MONSTER_ATTACK_ANIMATION_SECONDS
		)
		world_25d.sync(rooms, monster, thief, afterimages, dragging, attack_active, elapsed)


func _update_thief_stealth() -> void:
	if thief.is_empty():
		return
	if phase != "hunt" or has_extracted:
		thief["hidden_from_monster"] = false
		return
	var thief_effects: Dictionary = status_effects.get("thief", {})
	if (
		str(trapped_by.get("thief", "")) != ""
		or elapsed < float(thief_effects.get("stunned_until", 0.0))
	):
		thief["hidden_from_monster"] = false
		return
	if bool(thief.get("gm_force_visible", false)):
		thief["hidden_from_monster"] = false
		# A GM teleport keeps both actors visible for inspection. As soon as the
		# thief moves again, hand visibility back to the normal stealth rule.
		if bool(thief.get("moving", false)):
			thief["gm_force_visible"] = false
		return
	if bool(thief.get("moving", false)):
		thief["last_moved_at"] = elapsed
		thief["hidden_from_monster"] = false
		return
	# Stealth is a direct movement state: releasing all movement keys hides the
	# thief on that same physics tick, regardless of a previous reveal event.
	thief["hidden_from_monster"] = true


func _update_phase(delta: float) -> void:
	if phase != "hide" and phase != "ready" and phase != "hunt":
		return
	phase_clock += delta
	if phase_clock < 1.0:
		return
	var ticks := int(phase_clock)
	phase_clock -= ticks
	for _tick in range(ticks):
		seconds_left -= 1
		if seconds_left > 0:
			continue
		if phase == "hide":
			_begin_hunt_countdown()
		elif phase == "ready":
			_enter_hunt()
		else:
			_end_round("盗贼未能在8分钟内撤离，怪物守住了老宅。", false, true)
		break


func _update_temporary_events() -> void:
	noises = noises.filter(func(entry): return float(entry["expires"]) > elapsed)
	afterimages = afterimages.filter(func(entry): return float(entry["expires"]) > elapsed)


func _handle_continuous_input(delta: float) -> void:
	var mx := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var my := int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	_apply_view_relative_input(_role_for_player("A"), Vector2(mx, my), delta)

	var tx := int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
	var ty := int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
	_apply_view_relative_input(_role_for_player("B"), Vector2(tx, ty), delta)

func _apply_view_relative_input(role: String, screen_input: Vector2, delta: float) -> void:
	if screen_input.is_zero_approx():
		return
	if bool(help_open[role]):
		return
	if not _role_can_act(role):
		return
	if not (furniture_hit_actions[role] as Dictionary).is_empty():
		return
	if role == "monster" and not _active_storage_furniture().is_empty():
		return
	var world_direction := screen_input.normalized()
	if world_25d:
		world_direction = world_25d.camera_relative_vector(role, screen_input)
	_move_actor_continuous(role, world_direction, delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if bool(tutorial_transition_active):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and _is_gm_console_toggle(event):
		gm_console_open = not bool(gm_console_open)
		gm_command = ""
		get_viewport().set_input_as_handled()
		if hud:
			hud.queue_redraw()
		return
	if bool(gm_console_open):
		if event is InputEventKey and event.pressed:
			_handle_gm_console_key(event)
		get_viewport().set_input_as_handled()
		return
	if bool(main_menu_open):
		_handle_main_menu_input(event)
		get_viewport().set_input_as_handled()
		return
	if tutorial_system and tutorial_system.active:
		if tutorial_system.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if bool(game_pause_open):
		_handle_game_pause_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for role in ["monster", "thief"]:
			if (help_rects[role] as Rect2).has_point(event.position):
				help_open[role] = not bool(help_open[role])
				get_viewport().set_input_as_handled()
				return
		if restart_rect.has_point(event.position):
			new_game()
			return
		if result_restart_rect.has_point(event.position):
			_advance_from_result()
			return
		if phase == "ended" and current_round >= MATCH_ROUNDS:
			for action in match_end_rects:
				if (match_end_rects[action] as Rect2).has_point(event.position):
					match_end_selected = 0 if str(action) == "restart" else 1
					_activate_match_end_action(str(action))
					return
		if phase == "hide" and early_rect.has_point(event.position):
			_begin_hunt_countdown()
			return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	var physical: Key = event.physical_keycode
	if key == KEY_F2:
		new_game()
		return
	if key == KEY_ESCAPE:
		if bool(help_open["monster"]) or bool(help_open["thief"]):
			help_open["monster"] = false
			help_open["thief"] = false
			return
		if not _active_storage_furniture().is_empty():
			_handle_storage_panel_input(key, physical)
			return
		_open_game_pause()
		return
	if phase == "ended" and current_round >= MATCH_ROUNDS:
		if (
			physical in [KEY_W, KEY_A, KEY_S, KEY_D]
			or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
		):
			match_end_selected = 1 - int(match_end_selected)
		elif physical == KEY_SPACE or key == KEY_SPACE:
			_activate_match_end_action("restart" if int(match_end_selected) == 0 else "main_menu")
		return
	if phase == "shop":
		_handle_shop_input(key, physical)
		return
	var left_role := _role_for_player("A")
	var right_role := _role_for_player("B")
	if key == KEY_F1:
		help_open[left_role] = not bool(help_open[left_role])
		return
	if key == KEY_KP_ADD:
		help_open[right_role] = not bool(help_open[right_role])
		return
	if _help_blocks_key(key, physical):
		return
	if _handle_trap_escape_input("monster", key, physical):
		get_viewport().set_input_as_handled()
		return
	if _handle_trap_escape_input("thief", key, physical):
		get_viewport().set_input_as_handled()
		return
	if _handle_storage_panel_input(key, physical):
		get_viewport().set_input_as_handled()
		return
	if physical == KEY_H and phase == "hide" and left_role == "monster":
		_begin_hunt_countdown()
	elif physical == KEY_Q:
		if world_25d:
			world_25d.rotate_camera(left_role, -1)
	elif physical == KEY_E:
		if world_25d:
			world_25d.rotate_camera(left_role, 1)
	elif physical == KEY_G:
		_hit_furniture(left_role)
	elif physical == KEY_SPACE:
		if left_role == "monster":
			_attack()
	elif physical == KEY_R:
		_pick_up_nearby(left_role)
	elif physical == KEY_Z:
		_cycle_tool(left_role, -1)
	elif physical == KEY_X:
		_cycle_tool(left_role, 1)
	elif physical == KEY_F:
		_use_selected_tool(left_role)
	elif physical == KEY_B:
		_voice(left_role)
	elif physical == KEY_C and left_role == "thief":
		_use_pill()
	elif physical == KEY_V and left_role == "thief":
		_thief_exit()
	elif key == KEY_KP_0:
		_hit_furniture(right_role)
	elif key == KEY_KP_1:
		_pick_up_nearby(right_role)
	elif key == KEY_KP_2:
		if right_role == "monster":
			_attack()
		else:
			_use_pill()
	elif key == KEY_KP_3:
		_use_selected_tool(right_role)
	elif key == KEY_KP_MULTIPLY:
		_voice(right_role)
	elif key == KEY_KP_4:
		_cycle_tool(right_role, -1)
	elif key == KEY_KP_5:
		if right_role == "monster" and phase == "hide":
			_begin_hunt_countdown()
		elif right_role == "thief":
			_thief_exit()
	elif key == KEY_KP_6:
		_cycle_tool(right_role, 1)
	elif key == KEY_KP_7:
		if world_25d:
			world_25d.rotate_camera(right_role, -1)
	elif key == KEY_KP_9:
		if world_25d:
			world_25d.rotate_camera(right_role, 1)


func _open_game_pause() -> void:
	if bool(main_menu_open) or (tutorial_system and tutorial_system.active):
		return
	game_pause_open = true
	game_pause_selected = 0
	game_pause_rects.clear()
	for audio_player in walk_players.values():
		if is_instance_valid(audio_player):
			(audio_player as AudioStreamPlayer).stop()


func _close_game_pause() -> void:
	game_pause_open = false
	game_pause_selected = 0
	game_pause_rects.clear()


func _handle_game_pause_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _game_pause_action_at(event.position)
		if hovered != "":
			game_pause_selected = 0 if hovered == "continue" else 1
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked := _game_pause_action_at(event.position)
		if clicked != "":
			_activate_game_pause_action(clicked)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	var physical: Key = event.physical_keycode
	if key == KEY_ESCAPE:
		_close_game_pause()
		return
	if physical in [KEY_W, KEY_A, KEY_S, KEY_D] or key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		game_pause_selected = 1 - int(game_pause_selected)
		return
	if physical == KEY_R or key in [KEY_KP_1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_activate_game_pause_action("continue" if int(game_pause_selected) == 0 else "main_menu")


func _game_pause_action_at(position: Vector2) -> String:
	for action in game_pause_rects:
		if (game_pause_rects[action] as Rect2).has_point(position):
			return str(action)
	return ""


func _activate_game_pause_action(action: String) -> void:
	if action == "continue":
		_close_game_pause()
	elif action == "main_menu":
		_open_main_menu()


func _activate_match_end_action(action: String) -> void:
	if action == "restart":
		new_game()
	elif action == "main_menu":
		_open_main_menu()


func _handle_main_menu_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered_action := _main_menu_action_at(event.position)
		if hovered_action != "":
			_select_main_menu_action(hovered_action)
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var clicked_action := _main_menu_action_at(event.position)
		if clicked_action != "":
			_activate_main_menu_action(clicked_action)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	var physical: Key = event.physical_keycode
	if key == KEY_ESCAPE:
		if main_menu_panel == "settings" or main_menu_panel == "exit_confirm":
			main_menu_panel = "root"
			main_menu_selected = 0
			main_menu_rects.clear()
		return
	match str(main_menu_panel):
		"settings":
			_handle_main_menu_settings_key(key, physical)
		"exit_confirm":
			if key == KEY_LEFT or physical == KEY_A:
				main_menu_selected = 0
			elif key == KEY_RIGHT or physical == KEY_D:
				main_menu_selected = 1
			elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_activate_main_menu_action(
					"exit_cancel" if int(main_menu_selected) == 0 else "exit_confirm"
				)
		_:
			if key == KEY_LEFT or physical == KEY_A:
				main_menu_selected = posmod(int(main_menu_selected) - 1, 4)
			elif key == KEY_RIGHT or physical == KEY_D:
				main_menu_selected = posmod(int(main_menu_selected) + 1, 4)
			elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				var actions := ["start", "settings", "tutorial", "exit"]
				_activate_main_menu_action(actions[int(main_menu_selected)])


func _handle_main_menu_settings_key(key: Key, physical: Key) -> void:
	if key == KEY_UP or physical == KEY_W:
		main_menu_selected = posmod(int(main_menu_selected) - 1, 3)
	elif key == KEY_DOWN or physical == KEY_S:
		main_menu_selected = posmod(int(main_menu_selected) + 1, 3)
	elif key == KEY_LEFT or physical == KEY_A:
		if int(main_menu_selected) == 0:
			_adjust_main_menu_volume(-1)
	elif key == KEY_RIGHT or physical == KEY_D:
		if int(main_menu_selected) == 0:
			_adjust_main_menu_volume(1)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		match int(main_menu_selected):
			0:
				_adjust_main_menu_volume(1)
			1:
				_toggle_main_menu_fullscreen()
			_:
				_activate_main_menu_action("settings_back")


func _main_menu_action_at(position: Vector2) -> String:
	for action in main_menu_rects:
		if (main_menu_rects[action] as Rect2).has_point(position):
			return str(action)
	return ""


func _select_main_menu_action(action: String) -> void:
	match str(main_menu_panel):
		"settings":
			if action in ["volume_down", "volume_up"]:
				main_menu_selected = 0
			elif action == "fullscreen":
				main_menu_selected = 1
			elif action == "settings_back":
				main_menu_selected = 2
		"exit_confirm":
			main_menu_selected = 0 if action == "exit_cancel" else 1
		_:
			var actions := ["start", "settings", "tutorial", "exit"]
			var index := actions.find(action)
			if index >= 0:
				main_menu_selected = index


func _activate_main_menu_action(action: String) -> void:
	match action:
		"start":
			main_menu_open = false
			main_menu_panel = "root"
			main_menu_rects.clear()
			new_game()
		"settings":
			main_menu_panel = "settings"
			main_menu_selected = 0
			main_menu_rects.clear()
		"tutorial":
			main_menu_open = false
			main_menu_panel = "root"
			main_menu_rects.clear()
			_open_tutorial_mode()
		"exit":
			main_menu_panel = "exit_confirm"
			main_menu_selected = 0
			main_menu_rects.clear()
		"volume_down":
			_adjust_main_menu_volume(-1)
		"volume_up":
			_adjust_main_menu_volume(1)
		"fullscreen":
			_toggle_main_menu_fullscreen()
		"settings_back", "exit_cancel":
			main_menu_panel = "root"
			main_menu_selected = 0
			main_menu_rects.clear()
		"exit_confirm":
			get_tree().quit()


func _adjust_main_menu_volume(direction: int) -> void:
	main_menu_volume_step = clampi(int(main_menu_volume_step) + direction, 0, 10)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_mute(master_bus, int(main_menu_volume_step) == 0)
	if int(main_menu_volume_step) > 0:
		AudioServer.set_bus_volume_db(
			master_bus,
			linear_to_db(float(main_menu_volume_step) / 10.0),
		)


func _toggle_main_menu_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen := mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
		if fullscreen
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _is_gm_console_toggle(event: InputEventKey) -> bool:
	return (
		event.physical_keycode == KEY_QUOTELEFT
		or event.keycode == KEY_QUOTELEFT
		or event.keycode == KEY_ASCIITILDE
		or event.unicode == 96
		or event.unicode == 126
	)


func _handle_gm_console_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		gm_console_open = false
		gm_command = ""
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		var command := str(gm_command).strip_edges()
		gm_command = ""
		if command != "":
			_execute_gm_command(command)
		return
	if event.keycode == KEY_BACKSPACE:
		var text := str(gm_command)
		if not text.is_empty():
			gm_command = text.left(text.length() - 1)
		return
	if event.unicode >= 32 and event.unicode != 96 and event.unicode != 126:
		gm_command = str(gm_command) + String.chr(event.unicode)


func _help_blocks_key(key: Key, physical: Key) -> bool:
	var left_role := _role_for_player("A")
	var right_role := _role_for_player("B")
	if bool(help_open[left_role]) and physical in [
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_G, KEY_R, KEY_SPACE,
		KEY_Z, KEY_X, KEY_F, KEY_B, KEY_C, KEY_V, KEY_H,
	]:
		return true
	if bool(help_open[right_role]) and key in [
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5,
		KEY_KP_6, KEY_KP_7, KEY_KP_9, KEY_KP_MULTIPLY,
	]:
		return true
	return false


func _handle_storage_panel_input(key: Key, physical: Key) -> bool:
	if _active_storage_furniture().is_empty():
		return false
	if key == KEY_ESCAPE:
		active_storage_id = ""
		_push_log("已关闭家具面板。")
		return true
	var monster_player := _player_for_role("monster")
	var previous_pressed := (
		physical == KEY_A if monster_player == "A"
		else key == KEY_LEFT
	)
	var next_pressed := (
		physical == KEY_D if monster_player == "A"
		else key == KEY_RIGHT
	)
	var transfer_pressed := (
		physical == KEY_R if monster_player == "A"
		else key == KEY_KP_1
	)
	if previous_pressed:
		selected_treasure = (selected_treasure - 1 + TREASURES.size()) % TREASURES.size()
		return true
	if next_pressed:
		selected_treasure = (selected_treasure + 1) % TREASURES.size()
		return true
	if transfer_pressed:
		_place_treasure()
		return true
	return false


func _open_tutorial_mode() -> void:
	main_menu_open = false
	main_menu_panel = "root"
	main_menu_rects.clear()
	if tutorial_system:
		tutorial_system.open()


func _close_tutorial_mode(start_fresh_game := true) -> void:
	if tutorial_system:
		tutorial_system.close()
	if start_fresh_game:
		main_menu_open = false
		new_game()


func _on_tutorial_players_ready() -> void:
	if bool(tutorial_transition_active):
		return
	tutorial_transition_active = true
	if hud:
		hud.queue_redraw()
	call_deferred("_cleanup_tutorial_then_start_game")


func _cleanup_tutorial_then_start_game() -> void:
	if tutorial_system:
		tutorial_system.close()
	# Tutorial renderers and their four SubViewports are queued for deletion.
	# Give RenderingServer two frames to release them before rebuilding the
	# complete 6x6 match world; doing both in one frame can stall the GPU.
	await get_tree().process_frame
	await get_tree().process_frame
	main_menu_open = false
	new_game()
	tutorial_transition_active = false
	if hud:
		hud.queue_redraw()


func _on_tutorial_return_to_main_menu() -> void:
	call_deferred("_open_main_menu")


func _calculate_layout(size: Vector2) -> Dictionary:
	return hud.call("_calculate_layout", size) if hud else {}


func _minimap_rotation(role: String) -> float:
	return float(hud.call("_minimap_rotation", role)) if hud else 0.0
