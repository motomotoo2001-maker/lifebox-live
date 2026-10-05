# LIFEBOX LIVE Social Life & Economy Implementation Plan

> Execution mode: Native / inline TDD.

**Goal:** Add deterministic resident relationships, episodic memory, jobs, earnings, spending, and autonomous social interactions to the verified six-resident household.

**Base:** Plan 02 verified HEAD `d6a1412`.

**Architecture:** Social/economy logic remains headless and authoritative. Rendering, NavigationAgent3D, TikTok, and LLMs remain adapters or later layers. Social actions use resident IDs and deterministic reservations; memories record outcomes without requiring generated dialogue.

## Global constraints

- Godot 4.7.2, GDScript-first.
- Fixed-seed worlds must remain reproducible.
- Existing Plan 01/02 suites must stay green.
- No LLM/network dependency in resident life simulation.
- Money must remain finite and transaction-safe.
- Relationship values must remain bounded.
- Memory capacity must be bounded.
- One resident cannot participate in two simultaneous social sessions.
- Social systems must never steal a resident already busy with a SmartObject action.
- All new state must be serializable-friendly pure data where practical.

---

### Task 1 — Relationship state and graph

**Files**
- Create: `scripts/simulation/relationships/relationship_state.gd`
- Create: `scripts/simulation/relationships/relationship_graph.gd`
- Create: `tests/unit/test_relationship_graph.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- Directed resident-to-resident relationship state.
- Fields: affinity, trust, tension.
- affinity/trust/tension clamp to `-100..100`.
- Self relationships are rejected.
- Duplicate edge creation returns the existing state.
- Graph iteration order must be deterministic.

**TDD**
- RED: bounds, NaN safety, self-edge rejection, stable lookup, directed asymmetry.
- GREEN: minimal state + graph.
- Full suite must pass.

---

### Task 2 — Episodic memory

**Files**
- Create: `scripts/simulation/memory/memory_event.gd`
- Create: `scripts/simulation/memory/memory_store.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_memory_store.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- `MemoryEvent`: event_id, kind, simulation_seconds, related_resident_ids, valence, importance.
- valence clamps to `-1..1`; importance to `0..1`.
- `MemoryStore` rejects duplicate event IDs.
- Default capacity: 64.
- Deterministic eviction: lowest importance first, oldest first on ties.
- CharacterState owns one MemoryStore.

---

### Task 3 — Economy transaction core

**Files**
- Create: `scripts/simulation/economy/economy_transaction.gd`
- Create: `scripts/simulation/economy/economy_system.gd`
- Create: `tests/unit/test_economy_system.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- deposit, spend, transfer.
- Reject NaN/Inf/negative amounts.
- Spend cannot drive balance below zero.
- Transfer is atomic.
- Every successful change emits/returns a deterministic transaction record.
- Character money remains finite and non-negative.

---

### Task 4 — Jobs, income, and household expenses

**Files**
- Create: `scripts/simulation/economy/job_definition.gd`
- Create: `scripts/simulation/economy/job_state.gd`
- Create: `scripts/simulation/economy/job_system.gd`
- Create: `scripts/simulation/economy/household_expense_system.gd`
- Modify: `scripts/simulation/characters/character_state.gd`
- Create: `tests/unit/test_job_system.gd`
- Create: `tests/integration/test_household_expenses.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- Data-driven jobs with hourly pay and daily shift window.
- CharacterState owns JobState.
- Earnings depend only on simulated time worked.
- Household expenses charge a deterministic daily amount.
- Insufficient funds never create NaN/negative balances; unpaid amount is recorded as debt/arrears separately.

---

### Task 5 — Paid SmartObject interactions

**Files**
- Modify: `scripts/simulation/interactions/interaction_definition.gd`
- Modify: `scripts/simulation/actions/action_executor.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_paid_interaction.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- InteractionDefinition gains `money_cost` and `money_reward`.
- Unaffordable actions are not eligible candidates.
- Cost is charged atomically on successful completion.
- Reward is credited on completion.
- Failed movement/cancel never charges or rewards.
- Existing free Eat/Sleep behavior is unchanged.

---

### Task 6 — Social session reservation

**Files**
- Create: `scripts/simulation/social/social_action_definition.gd`
- Create: `scripts/simulation/social/social_session.gd`
- Create: `scripts/simulation/social/social_reservation_book.gd`
- Create: `tests/unit/test_social_reservation_book.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- Social actions: chat, compliment, argue.
- A social session has initiator, target, duration, action id.
- A resident can belong to at most one active session.
- Reservation of a pair is atomic.
- Cancellation/completion releases both residents.

---

### Task 7 — Autonomous social scoring and execution

**Files**
- Create: `scripts/simulation/social/social_system.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_autonomous_social_actions.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- Only idle, non-moving residents can start social actions.
- Target must also be idle and unreserved.
- Score uses social need, sociability, current relationship and action type.
- Same fixed seed produces same pair/action choices.
- Social sessions advance on simulated time.
- SmartObject actions keep priority when their utility is materially higher; social actions must not interrupt an active object action.

---

### Task 8 — Social outcomes write relationships and memories

**Files**
- Modify: `scripts/simulation/social/social_system.gd`
- Create: `tests/integration/test_social_outcomes.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- chat: modest affinity/trust increase.
- compliment: stronger positive affinity/trust and positive memory.
- argue: tension increase, affinity/trust decrease, negative memory.
- Both participants receive memory events.
- Relationship/memory updates happen once per completed session.
- Cancelled sessions apply no outcome.

---

### Task 9 — Autonomous spending decisions

**Files**
- Create: `scripts/simulation/economy/spending_decision_system.gd`
- Modify: `scripts/simulation/simulation_world.gd`
- Create: `tests/integration/test_autonomous_spending.gd`
- Modify: `tests/test_runner.gd`

**Contracts**
- Optional paid interactions are considered only when affordable.
- Need urgency and personality can bias spending.
- Residents with insufficient money remain valid and choose free alternatives/idle.
- Fixed seed produces deterministic tie resolution.
- No compulsive repeated purchase loop when the relevant need is already satisfied.

---

### Task 10 — 24-hour social/economy soak and documentation

**Files**
- Create: `tests/soak/test_social_economy_day_soak.gd`
- Create: `docs/architecture/social-economy-memory.md`
- Modify: `tests/test_runner.gd`

**Soak**
- Six residents.
- 24 simulated hours at accelerated time.
- Jobs and daily expense cycle.
- Free household SmartObjects plus at least one paid interaction.
- Autonomous social sessions.
- Deterministic simulated navigation feedback.
- Same-seed twin worlds.

**Assertions**
- no duplicate resident IDs;
- money is finite and non-negative;
- relationship values remain in bounds;
- memory stores never exceed capacity;
- no resident belongs to multiple social sessions;
- no social session overlaps an active SmartObject action;
- no stale SmartObject or social reservations;
- same-seed histories match;
- 24 simulated hours complete;
- all previous Plan 01/02 tests remain green;
- final Godot log has no SCRIPT ERROR / ERROR / WARNING lines.

## Plan 03 completion gate

Plan 03 is complete only when all ten tasks are verified on Godot 4.7.2 and the full suite is clean.

## Deferred

- generated natural-language dialogue / LLM;
- save/load persistence;
- TikTok Live bridge and Fate Engine;
- Story Director / Camera Director;
- final character art, animation polish, audio and VFX.
