# LIFEBOX LIVE — Save / Load UI Specification

## Goal

Expose the already deterministic persistence layer through the playable household interface.

## UX

- SAVE writes one quick-save slot.
- LOAD restores the latest valid quick-save and is disabled when neither the main save nor backup exists.
- Ctrl+S and Ctrl+L mirror the buttons.
- The event feed reports save/load success or failure.
- The previously selected resident is reselected after load when still present.

## Persistence boundary

- Simulation data is encoded with WorldSnapshotCodec.
- SaveSchema owns the envelope.
- SaveService owns atomic disk write and backup fallback.
- Loading restores into the existing SimulationWorld topology before the presentation shell is rebound.
- Presentation-only camera/HUD transient state is intentionally not persisted.

## Definition of Done

- authored SAVE and LOAD controls;
- HUD save_requested/load_requested signals;
- one quick-save path under user://;
- atomic SaveService is used rather than direct JSON writing;
- load rebinds actors to restored authoritative resident state;
- load button availability reflects main or backup save presence;
- contract suite and full headless regression are green.
