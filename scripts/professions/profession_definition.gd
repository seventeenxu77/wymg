class_name ProfessionDefinition
extends Resource

@export var id := ""
@export var title := ""
@export var role := ""
@export_multiline var description := ""


static func create(
	profession_id: String,
	profession_title: String,
	profession_role: String,
	profession_description: String,
) -> ProfessionDefinition:
	var definition := ProfessionDefinition.new()
	definition.id = profession_id
	definition.title = profession_title
	definition.role = profession_role
	definition.description = profession_description
	return definition
