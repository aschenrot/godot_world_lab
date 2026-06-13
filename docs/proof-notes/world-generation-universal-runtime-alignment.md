# Godot World Lab — World Generation Universal Runtime Alignment

## Purpose

This note clarifies how the Godot Lab world-generation roadmap and contract should be read against the Universal Domain Runtime Pipeline.

It is a docs-only architecture guardrail. It does not authorize runtime implementation work beyond the current migration gate.

---

## Critical Position

Godot Lab world generation is not targeting a single universal graph that can generate any possible world.

The target is a deterministic, data-first world-generation runtime that can support multiple typed world-domain families through explicit contracts, deterministic evaluation, generated facts, consumer projections, and host adapters.

The correct claim is:

```text
Godot Lab world generation can support multiple world families when each family declares explicit domain descriptors, semantics, projections, continuity rules, formation rules, and host-consumer outputs.
```

The incorrect claim is:

```text
Godot Lab world generation can generate any world through one generic graph.
```

That overgeneric shape is rejected. A single universal generic graph is not an acceptable mature world-generation domain model because it would collapse domain meaning into node soup.

---

## Relationship To The Universal Domain Runtime Pipeline

The long-term world-generation architecture should align with the Universal Domain Runtime Pipeline, but the current repo must not claim full maturity yet.

Current roadmap concepts map only to the early/mid shape:

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

A future mature shape may introduce explicit intermediate layers:

```text
WorldDefinition
→ WorldDefinitionSnapshot
→ WorldGenerationSemantics
→ WorldGenerationProgram
→ WorldGenerationCompiler
→ WorldGenerationArtifact
→ WorldGenerationEvaluator + GenerationContext
→ GeneratedWorldChunk
→ TopologyProjectionSet
→ FormationProductSet
→ Godot host adapters
→ visual / collision / debug realization
```

Those future concepts are allowed as architecture direction only:

```text
WorldGenerationSemantics
WorldGenerationProgram
WorldGenerationCompiler
WorldGenerationArtifact
WorldGenerationEvaluator
```

They must not be added during the current migration gate.

---

## GeneratedWorldChunk Is Not A Runtime Artifact

`GeneratedWorldChunk` is an evaluator output product.

It is not a runtime artifact, compiled program, cache manifest, host profile, registry snapshot, or reusable execution package.

Correct ownership:

```text
WorldGenerationArtifact
  compiled executable generation contract, if/when that layer exists later

WorldGenerationEvaluator
  deterministic executor for artifact + context, if/when that layer exists later

GeneratedWorldChunk
  canonical data-only generated product emitted by evaluation
```

Until a real artifact/compiler layer exists, the existing `GenerationPipeline` remains a migration-time execution spine. It must not be renamed into a full program/compiler/artifact architecture prematurely.

---

## Current Migration Gate

The current gate remains:

```text
hash hardening
smoke tests
provider pipeline wiring
```

Do not start M7+ while this gate is incomplete.

The current gate does not authorize:

```text
WorldGenerationSemantics implementation
WorldGenerationProgram implementation
WorldGenerationCompiler implementation
WorldGenerationArtifact implementation
WorldGenerationEvaluator extraction
new algorithms
Voronoi-first work
continent generation
cave generation
SDF rewrite
Runenwerk integration
save/load
spawning
visual rewrite
collision rewrite
procgen extraction
```

---

## Typed World-Domain Families

Supported world-domain families must stay explicit:

```text
cell_grid_2d
surface_2_5d
stacked_layers
volume_grid_3d
graph_region
hybrid
```

Each domain descriptor must eventually define:

```text
coordinate rules
ownership and halo rules
sampling rules
neighbor and continuity rules
projection rules
formation rules
supported consumer outputs
```

These descriptors are not labels over one flat 2D generator. They are contracts that determine how generation facts are owned, sampled, connected, projected, and realized.

---

## Algorithm Strategy Boundary

Algorithms are strategies, not architecture.

The following must remain field, stage, semantic, projection, or formation strategies:

```text
noise
Voronoi
SDF sampling
caves
continents
rooms
rivers
biomes
graph expansion
cellular automata
simulation passes
constraint solving
```

No roadmap phase should lock the architecture around one of these strategies.

---

## Overgeneric Architecture Boundary

A generic runtime pipeline is useful as a spine, but the mature world-generation model must still be domain-specific.

Rejected shape:

```text
one universal generic graph
→ untyped nodes
→ arbitrary outputs
→ host-specific interpretation
```

Required shape:

```text
typed domain descriptor
→ validated semantic contracts
→ deterministic program/artifact later, when justified
→ evaluator output facts
→ explicit topology projections
→ explicit formation products
→ host adapters
```

The architecture must be extensible without becoming meaningless.

---

## Maturity Claim Boundary

The roadmap must not claim full Universal Domain Runtime Pipeline maturity until all of the following exist and are proven by a production-equivalent vertical slice:

```text
semantic formation
program contract
runtime artifact
compiler
evaluator boundary
host boundary
diagnostics
provenance
stale-artifact checks
production-equivalent vertical slice
```

Until then, Godot Lab should claim only that it is migrating toward that shape.

---

## Consequence For The Existing Roadmap

Read `docs/proof-notes/world-generation-roadmap.md` and `docs/proof-notes/world-generation-contract.md` with these constraints:

* `GeneratedWorldChunk` means generated output product, not runtime artifact.
* `GenerationPipeline` is the current migration execution spine, not the final program/compiler model.
* `WorldGenerationSemantics`, `WorldGenerationProgram`, `WorldGenerationCompiler`, `WorldGenerationArtifact`, and `WorldGenerationEvaluator` are future architecture candidates only.
* Domain descriptors must become real contracts before claims about stacked, volumetric, graph, or hybrid worlds are accepted.
* The current implementation sequence stays intact.
* The next implementation work remains hash hardening, smoke tests, and provider pipeline wiring.

---

## Success Standard

Godot Lab world generation succeeds when it can prove multiple meaningfully different world definitions through the same deterministic contracts without making generation truth depend on Godot runtime objects, loaded neighbor chunks, rendering, collision, save state, spawning, or one preferred algorithm.
