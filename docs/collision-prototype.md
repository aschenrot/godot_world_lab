# Collision Prototype

This records M8 of the current roadmap: chunk-owned collision prototype.

## Runtime Shape

```text
ChunkVisual
  MultiMeshInstance3D buckets
  StaticBody3D ChunkCollision
    CollisionShape3D CellCollision_x_y
```

`scripts/collision/chunk_collision_builder.gd` builds a chunk-owned
`StaticBody3D` from `GeneratedChunkData.topology_layers` and an explicit
movement policy. Solid/minable cells block movement. Liquid/depth cells block
only when `liquid_blocks_movement` is true. Ground visual tiles never imply
collision.

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
- Source of truth: passed. Collision consumes generated topology layers and
  policy; it does not derive blockers from Godot nodes, meshes, or visual
  descriptor count.
- Lifecycle: passed. Collision is child-owned by chunk roots and removed by the
  existing unload/pool path.
- Scope: passed. This is a simple box backend only; no physics gameplay,
  navigation, save/load, ECS, or reusable collision extraction was added.

## Validation

```sh
godot --headless --path . --script tests/chunk_collision_smoke.gd
```
