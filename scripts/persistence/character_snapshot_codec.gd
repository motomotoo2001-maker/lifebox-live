class_name CharacterSnapshotCodec
extends RefCounted

const NEED_NAMES: Array[String] = [
	"hunger", "energy", "hygiene", "comfort", "social", "mood",
]
const TRAIT_NAMES: Array[String] = [
	"sociability", "neatness", "ambition", "kindness",
	"impulsiveness", "confidence", "humor", "jealousy",
]

static func encode(character: CharacterState) -> Dictionary:
	if character == null:
		return {}

	var needs: Dictionary = {}
	for need_name in NEED_NAMES:
		var need_state = character.needs.get(need_name)
		needs[need_name] = {
			"value": need_state.value,
			"decay_per_sim_hour": need_state.decay_per_sim_hour,
		}

	var personality: Dictionary = {}
	for trait_name in TRAIT_NAMES:
		personality[trait_name] = character.personality.get(trait_name)

	var events: Array = []
	for event in character.memory.events():
		var related_ids: Array = []
		for resident_id in event.related_resident_ids:
			related_ids.append(str(resident_id))
		events.append({
			"event_id": str(event.event_id),
			"kind": str(event.kind),
			"simulation_seconds": event.simulation_seconds,
			"related_resident_ids": related_ids,
			"valence": event.valence,
			"importance": event.importance,
		})

	var job_definition = null
	if character.job.definition != null:
		job_definition = {
			"id": str(character.job.definition.id),
			"pay_per_sim_hour": character.job.definition.pay_per_sim_hour,
			"shift_start_hour": character.job.definition.shift_start_hour,
			"shift_duration_hours": character.job.definition.shift_duration_hours,
		}

	return {
		"id": str(character.id),
		"display_name": character.display_name,
		"money": character.money,
		"needs": needs,
		"personality": personality,
		"memory": {
			"capacity": character.memory.capacity,
			"events": events,
		},
		"job": {
			"definition": job_definition,
			"total_worked_sim_seconds": character.job.total_worked_sim_seconds,
		},
		"schedule": _encode_schedule(character),
		"goals": _encode_goals(character),
	}

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	_validate_identity(data, errors)
	_validate_money(data, errors)
	_validate_needs(data, errors)
	_validate_personality(data, errors)
	_validate_memory(data, errors)
	_validate_job(data, errors)
	_validate_schedule(data, errors)
	_validate_goals(data, errors)

	return errors

static func decode_stable_state(data: Dictionary) -> CharacterState:
	if not validate(data).is_empty():
		return null

	var character := CharacterState.new(
		StringName(data["id"]),
		data["display_name"]
	)
	character.money = float(data["money"])

	var needs: Dictionary = data["needs"]
	for need_name in NEED_NAMES:
		var encoded_need: Dictionary = needs[need_name]
		var need_state = character.needs.get(need_name)
		need_state.value = float(encoded_need["value"])
		need_state.decay_per_sim_hour = float(encoded_need["decay_per_sim_hour"])

	var personality: Dictionary = data["personality"]
	for trait_name in TRAIT_NAMES:
		character.personality.set(trait_name, float(personality[trait_name]))

	var memory_data: Dictionary = data["memory"]
	character.memory.capacity = int(memory_data["capacity"])
	for encoded_event in memory_data["events"]:
		var related_ids: Array = []
		for resident_id in encoded_event["related_resident_ids"]:
			related_ids.append(StringName(resident_id))

		var event := MemoryEvent.new(
			StringName(encoded_event["event_id"]),
			StringName(encoded_event["kind"]),
			float(encoded_event["simulation_seconds"]),
			related_ids,
			float(encoded_event["valence"]),
			float(encoded_event["importance"])
		)
		if not character.memory.add(event):
			return null

	var job_data: Dictionary = data["job"]
	var definition_data = job_data["definition"]
	if definition_data != null:
		var definition := JobDefinition.new()
		definition.id = StringName(definition_data["id"])
		definition.pay_per_sim_hour = float(definition_data["pay_per_sim_hour"])
		definition.shift_start_hour = float(definition_data["shift_start_hour"])
		definition.shift_duration_hours = float(definition_data["shift_duration_hours"])
		character.job.assign(definition)
	character.job.total_worked_sim_seconds = float(job_data["total_worked_sim_seconds"])

	if data.has("schedule"):
		_decode_schedule(character, data["schedule"])
	if data.has("goals"):
		if not _decode_goals(character, data["goals"]):
			return null

	return character

static func _validate_identity(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("id") or not data["id"] is String or data["id"].is_empty():
		errors.append("resident id must be a non-empty string")
	if not data.has("display_name") or not data["display_name"] is String:
		errors.append("display_name must be a string")

static func _validate_money(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("money") or not _is_finite_number(data["money"]):
		errors.append("money must be a finite number")
		return
	if float(data["money"]) < 0.0:
		errors.append("money must be non-negative")

static func _validate_needs(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("needs") or not data["needs"] is Dictionary:
		errors.append("needs must be a Dictionary")
		return

	var needs: Dictionary = data["needs"]
	for need_name in NEED_NAMES:
		if not needs.has(need_name) or not needs[need_name] is Dictionary:
			errors.append("need %s must be a Dictionary" % need_name)
			continue

		var need_data: Dictionary = needs[need_name]
		if not need_data.has("value") or not _is_finite_number(need_data["value"]):
			errors.append("need %s value must be finite" % need_name)
		else:
			var value := float(need_data["value"])
			if value < 0.0 or value > 100.0:
				errors.append("need %s value must be inside 0..100" % need_name)

		if (
			not need_data.has("decay_per_sim_hour")
			or not _is_finite_number(need_data["decay_per_sim_hour"])
		):
			errors.append("need %s decay_per_sim_hour must be finite" % need_name)
		elif float(need_data["decay_per_sim_hour"]) < 0.0:
			errors.append("need %s decay_per_sim_hour must be non-negative" % need_name)

static func _validate_personality(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("personality") or not data["personality"] is Dictionary:
		errors.append("personality must be a Dictionary")
		return

	var personality: Dictionary = data["personality"]
	for trait_name in TRAIT_NAMES:
		if not personality.has(trait_name) or not _is_finite_number(personality[trait_name]):
			errors.append("personality %s must be finite" % trait_name)
			continue
		var value := float(personality[trait_name])
		if value < 0.0 or value > 1.0:
			errors.append("personality %s must be inside 0..1" % trait_name)

static func _validate_memory(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("memory") or not data["memory"] is Dictionary:
		errors.append("memory must be a Dictionary")
		return

	var memory: Dictionary = data["memory"]
	if (
		not memory.has("capacity")
		or not memory["capacity"] is int
		or int(memory["capacity"]) < 1
	):
		errors.append("memory capacity must be an integer >= 1")
		return

	if not memory.has("events") or not memory["events"] is Array:
		errors.append("memory events must be an Array")
		return

	var events: Array = memory["events"]
	if events.size() > int(memory["capacity"]):
		errors.append("memory event count exceeds capacity")

	var seen_ids: Dictionary = {}
	for raw_event in events:
		if not raw_event is Dictionary:
			errors.append("memory event must be a Dictionary")
			continue
		var event: Dictionary = raw_event

		if (
			not event.has("event_id")
			or not event["event_id"] is String
			or event["event_id"].is_empty()
		):
			errors.append("memory event_id must be a non-empty string")
		else:
			var event_id: String = event["event_id"]
			if seen_ids.has(event_id):
				errors.append("duplicate memory event_id: %s" % event_id)
			seen_ids[event_id] = true

		if not event.has("kind") or not event["kind"] is String:
			errors.append("memory kind must be a string")

		if (
			not event.has("simulation_seconds")
			or not _is_finite_number(event["simulation_seconds"])
			or float(event["simulation_seconds"]) < 0.0
		):
			errors.append("memory simulation_seconds must be finite and non-negative")

		if not event.has("related_resident_ids") or not event["related_resident_ids"] is Array:
			errors.append("memory related_resident_ids must be an Array")
		else:
			var related_seen: Dictionary = {}
			for resident_id in event["related_resident_ids"]:
				if not resident_id is String or resident_id.is_empty():
					errors.append("memory related resident id must be non-empty string")
				elif related_seen.has(resident_id):
					errors.append("memory related resident ids must be unique")
				else:
					related_seen[resident_id] = true

		if not event.has("valence") or not _is_finite_number(event["valence"]):
			errors.append("memory valence must be finite")
		else:
			var valence := float(event["valence"])
			if valence < -1.0 or valence > 1.0:
				errors.append("memory valence must be inside -1..1")

		if not event.has("importance") or not _is_finite_number(event["importance"]):
			errors.append("memory importance must be finite")
		else:
			var importance := float(event["importance"])
			if importance < 0.0 or importance > 1.0:
				errors.append("memory importance must be inside 0..1")

static func _validate_job(data: Dictionary, errors: Array[String]) -> void:
	if not data.has("job") or not data["job"] is Dictionary:
		errors.append("job must be a Dictionary")
		return

	var job: Dictionary = data["job"]
	if (
		not job.has("total_worked_sim_seconds")
		or not _is_finite_number(job["total_worked_sim_seconds"])
		or float(job["total_worked_sim_seconds"]) < 0.0
	):
		errors.append("job total_worked_sim_seconds must be finite and non-negative")

	if not job.has("definition"):
		errors.append("job definition key is required")
		return

	var definition = job["definition"]
	if definition == null:
		return
	if not definition is Dictionary:
		errors.append("job definition must be null or Dictionary")
		return

	if (
		not definition.has("id")
		or not definition["id"] is String
		or definition["id"].is_empty()
	):
		errors.append("job id must be a non-empty string")

	if (
		not definition.has("pay_per_sim_hour")
		or not _is_finite_number(definition["pay_per_sim_hour"])
		or float(definition["pay_per_sim_hour"]) <= 0.0
	):
		errors.append("job pay_per_sim_hour must be finite and positive")

	if (
		not definition.has("shift_start_hour")
		or not _is_finite_number(definition["shift_start_hour"])
	):
		errors.append("job shift_start_hour must be finite")
	else:
		var start := float(definition["shift_start_hour"])
		if start < 0.0 or start >= 24.0:
			errors.append("job shift_start_hour must be inside 0..<24")

	if (
		not definition.has("shift_duration_hours")
		or not _is_finite_number(definition["shift_duration_hours"])
	):
		errors.append("job shift_duration_hours must be finite")
	else:
		var duration := float(definition["shift_duration_hours"])
		if duration <= 0.0 or duration > 24.0:
			errors.append("job shift_duration_hours must be inside 0<..24")

static func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


static func validate_goal_targets(
	data: Dictionary,
	resident_ids: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("goals") or not data["goals"] is Dictionary:
		return errors

	var goals: Dictionary = data["goals"]
	if not goals.has("items") or not goals["items"] is Array:
		return errors

	var self_id := str(data.get("id", ""))
	for raw_goal in goals["items"]:
		if not raw_goal is Dictionary:
			continue
		var definition = raw_goal.get("definition")
		if not definition is Dictionary:
			continue
		var target = definition.get("target_resident_id", "")
		if not target is String or target.is_empty():
			continue
		if target == self_id:
			errors.append(
				"goal target resident must not be self: %s"
				% target
			)
		elif not resident_ids.has(target):
			errors.append(
				"goal target resident is missing: %s"
				% target
			)

	return errors

static func _encode_schedule(character: CharacterState) -> Dictionary:
	var definition_data = null
	if character.schedule != null and character.schedule.definition != null:
		var blocks: Array = []
		for block in character.schedule.definition.blocks:
			var tags: Array = []
			for tag in block.preferred_action_tags:
				tags.append(str(tag))
			blocks.append({
				"id": str(block.id),
				"kind": str(block.kind),
				"start_hour": block.start_hour,
				"duration_hours": block.duration_hours,
				"preferred_action_tags": tags,
			})
		definition_data = {"blocks": blocks}

	return {
		"day_index": character.schedule.day_index if character.schedule != null else 0,
		"active_block_id": (
			str(character.schedule.active_block_id)
			if character.schedule != null
			else ""
		),
		"definition": definition_data,
	}

static func _encode_goals(character: CharacterState) -> Dictionary:
	var items: Array = []
	if character.goals != null:
		for goal in character.goals.goals():
			if goal == null or goal.definition == null:
				continue
			var tags: Array = []
			for tag in goal.definition.preferred_action_tags:
				tags.append(str(tag))
			items.append({
				"definition": {
					"id": str(goal.definition.id),
					"category": str(goal.definition.category),
					"priority": goal.definition.priority,
					"preferred_action_tags": tags,
					"target_resident_id": str(goal.definition.target_resident_id),
				},
				"progress": goal.progress,
				"status": str(goal.status),
			})

	return {
		"day_index": character.goals.day_index if character.goals != null else -1,
		"items": items,
	}

static func _validate_schedule(
	data: Dictionary,
	errors: Array[String]
) -> void:
	if not data.has("schedule"):
		return
	if not data["schedule"] is Dictionary:
		errors.append("schedule must be a Dictionary")
		return

	var schedule: Dictionary = data["schedule"]
	if (
		not schedule.has("day_index")
		or not schedule["day_index"] is int
		or int(schedule["day_index"]) < 0
	):
		errors.append("schedule day_index must be an integer >= 0")

	if (
		not schedule.has("active_block_id")
		or not schedule["active_block_id"] is String
	):
		errors.append("schedule active_block_id must be a string")

	if not schedule.has("definition"):
		errors.append("schedule definition key is required")
		return

	var definition = schedule["definition"]
	if definition == null:
		if schedule.get("active_block_id", "") != "":
			errors.append(
				"schedule without definition cannot have active block"
			)
		return
	if not definition is Dictionary:
		errors.append("schedule definition must be null or Dictionary")
		return
	if not definition.has("blocks") or not definition["blocks"] is Array:
		errors.append("schedule definition blocks must be an Array")
		return

	var parsed := ScheduleDefinition.new()
	var block_ids: Dictionary = {}
	for raw_block in definition["blocks"]:
		if not raw_block is Dictionary:
			errors.append("schedule block must be a Dictionary")
			continue

		var block_data: Dictionary = raw_block
		var block := ScheduleBlock.new()

		if (
			not block_data.has("id")
			or not block_data["id"] is String
			or block_data["id"].is_empty()
		):
			errors.append("schedule block id must be a non-empty string")
			continue
		block.id = StringName(block_data["id"])
		var raw_kind = block_data.get("kind", "")
		if not raw_kind is String or raw_kind.is_empty():
			errors.append("schedule block kind must be a non-empty string")
		else:
			block.kind = StringName(raw_kind)

		if (
			not block_data.has("start_hour")
			or not _is_finite_number(block_data["start_hour"])
		):
			errors.append("schedule block start_hour must be finite")
			continue
		if (
			not block_data.has("duration_hours")
			or not _is_finite_number(block_data["duration_hours"])
		):
			errors.append("schedule block duration_hours must be finite")
			continue
		block.start_hour = float(block_data["start_hour"])
		block.duration_hours = float(block_data["duration_hours"])

		if (
			not block_data.has("preferred_action_tags")
			or not block_data["preferred_action_tags"] is Array
		):
			errors.append("schedule preferred_action_tags must be an Array")
		else:
			for raw_tag in block_data["preferred_action_tags"]:
				if not raw_tag is String or raw_tag.is_empty():
					errors.append(
						"schedule action tag must be a non-empty string"
					)
				else:
					block.preferred_action_tags.append(
						StringName(raw_tag)
					)

		parsed.blocks.append(block)
		block_ids[str(block.id)] = true

	for schedule_error in parsed.validate():
		errors.append(schedule_error)

	var active_block_id = schedule.get("active_block_id", "")
	if (
		active_block_id is String
		and not active_block_id.is_empty()
		and not block_ids.has(active_block_id)
	):
		errors.append(
			"schedule active block id is missing from definition"
		)

static func _validate_goals(
	data: Dictionary,
	errors: Array[String]
) -> void:
	if not data.has("goals"):
		return
	if not data["goals"] is Dictionary:
		errors.append("goals must be a Dictionary")
		return

	var goals: Dictionary = data["goals"]
	if (
		not goals.has("day_index")
		or not goals["day_index"] is int
		or int(goals["day_index"]) < -1
	):
		errors.append("goal day_index must be an integer >= -1")

	if not goals.has("items") or not goals["items"] is Array:
		errors.append("goal items must be an Array")
		return

	var seen_ids: Dictionary = {}
	var active_count := 0
	for raw_goal in goals["items"]:
		if not raw_goal is Dictionary:
			errors.append("goal item must be a Dictionary")
			continue
		var goal_data: Dictionary = raw_goal

		if (
			not goal_data.has("definition")
			or not goal_data["definition"] is Dictionary
		):
			errors.append("goal definition must be a Dictionary")
			continue

		var definition_data: Dictionary = goal_data["definition"]
		var definition := GoalDefinition.new()

		var raw_goal_id = definition_data.get("id", "")
		if not raw_goal_id is String or raw_goal_id.is_empty():
			errors.append("goal id must be a non-empty string")
		else:
			definition.id = StringName(raw_goal_id)

		var raw_category = definition_data.get("category", "")
		if not raw_category is String or raw_category.is_empty():
			errors.append("goal category must be a non-empty string")
		else:
			definition.category = StringName(raw_category)

		if (
			not definition_data.has("priority")
			or not _is_finite_number(definition_data["priority"])
		):
			errors.append("goal priority must be finite")
		else:
			definition.priority = float(definition_data["priority"])

		var target = definition_data.get("target_resident_id", "")
		if not target is String:
			errors.append("goal target_resident_id must be a string")
		else:
			definition.target_resident_id = StringName(target)

		if (
			not definition_data.has("preferred_action_tags")
			or not definition_data["preferred_action_tags"] is Array
		):
			errors.append("goal preferred_action_tags must be an Array")
		else:
			for raw_tag in definition_data["preferred_action_tags"]:
				if not raw_tag is String or raw_tag.is_empty():
					errors.append(
						"goal action tag must be a non-empty string"
					)
				else:
					definition.preferred_action_tags.append(
						StringName(raw_tag)
					)

		for goal_error in definition.validate():
			errors.append(goal_error)

		var goal_id := str(definition.id)
		if seen_ids.has(goal_id):
			errors.append("duplicate goal id: %s" % goal_id)
		else:
			seen_ids[goal_id] = true

		if (
			not goal_data.has("progress")
			or not _is_finite_number(goal_data["progress"])
		):
			errors.append("goal progress must be finite")
		else:
			var progress := float(goal_data["progress"])
			if progress < 0.0 or progress > 1.0:
				errors.append("goal progress must be inside 0..1")

		if not goal_data.has("status") or not goal_data["status"] is String:
			errors.append("goal status must be a string")
			continue

		var status: String = goal_data["status"]
		if status not in ["active", "completed", "failed"]:
			errors.append("goal status is invalid")
		elif status == "active":
			active_count += 1
		elif (
			status == "completed"
			and goal_data.has("progress")
			and _is_finite_number(goal_data["progress"])
			and not is_equal_approx(float(goal_data["progress"]), 1.0)
		):
			errors.append("completed goal must have full progress")

	if active_count > GoalSet.MAX_ACTIVE_GOALS:
		errors.append("too many active goals")

	if (
		goals.has("day_index")
		and goals["day_index"] is int
		and int(goals["day_index"]) < 0
		and not goals["items"].is_empty()
	):
		errors.append("unplanned goal day cannot contain items")

static func _decode_schedule(
	character: CharacterState,
	data: Dictionary
) -> void:
	character.schedule.day_index = int(data["day_index"])
	character.schedule.active_block_id = StringName(
		data["active_block_id"]
	)

	if data["definition"] == null:
		return

	var definition := ScheduleDefinition.new()
	for raw_block in data["definition"]["blocks"]:
		var block_data: Dictionary = raw_block
		var block := ScheduleBlock.new()
		block.id = StringName(block_data["id"])
		block.kind = StringName(block_data["kind"])
		block.start_hour = float(block_data["start_hour"])
		block.duration_hours = float(block_data["duration_hours"])
		for raw_tag in block_data["preferred_action_tags"]:
			block.preferred_action_tags.append(StringName(raw_tag))
		definition.blocks.append(block)

	character.schedule.definition = definition

static func _decode_goals(
	character: CharacterState,
	data: Dictionary
) -> bool:
	character.goals.day_index = int(data["day_index"])

	for raw_goal in data["items"]:
		var goal_data: Dictionary = raw_goal
		var definition_data: Dictionary = goal_data["definition"]
		var definition := GoalDefinition.new()
		definition.id = StringName(definition_data["id"])
		definition.category = StringName(definition_data["category"])
		definition.priority = float(definition_data["priority"])
		definition.target_resident_id = StringName(
			definition_data["target_resident_id"]
		)
		for raw_tag in definition_data["preferred_action_tags"]:
			definition.preferred_action_tags.append(
				StringName(raw_tag)
			)

		var goal := GoalState.new(definition)
		goal.progress = float(goal_data["progress"])
		goal.status = StringName(goal_data["status"])
		if not character.goals.add(goal):
			return false

	return true
