# Runenwerk Reconnect

This records M17: reconnect Runenwerk after the Godot proof.

## What Reconnected

Runenwerk now has a thin `domain/world_streaming` wrapper around
`Crystonix/spatial_streaming/crates/world_streaming`, matching its existing
wrapper pattern for `domain/spatial`, `domain/spatial_index`, and
`domain/chunking`.

The reconnect is intentionally narrow:

- Runenwerk can name the payload-neutral lifecycle controller as a domain crate.
- The wrapper re-exports stream requests, provider events, lifecycle events,
  budgets, priorities, and lifecycle states.
- Runenwerk docs now identify `world_streaming` as lifecycle truth.

## What Did Not Move

The reconnect does not move Godot lab systems into Runenwerk:

- generated tile/world experiments;
- Blender tile kit assets;
- `TileMeshCatalog`;
- chunk visual builders;
- collision prototype nodes;
- placed-object prototype nodes;
- overlay sandbox state;
- preview scenes or debug UI.

The reconnect also does not move Runenwerk platform semantics into reusable
repos:

- `world_ops` stays owner of edits, dirty regions, build queues, and
  replication deltas.
- `world_sdf` stays owner of SDF chunk/page payloads and collision summaries.
- `product` stays owner of formed product descriptors and publication.
- `procgen` stays owner of procedural documents and lowering policy.
- `engine` stays owner of runtime scheduling and resource composition.

## Why This Is The Correct First Reconnect

The Godot lab proved streaming, generated chunks, visual descriptors, MultiMesh
visuals, unload/pooling behavior, dirty updates, asset catalog diagnostics,
collision prototypes, placed assets, overlays, previews, and extraction
findings.

That proof is enough to let Runenwerk consume the neutral lifecycle crate. It is
not enough to replace Runenwerk's SDF-first field-product platform or engine
chunk build lifecycle in one step.

## Next Integration Gate

Future Runenwerk integration should use a strangler migration:

1. Keep the existing engine chunk lifecycle path.
2. Add one host/provider proof that drives `WorldStreamingController`.
3. Translate lifecycle events into existing engine runtime records.
4. Prove request order, provider completion, unload cleanup, dirty/build
   interaction, and replication behavior.
5. Only then replace or narrow the old engine lifecycle path.

## Critical Review

- Ownership: passed. Runenwerk consumes lifecycle truth without absorbing Godot
  realization or asset systems.
- SDF/product boundary: passed. No SDF, product, procgen, renderer, save/load,
  ECS, or app semantics moved.
- Migration safety: passed. Existing engine lifecycle remains intact.
- Known risk: broad Runenwerk workspace check currently fails in unrelated UI
  runtime imports, so M17 validation uses focused crate and docs gates.
