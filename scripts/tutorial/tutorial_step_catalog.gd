class_name TutorialStepCatalog
extends RefCounted

const OBJECTIVE_ORDER := [
	"help",
	"basics",
	"enter_room_2",
	"furniture",
	"enter_room_3",
	"challenge",
	"enter_room_4",
	"shop_hit",
	"shop",
	"use_tool",
	"enter_room_5",
	"exit_hit",
]


static func title(objective: String, role: String) -> String:
	match objective:
		"help": return "打开帮助菜单"
		"basics": return "移动与旋转视角"
		"enter_room_2": return "进入第二个房间"
		"furniture": return "学习家具与藏品"
		"enter_room_3": return "进入第三个房间"
		"challenge": return "潜行练习" if role == "thief" else "追击练习"
		"enter_room_4": return "进入第四个房间"
		"shop_hit": return "打开教学商店"
		"shop": return "购买并装备肾上腺素"
		"use_tool": return "使用肾上腺素"
		"enter_room_5": return "进入第五个房间"
		"exit_hit": return "离开教学"
	return "教学"
