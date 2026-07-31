class_name SkillCatalog
extends RefCounted

const SKILL_DEFINITION := preload("res://scripts/skills/skill_definition.gd")

const COLLECTOR_TRAP := "collector_trap"
const TRAP_MASTERY := "trap_mastery"
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
