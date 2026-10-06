# Resident Selection & UI Implementation Plan

**Goal:** Add presentation-only resident inspection and selection without weakening simulation authority.

## Task 1 — Selectable resident actor
- Add Area3D + CollisionShape3D pick target.
- Emit resident_selected(character_id) on left click.
- Add selection marker and set_selected(bool).

## Task 2 — Shell selection controller
- Connect resident selection signals.
- Add select_resident(character_id), selected_resident_id().
- Support keys 1–6 and Space pause.
- Add temporary manual camera focus.

## Task 3 — HUD readability
- Add explicit labels for Hunger / Energy / Social / Mood.
- Show running/paused state.
- Add compact controls hint.
- Preserve 720×1280 layout.

## Task 4 — Runtime contracts
- Extend resident actor, shell and HUD tests.
- Validate selected actor ownership.
- Run Godot CI/headless tests.

## Task 5 — Visual checkpoint
- Add Plan 11 capture workflow.
- Render real viewport screenshot after interaction/UI pass.
