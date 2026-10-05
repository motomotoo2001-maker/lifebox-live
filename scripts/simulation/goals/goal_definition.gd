class_name GoalDefinition
extends Resource

@export var id: StringName = &""
@export var category: StringName = &""
@export var preferred_action_tags: Array[StringName] = []
@export var priority: float = 0.5
@export var target_resident_id: StringName = &""

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("goal id must not be empty")
	if category == &"":
		errors.append("goal category must not be empty")
	if is_nan(priority) or is_inf(priority) or priority < 0.0 or priority > 1.0:
		errors.append("goal priority must be finite and inside 0..1")

	if preferred_action_tags.is_empty():
		errors.append("goal preferred_action_tags must not be empty")
	else:
		var seen: Dictionary = {}
		for tag in preferred_action_tags:
			if tag == &"":
				errors.append("goal action tag must not be empty")
			elif seen.has(tag):
				errors.append("duplicate goal action tag: %s" % tag)
			else:
				seen[tag] = true

	return errors
