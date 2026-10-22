# Infinite Stamina (UE4SS)

The player never runs out of stamina. Enemies keep their normal stamina.

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod for The Blood of Dawnwalker (Unreal Engine 5.5), made with
game version `dw1-pc-258504-shipping-patch2-all-CL-258504` (patch 2) and UE4SS `v3.0.1-1181-g83330635`
(experimental-latest of 2026-10-17, with the UE4SS team's `TheBloodOfDawnwalker` config). This README is for
developers; what the mod does and how to install it are in [openmods.md](openmods.md), the mod page on
[openmods](https://openmods.nexus). The same mod without UE4SS, as a replaced game asset, is
[dawnwalker_infinitestamina](https://github.com/KintaroModding/dawnwalker_infinitestamina).

## How it works

The game has a gameplay tag, `Effect.InfiniteStamina`; while a character has it, stamina is not used up (the game
itself gives it to the player for a few seconds during the Shadowstorm spell). `Scripts/main.lua` adds this tag to
the player as a loose tag (`AbilitySystemBlueprintLibrary.AddLooseGameplayTags`). A timer checks every two seconds that
the player still has it - after a new game, a save load, a death or a change of form - and adds it again when it is
missing. It only looks at the player character (`DawnwalkerPlayerCharacter`), so enemies are not changed.

## Deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

`deploy.ps1` copies `src\dawnwalker_infinitestamina_ue4ss\` to
`<game folder>\Dawnwalker\Binaries\Win64\ue4ss\Mods\dawnwalker_infinitestamina_ue4ss\`. The game folder is
`$env:UE5_GAMES_DIR\The Blood of Dawnwalker`; `-GameDir` or `-ModsDir` override it. The mod folder holds
`enabled.txt`, so UE4SS starts it without an entry in `mods.txt`. The mod writes its lines into `ue4ss\UE4SS.log`,
for example `[Infinite Stamina (UE4SS)] 1.0 loaded.`

## Project layout

```
src/dawnwalker_infinitestamina_ue4ss/   The UE4SS mod folder: Scripts/main.lua, enabled.txt
docs/                                   Cover and screenshots
deploy.ps1                              Copies the mod folder into the game's ue4ss\Mods
mod.json                                Name, version, game, engine and UE4SS version
```

## License

MIT, see [LICENSE](LICENSE).
