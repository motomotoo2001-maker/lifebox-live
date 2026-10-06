# LIFEBOX LIVE — Time of Day & Resident Details Specification

## Goal

Make the household feel more alive over time and make resident inspection meaningfully informative.

## Time-of-day visuals

The presentation layer derives lighting only from SimulationClock:
- night uses a dark blue environment, low moon-like key light, stronger indoor lamps;
- daytime raises sky brightness and warm daylight while indoor lamps recede;
- transitions are deterministic from simulation time;
- lighting never mutates simulation state.

## Resident details

The selected resident card shows all six authored needs:
- hunger;
- energy;
- hygiene;
- comfort;
- social;
- mood.

It also shows:
- closest known resident by affinity with tension;
- job pay rate;
- episodic memory count;
- current action, schedule, goal and money.

## Definition of Done

- six need bars are visible and readable;
- social/job/memory summaries update from authoritative state;
- time-of-day presentation updates every frame from SimulationClock;
- visual showcase contract covers lighting nodes/controller method;
- full Godot suite remains green;
- 9:16 viewport checkpoint is captured.
