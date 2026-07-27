@tool
class_name ActorSystem
extends "res://scripts/systems/round_system.gd"


# ToolSystem overrides these hooks. Keeping the interface here prevents the
# actor layer from depending on a concrete tool implementation.
func _cancel_teleporter(_role: String, _reason: String) -> void:
	pass


func _destroy_device_in_front(_role: String, _types: Array) -> bool:
	return false


func _device_hit_target_in_front(_role: String) -> Dictionary:
	return {}


func _apply_device_hit(_role: String, _action: Dictionary) -> bool:
	return false


func _move_actor_continuous(role: String, direction: Vector2, delta: float) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	if direction.is_zero_approx():
		return
	var speed := (FURNITURE_SPEED if dragging[role] != "" else ACTOR_SPEED) * _movement_multiplier(role)
	var intended_direction := direction.normalized()
	var actor := _get_actor(role)
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)
	var motion := intended_direction * speed * delta
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var step := motion / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			_move_actor_axis(role, Vector2(step.x, 0))
		if not is_zero_approx(step.y):
			_move_actor_axis(role, Vector2(0, step.y))
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)


func _role_can_act(role: String) -> bool:
	if str(trapped_by.get(role, "")) != "":
		return false
	var effects: Dictionary = status_effects.get(role, {})
	return elapsed >= float(effects.get("stunned_until", 0.0))


func _movement_multiplier(role: String) -> float:
	var effects: Dictionary = status_effects.get(role, {})
	if elapsed < float(effects.get("adrenaline_until", 0.0)):
		return 2.0
	if elapsed < float(effects.get("fatigue_until", 0.0)):
		return 0.5
	return 1.0


func _move_actor_axis(role: String, motion: Vector2) -> void:
	var actor := _get_actor(role)
	actor["dir"] = _direction_name(motion)
	var room := _room_at(actor["room"])

	if dragging[role] != "":
		var held := _find_furniture(room, dragging[role])
		if held.is_empty():
			dragging[role] = ""
			return
		var next_furniture: Vector2 = held["pos"] + motion
		var next_actor: Vector2 = actor["pos"] + motion
		var blocked := (
			next_furniture.x < 0.28 or next_furniture.y < 0.28
			or next_furniture.x > ROOM_SIZE - 0.28 or next_furniture.y > ROOM_SIZE - 0.28
			or not _position_clears_room_walls(room, next_actor, role)
		)
		for other in room["furniture"]:
			if other["id"] == held["id"]:
				continue
			if bool(other.get("destroyed", false)):
				continue
			if (other["pos"] as Vector2).distance_to(next_furniture) < 0.78 or (other["pos"] as Vector2).distance_to(next_actor) < 0.58:
				blocked = true
		if blocked:
			return
		var before := {"pos": held["pos"], "rotation": held["rotation"]}
		held["pos"] = next_furniture
		_record_furniture_strokes(room, held["id"], before, held)
		actor["pos"] = next_actor
		actor["moving"] = true
		_add_noise(role, "拖动家具", actor, 0.42)
		if role == "thief":
			_reveal_thief(actor)
		return

	var target_room: Vector2i = actor["room"]
	var target_pos: Vector2 = actor["pos"] + motion
	if target_pos.x < 0.0 or target_pos.x >= ROOM_SIZE or target_pos.y < 0.0 or target_pos.y >= ROOM_SIZE:
		var actor_pos: Vector2 = actor["pos"]
		var room_delta := Vector2i(
			int(signf(motion.x)) if not is_zero_approx(motion.x) else 0,
			int(signf(motion.y)) if not is_zero_approx(motion.y) else 0
		)
		var aligned: bool = abs(actor_pos.y - 2.5) <= 0.72 if room_delta.x != 0 else abs(actor_pos.x - 2.5) <= 0.72
		if not room["doors"].has(actor["dir"]) or not aligned:
			return
		target_room += room_delta
		if target_room.x < 0 or target_room.y < 0 or target_room.x >= MAP_SIZE or target_room.y >= MAP_SIZE:
			return
		if target_pos.x < 0.0: target_pos.x += ROOM_SIZE
		if target_pos.x >= ROOM_SIZE: target_pos.x -= ROOM_SIZE
		if target_pos.y < 0.0: target_pos.y += ROOM_SIZE
		if target_pos.y >= ROOM_SIZE: target_pos.y -= ROOM_SIZE

	var target_room_data := _room_at(target_room)
	if not _position_clears_room_walls(target_room_data, target_pos, role):
		return
	for furniture in target_room_data["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		if _actor_overlaps_furniture(target_pos, furniture, role):
			return
	actor["room"] = target_room
	actor["pos"] = target_pos
	actor["moving"] = true
	if role == "monster":
		_add_noise(role, "怪物脚步", actor, 0.42)
	else:
		actor["last_moved_at"] = elapsed
		_reveal_thief(actor)


func _actor_collision_radius(role: String) -> float:
	return MONSTER_COLLISION_RADIUS if role == "monster" else THIEF_COLLISION_RADIUS


func _position_clears_room_walls(room: Dictionary, pos: Vector2, role := "") -> bool:
	var doors: Array = room["doors"]
	var collision_radius := ACTOR_COLLISION_RADIUS if role == "" else _actor_collision_radius(role)
	var door_center_limit := (
		WORLD_25D_SCRIPT.DOOR_GAP / (2.0 * WORLD_25D_SCRIPT.CELL_SIZE)
		- collision_radius
	)
	if pos.x < collision_radius:
		if not doors.has("left") or absf(pos.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.x > ROOM_SIZE - collision_radius:
		if not doors.has("right") or absf(pos.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.y < collision_radius:
		if not doors.has("up") or absf(pos.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.y > ROOM_SIZE - collision_radius:
		if not doors.has("down") or absf(pos.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	return true


func _actor_overlaps_furniture(actor_pos: Vector2, furniture: Dictionary, role := "") -> bool:
	var half_extents := _furniture_half_extents(str(furniture["kind"]))
	var collision_radius := ACTOR_COLLISION_RADIUS if role == "" else _actor_collision_radius(role)
	var local_pos := (
		actor_pos - (furniture["pos"] as Vector2)
	).rotated(-deg_to_rad(float(furniture["rotation"])))
	var closest := Vector2(
		clampf(local_pos.x, -half_extents.x, half_extents.x),
		clampf(local_pos.y, -half_extents.y, half_extents.y),
	)
	return local_pos.distance_squared_to(closest) < collision_radius * collision_radius


func _furniture_half_extents(kind: String) -> Vector2:
	# Ground-plane footprint of the renderer's hidden 3D base meshes, converted
	# from world metres to the room's continuous coordinate system.
	var world_size: Vector2
	match kind:
		"床": world_size = Vector2(1.74, 0.87)
		"衣柜": world_size = Vector2(0.87, 0.87)
		"书柜": world_size = Vector2(1.0, 0.87)
		"木桶": world_size = Vector2(0.5, 0.5)
		"木箱": world_size = Vector2(0.6, 0.6)
		"花瓶": world_size = Vector2(0.28, 0.28)
		_: world_size = Vector2(0.6, 0.6)
	return world_size / WORLD_25D_SCRIPT.CELL_SIZE * 0.5


func _direction_name(motion: Vector2) -> String:
	if absf(motion.x) > absf(motion.y):
		return "right" if motion.x > 0.0 else "left"
	return "down" if motion.y > 0.0 else "up"


func _hit_furniture(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	if not (furniture_hit_actions[role] as Dictionary).is_empty():
		return
	var actor := _get_actor(role)
	var device := _device_hit_target_in_front(role)
	if not device.is_empty():
		var device_facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
		furniture_hit_actions[role] = {
			"elapsed": 0.0,
			"impacted": false,
			"room": actor["room"],
			"target_kind": "device",
			"target_id": str(device["id"]),
			"facing": device_facing.normalized(),
		}
		return
	var nearby := _furniture_in_front(role)
	if nearby.is_empty():
		_push_log("%s前方没有可撞击的家具。" % _role_name(role))
		return
	if bool(nearby["destroyed"]):
		_push_log("%s已经损毁。" % nearby["kind"])
		return
	if role == "monster":
		active_storage_id = ""
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	furniture_hit_actions[role] = {
		"elapsed": 0.0,
		"impacted": false,
		"room": actor["room"],
		"target_kind": "furniture",
		"furniture_id": str(nearby["id"]),
		"facing": facing.normalized(),
	}


func _update_furniture_hit_actions(delta: float) -> void:
	var impact_time := HIT_WINDUP_TIME + HIT_LUNGE_TIME
	var total_time := impact_time + HIT_RECOVER_TIME
	for role in ["monster", "thief"]:
		var action: Dictionary = furniture_hit_actions[role]
		if action.is_empty():
			continue
		action["elapsed"] = float(action["elapsed"]) + delta
		var action_time: float = action["elapsed"]
		var facing: Vector2 = action["facing"]
		var actor := _get_actor(role)
		if action_time < HIT_WINDUP_TIME:
			var windup_t := smoothstep(0.0, 1.0, action_time / HIT_WINDUP_TIME)
			actor["impact_visual_offset"] = -facing * HIT_WINDUP_DISTANCE * windup_t
		elif action_time < impact_time:
			var lunge_t := smoothstep(0.0, 1.0, (action_time - HIT_WINDUP_TIME) / HIT_LUNGE_TIME)
			actor["impact_visual_offset"] = facing * lerpf(-HIT_WINDUP_DISTANCE, HIT_LUNGE_DISTANCE, lunge_t)
		else:
			if not bool(action["impacted"]):
				action["impacted"] = true
				_apply_furniture_hit(role, action)
			var recover_t := clampf((action_time - impact_time) / HIT_RECOVER_TIME, 0.0, 1.0)
			actor["impact_visual_offset"] = facing * HIT_LUNGE_DISTANCE * (1.0 - smoothstep(0.0, 1.0, recover_t))
		if action_time >= total_time:
			actor["impact_visual_offset"] = Vector2.ZERO
			furniture_hit_actions[role] = {}


func _apply_furniture_hit(role: String, action: Dictionary) -> void:
	if str(action.get("target_kind", "furniture")) == "device":
		_apply_device_hit(role, action)
		return
	var room_coord: Vector2i = action["room"]
	var room := _room_at(room_coord)
	var furniture := _find_furniture(room, str(action["furniture_id"]))
	if furniture.is_empty() or bool(furniture["destroyed"]):
		return
	_refresh_furniture_durability(furniture)
	room["traces"].append({
		"pos": furniture["pos"],
		"role": role,
		"kind": "interact",
	})
	_add_noise(role, "撞击家具")
	if role == "thief":
		_reveal_thief()
	furniture["last_hit_time"] = elapsed
	_play_sound("furniture_hit", -9.0, 0.08)
	if role == "monster":
		var was_open := bool(furniture["opened"])
		furniture["opened"] = true
		_play_sound("furniture_open", -10.0, 0.12)
		_trigger_furniture_alarm(room_coord, furniture)
		if phase == "hide":
			active_storage_id = str(furniture["id"])
			if was_open:
				_push_log("%s已打开，藏品面板与家具面板已显示。" % furniture["kind"])
			else:
				_push_log("怪物一击打开了%s，藏品面板与家具面板已显示。" % furniture["kind"])
		else:
			var released_tools := _release_furniture_tools(room, furniture)
			if released_tools > 0:
				_push_log("怪物打开%s，发现并掉出 %d 件道具。" % [furniture["kind"], released_tools])
			elif was_open:
				_push_log("%s已经打开，里面没有可取道具。" % furniture["kind"])
			else:
				_push_log("怪物一击打开了%s。" % furniture["kind"])
	else:
		furniture["damage"] = int(furniture["damage"]) + 1
		var durability: int = int(furniture["durability"])
		if int(furniture["damage"]) >= durability:
			furniture["damage"] = durability
			furniture["destroyed"] = true
			furniture["opened"] = true
			_play_sound("furniture_open", -8.0, 0.12)
			_trigger_furniture_alarm(room_coord, furniture)
			var released := _release_furniture_contents(room, furniture)
			_push_log("盗贼撞毁了%s，掉出 %d 件物品。" % [furniture["kind"], released])
		else:
			_push_log("%s损毁度 %d / %d。" % [furniture["kind"], furniture["damage"], durability])


func _trigger_furniture_alarm(room_coord: Vector2i, furniture: Dictionary) -> bool:
	var contents: Array = furniture["contents"]
	for index in range(contents.size() - 1, -1, -1):
		var content: Dictionary = contents[index]
		if str(content.get("kind", "")) != "alarm":
			continue
		var owner := str(content.get("owner", "neutral"))
		contents.remove_at(index)
		_add_noise_at(
			owner,
			"家具警报",
			room_coord,
			furniture["pos"],
			0.0,
			5.0,
			true,
		)
		_push_log("%s里的警报器被触发，全宅邸响起5秒警报！" % furniture["kind"])
		return true
	return false


func _interact_furniture(role: String) -> void:
	_hit_furniture(role)


func _furniture_in_front(role: String, require_open := false) -> Dictionary:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var best: Dictionary = {}
	var best_distance := INF
	for furniture in room["furniture"]:
		if require_open and (not bool(furniture["opened"]) or bool(furniture["destroyed"])):
			continue
		var offset: Vector2 = (furniture["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance <= 0.001 or distance > FURNITURE_HIT_REACH:
			continue
		if offset.normalized().dot(facing) < FURNITURE_HIT_DOT:
			continue
		if distance < best_distance:
			best = furniture
			best_distance = distance
	return best


func _nearest_intact_furniture(role: String, max_distance := 1.25) -> Dictionary:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var best: Dictionary = {}
	var best_distance := INF
	for furniture in room["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		var distance := (furniture["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= max_distance and distance < best_distance:
			best = furniture
			best_distance = distance
	return best


func _update_storage_panel() -> void:
	if active_storage_id == "":
		return
	if _active_storage_furniture().is_empty():
		active_storage_id = ""


func _active_storage_furniture() -> Dictionary:
	if phase != "hide" or active_storage_id == "":
		return {}
	var room := _room_at(monster["room"])
	var furniture := _find_furniture(room, active_storage_id)
	if furniture.is_empty() or not bool(furniture["opened"]) or bool(furniture["destroyed"]):
		return {}
	if (furniture["pos"] as Vector2).distance_to(monster["pos"]) > 1.65:
		return {}
	return furniture


func _release_furniture_contents(room: Dictionary, furniture: Dictionary) -> int:
	var contents: Array = furniture["contents"]
	var released := contents.size()
	for index in range(contents.size()):
		var item: Dictionary = (contents[index] as Dictionary).duplicate(true)
		var angle := TAU * float(index) / float(maxi(contents.size(), 1))
		var offset := Vector2.RIGHT.rotated(angle) * (0.28 + 0.08 * float(index))
		item["pos"] = (furniture["pos"] as Vector2) + offset
		item["collected"] = false
		room["items"].append(item)
	contents.clear()
	return released


func _release_furniture_tools(room: Dictionary, furniture: Dictionary) -> int:
	var contents: Array = furniture["contents"]
	var released := 0
	for index in range(contents.size() - 1, -1, -1):
		var content: Dictionary = contents[index]
		if str(content.get("kind", "")) != "tool":
			continue
		var item := content.duplicate(true)
		var angle := float(released) * 1.9 + 0.35
		item["pos"] = (furniture["pos"] as Vector2) + Vector2.RIGHT.rotated(angle) * (0.34 + released * 0.06)
		item["collected"] = false
		room["items"].append(item)
		contents.remove_at(index)
		released += 1
	return released


func _toggle_furniture_mode(role: String) -> void:
	if dragging[role] == "":
		return
	drag_mode[role] = "rotate" if drag_mode[role] == "move" else "move"
	_push_log("%s切换到%s模式。" % [_role_name(role), "移动" if drag_mode[role] == "move" else "旋转"])


func _rotate_furniture(role: String, direction: float, degrees := ROTATION_STEP) -> void:
	if dragging[role] == "" or drag_mode[role] != "rotate":
		return
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var furniture := _find_furniture(room, dragging[role])
	if furniture.is_empty():
		return
	var before := {"pos": furniture["pos"], "rotation": furniture["rotation"]}
	furniture["rotation"] = fmod(float(furniture["rotation"]) + direction * degrees + 360.0, 360.0)
	_record_furniture_strokes(room, furniture["id"], before, furniture)
	_add_noise(role, "旋转家具", actor, 0.42)
	if role == "thief":
		_reveal_thief(actor)


func _furniture_corners(furniture: Dictionary) -> Array:
	var angle := deg_to_rad(float(furniture["rotation"]))
	var local_points := [
		Vector2(-0.38, -0.26), Vector2(0.38, -0.26),
		Vector2(0.38, 0.26), Vector2(-0.38, 0.26),
	]
	var result: Array = []
	for point in local_points:
		result.append((point as Vector2).rotated(angle) + (furniture["pos"] as Vector2))
	return result


func _record_furniture_strokes(room: Dictionary, furniture_id: String, before: Dictionary, after: Dictionary) -> void:
	var old_corners := _furniture_corners(before)
	var new_corners := _furniture_corners(after)
	for index in range(4):
		room["strokes"].append({
			"furniture_id": furniture_id,
			"from": old_corners[index],
			"to": new_corners[index],
		})


func _place_treasure() -> void:
	if phase != "hide":
		return
	var treasure: Dictionary = TREASURES[selected_treasure]
	var furniture := _active_storage_furniture()
	if furniture.is_empty():
		_push_log("先面向家具按 G 完成冲撞，打开面板后用 R 存取。")
		return
	var contents: Array = furniture["contents"]
	for index in range(contents.size()):
		var content: Dictionary = contents[index]
		if content["id"] == treasure["id"]:
			contents.remove_at(index)
			_refresh_furniture_durability(furniture)
			_push_log("已从%s取出%s。" % [furniture["kind"], treasure["label"]])
			return
	if _furniture_has_primary_content(furniture):
		_push_log("%s的藏品槽已被占用，请先取出原有内容。" % furniture["kind"])
		return
	for room in rooms:
		for other_furniture in room["furniture"]:
			for content in other_furniture["contents"]:
				if content["id"] == treasure["id"]:
					_push_log("%s已存放在其他家具，请先取出。" % treasure["label"])
					return
		for item in room["items"]:
			if item["id"] == treasure["id"] and not bool(item["collected"]):
				_push_log("%s已在房间中。" % treasure["label"])
				return
	contents.append(treasure.duplicate(true))
	_refresh_furniture_durability(furniture)
	var room := _room_at(monster["room"])
	room["traces"].append({"pos": monster["pos"], "role": "monster", "kind": "interact"})
	_push_log("已将%s存入%s（价值 %d）。" % [treasure["label"], furniture["kind"], treasure["value"]])


func _thief_exit() -> void:
	if phase != "hunt" or has_extracted:
		return
	if thief["room"] == ENTRANCE_ROOM and (thief["pos"] as Vector2).distance_to(ENTRANCE_POS) <= 0.58:
		_complete_extraction("入口")
	else:
		_push_log("只有回到入口处才能撤离。")


func _complete_extraction(method: String) -> void:
	if has_extracted:
		return
	_end_round(
		"盗贼通过%s完成本局唯一一次撤离，带出价值 %d 的财物。" % [method, loot_value],
		true,
		false,
	)


func _use_pill() -> void:
	if phase != "hunt" or pills <= 0 or int(thief["hp"]) >= 2 or not _role_can_act("thief"):
		return
	thief["hp"] += 1
	pills -= 1
	_add_noise("thief", "使用药丸")
	_reveal_thief()
	_push_log("盗贼回复了 1 滴血。")


func _trigger_thief_hit_feedback(hit_direction: Vector2) -> void:
	thief["hit_reaction_started_at"] = elapsed
	thief["hit_reaction_direction"] = (
		hit_direction.normalized()
		if not hit_direction.is_zero_approx()
		else Vector2.RIGHT
	)


func _voice(role: String) -> void:
	if phase != "hunt":
		return
	var actor := _get_actor(role)
	if elapsed - float(actor.get("last_voice_at", -10.0)) < VOICE_COOLDOWN_SECONDS:
		return
	actor["last_voice_at"] = elapsed
	var is_thief := role == "thief"
	var sound_name := "scream" if is_thief else "laugh"
	var noise_label := "盗贼尖叫" if is_thief else "怪物笑声"
	_play_sound(sound_name, -5.0, VOICE_COOLDOWN_SECONDS)
	_add_noise(
		role,
		noise_label,
		{},
		VOICE_COOLDOWN_SECONDS,
		VOICE_NOISE_SECONDS,
		false,
		true,
	)
	if is_thief:
		_reveal_thief(actor)
	_push_log("%s主动%s，声音暴露了当前位置。" % [
		_role_name(role),
		"尖叫" if is_thief else "大笑",
	])


func _attack() -> void:
	if phase != "hunt" or elapsed < attack_until or not _role_can_act("monster"):
		return
	attack_until = elapsed + MONSTER_ATTACK_COOLDOWN
	monster["attack_started_at"] = elapsed
	_play_sound("attack", -7.0, 0.18)
	_add_noise("monster", "挥砍")
	var same_room: bool = monster["room"] == thief["room"]
	var vector: Vector2 = thief["pos"] - monster["pos"]
	var distance := vector.length()
	var facing: Vector2 = monster.get("facing", _direction_vector(monster["dir"]))
	var dot := 1.0 if distance == 0.0 else vector.normalized().dot(facing)
	if same_room and distance <= 2.35 and dot >= cos(PI / 4.0):
		thief["hp"] -= 1
		_trigger_thief_hit_feedback(facing)
		status_effects["thief"]["stunned_until"] = maxf(
			float(status_effects["thief"].get("stunned_until", 0.0)),
			elapsed + MONSTER_ATTACK_HIT_STUN_SECONDS,
		)
		furniture_hit_actions["thief"] = {}
		thief["impact_visual_offset"] = Vector2.ZERO
		_cancel_teleporter("thief", "受到怪物攻击")
		_reveal_thief()
		if thief["hp"] <= 0:
			_play_sound("scream", -4.0, 0.2)
			_end_round("怪物砍倒了盗贼，守住了老宅。", false, true)
		else:
			_push_log("横扫命中！盗贼失去 1 滴血并硬直 %.1f 秒。" % MONSTER_ATTACK_HIT_STUN_SECONDS)
	else:
		if _destroy_device_in_front("monster", ["decoy", "phonograph"]):
			_push_log("怪物击碎了前方的装置。")
		else:
			_push_log("怪物挥砍落空。")
