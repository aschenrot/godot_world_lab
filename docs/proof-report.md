# Godot Proof Report

This report records the Godot proof completed before Runenwerk feature
integration.

## Completed Proof

| Milestone | Evidence |
| --- | --- |
| M2 Godot lab scaffold | `55d8c97 Create Godot world lab scaffold` |
| M3 streaming debug boxes | `e3084b0 Prove streaming debug chunk boxes` |
| M4 deterministic generation | `11fc3fe Add deterministic chunk generation` |
| M5 grid descriptor conversion | `bf5deb3 Convert generated grids to visual plans` |
| M6 MultiMesh visuals | `0c95658 Build MultiMesh chunk visuals` |
| M7 unload/pooling/budget pressure | `84c4891 Prove chunk visual pooling under budget pressure` |
| M8 async provider/cache | `e033c4a Add host-owned async provider cache` |
| M9 dirty-cell updates | `ec19e1e Add dirty cell visual updates` |
| M10 catalog variants | `e019827 Add catalog variant validation` |
| M11 optional ArrayMesh backend | `90fdc84 Add optional ArrayMesh visual backend` |

Supporting reusable-crate commits:

```text
Crystonix/spatial_streaming
  5a1b37b Harden world streaming lifecycle semantics

Crystonix/grid
  00b3512 Add Godot grid asset key resolver
  f187956 Expose Godot grid visual tile conversion
  af5f8c4 Expose Godot dirty visual tile conversion
```

## Validation Commands

```text
godot --headless --path . --script tests/chunk_generation_smoke.gd
godot --headless --path . --script tests/streaming_debug_smoke.gd
godot --headless --path . --script tests/visual_plan_smoke.gd
godot --headless --path . --script tests/multimesh_visual_smoke.gd
godot --headless --path . --script tests/pooling_budget_smoke.gd
godot --headless --path . --script tests/async_cache_smoke.gd
godot --headless --path . --script tests/dirty_update_smoke.gd
godot --headless --path . --script tests/catalog_variant_smoke.gd
godot --headless --path . --script tests/array_mesh_backend_smoke.gd
godot --headless --path . --quit
```

## Boundary Result

```text
grid
  owns topology, descriptors, dirty-corner math, and Godot value mapping.

spatial_streaming
  owns payload-neutral chunk residency lifecycle and request/event state.

godot_world_lab
  owns Godot generation experiments, provider delay, cache prototype, meshes,
  materials, catalogs, visual builders, pooling, scenes, and tests.
```

Runenwerk was not modified. Feature integration remains a separate future step.
That future step may consume `grid` and `spatial_streaming`, but must keep SDF,
ECS, product, procgen, editor, renderer, save format, and app semantics inside
Runenwerk.

