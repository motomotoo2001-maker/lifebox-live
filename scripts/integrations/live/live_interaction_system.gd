class_name LiveInteractionSystem
extends RefCounted

const MAX_EVENTS_PER_STEP := 8
const MAX_FATE_RESULT_BUFFER := 128
const DEFAULT_FATE_RNG_SEED := 86006

var queue := LiveEventQueue.new()
var processed_ledger := EventIdLedger.new()
var chaos := ChaosMeter.new()
var fate_engine := FateEngine.new()
var gift_tier_mapper := GiftTierMapper.new()
var comment_parser := CommentCommandParser.new()

var _vote_session: VoteSession = null
var _fate_rng := RandomNumberGenerator.new()
var _fate_results: Array[FateResult] = []

func _init() -> void:
	_fate_rng.seed = DEFAULT_FATE_RNG_SEED

func enqueue_event(event: LiveEvent) -> StringName:
	return queue.enqueue(event, processed_ledger)

func pending_count() -> int:
	return queue.size()

func processed_count() -> int:
	return processed_ledger.size()

func start_vote_session(session: VoteSession) -> bool:
	if session == null or not session.is_valid() or not session.is_open:
		return false
	_vote_session = session
	return true

func active_vote_session() -> VoteSession:
	return _vote_session

func close_vote_session() -> StringName:
	if _vote_session == null:
		return &""
	return _vote_session.close()

func take_fate_results() -> Array[FateResult]:
	var results: Array[FateResult] = []
	for result in _fate_results:
		results.append(result)
	_fate_results.clear()
	return results

func process_step(
	world: SimulationWorld,
	simulation_seconds: float
) -> int:
	if world == null:
		return 0
	if (
		is_nan(simulation_seconds)
		or is_inf(simulation_seconds)
		or simulation_seconds < 0.0
	):
		return 0

	var processed := 0
	while processed < MAX_EVENTS_PER_STEP and not queue.is_empty():
		var event := queue.pop_front()
		if event == null:
			continue

		if not processed_ledger.has(event.event_id):
			_process_event(event, world, simulation_seconds)
			processed_ledger.record(event.event_id)

		processed += 1

	return processed

func _process_event(
	event: LiveEvent,
	world: SimulationWorld,
	simulation_seconds: float
) -> void:
	match event.kind:
		LiveEvent.KIND_GIFT:
			var tier := gift_tier_mapper.tier_for(
				int(event.payload["gift_value"]),
				int(event.payload["repeat_count"])
			)
			var result := fate_engine.resolve(
				tier,
				world.characters(),
				world.relationship_graph,
				world.economy_system,
				chaos,
				simulation_seconds,
				_fate_rng
			)
			_buffer_fate_result(result)
		LiveEvent.KIND_LIKE_BATCH:
			chaos.add_likes(int(event.payload["count"]))
		LiveEvent.KIND_COMMENT:
			_process_comment(event)
		LiveEvent.KIND_FOLLOW, LiveEvent.KIND_SHARE:
			pass

func _process_comment(event: LiveEvent) -> void:
	if _vote_session == null or not _vote_session.is_open:
		return

	var command := comment_parser.parse(str(event.payload["text"]))
	if command == CommentCommandParser.COMMAND_NONE:
		return

	_vote_session.cast_vote(event.viewer_key, command)

func _buffer_fate_result(result: FateResult) -> void:
	if result == null:
		return
	while _fate_results.size() >= MAX_FATE_RESULT_BUFFER:
		_fate_results.pop_front()
	_fate_results.append(result)
