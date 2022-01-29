/**
 * Clean Kills: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2022  Alfred "Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#include <sourcemod>
#include <dhooks>
#include <sourcescramble>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define CK_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D & L4D2] Clean Kills",
	author = "Psyk0tik",
	description = "Kill swiftly, efficiently, and professionally.",
	version = CK_VERSION,
	url = "https://github.com/Psykotikism/Clean_Kills"
};

bool g_bDedicated, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"Clean Kills\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}

// Client check flags
#define CK_CHECK_INDEX (1 << 0) // check 0 < client <= MaxClients
#define CK_CHECK_CONNECTED (1 << 1) // check IsClientConnected(client)
#define CK_CHECK_INGAME (1 << 2) // check IsClientInGame(client)
#define CK_CHECK_ALIVE (1 << 3) // check IsPlayerAlive(client)
#define CK_CHECK_INKICKQUEUE (1 << 4) // check IsClientInKickQueue(client)
#define CK_CHECK_FAKECLIENT (1 << 5) // check IsFakeClient(client)

// Chat tags
#define CK_TAG "[CK]"
#define CK_TAG2 "\x04[CK]\x01"
#define CK_TAG3 "\x04[CK]\x03"
#define CK_TAG4 "\x04[CK]\x04"
#define CK_TAG5 "\x04[CK]\x05"

// Clean kill types
#define CK_TYPE_BOOMER (1 << 0) // Boomer
#define CK_TYPE_SMOKER (1 << 1) // Smoker
#define CK_TYPE_SPITTER (1 << 2) // Spitter

enum struct esGeneral
{
	bool g_bMapStarted;
	bool g_bPluginEnabled;

	ConVar g_cvCKDisabledGameModes;
	ConVar g_cvCKEnabledGameModes;
	ConVar g_cvCKGameMode;
	ConVar g_cvCKGameModeTypes;
	ConVar g_cvCKKillTypes;
	ConVar g_cvCKPluginEnabled;

	DynamicDetour g_ddEventKilledDetour;

	int g_iAttackerOffset;
	int g_iCurrentMode;

	MemoryPatch g_mpBoomerKill[6];
	MemoryPatch g_mpSmokerKill[4];
	MemoryPatch g_mpSpitterKill;
}

esGeneral g_esGeneral;

int g_iCleanKillTypes[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_clean", cmdCKCleanKills, ADMFLAG_ROOT, "Set a player's clean kills type(s).");

	g_esGeneral.g_cvCKDisabledGameModes = CreateConVar("l4d_clean_kills_disabled_gamemodes", "", "Disable Clean Kills in these game modes.\nSeparate by commas.\nEmpty: None\nNot empty: Disabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvCKEnabledGameModes = CreateConVar("l4d_clean_kills_enabled_gamemodes", "", "Enable Clean Kills in these game modes.\nSeparate by commas.\nEmpty: All\nNot empty: Enabled only in these game modes.", FCVAR_NOTIFY);
	g_esGeneral.g_cvCKGameModeTypes = CreateConVar("l4d_clean_kills_gamemode_types", "0", "Enable Clean Kills in these game mode types.\n0 OR 15: All game mode types.\n1: Co-Op modes only.\n2: Versus modes only.\n4: Survival modes only.\n8: Scavenge modes only. (Only available in Left 4 Dead 2.)", FCVAR_NOTIFY, true, 0.0, true, 15.0);
	g_esGeneral.g_cvCKKillTypes = CreateConVar("l4d_clean_kills_kill_types", (g_bSecondGame ? "7" : "3"), "Type(s) of clean kills allowed.\n0: NONE\n1: Boomers only\n2: Smokers only\n4: Spitters only (Only available in Left 4 Dead 2.)\n7: ALL", _, true, 0.0, true, 7.0);
	g_esGeneral.g_cvCKPluginEnabled = CreateConVar("l4d_clean_kills_enabled", "1", "Enable Clean Kills.\n0: OFF\n1: ON", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CreateConVar("l4d_clean_kills_version", CK_VERSION, "Clean Kills Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_SPONLY);
	AutoExecConfig(true, "l4d_clean_kills");

	g_esGeneral.g_cvCKGameMode = FindConVar("mp_gamemode");

	g_esGeneral.g_cvCKDisabledGameModes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvCKEnabledGameModes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvCKGameMode.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvCKGameModeTypes.AddChangeHook(vPluginStatusCvar);
	g_esGeneral.g_cvCKPluginEnabled.AddChangeHook(vPluginStatusCvar);

	GameData gdCleanKills = new GameData("l4d_clean_kills");

	switch (gdCleanKills == null)
	{
		case true: SetFailState("Unable to load the \"l4d_clean_kills\" gamedata file.");
		case false:
		{
			g_esGeneral.g_iAttackerOffset = gdCleanKills.GetOffset("CTerrorPlayer::Event_Killed::Attacker");
			if (g_esGeneral.g_iAttackerOffset == -1)
			{
				LogError("%s Failed to load offset: CTerrorPlayer::Event_Killed::Attacker", CK_TAG);
			}

			vSetupDetour(g_esGeneral.g_ddEventKilledDetour, gdCleanKills, "CKDetour_CTerrorPlayer::Event_Killed");

			vSetupPatch(g_esGeneral.g_mpBoomerKill[0], gdCleanKills, "CKPatch_Boomer1CleanKill");
			vSetupPatch(g_esGeneral.g_mpBoomerKill[1], gdCleanKills, "CKPatch_Boomer2CleanKill");
			vSetupPatch(g_esGeneral.g_mpBoomerKill[2], gdCleanKills, "CKPatch_Boomer3CleanKill");

			vSetupPatch(g_esGeneral.g_mpSmokerKill[0], gdCleanKills, "CKPatch_Smoker1CleanKill");
			vSetupPatch(g_esGeneral.g_mpSmokerKill[1], gdCleanKills, "CKPatch_Smoker2CleanKill");
			vSetupPatch(g_esGeneral.g_mpSmokerKill[2], gdCleanKills, "CKPatch_Smoker3CleanKill");
			vSetupPatch(g_esGeneral.g_mpSmokerKill[3], gdCleanKills, "CKPatch_Smoker4CleanKill");

			if (g_bSecondGame)
			{
				vSetupPatch(g_esGeneral.g_mpBoomerKill[3], gdCleanKills, "CKPatch_Boomer4CleanKill");
				vSetupPatch(g_esGeneral.g_mpBoomerKill[4], gdCleanKills, "CKPatch_Boomer5CleanKill");
				vSetupPatch(g_esGeneral.g_mpBoomerKill[5], gdCleanKills, "CKPatch_Boomer6CleanKill");

				vSetupPatch(g_esGeneral.g_mpSpitterKill, gdCleanKills, "CKPatch_SpitterCleanKill");
			}

			delete gdCleanKills;
		}
	}
}

public void OnMapStart()
{
	g_esGeneral.g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_esGeneral.g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	vPluginStatus();
}

Action cmdCKCleanKills(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);
	if (!bIsValidClient(client, CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_FAKECLIENT))
	{
		ReplyToCommand(client, "%s You must be in-game to use this command", CK_TAG);

		return Plugin_Handled;
	}

	if (!g_esGeneral.g_bPluginEnabled)
	{
		ReplyToCommand(client, "%s You cannot use this command right now.", CK_TAG2);

		return Plugin_Handled;
	}

	switch (args)
	{
		case 1:
		{
			int iLimit = g_bSecondGame ? 7 : 3;
			g_iCleanKillTypes[client] = iClamp(GetCmdArgInt(1), -1, iLimit);

			char sList[64];
			vGetInfectedTypeList(g_iCleanKillTypes[client], sList, sizeof sList);
			ReplyToCommand(client, "%s You now have\x05 clean kills\x01 on\x03 %s\x01.", CK_TAG2, sList);
		}
		case 2:
		{
			bool tn_is_ml;
			char target[32], target_name[32];
			int target_list[MAXPLAYERS], target_count;
			GetCmdArg(1, target, sizeof target);
			if ((target_count = ProcessTargetString(target, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_IMMUNITY, target_name, sizeof target_name, tn_is_ml)) <= 0)
			{
				ReplyToTargetError(client, target_count);

				return Plugin_Handled;
			}

			int iLimit = g_bSecondGame ? 7 : 3, iTypes = iClamp(GetCmdArgInt(2), -1, iLimit);
			char sList[64];
			vGetInfectedTypeList(iTypes, sList, sizeof sList);
			for (int iPlayer = 0; iPlayer < target_count; iPlayer++)
			{
				if (bIsValidClient(target_list[iPlayer]))
				{
					g_iCleanKillTypes[target_list[iPlayer]] = iTypes;

					ReplyToCommand(client, "%s You allowed\x05 %N\x01 to get clean kills on\x03 %s\x01.", CK_TAG2, target_list[iPlayer], sList);
					PrintToChat(target_list[iPlayer], "%s You now have\x05 clean kills\x01 on\x03 %s\x01.", CK_TAG2, sList);
				}
			}
		}
		default:
		{
			char sCmd[32];
			GetCmdArg(0, sCmd, sizeof sCmd);
			ReplyToCommand(client, "%s Usage: %s <-1: OFF|0: Use Cvar|1: Boomers|2: Smokers|%s>", CK_TAG2, sCmd, (g_bSecondGame ? "4: Spitters|7: ALL" : "3: ALL"));
		}
	}

	return Plugin_Handled;
}

MRESReturn mreEventKilledPre(int pThis, DHookParam hParams)
{
	int iAttacker = hParams.GetObjectVar(1, g_esGeneral.g_iAttackerOffset, ObjectValueType_Ehandle);
	if (bIsInfected(pThis, CK_CHECK_INDEX|CK_CHECK_INGAME) && bIsSurvivor(iAttacker))
	{
		int iTypes = (g_iCleanKillTypes[iAttacker] != 0) ? g_iCleanKillTypes[iAttacker] : g_esGeneral.g_cvCKKillTypes.IntValue;
		if (iTypes > 0)
		{
			if (bIsBoomer(pThis, CK_CHECK_INDEX|CK_CHECK_INGAME) && (iTypes & CK_TYPE_BOOMER))
			{
				g_esGeneral.g_mpBoomerKill[0].Enable();
				g_esGeneral.g_mpBoomerKill[1].Enable();
				g_esGeneral.g_mpBoomerKill[2].Enable();

				if (g_bSecondGame)
				{
					g_esGeneral.g_mpBoomerKill[3].Enable();
					g_esGeneral.g_mpBoomerKill[4].Enable();
					g_esGeneral.g_mpBoomerKill[5].Enable();
				}
			}
			else if (bIsSmoker(pThis, CK_CHECK_INDEX|CK_CHECK_INGAME) && (iTypes & CK_TYPE_SMOKER))
			{
				g_esGeneral.g_mpSmokerKill[0].Enable();
				g_esGeneral.g_mpSmokerKill[1].Enable();
				g_esGeneral.g_mpSmokerKill[2].Enable();
				g_esGeneral.g_mpSmokerKill[3].Enable();
			}
			else if (g_bSecondGame && bIsSpitter(pThis, CK_CHECK_INDEX|CK_CHECK_INGAME) && (iTypes & CK_TYPE_SPITTER))
			{
				g_esGeneral.g_mpSpitterKill.Enable();
			}
		}
	}

	return MRES_Ignored;
}

MRESReturn mreEventKilledPost(int pThis, DHookParam hParams)
{
	g_esGeneral.g_mpBoomerKill[0].Disable();
	g_esGeneral.g_mpBoomerKill[1].Disable();
	g_esGeneral.g_mpBoomerKill[2].Disable();

	g_esGeneral.g_mpSmokerKill[0].Disable();
	g_esGeneral.g_mpSmokerKill[1].Disable();
	g_esGeneral.g_mpSmokerKill[2].Disable();
	g_esGeneral.g_mpSmokerKill[3].Disable();

	if (g_bSecondGame)
	{
		g_esGeneral.g_mpBoomerKill[3].Disable();
		g_esGeneral.g_mpBoomerKill[4].Disable();
		g_esGeneral.g_mpBoomerKill[5].Disable();

		g_esGeneral.g_mpSpitterKill.Disable();
	}

	return MRES_Ignored;
}

public void L4D_OnGameModeChange(int gamemode)
{
	int iMode = g_esGeneral.g_cvCKGameModeTypes.IntValue;
	if (iMode != 0)
	{
		g_esGeneral.g_bPluginEnabled = (gamemode != 0 && (iMode & gamemode));
		g_esGeneral.g_iCurrentMode = gamemode;
	}
}

void vEventHandler(Event event, const char[] name, bool dontBroadcast)
{
	if (g_esGeneral.g_bPluginEnabled)
	{
		if (StrEqual(name, "bot_player_replace"))
		{
			int iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId),
				iPlayerId = event.GetInt("player"), iPlayer = GetClientOfUserId(iPlayerId);
			if (bIsValidClient(iBot) && bIsSurvivor(iPlayer))
			{
				g_iCleanKillTypes[iPlayer] = g_iCleanKillTypes[iBot];
				g_iCleanKillTypes[iBot] = 0;
			}
		}
		else if (StrEqual(name, "player_bot_replace"))
		{
			int iPlayerId = event.GetInt("player"), iPlayer = GetClientOfUserId(iPlayerId),
				iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
			if (bIsValidClient(iPlayer) && bIsSurvivor(iBot))
			{
				g_iCleanKillTypes[iBot] = g_iCleanKillTypes[iPlayer];
				g_iCleanKillTypes[iPlayer] = 0;
			}
		}
		else if (StrEqual(name, "player_connect") || StrEqual(name, "player_disconnect"))
		{
			int iSurvivorId = event.GetInt("userid"), iSurvivor = GetClientOfUserId(iSurvivorId);
			g_iCleanKillTypes[iSurvivor] = 0;
		}
	}
}

void vGetInfectedTypeList(int types, char[] buffer, int size)
{
	if (types == -1)
	{
		FormatEx(buffer, size, "nothing");

		return;
	}
	else if (types == 0)
	{
		types = g_esGeneral.g_cvCKKillTypes.IntValue;
	}

	bool bListed = false;
	if (types & CK_TYPE_BOOMER)
	{
		bListed = true;

		FormatEx(buffer, size, "Boomers");
	}

	if (types & CK_TYPE_SMOKER)
	{
		switch (bListed)
		{
			case true: Format(buffer, size, "%s\x01,\x03 Smokers", buffer);
			case false:
			{
				bListed = true;

				FormatEx(buffer, size, "Smokers");
			}
		}
	}

	if (g_bSecondGame && (types & CK_TYPE_SPITTER))
	{
		switch (bListed)
		{
			case true: Format(buffer, size, "%s\x01,\x03 Spitters", buffer);
			case false: FormatEx(buffer, size, "Spitters");
		}
	}
}

void vHookEvents(bool hook)
{
	static bool bHooked, bCheck[4];
	if (hook && !bHooked)
	{
		bHooked = true;

		bCheck[0] = HookEventEx("bot_player_replace", vEventHandler);
		bCheck[1] = HookEventEx("player_bot_replace", vEventHandler);
		bCheck[2] = HookEventEx("player_connect", vEventHandler, EventHookMode_Pre);
		bCheck[3] = HookEventEx("player_disconnect", vEventHandler, EventHookMode_Pre);
	}
	else if (!hook && bHooked)
	{
		bHooked = false;
		bool bPreHook[4];
		char sEvent[32];

		for (int iPos = 0; iPos < (sizeof bCheck); iPos++)
		{
			switch (iPos)
			{
				case 0: sEvent = "bot_player_replace";
				case 1: sEvent = "player_bot_replace";
				case 2: sEvent = "player_connect";
				case 3: sEvent = "player_disconnect";
			}

			if (bCheck[iPos])
			{
				bPreHook[iPos] = (2 <= iPos <= 3);
				UnhookEvent(sEvent, vEventHandler, (bPreHook[iPos] ? EventHookMode_Pre : EventHookMode_Post));
			}
		}
	}
}

void vPluginStatusCvar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vPluginStatus();
}

void vPluginStatus()
{
	bool bPluginAllowed = bIsPluginEnabled();
	if (!g_esGeneral.g_bPluginEnabled && bPluginAllowed)
	{
		vTogglePlugin(bPluginAllowed);
	}
	else if (g_esGeneral.g_bPluginEnabled && !bPluginAllowed)
	{
		vTogglePlugin(bPluginAllowed);
	}
}

void vSetupDetour(DynamicDetour &detourHandle, GameData dataHandle, const char[] name)
{
	detourHandle = DynamicDetour.FromConf(dataHandle, name);
	if (detourHandle == null)
	{
		LogError("%s Failed to detour: %s", CK_TAG, name);
	}
}

void vSetupPatch(MemoryPatch &patchHandle, GameData dataHandle, const char[] name)
{
	patchHandle = MemoryPatch.CreateFromConf(dataHandle, name);
	if (!patchHandle.Validate())
	{
		LogError("%s Failed to patch: %s", CK_TAG, name);
	}
}

void vToggleDetour(DynamicDetour &detourHandle, const char[] name, HookMode mode, DHookCallback callback, bool toggle)
{
	if (detourHandle == null)
	{
		return;
	}

	bool bToggle = toggle ? detourHandle.Enable(mode, callback) : detourHandle.Disable(mode, callback);
	if (!bToggle)
	{
		LogError("%s Failed to %s the %s-hook detour for the \"%s\" function.", CK_TAG, (toggle ? "enable" : "disable"), ((mode == Hook_Pre) ? "pre" : "post"), name);
	}
}

void vToggleDetours(bool toggle)
{
	vToggleDetour(g_esGeneral.g_ddEventKilledDetour, "CKDetour_CTerrorPlayer::Event_Killed", Hook_Pre, mreEventKilledPre, toggle);
	vToggleDetour(g_esGeneral.g_ddEventKilledDetour, "CKDetour_CTerrorPlayer::Event_Killed", Hook_Post, mreEventKilledPost, toggle);
}

void vTogglePlugin(bool toggle)
{
	g_esGeneral.g_bPluginEnabled = toggle;

	vHookEvents(toggle);
	vToggleDetours(toggle);
}

bool bIsBoomer(int boomer, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_ALIVE)
{
	return bIsInfected(boomer, flags) && GetEntProp(boomer, Prop_Send, "m_zombieClass") == 2;
}

bool bIsInfected(int infected, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_ALIVE)
{
	return bIsValidClient(infected, flags) && GetClientTeam(infected) == 3;
}

bool bIsPluginEnabled()
{
	if (!g_esGeneral.g_cvCKPluginEnabled.BoolValue || g_esGeneral.g_cvCKGameMode == null)
	{
		return false;
	}

	int iMode = g_esGeneral.g_cvCKGameModeTypes.IntValue;
	if (iMode != 0)
	{
		if (!g_esGeneral.g_bMapStarted)
		{
			return false;
		}

		g_esGeneral.g_iCurrentMode = L4D_GetGameModeType();

		if (g_esGeneral.g_iCurrentMode == 0 || !(iMode & g_esGeneral.g_iCurrentMode))
		{
			return false;
		}
	}

	char sFixed[32], sGameMode[32], sGameModes[513], sList[513];
	g_esGeneral.g_cvCKGameMode.GetString(sGameMode, sizeof sGameMode);
	FormatEx(sFixed, sizeof sFixed, ",%s,", sGameMode);

	g_esGeneral.g_cvCKEnabledGameModes.GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0] != '\0')
	{
		if (sGameModes[0] != '\0')
		{
			FormatEx(sList, sizeof sList, ",%s,", sGameModes);
		}

		if (sList[0] != '\0' && StrContains(sList, sFixed, false) == -1)
		{
			return false;
		}
	}

	g_esGeneral.g_cvCKDisabledGameModes.GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0] != '\0')
	{
		if (sGameModes[0] != '\0')
		{
			FormatEx(sList, sizeof sList, ",%s,", sGameModes);
		}

		if (sList[0] != '\0' && StrContains(sList, sFixed, false) != -1)
		{
			return false;
		}
	}

	return true;
}

bool bIsSmoker(int smoker, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_ALIVE)
{
	return bIsInfected(smoker, flags) && GetEntProp(smoker, Prop_Send, "m_zombieClass") == 1;
}

bool bIsSpitter(int spitter, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_ALIVE)
{
	return bIsInfected(spitter, flags) && g_bSecondGame && GetEntProp(spitter, Prop_Send, "m_zombieClass") == 4;
}

bool bIsSurvivor(int survivor, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME|CK_CHECK_ALIVE)
{
	return bIsValidClient(survivor, flags) && GetClientTeam(survivor) == 2;
}

bool bIsValidClient(int player, int flags = CK_CHECK_INDEX|CK_CHECK_INGAME)
{
	if (((flags & CK_CHECK_INDEX) && (player <= 0 || player > MaxClients)) || ((flags & CK_CHECK_CONNECTED) && !IsClientConnected(player))
		|| ((flags & CK_CHECK_INGAME) && !IsClientInGame(player)) || ((flags & CK_CHECK_ALIVE) && !IsPlayerAlive(player))
		|| ((flags & CK_CHECK_INKICKQUEUE) && IsClientInKickQueue(player)) || ((flags & CK_CHECK_FAKECLIENT) && IsFakeClient(player)))
	{
		return false;
	}

	return true;
}

bool bIsValidEntity(int entity, bool override = false, int start = 0)
{
	int iIndex = override ? start : MaxClients;
	return entity > iIndex && IsValidEntity(entity);
}

int iClamp(int value, int min, int max)
{
	if (value < min)
	{
		return min;
	}
	else if (value > max)
	{
		return max;
	}

	return value;
}

int iGetListenServerHost(int client, bool dedicated)
{
	if (client == 0 && !dedicated)
	{
		int iManager = FindEntityByClassname(-1, "terror_player_manager");
		if (bIsValidEntity(iManager))
		{
			int iHostOffset = FindSendPropInfo("CTerrorPlayerResource", "m_listenServerHost");
			if (iHostOffset != -1)
			{
				bool bHost[MAXPLAYERS + 1];
				GetEntDataArray(iManager, iHostOffset, bHost, (MAXPLAYERS + 1), 1);
				for (int iPlayer = 1; iPlayer < sizeof bHost; iPlayer++)
				{
					if (bHost[iPlayer])
					{
						return iPlayer;
					}
				}
			}
		}
	}

	return client;
}