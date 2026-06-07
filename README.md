# Godot World Lab

Godot World Lab proves chunk streaming, grid descriptor conversion, and chunk
visual realization before Runenwerk feature integration resumes.

This repository owns Godot-specific realization:

- scenes and debug UI
- chunk generation experiments
- mesh assets and material catalogs
- chunk visual builders
- host-owned async provider and cache prototypes

It does not own reusable topology, streaming lifecycle policy, Runenwerk SDF,
ECS spawning, renderer resources outside Godot, save formats, product semantics,
or procgen graph contracts.

## Reusable Inputs

- `Crystonix/grid` owns local grid math, storage, dual-grid topology,
  descriptor classification, and dirty-cell invalidation.
- `Crystonix/spatial_streaming` owns world coordinates, desired chunk residency,
  request/event lifecycle control, and the Godot streaming adapter.

## Native Addons

Build the addon crates from their source repositories, then copy the debug
libraries into:

```text
addons/godot_grid/bin/
addons/godot_world_streaming/bin/
```

The binaries are intentionally ignored by Git.

