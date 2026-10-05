extends RefCounted

const TRANSACTION_PATH := "res://scripts/simulation/economy/economy_transaction.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(TRANSACTION_PATH):
		failures.append("EconomyTransaction must exist at %s" % TRANSACTION_PATH)
		return failures
	if not FileAccess.file_exists(ECONOMY_PATH):
		failures.append("EconomySystem must exist at %s" % ECONOMY_PATH)
		return failures

	var economy_script := load(ECONOMY_PATH)
	var character_script := load(CHARACTER_PATH)
	if economy_script == null or character_script == null:
		failures.append("economy dependencies must load")
		return failures

	var economy = economy_script.new()
	var alice = character_script.new(&"alice", "Alice")
	var bob = character_script.new(&"bob", "Bob")
	alice.money = 10.0
	bob.money = 5.0

	if economy.deposit(null, 10.0) != null:
		failures.append("deposit must reject null resident")
	if economy.deposit(alice, 0.0) != null:
		failures.append("deposit must reject zero amount")
	if economy.deposit(alice, -1.0) != null:
		failures.append("deposit must reject negative amount")
	if economy.deposit(alice, NAN) != null or economy.deposit(alice, INF) != null:
		failures.append("deposit must reject non-finite amount")
	if not is_equal_approx(alice.money, 10.0):
		failures.append("rejected deposit must not change balance")

	var deposit_tx = economy.deposit(alice, 25.0, 100.0)
	if deposit_tx == null:
		failures.append("valid deposit must return transaction")
	else:
		if deposit_tx.transaction_id != &"txn_000001":
			failures.append("first successful transaction id must be deterministic")
		if deposit_tx.kind != &"deposit":
			failures.append("deposit transaction kind must be deposit")
		if deposit_tx.to_resident_id != alice.id:
			failures.append("deposit transaction must target resident")
		if not is_equal_approx(deposit_tx.amount, 25.0):
			failures.append("deposit transaction must preserve amount")
		if not is_equal_approx(deposit_tx.simulation_seconds, 100.0):
			failures.append("deposit transaction must preserve simulation time")
	if not is_equal_approx(alice.money, 35.0):
		failures.append("valid deposit must increase balance")

	var spend_tx = economy.spend(alice, 5.0, 110.0)
	if spend_tx == null or spend_tx.transaction_id != &"txn_000002":
		failures.append("second successful transaction must be deterministic spend")
	if not is_equal_approx(alice.money, 30.0):
		failures.append("valid spend must reduce balance")

	var before_failed_spend: float = alice.money
	if economy.spend(alice, 1000.0) != null:
		failures.append("overspend must be rejected")
	if not is_equal_approx(alice.money, before_failed_spend):
		failures.append("rejected overspend must not change balance")

	var transfer_tx = economy.transfer(alice, bob, 10.0, 120.0)
	if transfer_tx == null:
		failures.append("valid transfer must return transaction")
	else:
		if transfer_tx.transaction_id != &"txn_000003":
			failures.append("failed operations must not consume transaction ids")
		if transfer_tx.kind != &"transfer":
			failures.append("transfer transaction kind must be transfer")
		if transfer_tx.from_resident_id != alice.id or transfer_tx.to_resident_id != bob.id:
			failures.append("transfer transaction must preserve both resident ids")

	if not is_equal_approx(alice.money, 20.0) or not is_equal_approx(bob.money, 15.0):
		failures.append("valid transfer must update both balances atomically")

	var alice_before: float = alice.money
	var bob_before: float = bob.money
	if economy.transfer(alice, bob, 999.0) != null:
		failures.append("insufficient transfer must be rejected")
	if not is_equal_approx(alice.money, alice_before) or not is_equal_approx(bob.money, bob_before):
		failures.append("failed transfer must leave both balances unchanged")

	if economy.transfer(alice, alice, 1.0) != null:
		failures.append("self transfer must be rejected")
	if economy.transfer(alice, bob, NAN) != null:
		failures.append("non-finite transfer must be rejected")

	if alice.money < 0.0 or bob.money < 0.0 or is_nan(alice.money) or is_nan(bob.money):
		failures.append("economy operations must keep balances finite and non-negative")

	var history: Array = economy.transactions()
	if history.size() != 3:
		failures.append("economy history must include only successful transactions")
	history.clear()
	if economy.transactions().size() != 3:
		failures.append("transactions() must not expose mutable internal history")

	return failures
