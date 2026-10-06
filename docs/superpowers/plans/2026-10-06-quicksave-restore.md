# Quicksave & Restore Implementation Plan

1. Add SAVE/LOAD controls to the event HUD.
2. Add HUD signals and keyboard shortcuts.
3. Encode SimulationWorld through WorldSnapshotCodec and SaveSchema.
4. Save atomically with SaveService.
5. Restore into the existing SmartObject topology and rebind the visual shell.
6. Extend HUD/showcase contracts.
7. Run full tests and capture a viewport checkpoint.
