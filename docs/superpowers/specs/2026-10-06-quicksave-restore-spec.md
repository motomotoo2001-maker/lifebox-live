# LIFEBOX LIVE — Quicksave & Restore Specification

## Goal

Expose the existing deterministic persistence system to the playable household shell.

## Player flow

- SAVE writes the current authoritative SimulationWorld to user://lifebox_quicksave.save.
- LOAD restores that snapshot into the existing world topology and rebinds presentation actors.
- Ctrl+S and Ctrl+L mirror the buttons.
- The selected resident is preserved across a successful load when that resident still exists.
- Missing/corrupt saves fail safely and show a HUD message.

## Persistence boundary

The feature uses only:
- WorldSnapshotCodec.encode/restore;
- SaveSchema.create_envelope;
- SaveService atomic save/load.

No presentation-only camera or HUD state is added to the simulation snapshot.

## Definition of Done

- authored SAVE and LOAD buttons exist;
- HUD emits save/load requests;
- bootstrap performs validated save and restore;
- presentation is rebound after restore;
- load failure does not mutate the world;
- existing persistence tests remain green;
- real viewport checkpoint contains save/load controls.
