# Ball Brawl

A local two-player auto-battler for iPhone/iPad (SwiftUI + Canvas, custom fixed-timestep 2D physics).

## Run
1. Open `Untitled Project.xcodeproj` in Xcode.
2. Pick the **MyApp** scheme and an iPhone simulator or your device.
3. Press **⌘R**.

## Play
- Each player taps one of 23 fighters (see `MyApp/Config/FighterCatalog.swift` and `ArsenalCatalog.swift`). Both players can pick the same one.
- Blaster only: drag in the mini-arena to aim, then tap **Confirm Aim**. Other fighters: **Lock In**.
- **Start Battle** unlocks once both players are ready. After a 3-second countdown, the fight runs on its own.
- Use **Pause** or **Restart** during the battle. After the match: **Rematch** (same fighters and aim, new launch angles) or **Change Fighters**.

## VS Bot mode
- From the menu choose **VS Bot**, then pick 3 different fighters. The bot picks 3 at random.
- Each round is a normal 1v1 battle and health carries over between rounds.
- The survivor's owner may **keep** it or **swap** in another living teammate; the side that lost the round must send a remaining fighter. A double K.O. eliminates both.
- The first side to run out of fighters loses the series (both at once = draw).
- Series rules and the bot's choices live in `MyApp/Battle/BotSeries.swift`.

## Balance & tuning
- `MyApp/Config/FighterCatalog.swift`: per-fighter HP, radius, mass, damage, cooldowns, range, projectile speed, knockback.
- `MyApp/Config/GameConfig.swift`: arena size, physics (launch/min/max speed, restitution, damping), countdown, overtime (start time, ramp, cap).

## Code layout
| Folder | Responsibility |
|---|---|
| `Config/` | Fighter definitions + all tunable values |
| `Physics/` | Vector math, circle physics world (substepped, elastic, speed limits) |
| `Battle/` | Match state, `AttackSystem` (attack logic), `BattleSimulation` (rules, damage, KO/draw), cosmetic effects |
| `Rendering/` | Procedural drawing of fighters, arena, HUD |
| `UI/` | App flow model, setup screen, battle screen, game-loop engine |

To add a fighter, append a `FighterDefinition` to `FighterCatalog.all`. A brand-new attack type needs a new `AttackSpec` case, handled in `AttackSystem` and `FighterArt`.
