# Procgen Rust Boundary Review

## Purpose

This note reviews whether Godot Lab world generation should be extracted into a Rust crate or a new standalone repository now.

Decision:

```text
Do not create Crystonix/procgen now.
Do not extract Godot Lab world generation now.
Do not add a new Rust crate as the canonical owner now.
Do not add Runenwerk integration now.
Do not merge grid or spatial_streaming into another owner now.
```

A standalone Rust procgen repository is premature unless later evidence proves that neither Godot Lab, Runenwerk `domain/procgen`, `grid`, nor `spatial_streaming` owns the required invariants.

This is a boundary review only. It does not authorize implementation work, repo creation, crate creation, Runenwerk integration, new algorithms, M7+ world-generation work, or extraction.

---

## Current M15 Ownership Review

Decision:

```text
defer_extraction_and_integration
```

Current evidence:

```text
Godot Lab product contracts are proven enough to review.
Two meaningfully different definition contracts are proven.
Host adapter boundaries are non-authoritative.
Legacy generation is explicitly retained.
New runtime abstractions are explicitly deferred.
No replacement generation authority is proven.
No non-Godot consumer need is proven.
Runenwerk is not proven the wrong owner.
Runenwerk integration pressure is not proven.
No smaller Rust API is proven.
No durable external invariants are proven.
```

Current ownership findings:

```text
Godot Lab remains proof host and Godot adapter owner.
Runenwerk remains the future candidate for Runenwerk-specific procgen ownership if pressure is later proven.
grid remains owner of reusable grid/topology mechanics.
spatial_streaming remains owner of payload-neutral streaming lifecycle.
Crystonix/procgen has no owner yet and must not be created.
```

Guarded artifacts:

```text
Crystonix/procgen
Rust procgen crate
Runenwerk integration
Runenwerk final procgen graph contract
Runenwerk SDF payload ownership
grid/spatial_streaming merge
```

The current review is encoded by:

```text
scripts/world_generation/extraction_ownership_review.gd
tests/world_generation_extraction_ownership_review_smoke.gd
```

---

## Current Gate

The original Godot Lab world-generation gate was:

```text
hash hardening
smoke tests
provider pipeline wiring
```

That gate has since been completed and extended through semantic layers, topology projections, formation products, data-only features/continuity/placement, diagnostics/provenance, cache identity, provider shrink, definition diversity, domain contracts, host adapter review, legacy retention, and runtime abstraction review.

The immediate proof must establish that Godot Lab can route the current legacy generator through the canonical migration path:

```text
WorldDefinitionSnapshot
→ GenerationContext
→ GenerationPipeline
→ LegacyChunkGenerationStage
→ GeneratedWorldChunk
→ GeneratedChunkDataAdapter
→ Godot realization
```

That path is now deterministic, smoke-tested, and adapter-compatible. It still does not justify Rust extraction because the current blockers are ownership and external-consumer evidence, not local migration mechanics.

---

## Boundary Decision

### 1. Godot Lab

Godot Lab owns the proof host role.

It may own:

```text
Godot-facing authoring resources
GDScript migration path
world-generation proof scenes
Godot realization
visual/collision/debug builders
compatibility adapters
provider/cache bridge code
world-generation contract proving ground
```

Godot Lab should not become the permanent owner of reusable procedural generation invariants.

Godot Lab should prove:

```text
GeneratedWorldChunk product shape
topology projection boundaries
formation product boundaries
provider adapter boundaries
compatibility output preservation
deterministic identity/hash semantics
```

But proof is not extraction. A contract that only works for the current Godot Lab legacy generator is not ready to become a Rust crate.

---

### 2. Runenwerk

Runenwerk already has an existing Rust domain slot for procgen:

```text
domain/procgen
```

That crate currently owns or is positioned to own:

```text
ProcgenDocument
deterministic procgen identity
cache lineage
ratification
lowering
planning metadata
product descriptors
field preview formation
```

It also depends on or composes with existing Runenwerk domain crates:

```text
graph
product
ratification
spatial
world_ops
world_sdf
```

That matters because a new standalone `Crystonix/procgen` repository would immediately overlap with existing Runenwerk procgen ownership.

Preferred future direction, if Rust ownership becomes necessary:

```text
First choice: extend Runenwerk domain/procgen.
Second choice: add a narrowly justified Runenwerk domain crate if domain/procgen is too broad or wrongly shaped.
Last resort: create standalone Crystonix/procgen only after external consumer pressure proves Runenwerk is the wrong owner.
```

Do not make Godot Lab world generation depend on Runenwerk during the current gate. The correct next step is comparison, not integration.

---

### 3. grid

`grid` owns reusable grid and topology mechanics.

It may own:

```text
grid math
grid storage
tile topology
dual-grid topology helpers
grid generation helpers
thin Godot grid adapter
```

It should not own semantic world-generation truth.

In world-generation terms, `grid` should receive topology views or descriptor-ready products. It should not decide what a biome, cave, river, dungeon, continent, world feature, formation product, or semantic layer means.

Boundary rule:

```text
grid owns reusable grid/topology mechanics.
world generation owns semantic world facts and consumer projections.
Godot owns realization.
```

---

### 4. spatial_streaming

`spatial_streaming` owns payload-neutral streaming lifecycle.

It may own:

```text
spatial addressing
spatial indexing
chunk identity
chunk residency
streaming request lifecycle
focus-driven desired residency
payload-neutral streaming events
```

It should not own:

```text
procgen
world model
semantic world facts
SDF payload truth
asset ownership
ECS spawning
renderer resources
save formats
Godot scene ownership
```

Godot Lab should consume streaming requests and turn them into generation contexts. It should not move generation policy into streaming lifecycle code.

Boundary rule:

```text
spatial_streaming asks for payloads.
world generation produces payloads.
host adapters realize payloads.
```

---

## Should grid and spatial_streaming be put back into Runenwerk?

Not now.

Keep `grid` and `spatial_streaming` separate unless there is strong evidence that repo separation is creating more architectural cost than it removes.

Current recommendation:

```text
Do not merge grid back into Runenwerk now.
Do not merge spatial_streaming back into Runenwerk now.
Keep Runenwerk compatibility wrappers/adapters pointing at the extracted crates.
```

Reasoning:

* `grid` has a clean, reusable, engine-neutral core boundary with an optional Godot adapter.
* `spatial_streaming` has a clean, payload-neutral lifecycle boundary and explicitly avoids owning procgen/world-model concerns.
* Runenwerk can depend on these crates or wrap them without re-owning their invariants.
* Re-merging now would increase Runenwerk repository mass without solving the current Godot Lab world-generation migration problem.
* Re-merging would blur the distinction between reusable low-level infrastructure and Runenwerk-specific domain/runtime composition.

Reconsider re-merging only if one of these becomes true:

```text
1. Cross-repo versioning overhead blocks development repeatedly.
2. Most changes require synchronized commits across Runenwerk, grid, and spatial_streaming.
3. The extracted crates cannot maintain stable public boundaries.
4. Runenwerk-specific invariants dominate the crate APIs.
5. CI/release/tooling cost exceeds the architectural benefit of separation.
```

Until then, keep the split.

---

## Why a New Rust Procgen Repo Is Premature

A new standalone `Crystonix/procgen` repository would currently create more ambiguity than clarity.

It would compete with:

```text
Runenwerk/domain/procgen
Runenwerk/domain/product
Runenwerk/domain/world_ops
Runenwerk/domain/world_sdf
Runenwerk/domain/spatial
Runenwerk/domain/graph
grid topology helpers
spatial_streaming lifecycle contracts
Godot Lab proof contracts
```

The likely failure mode is three sources of procgen truth:

```text
Godot Lab world-generation docs and GDScript scaffolding
Runenwerk domain/procgen Rust contracts
new standalone Crystonix/procgen Rust contracts
```

That would make the architecture less coherent, not more reusable.

A standalone repo should own invariants, not merely shared code. At this point, the invariants are not proven outside Godot Lab and may already belong inside Runenwerk's existing procgen domain.

---

## Required Evidence Before Any Rust Extraction

Extraction is justified only after all of these are true:

```text
1. Godot Lab has completed the current migration gate.
2. GeneratedWorldChunk is the canonical product path in practice.
3. TopologyProjectionSet and FormationProductSet are stable enough to compare against Runenwerk product/world_ops/world_sdf concepts.
4. At least two meaningfully different Godot Lab world definitions use the same contracts.
5. A real non-Godot and non-Runenwerk consumer needs the same contracts.
6. Runenwerk domain/procgen is proven to be the wrong owner.
7. grid and spatial_streaming boundaries remain intact and do not already cover the reusable part.
8. The extracted Rust API would be smaller than the Godot Lab proof implementation.
9. The extracted crate/repo would own durable invariants, not migration scaffolding.
```

If these are not true, do not extract.

---

## Review Sequence After the Current Gate

After hash hardening, smoke tests, and provider pipeline wiring are complete, do this review sequence:

```text
1. Compare Godot Lab GeneratedWorldChunk against Runenwerk procgen/product descriptors.
2. Compare Godot Lab topology projections against grid topology and Runenwerk product contracts.
3. Compare Godot Lab formation products against Runenwerk world_ops/world_sdf/product concepts.
4. Compare Godot Lab generation identity/cache keys against Runenwerk procgen cache lineage.
5. Decide whether Godot Lab concepts are proof-only, Runenwerk extensions, grid/topology concerns, spatial_streaming lifecycle concerns, or genuinely new reusable procgen invariants.
```

The expected result is not a new repo. The expected result is a boundary decision.

---

## Preferred Future Options

Ranked from most likely to least likely:

### Option A — Keep proof in Godot Lab, extend Runenwerk/domain/procgen later

Best default.

Use this if Godot Lab generated products map cleanly to Runenwerk procgen documents, product descriptors, world operation windows, field products, or SDF products.

### Option B — Add a narrow Runenwerk domain crate

Possible only if `domain/procgen` becomes too broad, but the owner still belongs in Runenwerk.

Examples might be a narrowly scoped world-generation artifact or evaluator contract crate, but only after the proof matures.

### Option C — Keep docs-only shared contract

Valid if Godot Lab and Runenwerk only need conceptual alignment, not shared code.

### Option D — Create standalone Crystonix/procgen

Last resort.

Only valid after two Godot Lab world definitions and a real non-Godot/non-Runenwerk consumer prove that Runenwerk is the wrong owner.

---

## Final Decision

```text
Do not create Crystonix/procgen now.
Do not extract Godot Lab world generation now.
Do not merge grid back into Runenwerk now.
Do not merge spatial_streaming back into Runenwerk now.
Do not add Runenwerk integration now.
Do not add a Rust procgen crate now.
Do not add new algorithms now.
```

Keep the current Godot Lab proof in Godot Lab.

Future comparison should be against Runenwerk `domain/procgen`, `product`, `world_ops`, `world_sdf`, `spatial`, `graph`, plus the separate `grid` and `spatial_streaming` repositories.

Only after that comparison should ownership move.
