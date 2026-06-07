# Roadmap

This roadmap starts after the first formation-proof sequence:

```text
Authored -> Normalized -> Formed -> Instantiated -> Simulated -> Expressed / Observed
```

M0-M14 are implemented in the current proof slice. M15-M17 are future work only.

## Execution Rules

- Each milestone must preserve the ownership boundary:
  - `grid` owns topology truth.
  - `spatial_streaming` owns lifecycle truth.
  - `godot_world_lab` owns Godot realization.
- A milestone is not done until there is a smoke test or explicit manual proof
  that exercises the transition it claims to prove.
- Editor conveniences may be added, but they must consume formed products; they
  must not become runtime truth.
- Any extraction decision needs findings first. Do not move code out of the lab
  because it is interesting; move it only after the contract is stable.

## Current Proof Baseline

- M0 documents the lab contract.
- M1 generates seamless chunk-local logic from absolute world cells.
- M2 exposes callable runtime diagnostics.
- M3 makes `GeneratedChunkData`, `ChunkVisualPlan`, and
  `ChunkInstantiationPlan` explicit.
- M4 adds a debug movement playground that drives streaming focus.
- M5 proves authored tile-kit source archival and normalized GLB import.
- M6 loads authored GLB meshes at runtime through `TileMeshCatalog`.
- M7 adds observation previews for catalog and generated chunk products.
- M8 adds chunk-owned box collision derived from visual descriptors.
- M9 adds a placed object layer separate from terrain topology.
- M10 adds in-memory chunk overlays that survive unload/reload.
- M11 improves lab generation quality and cache/version diagnostics.
- M12 records extraction findings for assets, generation, collision, and placed
  objects before any reusable code is moved.
- M13 extracts only payload-neutral spatial hash helpers into
  `spatial_streaming/crates/spatial/src/hash`.
- M14 keeps the Godot lab generator in the lab and documents the blocked
  extraction gate for `grid_generation`.

## M5 - Tile-Kit Authoring / Import Proof

Status: complete for the current proof. See `docs/tile-kit-import-proof.md`.

- Add `assets/source/tiles/dual_grid_tiles.blend`.
- Add `assets/tiles/dual_grid_tiles.glb`.
- Update `docs/mesh-authoring-guide.md`.
- Base meshes: `corner`, `edge`, `t`, `diagonal`, `full`, `debug`.
- No authored rotated variants; rotations remain descriptor-driven.

## M6 - Runtime Authored Visuals

Status: complete for the current proof. See `docs/runtime-authored-visuals.md`.

- Load imported authored meshes through `TileMeshCatalog`.
- Keep `ChunkVisualBuilder` as the runtime realization path.
- Keep `MultiMeshInstance3D` buckets as the first runtime backend.
- Do not make `GridMap` or `MeshLibrary` runtime truth.

Done when authored GLB meshes replace fallback debug meshes without changing
`ChunkVisualPlan` or streaming lifecycle contracts.

## M7 - Observation / Editor Previews

Status: complete for the current proof. See `docs/observation-previews.md`.

- Add tile catalog preview.
- Add generated chunk preview.
- Add missing asset/material diagnostics.

Done when previews consume the same catalog, generator config, and formed plans
as runtime, with no duplicate topology or lifecycle logic in preview scripts.

## M8 - Collision Prototype

Status: complete for the current proof. See `docs/collision-prototype.md`.

- Add `chunk_collision_builder.gd`.
- First backend: chunk-owned `StaticBody3D` with simple box collision derived
  from tile descriptors.
- Do not put collision in `grid` or `spatial_streaming`.

Done when collision is built from formed visual/topology data and unloaded with
the chunk root, without leaking collision nodes across stream-out.

## M9 - Placed Asset Layer

Status: complete for the current proof. See `docs/placed-object-layer.md`.

- Add `PlacedObjectLayer`.
- Add `PlacedObjectDescriptor`.
- Keep placed objects separate from terrain tile topology.

Done when terrain tiles and placed objects can be rebuilt independently inside a
resident chunk.

## M10 - Chunk Overlay Sandbox

Status: complete for the current proof. See `docs/chunk-overlay-sandbox.md`.

- Support chunk-local overlays that survive unload/reload inside the lab
  session.
- Do not add a full save-game format yet.

Done when overlays survive lab unload/reload through an in-memory session store,
and the roadmap still explicitly defers durable save/load.

## M11 - Procedural Generation Quality Pass

Status: complete for the current proof. See `docs/procedural-generation-quality.md`.

- Improve hash/noise quality.
- Add smoothing.
- Add room/path carving.
- Define generator version behavior.
- Add debug markers.

Done when generator version changes are observable through diagnostics and do
not silently reuse stale cached chunk data.

## M12 - Findings Docs Before Extraction

Status: complete for the current proof.

- Add `asset-contract-findings.md`.
- Add `generation-contract-findings.md`.
- Add `collision-contract-findings.md`.
- Add `placed-object-contract-findings.md`.

Done when each findings doc states what stayed lab-specific, what became stable,
and what still blocks extraction.

## M13 - Extract Neutral Spatial Hash Only If Proven

Status: complete for the current proof.

- Likely location: `spatial_streaming/crates/spatial/src/hash/mod.rs`.
- Do not extract generation rules.

The extracted API is limited to deterministic integer coordinate hashing and
bucket mapping. It does not own wall thresholds, smoothing, rooms, paths, debug
markers, tile descriptors, SDF, ECS, assets, providers, or Runenwerk semantics.

## M14 - Extract Reusable Generation Only If Stable

Status: complete for the current proof. Extraction is deliberately deferred.

- Likely location: `grid/crates/grid_generation`.
- Do not include Godot or Runenwerk semantics.

`Crystonix/grid` already contains optional neutral `grid_generation` helpers,
but the Godot lab generator is still lab-specific. It is not moved until a
neutral cell schema, typed settings contract, deterministic tests, and a second
consumer need prove the reusable boundary.

## M15 - Asset Extraction Decision

- Do not automatically create `Crystonix/asset`.
- Choose one of:
  - no extraction
  - tilekit manifest only
  - minimal `asset_core` + `asset_tilekit`

## M16 - Godot Asset Adapter Only If Asset Contracts Exist

- GLB/glTF bridge.
- Godot catalog generation.
- `MeshLibrary` import/editor artifact if useful.
- No runtime world truth.

## M17 - Reconnect Runenwerk

Reconnect Runenwerk only after the lab proves:

- streaming
- generation
- visuals
- movement
- collision prototype
- placed assets
- diagnostics
- previews
- findings docs

Runenwerk integration must not move SDF, ECS, product, procgen, renderer,
editor, save, or app semantics into `grid`, `spatial_streaming`, or
`godot_world_lab`.

## Global Non-Goals

- Do not create `Crystonix/asset`.
- Do not extract generation.
- Do not integrate Runenwerk.
- Do not add SDF.
- Do not add ECS.
- Do not add networking.
- Do not add save/load.
- Do not add a procgen graph.
- Do not add production ArrayMesh merging.
- Do not make `GridMap` or `MeshLibrary` runtime truth.
- Keep topology truth in `grid`.
- Keep streaming lifecycle truth in `spatial_streaming`.
- Keep Godot realization in `godot_world_lab`.
