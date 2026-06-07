# Placed Object Layer

This records M9 of the current roadmap: placed asset layer.

## Contracts

```text
scripts/placed/placed_object_descriptor.gd
scripts/placed/placed_object_layer.gd
```

`PlacedObjectDescriptor` describes a chunk-local object independently from
terrain topology:

```text
object_id
chunk_coord
local_position
asset_key
rotation_degrees_y
metadata
```

`PlacedObjectLayer` realizes descriptors as Godot nodes under a chunk root. It
does not change `GeneratedChunkData`, `ChunkVisualPlan`,
`ChunkInstantiationPlan`, or streaming lifecycle state.

## Runtime Shape

```text
ChunkVisual
  MultiMeshInstance3D terrain buckets
  StaticBody3D ChunkCollision
  Node3D PlacedObjectLayer
    MeshInstance3D Placed_*
```

The layer can be rebuilt independently from terrain visuals.

## Critical Review

- Ownership: passed. Placed objects are a Godot-lab realization prototype.
- Topology separation: passed. Placed objects do not participate in dual-grid
  tile descriptors or dirty-cell topology.
- Lifecycle: passed. The placed layer is child-owned by chunk roots and removed
  with unload/pooling cleanup.
- Scope: passed. No save/load, ECS, product semantics, asset extraction, or
  Runenwerk integration was added.

## Validation

```sh
godot --headless --path . --script tests/placed_object_layer_smoke.gd
```
