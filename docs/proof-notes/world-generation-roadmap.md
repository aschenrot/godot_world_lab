# Godot World Lab — World Generation Roadmap

## Purpose

This roadmap defines the long-term procedural world-generation proof for `godot_world_lab`.

The target is not one specific world type such as a cave, continent, dungeon, hive, arena chain, factory, or overworld. The target is a deterministic, data-first proof pipeline that can support many world shapes without turning Godot Lab into a reusable engine too early.

Godot Lab remains the proof host. Reusable contracts must be documented and proven before extraction is considered.

```text
WorldDefinition
→ WorldDefinitionSnapshot
→ GenerationContext
→ GenerationPipeline
→ GeneratedWorldChunk
→ TopologyProjectionSet
→ FormationProductSet
→ Godot realization
```

Generation produces generated world facts. It does not create Godot nodes, meshes, collision objects, scenes, save records, ECS entities, Runenwerk SDF payloads, or gameplay spawns.

---

## Current Implementation Status

```text
M0.1 complete
M0.2 complete
M1 complete
M2 complete
M3 complete
M4 complete
M5 complete for the legacy-wrap migration gate
M6 complete for the compatibility adapter migration gate
Current migration gate complete: hash hardening, smoke tests, provider pipeline wiring
Next gate: begin M7+ only after review; do not remove legacy generation yet
```

The migration gate passed with:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
```

The initial docs-only package is complete. The roadmap must no longer be read as if no runtime scaffolding exists yet. M7+ semantic, topology, formation, cache, or extraction work remains review-gated.

M5 completion does not mean legacy generation has been deleted. It means the public provider path now routes through `GenerationPipeline` while the legacy generator remains isolated behind `LegacyChunkGenerationStage` and `_generate_legacy_chunk_generation_result(...)`.

M6 completion does not mean final semantic topology/formation products are mature. It means `GeneratedWorldChunk` and `GeneratedChunkDataAdapter` are now the canonical compatibility bridge for the current runtime.

---

## Repository Boundary

### Godot Lab owns

* Godot scenes
* debug UI
* generation experiments
* Godot-facing world definition resources
* chunk visual builders
* collision realization builders
* editor/runtime previews
* provider/cache adapters
* compatibility facades for current runtime data

### Godot Lab does not own

* reusable grid topology truth
* reusable streaming lifecycle truth
* final Runenwerk procgen graph contracts
* final Runenwerk SDF world truth
* save formats
* ECS entity ownership
* gameplay spawning decisions
* final asset import architecture
* Bevy adapter architecture

### External ownership assumptions

```text
grid
  owns topology/descriptor logic

spatial_streaming
  owns residency/request lifecycle

godot_world_lab
  owns Godot proof realization and migration adapters
```

`chunk_provider.gd` must shrink over time into a streaming provider adapter, generation request builder, cache bridge, and compatibility facade. It must not remain the long-term owner of generation policy.

---

## Stable Direction

The stable architecture is contract-shaped, not algorithm-shaped.

Concrete algorithms such as noise, Voronoi, SDF sampling, cellular automata, graph expansion, room carving, river routing, biome classification, or continent masking are strategies. They are not the architecture.

Stable stage categories are:

```text
Field stages
Layer stages
Feature stages
Continuity stages
Candidate stages
Projection stages
Validation stages
Diagnostic stages
```

Concrete stages may change. The generated product contract must remain stable.

---

## Canonical Product Flow

```text
WorldDefinitionSnapshot
  immutable runtime generation definition

GenerationContext
  immutable request inputs for one chunk

GenerationPipeline
  ordered stages over a GenerationWorkingSet

GeneratedWorldChunk
  canonical data-only generated product

TopologyProjectionSet
  consumer-specific derived topology views

FormationProductSet
  seam-safe prepared data for consumers

Godot realization
  visual, collision, debug, and preview objects
```

`GeneratedChunkData` is compatibility output only. Long term, current consumers should receive it through `GeneratedChunkDataAdapter` until they can consume `GeneratedWorldChunk`, topology projections, or formation products directly.

`logic_grid` is also compatibility-only. It should become a documented alias for a named topology projection, not the center of the generation model.

---

## Architecture Domains

### 1. Streaming lifecycle

Owned externally by `spatial_streaming`.

Godot Lab receives requests, builds generation contexts, bridges cache identity, and reports provider lifecycle callbacks.

Long-term role of:

```text
scripts/chunk_provider.gd
```

```text
streaming provider adapter
generation request builder
cache bridge
compatibility facade
```

---

### 2. World definition

Files:

```text
scripts/world_generation/definition/world_definition.gd
scripts/world_generation/definition/world_definition_snapshot.gd
scripts/world_generation/definition/world_definition_validator.gd
```

Responsibilities:

```text
WorldDefinition
  author-facing Godot Resource / configuration

WorldDefinitionSnapshot
  immutable data-only runtime definition

WorldDefinitionValidator
  validates stage ordering, layer schemas, projection requests, and unsupported combinations
```

Rule:

```text
Generation stages consume WorldDefinitionSnapshot, not live Godot editor resources.
```

---

### 3. Generation context

Files:

```text
scripts/world_generation/context/generation_context.gd
scripts/world_generation/context/chunk_generation_request.gd
scripts/world_generation/context/world_space.gd
```

Responsibilities:

```text
GenerationContext
  immutable inputs for one chunk generation

ChunkGenerationRequest
  provider-created request object

WorldSpace
  coordinate conversion and chunk/cell/volume bounds
```

Must include:

```text
world_definition_id
world_definition_version
world_definition_hash
world_seed
chunk_coord
owned bounds
sample bounds / halo bounds
requested product kinds
debug flags
```

Rule:

```text
Same definition snapshot + same context = same generated product.
```

---

### 4. Generation pipeline

Files:

```text
scripts/world_generation/pipeline/generation_pipeline.gd
scripts/world_generation/pipeline/generation_stage.gd
scripts/world_generation/pipeline/generation_working_set.gd
scripts/world_generation/pipeline/generation_stage_result.gd
```

Responsibilities:

```text
GenerationPipeline
  runs ordered stages

GenerationStage
  common interface for field/layer/feature/continuity/projection/diagnostic stages

GenerationWorkingSet
  mutable internal state during generation

GenerationStageResult
  status, diagnostics, emitted facts, validation errors
```

Rule:

```text
The working set is never the public product.
It must be finalized into GeneratedWorldChunk.
```

---

### 5. Semantic world facts

Layer files:

```text
scripts/world_generation/layers/world_layer.gd
scripts/world_generation/layers/world_layer_set.gd
scripts/world_generation/layers/world_layer_schema.gd
```

Feature files:

```text
scripts/world_generation/features/world_feature.gd
scripts/world_generation/features/world_feature_set.gd
scripts/world_generation/features/world_feature_schema.gd
```

Rule:

```text
WorldLayer and WorldFeature are semantic generation facts.
TopologyView is derived.
```

Features describe generated facts. They do not spawn scenes, entities, save records, assets, or products.

---

### 6. Fields

Files:

```text
scripts/world_generation/fields/world_field.gd
scripts/world_generation/fields/world_field_sample.gd
scripts/world_generation/fields/world_field_registry.gd
```

Fields are deterministic value sources over world space. Supported value types may include scalar, categorical, mask, distance, region id, density, flow, signed, and volume values.

Rule:

```text
Noise, Voronoi, SDF, authored masks, graphs, and simulations are field/stage strategies.
They are not the architecture.
```

---

### 7. Continuity

Files:

```text
scripts/world_generation/continuity/continuity_contract.gd
scripts/world_generation/continuity/continuity_fact.gd
scripts/world_generation/continuity/continuity_resolver.gd
scripts/world_generation/continuity/chunk_boundary_key.gd
```

Continuity covers more than chunk connectors:

```text
height continuity
region continuity
flow continuity
volume continuity
structure continuity
vertical continuity
graph continuity
```

Rule:

```text
Continuity must be computable without loaded neighbor chunks.
```

---

### 8. Placement candidates

Files:

```text
scripts/world_generation/placement/placement_candidate.gd
scripts/world_generation/placement/placement_candidate_set.gd
scripts/world_generation/placement/placement_policy.gd
```

Rule:

```text
Generation may emit opportunities.
Gameplay decides actual spawning later.
```

---

### 9. Topology projection

Files:

```text
scripts/world_generation/topology/topology_view.gd
scripts/world_generation/topology/topology_projection_set.gd
scripts/world_generation/topology/topology_projector.gd
scripts/world_generation/topology/topology_projection_policy.gd
```

Examples:

```text
visual_ground
visual_liquid
visual_solid
collision_blocking
navigation_walkable
mining
debug
```

Rule:

```text
grid receives topology views, not semantic world truth.
```

---

### 10. Generated product

Files:

```text
scripts/world_generation/products/generated_world_chunk.gd
scripts/world_generation/products/generated_chunk_identity.gd
scripts/world_generation/products/generated_chunk_data_adapter.gd
```

Canonical product shape:

```text
identity
bounds
world_layer_set
world_feature_set
continuity_fact_set
placement_candidate_set
topology_projection_set
formation_product_set
generation_diagnostics
```

Rule:

```text
GeneratedWorldChunk is data-only.
```

It must not contain Node, Resource handle, Mesh, Material, StaticBody3D, CollisionShape3D, PackedScene, save record, ECS entity, or Runenwerk SDF payload ownership.

---

### 11. Formation products

Files:

```text
scripts/world_generation/formation/formation_product.gd
scripts/world_generation/formation/formation_product_set.gd
scripts/world_generation/formation/formation_builder.gd
scripts/world_generation/formation/owned_halo_builder.gd
```

Rule:

```text
Formation prepares data for consumers.
It does not render, collide, or define topology truth.
```

---

### 12. Diagnostics and previews

Files:

```text
scripts/world_generation/diagnostics/generation_diagnostics.gd
scripts/world_generation/diagnostics/stage_diagnostics.gd
scripts/world_generation/diagnostics/generated_chunk_report.gd
scripts/previews/world_generation_preview.gd
scripts/previews/topology_projection_preview.gd
scripts/previews/continuity_preview.gd
```

Rule:

```text
Every generated chunk must be explainable by stage.
Previews observe generated products; they do not own generation rules.
```

---

## Milestone Roadmap

## Phase 0 — Baseline lock and correction

### M0.1 — Replace narrow roadmap language

File:

```text
docs/proof-notes/world-generation-roadmap.md
```

Change:

Replace `WorldProfile`-first wording with `WorldDefinition` and the canonical data-first pipeline.

Done when:

```text
WorldDefinition
→ GenerationContext
→ GenerationPipeline
→ semantic world facts
→ continuity facts
→ topology projections
→ formation products
→ Godot realization
```

is the explicit roadmap direction.

---

### M0.2 — Add canonical architecture contract

File:

```text
docs/proof-notes/world-generation-contract.md
```

Done when the contract defines:

```text
WorldDefinition
WorldDefinitionSnapshot
GenerationContext
GenerationPipeline
GenerationStage
GenerationWorkingSet
WorldField
WorldLayer
WorldFeature
ContinuityContract
ContinuityFact
PlacementCandidate
TopologyView
TopologyProjectionSet
FormationProduct
GeneratedWorldChunk
GenerationDiagnostics
```

and states all ownership boundaries.

---

## Phase 1 — Data contracts before runtime refactor

### M1 — Define identity, hashing, and determinism rules

Files:

```text
docs/proof-notes/world-generation-contract.md
scripts/world_generation/products/generated_chunk_identity.gd
```

Done when identity includes:

```text
world_definition_id
world_definition_version
world_definition_hash
generation_settings_hash
chunk_coord
requested_product_set
```

and tests/smoke checks prove same identity produces the same product signature.

---

### M2 — Add WorldDefinitionSnapshot

Files:

```text
scripts/world_generation/definition/world_definition.gd
scripts/world_generation/definition/world_definition_snapshot.gd
scripts/world_generation/definition/world_definition_validator.gd
```

Done when a live Godot-facing definition can compile into an immutable data-only snapshot.

Do not add concrete continent, cave, dungeon, Voronoi, or SDF logic here.

---

### M3 — Add GenerationContext

Files:

```text
scripts/world_generation/context/generation_context.gd
scripts/world_generation/context/chunk_generation_request.gd
scripts/world_generation/context/world_space.gd
```

Done when `GenerationContext` can describe chunk bounds, owned bounds, sample/halo bounds, world seed, definition hash, and requested products without accessing scene state.

---

## Phase 2 — Pipeline spine

### M4 — Add pipeline and working set

Files:

```text
scripts/world_generation/pipeline/generation_pipeline.gd
scripts/world_generation/pipeline/generation_stage.gd
scripts/world_generation/pipeline/generation_working_set.gd
scripts/world_generation/pipeline/generation_stage_result.gd
```

Done when a no-op pipeline can run deterministic ordered stages and return a stage report.

---

### M5 — Wrap current generation as one legacy stage

File:

```text
scripts/world_generation/pipeline/stages/legacy_chunk_generation_stage.gd
```

Also touched:

```text
scripts/chunk_provider.gd
method: generate_chunk_generation_result(...)
```

Done when `chunk_provider.gd` still returns the current compatibility shape, but internally delegates to a generation pipeline.

---

### M6 — Add generated product adapter

Files:

```text
scripts/world_generation/products/generated_world_chunk.gd
scripts/world_generation/products/generated_chunk_data_adapter.gd
scripts/chunk_provider.gd
method: make_generated_chunk_data(...)
```

Done when the pipeline emits `GeneratedWorldChunk`, and the adapter converts it to current `GeneratedChunkData`.

---

## Phase 3 — Semantic data model

### M7 — Add world layer model

Files:

```text
scripts/world_generation/layers/world_layer.gd
scripts/world_generation/layers/world_layer_set.gd
scripts/world_generation/layers/world_layer_schema.gd
```

Done when current `terrain_cells` and `topology_layers` can be represented as semantic layers plus derived topology views.

---

### M8 — Add topology projection model

Files:

```text
scripts/world_generation/topology/topology_view.gd
scripts/world_generation/topology/topology_projection_set.gd
scripts/world_generation/topology/topology_projector.gd
scripts/world_generation/topology/topology_projection_policy.gd
```

Done when current `ground`, `water`, `solid`, and `cliff` binary grids are emitted as named topology projections.

---

### M9 — Move logic_grid to compatibility-only status

Files:

```text
scripts/world_generation/products/generated_chunk_data_adapter.gd
scripts/chunk_provider.gd
method: generate_chunk_logic_grid(...)
method: make_generated_chunk_data(...)
```

Done when `logic_grid` is documented and tested as:

```text
compatibility alias for topology_projection["solid"]
```

---

## Phase 4 — Formation boundary

### M10 — Extract owned-halo formation into formation domain

Files:

```text
scripts/world_generation/formation/formation_product.gd
scripts/world_generation/formation/formation_product_set.gd
scripts/world_generation/formation/formation_builder.gd
scripts/world_generation/formation/owned_halo_builder.gd
scripts/chunk_provider.gd
method: make_formation_layers(...)
```

Done when formation is data-first and no longer buried inside provider generation.

---

### M11 — Update visual builder to consume formation products

File:

```text
scripts/chunk_visual_builder.gd
method: build_visual_plan_from_generated_chunk(...)
```

Done when visual plan construction can consume `FormationProductSet` through the adapter path.

---

### M12 — Update collision builder to consume collision projection

File:

```text
scripts/collision/chunk_collision_builder.gd
```

Done when collision consumes a named collision topology projection or collision formation product, not raw terrain assumptions.

---

## Phase 5 — Fields, features, continuity, placement

### M13 — Add world field contract

Files:

```text
scripts/world_generation/fields/world_field.gd
scripts/world_generation/fields/world_field_sample.gd
scripts/world_generation/fields/world_field_registry.gd
```

Done when a stage can sample named fields through a generic interface.

Only add interface and simple deterministic proof fields here.

---

### M14 — Add feature model

Files:

```text
scripts/world_generation/features/world_feature.gd
scripts/world_generation/features/world_feature_set.gd
scripts/world_generation/features/world_feature_schema.gd
```

Done when current room/path/debug-marker concepts can be represented as generic features, while old debug markers still exist through the compatibility adapter.

---

### M15 — Add continuity model

Files:

```text
scripts/world_generation/continuity/continuity_contract.gd
scripts/world_generation/continuity/continuity_fact.gd
scripts/world_generation/continuity/continuity_resolver.gd
scripts/world_generation/continuity/chunk_boundary_key.gd
```

Done when a continuity fact can be deterministically computed from world-space boundary keys without loaded neighbors.

---

### M16 — Add placement candidate model

Files:

```text
scripts/world_generation/placement/placement_candidate.gd
scripts/world_generation/placement/placement_candidate_set.gd
scripts/world_generation/placement/placement_policy.gd
```

Done when generation emits opportunities separately from features and debug markers.

No spawning. No scenes. No ECS. No save records.

---

## Phase 6 — Provider and cache refactor

### M17 — Shrink chunk_provider.gd into adapter role

File:

```text
scripts/chunk_provider.gd
```

Methods to reduce/delegate:

```text
generate_chunk_generation_result(...)
_generate_base_terrain_cells(...)
_carve_rooms_and_paths(...)
_repair_walkable_connectivity(...)
_balance_walkable_percent(...)
_derive_topology_layers(...)
_terrain_diagnostics(...)
```

Done when generation policy lives under:

```text
scripts/world_generation/
```

and `chunk_provider.gd` only owns request lifecycle, cache interaction, loaded chunk records, and compatibility methods.

---

### M18 — Update cache to store generated product identity

Files:

```text
scripts/chunk_cache.gd
scripts/world_generation/cache/generated_chunk_cache_key.gd
scripts/world_generation/cache/generated_chunk_cache_policy.gd
```

Done when cache key includes:

```text
chunk_coord
world_definition_id
world_definition_version
world_definition_hash
generation_settings_hash
requested_product_set
```

Cache must not store streaming lifecycle state or Godot realization.

---

## Phase 7 — Diagnostics and observation

### M19 — Add stage diagnostics

Files:

```text
scripts/world_generation/diagnostics/generation_diagnostics.gd
scripts/world_generation/diagnostics/stage_diagnostics.gd
scripts/world_generation/diagnostics/generated_chunk_report.gd
```

Done when every generated chunk reports definition identity, stage list, stage status, emitted layer counts, emitted feature counts, continuity fact counts, placement candidate counts, topology projection counts, formation product counts, and validation errors.

---

### M20 — Add world generation previews

Files:

```text
scripts/previews/world_generation_preview.gd
scripts/previews/topology_projection_preview.gd
scripts/previews/continuity_preview.gd
scenes/previews/world_generation_preview.tscn
```

Done when previews observe the same `GeneratedWorldChunk` products as runtime.

No duplicate topology rules in preview scripts.

---

## Phase 8 — Dimensionality hardening

### M21 — Add domain descriptors

Files:

```text
scripts/world_generation/layers/world_layer_schema.gd
scripts/world_generation/topology/topology_view.gd
scripts/world_generation/context/world_space.gd
```

Done when layers and topology views declare one of:

```text
cell_grid_2d
surface_2_5d
stacked_layers
volume_grid_3d
graph_region
hybrid
```

No rendering change required yet.

---

### M22 — Prove stacked-layer generation

Files:

```text
scripts/world_generation/
scripts/chunk_visual_builder.gd
scripts/collision/chunk_collision_builder.gd
```

Done when one generated chunk can contain multiple semantic vertical layers and derived topology projections without duplicating the same flat layer above itself.

This is where the old same-terrain-repeated-vertically bug class should become structurally impossible.

---

### M23 — Prove one non-flat topology projection

Files:

```text
scripts/world_generation/topology/
scripts/chunk_visual_builder.gd
```

Done when a topology projection can represent something other than one flat surface layer, while `grid` still only receives the projection format it owns.

---

## Phase 9 — Multiple world definitions

### M24 — Add first real non-legacy world definition

Files:

```text
scripts/world_generation/definition/
scripts/world_generation/pipeline/stages/
```

Done when the system can run one definition that is not just the legacy generator wrapped in pipeline form.

Still no concrete long-term commitment to any algorithm.

---

### M25 — Add second meaningfully different world definition

Files:

```text
scripts/world_generation/definition/
scripts/world_generation/pipeline/stages/
```

Done when two different world definitions use the same contracts:

```text
same pipeline interface
same generated product model
same topology projection model
same diagnostics model
same provider adapter
```

This is the minimum proof before discussing extraction again.

---

## Phase 10 — Extraction findings, not extraction

### M26 — Write procgen extraction findings

File:

```text
docs/proof-notes/procgen-extraction-findings.md
```

Done when the doc answers:

```text
Which contracts stayed stable?
Which parts remained Godot-specific?
Which parts would be reusable?
Which parts are still too tied to Godot?
Does Runenwerk need this?
Would a procgen repo own anything real yet?
```

---

### M27 — Decide whether Crystonix/procgen is justified

File:

```text
docs/proof-notes/procgen-extraction-decision.md
```

Possible decisions:

```text
no extraction
contract docs only
minimal procgen_core
minimal procgen_fields
minimal procgen_pipeline
defer until Runenwerk integration pressure
```

Default expected decision:

```text
defer extraction unless two world definitions and one non-Godot consumer need are proven
```

---

## Revised Milestone Order

```text
0. Revise roadmap language from WorldProfile to WorldDefinition.
1. Add canonical world-generation-contract.md.
2. Define identity/hash/determinism rules.
3. Add WorldDefinitionSnapshot.
4. Add GenerationContext.
5. Add GenerationPipeline and GenerationWorkingSet.
6. Wrap current generator as legacy stage.
7. Add GeneratedWorldChunk and compatibility adapter.
8. Add WorldLayer model.
9. Add TopologyProjection model.
10. Make logic_grid compatibility-only.
11. Extract formation domain.
12. Update visual builder to consume formation products.
13. Update collision builder to consume collision projection.
14. Add WorldField contract.
15. Add WorldFeature model.
16. Add ContinuityContract model.
17. Add PlacementCandidate model.
18. Shrink chunk_provider.gd into provider/cache adapter.
19. Update cache identity.
20. Add stage diagnostics.
21. Add world-generation previews.
22. Add domain descriptors for 2D/2.5D/stacked/3D/graph.
23. Prove stacked-layer generation.
24. Prove one non-flat topology projection.
25. Add first non-legacy world definition.
26. Add second meaningfully different world definition.
27. Write procgen extraction findings.
28. Decide whether extraction is justified.
```

---

## Completed Migration Gate

The docs-only baseline package (`M0.1 + M0.2`) and the migration gate are complete:

```text
hash hardening
smoke tests
provider pipeline wiring
```

Rules:

```text
No new world algorithm yet.
No concrete continent, cave, Voronoi, SDF, Runenwerk integration, save/load, ECS, asset extraction, gameplay spawning, or M7+ semantic-layer rewrite.
No Rust crate, repository extraction, Runenwerk integration, grid ownership move, or spatial_streaming ownership move.
```

This gate passed when the legacy provider generation path became deterministic under explicit ordered/unordered hash semantics, smoke-tested, finalized into `GeneratedWorldChunk`, and adapted back to the existing compatibility output through `GeneratedChunkDataAdapter`.

Next gate:

```text
begin M7+ only after review
do not remove legacy generation yet
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
* no premature `Crystonix/procgen` extraction
* no algorithm-specific architecture lock-in

---

## Success Criteria

This roadmap is complete when Godot Lab proves:

```text
A deterministic WorldDefinition-driven pipeline can generate streamed world facts,
derive topology projections,
produce seam-safe formation products,
and realize Godot visuals/collision/debug output without making generation truth depend on Godot runtime objects.
```

The result must support multiple meaningfully different world definitions before extraction is reconsidered.
