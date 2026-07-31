class_name SkillDefinition
extends Resource

@export var id := ""
@export var title := ""
@export var profession_id := ""
@export_enum("active", "passive") var kind := "passive"
@export var cooldown := 0.0
@export var max_deployments := 0
@export_multiline var description := ""


static func create(
	skill_id: String,
	skill_title: String,
	owner_profession_id: String,
	skill_kind: String,
	skill_cooldown: float,
	skill_max_deployments: int,
	skill_description: String,
) -> Resource:
	assert(skill_kind in ["active", "passive"])
	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.title = skill_title
	definition.profession_id = owner_profession_id
	definition.kind = skill_kind
	definition.cooldown = skill_cooldown
	definition.max_deployments = skill_max_deployments
	definition.description = skill_description
	return definition
