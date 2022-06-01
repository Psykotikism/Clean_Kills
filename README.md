# Clean Kills

## PayPal
[Donate to Motivate](https://paypal.me/Psyk0tikism?locale.x=en_US)

## License
> The following license is placed inside the source code of the plugin.

Clean Kills: a L4D/L4D2 SourceMod Plugin
Copyright (C) 2022  Alfred "Psyk0tik" Llagas

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

## About
Kill swiftly, efficiently, and professionally.

## Credits
**epz/epzminion** - For helping with gamedata information, giving the original idea, and overall invaluable input.

**Lux/LuxLuma** - For suggesting an idea about hit groups.

**SourceMod Team** - For continually updating/improving `SourceMod`.

## Requirements
1. `SourceMod 1.11.0.6724` or higher
2. [`DHooks 2.2.0-detours15` or higher](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)
3. [`Source Scramble`](https://github.com/nosoop/SMExt-SourceScramble)
4. [`Left 4 DHooks`](https://forums.alliedmods.net/showthread.php?t=321696)
5. Knowledge of installing SourceMod plugins.

## Notes
1. I do not provide support for listen/local servers but the plugin should still work properly on them.
2. I will not help you with installing or troubleshooting problems on your part.
3. If you get errors from SourceMod itself, that is your problem, not mine.
4. MAKE SURE YOU MEET ALL THE REQUIREMENTS AND FOLLOW THE INSTALLATION GUIDE PROPERLY.

## Features
1. Kill Boomers without triggering explosions or vomit feedback.
2. Kill Smokers without triggering smoke clouds or coughing.
3. Kill Spitters without triggering acid puddles.

## Commands
```
// Accessible by admins with "z" (Root) flag only.
sm_clean - Set a player's clean kills type(s) and hit group(s).

L4D1:
- Usage: sm_clean <-1: OFF|0: Use Cvar|1: Boomers|2: Smokers|3: ALL> <1-127: Hit groups>
- Usage: sm_clean <#userid|name> <-1: OFF|0: Use Cvar|1: Boomers|2: Smokers|3: ALL> <1-127: Hit groups>

L4D2:
- Usage: sm_clean <-1: OFF|0: Use Cvar|1: Boomers|2: Smokers|4: Spitters|7: ALL> <1-127: Hit groups>
- Usage: sm_clean <#userid|name> <-1: OFF|0: Use Cvar|1: Boomers|2: Smokers|4: Spitters|7: ALL> <1-127: Hit groups>
```

## ConVar Settings
```
// Disable Clean Kills in these game modes.
// Separate by commas.
// Empty: None
// Not empty: Disabled only in these game modes.
// -
// Default: ""
l4d_clean_kills_disabled_gamemodes ""

// Enable Clean Kills.
// 0: OFF
// 1: ON
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
l4d_clean_kills_enabled "1"

// Enable Clean Kills in these game modes.
// Separate by commas.
// Empty: All
// Not empty: Enabled only in these game modes.
// -
// Default: ""
l4d_clean_kills_enabled_gamemodes ""

// Enable Clean Kills in these game mode types.
// 0 OR 15: All game mode types.
// 1: Co-Op modes only.
// 2: Versus modes only.
// 4: Survival modes only.
// 8: Scavenge modes only. (Only available in Left 4 Dead 2.)
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "15.000000"
l4d_clean_kills_gamemode_types "0"

// Hit group(s) that trigger clean kills.
// 1: Headshots only
// 2: Chest shots only
// 4: Stomach shots only
// 8: Left arm shots only
// 16: Right arm shots only
// 32: Left leg shots only
// 64: Right leg shots only
// 127: ALL
// -
// Default: "127"
// Minimum: "1.000000"
// Maximum: "127.000000"
l4d_clean_kills_hit_groups "127"

// Type(s) of clean kills allowed.
// 0: NONE
// 1: Boomers only
// 2: Smokers only
// 4: Spitters only (Only available in Left 4 Dead 2.)
// 7: ALL
// -
// Default: "7"
// Minimum: "0.000000"
// Maximum: "7.000000"
l4d_clean_kills_kill_types "7"
```

## Installation
1. Delete files from old versions of the plugin.
2. Place `l4d_clean_kills.txt` in the `addons/sourcemod/gamedata` folder.
3. Place `l4d_clean_kills.smx` in the `addons/sourcemod/plugins` folder.
4. Place `l4d_clean_kills.sp` in the `addons/sourcemod/scripting` folder.

## Uninstalling/Upgrading to Newer Versions
1. Delete `l4d_clean_kills.sp` from the `addons/sourcemod/scripting` folder.
2. Delete `l4d_clean_kills.smx` from the `addons/sourcemod/plugins` folder.
3. Delete `l4d_clean_kills.txt` from the `addons/sourcemod/gamedata` folder.
4. Follow the Installation guide above. (Only for upgrading to newer versions.)

## Disabling
1. Move `l4d_clean_kills.smx` to the `plugins/disabled` folder.
2. Unload `Clean Kills` by typing `sm plugins unload l4d_clean_kills` in the server console.

## Third-Party Revisions Notice
If you would like to share your own revisions of this plugin, please rename the files so that there is no confusion for users.

## Final Words
Enjoy all my hard work and have fun with it!