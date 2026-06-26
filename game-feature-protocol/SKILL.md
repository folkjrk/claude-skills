---
name: game-feature-protocol
description: Protocol for building and refactoring features in this Unity roguelike so code stays REUSABLE (no spaghetti), MODULAR, and SCALABLE. Use whenever creating a new system (combat, enemies, items, dungeon, run loop, UI) or refactoring an existing one. Adapts the Feature-Modularization-Protocol (UFMP) to Unity/C#. Enforces one-way dependencies, ScriptableObject-driven data, composition, and event decoupling.
---

# Game Feature Protocol (Unity adaptation of UFMP)

This is the law of the codebase. Follow it for **every** feature so the project stays reusable,
easy to manage, and scalable — and so big-picture flow isn't broken by local changes.

Read alongside `Docs/ARCHITECTURE.md` (the concrete layer map) and
`Assets/Cutscene/ARCHITECTURE.md` (the reference implementation of these rules).

---

## 1. The Four Goals (why this skill exists)

1. **Reuse, don't repeat** → no spaghetti. Before writing code, find what exists.
2. **Modular & manageable** → each feature is a self-contained module with clear edges.
3. **Scalable** → adding content never forces edits to unrelated code.
4. **Protect the big-picture flow** → local changes can't ripple across the project.

---

## 2. The One Law: dependencies point DOWN only

```
UI ─► Features (Player, Enemies, Items, Dungeon, Run, Cutscene) ─► Combat ─► Core
```

- **Core** (services, save, events, input) depends on **nothing**.
- **Combat** (Health, IDamageable, damage) depends only on Core.
- **Features** depend on Core/Combat — **never on each other**.
- **UI** may depend on features.

If you ever need Player → Enemies (or any sideways/upward arrow), **stop**: route it through an
interface or event in Core/Combat instead. A sideways dependency is the #1 spaghetti seed.

Enforce with **one `.asmdef` per layer**, dependencies pointing down. A wrong reference then
fails to compile — the structure defends itself.

---

## 3. Reuse-First Checklist (do BEFORE writing any code)

1. **Search for an existing system.** Grep the relevant folder + `Core`/`Combat`. Does a
   component, service, SO, or interface already do this? (e.g. need HP? → `Health`. Need to
   remember something? → `GameStateService`. Need input? → `PlayerInput`.)
2. **Can I extend instead of add?** Prefer a new ScriptableObject asset or a serialized field
   over a new class. (Adding an NPC = a new `Conversation` asset, not new code — copy that idea.)
3. **Is this cross-cutting?** If two+ features need it, it belongs in **Core** or **Combat**,
   not inside one feature.
4. **Am I about to reference another feature directly?** Replace with an interface/event.

Only write new code once all four pass.

---

## 4. Anatomy of a Feature Module

Every feature (e.g. `Enemies/`) is structured the same way:

```
Enemies/
  Scripts/
    EnemyController.cs        MonoBehaviour: behavior, wires components together
    EnemyAI.cs                logic (plain C# where possible — testable, no Unity refs)
    EnemySpawner.cs           creates instances from data
    IEnemy.cs (if needed)     abstraction other layers may use
  (asmdef: Game.Enemies → depends on Game.Core, Game.Combat)
Data/Enemies/                 EnemyDefinition (SO) assets — the content
Prefabs/Enemies/              prefab visuals + components
```

Rules:
- **Data in ScriptableObjects, behavior in MonoBehaviours.** Content authors create assets;
  programmers don't touch code per enemy/item.
- **Composition over inheritance.** Capabilities are components (`Health`, `DamageDealer`),
  attached, not subclassed. No deep hierarchies.
- **Logic separated from Unity** where feasible (plain C# classes like `ConversationRunner`,
  `GameState`) so it's testable and reusable.

---

## 5. The Module Protocol (steps for a new/refactored feature)

1. **Define the boundary.** One sentence: what this module owns, what it does NOT own.
2. **Identify dependencies** — they must all be *downward* (Core/Combat). List them; if any
   point sideways, design an interface/event instead.
3. **Model the data** — what's a ScriptableObject (content) vs runtime state vs persisted state.
   Persisted → `GameStateService`. Run-scoped → a plain object, never saved.
4. **Define the public surface** — the few methods/events other layers use. Keep it tiny.
   Everything else is private. (See `DialogueBox`/`CutsceneController` public API size.)
5. **Communicate outward via events** (`OnDied`, `OnItemPicked`) — like
   `CutsceneController.OnCutsceneStarted`. Don't let outsiders poll or reach in.
6. **Wire through a service** if it's global (`RunManager.Instance`), following the
   `GameStateService` pattern: single owner, static accessor, safe no-op if absent.
7. **Add the asmdef + namespace** (`Game.<Feature>`). Verify it compiles with only downward refs.
8. **Update `Docs/ARCHITECTURE.md`** — flip the to-do checkbox, note the public surface.

---

## 6. Spaghetti Smells (reject these in review)

- A feature script `using` another feature's namespace (Player using Enemies).
- `FindObjectOfType` reaching across features instead of an injected/served reference.
- A `switch` on enemy/item *type* in shared code → should be data (SO) or polymorphism.
- Display strings, tuning numbers, or content hardcoded in logic → move to SO / serialized field.
- A growing method-parameter list → pass a small struct/view-model (see `DialogueLine`).
- Persisting run-scoped state, or putting meta-progress in a scene object instead of `GameState`.
- A new singleton that duplicates an existing service.

---

## 7. Big-Picture Flow to Protect (the roguelike loop)

Never let a feature break the **run-resets / meta-persists** split:

```
HUB ─StartRun─► Dungeon ─(Death|Escape)─► Result ─reward→GameStateService─► HUB ↺
```

- **RUN state** (HP, depth, seed, this-run inventory, live enemies) = in memory, discarded each
  run. Owned by `RunManager`. **Never saved.**
- **META state** (currency, unlocks, upgrades, best-depth, story flags) = `GameStateService`.
  **Always persisted.**

Before adding state to any feature, ask: *run-scoped or persistent?* Put it in the right bucket.
A feature must not assume it lives forever — it gets reset every run.

---

## 8. Definition of Done for a feature

- [ ] Dependencies point downward only; compiles under its `.asmdef`.
- [ ] Data is in ScriptableObjects; no content hardcoded in logic.
- [ ] Talks to other features via interfaces/events, not direct refs.
- [ ] State is correctly bucketed (run vs meta).
- [ ] Public surface is small and documented; internals private.
- [ ] `Docs/ARCHITECTURE.md` checkbox + notes updated.
