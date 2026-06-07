# Collision Prototype

This records M8 of the current roadmap: chunk-owned collision prototype.

## Runtime Shape

```text
ChunkVisual
  MultiMeshInstance3D buckets
  StaticBody3D ChunkCollision
    CollisionShape3D TileCollision_x_y
```

`scripts/collision/chunk_collision_builder.gd` builds a chunk-owned
`StaticBody3D` from `ChunkVisualPlan.visual_tiles`. Each non-empty visual tile
gets one simple `BoxShape3D` collision shape.

Collision is a Godot realization prototype. It is not owned by `grid` or
`spatial_streaming`, and it does not change topology, residency, generation, or
visual descriptor contracts.

## Lifecycle

`scripts/world_controller.gd` attaches collision to each resident chunk visual
root when `enable_collision_prototype` is true. Existing unload/pooling cleanup
removes collision with the chunk root, so collision nodes do not outlive active
visual roots.

## Critical Review

- Ownership: passed. Collision code is entirely in `godot_world_lab`.
- Source of truth: passed. Collision consumes `ChunkVisualPlan`; it does not
  derive new topology rules from Godot nodes or meshes.
- Lifecycle: passed. Collision is child-owned by chunk roots and removed by the
  existing unload/pool path.
- Scope: passed. This is a simple box backend only; no physics gameplay,
  navigation, save/load, ECS, or reusable collision extraction was added.

## Validation

```sh
godot --headless --path . --script tests/chunk_collision_smoke.gd
```
