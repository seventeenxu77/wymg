@tool
class_name GameplayStateFactory
extends RefCounted

# Transitional typed construction boundary for gameplay state.
#
# Runtime systems still consume Dictionary values, so these factories preserve
# the current public shape while centralizing defaults and validating inputs.
# Individual dictionaries can later be replaced by typed Resources without
# changing every caller at once.


static func actor(
	room: Vector2i,
	position: Vector2,
	direction: String,
	facing: Vector2,
	include_tutorial_fields := false
) -> Dictionary:
	assert(direction in ["up", "right", "down", "left"])
	var state := {
		"room": room,
		"pos": position,
		"dir": direction,
		"facing": facing,
		"impact_visual_offset": Vector2.ZERO,
		"hit_reaction_started_at": -10.0,
		"hit_reaction_direction": Vector2.ZERO,
		"attack_started_at": -10.0,
		"attack_ready_at": 0.0,
		"hit_stun_until": 0.0,
		"hit_invulnerable_until": 0.0,
		"downed": false,
		"rescue_progress": 0.0,
		"being_revived": false,
		"trapped": false,
		"trapped_started_at": -10.0,
		"trap_prompt": "",
		"trapped_by": "",
		"trap_escape_progress": 0,
		"trap_expected_left": true,
		"tools": [],
		"tool_selected": 0,
		"adrenaline_until": 0.0,
		"fatigue_until": 0.0,
		"teleport_started": -1.0,
		"teleport_ends": -1.0,
		"carried_loot": [],
		"carried_value": 0,
		"carried_weight": 0,
		"active_skill_ready_at": 0.0,
		"last_voice_at": -10.0,
		"hp": 2,
		"moving": false,
		"hidden_from_monster": false,
		"gm_force_visible": false,
		"last_moved_at": 0.0,
		"revealed_until": 0.0,
	}
	if include_tutorial_fields:
		state["downed"] = false
	return state


static func status_effects() -> Dictionary:
	return {
		"adrenaline_until": 0.0,
		"fatigue_until": 0.0,
		"stunned_until": 0.0,
		"teleport_started": -1.0,
		"teleport_ends": -1.0,
	}


static func tool(
	tool_type: String,
	id: String,
	definition: Dictionary,
	detector_battery_seconds: float
) -> Dictionary:
	assert(not tool_type.is_empty())
	assert(not id.is_empty())
	assert(definition.has("label"))
	var state := {
		"id": id,
		"kind": "tool",
		"tool_type": tool_type,
		"label": definition["label"],
		"value": 0,
	}
	match tool_type:
		"detector":
			state["charge"] = detector_battery_seconds
			state["active"] = false
			state["next_noise"] = 0.0
		"robot":
			state["deployed"] = false
			state["robot_id"] = ""
			state["stunned_until"] = 0.0
	return state


static func device(
	device_type: String,
	id: String,
	label: String,
	owner: String,
	position: Vector2,
	created_at: float
) -> Dictionary:
	assert(not device_type.is_empty())
	assert(not id.is_empty())
	assert(owner in ["monster", "thief"])
	return {
		"id": id,
		"kind": "device",
		"device_type": device_type,
		"label": label,
		"value": 0,
		"owner": owner,
		"pos": position,
		"collected": false,
		"created": created_at,
		"state": "active",
		"source": "tool",
	}
