# Dynamic Day/Night Lighting Implementation Plan

1. Add a presentation-only DayNightController.
2. Bind it to the authoritative SimulationWorld.
3. Drive Environment background/ambient values from simulation hour.
4. Drive key/fill directional lights and indoor OmniLight energies.
5. Add phase text to the HUD status line.
6. Add runtime contract coverage for phase boundaries and light intensity relationships.
7. Run Godot CI/headless tests and capture the current midnight household.
