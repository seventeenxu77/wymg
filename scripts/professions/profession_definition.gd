class_name ProfessionDefinition
extends Resource

@export var id := ""
@export var title := ""
@export var role := ""
@export_multiline var description := ""
@export var active_skill_id := ""
@export var passive_skill_id := ""


static func create(
	profession_id: String,
	profession_title: String,
	profession_role: String,
	profession_description: String,
	profession_active_skill_id := "",
	profession_passive_skill_id := "",
) -> ProfessionDefinition:
	var definition := ProfessionDefinition.new()
	definition.id = profession_id
	definition.title = profession_title
	definition.role = profession_role
	definition.description = profession_description
	definition.active_skill_id = profession_active_skill_id
	definition.passive_skill_id = profession_passive_skill_id
	return definition
