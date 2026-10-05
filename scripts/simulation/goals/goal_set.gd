class_name GoalSet
extends RefCounted

const MAX_ACTIVE_GOALS := 3

var _goals: Array[GoalState] = []

func add(goal: GoalState) -> bool:
	if goal == null or goal.definition == null:
		return false
	if not goal.definition.validate().is_empty():
		return false
	if get_goal(goal.definition.id) != null:
		return false
	if goal.is_active() and active_goals().size() >= MAX_ACTIVE_GOALS:
		return false

	_goals.append(goal)
	return true

func goals() -> Array[GoalState]:
	return _goals.duplicate()

func active_goals() -> Array[GoalState]:
	var active: Array[GoalState] = []
	for goal in _goals:
		if goal != null and goal.is_active():
			active.append(goal)
	return active

func get_goal(goal_id: StringName) -> GoalState:
	for goal in _goals:
		if goal != null and goal.definition != null and goal.definition.id == goal_id:
			return goal
	return null
