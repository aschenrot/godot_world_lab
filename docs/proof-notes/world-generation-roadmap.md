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
M7A complete: legacy terrain cells can be represented as data-only WorldLayer/WorldLayerSet while compatibility output remains unchanged.
M7B complete: GeneratedChunkDataAdapter reconstructs compatibility terrain_cells from semantic_legacy_terrain_cells when legacy_generation_result is absent, with legacy_terrain_cells as the fallback.
M7 complete: LegacyChunkGenerationStage emits a serialized semantic WorldLayerSet, and GeneratedChunkDataAdapter prefers that set as the internal terrain-cell source before individual semantic/raw legacy fallbacks.
M8 complete: current ground/water/solid/cliff topology layers can be represented as data-only TopologyProjection/TopologyProjectionSet products while topology_layers and logic_grid compatibility output remain preserved.
M9 complete: logic_grid is no longer stored in GeneratedWorldChunk legacy_generation_result and is restored only by GeneratedChunkDataAdapter compatibility paths from topology_layers.solid.
M10 complete: current owned-halo formation_layers can be represented as data-only FormationProduct/FormationProductSet products while formation_layers and top-level formation compatibility fields remain preserved.
Data-only world features, continuity facts, placement candidates, diagnostics/provenance, cache identity hardening, provider shrink, definition diversity proof, domain descriptor contracts, host adapter ownership review, legacy retention decision gate, mature runtime abstraction review, and Rust/Runenwerk/extraction ownership review are complete.
Legacy generation is explicitly retained by the current decision gate.
New runtime abstractions are explicitly deferred by the current maturity review.
Rust crates, Runenwerk integration, and extraction are explicitly deferred by the current ownership review.
Next gate: no remaining milestone in the requested sequence.
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

M7A complete: data-only semantic world-layer contract foundation exists for legacy `terrain_cells`.
The compatibility output remains unchanged, and topology projection is still deferred to M8.

M7B complete: adapter reconstruction now prefers the serialized semantic legacy terrain layer when a `GeneratedWorldChunk` no longer carries `legacy_generation_result`. If that semantic layer is missing, the adapter still falls back to the raw `legacy_terrain_cells` layer. This keeps compatibility output alive while moving the internal source of terrain cells toward `WorldLayer` data.

Finish M7 complete: `LegacyChunkGenerationStage` now stores the serialized semantic `WorldLayerSet` in the generated chunk layer store, and `GeneratedChunkDataAdapter` reads terrain cells from that set first when `legacy_generation_result` is absent. The individual serialized semantic terrain layer and raw `legacy_terrain_cells` remain compatibility fallbacks.

M7B proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
```

Deferred:

```text
M8 topology projection products remain data-only future work.
Legacy generation remains retained until semantic/topology/formation parity is proven.
```

---

### M8 — Add topology projection model

Files:

```text
scripts/world_generation/topology/topology_projection.gd
scripts/world_generation/topology/topology_projection_set.gd
```

Done when current `ground`, `water`, `solid`, and `cliff` binary grids are emitted as named topology projections.

M8 complete: data-only `TopologyProjection` and `TopologyProjectionSet` now wrap the current legacy `topology_layers` grids. `LegacyChunkGenerationStage` emits the serialized projection set alongside the raw topology projection dictionary, `GeneratedWorldChunk` carries both, and `GeneratedChunkDataAdapter` can reconstruct legacy `topology_layers` and `logic_grid` from the projection set when `legacy_generation_result` is absent.

M8 proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_topology_projection_smoke.gd
```

Deferred:

```text
TopologyProjector and TopologyProjectionPolicy remain deferred until topology derivation moves beyond wrapping current legacy grids.
M9 must demote logic_grid to an adapter-only compatibility alias.
Formation products are covered by M10.
Legacy generation remains retained until semantic/topology/formation parity is proven.
```

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

M9 complete: `LegacyChunkGenerationStage` stores its legacy generation result without `logic_grid`, and `GeneratedWorldChunk.from_legacy_generation_result(...)` strips that alias as well. Public compatibility paths still expose `logic_grid` through `GeneratedChunkDataAdapter`, derived from `topology_layers.solid` or the serialized `TopologyProjectionSet` when needed.

M9 proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_topology_projection_smoke.gd
```

Deferred:

```text
logic_grid remains present in public compatibility output, chunk cache records, and host compatibility methods until later adapter/cache milestones.
Formation products are covered by M10.
Legacy generation remains retained until semantic/topology/formation parity is proven.
```

---

## Phase 4 — Formation boundary

### M10 — Extract owned-halo formation into formation domain

Files:

```text
scripts/world_generation/formation/formation_product.gd
scripts/world_generation/formation/formation_product_set.gd
scripts/world_generation/formation/formation_layer_builder.gd
scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd
scripts/chunk_provider.gd
method: make_formation_layers(...)
```

Done when formation is data-first and no longer buried inside provider generation.

M10 complete: data-only `FormationProduct` and `FormationProductSet` now wrap the current owned-halo `formation_layers`. `LegacyFormationProductStage` builds the formation products from requested topology projections during `GenerationPipeline`, stores the result in `GenerationWorkingSet.STORE_FORMATION` and `STORE_PRODUCTS`, and `GeneratedWorldChunk.from_working_set(...)` finalizes the canonical `formation_product_set` without provider-side patching. `GeneratedChunkDataAdapter` emits both the new product set and all existing compatibility fields:

```text
formation_layers
formation_grid
formation_origin_cell
owned_visual_origin
owned_visual_size
formation_mode
source_chunk_coords
```

M10 proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_topology_projection_smoke.gd
godot --headless --path . --script tests/world_generation_formation_product_smoke.gd
godot --headless --path . --script tests/formation_products_smoke.gd
```

Deferred:

```text
chunk_provider.make_generated_chunk_data(...) still has a compatibility path that builds GeneratedChunkData fields for existing host consumers.
Visual/collision consumers still read compatibility fields through GeneratedChunkData while realization is migrated to canonical products.
Legacy generation remains retained until semantic/topology/formation parity is proven across runtime consumers.
```

---

### M11 — Update visual builder to consume formation products

File:

```text
scripts/chunk_visual_builder.gd
method: build_visual_plan_from_generated_chunk(...)
```

Done when visual plan construction can consume `FormationProductSet` through the adapter path.

M11/M12 host adapter review complete: `chunk_visual_builder.gd` now exposes a non-authoritative host adapter contract, records the `GeneratedChunkData` source product on visual plans, and prefers formation/topology product fields before the `logic_grid` compatibility alias. Visual plans and instantiation plans retain derived visual data only; they do not retain generation-truth payloads such as semantic layers, topology projection sets, formation product sets, terrain cells, or legacy generation results.

---

### M12 — Update collision builder to consume collision projection

File:

```text
scripts/collision/chunk_collision_builder.gd
```

Done when collision consumes a named collision topology projection or collision formation product, not raw terrain assumptions.

M11/M12 host adapter review complete: `chunk_collision_builder.gd` now exposes a non-authoritative host adapter contract, records consumed source fields on collision plans, and consumes `GeneratedChunkData.topology_layers.solid`/`water` without requiring the `logic_grid` compatibility alias. Collision plans and `StaticBody3D` realization metadata retain collision policy/shape data only; they do not retain generation-truth payloads.

Compatibility:

```text
WorldController still obtains GeneratedChunkData from ChunkProvider and passes it to visual/collision adapters.
GeneratedChunkData compatibility output is unchanged.
Visual node construction, multimesh instantiation, collision shape construction, and collision policy behavior are unchanged.
logic_grid remains available as an adapter-only compatibility alias and remains a fallback for older direct adapter calls.
Legacy generation remains retained.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_host_adapter_review_smoke.gd
godot --headless --path . --script tests/visual_plan_smoke.gd
godot --headless --path . --script tests/chunk_collision_smoke.gd
godot --headless --path . --script tests/formation_products_smoke.gd
```

Deferred:

```text
Direct GeneratedWorldChunk-to-host adapters, visual/collision algorithm redesign, legacy removal, save/load, spawning, ECS, Rust extraction, and Runenwerk integration remain later decisions.
```

---

### Legacy removal/retention decision gate — complete

Files:

```text
scripts/world_generation/legacy/legacy_retention_decision.gd
tests/world_generation_legacy_retention_decision_smoke.gd
docs/proof-notes/world-generation-roadmap.md
```

Decision:

```text
retain_legacy_generation
```

Done:

```text
LegacyRetentionDecision records explicit removal criteria, blocking criteria, rationale, deferred scope, deterministic identity, and the final retain/remove-review decision.
The current gate proves semantic layer, topology projection, formation product, host adapter, and GeneratedChunkData compatibility parity at the adapter layer.
The current gate also proves legacy removal is still blocked because no replacement generation authority exists, LegacyChunkGenerationStage can still run, and ChunkProvider still exposes the legacy wrapper.
```

Compatibility:

```text
LegacyChunkGenerator, LegacyChunkGenerationStage, ChunkProvider._generate_legacy_chunk_generation_result(...), and all compatibility outputs remain retained.
GeneratedChunkData compatibility output is unchanged.
The decision gate introduces no new generation algorithm, no visual/collision rewrite, no save/load, no spawning, no ECS, no Rust extraction, and no Runenwerk integration.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_legacy_retention_decision_smoke.gd
```

Deferred:

```text
Replacement generation authority, legacy stage replacement, legacy wrapper removal, legacy generation result removal, legacy cache wrapper removal, mature runtime abstraction review, Rust extraction, and Runenwerk integration remain later decisions.
```

---

### Mature runtime abstraction review — complete

Files:

```text
scripts/world_generation/runtime_abstraction_review.gd
tests/world_generation_runtime_abstraction_review_smoke.gd
docs/proof-notes/world-generation-roadmap.md
```

Decision:

```text
defer_new_runtime_abstractions
```

Guarded symbols remain deferred:

```text
WorldGenerationSemantics
WorldGenerationProgram
WorldGenerationCompiler
WorldGenerationArtifact
WorldGenerationEvaluator
```

Done:

```text
RuntimeAbstractionReview records maturity criteria, blocking criteria, guarded symbols, rationale, deferred scope, deterministic identity, and the final defer/eligible decision.
The current review acknowledges stable data product contracts, meaningfully different definition contracts, and non-authoritative host adapter boundaries.
The current review blocks new runtime abstractions because the legacy retention gate does not allow removal, no replacement generation authority exists, direct GeneratedWorldChunk host adapters are not proven, no non-Godot consumer need is proven, and Runenwerk integration pressure is not proven.
```

Compatibility:

```text
No WorldGenerationSemantics, Program, Compiler, Artifact, or Evaluator is introduced.
GenerationPipeline, GenerationWorkingSet, GeneratedWorldChunk, GeneratedChunkDataAdapter, host adapters, legacy generation, and compatibility output remain unchanged.
The review introduces no new generation algorithm, no visual/collision rewrite, no save/load, no spawning, no ECS, no Rust extraction, and no Runenwerk integration.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_runtime_abstraction_review_smoke.gd
```

Deferred:

```text
Runtime abstraction design, direct GeneratedWorldChunk host adapters, replacement generation authority, non-Godot consumer contract, Runenwerk integration pressure review, Rust extraction, and Crystonix/procgen extraction remain later decisions.
```

---

### Rust/Runenwerk/extraction ownership review — complete

Files:

```text
scripts/world_generation/extraction_ownership_review.gd
tests/world_generation_extraction_ownership_review_smoke.gd
docs/proof-notes/world-generation-roadmap.md
docs/proof-notes/procgen-rust-boundary-review.md
```

Decision:

```text
defer_extraction_and_integration
```

Guarded artifacts remain deferred:

```text
Crystonix/procgen
Rust procgen crate
Runenwerk integration
Runenwerk final procgen graph contract
Runenwerk SDF payload ownership
grid/spatial_streaming merge
```

Done:

```text
ExtractionOwnershipReview records ownership criteria, blocking criteria, ownership findings, guarded artifacts, rationale, deferred scope, deterministic identity, and the final defer/eligible decision.
The current review acknowledges Godot Lab product contracts are proven enough to review.
The current review blocks extraction and integration because legacy removal is not allowed, runtime abstraction is not allowed, no replacement generation authority exists, no non-Godot consumer need is proven, Runenwerk is not proven the wrong owner, Runenwerk integration pressure is not proven, no smaller Rust API is proven, and no durable external invariants are proven.
```

Ownership findings:

```text
Godot Lab remains proof host and Godot adapter owner.
Runenwerk remains the future candidate for Runenwerk-specific procgen ownership if pressure is later proven.
grid remains owner of reusable grid/topology mechanics.
spatial_streaming remains owner of payload-neutral streaming lifecycle.
Crystonix/procgen has no owner yet and must not be created.
```

Compatibility:

```text
No Rust crate, no Crystonix/procgen repository, no Runenwerk integration, no grid/spatial_streaming merge, no save/load, no spawning, no ECS, and no new algorithm is introduced.
GenerationPipeline, GenerationWorkingSet, GeneratedWorldChunk, GeneratedChunkDataAdapter, host adapters, legacy generation, and compatibility output remain unchanged.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_extraction_ownership_review_smoke.gd
```

Deferred:

```text
Crystonix/procgen repository, Rust procgen crate, Runenwerk integration, Runenwerk final procgen graph contract, Runenwerk SDF payload ownership, grid/spatial_streaming merge, save/load ownership, ECS ownership, spawning ownership, and extraction design remain future decisions.
```

---

## Phase 5 — Fields, features, continuity, placement

### Data-only features, continuity facts, and placement candidates — complete

Files:

```text
scripts/world_generation/features/world_feature.gd
scripts/world_generation/features/world_feature_set.gd
scripts/world_generation/continuity/continuity_fact.gd
scripts/world_generation/continuity/continuity_fact_set.gd
scripts/world_generation/placement/placement_candidate.gd
scripts/world_generation/placement/placement_candidate_set.gd
tests/world_generation_feature_continuity_placement_smoke.gd
```

Done:

```text
WorldFeature/WorldFeatureSet wrap legacy debug markers as data-only generated facts.
ContinuityFact/ContinuityFactSet record deterministic context boundary facts from chunk bounds without loaded neighbors.
PlacementCandidate/PlacementCandidateSet wrap debug-marker opportunities as generation-only candidate data.
LegacyChunkGenerationStage stores product dictionaries in world_features, continuity_facts, and placement_candidates.
GeneratedWorldChunk.from_legacy_generation_result also populates these product sets for compatibility-created chunks.
```

Compatibility:

```text
legacy_debug_markers remains present in world_features and GeneratedChunkDataAdapter compatibility output.
Placement candidates do not spawn scenes, own entities, own save records, or introduce ECS/runtime references.
Legacy generation remains retained.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_feature_continuity_placement_smoke.gd
```

Deferred:

```text
WorldFeatureSchema, ContinuityContract, ContinuityResolver, ChunkBoundaryKey, PlacementPolicy, and WorldField sampling remain deferred.
No spawning, save/load, ECS, new world algorithm, or visual/collision rewrite is introduced by this milestone.
```

---

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

### Provider legacy-generation shrink — complete

Files:

```text
scripts/chunk_provider.gd
scripts/world_generation/legacy/legacy_chunk_generator.gd
tests/world_generation_provider_shrink_smoke.gd
```

Done:

```text
LegacyChunkGenerator owns the old terrain generation policy: base terrain cells, room/path carving, connectivity repair, walkability balancing, topology layer derivation, terrain diagnostics, and logic-grid compatibility reconstruction.
chunk_provider.gd keeps request lifecycle, cache interaction, loaded chunk records, world definition/context construction, formation compatibility, sampling, and host compatibility methods.
chunk_provider.gd private legacy methods now delegate to LegacyChunkGenerator rather than owning the generation policy bodies.
```

Compatibility:

```text
_generate_legacy_chunk_generation_result(...) remains available as the legacy wrapper used by LegacyChunkGenerationStage.
generate_chunk_generation_result(...), generate_chunk_logic_grid(...), make_generated_chunk_data(...), and sampling helpers keep their existing compatibility behavior.
Legacy generation remains retained.
GeneratedChunkData output remains unchanged.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_provider_shrink_smoke.gd
```

Deferred:

```text
Formation construction, host adapter review, visual/collision product consumption, legacy removal, new world definitions, and any algorithm redesign remain later milestones.
```

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

### Cache identity hardening — complete

Files:

```text
scripts/chunk_cache.gd
scripts/chunk_provider.gd
scripts/world_generation/cache/generated_chunk_cache_key.gd
scripts/world_generation/cache/generated_chunk_cache_policy.gd
tests/world_generation_cache_identity_smoke.gd
```

Done:

```text
GeneratedChunkCacheKey is derived from GeneratedChunkIdentity.
GeneratedChunkCachePolicy rejects incomplete generated identities.
ChunkCache stores and loads generation results by generated identity.
ChunkProvider uses the generated identity cache key for loaded chunk records, generation-result cache entries, and formation sampling cache entries.
```

Cache identity includes:

```text
chunk_coord
world_definition_id
world_definition_version
world_definition_hash
generation_settings_hash
requested_product_set
```

Compatibility:

```text
ChunkCache keeps legacy has_chunk/load_generation_result/store_generation_result wrappers for existing host compatibility.
GeneratedChunkData compatibility output is unchanged.
Cache records still store generation results only, not streaming lifecycle state, Godot realization, visuals, collision objects, scenes, save records, or ECS entities.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_cache_identity_smoke.gd
```

Deferred:

```text
Persisted/on-disk cache storage, eviction policy, provider shrink, host adapter review, and legacy cache wrapper removal remain later decisions.
```

---

## Phase 7 — Diagnostics and observation

### Diagnostics/provenance and deterministic product identity coverage — complete

Files:

```text
scripts/world_generation/diagnostics/stage_diagnostics.gd
scripts/world_generation/diagnostics/generation_diagnostics.gd
scripts/world_generation/diagnostics/generated_chunk_report.gd
tests/world_generation_diagnostics_provenance_smoke.gd
```

Done:

```text
StageDiagnostics wraps GenerationStageResult dictionaries with stage id, category, status, emitted counts, validation errors, warnings, input/output working-set signatures, and deterministic signature contribution.
GenerationDiagnostics summarizes GeneratedWorldChunk identity, stage diagnostics, emitted counts, product counts, validation errors, warnings, product signatures, and provenance.
GeneratedChunkReport exposes a compact inspectable report for debug UI/previews without duplicating generation rules.
GeneratedWorldChunk exposes diagnostics_report(), generated_chunk_report(), and product_signature_map() helpers.
```

Identity coverage:

```text
product_signature_map records deterministic signatures for generated_world_chunk, identity, bounds, semantic/product stores, stage_results, validation_issues, and retained legacy_generation_result.
Smoke coverage proves diagnostics and generated chunk reports are deterministic for identical generated products.
Smoke coverage proves generated_world_chunk and world_features signatures change when feature product data changes.
```

Compatibility:

```text
GeneratedChunkData compatibility output is unchanged.
Diagnostics/provenance are report products only and do not own generation truth, Godot runtime objects, scenes, save records, or ECS entities.
Legacy generation remains retained.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_diagnostics_provenance_smoke.gd
```

Deferred:

```text
Preview scenes, visual/collision consumer rewrites, cache identity hardening, and provider shrink remain later milestones.
No new world algorithm, spawning, save/load, ECS, Rust extraction, or Runenwerk integration is introduced by this milestone.
```

---

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
scripts/world_generation/context/domain_descriptor_contract.gd
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

### Domain descriptor contracts — complete

Files:

```text
scripts/world_generation/context/domain_descriptor_contract.gd
scripts/world_generation/context/world_space.gd
scripts/world_generation/context/generation_context.gd
scripts/world_generation/definition/world_definition_validator.gd
scripts/world_generation/topology/topology_view.gd
tests/world_generation_domain_contract_smoke.gd
```

Done:

```text
DomainDescriptorContract records concrete coordinate, ownership, halo, sampling, continuity, projection, formation, and outputs contracts for each supported domain descriptor.
WorldSpace is the registry for cell_grid_2d, surface_2_5d, stacked_layers, volume_grid_3d, graph_region, and hybrid contracts.
GenerationContext exposes the selected domain contract in its inspectable dictionary without changing generation behavior.
WorldDefinitionValidator verifies supported descriptors have valid domain contracts.
TopologyView can declare a domain contract and deterministic contract identity without deriving topology.
```

Compatibility:

```text
cell_grid_2d remains the active compatibility domain and keeps existing Rect2i owned/sample bounds.
surface_2_5d, stacked_layers, volume_grid_3d, graph_region, and hybrid are declared contracts only; no new generation algorithm is introduced.
GeneratedChunkData compatibility output, topology_layers, logic_grid alias behavior, formation compatibility fields, visuals, and collision are unchanged.
Legacy generation remains retained.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_domain_contract_smoke.gd
```

Deferred:

```text
Stacked-layer generation, non-flat topology projection, host adapter review, visual/collision consumption changes, legacy removal, mature runtime abstraction, Rust extraction, and Runenwerk integration remain later milestones.
```

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

### Meaningfully different world definition proof — complete

Files:

```text
scripts/world_generation/definition/world_definition.gd
scripts/world_generation/definition/world_definition_profile_library.gd
tests/world_generation_definition_diversity_smoke.gd
```

Done:

```text
WorldDefinition now exposes contract_hash(), which excludes generation_settings and world_seed and hashes the definition contract surface.
WorldDefinitionProfileLibrary defines two proof definitions with identical generation settings but different layer, feature, continuity, topology, formation, and requested product contracts.
The surface_material_chunk and navigation_topology_survey proof definitions run through the same GenerationPipeline, GeneratedWorldChunk product model, diagnostics model, and provider adapter contract.
```

Proof definitions:

```text
surface_material_chunk:
  focuses on semantic terrain/surface material layers, room/path features, full topology projections, and full formation products.

navigation_topology_survey:
  focuses on walkability/solid navigation contracts, connectivity/transition facts, solid topology projection, continuity facts, placement candidates, and diagnostics.
```

Compatibility:

```text
This is a contract proof only. It does not add a new generation algorithm, remove legacy generation, rewrite visual/collision consumers, add save/load, spawn gameplay entities, or introduce ECS.
GeneratedChunkData compatibility output is unchanged.
```

Proof:

```sh
godot --headless --path . --script tests/world_generation_migration_gate_smoke.gd
godot --headless --path . --script tests/world_generation_semantic_layer_smoke.gd
godot --headless --path . --script tests/world_generation_definition_diversity_smoke.gd
```

Deferred:

```text
Real non-legacy algorithms, domain descriptor hardening, visual/collision adapter review, legacy removal, and extraction review remain later milestones.
```

---

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
