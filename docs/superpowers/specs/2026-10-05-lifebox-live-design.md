# LIFEBOX LIVE — Design Specification

## Product vision
LIFEBOX LIVE is an autonomous 9:16 3D life simulation for live streaming. Six adult AI residents live continuously without a human host. Viewers influence fate through gifts, likes, and chat without directly controlling characters.

## Vertical slice
- One modular dollhouse with four functional rooms, yard, and a short street segment.
- Six adult residents.
- Needs: hunger, energy, hygiene, comfort, social, mood.
- Money, jobs, personal spending, relationships, and significant memories.
- 20+ autonomous actions through SmartObjects.
- 30+ context-validated Fate events.
- Story Director, automatic camera, 9:16 HUD.
- Save/restore, accelerated simulation, headless testing.
- Replaceable Live Bridge with mock/replay/provider adapters.

## Architecture
Simulation is independent from rendering FPS and external LLMs. Utility AI handles minute-to-minute behavior. LLM use is optional and limited to higher-level goals, short dialogue, and rare story decisions. TikTok-specific transport is isolated behind a normalized LiveEvent interface.

## Reliability
The world must survive network/LLM outages, reconnect live transport, deduplicate event IDs, bound queues, recover stuck actions, autosave atomically, and support deterministic fixed-seed replay.

## Vertical-slice definition of done
1. Six residents live autonomously for at least two real-time hours.
2. Accelerated headless test completes 8+ simulation hours without deadlock.
3. At least 20 SmartObject actions work.
4. At least 30 Fate events respect context and cooldowns.
5. Mock and production live providers share the same event contract.
6. Story/camera directors produce stable, readable 9:16 presentation.
7. Save/restart restores equivalent world state.
8. LLM outage does not stop the simulation.
9. Godot 4.7.2 headless smoke test is reproducible.

## Development order
Simulation foundation → household → persistence/replay → Fate/live interaction → story/presentation → art/animation/audio → production provider → soak/performance/release.
