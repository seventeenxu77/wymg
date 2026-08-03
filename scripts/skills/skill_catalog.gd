class_name SkillCatalog
extends RefCounted

const SKILL_DEFINITION := preload("res://scripts/skills/skill_definition.gd")

const COLLECTOR_TRAP := "collector_trap"
const TRAP_MASTERY := "trap_mastery"
const SCOUT_ECHO_SCAN := "scout_echo_scan"
const KEEN_HEARING := "keen_hearing"
const SUPPORT_FIRST_AID := "support_first_aid"
const RESCUE_TRAINING := "rescue_training"
const HAULER_SPRINT := "hauler_sprint"
const LOAD_TRAINING := "load_training"


static func all() -> Array:
	return [
		SKILL_DEFINITION.create(
			COLLECTOR_TRAP,
			"布置机关",
			"collector",
			"active",
			15.0,
			3,
			"放置不占用道具栏的捕兽夹；第四个夹子会替换最早放置的技能夹子。",
		),
		SKILL_DEFINITION.create(
			TRAP_MASTERY,
			"机关主人",
			"collector",
			"passive",
			0.0,
			0,
			"收藏家不会触发自己通过职业技能放置的捕兽夹。",
		),
		SKILL_DEFINITION.create(
			SCOUT_ECHO_SCAN,
			"回声勘察",
			"scout",
			"active",
			20.0,
			0,
			"扫描当前与相邻房间 5 秒，并显示怪物最近一次噪音所在房间。",
			5.0,
		),
		SKILL_DEFINITION.create(
			KEEN_HEARING,
			"敏锐听觉",
			"scout",
			"passive",
			0.0,
			0,
			"敌方噪音提示额外保留 1 秒。",
			1.0,
		),
		SKILL_DEFINITION.create(
			SUPPORT_FIRST_AID,
			"紧急包扎",
			"support",
			"active",
			35.0,
			0,
			"在受伤队友附近按住技能键完成包扎，恢复 1 点生命。",
			0.0,
			1.2,
			1.2,
			20.0,
		),
		SKILL_DEFINITION.create(
			RESCUE_TRAINING,
			"救援训练",
			"support",
			"passive",
			0.0,
			0,
			"救援时间缩短至 1.75 秒，并延长被救队友的短暂无敌。",
		),
		SKILL_DEFINITION.create(
			HAULER_SPRINT,
			"卸重疾行",
			"hauler",
			"active",
			26.0,
			0,
			"5 秒内忽略负重减速，但无法潜行并持续制造脚步噪音。",
			5.0,
		),
		SKILL_DEFINITION.create(
			LOAD_TRAINING,
			"负重训练",
			"hauler",
			"passive",
			0.0,
			0,
			"负重造成的速度惩罚减半，最低负重速度提高到正常速度的 75%。",
		),
	]


static func find(skill_id: String) -> Resource:
	for definition in all():
		if definition.id == skill_id:
			return definition
	return null
