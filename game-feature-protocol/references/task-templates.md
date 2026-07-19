# NodeCanvas Task Templates

Copy-paste starting points for the four Task shapes and the C# ↔ FSM boundary. All verified
against the NodeCanvas 3.x API. Read `../unity-nodecanvas-architecture.md` for the rules these
templates obey (Body/Brain split, typed agent, `EndAction`, Sensor-Task-writes-Blackboard).

## Body component (pure OOP — no NodeCanvas)

The Body knows nothing about NodeCanvas. It exposes verbs (methods) and computed state (properties).

```csharp
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class EnemyController : MonoBehaviour
{
    [SerializeField] private float movementSpeed = 5f;

    public float CurrentHealth { get; private set; } = 100f;

    private Animator animator;   // cached — never GetComponent per call

    private void Awake() => animator = GetComponent<Animator>();

    public void MoveTowards(Vector3 targetPosition)
    {
        transform.position = Vector3.MoveTowards(
            transform.position, targetPosition, movementSpeed * Time.deltaTime);
    }

    public void StopMoving() { /* zero velocity / stop NavMeshAgent */ }

    public void PlayAnimation(string triggerName) => animator.SetTrigger(triggerName);
}
```

## ActionTask hook (thin adapter, typed agent)

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("Commands the enemy to move toward a target position.")]
public class MoveToTargetAction : ActionTask<EnemyController>   // agent IS the EnemyController
{
    [RequiredField] public BBParameter<Vector3> targetPosition;
    public BBParameter<float> arriveDistance = 0.5f;

    protected override void OnExecute() => agent.PlayAnimation("Walk");

    protected override void OnUpdate()
    {
        agent.MoveTowards(targetPosition.value);

        if (Vector3.Distance(agent.transform.position, targetPosition.value) < arriveDistance.value)
            EndAction(true);            // every path must reach EndAction
    }

    protected override void OnStop() => agent.StopMoving();  // also runs when a transition interrupts us
}
```

## ConditionTask hook

Prefer reading a computed Body property (`agent.CanSeeTarget`) so no math lives in the Task.
A trivial comparison like the range check below is acceptable when the Body already exposes the inputs.

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("True when the target is within range of the enemy.")]
public class IsTargetInRange : ConditionTask<EnemyController>
{
    [RequiredField, BlackboardOnly] public BBParameter<Transform> target;
    public BBParameter<float> range = 10f;

    protected override bool OnCheck()
        => Vector3.Distance(agent.transform.position, target.value.position) <= range.value;
}
```

## Sensor Task (the ONLY two-way adapter — reads Body, writes Blackboard)

This is how Blackboard variables get populated from the Body without the Body knowing NodeCanvas.
Place it high in a BT (or as a parallel service) so it refreshes before the deciders read it.

```csharp
using NodeCanvas.Framework;
using ParadoxNotion.Design;
using UnityEngine;

[Category("MyGame/Enemy")]
[Description("Reads the Body's perception and publishes the current target to the Blackboard.")]
public class UpdateTargetSensor : ActionTask<EnemyPerception>
{
    [BlackboardOnly] public BBParameter<Transform> outTarget;   // out-value: Task writes, graph reads

    protected override void OnExecute()
    {
        outTarget.value = agent.CurrentTarget;   // Body stays NodeCanvas-free
        EndAction(outTarget.value != null);
    }
}
```

## C# ↔ FSM boundary (supplementary only)

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
