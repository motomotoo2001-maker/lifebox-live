class_name EconomySystem
extends RefCounted

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
