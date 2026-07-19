---
name: unity-nodecanvas-architecture
description: Architect AND implement Unity games using NodeCanvas (FSM + Behavior Trees) with clean Body/Brain OOP separation and programmer/designer collaboration. Use whenever the user asks about Unity game architecture, NodeCanvas, behavior trees (BT), finite state machines (FSM), enemy/boss AI, game-state flow, designer-friendly workflows, writing custom ActionTask<T>/ConditionTask<T>/Sensor Tasks, Blackboard/BBParameter patterns, the NodeCanvas 3.x API (lifecycle, EndAction, IStateCallbackReceiver, FSMOwner, asset vs bound graphs), save systems for roguelikes, or how to split work between coders and designers and plan a Unity build roadmap. Also trigger on "Body vs Brain" architecture, Task/Blackboard patterns, or graph-driven AI.
---

# Unity + NodeCanvas Architecture (Body / Brain)

The rule of this codebase: **C# is the Body, NodeCanvas is the Brain.** Programmers build
capabilities; designers compose behavior; neither steps on the other's territory. The Brain
never manipulates data directly — it looks at the Body through the Blackboard and pulls its
triggers through thin custom Tasks.

> **Works under `game-feature-protocol`.** That protocol is the constitution (dependency
> direction, `.asmdef` layers, run-vs-meta state, reuse-first). This skill is the AI/behavior
> department operating *inside* those rules. Where they overlap they agree; where this skill is
> more specific (Tasks, Blackboard, FSM/BT), the protocol's dependency rule still wins:
> **a Task must never reach across features** — no direct `using` of another feature, no
> `FindObjectOfType`, no cross-feature singleton. Task scripts live in the same layer/`.asmdef`
> as the feature whose Body they command, and all dependencies still point down.

## The One Rule

- **Body** (C# code, programmers) knows *how*: walk, see, chase, pick a lock.
- **Brain** (NodeCanvas graphs, designers) decides *when*: "patrol until you hear a noise, then investigate."
- A designer never touches C#. A programmer never puts decisions inside a graph's job.
- **The Body must compile and work with the NodeCanvas package removed.** No `using NodeCanvas.*`
  in a Body script, no graph/Blackboard references. If the Body needs NodeCanvas, the architecture is wrong.

## Core Concepts (teach these when asked)

### FSM vs State Pattern vs Behavior Tree

| Concept | What it is | When to use |
|---|---|---|
| **FSM** (Finite State Machine) | A *concept*: finite states, one active at a time, explicit transitions | Discrete modes with clear transitions (game loop, doors, menus) |
| **State Pattern** | One *OOP implementation* of FSM: class-per-state with a shared interface (`Enter/Update/Exit`) | When you implement an FSM in code and want Open/Closed extensibility |
| **Behavior Tree** (BT) | Tick-driven decision structure: re-evaluated top-down every frame, no "current state" | Continuous prioritized decisions (enemy AI, boss phases, director AI) |

Key clarifications users often need:
- FSM and "state machine" are the same thing (FSM = Finite State Machine).
- State Pattern is always OOP; FSM can be implemented with switch/enum, dictionaries, State Pattern, or a visual tool like NodeCanvas.
- BT is not limited to enemies — any *deciding agent* qualifies: bosses, companions, crowd NPCs, or a Left 4 Dead-style Director AI with no character at all.

### FSM or BT? (the deliberate split)

- **Game Flow uses an FSM** — the run loop (Menu → Build → Explore → Results) is discrete modes waiting on events.
- **Enemies use BTs** — they weigh multiple priorities every frame (see player > hear noise > patrol). An FSM here explodes into a web of transitions; a BT's Selector ordering handles priority for free.
- **Hybrid** — FSM on top for modes, a nested BT inside a state for the messy decisions. Default to FSM; reach for BT when transition spaghetti appears.

### The layer stack

```
Graph (FSM/BT asset)   <- designer territory; states/transitions only
      |
  Blackboard           <- data bridge (designer bindings + Sensor Tasks write; Tasks read)
      |
Tasks (Action/Condition/Sensor)  <- programmer-written glue; thin wrappers only
      |
Body (Game Systems)    <- Controller, Perception, Locomotion; NO NodeCanvas knowledge
```

### Who writes the Blackboard?

The Body never touches the Blackboard (it doesn't know NodeCanvas exists), and graphs don't
compute — so Blackboard variables get populated **exactly two ways**:

1. **Designer bindings** — scene/prefab references bound in the inspector (`PlayerTransform`).
2. **Sensor Tasks** — thin Tasks that read a Body component and publish the result to a
   `[BlackboardOnly]` *out*-parameter. This is the **only** place allowed to know both sides.

> Never solve this with a Body script that writes the Blackboard, and never let a Task call
> `blackboard.SetValue()` for anything but its own declared out-parameter. Conditions that only
> compare can also read the typed Body directly (see `IsTargetInRange` in the templates) instead
> of going through the Blackboard at all.

## NodeCanvas API Essentials (verified against NodeCanvas 3.x)

- **Typed agent via generics**: `ActionTask<EnemyController>` makes `agent` strongly typed and
  auto-requires that component on the GameObject. The old `[AgentType]` attribute is **deprecated
  since v2.7.0 — never use it.** Only **one** generic type argument is supported.
- **ActionTask lifecycle** (all `protected override`):
  - `string OnInit()` — once per graph start; return an error string or null. **Cache lookups here.**
  - `void OnExecute()` — once each time the action starts.
  - `void OnUpdate()` — every frame while running.
  - `void OnStop()` — when the action ends **or is interrupted** by a transition. Cleanup here.
  - `void OnPause()` — when the graph pauses.
- **`EndAction(bool success)` is mandatory.** An action that never calls it runs forever and
  stalls the state. Every path in `OnExecute`/`OnUpdate` must eventually reach it.
- **ConditionTask**: override `bool OnCheck()`. `OnEnable`/`OnDisable` fire when it becomes active/inactive.
- **BBParameter**: read/write via `.value`. Prefer BBParameters over touching `.blackboard` directly.
  - `[RequiredField]` — task fails init if null/empty (red in editor).
  - `[BlackboardOnly]` — must bind to a Blackboard variable, not a literal.
- **Meta attributes** (`ParadoxNotion.Design`): `[Category("MyGame/Enemy")]` (use `/` for
  subcategories), `[Name("...")]`, `[Description("...")]`. Framework types are in `NodeCanvas.Framework`.
- **Task helpers**: `elapsedTime`, `SendEvent(string)`, `StartCoroutine(IEnumerator)`.
- **C# reacting to states**: implement `IStateCallbackReceiver`
  (`OnStateEnter/Update/Exit(IState)`) on a MonoBehaviour next to the `FSMOwner` — for
  *supplementary* SFX/UI/analytics only, **never** state behavior.
- **Code driving the FSM**: `GetComponent<FSMOwner>().SendEvent("EventName")` + an OnEvent
  transition. Don't force states from code.

## Writing Tasks (the glue layer)

Tasks are thin wrappers. All real logic lives in Body systems. A Task over ~30 lines means logic
is leaking in — extract it down into the Body.

**A Task may use exactly these NodeCanvas things:**
- `BBParameter<T>` — designer-tunable values / Blackboard bindings shown on the node
- `EndAction(true/false)` — report Success/Failure (ActionTask)
- `agent` — the typed owning component (via `ActionTask<T>`)
- for a **Sensor Task only**: writing its own `[BlackboardOnly]` out-parameter

**A Task must never:**
- do math/physics/pathfinding/coordinate juggling — that's the Body's job (a trivial comparison is fine)
- call `blackboard.SetValue()` for anything but its own out-parameter
- reference `graphOwner.graph` — a Task shouldn't know its own graph
- use a cross-feature singleton (`Player.Instance`) or `FindObjectOfType` — get the target from the Blackboard instead (violates `game-feature-protocol`)

Canonical ActionTask (typed agent, full lifecycle):

```csharp
[Category("MyGame/Enemy")]
[Description("Chase the target until out of give-up range.")]
public class ChaseTarget : ActionTask<EnemyLocomotion>   // agent IS the EnemyLocomotion
{
    public BBParameter<float> giveUpDistance = 15f;          // designer tunes this
    [RequiredField, BlackboardOnly] public BBParameter<Transform> target; // Sensor writes, Task reads

    protected override void OnExecute() => agent.StartChase(target.value);
    protected override void OnUpdate()
    {
        if (agent.DistanceToTarget > giveUpDistance.value)
            EndAction(false); // Failure -> Selector tries next branch
    }
    protected override void OnStop() => agent.StopChase(); // also runs on interruption
}
```

**Struct gotcha:** structs are value types — mutating a copy read from the Blackboard silently
does nothing. Treat Blackboard structs as read-only snapshots and route mutations through Body systems.

For the full template gallery (Body component, ActionTask, ConditionTask, Sensor Task, and the
C# ↔ FSM boundary), read `references/task-templates.md`.

## Workflow: adding a new AI behavior (bottom-up, never graph-first)

1. **Body first** — add/extend the capability as a plain C# method (`Dash()`, `Aim(Transform)`).
   Test it without any graph (a debug key if needed).
2. **Hook second** — write the thin `ActionTask<T>`/`ConditionTask<T>`/Sensor. BBParameters in,
   one verb, `EndAction` out, cleanup in `OnStop`.
3. **Blackboard third** — add/bind the variables the hook needs.
4. **Graph last** — drop the Task into a state and wire transitions in the editor.

If step 2 needs more than ~30 lines, the logic belongs in the Body — move it down.

## The Designer Contract

The point of this architecture is that a non-coder can read and edit graphs alone. That holds
only if both sides keep the contract:

**Coder side:**
- Every capability ships as a small named verb Task with `[Category("GameName/...")]` and a
  plain-language `[Name]`/`[Description]` ("Walks the enemy to a spot", not "Invokes locomotion delegate").
- **No reflected/built-in low-level tasks in graphs** (Execute Function, Get/Set Field, Send
  Message) — they turn the graph back into code drawn as boxes and break on rename.
- **Ship a test scene per feature** so the designer iterates on graphs without waiting for the full game.
- Blackboard variable names are UI too (`PlayerTransform`, not `tfRef`).

**Designer side:**
- Compose flows only from custom verb Tasks (`MyGame/...`) + transitions, and edit Blackboard values.
- Need a capability that doesn't exist? **Request a new verb Task** — never approximate it with low-level tasks.
- Never edit C# or add components to prefabs.

**Litmus test:** read the graph aloud. *"Patrol between my points. If I hear a noise, investigate.
If I see the player, chase."* If it doesn't sound like a sentence a producer understands, the
Tasks are too low-level — fix the Tasks, not the graph.

## Project Structure Template

```
Assets/
  Scripts/
    GameFlow/     <- manager + Tasks/ (Actions, Conditions)
    Player/       <- input-driven, no graphs
    Enemies/      <- Controller, Perception, Locomotion + Tasks/{Actions,Conditions}
    <Feature>/    <- one folder per module, Tasks/ subfolder if graph-facing
  AI/Graphs/      <- FSM + BT assets  == DESIGNER TERRITORY
  Data/           <- ScriptableObjects (items, tables, stats) == DESIGNER TERRITORY
```

- Task scripts belong to the **feature that owns the Body they command** — same `.asmdef`, same
  namespace (`Game.Enemies.Tasks`). `[Category]` mirrors the folder.
- **Asset graph (.asset) vs bound graph (embedded in prefab):** default to asset graphs — shared
  across every instance of an enemy type, diff-friendly, live in `AI/Graphs/`. Use a bound graph
  only for a one-off (a unique boss, a scripted sequence) with no reuse value.
- Modules that are pure mechanics (e.g., inventory) get **no graphs** — designer influence flows
  through ScriptableObject data instead. Graphs for *behavior*, SOs for *data*, code for *capability*.

## Save System Pattern (roguelike)

Two files with different lifetimes:

| File | Lifetime | Contents |
|---|---|---|
| `meta.json` | Permanent, cross-run | total runs, deaths, best score, unlocks |
| `run.json` | One run; deleted on death/escape | run seed, player state, inventory, opened chests, visited rooms |

Rules that prevent bugs:
- Save the **seed**, not the dungeon — regenerate deterministically on load.
- Enemy state is never saved — enemies respawn from the seed.
- `OnApplicationQuit` during gameplay → `SaveRun()`. Death or escape → `SaveMeta()` then `DeleteRun()`.
  On boot → `LoadMeta()`, and if `LoadRun()` finds a pending run, offer Continue.
- Build `SaveManager` + `ISaveable` in Phase 0 — every later system hooks into it; retrofitting is painful.

## Build Order (parallel-friendly)

1. **Foundation** — folders, core interfaces, SaveManager (first, not last)
2. **Player Body** — movement, interaction, any player-emitted signals (e.g., noise)
3. **Inventory / core mechanics** — pure C#, no graphs
4. **One enemy, bottom-up** — Perception/Locomotion Body → Tasks → first BT + **test scene** ← *the milestone where the designer starts working in parallel*
5. **Feature systems** — loot, locks, minigames
6. **Procedural assembly** — designers author pieces (room prefabs, spawn tables); code shuffles them; graphs never generate content
7. **Game Flow FSM** — full loop + save integration
8. **Presentation** — animation wrappers (e.g., `CharacterView` wrapping Spine), parallax; stubs earlier, polish here

Build the Body bottom-up so the designer gets a working sandbox as early as possible, then both tracks run in parallel.

## Planning Documents (game dev vs web dev)

Game planning starts from *feel and loop*, not data and screens. Order: **Core Loop → System
Diagram → FSM/BT diagrams → Data design (SOs) → Level design → Build plan**. An ERD equivalent
exists (save structs, item databases) but comes mid-plan, not first. When asked to plan a game
project, produce: the one-sentence pitch, the core loop with its retention hook, a module table
(Body vs Brain columns), Task lists per graph, the save schema, and a phased build order with the
designer-parallel milestone marked.

## Spaghetti Smells (reject in review)

- A Body script with `using NodeCanvas.*` or a serialized graph/Blackboard reference.
- A Task doing pathfinding, physics casts, or heavy math → move it into the Body.
- `GetComponent` inside a Task `OnUpdate` or a hot Body method → cache in `OnInit`/`Awake`.
- An ActionTask with a path that never calls `EndAction` → the state hangs.
- Cleanup only in the success branch → interruptions leak state; use `OnStop`.
- Reading `blackboard.GetVariable(...)` directly instead of a `BBParameter<T>` field.
- Gameplay behavior inside `IStateCallbackReceiver` callbacks, or code forcing a state instead of `SendEvent`.
- A reflected/built-in low-level task in a graph → replace with a named custom verb Task.
- A giant "do everything" Task instead of small composable verbs.
- A Task using a cross-feature singleton or `FindObjectOfType` → get it from the Blackboard.

## Definition of Done (for an AI behavior)

- [ ] Body compiles with zero NodeCanvas references; works when called directly.
- [ ] Every ActionTask reaches `EndAction` on all paths and cleans up in `OnStop`.
- [ ] Task inputs are `BBParameter<T>` with `[RequiredField]`/`[BlackboardOnly]` where apt; typed `ActionTask<T>` agent.
- [ ] Blackboard is written only by designer bindings and Sensor Tasks — never the Body.
- [ ] No math/physics in Tasks or graphs — only decisions and Body calls.
- [ ] `[Category]` + plain-language `[Name]`/`[Description]`; no reflected low-level tasks in any graph.
- [ ] Graph reads as a plain-English sentence a designer can edit without touching code.
- [ ] Save state correctly bucketed (run vs meta) per `game-feature-protocol`.

## Reference

- `references/task-templates.md` — full code gallery (Body, ActionTask, ConditionTask, Sensor, C# ↔ FSM boundary).
- `references/worked-example.md` — a complete stealth roguelike ("Loot Goblin") with all Tasks, FSM/BT layouts, Blackboard keys, save structs, and a week-by-week plan.
