# Animation & Interaction Readability Implementation Plan

**Goal:** Improve presentation-only resident animation and interaction readability without changing simulation authority.

## Task 1 — Resident presentation states
- Extend ResidentActor3D with idle/walk/interact/social presentation states.
- Add deterministic pose animation per state.
- Preserve movement API/signals.

## Task 2 — Visual shell state mapping
- Derive actor presentation state from CharacterState movement/current action/social reservation.
- Add runtime contract tests for mapping.
- Ensure presentation cannot mutate simulation.

## Task 3 — Emote/activity feedback
- Add ActivityBadge/Label3D to resident scene.
- Add set_activity_badge(text, duration) and clear_activity_badge().
- Drive simple work/meal/social/fun/alert feedback from authoritative state/events.

## Task 4 — Visual checkpoint gate
- Render refreshed 9:16 showcase + soak.
- Inspect readability/occlusion.
- Run Godot CI, Headless Tests and Visual Checkpoint.
- Save screenshots and checkpoint docs.

## Constraints
- Godot 4.7.2.
- gl_compatibility preserved.
- simulation remains authoritative.
- no gameplay/state mutation from presentation.
- deterministic visual state mapping.
