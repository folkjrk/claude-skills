---
name: unity-nodecanvas-fsm
description: Hybrid OOP + NodeCanvas architecture for Unity — C# code is the "Body" (data, physics, mechanics), NodeCanvas FSM/BT graphs are the "Brain" (decisions, timing, game states). Use whenever writing enemy AI, boss behaviors, game-state flow, custom ActionTask/ConditionTask, or any NodeCanvas graph integration in a Unity project. Enforces strict Body/Brain separation via Blackboard and custom Task hooks.
---

# Unity + NodeCanvas Hybrid Architecture (Body / Brain)

The rule of this codebase: **C# is the Body, NodeCanvas is the Brain.** The Brain never
manipulates data directly — it looks at the Body through the Blackboard and pulls its
triggers through thin custom Tasks.

Read alongside `game-feature-protocol` (layering, ScriptableObjects, one-way dependencies).
Task scripts live in the same layer as the feature they command; all dependencies still point down.

---

## 1. The Four Layers

| Layer | What it is | Allowed to know about |
|---|---|---|
| **Body** | Pure C# components: `Health`, `Locomotion`, `Weapon`, `EnemyController`. Data, physics, animation, core mechanics. Standard OOP: encapsulation, interfaces, composition. | Unity API only. **Never `using NodeCanvas.*`** |
| **Blackboard** | NodeCanvas `Blackboard` component — the data bridge. Holds graph-visible variables (`PlayerTransform`, `TargetPosition`). | — |
| **Custom Tasks** | Thin C# adapters inheriting `ActionTask<T>` / `ConditionTask<T>`. The buttons the FSM presses. | Body + NodeCanvas.Framework |
| **Graph** | The visual FSM/BT asset. High-level states and transitions only (`Patrol → Chase → Attack`). | Tasks + Blackboard variables |

### Golden rules

1. **The Body doesn't know NodeCanvas exists.** No NodeCanvas usings, no graph references,
   no Blackboard reads. It compiles and works with the NodeCanvas package removed.
2. **The Brain decides *when*, the Body does *how*.** No math, physics, pathfinding, or
   coordinate juggling inside Tasks or graphs — a Task translates a decision into one or two
   Body method calls, then reports back with `EndAction`.
3. **Data crosses only through BBParameters.** Tasks declare `BBParameter<T>` fields;
   designers bind them to Blackboard variables in the editor. Never hardcode cross-references.
4. **One Task = one verb.** `MoveToTarget`, `PlayAttack`, `IsTargetInRange`. Fifty small
   Tasks that designers compose beat five clever ones.

### Who writes the Blackboard?

The Body never touches the Blackboard (rule 1), and graphs don't compute (rule 2) — so
Blackboard variables get populated exactly two ways:

- **Designer bindings** — scene/prefab references bound in the inspector (`PlayerTransform`).
- **Sensor Tasks** — thin Tasks that read from a Body component and publish the result to a
  `[BlackboardOnly]` out-parameter (see template in §3). This is the only place allowed to
  know both sides. Never solve this with a Body script that references the Blackboard.

### FSM or BT?

- **FSM** — discrete modes where "what state am I in" matters: game flow, boss phases,
  patrol/chase/attack loops with explicit transitions.
- **BT** — prioritized decision-making re-evaluated continuously: target selection,
  fallback chains, utility-style choices.
- **Hybrid** — FSM on top for modes, a nested BT inside a state for the messy decisions.
  Default to FSM; reach for BT when transition spaghetti appears.

---

## 2. NodeCanvas API Rules (verified against official NodeCanvas 3.x docs)

- **Typed agent via generics**: `ActionTask<EnemyController>` makes `agent` strongly typed to
  that component and auto-requires it on the GameObject. (The old `[AgentType]` attribute is
  deprecated since v2.7.0 — never use it.) Only **one** generic type argument is supported.
- **ActionTask lifecycle** (all `protected override`):
  - `string OnInit()` — once per graph start; return an error string or null. Cache lookups here.
  - `void OnExecute()` — once each time the action starts.
  - `void OnUpdate()` — every frame while running.
  - `void OnStop()` — when the action ends **or is interrupted** (state transition). Do cleanup here.
  - `void OnPause()` — when the graph pauses.
- **`EndAction(bool success)` is mandatory.** An action that never calls it runs forever and
  stalls the state. Every code path in `OnExecute`/`OnUpdate` must eventually reach it.
- **ConditionTask**: override `bool OnCheck()`; `OnEnable`/`OnDisable` fire when the condition
  becomes active/inactive.
- **BBParameter**: read/write through `.value` (`targetPosition.value`). Prefer BBParameters
  over touching the inherited `.blackboard` directly — the docs explicitly recommend this.
  - `[RequiredField]` — task fails init if the field is null/empty (shows red in editor).
  - `[BlackboardOnly]` — field must bind to a Blackboard variable, not a literal value.
- **Meta attributes** (namespace `ParadoxNotion.Design`): `[Category("MyGame/Enemy")]`
  (use `/` for subcategories), `[Name("...")]`, `[Description("...")]`. Framework types come
  from `NodeCanvas.Framework`.
- **Task helpers**: `elapsedTime` (seconds since action started), `SendEvent(string)`,
  `StartCoroutine(IEnumerator)`.
- **C# reacting to states**: implement `IStateCallbackReceiver`
  (`OnStateEnter/OnStateUpdate/OnStateExit(IState)`) on a MonoBehaviour next to the `FSMOwner`.
  The docs are explicit: this is for *supplementary* notifications (SFX, UI, analytics) —
  **never** define state behavior there.
- **Code driving the FSM**: call `GetComponent<FSMOwner>().SendEvent("EventName")` and use an
  OnEvent transition in the graph. Don't force states from code.

---

## 3. Templates

### Body component (pure OOP — no NodeCanvas)

```csharp
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class EnemyController : MonoBehaviour
{
    [SerializeField] private float movementSpeed = 5f;

    public float CurrentHealth { get; private set; } = 100f;

    private Animator animator;   // cached — never GetComponent per call

    private void Awake()
    {
        animator = GetComponent<Animator>();
    }

    public void MoveTowards(Vector3 targetPosition)
    {
        transform.position = Vector3.MoveTowards(
            transform.position, targetPosition, movementSpeed * Time.deltaTime);
    }

    public void StopMoving() { /* zero velocity / stop NavMeshAgent */ }

    public void PlayAnimation(string triggerName)
    {
        animator.SetTrigger(triggerName);
    }
}
```

### ActionTask hook (thin adapter)

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("Commands the EnemyController to move toward a target position.")]
public class MoveToTargetAction : ActionTask<EnemyController>
{
    [RequiredField]
    public BBParameter<Vector3> targetPosition;
    public BBParameter<float> arriveDistance = 0.5f;

    protected override void OnExecute()
    {
        agent.PlayAnimation("Walk");    // agent IS the EnemyController
    }

    protected override void OnUpdate()
    {
        agent.MoveTowards(targetPosition.value);

        if (Vector3.Distance(agent.transform.position, targetPosition.value)
            < arriveDistance.value)
        {
            EndAction(true);            // every path must reach EndAction
        }
    }

    protected override void OnStop()
    {
        agent.StopMoving();             // also runs when a transition interrupts us
    }
}
```

### ConditionTask hook

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("True when the target is within range of the enemy.")]
public class IsTargetInRange : ConditionTask<EnemyController>
{
    [RequiredField, BlackboardOnly]
    public BBParameter<Transform> target;
    public BBParameter<float> range = 10f;

    protected override bool OnCheck()
    {
        return Vector3.Distance(agent.transform.position, target.value.position)
               <= range.value;
    }
}
```

### Sensor Task (the only two-way adapter)

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("Reads the Body's perception and publishes the current target to the Blackboard.")]
public class UpdateTargetSensor : ActionTask<EnemyPerception>
{
    [BlackboardOnly]
    public BBParameter<Transform> outTarget;   // out-value: Task writes, graph reads

    protected override void OnExecute()
    {
        outTarget.value = agent.CurrentTarget;  // Body stays NodeCanvas-free
        EndAction(outTarget.value != null);
    }
}
```

### C# ↔ FSM boundary (supplementary only)

```csharp
using NodeCanvas.Framework;
using NodeCanvas.StateMachines;
using UnityEngine;

public class EnemyStateFX : MonoBehaviour, IStateCallbackReceiver
{
    // SFX / UI / analytics ONLY — never gameplay behavior here.
    public void OnStateEnter(IState state) { }
    public void OnStateUpdate(IState state) { }
    public void OnStateExit(IState state) { }
}

// Driving the FSM from code: send an event, let the graph decide the transition.
// GetComponent<FSMOwner>().SendEvent("PlayerSpotted");
```

---

## 4. Project Layout

```
Assets/
  Scripts/
    <Feature>/                    Body components (EnemyController, Health, ...)
    <Feature>/Tasks/
      Actions/                    ActionTask<T> hooks
      Conditions/                 ConditionTask<T> hooks
  AI/
    Graphs/                       FSM / BT assets (.asset)
```

- Task scripts belong to the **feature that owns the Body they command** — same asmdef,
  same namespace (`Game.Enemies.Tasks`).
- `[Category]` mirrors the folder: `MyGame/Enemy`, `MyGame/GameFlow`.
- Graph assets are content, like ScriptableObjects — designers own them.
- **Asset graph (.asset) vs bound graph (embedded in prefab):** default to asset graphs —
  shared across every instance of an enemy type, live in `AI/Graphs/`, diff-friendly.
  Use a bound graph only for a one-off (a unique boss, a scripted scene sequence) where
  the graph has no reuse value and belongs with the prefab.

---

## 5. Workflow: adding a new AI behavior

Work **bottom-up**, never graph-first:

1. **Body first** — add/extend the capability as a plain C# method (`Dash()`, `Aim(Transform)`).
   Test it works without any graph (call it from a debug key if needed).
2. **Hook second** — write the thin `ActionTask<T>`/`ConditionTask<T>` that calls it.
   BBParameters in, one verb, `EndAction` out, cleanup in `OnStop`.
3. **Blackboard third** — add/bind the variables the hook needs.
4. **Graph last** — drop the Task into a state and wire transitions in the editor.

If step 2 needs more than ~30 lines, the logic belongs in the Body — move it down.

---

## 6. The Designer Contract

The whole point of this architecture is that a non-coder designer can read and edit graphs
alone. That only holds if both sides keep the contract:

**Coder side:**
- **No reflected/built-in low-level tasks in graphs.** NodeCanvas ships "Execute Function",
  "Get/Set Field", "Send Message" and similar reflection tasks — banned. They turn the graph
  back into code drawn as boxes, break on rename, and designers can't read them. Every
  capability a graph needs gets a named custom verb Task instead.
- **`[Name]` and `[Description]` are the designer's UI.** Write them in plain product
  language ("Walks the enemy to a spot", not "Invokes locomotion delegate"). No programmer
  jargon, no class names. Same for Blackboard variable names (`PlayerTransform`, not `tfRef`).
- **Ship a test scene per feature** where the graph can be run and tweaked in isolation, so
  the designer can iterate without asking for help.

**Designer side:**
- Compose flows only from custom verb Tasks (`MyGame/...` categories) + transitions.
- Need a capability that doesn't exist? **Request a new verb Task from a coder** — never
  approximate it by wiring low-level/built-in tasks together.
- Edit graphs and Blackboard values freely; never edit C# or add components to prefabs.

Litmus test: read the graph aloud. If it doesn't sound like a sentence a producer would
understand ("When the player is in range, chase; on contact, attack"), it's too low-level.

---

## 7. Spaghetti Smells (reject in review)

- A Task doing pathfinding, physics casts, or heavy math → move it into the Body.
- A Body script with `using NodeCanvas.*` or a serialized graph/Blackboard reference.
- `GetComponent` inside `OnUpdate` (Task) or a hot Body method → cache in `OnInit`/`Awake`.
- An ActionTask with a code path that never calls `EndAction` → the state hangs.
- Cleanup in `OnUpdate`'s success branch only → interruptions leak state; use `OnStop`.
- Reading `blackboard.GetVariable(...)` directly instead of a `BBParameter<T>` field.
- Gameplay behavior inside `IStateCallbackReceiver` callbacks.
- Code calling into the FSM to force a state instead of `SendEvent` + a graph transition.
- A giant "do everything" Task instead of small composable verbs.
- A reflected/built-in low-level task ("Execute Function", "Get/Set Field") in a graph →
  replace with a named custom verb Task (see §6).

---

## 8. Definition of Done

- [ ] Body compiles with zero NodeCanvas references; works when called directly.
- [ ] Every ActionTask reaches `EndAction` on all paths and cleans up in `OnStop`.
- [ ] All Task inputs are `BBParameter<T>` with `[RequiredField]`/`[BlackboardOnly]` where apt.
- [ ] Tasks have `[Category]` + `[Description]`; typed agent via `ActionTask<T>`.
- [ ] `[Name]`/`[Description]` written in plain product language a non-coder understands.
- [ ] No math/physics in Tasks or graphs — only decisions and Body calls.
- [ ] No reflected/built-in low-level tasks in any graph — custom verb Tasks only.
- [ ] Graph reads as a plain-English flowchart a designer can edit without touching code.
