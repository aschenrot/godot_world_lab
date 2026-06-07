# Placed Object Contract Findings

This records M12 placed-object findings before any extraction decision.

## Stable Contract

The lab has a useful separation:

- Terrain topology is represented by grid-derived visual descriptors.
- Placed objects are represented by `PlacedObjectDescriptor`.
- `PlacedObjectLayer` can rebuild independently from terrain visual buckets.
- Placed objects unload with chunk roots.

The minimum descriptor fields are stable enough for the lab:

```text
object_id
chunk_coord
local_position
asset_key
rotation_degrees_y
metadata
```

## Lab-Specific Implementation

These parts remain Godot World Lab details:

- The deterministic marker generator.
- `MeshInstance3D` realization.
- Descriptor metadata contents.
- Object naming.
- The use of the tile catalog's `debug` asset for lab markers.

Placed objects are not save-game records yet. They are runtime lab descriptors
used to prove separation from terrain topology.

## Extraction Blockers

Do not extract placed-object logic yet.

The blockers are:

- There is no durable identity or persistence contract.
- There is no asset catalog contract beyond the tile-kit manifest.
- There is no ECS, scene ownership, product, or editor contract.
- Overlay behavior and placed-object behavior have not been reconciled into a
  durable save/load model.
- Runenwerk object semantics are intentionally absent.

## Future Contract Candidate

A future neutral contract could define chunk-local placed-object descriptors,
but only after the lab proves:

- durable object identity
- asset references that are not tied to one Godot catalog
- editor mutation behavior
- save/load boundaries
- interaction with collision and overlays

## Critical Review

- Ownership: passed. Placed objects remain lab realization.
- Topology separation: passed. Terrain tile descriptors are not polluted by
  object placement.
- Extraction readiness: blocked. The separation is stable, but persistence and
  asset semantics are not.
