class_name GameModeCatalog
extends RefCounted

const MODE_DEFINITION := preload("res://scripts/modes/game_mode_definition.gd")

const LOCAL_DUEL := "local_duel"
const ONLINE_HUNT := "online_hunt"
const SOLO_ADVENTURE := "solo_adventure"
const TACTICAL := "tactical"


static func all() -> Array[GameModeDefinition]:
	return [
		MODE_DEFINITION.create(
			LOCAL_DUEL,
			"经典本地双人",
			"保留现有同键盘、双分屏与四局身份轮换玩法。",
			true,
			false,
		),
		MODE_DEFINITION.create(
			ONLINE_HUNT,
			"联机狩猎",
			"独立联机入口；当前开放大厅与本机连接框架。",
			true,
			true,
		),
		MODE_DEFINITION.create(
			SOLO_ADVENTURE,
			"单人冒险",
			"玩家与智能 AI 共同进入宅邸，后续开放。",
			false,
			false,
		),
		MODE_DEFINITION.create(
			TACTICAL,
			"回合战棋",
			"共享职业与世界观的独立回合模式，后续开放。",
			false,
			false,
		),
	]


static func find(mode_id: String) -> GameModeDefinition:
	for definition in all():
		if definition.id == mode_id:
			return definition
	return null
