extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game._execute_gm_command("tutorial")
	assert(bool(game.tutorial_system.active))
	assert(not bool(game.main_menu_open))
	assert(str(game.tutorial_system.sessions["A"]["mode"]) == "select")
	assert(str(game.tutorial_system.sessions["B"]["mode"]) == "select")

	game._execute_gm_command("tutorial A thief")
	game._execute_gm_command("tutorial B monster")
	await process_frame
	var left: Dictionary = game.tutorial_system.sessions["A"]
	var right: Dictionary = game.tutorial_system.sessions["B"]
	assert(str(left["role"]) == "thief")
	assert(str(right["role"]) == "monster")
	assert(left["renderer"] != right["renderer"])
	assert(left["renderer"].monster_viewport.world_3d != right["renderer"].monster_viewport.world_3d)
	assert((left["rooms"] as Array).size() == 5)
	assert((right["rooms"] as Array).size() == 5)

	# A modal on one side must never swallow the other player's key range.
	left["panel_open"] = true
	right["objective"] = "challenge"
	right["monster"]["room"] = Vector2i(2, 0)
	right["monster"]["pos"] = Vector2(1.0, 2.5)
	right["monster"]["facing"] = Vector2.RIGHT
	right["thief"]["room"] = Vector2i(2, 0)
	right["thief"]["pos"] = Vector2(2.0, 2.5)
	game.tutorial_system.handle_input(_key(KEY_KP_2, KEY_KP_2))
	assert(int(right["ai_hits"]) == 1)
	left["panel_open"] = false

	# Finishing one side while the other is in its shop keeps that shop usable.
	left["shop_open"] = true
	left["shop_focus"] = 0
	left["shop_owned"] = false
	game.tutorial_system._finish_run("B")
	game.tutorial_system.handle_input(_key(KEY_R, KEY_R))
	assert(bool(left["shop_owned"]))
	left["shop_open"] = false

	left["objective"] = "challenge"
	left["thief"]["room"] = Vector2i(2, 0)
	left["thief"]["moving"] = false
	left["stationary_time"] = 0.0
	game.tutorial_system._update_player_stealth(left, 0.01)
	assert(bool(left["thief"]["hidden_from_monster"]))
	left["thief"]["moving"] = true
	game.tutorial_system._update_player_stealth(left, 0.01)
	assert(not bool(left["thief"]["hidden_from_monster"]))
	left["thief"]["pos"] = Vector2(0.9, 2.5)
	left["monster"]["pos"] = Vector2(1.1, 2.5)
	left["thief"]["hidden_from_monster"] = false
	left["thief"]["moving"] = true
	left["ai_touch_cooldown"] = 0.0
	var contact_position: Vector2 = left["thief"]["pos"]
	game.tutorial_system._update_ai_monster(left, 0.01)
	assert((left["thief"]["pos"] as Vector2).is_equal_approx(contact_position))
	game.tutorial_system._move_player(left, Vector2.DOWN, 0.1)
	assert((left["thief"]["pos"] as Vector2).distance_to(contact_position) > 0.01)

	var abandoned_renderer: Node = left["renderer"]
	game.tutorial_system.handle_input(_key(KEY_T, KEY_T))
	assert(str(game.tutorial_system.sessions["A"]["mode"]) == "select")
	assert((game.tutorial_system.sessions["A"]["rooms"] as Array).is_empty())
	await process_frame
	assert(not is_instance_valid(abandoned_renderer))

	game.tutorial_system.start_run("A", "thief")
	var course: Dictionary = game.tutorial_system.sessions["A"]
	game.tutorial_system.handle_input(_key(KEY_F1, KEY_F1))
	assert(str(course["objective"]) == "basics")
	game.tutorial_system.handle_input(_key(KEY_F1, KEY_F1))
	assert(not bool(course["help_open"]))
	course["moved_distance"] = 1.2
	course["rotated_cw"] = true
	course["rotated_ccw"] = true
	game.tutorial_system._update_basics_objective(course)
	assert(str(course["objective"]) == "enter_room_2")
	course["objective"] = "furniture"
	course["thief"]["room"] = Vector2i(1, 0)
	course["thief"]["pos"] = Vector2(1.45, 2.5)
	course["thief"]["facing"] = Vector2.RIGHT
	for _hit in range(6):
		game.tutorial_system._tutorial_hit("A", course)
	game.tutorial_system.elapsed += game.tutorial_system.HIT_WINDUP_TIME * 0.8
	game.tutorial_system._update_action_visuals(course)
	assert(not (course["thief"]["impact_visual_offset"] as Vector2).is_zero_approx())
	var storage: Dictionary = course["rooms"][1]["furniture"][0]
	assert(bool(storage["destroyed"]))
	course["thief"]["pos"] = Vector2(2.9, 2.5)
	game.tutorial_system._tutorial_pickup(course)
	assert(str(course["objective"]) == "enter_room_3")
	course["objective"] = "challenge"
	course["thief"]["room"] = Vector2i(2, 0)
	course["thief"]["pos"] = Vector2(4.3, 2.5)
	course["monster"]["pos"] = Vector2(0.6, 0.6)
	game.tutorial_system._update_ai_monster(course, 0.01)
	assert(str(course["objective"]) == "enter_room_4")
	course["objective"] = "shop_hit"
	course["thief"]["room"] = Vector2i(3, 0)
	course["thief"]["pos"] = Vector2(1.45, 2.5)
	course["thief"]["facing"] = Vector2.RIGHT
	game.tutorial_system._tutorial_hit("A", course)
	assert(bool(course["shop_open"]))
	game.tutorial_system.handle_input(_key(KEY_R, KEY_R))
	assert(bool(course["shop_owned"]))
	game.tutorial_system.handle_input(_key(KEY_R, KEY_R))
	assert(bool(course["shop_equipped"]))
	game.tutorial_system.handle_input(_key(KEY_H, KEY_H))
	assert(not bool(course["shop_open"]))
	assert(str(course["objective"]) == "use_tool")
	game.tutorial_system.handle_input(_key(KEY_F, KEY_F))
	assert(str(course["objective"]) == "enter_room_5")
	assert((course["inventory"] as Array).is_empty())
	course["objective"] = "exit_hit"
	course["thief"]["room"] = Vector2i(4, 0)
	course["thief"]["pos"] = Vector2(1.45, 2.5)
	course["thief"]["facing"] = Vector2.RIGHT
	game.tutorial_system._tutorial_hit("A", course)
	assert(bool(game.tutorial_system.completed["A"]["thief"]))
	assert(str(game.tutorial_system.sessions["A"]["mode"]) == "select")

	game.tutorial_system.start_run("B", "monster")
	var monster_course: Dictionary = game.tutorial_system.sessions["B"]
	game.tutorial_system.handle_input(_key(KEY_KP_ADD, KEY_KP_ADD))
	assert(str(monster_course["objective"]) == "basics")
	game.tutorial_system.handle_input(_key(KEY_KP_ADD, KEY_KP_ADD))
	monster_course["objective"] = "furniture"
	monster_course["monster"]["room"] = Vector2i(1, 0)
	monster_course["monster"]["pos"] = Vector2(1.45, 2.5)
	monster_course["monster"]["facing"] = Vector2.RIGHT
	game.tutorial_system._tutorial_hit("B", monster_course)
	assert(bool(monster_course["panel_open"]))
	game.tutorial_system._place_tutorial_treasure(monster_course)
	assert(str(monster_course["objective"]) == "enter_room_3")
	var monster_storage: Dictionary = monster_course["rooms"][1]["furniture"][0]
	assert(int(monster_storage["durability"]) == 6)
	monster_course["objective"] = "challenge"
	monster_course["monster"]["room"] = Vector2i(2, 0)
	monster_course["monster"]["pos"] = Vector2(1.0, 2.5)
	monster_course["monster"]["facing"] = Vector2.RIGHT
	monster_course["thief"]["pos"] = Vector2(2.0, 2.5)
	game.tutorial_system._tutorial_attack(monster_course)
	monster_course["attack_until"] = 0.0
	game.tutorial_system._tutorial_attack(monster_course)
	assert(bool(monster_course["thief"]["downed"]))
	assert(str(monster_course["objective"]) == "enter_room_4")
	game.tutorial_system.handle_input(_key(KEY_KP_SUBTRACT, KEY_KP_SUBTRACT))
	assert(str(game.tutorial_system.sessions["B"]["mode"]) == "select")

	game.phase = "hunt"
	game.elapsed = 20.0
	game.thief["moving"] = false
	game.thief["last_moved_at"] = 18.0
	game.thief["revealed_until"] = 100.0
	game._update_thief_stealth()
	assert(bool(game.thief["hidden_from_monster"]))
	game.world_25d.sync(
		game.rooms,
		game.monster,
		game.thief,
		game.afterimages,
		game.dragging,
		false,
		game.elapsed,
	)
	var thief_sprite := game.world_25d.thief_node.get_node("SwayPivot/PaperSprite") as Sprite3D
	assert((thief_sprite.layers & World25D.LAYER_SHARED_ACTORS) == 0)
	assert((thief_sprite.layers & World25D.LAYER_THIEF) != 0)
	game._reveal_thief()
	assert(not bool(game.thief["hidden_from_monster"]))

	game.tutorial_system.mark_ready("A")
	game.tutorial_system.mark_ready("B")
	assert(bool(game.tutorial_system.active))
	assert(bool(game.tutorial_system.finish_confirm_open))
	assert(str(game.tutorial_system.sessions["A"]["mode"]) == "ready")
	assert(str(game.tutorial_system.sessions["B"]["mode"]) == "ready")

	# “先等等” cleans tutorial resources and returns to the main menu.
	game.tutorial_system.handle_input(_key(KEY_D, KEY_D))
	assert(int(game.tutorial_system.finish_confirm_selection) == 1)
	game.tutorial_system.handle_input(_key(KEY_SPACE, KEY_SPACE))
	await process_frame
	await process_frame
	assert(not bool(game.tutorial_system.active))
	assert(bool(game.main_menu_open))

	# Opening tutorial again and choosing the default “冲” starts a fresh round.
	game._open_tutorial_mode()
	game.tutorial_system.mark_ready("A")
	game.tutorial_system.mark_ready("B")
	assert(bool(game.tutorial_system.finish_confirm_open))
	await process_frame
	assert((game.tutorial_system.finish_confirm_rects as Array).size() == 2)
	var rush_click := InputEventMouseButton.new()
	rush_click.pressed = true
	rush_click.button_index = MOUSE_BUTTON_LEFT
	rush_click.position = (game.tutorial_system.finish_confirm_rects[0] as Rect2).get_center()
	game._input(rush_click)
	assert(bool(game.tutorial_transition_active))
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	assert(not bool(game.tutorial_system.active))
	assert(not bool(game.tutorial_transition_active))
	assert(not bool(game.main_menu_open))
	assert(game.current_round == 1)
	assert(game.phase == "hide")

	print("Tutorial system test passed: dual isolation, cleanup, final confirmation, and stationary stealth.")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _key(key: Key, physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = physical
	return event
