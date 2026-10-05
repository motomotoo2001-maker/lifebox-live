class_name GoalState
extends RefCounted

const MAX_ACTIVE_GOALS := 3

var day_index: int = -1
var _goals: Array[DailyGoal] = []

func add_goal(goal: DailyGoal) -> bool:
	if goal == null or goal.id == &"":
		return false
	if _goals.size() >= MAX_ACTIVE_GOALS:
		return false
	if get_goal(goal.id) != null:
		return false
	_goals.append(goal)
	return true

func get_goal(goal_id: StringName) -> DailyGoal:
	for goal in _goals:
		if goal.id == goal_id:
			return goal
	return null

func active_goals() -> Array[DailyGoal]:
	return _goals.duplicate()

func clear_for_day(new_day_index: int) -> void:
	day_index = maxi(new_day_index, 0)
	_goals.clear()
