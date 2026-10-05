class_name GoalSet
extends RefCounted

const MAX_ACTIVE_GOALS := 3

var day_index: int = -1
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


func begin_day(new_day_index: int) -> bool:
	if new_day_index < 0 or new_day_index <= day_index:
		return false

	for goal in _goals:
		if goal != null and goal.is_active():
			goal.fail()
	_goals.clear()
	day_index = new_day_index
	return true
