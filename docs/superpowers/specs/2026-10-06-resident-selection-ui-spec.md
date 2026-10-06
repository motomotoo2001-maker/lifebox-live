# LIFEBOX LIVE — Resident Selection & UI Specification

## Goal

Turn the visual simulation from a passive showcase into an inspectable life-sim view. The player must be able to select any resident, see who is selected, inspect readable needs, and temporarily focus the camera on that resident without changing simulation authority.

## Interaction

- Click a resident to select them.
- Number keys 1–6 select residents deterministically.
- Space toggles presentation-side simulation advance/pause.
- Selection never mutates needs, goals, relationships, schedules, jobs, actions, RNG or movement authority.

## Resident feedback

- Selected resident displays a visible ground marker.
- Existing name/activity labels remain readable.
- Selection is presentation-only and can be changed at any time.

## Camera

- Selecting a resident gives a short manual camera focus.
- Autonomous camera direction resumes automatically after the manual focus window.
- Manual focus does not affect simulation state.

## HUD

- Clearly show selected resident name and money.
- Label Hunger, Energy, Social and Mood bars.
- Show Pause/Running state in the top status.
- Add a compact control hint for click / 1–6 / Space.

## Definition of Done

- mouse selection works through an Area3D pick target;
- number-key selection works;
- Space pause toggle works;
- selected resident marker updates correctly;
- HUD labels all need bars;
- camera manual focus is deterministic and temporary;
- validation checks selected resident ownership;
- all existing tests stay green;
- 9:16 visual capture remains valid.
