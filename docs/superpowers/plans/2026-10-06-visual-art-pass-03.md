# Visual Art Pass 03 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing vertical dollhouse scene materially more readable and lived-in through deterministic resident variation, room props, materials and lighting while leaving simulation behavior unchanged.

**Architecture:** Presentation remains downstream of simulation. `ResidentActor3D` gains a deterministic visual-profile API that only changes meshes/materials/scales. `HouseholdBlockout` gains static prop builders grouped by room. Lighting changes remain scene/presentation-only and compatible with the existing automated Visual Checkpoint workflow.

**Tech Stack:** Godot 4.7.2, GDScript, StandardMaterial3D, primitive meshes, existing Visual Checkpoint workflow.

**Spec:** `docs/superpowers/specs/2026-10-06-visual-art-pass-03-spec.md`

## Global Constraints

- Godot 4.7.2.
- Simulation remains authoritative.
- No gameplay/state mutation from presentation.
- gl_compatibility rendering must remain supported.
- Existing 9:16 Visual Checkpoint stays deterministic.
- Existing Plan 01–07 tests remain green.

## Review Focus

- New resident profile API must not change movement/state authority.
- Visual variants must be deterministic from stable inputs.
- Added props must not block authored navigation paths or destination markers.
- Local lights must not blow out the vertical CI render.
- New wall/prop silhouettes must not hide residents in the default establishing camera.

---

### Task 1: Resident Visual Profiles

**Files:**
- Modify: `scenes/characters/resident_actor_3d.tscn`
- Modify: `scripts/presentation/characters/resident_actor_3d.gd`
- Modify: `tests/runtime/test_resident_actor_contract.gd`

**Interfaces:**
- Add visual nodes for eyes and secondary clothing treatment.
- Add `set_visual_profile(profile_index: int) -> void`.
- Preserve `set_visual_color(Color)`, movement signals and movement API.

- [ ] Write failing runtime contract for new nodes/profile method.
- [ ] Run Godot contract test; expect RED only for missing profile visuals.
- [ ] Implement deterministic profile variation for hair scale/offset, trouser color, eye material and body scale.
- [ ] Run resident actor contract + full tests; expect GREEN.
- [ ] Commit: `feat: add deterministic resident visual profiles`

### Task 2: Room Identity Props

**Files:**
- Modify: `scripts/presentation/world/household_blockout.gd`
- Modify: `tests/runtime/test_household_blockout_contract.gd`

**Interfaces:**
- Add grouped builders:
  - `_build_kitchen_details()`
  - `_build_living_details()`
  - `_build_bedroom_details()`
  - `_build_bathroom_details()`
  - `_build_hall_details()`
  - `_build_yard_details()`

- [ ] Write failing contract for all six room-detail builders and required visual containers/landmarks.
- [ ] Verify RED.
- [ ] Add lightweight primitive props without moving navigation/destination markers.
- [ ] Verify GREEN and navigation contract remains unchanged.
- [ ] Commit: `feat: add lived in household room props`

### Task 3: Materials, Lighting & Composition

**Files:**
- Modify: `scenes/debug/visual_showcase.tscn`
- Modify: `scripts/presentation/world/household_blockout.gd`
- Modify: `scripts/presentation/visual_simulation_shell.gd` if camera framing needs adjustment.
- Modify: runtime visual contracts only where interfaces change.

**Interfaces:**
- Room floor colors become warmer and more semantically distinct.
- Add restrained interior OmniLight3D nodes to the showcase.
- Preserve establishing and focused camera behavior.

- [ ] Add visual contract assertions for supported lights/camera nodes if needed.
- [ ] Render checkpoint and soak PNG.
- [ ] Tune only presentation values until silhouettes/rooms are readable without clipping.
- [ ] Run editor scan, runtime contracts and full suite.
- [ ] Commit: `feat: polish dollhouse materials lighting and framing`

### Task 4: Final Visual Checkpoint Gate

**Files:**
- Modify: `docs/architecture/visual-simulation-shell.md` or add Art Pass 03 section.
- Existing workflow: `.github/workflows/visual-checkpoint.yml`

**Interfaces:**
- Final automated artifacts:
  - `lifebox-visual-showcase.png`
  - `lifebox-visual-soak.png`

- [ ] Run Visual Checkpoint on final HEAD.
- [ ] Inspect both PNGs for clipped residents, unreadable rooms, blown lighting or broken HUD.
- [ ] Run Godot CI and Godot Headless Tests.
- [ ] Inspect logs for hidden `SCRIPT ERROR / ERROR / WARNING`.
- [ ] Document final visual architecture and deferred art work.
- [ ] Commit: `docs: record visual art pass 03 checkpoint`

## Self-Review

- **Spec coverage:** resident distinction, room props, materials/lights, camera readability and PNG verification all have explicit owners.
- **Step scan:** every task is independently reviewable and ends at a visual or contract gate.
- **Type consistency:** existing presentation APIs are preserved; only one new resident visual-profile API is introduced.
- **Review Focus:** navigation obstruction, deterministic variation, light blowout, camera occlusion and simulation authority are covered by Tasks 1–4.
- **Proportion:** no gameplay redesign is included; this remains a presentation-only pass.
