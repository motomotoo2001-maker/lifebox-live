extends RefCounted

const EXPENSE_SYSTEM_PATH := "res://scripts/simulation/economy/household_expense_system.gd"
const ECONOMY_PATH := "res://scripts/simulation/economy/economy_system.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(EXPENSE_SYSTEM_PATH):
		failures.append("HouseholdExpenseSystem must exist at %s" % EXPENSE_SYSTEM_PATH)
		return failures

	var expense_script := load(EXPENSE_SYSTEM_PATH)
	var economy_script := load(ECONOMY_PATH)
	var character_script := load(CHARACTER_PATH)
	if expense_script == null or economy_script == null or character_script == null:
		failures.append("household expense dependencies must load")
		return failures

	var alice = character_script.new(&"alice", "Alice")
	var bob = character_script.new(&"bob", "Bob")
	alice.money = 80.0
	bob.money = 10.0
	var residents: Array = [alice, bob]

	var economy = economy_script.new()
	var expenses = expense_script.new(100.0)

	expenses.advance(residents, 86399.0, economy)
	if not is_equal_approx(alice.money, 80.0) or not is_equal_approx(bob.money, 10.0):
		failures.append("household expense must not charge before first full simulated day")
	if not is_equal_approx(expenses.arrears, 0.0):
		failures.append("arrears must start at zero")

	expenses.advance(residents, 86400.0, economy)
	if not is_equal_approx(alice.money, 30.0):
		failures.append("first resident must pay its equal daily share when affordable")
	if not is_equal_approx(bob.money, 0.0):
		failures.append("second resident must pay available balance without going negative")
	if not is_equal_approx(expenses.arrears, 40.0):
		failures.append("unpaid first-day share must be recorded as arrears")
	if expenses.processed_days != 1:
		failures.append("first completed day must be processed exactly once")

	var tx_count_after_day_one := economy.transactions().size()
	expenses.advance(residents, 90000.0, economy)
	if economy.transactions().size() != tx_count_after_day_one:
		failures.append("same simulated day must not charge household twice")
	if not is_equal_approx(expenses.arrears, 40.0):
		failures.append("same-day advance must not change arrears")

	expenses.advance(residents, 172800.0, economy)
	if not is_equal_approx(alice.money, 0.0):
		failures.append("second day must spend remaining available money without negative balance")
	if not is_equal_approx(bob.money, 0.0):
		failures.append("zero-balance resident must remain at zero")
	if not is_equal_approx(expenses.arrears, 110.0):
		failures.append("second-day unpaid household amount must accumulate into arrears")
	if expenses.processed_days != 2:
		failures.append("two completed simulated days must be processed")

	if alice.money < 0.0 or bob.money < 0.0:
		failures.append("household expenses must never create negative resident balance")
	if is_nan(expenses.arrears) or is_inf(expenses.arrears) or expenses.arrears < 0.0:
		failures.append("household arrears must remain finite and non-negative")

	var empty_expenses = expense_script.new(60.0)
	var empty_economy = economy_script.new()
	var nobody: Array = []
	empty_expenses.advance(nobody, 86400.0, empty_economy)
	if not is_equal_approx(empty_expenses.arrears, 60.0):
		failures.append("empty household must record full unpaid daily amount as arrears")

	return failures
