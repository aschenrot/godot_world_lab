# Godot World Lab — World Generation Contract

## Purpose

This document defines the stable vocabulary and ownership boundaries for the Godot Lab procedural world-generation proof.

The contract exists to keep implementation work data-first, deterministic, and extractable later only if the proof earns extraction. It intentionally avoids committing the architecture to one algorithm, one world shape, one rendering technique, one save format, or one runtime engine.

Canonical direction:

```text
WorldDefinitionSnapshot + GenerationContext
→ GenerationPipeline
→ GeneratedWorldChunk
→ TopologyProjectionSet
→ FormationProductSet
→ Godot realization
```

Generation truth is data. Godot nodes, meshes, materials, collision shapes, scenes, save records, ECS entities, and Runenwerk SDF payloads are not generation truth.

---

## Ownership Boundaries

## Godot Lab

Godot Lab owns:

```text
Godot-facing authoring resources
runtime proof scenes
debug UI
preview scenes
provider/cache adapters
visual realization
collision realization
compatibility adapters
experimental generation stages
```

Godot Lab does not own reusable topology truth, reusable streaming lifecycle truth, final Runenwerk graph contracts, final Runenwerk world truth, save formats, ECS entity ownership, or final gameplay spawning decisions.

---

## grid

`grid` owns reusable topology and descriptor logic.

Godot Lab may derive topology projections for `grid`, but semantic world truth must not be collapsed into `grid` concepts too early.

Rule:

```text
grid receives topology views, not semantic world truth.
```

---

## spatial_streaming

`spatial_streaming` owns residency and request lifecycle.

Godot Lab may implement a provider adapter, but generation policy must not become part of streaming lifecycle truth.

Rule:

```text
streaming asks for chunk products;
generation produces chunk products;
realization displays chunk products.
```

---

## Runenwerk

Runenwerk is not directly integrated by this contract.

This proof should preserve a future mapping toward Runenwerk concepts, but Godot Lab must not create final Runenwerk procgen graph contracts, SDF save truth, product semantics, or asset extraction boundaries prematurely.

---

## Determinism Contract

Generation must be deterministic for a fixed snapshot and context.

```text
same WorldDefinitionSnapshot
+ same GenerationContext
= same GeneratedWorldChunk signature
```

A generation result must not depend on:

* currently loaded neighbor chunks
* node tree state
* frame order
* renderer state
* physics state
* mutable editor resources
* object instance ids
* unordered dictionary iteration where order affects output
* cache hit/miss behavior

Cache may avoid recomputation. Cache must not change generated truth.

---

## Canonical Terms

## WorldDefinition

Author-facing Godot configuration for a world-generation proof.

Expected file:

```text
scripts/world_generation/definition/world_definition.gd
```

Responsibilities:

* declare world identity
* declare generation stage configuration
* declare layer schemas
* declare feature schemas
* declare continuity policies
* declare requested topology projections
* declare requested formation products
* expose editor-friendly configuration

Non-responsibilities:

* no direct chunk generation
* no scene spawning
* no mesh ownership
* no collision ownership
* no save ownership
* no final Runenwerk program ownership

`WorldDefinition` replaces the narrower `WorldProfile` concept. `WorldProfile` may remain only as historical/compatibility language in old notes.

---

## WorldDefinitionSnapshot

Immutable runtime data compiled from `WorldDefinition`.

Expected file:

```text
scripts/world_generation/definition/world_definition_snapshot.gd
```

Responsibilities:

* provide stable definition identity
* provide stable version/hash data
* expose generation settings as data-only values
* freeze stage order
* freeze layer schemas
* freeze topology projection requests
* freeze formation product requests

Non-responsibilities:

* no live Resource mutation
* no editor-only state
* no Node references
* no Mesh/Material/CollisionShape references
* no random generation side effects

Rule:

```text
Generation stages consume WorldDefinitionSnapshot, not live Godot editor resources.
```

---

## WorldDefinitionValidator

Validation service for definitions and snapshots.

Expected file:

```text
scripts/world_generation/definition/world_definition_validator.gd
```

Responsibilities:

* validate stage ordering
* validate layer schema references
* validate feature schema references
* validate requested projections
* validate requested formation products
* reject unsupported dimensionality combinations
* report contract errors before runtime generation

---

## ChunkGenerationRequest

Provider-created request object representing what should be generated.

Expected file:

```text
scripts/world_generation/context/chunk_generation_request.gd
```

Responsibilities:

* capture incoming streaming request data
* identify requested chunk coordinate
* identify requested product kinds
* carry debug flags
* bridge from provider lifecycle into generation context creation

Non-responsibilities:

* no generation policy
* no cache ownership
* no Godot realization

---

## GenerationContext

Immutable inputs for generating one chunk product.

Expected file:

```text
scripts/world_generation/context/generation_context.gd
```

Must include:

```text
world_definition_id
world_definition_version
world_definition_hash
generation_settings_hash
world_seed
chunk_coord
owned bounds
sample bounds / halo bounds
requested_product_set
debug flags
```

Responsibilities:

* define the exact generation request
* expose world-space bounds
* expose owned and halo sampling bounds
* support deterministic hashing/signature generation

Non-responsibilities:

* no mutable working data
* no stage output storage
* no Node references
* no loaded-neighbor dependency

---

## WorldSpace

Coordinate conversion and bounds helper.

Expected file:

```text
scripts/world_generation/context/world_space.gd
```

Responsibilities:

* convert chunk coordinates to world cell bounds
* convert local cells to world cells
* compute owned bounds
* compute sample/halo bounds
* describe dimensional domains

Supported domain descriptors:

```text
cell_grid_2d
surface_2_5d
stacked_layers
volume_grid_3d
graph_region
hybrid
```

---

## GenerationPipeline

Ordered deterministic runner for generation stages.

Expected file:

```text
scripts/world_generation/pipeline/generation_pipeline.gd
```

Responsibilities:

* receive `WorldDefinitionSnapshot`
* receive `GenerationContext`
* initialize `GenerationWorkingSet`
* run ordered `GenerationStage` instances
* collect stage results and diagnostics
* finalize into `GeneratedWorldChunk`

Non-responsibilities:

* no Godot node creation
* no mesh building
* no collision shape building
* no cache lifecycle ownership
* no streaming lifecycle ownership

---

## GenerationStage

Common interface for deterministic generation pipeline steps.

Expected file:

```text
scripts/world_generation/pipeline/generation_stage.gd
```

Stage categories:

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

Rules:

* stages operate on `GenerationWorkingSet`
* stages report through `GenerationStageResult`
* stages must be deterministic for the same snapshot/context/working-set input
* stages must not create Godot realization objects
* stages must not depend on loaded neighbor chunks

---

## GenerationWorkingSet

Mutable internal state during pipeline execution.

Expected file:

```text
scripts/world_generation/pipeline/generation_working_set.gd
```

Responsibilities:

* store intermediate field samples
* store intermediate semantic layers
* store intermediate features
* store continuity facts
* store placement candidates
* store topology projections
* store formation products
* store diagnostics while stages execute

Rule:

```text
GenerationWorkingSet is not public product data.
It must be finalized into GeneratedWorldChunk.
```

---

## GenerationStageResult

Structured result from one stage execution.

Expected file:

```text
scripts/world_generation/pipeline/generation_stage_result.gd
```

Responsibilities:

* stage id
* stage category
* status
* emitted counts
* warnings
* validation errors
* deterministic signature contribution
* diagnostics payload

---

## WorldField

Deterministic value source over world space.

Expected file:

```text
scripts/world_generation/fields/world_field.gd
```

Supported value types may include:

```text
scalar
categorical
mask
distance
region id
density
flow
signed
volume
```

Rules:

* fields are sampled by stages
* fields are not architecture-specific algorithms
* noise, Voronoi, SDF, masks, graph queries, and simulations are strategies behind this contract

---

## WorldFieldSample

Sampled field value with coordinate/domain metadata.

Expected file:

```text
scripts/world_generation/fields/world_field_sample.gd
```

Responsibilities:

* field id
* world coordinate
* domain descriptor
* value type
* sampled value
* optional confidence/source metadata

---

## WorldFieldRegistry

Named field lookup available to stages.

Expected file:

```text
scripts/world_generation/fields/world_field_registry.gd
```

Responsibilities:

* register field providers
* resolve fields by id
* reject missing field references during validation

---

## WorldLayer

Named semantic world data emitted by generation.

Expected file:

```text
scripts/world_generation/layers/world_layer.gd
```

Responsibilities:

* hold semantic data for one named layer
* declare schema id
* declare dimensional domain
* provide deterministic value access

Examples:

```text
terrain_material
liquid_presence
solid_presence
height_band
biome_region
structure_region
underground_volume
```

Rule:

```text
WorldLayer is semantic.
TopologyView is derived.
```

---

## WorldLayerSet

Collection of emitted semantic world layers for one generated chunk.

Expected file:

```text
scripts/world_generation/layers/world_layer_set.gd
```

Responsibilities:

* add/get layers by id
* expose deterministic layer order
* provide layer counts for diagnostics
* provide product signature input

---

## WorldLayerSchema

Type/domain/value contract for a world layer.

Expected file:

```text
scripts/world_generation/layers/world_layer_schema.gd
```

Responsibilities:

* layer id
* value type
* dimensional domain
* allowed values/ranges
* required fields
* projection eligibility

---

## WorldFeature

Structured generated fact.

Expected file:

```text
scripts/world_generation/features/world_feature.gd
```

Feature shape:

```text
feature_id
feature_kind
bounds
influence
priority
source_stage
constraints
tags
metadata
```

Examples:

```text
open_area
corridor
barrier
liquid_pool
resource_cluster
landmark
transition
region_marker
structure_seed
```

Rules:

* features describe world facts
* features do not spawn scenes
* features do not own entities
* features do not own save records
* features do not own final formed products

---

## WorldFeatureSet

Collection of emitted features for one generated chunk.

Expected file:

```text
scripts/world_generation/features/world_feature_set.gd
```

Responsibilities:

* store features by id
* expose deterministic ordering
* support feature queries by kind/tag/bounds
* provide feature counts for diagnostics

---

## WorldFeatureSchema

Validation contract for feature fields and tags.

Expected file:

```text
scripts/world_generation/features/world_feature_schema.gd
```

Responsibilities:

* validate feature kind
* validate required metadata
* validate bounds/influence shape
* validate allowed tags

---

## ContinuityContract

Deterministic agreement rule across boundaries, regions, volumes, or graphs.

Expected file:

```text
scripts/world_generation/continuity/continuity_contract.gd
```

Continuity may cover:

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

## ContinuityFact

Generated agreement data emitted by continuity stages.

Expected file:

```text
scripts/world_generation/continuity/continuity_fact.gd
```

Responsibilities:

* continuity id
* continuity kind
* boundary/region key
* participating domain
* deterministic value
* source contract
* priority
* metadata

`ChunkConnector` may become one kind of `ContinuityFact`, not the whole continuity model.

---

## ContinuityResolver

Applies continuity facts to layers, features, projections, or formation products.

Expected file:

```text
scripts/world_generation/continuity/continuity_resolver.gd
```

Responsibilities:

* read continuity contracts
* compute continuity facts
* apply facts deterministically
* report conflicts and repairs

---

## ChunkBoundaryKey

Stable world-space key for chunk boundaries and adjacency surfaces.

Expected file:

```text
scripts/world_generation/continuity/chunk_boundary_key.gd
```

Must support:

```text
edges
corners
vertical faces
volume faces
region seams
graph portals
```

---

## PlacementCandidate

Generated opportunity, not a spawned object.

Expected file:

```text
scripts/world_generation/placement/placement_candidate.gd
```

Candidate shape:

```text
candidate_id
candidate_kind
world_position_or_bounds
source_feature
score
constraints
tags
metadata
```

Rule:

```text
Generation may emit placement opportunities.
Gameplay decides what actually spawns later.
```

---

## PlacementCandidateSet

Collection of placement opportunities.

Expected file:

```text
scripts/world_generation/placement/placement_candidate_set.gd
```

Responsibilities:

* store candidates deterministically
* query by kind/tag/bounds
* report candidate counts

---

## PlacementPolicy

Scoring and constraint policy for placement opportunities.

Expected file:

```text
scripts/world_generation/placement/placement_policy.gd
```

Responsibilities:

* score valid candidate locations
* apply spacing rules
* apply layer/feature/topology constraints
* avoid spawning ownership

---

## TopologyView

Consumer-specific simplified topology derived from semantic facts.

Expected file:

```text
scripts/world_generation/topology/topology_view.gd
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

Responsibilities:

* declare projection id
* declare dimensional domain
* expose topology values in consumer format
* provide deterministic signature data

Rule:

```text
TopologyView is derived from semantic layers/features/continuity.
It is not semantic world truth.
```

---

## TopologyProjectionSet

All topology views emitted for one generated chunk.

Expected file:

```text
scripts/world_generation/topology/topology_projection_set.gd
```

Responsibilities:

* store topology views by projection id
* expose deterministic ordering
* support adapter access for old runtime consumers

---

## TopologyProjector

Derives topology views from world layers, features, and continuity facts.

Expected file:

```text
scripts/world_generation/topology/topology_projector.gd
```

Responsibilities:

* read semantic layers
* read features
* read continuity facts
* build requested topology views
* report projection diagnostics

---

## TopologyProjectionPolicy

Definition of requested topology projections.

Expected file:

```text
scripts/world_generation/topology/topology_projection_policy.gd
```

Responsibilities:

* declare projection id
* declare source layer/feature requirements
* declare target consumer
* declare domain descriptor
* declare output value contract

---

## GeneratedWorldChunk

Canonical generated data product.

Expected file:

```text
scripts/world_generation/products/generated_world_chunk.gd
```

Canonical shape:

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

Rules:

* data-only
* deterministic
* inspectable
* adapter-friendly
* no Node ownership
* no Resource handle ownership
* no Mesh ownership
* no Material ownership
* no StaticBody3D ownership
* no CollisionShape3D ownership
* no PackedScene ownership
* no save record ownership
* no ECS entity ownership
* no Runenwerk SDF payload ownership

---

## GeneratedChunkIdentity

Stable identity/hash/version metadata for a generated product.

Expected file:

```text
scripts/world_generation/products/generated_chunk_identity.gd
```

Must include:

```text
world_definition_id
world_definition_version
world_definition_hash
generation_settings_hash
chunk_coord
requested_product_set
```

Should also support:

```text
product_signature
schema_version
pipeline_version
```

---

## GeneratedChunkDataAdapter

Compatibility bridge from canonical product to current runtime data.

Expected file:

```text
scripts/world_generation/products/generated_chunk_data_adapter.gd
```

Responsibilities:

* convert `GeneratedWorldChunk` into current `GeneratedChunkData`
* preserve current visual/collision behavior during migration
* expose `logic_grid` only as compatibility data
* map topology projections to existing generated data fields

Rule:

```text
GeneratedChunkData is compatibility output.
GeneratedWorldChunk is canonical generation output.
```

---

## FormationProduct

Seam-safe prepared product for a consumer.

Expected file:

```text
scripts/world_generation/formation/formation_product.gd
```

Responsibilities:

* describe consumer target
* include owned area data
* include required halo/sample data
* preserve seam-safe inputs for realization
* avoid renderer/collision ownership

Examples:

```text
visual_ground_formation
visual_liquid_formation
collision_blocking_formation
navigation_formation
debug_overlay_formation
```

---

## FormationProductSet

Collection of formation products emitted for one generated chunk.

Expected file:

```text
scripts/world_generation/formation/formation_product_set.gd
```

Responsibilities:

* store formation products by id
* expose deterministic ordering
* provide formation counts for diagnostics

---

## Formation Builder Boundary

Converts topology projections into formation products.

Current files:

```text
scripts/world_generation/formation/formation_layer_builder.gd
scripts/world_generation/pipeline/stages/legacy_formation_product_stage.gd
```

Responsibilities:

* read topology projections
* build consumer-specific formation products
* coordinate owned/halo data
* report formation diagnostics
* store canonical formation output in `GenerationWorkingSet.STORE_FORMATION`

Rule:

```text
Formation prepares data.
Rendering and collision creation happen later.
```

---

## Owned Halo Sampling Boundary

Handles owned area and halo sampling bounds for formation.

Current files:

```text
scripts/world_generation/formation/formation_halo_sampler.gd
scripts/world_generation/formation/formation_layer_builder.gd
```

Responsibilities:

* compute owned cells/regions
* compute halo sample requirements
* avoid neighbor-loaded dependency
* support seam-safe formation

---

## GenerationDiagnostics

Chunk-level explainability report.

Expected file:

```text
scripts/world_generation/diagnostics/generation_diagnostics.gd
```

Must report:

```text
definition identity
stage list
stage status
emitted layer counts
emitted feature counts
continuity fact counts
placement candidate counts
topology projection counts
formation product counts
validation errors
warnings
product signature
```

---

## StageDiagnostics

Per-stage explainability report.

Expected file:

```text
scripts/world_generation/diagnostics/stage_diagnostics.gd
```

Responsibilities:

* stage id
* stage category
* input summary
* output summary
* warnings
* validation errors
* deterministic signature contribution

---

## GeneratedChunkReport

Inspectable summary for debug UI/previews.

Expected file:

```text
scripts/world_generation/diagnostics/generated_chunk_report.gd
```

Responsibilities:

* summarize `GeneratedWorldChunk`
* expose human-readable diagnostics
* support previews without duplicating generation rules

---

## Current Compatibility Rules

## chunk_provider.gd

Current file:

```text
scripts/chunk_provider.gd
```

Long-term role:

```text
streaming provider adapter
generation request builder
cache bridge
compatibility facade
```

Methods to reduce/delegate over time:

```text
generate_chunk_generation_result(...)
_generate_base_terrain_cells(...)
_carve_rooms_and_paths(...)
_repair_walkable_connectivity(...)
_balance_walkable_percent(...)
_derive_topology_layers(...)
_terrain_diagnostics(...)
```

`chunk_provider.gd` may temporarily keep compatibility behavior. It should not remain the permanent generation policy owner.

---

## GeneratedChunkData

`GeneratedChunkData` is current compatibility output for existing visual/collision paths.

Rule:

```text
GeneratedWorldChunk = canonical product
GeneratedChunkData = compatibility bridge
```

---

## logic_grid

`logic_grid` is compatibility-only.

Target rule:

```text
logic_grid = compatibility alias for topology_projection["solid"]
```

It must not define the center of the long-term model.

---

## Terrain cells and topology layers

Current terrain cell and topology layer data may remain while migrating, but the target model is:

```text
semantic layers/features/continuity facts
→ topology projections
→ formation products
→ realization
```

---

## Dimensionality Contract

Every semantic layer and topology projection should declare its domain.

Supported descriptors:

```text
cell_grid_2d
surface_2_5d
stacked_layers
volume_grid_3d
graph_region
hybrid
```

The architecture must support vertical geometry, floors, walls, liquids below ground, shafts, bridges, roofs, caves, volumes, and graph/region spaces without rewriting the whole pipeline.

The repeated-flat-layer-above-itself bug class should become structurally impossible once stacked-layer generation and domain descriptors are in place.

---

## Algorithm Strategy Boundary

Allowed strategies include:

```text
noise
Voronoi
SDF sampling
authored masks
cellular automata
graph expansion
region partitioning
simulation passes
constraint solving
```

Rule:

```text
Strategies plug into fields and stages.
Strategies do not define the architecture.
```

No milestone should hardcode the roadmap around a single terrain algorithm.

---

## Extraction Rule

Do not create `Crystonix/procgen` yet.

Extraction requires proof that at least two meaningfully different world definitions and one non-Godot consumer need the same stable contracts.

Until then, reusable-looking concepts stay in:

```text
docs/proof-notes/
scripts/world_generation/
```

and are treated as Godot Lab proof code.

---

## Implementation Order

The first runtime implementation package after this contract should be:

```text
1. generated_chunk_identity.gd
2. world_definition_snapshot.gd
3. generation_context.gd
4. generation_pipeline.gd
5. generated_world_chunk.gd
6. generated_chunk_data_adapter.gd
7. legacy_chunk_generation_stage.gd
```

Then migrate `scripts/chunk_provider.gd` method-by-method instead of rewriting all generation behavior at once.

---

## Non-Goals

This contract does not authorize:

* concrete continent generator work
* concrete cave generator work
* Voronoi-first architecture
* SDF rewrite
* Runenwerk integration
* save/load architecture
* ECS spawning
* gameplay spawning
* asset extraction
* Bevy adapter work
* mesh/collision ownership inside generation
* premature procgen repository extraction
