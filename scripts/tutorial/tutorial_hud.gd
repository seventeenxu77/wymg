class_name TutorialHud
extends Node2D

const BG := Color("#0b0c0c")
const PANEL := Color("#171a17")
const PANEL_ALT := Color("#111312")
const LINE := Color("#454a43")
const TEXT := Color("#eee9dd")
const MUTED := Color("#979c94")
const GOLD := Color("#e6cc64")
const MONSTER := Color("#ff6b4a")
const THIEF := Color("#66d9c3")

var game: Node
var tutorial: Node
var font: Font


func setup(host: Node, tutorial_system: Node) -> void:
	game = host
	tutorial = tutorial_system
	font = ThemeDB.fallback_font
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	if tutorial and tutorial.active:
		queue_redraw()


func _draw() -> void:
	if not tutorial or not tutorial.active:
		return
	if bool(game.main_menu_open):
		return
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var margin := 10.0
	var gap := 10.0
	var panel_width := (size.x - margin * 2.0 - gap) / 2.0
	var left := Rect2(Vector2(margin, margin), Vector2(panel_width, size.y - margin * 2.0))
	var right := Rect2(Vector2(left.end.x + gap, margin), left.size)
	_draw_player_panel(left, "A")
	_draw_player_panel(right, "B")
	draw_rect(
		Rect2(Vector2(size.x * 0.5 - 2.0, 8.0), Vector2(4.0, size.y - 16.0)),
		Color("#32362f"),
	)
	if bool(game.gm_console_open):
		_draw_gm_console(size)


func _draw_player_panel(panel: Rect2, player: String) -> void:
	var session: Dictionary = tutorial.sessions[player]
	draw_rect(panel, PANEL)
	draw_rect(panel, LINE, false, 1.5)
	var mode := str(session.get("mode", "select"))
	if mode == "running":
		_draw_running(panel, player, session)
	elif mode == "ready":
		_draw_ready(panel, player, session)
	else:
		_draw_selection(panel, player, session)


func _draw_selection(panel: Rect2, player: String, session: Dictionary) -> void:
	var accent := THIEF if player == "A" else MONSTER
	_text("玩家 %s" % player, panel.position + Vector2(32, 42), 20, TEXT)
	_text("独立教学角色选择", panel.position + Vector2(32, 72), 12, MUTED)
	_multiline(
		str(session.get("message", "")),
		panel.position + Vector2(32, 108),
		panel.size.x - 64,
		12,
		TEXT,
		20,
	)
	var labels := ["盗贼教学", "怪物教学", "退出教学并准备"]
	var descriptions := [
		"家具搜查、静止隐匿、商店、道具与撤离",
		"藏品放置、追踪噪音、攻击、商店与道具",
		"清理当前教学资源，等待另一位玩家",
	]
	var rects: Array = []
	var start_y := panel.position.y + 200.0
	for index in range(labels.size()):
		var rect := Rect2(
			Vector2(panel.position.x + 42.0, start_y + index * 92.0),
			Vector2(panel.size.x - 84.0, 68.0),
		)
		rects.append(rect)
		var selected := int(session.get("selection", 0)) == index
		draw_rect(rect, Color("#2b302b") if selected else PANEL_ALT)
		draw_rect(rect, accent if selected else LINE, false, 2.0 if selected else 1.0)
		_text(labels[index], rect.position + Vector2(18, 27), 14, TEXT)
		_text(descriptions[index], rect.position + Vector2(18, 51), 10, MUTED)
	tutorial.selection_rects[player] = rects
	var status_y := panel.end.y - 112.0
	_text("本次启动完成记录", Vector2(panel.position.x + 42, status_y), 11, MUTED)
	var thief_done := bool(tutorial.completed[player]["thief"])
	var monster_done := bool(tutorial.completed[player]["monster"])
	_text(
		"盗贼 %s　　怪物 %s" % ["已完成" if thief_done else "未完成", "已完成" if monster_done else "未完成"],
		Vector2(panel.position.x + 42, status_y + 27),
		12,
		GOLD if thief_done or monster_done else TEXT,
	)
	var controls := "W/S 选择 · R 确认" if player == "A" else "↑/↓ 选择 · Num1 确认"
	_text_center(controls, Rect2(Vector2(panel.position.x, panel.end.y - 52), Vector2(panel.size.x, 24)), 11, accent)


func _draw_ready(panel: Rect2, player: String, session: Dictionary) -> void:
	var accent := THIEF if player == "A" else MONSTER
	var center := panel.get_center()
	_text_center("玩家 %s 已退出教学" % player, Rect2(center - Vector2(220, 100), Vector2(440, 34)), 22, TEXT)
	_text_center("等待另一位玩家退出教学后开始正式比赛", Rect2(center - Vector2(240, 48), Vector2(480, 28)), 12, MUTED)
	var button := Rect2(center + Vector2(-150, 30), Vector2(300, 52))
	draw_rect(button, Color("#272c27"))
	draw_rect(button, accent, false, 2)
	_text_center("取消准备，返回教学选择", button, 13, TEXT)
	tutorial.selection_rects[player] = [button]
	_text_center(
		"点击按钮，或按%s" % ("R" if player == "A" else "Num1"),
		Rect2(Vector2(panel.position.x, button.end.y + 14), Vector2(panel.size.x, 24)),
		10,
		MUTED,
	)


func _draw_running(panel: Rect2, player: String, session: Dictionary) -> void:
	var role := str(session["role"])
	var accent := MONSTER if role == "monster" else THIEF
	var renderer: World25D = session["renderer"]
	_text("玩家%s · %s教学" % [player, "怪物" if role == "monster" else "盗贼"], panel.position + Vector2(30, 35), 16, TEXT)
	var exit_button := Rect2(Vector2(panel.end.x - 158, panel.position.y + 14), Vector2(128, 34))
	draw_rect(exit_button, Color("#2b2523"))
	draw_rect(exit_button, Color("#d87766"), false, 1.5)
	_text_center("退出当前教程", exit_button, 11, Color("#f2b2a7"))
	tutorial.exit_rects[player] = exit_button

	var room_side := minf(panel.size.x - 44.0, panel.size.y - 224.0)
	var room_rect := Rect2(
		Vector2(panel.position.x + (panel.size.x - room_side) * 0.5, panel.position.y + 62.0),
		Vector2(room_side, room_side),
	)
	draw_rect(room_rect.grow(5), Color("#282b26"))
	if renderer:
		var texture := renderer.texture_for(role)
		if texture:
			draw_texture_rect(texture, room_rect, false)
	draw_rect(room_rect, accent, false, 1.5)
	_draw_room_progress(room_rect, session)
	_draw_world_prompt(room_rect, session)
	_draw_noise_prompt(room_rect, session)

	var objective_card := Rect2(
		Vector2(panel.position.x + 22.0, room_rect.end.y + 12.0),
		Vector2(panel.size.x - 44.0, panel.end.y - room_rect.end.y - 34.0),
	)
	draw_rect(objective_card, PANEL_ALT)
	draw_rect(objective_card, LINE, false, 1.0)
	_text("当前目标 · %s" % tutorial.objective_title(session), objective_card.position + Vector2(16, 26), 13, accent)
	_multiline(
		tutorial.objective_detail(player, session),
		objective_card.position + Vector2(16, 51),
		objective_card.size.x - 32,
		11,
		TEXT,
		19,
	)
	if str(session.get("message", "")) != "":
		_text(str(session["message"]), objective_card.position + Vector2(16, objective_card.size.y - 16), 9, Color("#ef9a7f"))
	if role == "thief":
		var hidden := bool((session["thief"] as Dictionary).get("hidden_from_monster", false))
		var state_rect := Rect2(Vector2(room_rect.end.x - 116, room_rect.position.y + 14), Vector2(98, 28))
		draw_rect(state_rect, Color(0.04, 0.05, 0.045, 0.88))
		draw_rect(state_rect, THIEF if hidden else LINE, false, 1.0)
		_text_center("已隐匿" if hidden else "可被发现", state_rect, 10, THIEF if hidden else MUTED)
	_draw_context_overlays(panel, room_rect, player, session)


func _draw_room_progress(room_rect: Rect2, session: Dictionary) -> void:
	var actor: Dictionary = session[str(session["role"])]
	var current_room := int((actor["room"] as Vector2i).x)
	var width := 150.0
	var rect := Rect2(room_rect.get_center().x - width * 0.5, room_rect.position.y + 12, width, 24)
	draw_rect(rect, Color(0.035, 0.04, 0.035, 0.88))
	var cell := width / 5.0
	for index in range(5):
		var cell_rect := Rect2(Vector2(rect.position.x + index * cell, rect.position.y), Vector2(cell, rect.size.y))
		draw_rect(cell_rect, GOLD if index == current_room else LINE, false, 1.0)
		_text_center(str(index + 1), cell_rect, 9, GOLD if index == current_room else MUTED)


func _draw_world_prompt(room_rect: Rect2, session: Dictionary) -> void:
	var objective := str(session["objective"])
	var target_room := Vector2i(-1, -1)
	var target_pos := Vector2.ZERO
	var label := ""
	match objective:
		"furniture":
			target_room = Vector2i(1, 0)
			target_pos = Vector2(2.5, 2.5)
			label = "教学家具"
		"shop_hit":
			target_room = Vector2i(3, 0)
			target_pos = Vector2(2.5, 2.5)
			label = "教学商店"
		"exit_hit":
			target_room = Vector2i(4, 0)
			target_pos = Vector2(2.5, 2.5)
			label = "教学出口"
	if label == "":
		return
	var actor: Dictionary = session[str(session["role"])]
	if actor["room"] != target_room:
		return
	var renderer: World25D = session["renderer"]
	var normalized := renderer.project_normalized(str(session["role"]), target_room, target_pos, 1.35)
	var center := room_rect.position + normalized * room_rect.size
	var pulse := 19.0 + sin(tutorial.elapsed * 7.0) * 4.0
	draw_arc(center, pulse, 0, TAU, 32, GOLD, 2.0)
	_text_center(label, Rect2(center + Vector2(-80, -48), Vector2(160, 22)), 11, GOLD)


func _draw_noise_prompt(room_rect: Rect2, session: Dictionary) -> void:
	if tutorial.elapsed >= float(session.get("noise_until", 0.0)):
		return
	var actor: Dictionary = session[str(session["role"])]
	if actor["room"] != Vector2i(2, 0):
		return
	var renderer: World25D = session["renderer"]
	var normalized := renderer.project_normalized(
		str(session["role"]),
		Vector2i(2, 0),
		session["noise_pos"],
		0.6,
	)
	var center := room_rect.position + normalized * room_rect.size
	var fade := clampf(float(session["noise_until"]) - tutorial.elapsed, 0.0, 1.0)
	for radius in [24.0, 39.0, 54.0]:
		draw_arc(center, radius, 0, TAU, 36, Color(GOLD, fade), 2.0)
	_text_center("噪音", Rect2(center + Vector2(-45, -72), Vector2(90, 20)), 10, Color(GOLD, fade))


func _draw_context_overlays(panel: Rect2, room_rect: Rect2, player: String, session: Dictionary) -> void:
	if bool(session["help_open"]):
		_draw_help_overlay(room_rect, player, str(session["role"]))
	if bool(session["panel_open"]):
		_draw_storage_overlay(room_rect, player, session)
	if bool(session["shop_open"]):
		_draw_shop_overlay(panel, player, session)


func _draw_help_overlay(room_rect: Rect2, player: String, role: String) -> void:
	var accent := MONSTER if role == "monster" else THIEF
	var card := room_rect.grow(-34)
	draw_rect(card, Color(0.025, 0.03, 0.025, 0.98))
	draw_rect(card, accent, false, 2)
	_text_center("帮助与完整键位", Rect2(card.position + Vector2(0, 20), Vector2(card.size.x, 28)), 19, TEXT)
	var controls := ""
	if player == "A":
		controls = (
			"WASD　移动\nQ / E　逆时针 / 顺时针旋转\nG　撞击家具\nR　拾取 / 面板存取\n"
			+ ("空格　攻击\n" if role == "monster" else "")
			+ "Z / X　选择道具\nF　使用道具\nF1 / Esc　关闭帮助"
		)
	else:
		controls = (
			"方向键　移动\nNum7 / Num9　逆时针 / 顺时针旋转\nNum0　撞击家具\nNum1　拾取 / 面板存取\n"
			+ ("Num2　攻击\n" if role == "monster" else "")
			+ "Num4 / Num6　选择道具\nNum3　使用道具\nNum+ / Esc　关闭帮助"
		)
	_multiline(controls, card.position + Vector2(42, 82), card.size.x - 84, 13, TEXT, 29)
	_text_center("正式比赛中，两位玩家会在四局内交替扮演怪物与盗贼。", Rect2(Vector2(card.position.x, card.end.y - 60), Vector2(card.size.x, 26)), 10, MUTED)


func _draw_storage_overlay(room_rect: Rect2, player: String, session: Dictionary) -> void:
	var card := Rect2(
		Vector2(room_rect.position.x + 34, room_rect.end.y - 180),
		Vector2(room_rect.size.x - 68, 146),
	)
	draw_rect(card, Color(0.035, 0.04, 0.035, 0.98))
	draw_rect(card, GOLD, false, 2)
	_text("家具面板", card.position + Vector2(18, 29), 14, GOLD)
	_text("随身藏品：银制烛台 · 价值2", card.position + Vector2(18, 61), 11, TEXT)
	_text("放入后总耐久：家具2 + 藏品附加2 = 4", card.position + Vector2(18, 87), 11, TEXT)
	_text_center(
		"按%s放入藏品" % ("R" if player == "A" else "Num1"),
		Rect2(Vector2(card.position.x, card.end.y - 38), Vector2(card.size.x, 22)),
		11,
		GOLD,
	)


func _draw_shop_overlay(panel: Rect2, player: String, session: Dictionary) -> void:
	var card := panel.grow(-26)
	draw_rect(card, Color(0.025, 0.03, 0.025, 0.99))
	draw_rect(card, GOLD, false, 2)
	_text("教学商店 · %d金币" % int(session["shop_coins"]), card.position + Vector2(24, 34), 17, TEXT)
	_text("购买后先进入仓库，再从仓库放入装备栏。教学资源不会带入正式比赛。", card.position + Vector2(24, 61), 10, MUTED)
	var gap := 10.0
	var column_width := (card.size.x - 68.0 - gap * 2.0) / 3.0
	var columns := ["商品", "仓库", "装备栏"]
	for index in range(3):
		var rect := Rect2(
			Vector2(card.position.x + 24 + index * (column_width + gap), card.position.y + 92),
			Vector2(column_width, card.size.y - 180),
		)
		var focused := int(session["shop_focus"]) == index
		draw_rect(rect, PANEL_ALT)
		draw_rect(rect, GOLD if focused else LINE, false, 2.0 if focused else 1.0)
		_text_center(columns[index], Rect2(rect.position, Vector2(rect.size.x, 38)), 12, GOLD if focused else TEXT)
		var item_text := ""
		if index == 0:
			item_text = "肾上腺素\n价格：2\n6秒双倍速度\n随后3秒半速疲劳"
		elif index == 1:
			item_text = "肾上腺素" if bool(session["shop_owned"]) else "空"
		else:
			item_text = "肾上腺素" if bool(session["shop_equipped"]) else "空"
		_multiline(item_text, rect.position + Vector2(16, 66), rect.size.x - 32, 11, TEXT, 22)
	var controls := (
		"A/D 切换栏位 · R 购买/装备 · H 准备"
		if player == "A"
		else "Num4/6 切换栏位 · Num1 购买/装备 · Num5 准备"
	)
	_text_center(controls, Rect2(Vector2(card.position.x, card.end.y - 58), Vector2(card.size.x, 24)), 11, GOLD)


func _draw_gm_console(size: Vector2) -> void:
	var width := minf(size.x - 40.0, 1040.0)
	var card := Rect2(Vector2((size.x - width) * 0.5, size.y - 178.0), Vector2(width, 158.0))
	draw_rect(card, Color(0.015, 0.018, 0.015, 0.99))
	draw_rect(card, Color("#86e36f"), false, 2.0)
	_text("GM CONSOLE", card.position + Vector2(12, 23), 12, Color("#86e36f"))
	_text_right("~ / Esc 关闭", card.position + Vector2(card.size.x - 12, 23), 10, MUTED)
	_text(str(game.gm_output), card.position + Vector2(14, 56), 11, TEXT)
	var input_rect := Rect2(Vector2(card.position.x + 12, card.end.y - 38), Vector2(card.size.x - 24, 27))
	draw_rect(input_rect, Color("#090b09"))
	draw_rect(input_rect, Color("#456d43"), false, 1.0)
	_text("> " + str(game.gm_command) + "▌", input_rect.position + Vector2(8, 19), 12, Color("#b8f0ae"))


func _text(value: String, position: Vector2, size: int, color := TEXT) -> void:
	draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(value: String, position: Vector2, size: int, color := TEXT) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(value, Vector2(position.x - width, position.y), size, color)


func _text_center(value: String, rect: Rect2, size: int, color := TEXT) -> void:
	var dimensions := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_text(
		value,
		Vector2(rect.get_center().x - dimensions.x * 0.5, rect.get_center().y + dimensions.y * 0.34),
		size,
		color,
	)


func _multiline(value: String, position: Vector2, width: float, size: int, color: Color, line_height: float) -> void:
	var lines := value.split("\n")
	var y := position.y
	for raw_line in lines:
		var paragraph := str(raw_line)
		if paragraph.is_empty():
			y += line_height
			continue
		var line := ""
		for index in range(paragraph.length()):
			var character := paragraph.substr(index, 1)
			var candidate := line + character
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
				_text(line, Vector2(position.x, y), size, color)
				y += line_height
				line = character
			else:
				line = candidate
		if line != "":
			_text(line, Vector2(position.x, y), size, color)
			y += line_height
