# LIFEBOX LIVE Simulation Foundation Implementation Plan

> Native execution on branch `dev/plan-01-simulation-foundation`. TDD is mandatory.

**Goal:** Build a deterministic headless foundation where one resident autonomously satisfies hunger and fatigue without graphics, network, or LLM dependencies.

## Global constraints
- Godot 4.7.2.
- Simulation independent of render FPS.
- Tests run headless.
- Fixed seed produces reproducible decisions.
- No monolithic `game.gd`.
- No TikTok, LLM, camera, navigation, or art dependencies in Plan 01.

## Tasks
1. Bootstrap project and headless test runner.
2. SimulationClock with 0x–20x time scaling.
3. EventBus.
4. NeedState and NeedProfile.
5. CharacterState and PersonalityState.
6. NeedSystem.
7. InteractionDefinition and SmartObject reservation contract.
8. ActionCandidate and deterministic UtilityAI.
9. Minimal SimulationWorld and ActionExecutor for Eat/Sleep/Idle.
10. Fixed-seed accelerated smoke/soak test and architecture notes.

## Completion gate
- Headless suite exits 0.
- One resident cycles through Eat/Sleep/Idle.
- Fixed-seed runs are reproducible.
- Large delta inputs preserve legal need ranges.
- SmartObject reservations clean up.
- Simulation core has no network/LLM/render dependency.
