# Save / Load UI Implementation Plan

1. Add SAVE and LOAD buttons to the bottom event panel.
2. Add persistence request signals to VisualHUD.
3. Add quick_save(), quick_load(), has_quicksave() to the playable bootstrap.
4. Use WorldSnapshotCodec + SaveSchema + SaveService for the only disk path.
5. Rebind the visual shell after successful restore and preserve resident selection.
6. Add Ctrl+S / Ctrl+L shortcuts.
7. Add runtime contract coverage, run the full Godot suite, and capture a new 9:16 checkpoint.
