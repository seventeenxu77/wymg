@tool
class_name ToolSystem
extends "res://scripts/systems/actor_system.gd"

func _selected_tool(role: String) -> Dictionary:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		return {}
	var index := clampi(int(tool_selected[role]), 0, inventory.size() - 1)
	tool_selected[role] = index
	return inventory[index]


func _cycle_tool(role: String, direction: int) -> void:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		_push_log("%s没有携带道具。" % _role_name(role))
		return
	tool_selected[role] = posmod(int(tool_selected[role]) + direction, inventory.size())
	_push_log("%s选择了%s。" % [_role_name(role), _selected_tool(role)["label"]])


func _consume_selected_tool(role: String) -> void:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		return
	var index := clampi(int(tool_selected[role]), 0, inventory.size() - 1)
	inventory.remove_at(index)
	tool_selected[role] = clampi(index, 0, maxi(inventory.size() - 1, 0))


func _pick_up_nearby(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for item in room["items"]:
		if not _role_can_pick_up_item(role, item):
			continue
		var distance := (item["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= PICKUP_DISTANCE and distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	if nearest.is_empty():
		_push_log("%s附近没有可拾取物品。" % _role_name(role))
		return
	var is_world_tool := str(nearest.get("kind", "")) == "tool"
	var is_trap_tool := (
		str(nearest.get("kind", "")) == "device"
		and str(nearest.get("device_type", "")) == "trap"
		and str(nearest.get("state", "")) == "recoverable"
	)
	if is_world_tool or is_trap_tool:
		var inventory: Array = tool_inventories[role]
		if inventory.size() >= TOOL_INVENTORY_CAPACITY:
			_push_log("%s的3格道具栏已满。" % _role_name(role))
			return
		var tool_type := "trap" if is_trap_tool else str(nearest["tool_type"])
		if role == "monster" and tool_type == "teleporter":
			_push_log("传送器只能由盗贼使用。")
			return
		var carried := _make_tool_instance(tool_type, str(nearest["id"]))
		if tool_type == "detector":
			carried["charge"] = float(nearest.get("charge", DETECTOR_BATTERY_SECONDS))
		inventory.append(carried)
		tool_selected[role] = inventory.size() - 1
		nearest["collected"] = true
		_add_noise(role, "拾取道具")
		if role == "thief":
			_reveal_thief()
		_push_log("%s拾取了%s（%d/3）。" % [_role_name(role), carried["label"], inventory.size()])
		return
	if role != "thief":
		return
	nearest["collected"] = true
	if str(nearest["kind"]) in ["treasure", "trinket"]:
		loot_value += int(nearest["value"])
		if _is_monster_treasure(nearest):
			stolen_monster_value += int(nearest["value"])
		_push_log("盗贼携带%s，身上价值 %d。" % [nearest["label"], loot_value])
	else:
		pills += 1
		_push_log("盗贼捡到一颗治疗药丸。")
	_add_noise("thief", "拾取物品")
	_reveal_thief()


func _role_can_pick_up_item(role: String, item: Dictionary) -> bool:
	if bool(item.get("collected", false)):
		return false
	var is_tool := str(item.get("kind", "")) == "tool"
	var is_recovered_trap := (
		str(item.get("kind", "")) == "device"
		and str(item.get("device_type", "")) == "trap"
		and str(item.get("state", "")) == "recoverable"
	)
	var is_loot := str(item.get("kind", "")) in ["treasure", "trinket", "pill"]
	if role == "monster" and not (is_tool or is_recovered_trap):
		return false
	if role == "thief" and not (is_tool or is_recovered_trap or is_loot):
		return false
	if role == "monster" and str(item.get("tool_type", "")) == "teleporter":
		return false
	return true


func _nearby_tool_for_panel(role: String) -> Dictionary:
	var actor := _get_actor(role)
	if actor.is_empty():
		return {}
	var room := _room_at(actor["room"])
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for item in room["items"]:
		if bool(item.get("collected", false)):
			continue
		var kind := str(item.get("kind", ""))
		var device_type := str(item.get("device_type", ""))
		if kind != "tool" and (kind != "device" or device_type == "decoy"):
			continue
		var tool_type := str(item.get("tool_type", device_type))
		if not TOOL_DEFS.has(tool_type):
			continue
		var distance := (item["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= TOOL_INSPECT_DISTANCE and distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	if nearest.is_empty():
		return {}
	return {"item": nearest, "distance": nearest_distance}


func _thief_search() -> void:
	_pick_up_nearby("thief")


func _use_selected_tool(role: String) -> void:
	var tool := _selected_tool(role)
	if (
		not tool.is_empty()
		and str(tool.get("tool_type", "")) == "detector"
		and bool(tool.get("active", false))
	):
		_toggle_detector(role, tool)
		return
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	if _activate_nearby_phonograph(role):
		return
	if tool.is_empty():
		_push_log("%s没有可用道具。" % _role_name(role))
		return
	if role == "thief":
		_reveal_thief()
	match str(tool["tool_type"]):
		"detector": _toggle_detector(role, tool)
		"alarm": _place_alarm(role)
		"trap": _place_trap(role)
		"adrenaline": _use_adrenaline(role)
		"decoy": _use_decoy(role)
		"phonograph": _place_phonograph(role)
		"teleporter": _start_teleporter(role)
		"spring_glove": _use_spring_glove(role)
		"robot": _use_robot(role, tool)


func _toggle_detector(role: String, tool: Dictionary) -> void:
	if float(tool.get("charge", 0.0)) <= 0.0:
		tool["active"] = false
		_push_log("藏品探测器电量已经耗尽。")
		return
	tool["active"] = not bool(tool.get("active", false))
	if bool(tool["active"]):
		tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
		_push_log("%s开启探测器，本房间藏品信号开始显现。" % _role_name(role))
	else:
		_push_log("%s关闭探测器。" % _role_name(role))


func _place_alarm(role: String) -> void:
	var furniture := _nearest_intact_furniture(role)
	if furniture.is_empty():
		_push_log("必须靠近一件完好的家具才能安装警报器；本次未消耗道具。")
		return
	if _furniture_has_primary_content(furniture):
		_push_log("%s的藏品槽已经被占用。" % furniture["kind"])
		return
	furniture["contents"].append({
		"id": "alarm-%d" % next_device_id,
		"kind": "alarm",
		"label": "警报器",
		"value": 0,
		"signal_value": 3,
		"owner": role,
	})
	next_device_id += 1
	_consume_selected_tool(role)
	_add_noise(role, "安装警报器")
	if role == "thief":
		_reveal_thief()
	_push_log("%s把警报器藏进了%s。" % [_role_name(role), furniture["kind"]])


func _device_position(role: String, forward_distance := 0.42) -> Vector2:
	var actor := _get_actor(role)
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var target: Vector2 = actor["pos"] + facing.normalized() * forward_distance
	var room := _room_at(actor["room"])
	if not _position_clears_room_walls(room, target, role):
		return actor["pos"]
	for furniture in room["furniture"]:
		if not bool(furniture.get("destroyed", false)) and _actor_overlaps_furniture(target, furniture, role):
			return actor["pos"]
	return target


func _spawn_device(role: String, device_type: String, position: Vector2) -> Dictionary:
	var actor := _get_actor(role)
	var device := GAMEPLAY_STATE_FACTORY.device(
		device_type,
		"device-%d" % next_device_id,
		str(TOOL_DEFS[device_type]["label"]),
		role,
		position,
		elapsed,
	)
	next_device_id += 1
	_room_at(actor["room"])["items"].append(device)
	return device


func _use_robot(role: String, tool: Dictionary) -> void:
	if bool(tool.get("deployed", false)):
		_swap_with_robot(role, tool)
		return
	var actor := _get_actor(role)
	var device := _spawn_device(role, "robot", _device_position(role, 0.52))
	device["origin_room"] = actor["room"]
	device["patrol_rooms"] = _robot_patrol_rooms(actor["room"])
	device["waypoints"] = []
	device["stunned_until"] = 0.0
	device["next_alarm"] = 0.0
	device["alert_until"] = 0.0
	device["stuck_time"] = 0.0
	device["state"] = "active"
	tool["deployed"] = true
	tool["robot_id"] = str(device["id"])
	tool["stunned_until"] = 0.0
	_add_noise(role, "召唤发条巡夜偶")
	if role == "thief":
		_reveal_thief()
	_push_log(
		"%s召唤了发条巡夜偶，它会在周围九宫格的 %d 个可达房间内巡逻。"
		% [_role_name(role), (device["patrol_rooms"] as Array).size()]
	)


func _swap_with_robot(role: String, tool: Dictionary) -> void:
	var found := _find_device_entry(str(tool.get("robot_id", "")))
	if found.is_empty():
		_push_log("%s的巡夜偶已经失效。" % _role_name(role))
		_consume_selected_tool(role)
		return
	var robot: Dictionary = found["item"]
	if elapsed < float(robot.get("stunned_until", 0.0)):
		_push_log(
			"巡夜偶仍在停机，%.1f秒后才能换位。"
			% (float(robot["stunned_until"]) - elapsed)
		)
		return
	var actor := _get_actor(role)
	var old_room: Vector2i = actor["room"]
	var old_pos: Vector2 = actor["pos"]
	var robot_room: Vector2i = (found["room"] as Dictionary)["coord"]
	var robot_pos: Vector2 = robot["pos"]
	dragging[role] = ""
	drag_mode[role] = "move"
	actor["room"] = robot_room
	actor["pos"] = robot_pos
	actor["moving"] = false
	robot["collected"] = true
	_add_noise_at(role, "巡夜偶换位起点", old_room, old_pos, 0.0, 2.0, false)
	_add_noise_at(role, "巡夜偶换位终点", robot_room, robot_pos, 0.0, 2.0, false)
	if role == "thief":
		_reveal_thief(actor)
	_consume_selected_tool(role)
	_push_log("%s与巡夜偶交换位置，巡夜偶随即报废。" % _role_name(role))


func _robot_patrol_rooms(origin: Vector2i) -> Array:
	var result: Array = []
	var pending: Array = [origin]
	var visited := {_coord_key(origin): true}
	while not pending.is_empty():
		var coord: Vector2i = pending.pop_front()
		result.append(coord)
		var room := _room_at(coord)
		for edge in DIRECTIONS:
			if not (room["doors"] as Array).has(str(edge["name"])):
				continue
			var neighbor: Vector2i = coord + (edge["delta"] as Vector2i)
			if (
				neighbor.x < 0 or neighbor.y < 0
				or neighbor.x >= MAP_SIZE or neighbor.y >= MAP_SIZE
				or absi(neighbor.x - origin.x) > 1
				or absi(neighbor.y - origin.y) > 1
			):
				continue
			var key := _coord_key(neighbor)
			if visited.has(key):
				continue
			visited[key] = true
			pending.append(neighbor)
	return result


func _coord_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func _find_device_entry(device_id: String) -> Dictionary:
	if device_id == "":
		return {}
	for room in rooms:
		for item in room["items"]:
			if (
				str(item.get("id", "")) == device_id
				and not bool(item.get("collected", false))
			):
				return {"room": room, "item": item}
	return {}


func _place_trap(role: String) -> void:
	var device := _spawn_device(role, "trap", _device_position(role, 0.5))
	device["armed_at"] = elapsed + TRAP_ARM_DELAY
	_consume_selected_tool(role)
	_push_log("%s放置了捕兽夹，0.6秒后完成布置。" % _role_name(role))


func _use_adrenaline(role: String) -> void:
	var effects: Dictionary = status_effects[role]
	if elapsed < float(effects["fatigue_until"]):
		_push_log("%s仍受肾上腺素或疲劳影响。" % _role_name(role))
		return
	effects["adrenaline_until"] = elapsed + ADRENALINE_SECONDS
	effects["fatigue_until"] = elapsed + ADRENALINE_SECONDS + FATIGUE_SECONDS
	_consume_selected_tool(role)
	_add_noise(role, "注射肾上腺素")
	if role == "thief":
		_reveal_thief()
	_push_log("%s进入6秒双倍加速，随后疲劳3秒。" % _role_name(role))


func _use_decoy(role: String) -> void:
	var actor := _get_actor(role)
	var decoy := _spawn_device(role, "decoy", actor["pos"])
	decoy["expires"] = elapsed + DECOY_SECONDS
	decoy["character_role"] = role
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	decoy["move_direction"] = -facing.normalized()
	_consume_selected_tool(role)
	_displace_actor(role, facing.normalized() * DECOY_DASH_DISTANCE)
	_add_noise(role, "替身位移")
	if role == "thief":
		_reveal_thief()
	_push_log("%s向前位移，替身沿反方向奔跑10秒。" % _role_name(role))


func _place_phonograph(role: String) -> void:
	var device := _spawn_device(role, "phonograph", _device_position(role, 0.45))
	device["state"] = "idle"
	_consume_selected_tool(role)
	_push_log("%s放置了留声机；靠近后再按使用键启动。" % _role_name(role))


func _activate_nearby_phonograph(role: String) -> bool:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	for item in room["items"]:
		if (
			bool(item.get("collected", false))
			or str(item.get("device_type", "")) != "phonograph"
			or str(item.get("state", "")) != "idle"
			or str(item.get("owner", "")) != role
		):
			continue
		if (item["pos"] as Vector2).distance_to(actor["pos"]) > 0.9:
			continue
		item["state"] = "playing"
		item["starts_at"] = elapsed + PHONOGRAPH_DELAY
		item["expires"] = elapsed + PHONOGRAPH_DELAY + PHONOGRAPH_SECONDS
		item["next_noise"] = elapsed + PHONOGRAPH_DELAY
		_push_log("%s启动留声机，2秒后开始播放10秒撞击声。" % _role_name(role))
		return true
	return false


func _start_teleporter(role: String) -> void:
	if role != "thief":
		_push_log("传送器只能由盗贼启动。")
		return
	if phase != "hunt" or has_extracted:
		return
	var effects: Dictionary = status_effects[role]
	if float(effects["teleport_ends"]) > elapsed:
		_push_log("传送器已经在轰鸣充能。")
		return
	effects["teleport_started"] = elapsed
	effects["teleport_ends"] = elapsed + TELEPORT_CHANNEL_SECONDS
	_consume_selected_tool(role)
	_add_noise(role, "传送器轰鸣", {}, 0.0, TELEPORT_CHANNEL_SECONDS, true, true)
	_reveal_thief()
	_push_log("传送器开始持续轰鸣，5秒后携带全部财物撤离。")


func _use_spring_glove(role: String) -> void:
	var actor := _get_actor(role)
	var target_role := "thief" if role == "monster" else "monster"
	var target := _get_actor(target_role)
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var vector: Vector2 = target["pos"] - actor["pos"]
	var hit_actor: bool = (
		actor["room"] == target["room"]
		and vector.length() <= SPRING_GLOVE_REACH
		and (vector.is_zero_approx() or vector.normalized().dot(facing) >= 0.5)
	)
	_consume_selected_tool(role)
	_add_noise(role, "弹簧拳套")
	if hit_actor:
		status_effects[target_role]["stunned_until"] = elapsed + SPRING_GLOVE_STUN_SECONDS
		_cancel_teleporter(target_role, "被弹簧拳套击中")
		_displace_actor(target_role, facing.normalized() * SPRING_GLOVE_KNOCKBACK)
		if target_role == "thief":
			_reveal_thief()
		_push_log("%s被击退并眩晕1秒！" % _role_name(target_role))
	elif _destroy_device_in_front(role, ["decoy", "phonograph"]):
		_push_log("弹簧拳套击碎了前方装置。")
	else:
		_push_log("%s的弹簧拳套落空并损毁。" % _role_name(role))


func _displace_actor(role: String, displacement: Vector2) -> void:
	if displacement.is_zero_approx():
		return
	var actor := _get_actor(role)
	dragging[role] = ""
	drag_mode[role] = "move"
	var old_facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var old_dir := str(actor["dir"])
	var subdivisions := maxi(1, int(ceil(displacement.length() / 0.05)))
	var step := displacement / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			_move_actor_axis(role, Vector2(step.x, 0))
		if not is_zero_approx(step.y):
			_move_actor_axis(role, Vector2(0, step.y))
	actor["facing"] = old_facing
	actor["dir"] = old_dir


func _handle_trap_escape_input(role: String, key: Key, physical: Key) -> bool:
	if str(trapped_by.get(role, "")) == "":
		return false
	var player := _player_for_role(role)
	var pressed_left := physical == KEY_A if player == "A" else key == KEY_LEFT
	var pressed_right := physical == KEY_D if player == "A" else key == KEY_RIGHT
	if not pressed_left and not pressed_right:
		return false
	var expects_left: bool = bool(trap_expected_left[role])
	if (expects_left and pressed_left) or (not expects_left and pressed_right):
		trap_escape_progress[role] = int(trap_escape_progress[role]) + 1
		trap_expected_left[role] = not expects_left
		var next_left: bool = bool(trap_expected_left[role])
		var prompt := "A" if next_left else "D"
		if player != "A":
			prompt = "←" if next_left else "→"
		_get_actor(role)["trap_prompt"] = prompt
		_add_noise(role, "捕兽夹挣扎", {}, 0.12, 2.0, true, true)
		if int(trap_escape_progress[role]) >= TRAP_ESCAPE_PRESSES:
			_escape_trap(role)
	return true


func _escape_trap(role: String) -> void:
	var device_id := str(trapped_by[role])
	for room in rooms:
		for item in room["items"]:
			if str(item.get("id", "")) != device_id:
				continue
			item["state"] = "recoverable"
			item["tool_type"] = "trap"
			item["label"] = TOOL_DEFS["trap"]["label"]
			break
	trapped_by[role] = ""
	trap_escape_progress[role] = 0
	trap_expected_left[role] = true
	var actor := _get_actor(role)
	actor["trapped"] = false
	actor["trap_prompt"] = ""
	_push_log("%s挣脱捕兽夹，夹子现在可以被任意一方拾取。" % _role_name(role))


func _cancel_teleporter(role: String, reason: String) -> void:
	var effects: Dictionary = status_effects.get(role, {})
	if float(effects.get("teleport_ends", -1.0)) <= elapsed:
		return
	effects["teleport_started"] = -1.0
	effects["teleport_ends"] = -1.0
	_push_log("%s，%s的传送被打断。" % [reason, _role_name(role)])


func _device_hit_target_in_front(role: String) -> Dictionary:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var best: Dictionary = {}
	var best_distance := INF
	for item in room["items"]:
		if (
			bool(item.get("collected", false))
			or str(item.get("kind", "")) != "device"
			or str(item.get("device_type", "")) != "robot"
			or str(item.get("owner", "")) == role
		):
			continue
		var offset: Vector2 = (item["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance <= 0.001 or distance > FURNITURE_HIT_REACH:
			continue
		if offset.normalized().dot(facing) < FURNITURE_HIT_DOT:
			continue
		if distance < best_distance:
			best = item
			best_distance = distance
	return best


func _apply_device_hit(role: String, action: Dictionary) -> bool:
	var found := _find_device_entry(str(action.get("target_id", "")))
	if found.is_empty():
		_push_log("%s撞向巡夜偶，但它已经离开。" % _role_name(role))
		return false
	var robot: Dictionary = found["item"]
	var robot_room: Vector2i = (found["room"] as Dictionary)["coord"]
	var actor := _get_actor(role)
	var facing: Vector2 = action.get("facing", actor.get("facing", Vector2.RIGHT))
	var offset: Vector2 = (robot["pos"] as Vector2) - (actor["pos"] as Vector2)
	if (
		actor["room"] != robot_room
		or offset.length() > FURNITURE_HIT_REACH + HIT_LUNGE_DISTANCE
		or (not offset.is_zero_approx() and offset.normalized().dot(facing) < 0.35)
	):
		_push_log("%s撞向巡夜偶，但它躲开了。" % _role_name(role))
		return false
	var stunned_until := elapsed + ROBOT_STUN_SECONDS
	robot["stunned_until"] = stunned_until
	robot["state"] = "stunned"
	robot["waypoints"] = []
	robot["stuck_time"] = 0.0
	for inventory in tool_inventories.values():
		for tool in inventory:
			if str(tool.get("robot_id", "")) == str(robot["id"]):
				tool["stunned_until"] = stunned_until
	_add_noise(role, "撞击巡夜偶")
	if role == "thief":
		_reveal_thief()
	_play_sound("furniture_hit", -9.0, 0.08)
	_push_log(
		"%s撞晕了敌方巡夜偶；它将在10秒内停止巡逻、报警和换位。"
		% _role_name(role)
	)
	return true


func _update_tool_states(delta: float) -> void:
	for room in rooms:
		for furniture in room["furniture"]:
			furniture["detector_active"] = false
	for role in ["monster", "thief"]:
		var inventory: Array = tool_inventories[role]
		for tool in inventory:
			if str(tool.get("tool_type", "")) != "detector" or not bool(tool.get("active", false)):
				continue
			var charge := maxf(float(tool.get("charge", 0.0)) - delta, 0.0)
			tool["charge"] = charge
			if charge <= 0.0:
				tool["active"] = false
				_push_log("%s的藏品探测器电量耗尽。" % _role_name(role))
				continue
			var actor := _get_actor(role)
			for furniture in _room_at(actor["room"])["furniture"]:
				furniture["detector_active"] = true
			if elapsed >= float(tool.get("next_noise", 0.0)):
				tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
				_add_noise(role, "探测器脉冲", {}, 0.0, 2.0, true, true)
		var effects: Dictionary = status_effects[role]
		var teleport_ends := float(effects.get("teleport_ends", -1.0))
		if teleport_ends > 0.0 and elapsed >= teleport_ends:
			effects["teleport_started"] = -1.0
			effects["teleport_ends"] = -1.0
			if role == "thief" and phase == "hunt" and not has_extracted:
				_complete_extraction("传送器")


func _update_robots(delta: float) -> void:
	var robots: Array = []
	for room in rooms:
		for item in room["items"]:
			if (
				not bool(item.get("collected", false))
				and str(item.get("kind", "")) == "device"
				and str(item.get("device_type", "")) == "robot"
			):
				robots.append(item)
	for robot in robots:
		var found := _find_device_entry(str(robot["id"]))
		if found.is_empty():
			continue
		var room: Dictionary = found["room"]
		if elapsed < float(robot.get("stunned_until", 0.0)):
			robot["state"] = "stunned"
			continue
		if str(robot.get("state", "")) == "stunned":
			robot["state"] = "active"
			_push_log("%s的巡夜偶恢复工作。" % _role_name(str(robot.get("owner", "monster"))))
			robot["waypoints"] = []
			robot["stuck_time"] = 0.0
			_sync_robot_controller_state(robot, 0.0)
		_check_robot_alarm(robot, room)
		if delta <= 0.0:
			continue
		_update_robot_movement(robot, room["coord"], delta)


func _sync_robot_controller_state(robot: Dictionary, stunned_until: float) -> void:
	for inventory in tool_inventories.values():
		for tool in inventory:
			if str(tool.get("robot_id", "")) == str(robot.get("id", "")):
				tool["stunned_until"] = stunned_until


func _check_robot_alarm(robot: Dictionary, room: Dictionary) -> void:
	if phase != "hunt" or elapsed < float(robot.get("next_alarm", 0.0)):
		return
	var owner := str(robot.get("owner", "monster"))
	var enemy_role := "thief" if owner == "monster" else "monster"
	var enemy := _get_actor(enemy_role)
	if enemy["room"] != room["coord"]:
		return
	robot["next_alarm"] = elapsed + ROBOT_ALARM_COOLDOWN
	robot["alert_until"] = elapsed + ROBOT_ALARM_SECONDS
	_add_noise_at(
		owner,
		"巡夜偶警报",
		room["coord"],
		robot["pos"],
		0.0,
			ROBOT_ALARM_SECONDS,
			true,
			str(robot["id"]),
		)
	_push_log(
		"%s的巡夜偶在房间(%d,%d)发现敌人，警报持续3秒！"
		% [owner, room["coord"].x + 1, room["coord"].y + 1]
	)


func _update_robot_movement(robot: Dictionary, room_coord: Vector2i, delta: float) -> void:
	var waypoints: Array = robot.get("waypoints", [])
	if waypoints.is_empty():
		waypoints = _make_robot_waypoints(robot, room_coord)
		robot["waypoints"] = waypoints
	if waypoints.is_empty():
		return
	var current_global := _robot_global_position(room_coord, robot["pos"])
	var target_global: Vector2 = waypoints[0]
	var to_target := target_global - current_global
	if to_target.length() <= 0.08:
		waypoints.pop_front()
		robot["waypoints"] = waypoints
		return
	var travel := minf(ROBOT_SPEED * delta, to_target.length())
	var before := current_global
	var current_room := _move_robot_motion(robot, room_coord, to_target.normalized() * travel)
	var after := _robot_global_position(current_room, robot["pos"])
	if after.distance_to(before) <= 0.001:
		robot["stuck_time"] = float(robot.get("stuck_time", 0.0)) + delta
		if float(robot["stuck_time"]) >= 0.45:
			robot["waypoints"] = []
			robot["stuck_time"] = 0.0
	else:
		robot["stuck_time"] = 0.0
	if after.distance_to(target_global) <= 0.1 and not (robot["waypoints"] as Array).is_empty():
		(robot["waypoints"] as Array).pop_front()


func _make_robot_waypoints(robot: Dictionary, current_room: Vector2i) -> Array:
	var patrol_rooms: Array = robot.get("patrol_rooms", [current_room])
	if patrol_rooms.is_empty():
		patrol_rooms = [current_room]
	var result: Array = []
	var current_data := _room_at(current_room)
	var fallback: Vector2 = robot["pos"]
	for _index in range(ROBOT_ROOM_WANDER_POINTS):
		var local_target := _robot_random_position(current_data, fallback)
		result.append(_robot_global_position(current_room, local_target))
		fallback = local_target
	var exits: Array = []
	for edge in DIRECTIONS:
		if not (current_data["doors"] as Array).has(str(edge["name"])):
			continue
		var neighbor: Vector2i = current_room + (edge["delta"] as Vector2i)
		if patrol_rooms.has(neighbor):
			exits.append({"room": neighbor, "delta": edge["delta"]})
	if not exits.is_empty():
		var chosen: Dictionary = exits[rng.randi_range(0, exits.size() - 1)]
		var next_room: Vector2i = chosen["room"]
		var room_delta: Vector2i = chosen["delta"]
		result.append(
			_robot_global_position(
				next_room,
				_robot_door_entry_position(room_delta),
			)
		)
	return result


func _robot_door_entry_position(delta_room: Vector2i) -> Vector2:
	if delta_room.x > 0:
		return Vector2(0.32, ROOM_SIZE * 0.5)
	if delta_room.x < 0:
		return Vector2(ROOM_SIZE - 0.32, ROOM_SIZE * 0.5)
	if delta_room.y > 0:
		return Vector2(ROOM_SIZE * 0.5, 0.32)
	return Vector2(ROOM_SIZE * 0.5, ROOM_SIZE - 0.32)


func _robot_random_position(room: Dictionary, fallback: Vector2) -> Vector2:
	for _attempt in range(32):
		var candidate := Vector2(
			0.42 + rng.randf() * (ROOM_SIZE - 0.84),
			0.42 + rng.randf() * (ROOM_SIZE - 0.84),
		)
		if not _position_clears_room_walls(room, candidate):
			continue
		var blocked := false
		for furniture in room["furniture"]:
			if (
				not bool(furniture.get("destroyed", false))
				and _actor_overlaps_furniture(candidate, furniture)
			):
				blocked = true
				break
		if not blocked:
			return candidate
	return fallback


func _robot_global_position(room: Vector2i, pos: Vector2) -> Vector2:
	return Vector2(room) * ROOM_SIZE + pos


func _move_robot_motion(
	robot: Dictionary,
	start_room: Vector2i,
	motion: Vector2
) -> Vector2i:
	var room_coord := start_room
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var step := motion / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			room_coord = _move_robot_axis(robot, room_coord, Vector2(step.x, 0.0))
		if not is_zero_approx(step.y):
			room_coord = _move_robot_axis(robot, room_coord, Vector2(0.0, step.y))
	return room_coord


func _move_robot_axis(
	robot: Dictionary,
	room_coord: Vector2i,
	motion: Vector2
) -> Vector2i:
	var room := _room_at(room_coord)
	var target_room := room_coord
	var target_pos: Vector2 = robot["pos"] + motion
	if (
		target_pos.x < 0.0 or target_pos.x >= ROOM_SIZE
		or target_pos.y < 0.0 or target_pos.y >= ROOM_SIZE
	):
		var direction_name := _direction_name(motion)
		var room_delta := Vector2i(
			int(signf(motion.x)) if not is_zero_approx(motion.x) else 0,
			int(signf(motion.y)) if not is_zero_approx(motion.y) else 0,
		)
		var current_pos: Vector2 = robot["pos"]
		var aligned: bool = (
			absf(current_pos.y - ROOM_SIZE * 0.5) <= 0.72
			if room_delta.x != 0
			else absf(current_pos.x - ROOM_SIZE * 0.5) <= 0.72
		)
		if not (room["doors"] as Array).has(direction_name) or not aligned:
			return room_coord
		target_room += room_delta
		if (
			target_room.x < 0 or target_room.y < 0
			or target_room.x >= MAP_SIZE or target_room.y >= MAP_SIZE
		):
			return room_coord
		if target_pos.x < 0.0:
			target_pos.x += ROOM_SIZE
		if target_pos.x >= ROOM_SIZE:
			target_pos.x -= ROOM_SIZE
		if target_pos.y < 0.0:
			target_pos.y += ROOM_SIZE
		if target_pos.y >= ROOM_SIZE:
			target_pos.y -= ROOM_SIZE
	var target_data := _room_at(target_room)
	if not _position_clears_room_walls(target_data, target_pos):
		return room_coord
	for furniture in target_data["furniture"]:
		if (
			not bool(furniture.get("destroyed", false))
			and _actor_overlaps_furniture(target_pos, furniture)
		):
			return room_coord
	robot["pos"] = target_pos
	if target_room != room_coord:
		(room["items"] as Array).erase(robot)
		(target_data["items"] as Array).append(robot)
	return target_room


func _update_devices(delta := 0.0) -> void:
	_update_robots(delta)
	_update_decoys(delta)
	for room in rooms:
		for item in room["items"]:
			if bool(item.get("collected", false)) or str(item.get("kind", "")) != "device":
				continue
			match str(item.get("device_type", "")):
				"trap":
					var trap_state := str(item.get("state", ""))
					if trap_state == "sprung":
						if elapsed >= float(item.get("next_noise", 0.0)):
							item["next_noise"] = elapsed + 1.0
							_add_noise_at(
								str(item.get("trapped_role", item.get("owner", "neutral"))),
								"捕兽夹持续响动",
								room["coord"],
								item["pos"],
								0.0,
								2.0,
								true,
							)
						continue
					if trap_state != "active" or elapsed < float(item.get("armed_at", INF)):
						continue
					for role in ["monster", "thief"]:
						if str(trapped_by[role]) != "":
							continue
						var actor := _get_actor(role)
						if actor["room"] != room["coord"]:
							continue
						if (actor["pos"] as Vector2).distance_to(item["pos"]) <= TRAP_TRIGGER_RADIUS:
							item["state"] = "sprung"
							item["trapped_role"] = role
							item["sprung_at"] = elapsed
							item["next_noise"] = elapsed + 1.0
							trapped_by[role] = str(item["id"])
							trap_escape_progress[role] = 0
							trap_expected_left[role] = true
							actor["trapped"] = true
							actor["trapped_started_at"] = elapsed
							actor["trap_prompt"] = "A" if _player_for_role(role) == "A" else "←"
							_cancel_teleporter(role, "踩中捕兽夹")
							_add_noise_at(role, "捕兽夹触发", room["coord"], item["pos"], 0.0, 3.0, true)
							_push_log("%s踩中捕兽夹，左右键交替20次才能挣脱！" % _role_name(role))
							break
				"decoy":
					if elapsed >= float(item.get("expires", INF)):
						item["collected"] = true
				"phonograph":
					if str(item.get("state", "")) == "idle":
						continue
					if elapsed >= float(item.get("expires", INF)):
						item["collected"] = true
						_push_log("留声机播放完毕并自动粉碎。")
					elif elapsed >= float(item.get("starts_at", INF)) and elapsed >= float(item.get("next_noise", INF)):
						item["next_noise"] = elapsed + 0.9
						_add_noise_at(
							str(item.get("owner", "neutral")),
							"留声机撞击",
							room["coord"],
							item["pos"],
							0.0,
							2.0,
							true,
						)


func _update_decoys(delta: float) -> void:
	if delta <= 0.0:
		return
	var decoys: Array = []
	for room in rooms:
		for item in room["items"]:
			if (
				not bool(item.get("collected", false))
				and str(item.get("kind", "")) == "device"
				and str(item.get("device_type", "")) == "decoy"
				and elapsed < float(item.get("expires", INF))
			):
				decoys.append(item)
	for decoy in decoys:
		var found := _find_device_entry(str(decoy.get("id", "")))
		if found.is_empty():
			continue
		var direction: Vector2 = decoy.get("move_direction", Vector2.ZERO)
		if direction.is_zero_approx():
			continue
		var room: Dictionary = found["room"]
		_move_robot_motion(
			decoy,
			room["coord"],
			direction.normalized() * DECOY_SPEED * delta,
		)


func _destroy_device_in_front(role: String, types: Array) -> bool:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var best: Dictionary = {}
	var best_distance := INF
	for item in room["items"]:
		if bool(item.get("collected", false)) or str(item.get("kind", "")) != "device":
			continue
		if not types.has(str(item.get("device_type", ""))):
			continue
		if str(item.get("owner", "")) == role:
			continue
		var offset: Vector2 = item["pos"] - actor["pos"]
		var distance := offset.length()
		if distance > SPRING_GLOVE_REACH or distance >= best_distance:
			continue
		if not offset.is_zero_approx() and offset.normalized().dot(facing) < 0.5:
			continue
		best = item
		best_distance = distance
	if best.is_empty():
		return false
	best["collected"] = true
	return true
