# Character Art & Interaction Anchors Implementation Plan

**Goal:** Improve resident silhouettes, interaction placement and player inspection controls without changing simulation authority.

## Task 1 — Resident visual pass
- Add hands, shoes, clothing accent and optional hair/accessory meshes.
- Drive variants from the existing deterministic visual profile index.
- Keep CharacterBody3D, NavigationAgent3D and existing signals intact.

## Task 2 — Presentation interaction anchors
- Extend _presentation_target_for() for fridge, shower and beds.
- Preserve deterministic sofa slots.
- Continue reporting authoritative target_object_id on arrival/failure.

## Task 3 — Inspection/time controls
- Add +/- time-scale changes through SimulationClock.
- Add Escape overview reset.
- Add selected resident action and current speed to HUD.

## Task 4 — Contracts
- Extend ResidentActor3D and VisualHUD contracts.
- Add deterministic anchor tests where practical.
- Run full Godot CI and headless tests.

## Task 5 — Visual checkpoint
- Render a real 720×1280 Godot viewport screenshot.
- Inspect silhouette readability, furniture overlap and HUD legibility.
