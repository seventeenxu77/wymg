class_name NetworkToolCatalog
extends RefCounted

const GAME_STATE_BASE := preload("res://scripts/systems/game_state_base.gd")
const GAMEPLAY_STATE_FACTORY := preload("res://scripts/state/gameplay_state_factory.gd")

const SUPPORTED_TYPES := [
	"adrenaline",
	"decoy",
	"phonograph",
	"trap",
	"detector",
	"alarm",
	"teleporter",
	"spring_glove",
	"robot",
]
const MAX_LOADOUT_SIZE := 3


static func supports(tool_type: String) -> bool:
	return tool_type in SUPPORTED_TYPES


static func allowed_for_slot(tool_type: String, slot: String) -> bool:
	if not supports(tool_type):
		return false
	if slot == "monster":
		return tool_type != "teleporter"
	return slot in ["thief-1", "thief-2", "thief-3"]


static func is_valid_loadout(tool_types: Array, slot: String) -> bool:
	if tool_types.size() > MAX_LOADOUT_SIZE:
		return false
	var seen: Dictionary = {}
	for tool_type_variant in tool_types:
		var tool_type := str(tool_type_variant)
		if not allowed_for_slot(tool_type, slot) or seen.has(tool_type):
			return false
		seen[tool_type] = true
	return true


static func make_tool(tool_type: String, id: String) -> Dictionary:
	assert(supports(tool_type))
	return GAMEPLAY_STATE_FACTORY.tool(
		tool_type,
		id,
		GAME_STATE_BASE.TOOL_DEFS[tool_type],
		GAME_STATE_BASE.DETECTOR_BATTERY_SECONDS,
	)


static func type_index(tool_type: String) -> int:
	return SUPPORTED_TYPES.find(tool_type)


static func type_from_index(index: int) -> String:
	if index < 0 or index >= SUPPORTED_TYPES.size():
		return ""
	return str(SUPPORTED_TYPES[index])


static func test_loadout_for_slot(slot: String) -> Array[String]:
	match slot:
		"monster":
			return ["trap", "phonograph", "robot"]
		"thief-1":
			return ["adrenaline", "decoy", "detector"]
		"thief-2":
			return ["trap", "alarm", "spring_glove"]
		"thief-3":
			return ["phonograph", "teleporter", "robot"]
	return []
