class_name TutorialSystem
extends Node

signal all_players_ready
signal return_to_main_menu_requested

const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")
const GAMEPLAY_STATE_FACTORY := preload("res://scripts/state/gameplay_state_factory.gd")
const TUTORIAL_STEP_CATALOG := preload("res://scripts/tutorial/tutorial_step_catalog.gd")

const ROOM_SIZE := 5.0
const ACTOR_SPEED := 4.0
const HIDE_DELAY := 0.0
const ATTACK_REACH := 2.35
const ATTACK_DOT := 0.707
const MONSTER_ATTACK_COOLDOWN := 1.0
const MONSTER_ATTACK_ANIMATION_SECONDS := 0.55
const ADRENALINE_SECONDS := 6.0
const FATIGUE_SECONDS := 3.0
const HIT_WINDUP_TIME := 0.14
const HIT_LUNGE_TIME := 0.12
const HIT_RECOVER_TIME := 0.18
const HIT_WINDUP_DISTANCE := 0.18
const HIT_LUNGE_DISTANCE := 0.32

const OBJECTIVE_ORDER := TUTORIAL_STEP_CATALOG.OBJECTIVE_ORDER

var game: Node
var active := false
var elapsed := 0.0
var sessions: Dictionary = {}
var completed := {
	"A": {"monster": false, "thief": false},
	"B": {"monster": false, "thief": false},
}
var selection_rects := {"A": [], "B": []}
var exit_rects := {"A": Rect2(), "B": Rect2()}
var finish_confirm_open := false
var finish_confirm_selection := 0
var finish_confirm_rects: Array = []
var rng := RandomNumberGenerator.new()


func setup(host: Node) -> void:
	game = host
	rng.randomize()
	sessions = {
		"A": _fresh_lobby_session(),
		"B": _fresh_lobby_session(),
	}
	set_physics_process(false)


func open() -> void:
	if active:
		return
	active = true
	elapsed = 0.0
	finish_confirm_open = false
	finish_confirm_selection = 0
	finish_confirm_rects.clear()
	for player in ["A", "B"]:
		_clear_run(player)
		sessions[player] = _fresh_lobby_session()
	set_physics_process(true)


func close() -> void:
	if not active:
		return
	for player in ["A", "B"]:
		_clear_run(player)
	active = false
	set_physics_process(false)
	selection_rects = {"A": [], "B": []}
	exit_rects = {"A": Rect2(), "B": Rect2()}
	finish_confirm_open = false
	finish_confirm_selection = 0
	finish_confirm_rects.clear()


func _fresh_lobby_session() -> Dictionary:
	return {
		"mode": "select",
		"selection": 0,
		"message": "请选择要学习的角色。",
		"role": "",
		"renderer": null,
		"rooms": [],
	}


func _fresh_actor(room: Vector2i, pos: Vector2, direction: String) -> Dictionary:
	return GAMEPLAY_STATE_FACTORY.actor(
		room,
		pos,
		direction,
		_direction_vector(direction),
		true,
	)


func start_run(player: String, role: String) -> void:
	if player not in ["A", "B"] or role not in ["monster", "thief"]:
		return
	_clear_run(player)
	var renderer: World25D = WORLD_25D_SCRIPT.new()
	renderer.name = "TutorialWorld%s" % player
	add_child(renderer)
	renderer.setup(null, true)
	var audio_root := Node.new()
	audio_root.name = "TutorialAudio%s" % player
	add_child(audio_root)
	var rooms := _make_rooms(role)
	var player_actor := _fresh_actor(Vector2i(0, 0), Vector2(0.72, 2.5), "right")
	var ai_role := "monster" if role == "thief" else "thief"
	var ai_actor := _fresh_actor(
		Vector2i(2, 0),
		Vector2(3.75, 1.25) if role == "thief" else Vector2(3.65, 3.6),
		"left",
	)
	var monster := player_actor if role == "monster" else ai_actor
	var thief := player_actor if role == "thief" else ai_actor
	var treasure := {
		"id": "tutorial-carried-%s" % player,
		"kind": "treasure",
		"label": "银制烛台",
		"value": 4,
	}
	sessions[player] = {
		"mode": "running",
		"selection": 0,
		"message": "",
		"role": role,
		"ai_role": ai_role,
		"renderer": renderer,
		"audio_root": audio_root,
		"rooms": rooms,
		"monster": monster,
		"thief": thief,
		"objective": "help",
		"help_open": false,
		"moved_distance": 0.0,
		"rotated_cw": false,
		"rotated_ccw": false,
		"stationary_time": 0.0,
		"ai_patrol_index": 0,
		"ai_cycle": 0.0,
		"ai_noise_cycle": -1,
		"ai_target": Vector2(3.65, 3.6),
		"ai_target_until": 0.0,
		"ai_hits": 0,
		"ai_alerted": false,
		"ai_touch_cooldown": 0.0,
		"noise_until": 0.0,
		"noise_pos": Vector2.ZERO,
		"panel_open": false,
		"carried_treasures": [treasure] if role == "monster" else [],
		"loot": [],
		"shop_open": false,
		"shop_focus": 0,
		"shop_coins": 5,
		"shop_owned": false,
		"shop_equipped": false,
		"shop_ready": false,
		"inventory": [],
		"adrenaline_until": 0.0,
		"fatigue_until": 0.0,
		"impact_until": 0.0,
		"impact_started_at": -10.0,
		"impact_facing": Vector2.RIGHT,
		"attack_until": 0.0,
		"pickup_until": 0.0,
		"tool_effect_until": 0.0,
		"projection_ready": false,
	}
	renderer.rebuild(rooms)
	renderer.sync(rooms, monster, thief, [], {"monster": "", "thief": ""}, false, elapsed)


func exit_current_run(player: String) -> void:
	if player not in ["A", "B"]:
		return
	var previous_role := str(sessions[player].get("role", ""))
	_clear_run(player)
	sessions[player] = _fresh_lobby_session()
	if previous_role != "":
		sessions[player]["message"] = "已退出%s教学，教学资源已清理。" % _role_label(previous_role)


func reset_run(player: String) -> void:
	if player not in ["A", "B"]:
		return
	var role := str(sessions[player].get("role", ""))
	if role == "":
		return
	start_run(player, role)


func force_next(player: String) -> void:
	if player not in ["A", "B"]:
		return
	var session: Dictionary = sessions[player]
	if str(session.get("mode", "")) != "running":
		return
	var current := str(session.get("objective", "help"))
	var index := OBJECTIVE_ORDER.find(current)
	if index < 0 or index >= OBJECTIVE_ORDER.size() - 1:
		_finish_run(player)
		return
	session["objective"] = OBJECTIVE_ORDER[index + 1]
	_prepare_for_objective(session)


func mark_ready(player: String) -> void:
	if player not in ["A", "B"]:
		return
	_clear_run(player)
	var session := _fresh_lobby_session()
	session["mode"] = "ready"
	session["message"] = "已退出教学，等待另一位玩家。"
	sessions[player] = session
	if str(sessions["A"]["mode"]) == "ready" and str(sessions["B"]["mode"]) == "ready":
		finish_confirm_open = true
		finish_confirm_selection = 0


func cancel_ready(player: String) -> void:
	if player not in ["A", "B"] or str(sessions[player].get("mode", "")) != "ready":
		return
	finish_confirm_open = false
	finish_confirm_rects.clear()
	sessions[player] = _fresh_lobby_session()


func _clear_run(player: String) -> void:
	if not sessions.has(player):
		return
	var renderer = sessions[player].get("renderer")
	if renderer != null and is_instance_valid(renderer):
		renderer.queue_free()
	var audio_root = sessions[player].get("audio_root")
	if audio_root != null and is_instance_valid(audio_root):
		audio_root.queue_free()
	sessions[player]["renderer"] = null
	sessions[player]["audio_root"] = null
	sessions[player]["rooms"] = []
	sessions[player].erase("monster")
	sessions[player].erase("thief")


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if finish_confirm_open:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			return _handle_finish_confirm_click(event.position)
		if event is InputEventKey and event.pressed and not event.echo:
			return _handle_finish_confirm_key(event)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		return _handle_mouse_click(event.position)
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode == KEY_ESCAPE:
		var closed_help := false
		for player in ["A", "B"]:
			var session: Dictionary = sessions[player]
			if bool(session.get("help_open", false)):
				session["help_open"] = false
				closed_help = true
		return closed_help
	var owner := _event_owner(event)
	if owner == "":
		return false
	return _handle_player_key(owner, event)


func _handle_finish_confirm_click(position: Vector2) -> bool:
	for index in range(finish_confirm_rects.size()):
		if (finish_confirm_rects[index] as Rect2).has_point(position):
			finish_confirm_selection = index
			_activate_finish_confirm()
			return true
	return true


func _handle_finish_confirm_key(event: InputEventKey) -> bool:
	var physical := event.physical_keycode
	var logical := event.keycode
	if (
		physical in [KEY_A, KEY_D, KEY_W, KEY_S]
		or logical in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	):
		finish_confirm_selection = 1 - finish_confirm_selection
		return true
	if (
		physical == KEY_R
		or physical == KEY_SPACE
		or logical in [KEY_KP_1, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	):
		_activate_finish_confirm()
		return true
	if logical == KEY_ESCAPE:
		finish_confirm_selection = 1
		_activate_finish_confirm()
		return true
	return true


func _activate_finish_confirm() -> void:
	if not finish_confirm_open:
		return
	finish_confirm_open = false
	finish_confirm_rects.clear()
	if finish_confirm_selection == 0:
		all_players_ready.emit()
	else:
		return_to_main_menu_requested.emit()


func _handle_mouse_click(position: Vector2) -> bool:
	for player in ["A", "B"]:
		var session: Dictionary = sessions[player]
		if str(session.get("mode", "")) == "running":
			if (exit_rects[player] as Rect2).has_point(position):
				exit_current_run(player)
				return true
			continue
		var rects: Array = selection_rects[player]
		for index in range(rects.size()):
			if not (rects[index] as Rect2).has_point(position):
				continue
			if str(session.get("mode", "")) == "ready":
				cancel_ready(player)
			elif index == 0:
				start_run(player, "thief")
			elif index == 1:
				start_run(player, "monster")
			else:
				mark_ready(player)
			return true
	return false


func _handle_player_key(player: String, event: InputEventKey) -> bool:
	var session: Dictionary = sessions[player]
	var mode := str(session.get("mode", "select"))
	if _is_exit_key(player, event):
		if mode == "running":
			exit_current_run(player)
		elif mode == "ready":
			cancel_ready(player)
		else:
			mark_ready(player)
		return true
	if mode == "select":
		var previous := _is_previous_key(player, event)
		var next := _is_next_key(player, event)
		if previous or next:
			session["selection"] = posmod(int(session["selection"]) + (-1 if previous else 1), 3)
			return true
		if _is_confirm_key(player, event):
			match int(session["selection"]):
				0: start_run(player, "thief")
				1: start_run(player, "monster")
				_: mark_ready(player)
			return true
		return false
	if mode == "ready":
		if _is_confirm_key(player, event):
			cancel_ready(player)
			return true
		return false
	if mode != "running":
		return false
	if _is_help_key(player, event):
		session["help_open"] = not bool(session["help_open"])
		if str(session["objective"]) == "help":
			session["objective"] = "basics"
		return true
	if bool(session["help_open"]):
		return true
	if bool(session["shop_open"]):
		return _handle_shop_key(player, session, event)
	if bool(session["panel_open"]):
		if _is_pickup_key(player, event):
			_place_tutorial_treasure(session)
			return true
		return true
	if _is_rotate_ccw_key(player, event):
		var renderer: World25D = session["renderer"]
		renderer.rotate_camera(str(session["role"]), -1)
		session["rotated_ccw"] = true
		_update_basics_objective(session)
		return true
	if _is_rotate_cw_key(player, event):
		var renderer: World25D = session["renderer"]
		renderer.rotate_camera(str(session["role"]), 1)
		session["rotated_cw"] = true
		_update_basics_objective(session)
		return true
	if _is_hit_key(player, event):
		if elapsed >= float(session.get("impact_until", 0.0)):
			_tutorial_hit(player, session)
		return true
	if _is_pickup_key(player, event):
		_tutorial_pickup(session)
		return true
	if _is_attack_key(player, event) and str(session["role"]) == "monster":
		_tutorial_attack(session)
		return true
	if _is_use_tool_key(player, event):
		_use_tutorial_tool(session)
		return true
	return false


func _handle_shop_key(player: String, session: Dictionary, event: InputEventKey) -> bool:
	if _is_focus_left_key(player, event):
		session["shop_focus"] = posmod(int(session["shop_focus"]) - 1, 3)
		return true
	if _is_focus_right_key(player, event):
		session["shop_focus"] = posmod(int(session["shop_focus"]) + 1, 3)
		return true
	if _is_confirm_key(player, event):
		match int(session["shop_focus"]):
			0:
				if not bool(session["shop_owned"]) and int(session["shop_coins"]) >= 2:
					session["shop_coins"] = int(session["shop_coins"]) - 2
					session["shop_owned"] = true
					session["shop_focus"] = 1
			1:
				if bool(session["shop_owned"]):
					session["shop_equipped"] = true
					session["shop_focus"] = 2
			2:
				if bool(session["shop_equipped"]):
					session["shop_equipped"] = false
					session["shop_focus"] = 1
		return true
	if _is_ready_key(player, event) and bool(session["shop_equipped"]):
		session["shop_ready"] = true
		session["shop_open"] = false
		session["inventory"] = [{
			"id": "tutorial-adrenaline",
			"kind": "tool",
			"tool_type": "adrenaline",
			"label": "肾上腺素",
		}]
		session["objective"] = "use_tool"
		var actor := _player_actor(session)
		actor["room"] = Vector2i(3, 0)
		actor["pos"] = Vector2(2.5, 3.65)
		actor["dir"] = "up"
		actor["facing"] = Vector2.UP
		return true
	return true


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	for player in ["A", "B"]:
		var session: Dictionary = sessions[player]
		if str(session.get("mode", "")) != "running":
			continue
		_update_run(player, session, delta)


func _update_run(player: String, session: Dictionary, delta: float) -> void:
	var actor := _player_actor(session)
	actor["moving"] = false
	actor["impact_visual_offset"] = Vector2.ZERO
	if not bool(session["shop_open"]) and not bool(session["help_open"]) and not bool(session["panel_open"]):
		var screen_input := _continuous_input(player)
		if not screen_input.is_zero_approx():
			var renderer: World25D = session["renderer"]
			var direction := renderer.camera_relative_vector(str(session["role"]), screen_input)
			_move_player(session, direction, delta)
	_update_player_stealth(session, delta)
	_update_tutorial_ai(session, delta)
	_update_timed_effects(session)
	_update_action_visuals(session)
	_sync_session(session)
	session["projection_ready"] = true


func _continuous_input(player: String) -> Vector2:
	if player == "A":
		return Vector2(
			int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
			int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)),
		)
	return Vector2(
		int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT)),
		int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP)),
	)


func _move_player(session: Dictionary, direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var actor := _player_actor(session)
	var multiplier := 1.0
	if elapsed < float(session["adrenaline_until"]):
		multiplier = 2.0
	elif elapsed < float(session["fatigue_until"]):
		multiplier = 0.5
	var motion := direction.normalized() * ACTOR_SPEED * multiplier * delta
	var before: Vector2 = actor["pos"]
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var step := motion / float(subdivisions)
	for _index in range(subdivisions):
		_move_player_axis(session, Vector2(step.x, 0.0))
		_move_player_axis(session, Vector2(0.0, step.y))
	var moved := (actor["pos"] as Vector2).distance_to(before)
	if moved <= 0.0:
		return
	actor["moving"] = true
	actor["facing"] = direction.normalized()
	actor["dir"] = _direction_name(direction)
	session["moved_distance"] = float(session["moved_distance"]) + moved
	_update_basics_objective(session)


func _move_player_axis(session: Dictionary, motion: Vector2) -> void:
	if motion.is_zero_approx():
		return
	var actor := _player_actor(session)
	var room_coord: Vector2i = actor["room"]
	var target_room := room_coord
	var target_pos: Vector2 = actor["pos"] + motion
	if target_pos.x < 0.0 or target_pos.x >= ROOM_SIZE:
		if absf(float(actor["pos"].y) - 2.5) > 0.82:
			return
		var direction := -1 if target_pos.x < 0.0 else 1
		var next_index := room_coord.x + direction
		if next_index < 0 or next_index >= 5 or not _can_enter_room(session, next_index):
			return
		target_room = Vector2i(next_index, 0)
		target_pos.x += ROOM_SIZE if direction < 0 else -ROOM_SIZE
	if target_pos.y < 0.28 or target_pos.y > ROOM_SIZE - 0.28:
		return
	if (
		(target_pos.x < 0.28 or target_pos.x > ROOM_SIZE - 0.28)
		and absf(target_pos.y - 2.5) > 0.82
	):
		return
	var room := _tutorial_room_at(session, target_room)
	for furniture in room["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		if _overlaps_furniture(target_pos, furniture):
			return
	actor["room"] = target_room
	actor["pos"] = target_pos
	_on_room_entered(session, target_room.x)


func _can_enter_room(session: Dictionary, room_index: int) -> bool:
	var current_index: int = (_player_actor(session)["room"] as Vector2i).x
	if room_index <= current_index:
		return true
	var objective := str(session["objective"])
	match room_index:
		1: return objective in ["enter_room_2", "furniture", "enter_room_3", "challenge", "enter_room_4", "shop_hit", "shop", "use_tool", "enter_room_5", "exit_hit"]
		2: return objective in ["enter_room_3", "challenge", "enter_room_4", "shop_hit", "shop", "use_tool", "enter_room_5", "exit_hit"]
		3: return objective in ["enter_room_4", "shop_hit", "shop", "use_tool", "enter_room_5", "exit_hit"]
		4: return objective in ["enter_room_5", "exit_hit"]
	return false


func _on_room_entered(session: Dictionary, room_index: int) -> void:
	var objective := str(session["objective"])
	if room_index == 1 and objective == "enter_room_2":
		session["objective"] = "furniture"
	elif room_index == 2 and objective == "enter_room_3":
		session["objective"] = "challenge"
		session["stationary_time"] = 0.0
	elif room_index == 3 and objective == "enter_room_4":
		session["objective"] = "shop_hit"
	elif room_index == 4 and objective == "enter_room_5":
		session["objective"] = "exit_hit"


func _update_basics_objective(session: Dictionary) -> void:
	if str(session["objective"]) != "basics":
		return
	if (
		float(session["moved_distance"]) >= 1.2
		and bool(session["rotated_cw"])
		and bool(session["rotated_ccw"])
	):
		session["objective"] = "enter_room_2"


func _update_player_stealth(session: Dictionary, delta: float) -> void:
	var actor := _player_actor(session)
	if str(session["role"]) != "thief":
		actor["hidden_from_monster"] = false
		return
	if bool(actor["moving"]):
		session["stationary_time"] = 0.0
		actor["hidden_from_monster"] = false
	else:
		session["stationary_time"] = float(session["stationary_time"]) + delta
		actor["hidden_from_monster"] = true


func _tutorial_hit(player: String, session: Dictionary) -> void:
	var actor := _player_actor(session)
	session["impact_started_at"] = elapsed
	session["impact_until"] = elapsed + HIT_WINDUP_TIME + HIT_LUNGE_TIME + HIT_RECOVER_TIME
	session["impact_facing"] = (actor.get("facing", Vector2.RIGHT) as Vector2).normalized()
	actor["hidden_from_monster"] = false
	session["stationary_time"] = 0.0
	var objective := str(session["objective"])
	var room := _tutorial_room_at(session, actor["room"])
	var furniture := _furniture_in_front(actor, room)
	if furniture.is_empty():
		return
	furniture["last_hit_time"] = elapsed
	_play_tutorial_sound(session, "furniture_hit", -9.0)
	if objective == "furniture":
		if str(session["role"]) == "monster":
			furniture["opened"] = true
			session["panel_open"] = true
		else:
			furniture["damage"] = int(furniture["damage"]) + 1
			if int(furniture["damage"]) >= int(furniture["durability"]):
				furniture["damage"] = int(furniture["durability"])
				furniture["destroyed"] = true
				furniture["opened"] = true
				_release_tutorial_contents(room, furniture)
		return
	if objective == "shop_hit" and str(furniture["id"]).begins_with("tutorial-shop"):
		session["shop_open"] = true
		session["objective"] = "shop"
		return
	if objective == "exit_hit" and str(furniture["id"]).begins_with("tutorial-exit"):
		_finish_run(player)


func _place_tutorial_treasure(session: Dictionary) -> void:
	var actor := _player_actor(session)
	var room := _tutorial_room_at(session, actor["room"])
	var furniture := _furniture_in_front(actor, room)
	if furniture.is_empty():
		return
	var carried: Array = session["carried_treasures"]
	if carried.is_empty():
		return
	var treasure: Dictionary = carried[0]
	furniture["contents"].append(treasure.duplicate(true))
	carried.clear()
	furniture["durability"] = int(furniture["base_durability"]) + int(treasure["value"])
	furniture["last_hit_time"] = elapsed
	session["pickup_until"] = elapsed + 0.42
	session["panel_open"] = false
	session["objective"] = "enter_room_3"


func _tutorial_pickup(session: Dictionary) -> void:
	if str(session["role"]) != "thief" or str(session["objective"]) != "furniture":
		return
	var actor := _player_actor(session)
	var room := _tutorial_room_at(session, actor["room"])
	for item in room["items"]:
		if bool(item.get("collected", false)):
			continue
		if (item["pos"] as Vector2).distance_to(actor["pos"]) > 0.82:
			continue
		item["collected"] = true
		(session["loot"] as Array).append(item.duplicate(true))
		session["pickup_until"] = elapsed + 0.42
		session["objective"] = "enter_room_3"
		actor["hidden_from_monster"] = false
		session["stationary_time"] = 0.0
		return


func _tutorial_attack(session: Dictionary) -> void:
	if str(session["objective"]) != "challenge" or elapsed < float(session["attack_until"]):
		return
	var actor := _player_actor(session)
	session["attack_until"] = elapsed + MONSTER_ATTACK_COOLDOWN
	actor["attack_started_at"] = elapsed
	var ai := _ai_actor(session)
	if bool(ai.get("downed", false)) or actor["room"] != ai["room"]:
		return
	var offset: Vector2 = ai["pos"] - actor["pos"]
	var distance := offset.length()
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var dot := 1.0 if distance <= 0.001 else offset.normalized().dot(facing)
	if distance > ATTACK_REACH or dot < ATTACK_DOT:
		return
	session["ai_hits"] = int(session["ai_hits"]) + 1
	if int(session["ai_hits"]) >= 2:
		ai["downed"] = true
		ai["moving"] = false
		session["objective"] = "enter_room_4"


func _use_tutorial_tool(session: Dictionary) -> void:
	if str(session["objective"]) != "use_tool" or (session["inventory"] as Array).is_empty():
		return
	(session["inventory"] as Array).clear()
	session["tool_effect_until"] = elapsed + 0.7
	session["adrenaline_until"] = elapsed + ADRENALINE_SECONDS
	session["fatigue_until"] = elapsed + ADRENALINE_SECONDS + FATIGUE_SECONDS
	session["objective"] = "enter_room_5"


func _update_tutorial_ai(session: Dictionary, delta: float) -> void:
	var actor := _player_actor(session)
	var ai := _ai_actor(session)
	ai["moving"] = false
	if bool(ai.get("downed", false)) or actor["room"] != Vector2i(2, 0):
		return
	if str(session["role"]) == "thief":
		_update_ai_monster(session, delta)
	else:
		_update_ai_thief(session, delta)


func _update_ai_monster(session: Dictionary, delta: float) -> void:
	var player := _player_actor(session)
	var ai := _ai_actor(session)
	if elapsed >= float(session["noise_until"]):
		session["noise_until"] = elapsed + 1.0
		session["noise_pos"] = ai["pos"]
		_play_tutorial_sound(session, "walk", -14.0)
	var hidden := bool(player.get("hidden_from_monster", false))
	var distance := (player["pos"] as Vector2).distance_to(ai["pos"])
	var chasing := not hidden and distance <= 3.0
	session["ai_alerted"] = chasing
	var target: Vector2
	if chasing:
		target = player["pos"]
	else:
		var patrol_points := [
			Vector2(3.8, 1.2),
			Vector2(1.2, 1.25),
			Vector2(1.25, 3.75),
			Vector2(3.75, 3.7),
		]
		var patrol_index := int(session["ai_patrol_index"])
		target = patrol_points[patrol_index]
		if (ai["pos"] as Vector2).distance_to(target) < 0.18:
			session["ai_patrol_index"] = (patrol_index + 1) % patrol_points.size()
			target = patrol_points[int(session["ai_patrol_index"])]
	_move_ai_toward(ai, target, ACTOR_SPEED * 0.62, delta)
	if (
		chasing
		and (player["pos"] as Vector2).distance_to(ai["pos"]) < 0.56
		and elapsed >= float(session["ai_touch_cooldown"])
	):
		# Tutorial health is infinite. Contact demonstrates a hit but never
		# teleports, stuns, traps, or otherwise takes movement control away.
		session["ai_touch_cooldown"] = elapsed + 0.8
		session["message"] = "怪物碰到了你；教学中不会死亡，也不会限制你的移动。停止移动可立刻隐匿。"
	elif (
		str(session["objective"]) == "challenge"
		and float(player["pos"].x) >= 4.25
		and not chasing
	):
		session["objective"] = "enter_room_4"


func _update_ai_thief(session: Dictionary, delta: float) -> void:
	var ai := _ai_actor(session)
	session["ai_cycle"] = float(session["ai_cycle"]) + delta
	var cycle_number := int(floor(float(session["ai_cycle"]) / 5.0))
	var cycle_time := fmod(float(session["ai_cycle"]), 5.0)
	if cycle_time < 4.0:
		if elapsed >= float(session["ai_target_until"]):
			session["ai_target_until"] = elapsed + rng.randf_range(0.75, 1.3)
			session["ai_target"] = Vector2(
				rng.randf_range(0.7, 4.3),
				rng.randf_range(0.7, 4.3),
			)
		var target: Vector2 = session["ai_target"]
		_move_ai_toward(ai, target, ACTOR_SPEED * 0.72, delta)
	else:
		_move_ai_toward(ai, Vector2(2.5, 2.5), ACTOR_SPEED * 0.7, delta)
		if int(session["ai_noise_cycle"]) != cycle_number and (ai["pos"] as Vector2).distance_to(Vector2(2.5, 2.5)) < 0.8:
			session["ai_noise_cycle"] = cycle_number
			session["noise_until"] = elapsed + 1.4
			session["noise_pos"] = Vector2(2.5, 2.5)
			var room := _tutorial_room_at(session, Vector2i(2, 0))
			var furniture: Dictionary = room["furniture"][0]
			furniture["last_hit_time"] = elapsed
			_play_tutorial_sound(session, "furniture_hit", -10.0)


func _move_ai_toward(ai: Dictionary, target: Vector2, speed: float, delta: float) -> void:
	var offset: Vector2 = target - ai["pos"]
	if offset.length() <= 0.01:
		return
	var motion := offset.normalized() * minf(speed * delta, offset.length())
	ai["pos"] = Vector2(
		clampf(float(ai["pos"].x) + motion.x, 0.42, ROOM_SIZE - 0.42),
		clampf(float(ai["pos"].y) + motion.y, 0.42, ROOM_SIZE - 0.42),
	)
	ai["moving"] = true
	ai["facing"] = motion.normalized()
	ai["dir"] = _direction_name(motion)


func _play_tutorial_sound(session: Dictionary, sound_name: String, volume_db: float) -> void:
	if not game or not game.sound_streams.has(sound_name):
		return
	var audio_root = session.get("audio_root")
	if audio_root == null or not is_instance_valid(audio_root):
		return
	var player := AudioStreamPlayer.new()
	player.stream = game.sound_streams[sound_name]
	player.volume_db = volume_db
	audio_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _update_timed_effects(session: Dictionary) -> void:
	if elapsed >= float(session["fatigue_until"]):
		session["adrenaline_until"] = 0.0
		session["fatigue_until"] = 0.0


func _update_action_visuals(session: Dictionary) -> void:
	var actor := _player_actor(session)
	var action_time := elapsed - float(session.get("impact_started_at", -10.0))
	var impact_time := HIT_WINDUP_TIME + HIT_LUNGE_TIME
	var total_time := impact_time + HIT_RECOVER_TIME
	if action_time < 0.0 or action_time >= total_time:
		actor["impact_visual_offset"] = Vector2.ZERO
		return
	var facing: Vector2 = session.get("impact_facing", Vector2.RIGHT)
	if action_time < HIT_WINDUP_TIME:
		var windup_t := smoothstep(0.0, 1.0, action_time / HIT_WINDUP_TIME)
		actor["impact_visual_offset"] = -facing * HIT_WINDUP_DISTANCE * windup_t
	elif action_time < impact_time:
		var lunge_t := smoothstep(0.0, 1.0, (action_time - HIT_WINDUP_TIME) / HIT_LUNGE_TIME)
		actor["impact_visual_offset"] = facing * lerpf(-HIT_WINDUP_DISTANCE, HIT_LUNGE_DISTANCE, lunge_t)
	else:
		var recover_t := clampf((action_time - impact_time) / HIT_RECOVER_TIME, 0.0, 1.0)
		actor["impact_visual_offset"] = facing * HIT_LUNGE_DISTANCE * (1.0 - smoothstep(0.0, 1.0, recover_t))


func _sync_session(session: Dictionary) -> void:
	var renderer: World25D = session["renderer"]
	if not renderer or not is_instance_valid(renderer):
		return
	var selected := {"monster": "", "thief": ""}
	var objective := str(session["objective"])
	if objective == "furniture":
		selected[str(session["role"])] = "tutorial-storage-%s" % str(session["role"])
	elif objective in ["shop_hit", "shop"]:
		selected[str(session["role"])] = "tutorial-shop-%s" % str(session["role"])
	elif objective == "exit_hit":
		selected[str(session["role"])] = "tutorial-exit-%s" % str(session["role"])
	renderer.sync(
		session["rooms"],
		session["monster"],
		session["thief"],
		[],
		selected,
		elapsed - float((session["monster"] as Dictionary).get("attack_started_at", -10.0))
			< MONSTER_ATTACK_ANIMATION_SECONDS,
		elapsed,
	)


func _prepare_for_objective(session: Dictionary) -> void:
	var objective := str(session["objective"])
	var actor := _player_actor(session)
	match objective:
		"furniture":
			actor["room"] = Vector2i(1, 0)
			actor["pos"] = Vector2(0.7, 2.5)
		"challenge":
			actor["room"] = Vector2i(2, 0)
			actor["pos"] = Vector2(0.65, 2.5)
		"shop_hit":
			actor["room"] = Vector2i(3, 0)
			actor["pos"] = Vector2(2.5, 4.0)
		"shop":
			session["shop_open"] = true
		"use_tool":
			session["shop_open"] = false
			session["shop_owned"] = true
			session["shop_equipped"] = true
			session["inventory"] = [{"tool_type": "adrenaline", "label": "肾上腺素"}]
			actor["room"] = Vector2i(3, 0)
			actor["pos"] = Vector2(2.5, 3.65)
		"exit_hit":
			actor["room"] = Vector2i(4, 0)
			actor["pos"] = Vector2(2.5, 4.0)


func _finish_run(player: String) -> void:
	if player not in ["A", "B"]:
		return
	var role := str(sessions[player].get("role", ""))
	if role == "":
		return
	completed[player][role] = true
	_clear_run(player)
	var lobby := _fresh_lobby_session()
	lobby["message"] = (
		"%s教学完成。正式比赛会在4局中交替身份，强烈建议继续学习另一个角色。"
		% _role_label(role)
	)
	sessions[player] = lobby


func _player_actor(session: Dictionary) -> Dictionary:
	return session[str(session["role"])]


func _ai_actor(session: Dictionary) -> Dictionary:
	return session[str(session["ai_role"])]


func _tutorial_room_at(session: Dictionary, coord: Vector2i) -> Dictionary:
	return (session["rooms"] as Array)[clampi(coord.x, 0, 4)]


func _make_rooms(role: String) -> Array:
	var rooms: Array = []
	for index in range(5):
		var doors: Array = []
		if index > 0:
			doors.append("left")
		if index < 4:
			doors.append("right")
		rooms.append({
			"coord": Vector2i(index, 0),
			"doors": doors,
			"furniture": [],
			"items": [],
			"traces": [],
			"strokes": [],
			"floor_texture": WORLD_25D_SCRIPT.FLOOR_TEXTURES[index % WORLD_25D_SCRIPT.FLOOR_TEXTURES.size()],
		})
	var storage_contents: Array = []
	if role == "thief":
		storage_contents.append({
			"id": "tutorial-floor-treasure",
			"kind": "treasure",
			"label": "银制烛台",
			"value": 4,
		})
	(rooms[1]["furniture"] as Array).append(_make_furniture(
		"tutorial-storage-%s" % role,
		"木桶",
		Vector2(2.5, 2.5),
		2,
		storage_contents,
	))
	if role == "thief":
		(rooms[2]["furniture"] as Array).append(_make_furniture(
			"tutorial-cover-left",
			"书柜",
			Vector2(2.15, 1.45),
			4,
			[],
		))
		(rooms[2]["furniture"] as Array).append(_make_furniture(
			"tutorial-cover-right",
			"衣柜",
			Vector2(3.15, 3.55),
			4,
			[],
		))
	else:
		(rooms[2]["furniture"] as Array).append(_make_furniture(
			"tutorial-ai-target",
			"木箱",
			Vector2(2.5, 2.5),
			3,
			[],
		))
	(rooms[3]["furniture"] as Array).append(_make_furniture(
		"tutorial-shop-%s" % role,
		"木箱",
		Vector2(2.5, 2.5),
		3,
		[],
	))
	(rooms[4]["furniture"] as Array).append(_make_furniture(
		"tutorial-exit-%s" % role,
		"花瓶",
		Vector2(2.5, 2.5),
		1,
		[],
	))
	return rooms


func _make_furniture(id: String, kind: String, pos: Vector2, base: int, contents: Array) -> Dictionary:
	var bonus := 0
	for content in contents:
		if str(content.get("kind", "")) == "treasure":
			bonus += int(content.get("value", 0))
	return {
		"id": id,
		"kind": kind,
		"pos": pos,
		"rotation": 0.0,
		"opened": false,
		"destroyed": false,
		"damage": 0,
		"base_durability": base,
		"durability": base + bonus,
		"contents": contents,
		"last_hit_time": -10.0,
	}


func _release_tutorial_contents(room: Dictionary, furniture: Dictionary) -> void:
	var contents: Array = furniture["contents"]
	for index in range(contents.size()):
		var item: Dictionary = (contents[index] as Dictionary).duplicate(true)
		item["pos"] = (furniture["pos"] as Vector2) + Vector2(0.45 + index * 0.12, 0.0)
		item["collected"] = false
		room["items"].append(item)
	contents.clear()


func _furniture_in_front(actor: Dictionary, room: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	for furniture in room["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		var offset: Vector2 = furniture["pos"] - actor["pos"]
		var distance := offset.length()
		if distance <= 0.001 or distance > 1.42:
			continue
		if offset.normalized().dot(facing) < 0.58:
			continue
		if distance < best_distance:
			best = furniture
			best_distance = distance
	return best


func _overlaps_furniture(pos: Vector2, furniture: Dictionary) -> bool:
	var radius := 0.56
	match str(furniture["kind"]):
		"书柜", "衣柜": radius = 0.7
		"花瓶": radius = 0.34
	return (furniture["pos"] as Vector2).distance_to(pos) < radius


func _role_label(role: String) -> String:
	return "怪物" if role == "monster" else "盗贼"


func _direction_vector(direction: String) -> Vector2:
	match direction:
		"up": return Vector2.UP
		"right": return Vector2.RIGHT
		"down": return Vector2.DOWN
		_: return Vector2.LEFT


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func objective_title(session: Dictionary) -> String:
	return TUTORIAL_STEP_CATALOG.title(
		str(session.get("objective", "")),
		str(session.get("role", "")),
	)


func objective_detail(player: String, session: Dictionary) -> String:
	var role := str(session.get("role", ""))
	var objective := str(session.get("objective", ""))
	match objective:
		"help":
			return "按 %s 打开帮助菜单；查看后再关闭。" % ("F1" if player == "A" else "Num+")
		"basics":
			return "%s移动 %.0f%%；按%s逆时针%s；按%s顺时针%s。" % [
				"WASD " if player == "A" else "方向键 ",
				clampf(float(session["moved_distance"]) / 1.2 * 100.0, 0.0, 100.0),
				"Q" if player == "A" else "Num7",
				"（完成）" if bool(session["rotated_ccw"]) else "",
				"E" if player == "A" else "Num9",
				"（完成）" if bool(session["rotated_cw"]) else "",
			]
		"enter_room_2":
			return "沿右侧门进入下一个房间。"
		"furniture":
			if role == "thief":
				var room := _tutorial_room_at(session, Vector2i(1, 0))
				var furniture: Dictionary = room["furniture"][0]
				var hit_key := "G" if player == "A" else "Num0"
				var pickup_key := "R" if player == "A" else "Num1"
				return (
					"先按%s撞击木桶至损毁（%d/%d），再靠近掉落藏品按%s拾取。耐久 = 家具2 + 藏品附加4。"
					% [hit_key, int(furniture["damage"]), int(furniture["durability"]), pickup_key]
				)
			return "先按%s撞击一次打开家具，再按%s把随身藏品放入。放入后耐久 = 家具2 + 藏品附加4。" % [
				"G" if player == "A" else "Num0",
				"R" if player == "A" else "Num1",
			]
		"enter_room_3":
			return "家具教学完成，从右侧门进入第三个房间。"
		"challenge":
			if role == "thief":
				return "停止移动会立刻隐匿；即使被怪物碰到也仍可移动。避开巡逻，到达房间右侧。"
			var cooldown_left := maxf(float(session["attack_until"]) - elapsed, 0.0)
			if cooldown_left > 0.0:
				return "横扫冷却 %.1f 秒；跟随噪音锁定AI盗贼。命中：%d / 2。" % [
					cooldown_left,
					int(session["ai_hits"]),
				]
			return "跟随噪音寻找AI盗贼，用%s命中两次：%d / 2。" % [
				"空格" if player == "A" else "Num2",
				int(session["ai_hits"]),
			]
		"enter_room_4":
			return "对抗练习完成，从右侧门进入第四个房间。"
		"shop_hit":
			return "靠近中央发光的教学商店，按%s撞击打开。" % ("G" if player == "A" else "Num0")
		"shop":
			return "%s切换栏位，%s购买/装备，最后按%s准备。" % [
				"A/D" if player == "A" else "←/→",
				"R" if player == "A" else "Num1",
				"H" if player == "A" else "Num5",
			]
		"use_tool":
			return "按%s使用已装备的肾上腺素。" % ("F" if player == "A" else "Num3")
		"enter_room_5":
			return "利用加速从右侧门进入第五个房间；随后会有3秒疲劳。"
		"exit_hit":
			return "靠近中央出口，按%s撞击并完成本角色教学。" % ("G" if player == "A" else "Num0")
	return ""


func prompt_key(player: String, session: Dictionary) -> String:
	if str(session.get("mode", "")) != "running":
		return ""
	if bool(session.get("help_open", false)):
		return "F1" if player == "A" else "Num+"
	if bool(session.get("panel_open", false)):
		return "R" if player == "A" else "Num1"
	if bool(session.get("shop_open", false)):
		if bool(session.get("shop_equipped", false)):
			return "H" if player == "A" else "Num5"
		return "R" if player == "A" else "Num1"
	var objective := str(session.get("objective", ""))
	match objective:
		"help": return "F1" if player == "A" else "Num+"
		"basics":
			if float(session.get("moved_distance", 0.0)) < 1.2:
				return "WASD" if player == "A" else "方向键"
			if not bool(session.get("rotated_ccw", false)):
				return "Q" if player == "A" else "Num7"
			return "E" if player == "A" else "Num9"
		"enter_room_2", "enter_room_3", "enter_room_4", "enter_room_5":
			return "D" if player == "A" else "→"
		"furniture":
			if str(session.get("role", "")) == "thief":
				var furniture: Dictionary = _tutorial_room_at(session, Vector2i(1, 0))["furniture"][0]
				if bool(furniture.get("destroyed", false)):
					return "R" if player == "A" else "Num1"
			return "G" if player == "A" else "Num0"
		"challenge":
			if str(session.get("role", "")) == "monster":
				return "Space" if player == "A" else "Num2"
			return "D" if player == "A" else "→"
		"shop_hit", "exit_hit":
			return "G" if player == "A" else "Num0"
		"use_tool":
			return "F" if player == "A" else "Num3"
	return ""


func is_prompt_key_pressed(player: String, key_label: String) -> bool:
	if key_label == "":
		return false
	if player == "A":
		match key_label:
			"WASD": return (
				Input.is_physical_key_pressed(KEY_W)
				or Input.is_physical_key_pressed(KEY_A)
				or Input.is_physical_key_pressed(KEY_S)
				or Input.is_physical_key_pressed(KEY_D)
			)
			"Q": return Input.is_physical_key_pressed(KEY_Q)
			"E": return Input.is_physical_key_pressed(KEY_E)
			"D": return Input.is_physical_key_pressed(KEY_D)
			"G": return Input.is_physical_key_pressed(KEY_G)
			"R": return Input.is_physical_key_pressed(KEY_R)
			"Space": return Input.is_physical_key_pressed(KEY_SPACE)
			"F": return Input.is_physical_key_pressed(KEY_F)
			"H": return Input.is_physical_key_pressed(KEY_H)
			"F1": return Input.is_key_pressed(KEY_F1)
	else:
		match key_label:
			"方向键": return (
				Input.is_key_pressed(KEY_UP)
				or Input.is_key_pressed(KEY_LEFT)
				or Input.is_key_pressed(KEY_DOWN)
				or Input.is_key_pressed(KEY_RIGHT)
			)
			"→": return Input.is_key_pressed(KEY_RIGHT)
			"Num+": return Input.is_key_pressed(KEY_KP_ADD)
			"Num7": return Input.is_key_pressed(KEY_KP_7)
			"Num9": return Input.is_key_pressed(KEY_KP_9)
			"Num0": return Input.is_key_pressed(KEY_KP_0)
			"Num1": return Input.is_key_pressed(KEY_KP_1)
			"Num2": return Input.is_key_pressed(KEY_KP_2)
			"Num3": return Input.is_key_pressed(KEY_KP_3)
			"Num5": return Input.is_key_pressed(KEY_KP_5)
	return false


func _event_owner(event: InputEventKey) -> String:
	var physical := event.physical_keycode
	var logical := event.keycode
	if logical == KEY_F1 or physical in [
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_G, KEY_R,
		KEY_SPACE, KEY_Z, KEY_X, KEY_F, KEY_C, KEY_V, KEY_H, KEY_T,
	]:
		return "A"
	if logical in [
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4,
		KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9,
		KEY_KP_ADD, KEY_KP_SUBTRACT,
	]:
		return "B"
	return ""


func _is_previous_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode in [KEY_W, KEY_A] if player == "A" else event.keycode in [KEY_UP, KEY_LEFT]


func _is_next_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode in [KEY_S, KEY_D] if player == "A" else event.keycode in [KEY_DOWN, KEY_RIGHT]


func _is_confirm_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_R if player == "A" else event.keycode == KEY_KP_1


func _is_ready_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_H if player == "A" else event.keycode == KEY_KP_5


func _is_help_key(player: String, event: InputEventKey) -> bool:
	return event.keycode == KEY_F1 if player == "A" else event.keycode == KEY_KP_ADD


func _is_rotate_ccw_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_Q if player == "A" else event.keycode == KEY_KP_7


func _is_rotate_cw_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_E if player == "A" else event.keycode == KEY_KP_9


func _is_hit_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_G if player == "A" else event.keycode == KEY_KP_0


func _is_pickup_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_R if player == "A" else event.keycode == KEY_KP_1


func _is_attack_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_SPACE if player == "A" else event.keycode == KEY_KP_2


func _is_use_tool_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_F if player == "A" else event.keycode == KEY_KP_3


func _is_exit_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_T if player == "A" else event.keycode == KEY_KP_SUBTRACT


func _is_focus_left_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_A if player == "A" else event.keycode == KEY_LEFT


func _is_focus_right_key(player: String, event: InputEventKey) -> bool:
	return event.physical_keycode == KEY_D if player == "A" else event.keycode == KEY_RIGHT
