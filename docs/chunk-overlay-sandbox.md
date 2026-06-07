# Chunk Overlay Sandbox

This records M10 of the current roadmap: chunk-local overlay sandbox.

## Contract

```text
scripts/overlays/chunk_overlay_sandbox.gd
```

The overlay sandbox stores chunk-local dictionaries in memory for the current lab
session. It can attach a `ChunkOverlay` node to a resident chunk root and reapply
that overlay when the chunk unloads and reloads.

This is deliberately not a save-game system. It performs no filesystem IO and
defines no durable serialization format.

## Runtime Shape

```text
ChunkVisual
  MultiMeshInstance3D terrain buckets
  StaticBody3D ChunkCollision
  Node3D PlacedObjectLayer
  Node3D ChunkOverlay
```

Overlay state is separate from terrain topology, placed-object descriptors, and
streaming lifecycle state.

## Critical Review

- Ownership: passed. Overlay state is a Godot-lab session prototype only.
- Lifecycle: passed. Overlay nodes unload with chunk roots, while in-memory
  overlay data survives inside the lab controller and reapplies on reload.
- Scope: passed. No save/load format, filesystem persistence, networking, ECS,
  or Runenwerk integration was added.
- Extraction: passed. No overlay logic moved to `grid` or `spatial_streaming`.

## Validation

```sh
godot --headless --path . --script tests/chunk_overlay_sandbox_smoke.gd
```
