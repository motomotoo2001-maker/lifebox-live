# LIFEBOX LIVE — Social, Economy & Memory Architecture

## Scope

Plan 03 extends the verified autonomous household with deterministic social life, episodic memory, jobs, household expenses, paid interactions, and personality-aware spending.

The simulation remains fully functional without network access or an LLM.

## Core resident state

Each `CharacterState` now owns:

- Needs and personality;
- Movement state;
- `MemoryStore`;
- `JobState`;
- Personal money balance;
- Current action id.

All resident identity remains based on stable non-empty `StringName` IDs.

## Relationships

`RelationshipGraph` stores directed resident-to-resident edges.

Each `RelationshipState` contains:

- affinity;
- trust;
- tension.

All values remain bounded to `-100..100`.

Edges are directional so A→B and B→A may diverge later even though the current social outcome profiles update both directions symmetrically.

## Episodic memory

`MemoryEvent` contains:

- event id;
- event kind;
- simulation timestamp;
- related resident IDs;
- valence in `-1..1`;
- importance in `0..1`.

`MemoryStore` defaults to capacity 64.

When capacity is exceeded:

1. lowest importance is evicted first;
2. oldest timestamp wins ties.

Memory event IDs are deterministic and duplicate IDs are rejected.

## Economy transaction core

`EconomySystem` provides:

- deposit;
- spend;
- transfer;
- immutable-style transaction records.

Rules:

- amounts must be finite and positive;
- balances remain finite and non-negative;
- overspend is rejected;
- transfers are atomic;
- failed operations do not consume transaction sequence IDs.

## Jobs

`JobDefinition` is data driven:

- stable job id;
- pay per simulated hour;
- daily shift start hour;
- shift duration.

`JobState` tracks the assigned definition and total worked simulated seconds.

`JobSystem` computes exact overlap between the processed simulation interval and repeating daily shifts, including shifts that cross midnight.

## Household expenses

`HouseholdExpenseSystem` processes one deterministic daily household charge.

The daily amount is split equally across valid residents.

If a resident cannot cover their share:

- available money is spent;
- money never becomes negative;
- unpaid value accumulates into household arrears.

## World economic cadence

Needs, actions, navigation watchdogs, and social scheduling remain on the one-second fixed simulation step.

Jobs and household bills run on a separate 60-simulated-second cadence.

This avoids generating one wage transaction per resident per simulated second while preserving deterministic shift overlap. A dedicated regression verifies that one resident working exactly one simulated hour produces 60 one-minute wage transactions rather than 3600 one-second transactions, while preserving the exact same total pay and worked time.

```text
real delta
  -> SimulationClock
  -> fixed 1s SimulationWorld steps
      -> needs
      -> SmartObject actions
      -> social actions
      -> accumulate economy time
          -> every 60 simulated seconds
              -> job income
              -> household expenses
```

## Paid SmartObject interactions

`InteractionDefinition` now supports:

- `money_cost`;
- `money_reward`.

Rules:

- unaffordable paid actions are filtered before utility selection;
- money is not charged while moving;
- arrival alone does not charge;
- cost/reward is settled only on successful interaction completion;
- movement failure and cancellation create no transaction;
- free interactions preserve Plan 02 behavior.

## Spending decisions

`SpendingDecisionSystem` adjusts paid-action utility using:

- current need urgency;
- resident impulsiveness;
- cost as a fraction of available money.

Free interactions retain their original utility score.

If base utility is zero, paid utility remains zero. This prevents a resident from repeatedly buying something after the relevant need is already satisfied.

Same-seed utility ties remain deterministic through the existing world RNG.

## Social reservations

`SocialReservationBook` atomically reserves two residents.

Guarantees:

- no self-session;
- one active social session per resident;
- failed reservations do not consume session IDs;
- unrelated pairs may coexist;
- release frees both participants;
- no stale reservations remain after completion/cancel.

## Autonomous social scheduler

`SocialSystem` evaluates idle, non-moving, unreserved residents.

Scoring uses:

- social need urgency;
- sociability;
- kindness;
- impulsiveness;
- affinity;
- trust;
- tension;
- action type.

Current semantic actions:

- `chat`;
- `compliment`;
- `argue`.

SmartObject actions are processed before social scheduling, so social life does not interrupt an already selected object interaction.

## Social outcomes

On successful social completion:

### Chat

- modest affinity increase;
- modest trust increase;
- small tension reduction;
- positive low-importance memory.

### Compliment

- stronger affinity/trust increase;
- stronger tension reduction;
- positive higher-importance memory.

### Argue

- affinity decrease;
- trust decrease;
- tension increase;
- negative high-importance memory.

Both participants receive a memory referring to the other resident.

Completed sessions are exposed once through a drainable completed-session queue.

Cancelled sessions:

- release both participants;
- restore idle action state;
- create no relationship outcome;
- create no memory.

## 24-hour verification

The final Plan 03 soak creates two identical independent worlds.

Each contains:

- six residents;
- unique resident IDs;
- individual jobs;
- household bills;
- one shared free fridge;
- six beds;
- a free relaxation object;
- a paid coffee interaction;
- autonomous social sessions;
- deterministic navigation arrival/failure feedback.

Each world runs for exactly 24 simulated hours at 20×.

The soak verifies:

- same-seed sampled histories are identical;
- money remains finite and non-negative;
- relationship values remain inside `-100..100`;
- memories never exceed capacity;
- no resident belongs to multiple social sessions;
- social residents never retain SmartObject movement intent;
- SmartObjects never have multiple active users;
- no stale SmartObject reservations;
- jobs perform simulated work;
- daily household expense cycle executes;
- social relationships and episodic memories are produced;
- simulation finishes exactly one 24-hour day.

## Final Plan 03 verification

Verified on Godot 4.7.2:

- relationship graph: yes;
- bounded episodic memory: yes;
- atomic economy: yes;
- jobs and household expenses: yes;
- paid interactions: yes;
- atomic social reservations: yes;
- autonomous social scheduling: yes;
- relationship + memory social outcomes: yes;
- personality-aware spending: yes;
- 24-hour deterministic twin-world soak: yes;
- full headless suite: **34 suites passing**;
- hidden Godot `SCRIPT ERROR / ERROR / WARNING`: **none**.

## Deferred

The following remain outside Plan 03:

- persistence / save migrations;
- replay reconstruction;
- LLM dialogue generation;
- TikTok Live transport;
- Fate Engine;
- Story Director / Camera Director;
- final art, character animation, audio and VFX.
