class_name ProfessionCatalog
extends RefCounted

const PROFESSION_DEFINITION := preload(
	"res://scripts/professions/profession_definition.gd"
)

const COLLECTOR := "collector"
const SCOUT := "scout"
const SUPPORT := "support"
const HAULER := "hauler"


static func all() -> Array:
	return [
		PROFESSION_DEFINITION.create(
			COLLECTOR,
			"收藏家",
			"monster",
			"看守宅邸与私人藏品的怪物职业。",
			"collector_trap",
			"trap_mastery",
		),
		PROFESSION_DEFINITION.create(
			SCOUT,
			"侦察者",
			"thief",
			"负责发现路线、危险与关键目标的盗贼职业。",
			"scout_echo_scan",
			"keen_hearing",
		),
		PROFESSION_DEFINITION.create(
			SUPPORT,
			"支援者",
			"thief",
			"负责协助队友维持行动能力的盗贼职业。",
			"support_first_aid",
			"rescue_training",
		),
		PROFESSION_DEFINITION.create(
			HAULER,
			"搬运者",
			"thief",
			"负责转移藏品并承担高风险运输的盗贼职业。",
			"hauler_sprint",
			"load_training",
		),
	]


static func find(profession_id: String) -> Resource:
	for definition in all():
		if definition.id == profession_id:
			return definition
	return null


static func for_slot(slot: String) -> Array:
	var role := role_for_slot(slot)
	var result: Array = []
	for definition in all():
		if definition.role == role:
			result.append(definition)
	return result


static func is_allowed(profession_id: String, slot: String) -> bool:
	var definition := find(profession_id)
	return definition != null and definition.role == role_for_slot(slot)


static func default_for_slot(slot: String) -> String:
	match slot:
		"monster":
			return COLLECTOR
		"thief-1":
			return SCOUT
		"thief-2":
			return SUPPORT
		"thief-3":
			return HAULER
	return ""


static func title_for(profession_id: String) -> String:
	var definition := find(profession_id)
	return definition.title if definition else "未选择"


static func role_for_slot(slot: String) -> String:
	if slot == "monster":
		return "monster"
	if slot.begins_with("thief-"):
		return "thief"
	return ""
