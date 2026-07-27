# Collision Contract Findings

This records M12 collision findings before any extraction decision.

## Stable Contract

The lab has a stable collision prototype boundary:

- Collision is chunk-owned and unloads with the chunk root.
- Collision consumes canonical `GeneratedWorldChunkRecord.topology_layers`
  plus an explicit movement policy.
- The current backend creates one `StaticBody3D` per chunk and one
  `BoxShape3D` shape owner per merged blocking rectangle or explicit walkable
  floor rectangle.
- Collision diagnostics report blocking cell count, merged shape count,
  merge ratio, cell counts by reason/layer, shape counts by reason/layer, and
  separate floor cell/shape counts when floor collision is enabled.

This proves that collision can be derived from formed products without changing
topology or streaming truth.

## Lab-Specific Implementation

These parts remain Godot World Lab details:

- `StaticBody3D`, `CollisionShape3D`, and `BoxShape3D` ownership.
- Collision height.
- Shape naming.
- Physics layer/mask defaults.
- Liquid/depth movement policy defaults.

Ground visual tiles do not imply blockers. Solid/minable cells block movement,
and liquid/depth cells block only when the lab policy says they do. The
world controller can request separate walkable floor collision from canonical
ground topology so rendered ground has physics without becoming a movement
blocker. The prototype is intentionally conservative. It proves lifecycle and
ownership, not final gameplay physics.

## Extraction Blockers

Do not move collision into `grid` or `spatial_streaming`.

The blockers are:

- `grid` should not know Godot physics resources.
- `spatial_streaming` should not know collision or renderer realization.
- The collision backend has not been validated against navigation, placed
  objects, mining, liquid traversal rules, or Runenwerk gameplay semantics.
- There is no neutral collision shape descriptor contract yet.

## Future Contract Candidate

A future neutral contract could be:

```text
terrain topology layers + collision policy -> chunk-local collision primitive descriptors
```

That contract would still not own Godot `StaticBody3D` nodes. The Godot adapter
would translate neutral descriptors into physics nodes.

## Critical Review

- Ownership: passed. Collision remains Godot lab realization.
- Lifecycle: passed. Collision is chunk-root-owned.
- Extraction readiness: blocked. A neutral collision descriptor may be useful
  later, but current proof is Godot-specific.
