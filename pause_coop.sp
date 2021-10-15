/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <sdktools>
#undef REQUIRE_PLUGIN
//#include <readyup>

public Plugin myinfo =
{
	name = "Pause plugin (for coop without readyup)",
	author = "CanadaRox, 海洋空氣",
	description = "Adds pause functionality without breaking pauses",
	version = "9",
	url = ""
};

char teamString[][] =
{
	"None",
	"Spectator",
	"Survivors",
	"Infected"
};

Handle menuPanel;
Handle readyCountdownTimer;
Handle sv_pausable;
Handle sv_noclipduringpause;
bool isPaused;
// bool teamReady[L4D2Team];
bool playerReady[MAXPLAYERS + 1] = true;
int readyDelay;
Handle pauseDelayCvar;
int pauseDelay;
bool readyUpIsAvailable;
Handle pauseForward;
Handle unpauseForward;
Handle deferredPauseTimer;
Handle l4d_ready_delay;
Handle l4d_ready_blips;
bool playerCantPause[MAXPLAYERS+1];
Handle playerCantPauseTimers[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] name, int err_max)
{
	CreateNative("IsInPause", Native_IsInPause);
	pauseForward = CreateGlobalForward("OnPause", ET_Event);
	unpauseForward = CreateGlobalForward("OnUnpause", ET_Event);
	RegPluginLibrary("pause");

	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_pause", Pause_Cmd, "Pauses the game");
	RegConsoleCmd("sm_p", Pause_Cmd, "Pauses the game");
	RegConsoleCmd("sm_unpause", Unpause_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_ready", Unpause_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_r", Unpause_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_unready", Unready_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_ur", Unready_Cmd, "Marks your team as ready for an unpause");
	RegConsoleCmd("sm_toggleready", ToggleReady_Cmd, "Toggles your team's ready status");

	RegAdminCmd("sm_fs", ForceUnpause_Cmd, ADMFLAG_BAN, "Unpauses the game regardless of team ready status.  Must be used to unpause admin pauses");
	RegAdminCmd("sm_forcestart", ForceUnpause_Cmd, ADMFLAG_BAN, "Unpauses the game regardless of team ready status.  Must be used to unpause admin pauses");

	AddCommandListener(Say_Callback, "say");
	AddCommandListener(TeamSay_Callback, "say_team");
	AddCommandListener(Unpause_Callback, "unpause");

	sv_pausable = FindConVar("sv_pausable");
	sv_noclipduringpause = FindConVar("sv_noclipduringpause");

	pauseDelayCvar = CreateConVar("sm_pausedelay", "0", "Delay to apply before a pause happens.  Could be used to prevent Tactical Pauses", _, true, 0.0);
	l4d_ready_delay = CreateConVar("l4d_ready_delay", "5", "Number of seconds to count down before the round goes live.", _, true, 0.0);
	l4d_ready_blips = CreateConVar("l4d_ready_blips", "1", "Enable beep on unpause");

	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event);
}
// 没有readyup插件
/*
public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}
*/
public int Native_IsInPause(Handle plugin, int numParams)
{
	return view_as<int>(isPaused);
}

public void OnClientPutInServer(int client)
{
	if (isPaused)
	{
		if (!IsFakeClient(client))
		{
			CPrintToChatAll("{green}[SM] {blue}\x03%N {default}已经完全加载了. 使用 {olive}/r {default}解除暂停.", client);
			ChangeClientTeam(client, 1);
		}
	}
}

public void OnMapStart()
{
	PrecacheSound("buttons/blip2.wav");
}

public void RoundEnd_Event(Handle event, char[] name, bool dontBroadcast)
{
	if (deferredPauseTimer != INVALID_HANDLE)
	{
		CloseHandle(deferredPauseTimer);
		deferredPauseTimer = INVALID_HANDLE;
	}
}

public void PlayerTeam_Event(Handle event, char[] name, bool dontBroadcast)
{
	if (GetEventInt(event, "team") == 3)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		playerCantPause[client] = true;
		if (playerCantPauseTimers[client] != INVALID_HANDLE)
		{
			KillTimer(playerCantPauseTimers[client]);
			playerCantPauseTimers[client] = INVALID_HANDLE;
		}
		playerCantPauseTimers[client] = CreateTimer(2.0, AllowPlayerPause_Timer, client);
	}
}

public Action AllowPlayerPause_Timer(Handle timer, int client)
{
	playerCantPause[client] = false;
	playerCantPauseTimers[client] = INVALID_HANDLE;
}

public Action Pause_Cmd(int client, int args)
{
	if (!readyUpIsAvailable && pauseDelay == 0 && !isPaused && IsPlayer(client) && !playerCantPause[client])
	{
		CPrintToChatAll("{green}[SM] {blue}%N {default}打了一手暂停, {olive}/r {default}准备, {olive}/ur {default}取消准备.", client);
		pauseDelay = GetConVarInt(pauseDelayCvar);
		if (pauseDelay == 0)
			AttemptPause();
		else
			CreateTimer(1.0, PauseDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Handled;
}

public Action PauseDelay_Timer(Handle timer)
{
	if (pauseDelay == 0)
	{
		CPrintToChatAll("{red}已暂停!");
		AttemptPause();
		return Plugin_Stop;
	}
	else
	{
		CPrintToChatAll("{red}Game pausing in: %d", pauseDelay);
		pauseDelay--;
	}
	return Plugin_Continue;
}

public Action Unpause_Cmd(int client, int args)
{
	if (isPaused && IsPlayer(client) && !playerCantPause[client])
	{
		int clientTeam = GetClientTeam(client);
		if (!playerReady[client] && clientTeam == 2)
		{
			CPrintToChatAll("{green}[SM] {blue}%N {default}is {olive}ready{default}.", client);
		}
		playerReady[client] = true;
		if (CheckFullReady())
		{
			InitiateLiveCountdown();
		}
	}
	return Plugin_Handled;
}

public Action Unready_Cmd(int client, int args)
{
	if (isPaused && IsPlayer(client))
	{
		if (playerReady[client])
		{
			CPrintToChatAll("{green}[SM] {blue}%N {default}is {olive}unready{default}.", client);
		}
		playerReady[client] = false;
		CancelFullReady(client);
	}
	return Plugin_Handled;
}

public Action ToggleReady_Cmd(int client, int args)
{
	if (isPaused && IsPlayer(client))
	{
		playerReady[client] = !playerReady[client];
		//PrintToChatAll("[SM] %N marked %s as %sready", client, teamString[L4D2Team:GetClientTeam(client)], playerReady[client] ? "" : "not ");
		CPrintToChatAll("{green}[SM] {blue}%N {default}is {olive}%sready", client, playerReady[client] ? "" : "not ");
		if (playerReady[client] && CheckFullReady())
		{
			InitiateLiveCountdown();
		}
		else if (!playerReady[client])
		{
			CancelFullReady(client);
		}
	}
	return Plugin_Handled;
}

public Action ForcePause_Cmd(int client, int args)
{
	if (!isPaused)
	{
		Pause();
	}
}

public Action ForceUnpause_Cmd(int client, int args)
{
	if (isPaused)
	{
		InitiateLiveCountdown();
	}
}

void AttemptPause()
{
	if (deferredPauseTimer == INVALID_HANDLE)
	{
		if (CanPause())
		{
			Pause();
		}
		else
		{
			CPrintToChatAll("{green}[SM] {default}暂停因为正在救人而被延迟了!");
			deferredPauseTimer = CreateTimer(0.1, DeferredPause_Timer, _, TIMER_REPEAT);
		}
	}
}

public Action DeferredPause_Timer(Handle timer)
{
	if (CanPause())
	{
		deferredPauseTimer = INVALID_HANDLE;
		Pause();
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void Pause()
{
	/*
	for (new L4D2Team:team; team < L4D2Team; team++)
	{
		teamReady[team] = false;
	}*/
	for (int client = 1; client <= MaxClients; client++)
	{
		playerReady[client] = false;
	}

	isPaused = true;
	readyCountdownTimer = INVALID_HANDLE;

	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	bool pauseProcessed = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if(!pauseProcessed)
			{
				SetConVarBool(sv_pausable, true);
				FakeClientCommand(client, "pause");
				SetConVarBool(sv_pausable, false);
				pauseProcessed = true;
			}
			if (GetClientTeam(client) == 1)
			{
				SendConVarValue(client, sv_noclipduringpause, "1");
			}
		}
	}
	Call_StartForward(pauseForward);
	Call_Finish();
}

void Unpause()
{
	isPaused = false;

	bool unpauseProcessed = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if(!unpauseProcessed)
			{
				SetConVarBool(sv_pausable, true);
				FakeClientCommand(client, "unpause");
				SetConVarBool(sv_pausable, false);
				unpauseProcessed = true;
			}
			if (GetClientTeam(client) == 1)
			{
				SendConVarValue(client, sv_noclipduringpause, "0");
			}
		}
	}
	Call_StartForward(unpauseForward);
	Call_Finish();
}

// 战役面板

public Action MenuRefresh_Timer(Handle timer)
{
	if (isPaused)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

void UpdatePanel()
{
	if (menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
		menuPanel = INVALID_HANDLE;
	}
	
	menuPanel = CreatePanel();
	
	// DrawPanelText(menuPanel, "Team Status");
	// DrawPanelText(menuPanel, teamReady[L4D2Team_Survivor] ? "->1. Survivors: Ready" : "->1. Survivors: Not ready");
	// DrawPanelText(menuPanel, teamReady[L4D2Team_Infected] ? "->2. Infected: Ready" : "->2. Infected: Not ready");
	
	DrawPanelText(menuPanel, "准备状态");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		char buffer[64];
		if (IsPlayer(client))
		{
			playerReady[client] ? (Format(buffer, sizeof(buffer), "☑ %N", client)) : (Format(buffer, sizeof(buffer), "☐ %N", client));
			DrawPanelText(menuPanel, buffer);
		}
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

void InitiateLiveCountdown()
{
	if (readyCountdownTimer == INVALID_HANDLE)
	{
		CPrintToChatAll("{red}即将开始!\n{default}输入 {olive}/ur {default}取消准备.");
		readyDelay = GetConVarInt(l4d_ready_delay);
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ReadyCountdownDelay_Timer(Handle timer)
{
	if (readyDelay == 0)
	{
		CPrintToChatAll("{red}回合开始!");
		if (GetConVarBool(l4d_ready_blips))
		{
			CreateTimer(0.01, BlipDelay_Timer);
		}
		Unpause();
		return Plugin_Stop;
	}
	else
	{
		CPrintToChatAll("倒计时: %d", readyDelay);
		readyDelay--;
	}
	return Plugin_Continue;
}

public Action BlipDelay_Timer(Handle timer)
{
	EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
}

void CancelFullReady(int client)
{
	if (readyCountdownTimer != INVALID_HANDLE)
	{
		CloseHandle(readyCountdownTimer);
		readyCountdownTimer = INVALID_HANDLE;
		CPrintToChatAll("{blue}%N {red}中断了倒计时!", client);
	}
}

public Action Say_Callback(int client, char[] command, int argc)
{
	if (isPaused)
	{
		char buffer[256];
		GetCmdArgString(buffer, sizeof(buffer));
		StripQuotes(buffer);
		if (IsChatTrigger() && buffer[0] == '/' || buffer[0] == '@')  // Hidden command or chat trigger
		{
			return Plugin_Continue;
		}
		if (client == 0)
		{
			PrintToChatAll("Console : %s", buffer);
		}
		else
		{
			CPrintToChatAllEx(client, "{teamcolor}%N{default} : %s", client, buffer);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action TeamSay_Callback(int client, char[] command, int argc)
{
	if (isPaused)
	{
		char buffer[256];
		GetCmdArgString(buffer, sizeof(buffer));
		StripQuotes(buffer);
		if (IsChatTrigger() && buffer[0] == '/' || buffer[0] == '@')  // Hidden command or chat trigger
		{
			return Plugin_Continue;
		}
		PrintToTeam(client, GetClientTeam(client), buffer);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Unpause_Callback(int client, char[] command, int argc)
{
	if (isPaused)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool CheckFullReady()
{
	bool AllReady = true;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsPlayer(client) && !playerReady[client])
		{
			AllReady = false;
		}
	}
	return AllReady;
}

stock bool IsPlayer(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2);
}

stock void PrintToTeam(int author, int team, const char[] buffer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && GetClientTeam(client) == team)
		{
			CPrintToChatEx(client, author, "(%s) {teamcolor}%N{default} :  %s", teamString[GetClientTeam(author)], author, buffer);
		}
	}
}

public int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { }

stock int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

stock bool IsPlayerIncap(int client) { return view_as<bool>( GetEntProp(client, Prop_Send, "m_isIncapacitated") ); }

bool CanPause()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			if (IsPlayerIncap(client))
			{
				if (GetEntProp(client, Prop_Send, "m_reviveOwner") > 0)
				{
					return false;
				}
			}
			else
			{
				if (GetEntProp(client, Prop_Send, "m_reviveTarget") > 0)
				{
					return false;
				}
			}
		}
	}
	return true;
}
