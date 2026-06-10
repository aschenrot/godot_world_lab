# Godot World Lab — World Generation Proof Roadmap

## Purpose

This roadmap defines the next Godot World Lab work for proving a flexible procedural world-generation pipeline.

The goal is not to hardcode one world type such as a cave, dungeon, hive, factory, or arena chain. The goal is to prove a general chunk-world generation flow that can later map cleanly into Runenwerk’s domain/procgen, world, asset, and formed-product architecture.

Godot World Lab remains the proof host. It may contain temporary Godot-specific implementation code, but reusable concepts must be documented before extraction.

---

## Current Boundary

### Godot World Lab owns

* Godot scenes
* debug UI
* generation experiments
* temporary world profile proof code
* tile mesh catalog proof code
* chunk visual builders
* collision formation prototypes
* provider/cache prototypes
* editor preview experiments

### Godot World Lab does not own

* reusable grid topology
* reusable chunk streaming policy
* final Runenwerk procgen graph contracts
* final Runenwerk SDF world truth
* save formats
* product semantics
* final asset import architecture
* Bevy adapter architecture

---

## Long-Term Direction

The proof should move toward this shape:

```text
WorldProfile
→ generation stages
→ layered chunk data
→ features
→ connectors
→ placement candidates
→ topology layers
→ visual/collision formed products
```

This should later map to Runenwerk as:

```text
Godot WorldProfile proof
→ future Runenwerk ProcgenProgram / graph-backed document

WorldLayer facts
→ future world/product query data

ChunkConnector
→ future world/procgen continuity contract

PlacementCandidate
→ future gameplay/spawn/encounter input

Visual and collision output
→ formed products, not authoritative world truth
```

---

## Milestone 1 — World Generation Contract

### File

```text
docs/proof-notes/world-generation-contract.md
```

### Goal

Define the proof vocabulary before continuing implementation.

### Include

* WorldProfile
* WorldLayer
* WorldFeature
* ChunkConnector
* PlacementCandidate
* GenerationStage
* GenerationDiagnostics

### Done When

The project has a clear document explaining what the generator produces, what it does not own, and how the proof maps toward Runenwerk later.

---

## Milestone 2 — Temporary WorldProfile

### File

```text
scripts/world_generation/world_profile.gd
```

### Goal

Introduce a temporary Godot-side `WorldProfile` concept.

This is not the final Runenwerk model. It is a proof object for organizing generation settings.

### Should Contain

* profile_id
* chunk_size
* seed behavior
* noise settings
* layer settings
* feature settings
* connector settings
* walkability settings
* debug settings

### Done When

`chunk_provider.gd` can be described as evaluating a `WorldProfile` into generated chunk data.

---

## Milestone 3 — Refactor Generation Into Named Stages

### File

```text
scripts/chunk_provider.gd
```

### Main Method

```text
generate_chunk_generation_result(...)
```

### Goal

Keep current behavior, but organize it as a generic pipeline.

### Target Stage Shape

```text
sample_base_fields
classify_world_layers
apply_world_features
apply_chunk_connectors
repair_connectivity
derive_topology_layers
build_generation_diagnostics
```

### Done When

The generator reads like a staged world-generation pipeline instead of one hardcoded generator.

---

## Milestone 4 — World-Space Consistency

### File

```text
scripts/chunk_provider.gd
```

### Focus Methods

```text
_balance_walkable_percent(...)
_sorted_cells_by_hash(...)
_initial_solid_cell(...)
_generate_base_terrain_cells(...)
```

### Goal

All deterministic terrain decisions should use world-space coordinates where appropriate.

### Problem To Fix

Some balancing/repair logic may still use local cell coordinates, which can repeat the same pattern in every chunk.

### Done When

Noise, balancing, repair, and placement ordering do not rely on local-only coordinates for global decisions.

---

## Milestone 5 — ChunkConnector Contract

### File

```text
scripts/chunk_provider.gd
```

### Goal

Add a generic chunk continuity concept.

A connector can represent:

* road continuation
* river continuation
* corridor continuation
* cave tunnel continuation
* biome transition
* arena entrance
* generated path continuation

### Suggested Helper Methods

```text
_connector_points_for_chunk(...)
_shared_connector_for_edge(...)
_apply_chunk_connectors(...)
```

### Done When

Neighbor chunks can agree on shared exits or continuation points.

---

## Milestone 6 — Generalize Rooms And Paths Into WorldFeature

### File

```text
scripts/chunk_provider.gd
```

### Current Methods To Evolve

```text
_carve_rooms_and_paths(...)
_room_rects_for_chunk(...)
_carve_path(...)
_carve_rect(...)
```

### Goal

Treat rooms and paths as one kind of generic feature, not as the whole generator model.

### Generic Feature Types

* open_area
* corridor
* barrier
* liquid_pool
* resource_cluster
* arena
* landmark
* spawn_zone
* transition

### Done When

Diagnostics and generated data speak in terms of features, not only hardcoded rooms and paths.

---

## Milestone 7 — Placement Candidates

### File

```text
scripts/chunk_provider.gd
```

### Goal

Generation should suggest valid placement locations without spawning gameplay objects directly.

### Candidate Types

* spawn_candidate
* resource_candidate
* landmark_candidate
* cover_candidate
* hazard_candidate
* entrance_candidate
* exit_candidate

### Boundary Rule

World generation suggests valid places. Gameplay systems decide what actually spawns.

### Done When

Generated chunk data exposes placement candidates separately from debug markers.

---

## Milestone 8 — Stage Diagnostics

### File

```text
scripts/chunk_provider.gd
```

### Goal

Make generation inspectable.

### Diagnostics Should Include

* profile id
* generation version
* settings hash
* base field stats
* layer counts
* feature counts
* connector counts
* placement candidate counts
* walkable percentage
* sampled neighbor chunk count
* formation sample cache count

### Done When

A bad generated chunk can be debugged by stage instead of by guessing.

---

## Milestone 9 — Formation Sample Cache Bounds

### File

```text
scripts/chunk_provider.gd
```

### Goal

Prevent infinite streaming from growing generation sampling caches forever.

### Add Concepts

```text
max_formation_sample_cache_entries
last_generation_settings_hash
_prune_formation_sample_cache(...)
_clear_generation_transient_caches_if_settings_changed(...)
```

### Done When

Flying through the world for a long time does not continuously increase formation sample cache size.

---

## Milestone 10 — Keep Visuals And Collision Derived

### Files

```text
scripts/chunk_visual_builder.gd
scripts/collision/chunk_collision_builder.gd
```

### Rule

Generation outputs world facts.

Visuals and collision are formed from those facts.

### Generation May Output

* layers
* features
* connectors
* placement candidates
* diagnostics

### Generation Must Not Own

* Godot Mesh
* Godot Material
* StaticBody3D
* CollisionShape3D
* MultiMeshInstance3D
* PackedScene runtime ownership

### Done When

`chunk_provider.gd` remains world-data-oriented, while visual and collision systems remain derived product builders.

---

## Execution Order

```text
1. Create world-generation-contract.md
2. Add world_profile.gd
3. Refactor chunk_provider.gd into named stages
4. Fix world-space consistency
5. Add ChunkConnector helpers
6. Generalize rooms/paths into WorldFeature terminology
7. Add placement candidates
8. Add stage diagnostics
9. Bound formation sample cache
10. Only then continue visual/collision hardening
```

---

## Non-Goals For This Roadmap

Do not do these during this roadmap:

* no new Crystonix/asset repo
* no Bevy adapter
* no Runenwerk integration
* no full graph editor
* no SDF rewrite
* no save system
* no enemy spawning
* no final gameplay loop
* no final procgen graph schema

---

## Success Criteria

This roadmap is complete when the Godot lab can prove:

```text
A profile-driven chunk generator can produce continuous streamed world data,
with generic layers, features, connectors, placement candidates, diagnostics,
and derived visual/collision products.
```

The result should be flexible enough to support many future world types, while still remaining a Godot-side proof instead of premature Runenwerk architecture.
