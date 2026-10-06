# LIFEBOX LIVE — Room-aware Navigation Specification

## Goal

Stop residents from treating the apartment as one open rectangle. Navigation must respect the six-room walls and route through the authored hallway door openings.

## Layout model

The household is represented as:
- three back rooms;
- three front rooms;
- one continuous central hallway;
- three back doorway connectors;
- three front doorway connectors;
- vertical divider wall strips outside the hallway.

The generated NavigationMesh is presentation navigation only. Simulation movement intent remains authoritative and continues to contain only logical destination and arrival radius.

## Constraints

- CharacterBody3D / NavigationAgent3D contract is unchanged.
- Navigation mesh is built deterministically from fixed coordinates.
- Solid vertical room separators have no navigation polygons.
- Solid horizontal wall bands have no navigation polygons except at the three authored doorway spans.
- Hallway remains fully connected left-to-right.

## Definition of Done

- runtime NavigationRegion3D receives the room-aware NavigationMesh;
- doorway cells are navigable;
- wall-strip cells are excluded;
- authored mesh contains enough polygons to represent rooms, hall, and connectors;
- all existing movement/soak tests remain green;
- visual capture succeeds with residents still reaching household SmartObjects.
