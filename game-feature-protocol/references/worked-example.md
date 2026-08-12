# Worked Example — "Loot Goblin" (Stealth Roguelike)

A complete application of the architecture: *a goblin sneaks through a randomly-assembled
dungeon, lockpicks chests, steals loot, and manages a tight slot-limited inventory to escape
— die and the run resets.*

Use this as a template when planning a similar project. Adapt names and modules to the
user's game.

## Module Table

| Module | Body (code) | Brain (designer) |
|---|---|---|
| Game Flow | Scene loading, run seed, save | **FSM graph** |
| Player | `PlayerController`, `NoiseEmitter`, `Interactor` | — (input driven) |
| Enemies | `EnemyLocomotion`, `EnemyPerception`, `EnemyController` | **BT per enemy type** |
| Loot & Locks | `LootContainer`, `Lock`, `LockpickMinigame` | LootTable SOs |
| Inventory | Grid model + encumbrance (pure C#) | ItemDefinition SOs |
| Dungeon | `DungeonAssembler` (seed -> pick & connect rooms) | Room layout prefabs + spawn tables |
| Presentation | `CharacterView` (wraps Spine), `ParallaxLayer` | Skeletons, animations, dressing |

Cross-system hook worth copying: **encumbrance -> noise** (heavier inventory = louder
footsteps = worse stealth). One number ties the inventory system into the stealth loop.
Look for a hook like this in any design — it is what makes systems feel connected.

## Game Flow FSM

```
[Menu]
  | press Start
[Build Run]           Actions: GenerateDungeon, LoadScene
  | dungeon ready
[Explore]             (enemy BTs tick every frame)
  |-- IsPlayerDead    --> [Results - Death]   Action: SaveMetaProgress
  |-- IsPlayerEscaped --> [Results - Escaped] Action: SaveMetaProgress
                             |
                        [Menu (new run)]
```

FSM Tasks to write:
- Conditions: `IsPlayerDead`, `IsPlayerEscaped`
- Actions: `GenerateDungeon`, `LoadScene`, `SaveMetaProgress`

## Enemy Guard BT

```
Selector
|-- Sequence (Chase - priority 1)
|   |-- IsPlayerVisible?
|   `-- ChasePlayer
|-- Sequence (Investigate - priority 2)
|   |-- DidHearNoise?
|   |-- UpdateNoiseLocation
|   |-- WalkToPoint (noise position)
|   `-- LookAround
`-- Sequence (Patrol - default)
    `-- WalkToPoint (waypoint loop)
```

BT Tasks to write:
- Conditions: `IsPlayerVisible`, `DidHearNoise`, `IsLootMissing`
- Actions: `ChasePlayer`, `WalkToPoint`, `LookAround`, `RaiseAlarm`, `UpdateNoiseLocation`

Read aloud: *"Patrol between my points. If I hear a noise, go investigate it. If I see the
goblin, chase. If I lose him, search, then go back to patrolling."* — passes the sentence test.

## Blackboard Keys

Enemy blackboard — populated only by **Sensor Tasks** (which read the Body) or **designer
bindings**, never by a Body script writing the Blackboard directly. Deciders read; sensors write.

| Key | Type | Written by |
|---|---|---|
| `LastNoisePosition` | Vector3 | `UpdateNoiseLocation` (sensor task) |
| `AlertLevel` | float | `SensePerception` (sensor task, reads `EnemyPerception`) |
| `CurrentTarget` | Transform | `UpdateTargetSensor` (sensor task, reads `EnemyPerception`) |

`IsPlayerVisible` and `DidHearNoise` don't need a Blackboard slot — they're ConditionTasks that
read a computed property off the typed Body (`agent.CanSeePlayer`, `agent.HeardNoiseThisFrame`).

Game Flow blackboard:

| Key | Type | Written by |
|---|---|---|
| `RunSeed` | int | `GenerateDungeon` (FSM action, or a designer-set default) |
| `PlayerEscaped` | bool | `SenseEscape` (sensor task, reads the exit-portal trigger on the Body) |
| `PlayerDead` | bool | `SensePlayerDead` (sensor task, reads `PlayerController.IsDead`) |

Equivalently, the FSM's `IsPlayerDead`/`IsPlayerEscaped` ConditionTasks can read the Body
directly and skip these keys — pick one style and keep it consistent.

## Save Schema

```csharp
[Serializable]
public struct MetaSave              // meta.json - permanent
{
    public int          totalRuns;
    public int          totalDeaths;
    public int          bestLootValue;
    public List<string> unlockedUpgrades;
}

[Serializable]
public struct RunSave               // run.json - deleted on death/escape
{
    public int               runSeed;        // regenerate dungeon from this
    public int               currentRoomIndex;
    public bool[]            visitedRooms;
    public PlayerSaveData    player;         // position, health, sneaking
    public InventorySaveData inventory;      // itemId + gridPos entries
    public LootSaveData      loot;           // opened chest IDs
}
```

Save/delete matrix:

| Event | Action |
|---|---|
| Player dies | `SaveMeta()` -> `DeleteRun()` |
| Player escapes | `SaveMeta()` -> `DeleteRun()` |
| Quit mid-run | `SaveRun()` |
| Start new run | `DeleteRun()` |
| Boot game | `LoadMeta()` + check `LoadRun()` for a Continue option |

`SaveMetaProgress` is itself an FSM ActionTask — the graph triggers it in the Results
state, and the task calls SaveManager (thin wrapper rule applies here too).

## Phased Plan (12 weeks, one programmer + one designer)

| Phase | Weeks | Programmer | Designer |
|---|---|---|---|
| 0 Foundation | 1 | Folders, `ISaveable`, `SaveManager` | — |
| 1 Player Body | 2 | Controller, NoiseEmitter, Interactor | — |
| 2 Inventory | 3 | Grid model, encumbrance -> noise | First ItemDefinition SOs |
| 3 First Enemy | 4-5 | Perception, Locomotion, all Tasks, **test scene** | **Starts in parallel: first Guard BT** |
| 4 Loot & Locks | 6 | Containers, Lock, minigame, `IsLootMissing` | LootTable SOs |
| 5 Dungeon | 7-8 | Assembler, connectors | Room prefabs, spawn tables |
| 6 Game Flow | 9 | FSM Tasks, save integration, Continue flow | GameFlow FSM graph |
| 7 Presentation | 10-12 | Spine wrapper, parallax, audio | Skeletons, animation, dressing |

The Phase 3 test scene (one room, one guard, player stub) is what unlocks parallel work —
prioritize it over completeness.
