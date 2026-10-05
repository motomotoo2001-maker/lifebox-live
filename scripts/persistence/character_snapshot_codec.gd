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
	}

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	_validate_identity(data, errors)
	_validate_money(data, errors)
	_validate_needs(data, errors)
	_validate_personality(data, errors)
	_validate_memory(data, errors)
	_validate_job(data, errors)

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
