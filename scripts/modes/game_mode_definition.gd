class_name GameModeDefinition
extends Resource

var id: String
var title: String
var description: String
var available: bool
var networked: bool


static func create(
	mode_id: String,
	mode_title: String,
	mode_description: String,
	is_available: bool,
	is_networked: bool
) -> GameModeDefinition:
	var definition := GameModeDefinition.new()
	definition.id = mode_id
	definition.title = mode_title
	definition.description = mode_description
	definition.available = is_available
	definition.networked = is_networked
	return definition
