class_name EconomySystem
extends RefCounted

const DEFAULT_PERSISTED_TRANSACTION_LIMIT := 512

var _sequence: int = 0
var _transactions: Array[EconomyTransaction] = []

func deposit(
	character: CharacterState,
	amount: float,
	simulation_seconds: float = 0.0
) -> EconomyTransaction:
	if not _can_change_balance(character, amount):
		return null

	var new_balance := character.money + amount
	if is_nan(new_balance) or is_inf(new_balance):
		return null

	character.money = new_balance
	return _record(
		&"deposit",
		&"",
		character.id,
		amount,
		simulation_seconds
	)

func spend(
	character: CharacterState,
	amount: float,
	simulation_seconds: float = 0.0
) -> EconomyTransaction:
	if not _can_change_balance(character, amount):
		return null
	if character.money < amount:
		return null

	var new_balance := character.money - amount
	if is_nan(new_balance) or is_inf(new_balance) or new_balance < 0.0:
		return null

	character.money = new_balance
	return _record(
		&"spend",
		character.id,
		&"",
		amount,
		simulation_seconds
	)

func transfer(
	from_character: CharacterState,
	to_character: CharacterState,
	amount: float,
	simulation_seconds: float = 0.0
) -> EconomyTransaction:
	if from_character == null or to_character == null:
		return null
	if from_character == to_character or from_character.id == to_character.id:
		return null
	if not _is_valid_amount(amount):
		return null
	if not _is_valid_balance(from_character.money) or not _is_valid_balance(to_character.money):
		return null
	if from_character.money < amount:
		return null

	var new_from_balance := from_character.money - amount
	var new_to_balance := to_character.money + amount
	if (
		is_nan(new_from_balance)
		or is_inf(new_from_balance)
		or is_nan(new_to_balance)
		or is_inf(new_to_balance)
		or new_from_balance < 0.0
	):
		return null

	from_character.money = new_from_balance
	to_character.money = new_to_balance

	return _record(
		&"transfer",
		from_character.id,
		to_character.id,
		amount,
		simulation_seconds
	)

func transactions() -> Array[EconomyTransaction]:
	return _transactions.duplicate()

func capture_persistence_state(
	max_transactions: int = DEFAULT_PERSISTED_TRANSACTION_LIMIT
) -> Dictionary:
	var limit := maxi(max_transactions, 0)
	var start_index := maxi(_transactions.size() - limit, 0)
	var encoded_transactions: Array = []

	for index in range(start_index, _transactions.size()):
		var transaction: EconomyTransaction = _transactions[index]
		encoded_transactions.append({
			"transaction_id": str(transaction.transaction_id),
			"kind": str(transaction.kind),
			"from_resident_id": str(transaction.from_resident_id),
			"to_resident_id": str(transaction.to_resident_id),
			"amount": transaction.amount,
			"simulation_seconds": transaction.simulation_seconds,
		})

	return {
		"sequence": _sequence,
		"transactions": encoded_transactions,
	}

func restore_persistence_state(data: Dictionary) -> bool:
	if not _validate_persistence_state(data):
		return false

	var restored_transactions: Array[EconomyTransaction] = []
	for raw_transaction in data["transactions"]:
		var transaction_data: Dictionary = raw_transaction
		restored_transactions.append(EconomyTransaction.new(
			StringName(transaction_data["transaction_id"]),
			StringName(transaction_data["kind"]),
			StringName(transaction_data["from_resident_id"]),
			StringName(transaction_data["to_resident_id"]),
			float(transaction_data["amount"]),
			float(transaction_data["simulation_seconds"])
		))

	_sequence = int(data["sequence"])
	_transactions = restored_transactions
	return true

func _validate_persistence_state(data: Dictionary) -> bool:
	if not data.has("sequence") or not data["sequence"] is int:
		return false
	var sequence := int(data["sequence"])
	if sequence < 0:
		return false

	if not data.has("transactions") or not data["transactions"] is Array:
		return false
	var encoded_transactions: Array = data["transactions"]
	if encoded_transactions.size() > DEFAULT_PERSISTED_TRANSACTION_LIMIT:
		return false

	var seen_ids: Dictionary = {}
	for raw_transaction in encoded_transactions:
		if not raw_transaction is Dictionary:
			return false
		var transaction: Dictionary = raw_transaction

		for key in [
			"transaction_id",
			"kind",
			"from_resident_id",
			"to_resident_id",
			"amount",
			"simulation_seconds",
		]:
			if not transaction.has(key):
				return false

		if not transaction["transaction_id"] is String:
			return false
		var transaction_id: String = transaction["transaction_id"]
		var transaction_sequence := _transaction_sequence_from_id(transaction_id)
		if transaction_sequence <= 0 or transaction_sequence > sequence:
			return false
		if seen_ids.has(transaction_id):
			return false
		seen_ids[transaction_id] = true

		if not transaction["kind"] is String:
			return false
		var kind: String = transaction["kind"]
		if kind not in ["deposit", "spend", "transfer"]:
			return false

		if not transaction["from_resident_id"] is String:
			return false
		if not transaction["to_resident_id"] is String:
			return false

		if not _is_finite_number(transaction["amount"]):
			return false
		if float(transaction["amount"]) <= 0.0:
			return false

		if not _is_finite_number(transaction["simulation_seconds"]):
			return false
		if float(transaction["simulation_seconds"]) < 0.0:
			return false

	return true

func _transaction_sequence_from_id(transaction_id: String) -> int:
	if not transaction_id.begins_with("txn_"):
		return -1
	var suffix := transaction_id.trim_prefix("txn_")
	if suffix.is_empty() or not suffix.is_valid_int():
		return -1
	var parsed := int(suffix)
	if transaction_id != "txn_%06d" % parsed:
		return -1
	return parsed

func _can_change_balance(character: CharacterState, amount: float) -> bool:
	if character == null:
		return false
	if not _is_valid_amount(amount):
		return false
	return _is_valid_balance(character.money)

func _is_valid_amount(amount: float) -> bool:
	return not is_nan(amount) and not is_inf(amount) and amount > 0.0

func _is_valid_balance(balance: float) -> bool:
	return not is_nan(balance) and not is_inf(balance) and balance >= 0.0

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)

func _record(
	kind: StringName,
	from_resident_id: StringName,
	to_resident_id: StringName,
	amount: float,
	simulation_seconds: float
) -> EconomyTransaction:
	_sequence += 1
	var transaction := EconomyTransaction.new(
		StringName("txn_%06d" % _sequence),
		kind,
		from_resident_id,
		to_resident_id,
		amount,
		simulation_seconds
	)
	_transactions.append(transaction)
	return transaction
