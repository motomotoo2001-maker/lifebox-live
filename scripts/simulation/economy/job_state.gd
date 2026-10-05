class_name JobState
extends RefCounted

var definition: JobDefinition = null
var total_worked_sim_seconds: float = 0.0

func assign(new_definition: JobDefinition) -> void:
	definition = new_definition
	total_worked_sim_seconds = 0.0
