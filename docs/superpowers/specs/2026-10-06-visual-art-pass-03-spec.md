# LIFEBOX LIVE — Visual Art Pass 03 Specification

## Goal

Upgrade the existing 9:16 Godot visual shell from a readable blockout into a more lived-in stylized dollhouse without changing simulation authority.

## Current baseline

The verified Art Pass 02 already has:
- six visible low-poly residents;
- arms, legs, head, hair, nose and idle/walk motion;
- six-room cutaway layout;
- fridge, sofa, shower and six beds;
- vertical 9:16 camera/HUD;
- automated Visual Checkpoint PNGs.

## Art Pass 03 scope

### Resident readability

Residents must remain lightweight but become visually distinct at a glance.

Add:
- separate shirt/body and trouser/leg treatment;
- eyes;
- deterministic hair silhouette variation;
- deterministic clothing secondary color variation;
- subtle scale/stance variation;
- preserve existing per-resident primary color and movement behavior.

No skeletal animation or imported character pack in this pass.

### Household readability

Each major room should communicate its role without labels.

Add stylized low-poly props:
- Kitchen: counter run, cabinet fronts, table/stools.
- Living: rug, coffee table, TV/media unit.
- Bedroom: bedside furniture/decor around existing beds.
- Bathroom: sink/vanity and toilet silhouette around existing shower.
- Hall: console/plant or similar landmark.
- Yard: planter/bench/greenery.

Props must remain static presentation only.

### Materials and lighting

Improve visual separation without expensive rendering features.

Use:
- warmer room-specific floor palettes;
- restrained accent colors;
- soft local point/omni lights for interior warmth;
- existing directional key/fill preserved for stable CI rendering;
- no post-processing dependency that breaks gl_compatibility.

### Camera/readability

Keep the existing vertical composition, but improve framing if needed so:
- all rooms remain readable in establishing view;
- resident silhouettes do not disappear behind wall segments;
- focused camera still preserves context.

### Verification

- Existing gameplay/simulation suites remain unchanged.
- ResidentActor3D runtime contract expands for new visual nodes/profile API.
- HouseholdBlockout runtime contract expands for new prop groups/build methods.
- Visual Checkpoint must render both checkpoint and soak PNGs.
- Final screenshot must be materially more readable than Art Pass 02 while preserving deterministic scene output.

## Non-goals

- final production character models;
- skeletal animation;
- texture atlas pipeline;
- Blender-authored environment;
- Story Director camera cinematics;
- TikTok overlay art.
