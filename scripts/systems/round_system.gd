@tool
class_name RoundSystem
extends "res://scripts/systems/audio_system.gd"

func _player_for_role(role: String) -> String:
	# Existing @tool scene instances can keep Nil for newly added members after
	# a script hot reload. Coerce that transient editor value to round one so
	# the inspector redraw does not emit the same error every frame.
	var round_number := maxi(int(current_round), 1)
	var player_a_is_monster := round_number % 2 == 1
	if role == "monster":
		return "A" if player_a_is_monster else "B"
	return "B" if player_a_is_monster else "A"


func _role_for_player(player: String) -> String:
	return "monster" if _player_for_role("monster") == player else "thief"


func _take_loadout_for_round(player: String) -> Array:
	var carried: Array = []
	var stash: Array = player_stashes[player]
	var valid_loadout: Array = []
	for item_id in player_loadouts[player]:
		for index in range(stash.size()):
			var tool: Dictionary = stash[index]
			if str(tool.get("id", "")) != str(item_id):
				continue
			tool["active"] = false
			carried.append(tool)
			valid_loadout.append(str(item_id))
			stash.remove_at(index)
			break
		if carried.size() >= TOOL_INVENTORY_CAPACITY:
			break
	player_loadouts[player] = valid_loadout
	return carried


func _handle_shop_input(key: Key, physical: Key) -> void:
	var player := ""
	var action := ""
	if physical == KEY_W:
		player = "A"
		action = "previous"
	elif physical == KEY_S:
		player = "A"
		action = "next"
	elif physical == KEY_A:
		player = "A"
		action = "focus_left"
	elif physical == KEY_D:
		player = "A"
		action = "focus_right"
	elif physical == KEY_R:
		player = "A"
		action = "activate"
	elif physical == KEY_H:
		player = "A"
		action = "ready"
	elif key == KEY_UP:
		player = "B"
		action = "previous"
	elif key == KEY_DOWN:
		player = "B"
		action = "next"
	elif key == KEY_KP_4:
		player = "B"
		action = "focus_left"
	elif key == KEY_KP_6:
		player = "B"
		action = "focus_right"
	elif key == KEY_KP_1:
		player = "B"
		action = "activate"
	elif key == KEY_KP_5:
		player = "B"
		action = "ready"
	if player == "":
		return
	if action == "previous":
		_move_shop_selection(player, -1)
	elif action == "next":
		_move_shop_selection(player, 1)
	elif action == "focus_left":
		_move_shop_focus(player, -1)
	elif action == "focus_right":
		_move_shop_focus(player, 1)
	elif action == "activate":
		_activate_shop_focus(player)
	else:
		shop_ready[player] = not bool(shop_ready[player])
	if bool(shop_ready["A"]) and bool(shop_ready["B"]):
		current_round += 1
		_start_round()


func _move_shop_focus(player: String, direction: int) -> void:
	var columns := ["products", "warehouse", "loadout"]
	var current_index := columns.find(str(shop_focus[player]))
	shop_focus[player] = columns[posmod(current_index + direction, columns.size())]
	shop_ready[player] = false


func _move_shop_selection(player: String, direction: int) -> void:
	match str(shop_focus[player]):
		"warehouse":
			var items := _shop_warehouse_items(player)
			warehouse_selected[player] = (
				posmod(int(warehouse_selected[player]) + direction, items.size())
				if not items.is_empty() else 0
			)
		"loadout":
			var items := _shop_equipped_items(player)
			loadout_selected[player] = (
				posmod(int(loadout_selected[player]) + direction, items.size())
				if not items.is_empty() else 0
			)
		_:
			shop_selected[player] = posmod(int(shop_selected[player]) + direction, SHOP_TOOL_TYPES.size())
	shop_ready[player] = false


func _activate_shop_focus(player: String) -> void:
	match str(shop_focus[player]):
		"warehouse":
			_equip_selected_warehouse_item(player)
		"loadout":
			_unequip_selected_loadout_item(player)
		_:
			_buy_selected_shop_tool(player)


func _execute_gm_command(command_line: String) -> void:
	gm_history.push_front("> " + command_line)
	if gm_history.size() > 4:
		gm_history.resize(4)
	var parts := command_line.split(" ", false)
	if parts.is_empty():
		return
	var command := str(parts[0]).to_lower()
	match command:
		"next":
			_gm_next_stage()
		"help":
			gm_output = "next 下一阶段｜gold A 50 加金币｜give A adrenaline 发道具｜~ / Esc 关闭"
		"gold":
			if parts.size() != 3 or str(parts[1]).to_upper() not in ["A", "B"] or not str(parts[2]).is_valid_int():
				gm_output = "用法：gold A 50"
				return
			var player := str(parts[1]).to_upper()
			var amount := int(parts[2])
			player_coins[player] = maxi(int(player_coins.get(player, 0)) + amount, 0)
			gm_output = "玩家%s金币已调整为 %d。" % [player, player_coins[player]]
		"give":
			if parts.size() != 3:
				gm_output = "用法：give A adrenaline"
				return
			_gm_give_tool(str(parts[1]).to_upper(), str(parts[2]).to_lower())
		_:
			gm_output = "未知命令：%s。输入 help 查看命令。" % command


func _gm_next_stage() -> void:
	match phase:
		"hide":
			_begin_hunt_countdown()
			_enter_hunt()
			gm_output = "已跳过藏宝倒计时，进入第%d局追杀阶段。" % current_round
		"ready":
			_enter_hunt()
			gm_output = "已跳过准备倒计时，进入第%d局追杀阶段。" % current_round
		"hunt":
			_end_round("GM结束了本局，盗贼财物未撤离。", false, true)
			if current_round < MATCH_ROUNDS:
				_advance_from_result()
				gm_output = "第%d局已结束，进入局间商店。" % current_round
			else:
				gm_output = "第四局已结束，进入最终结算。"
		"ended":
			if current_round >= MATCH_ROUNDS:
				gm_output = "四局比赛已经结束。"
			else:
				_advance_from_result()
				gm_output = "已进入第%d局后的局间商店。" % current_round
		"shop":
			if current_round >= MATCH_ROUNDS:
				gm_output = "四局比赛已经结束。"
				return
			current_round += 1
			_start_round()
			gm_output = "已进入第%d局藏宝阶段。" % current_round
		_:
			gm_output = "当前阶段无法使用 next。"


func _gm_give_tool(player: String, tool_type: String) -> void:
	if player not in ["A", "B"]:
		gm_output = "玩家只能填写 A 或 B。"
		return
	if not TOOL_DEFS.has(tool_type):
		gm_output = "无效道具。可用：%s" % "、".join(SHOP_TOOL_TYPES)
		return
	var id := "gm-%s-%d" % [player, next_device_id]
	next_device_id += 1
	var tool := _make_tool_instance(tool_type, id)
	if phase in ["hide", "ready", "hunt"]:
		var role := _role_for_player(player)
		var inventory: Array = tool_inventories[role]
		if inventory.size() >= TOOL_INVENTORY_CAPACITY:
			gm_output = "玩家%s当前道具栏已满。" % player
			return
		inventory.append(tool)
		tool_selected[role] = inventory.size() - 1
		gm_output = "已将%s放入玩家%s当前道具栏。" % [TOOL_DEFS[tool_type]["label"], player]
		return
	(player_stashes[player] as Array).append(tool)
	if (player_loadouts[player] as Array).size() < TOOL_INVENTORY_CAPACITY:
		(player_loadouts[player] as Array).append(id)
	gm_output = "已将%s放入玩家%s仓库。" % [TOOL_DEFS[tool_type]["label"], player]


func _selected_shop_tool_type(player: String) -> String:
	return str(SHOP_TOOL_TYPES[clampi(int(shop_selected[player]), 0, SHOP_TOOL_TYPES.size() - 1)])


func _buy_selected_shop_tool(player: String) -> void:
	var tool_type := _selected_shop_tool_type(player)
	var price := int(TOOL_DEFS[tool_type]["price"])
	if int(player_coins[player]) < price:
		_push_log("玩家%s金币不足，无法购买%s。" % [player, TOOL_DEFS[tool_type]["label"]])
		return
	player_coins[player] = int(player_coins[player]) - price
	var id := "shop-%s-%d" % [player, next_device_id]
	next_device_id += 1
	var tool := _make_tool_instance(tool_type, id)
	(player_stashes[player] as Array).append(tool)
	warehouse_selected[player] = maxi(_shop_warehouse_items(player).size() - 1, 0)
	_push_log("玩家%s购买了%s，已放入仓库。" % [player, TOOL_DEFS[tool_type]["label"]])
	shop_ready[player] = false


func _shop_warehouse_items(player: String) -> Array:
	var result: Array = []
	var loadout: Array = player_loadouts[player]
	for tool in player_stashes[player]:
		if not loadout.has(str(tool.get("id", ""))):
			result.append(tool)
	return result


func _shop_equipped_items(player: String) -> Array:
	var result: Array = []
	var stash: Array = player_stashes[player]
	for equipped_id in player_loadouts[player]:
		for tool in stash:
			if str(tool.get("id", "")) == str(equipped_id):
				result.append(tool)
				break
	return result


func _equip_selected_warehouse_item(player: String) -> void:
	var loadout: Array = player_loadouts[player]
	if loadout.size() >= TOOL_INVENTORY_CAPACITY:
		_push_log("玩家%s的出战栏已满（最多3件）。" % player)
		return
	var available := _shop_warehouse_items(player)
	if available.is_empty():
		_push_log("玩家%s的仓库中没有未装备道具。" % player)
		return
	var index := clampi(int(warehouse_selected[player]), 0, available.size() - 1)
	var tool: Dictionary = available[index]
	loadout.append(str(tool["id"]))
	warehouse_selected[player] = mini(index, maxi(_shop_warehouse_items(player).size() - 1, 0))
	loadout_selected[player] = loadout.size() - 1
	_push_log("玩家%s装备了%s。" % [player, TOOL_DEFS[str(tool["tool_type"])]["label"]])
	shop_ready[player] = false


func _unequip_selected_loadout_item(player: String) -> void:
	var equipped := _shop_equipped_items(player)
	if equipped.is_empty():
		_push_log("玩家%s的装备栏是空的。" % player)
		return
	var index := clampi(int(loadout_selected[player]), 0, equipped.size() - 1)
	var tool: Dictionary = equipped[index]
	(player_loadouts[player] as Array).erase(str(tool["id"]))
	loadout_selected[player] = mini(index, maxi(_shop_equipped_items(player).size() - 1, 0))
	warehouse_selected[player] = maxi(_shop_warehouse_items(player).size() - 1, 0)
	_push_log("玩家%s卸下了%s，已放回仓库。" % [player, TOOL_DEFS[str(tool["tool_type"])]["label"]])
	shop_ready[player] = false


func _toggle_selected_shop_tool(player: String) -> void:
	# Compatibility entry point for older tests/tools: explicitly equip the
	# selected warehouse item rather than coupling equipment to product choice.
	_equip_selected_warehouse_item(player)


func _return_round_tools_to_stashes() -> void:
	for role in ["monster", "thief"]:
		var player := _player_for_role(role)
		for tool in tool_inventories[role]:
			tool["active"] = false
			(player_stashes[player] as Array).append(tool)
		tool_inventories[role] = []
	for player in ["A", "B"]:
		var available_ids: Dictionary = {}
		for tool in player_stashes[player]:
			available_ids[str(tool.get("id", ""))] = true
		var valid: Array = []
		for id in player_loadouts[player]:
			if available_ids.has(str(id)) and valid.size() < TOOL_INVENTORY_CAPACITY:
				valid.append(str(id))
		player_loadouts[player] = valid


func _monster_treasure_value() -> int:
	var total := 0
	for treasure in TREASURES:
		total += int(treasure["value"])
	return total


func _end_round(reason: String, thief_escaped: bool, monster_victory := false) -> void:
	if phase == "ended" or phase == "shop" or phase == "match_ended":
		return
	has_extracted = thief_escaped
	extracted_value = loot_value if thief_escaped else 0
	var monster_player := _player_for_role("monster")
	var thief_player := _player_for_role("thief")
	var monster_coins := _monster_treasure_value() * COINS_PER_LOOT_VALUE
	var thief_coins := extracted_value * COINS_PER_LOOT_VALUE
	round_awards = {"A": 0, "B": 0}
	round_awards[monster_player] = monster_coins
	round_awards[thief_player] = thief_coins
	for player in ["A", "B"]:
		player_coins[player] = int(player_coins[player]) + int(round_awards[player])
		match_totals[player] = int(match_totals[player]) + int(round_awards[player])
	_return_round_tools_to_stashes()
	phase = "ended"
	outcome = (
		"%s\n玩家%s（怪物）获得 %d 金币；玩家%s（盗贼）获得 %d 金币。"
		% [reason, monster_player, monster_coins, thief_player, thief_coins]
	)
	if monster_victory:
		_play_sound("monster_win", -8.0, 0.5)


func _advance_from_result() -> void:
	if phase != "ended":
		return
	if current_round >= MATCH_ROUNDS:
		new_game()
		return
	phase = "shop"
	shop_ready = {"A": false, "B": false}
	shop_selected = {"A": 0, "B": 0}
	shop_focus = {"A": "products", "B": "products"}
	warehouse_selected = {"A": 0, "B": 0}
	loadout_selected = {"A": 0, "B": 0}
	logs = ["局间商店开启：购买只进入仓库，再从仓库选择至多3件装备。"]
	result_restart_rect = Rect2()


func _begin_hunt_countdown() -> void:
	if phase != "hide":
		return
	phase = "ready"
	seconds_left = 5
	phase_clock = 0.0
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
	for role in ["monster", "thief"]:
		for tool in tool_inventories[role]:
			if str(tool.get("tool_type", "")) == "detector":
				tool["active"] = false
	_push_log("藏宝结束：双方已回到起点，5 秒后正式开始。")


func _enter_hunt() -> void:
	if phase != "ready":
		return
	var unplaced := 0
	for treasure in TREASURES:
		if not _treasure_is_in_world(str(treasure["id"])):
			var furniture := _random_intact_furniture()
			if not furniture.is_empty():
				furniture["contents"].append((treasure as Dictionary).duplicate(true))
				_refresh_furniture_durability(furniture)
			unplaced += 1
	phase = "hunt"
	seconds_left = HUNT_SECONDS
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
	last_afterimage_at = -10.0
	stomach_clock = 15.0
	if unplaced > 0:
		_push_log("搜查开始：%d 件未存放藏品已自动放入家具。" % unplaced)
	else:
		_push_log("搜查开始：怪物与盗贼已回到各自起点。")


func _treasure_is_in_world(treasure_id: String) -> bool:
	for room in rooms:
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content["id"]) == treasure_id:
					return true
		for item in room["items"]:
			if str(item["id"]) == treasure_id and not bool(item["collected"]):
				return true
	return false


func _random_intact_furniture() -> Dictionary:
	var candidates: Array = []
	for room in rooms:
		for furniture in room["furniture"]:
			if not bool(furniture["destroyed"]) and not _furniture_has_primary_content(furniture):
				candidates.append(furniture)
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)]
