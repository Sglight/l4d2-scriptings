#define PLUGIN_VERSION 		"1.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Survivor Thirdperson
*	Author	:	SilverShot
*	Descrp	:	Creates a command for survivors to use thirdperson view.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=185664
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (12-Oct-2019)
	- Added commands "sm_3rdon" and "sm_3rdoff" to explicitly set the view.

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.1 (21-May-2012)
	- Removed admin only access from the commands, they are now usable by all survivors.

1.0 (20-May-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Thirdperson\x04] \x01"

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
bool g_bCvarAllow, g_bThirdView[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Survivor Thirdperson",
	author = "SilverShot",
	description = "Creates a command for survivors to use thirdperson view.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=185664"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	g_hCvarAllow =		CreateConVar(	"l4d2_third_allow",		"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d2_third_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_third_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_third_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(						"l4d2_third_version",	PLUGIN_VERSION, "Survivor Thirdperson plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_third");

	RegConsoleCmd("sm_3rdoff",		CmdTP_Off,		"Turns thirdperson view off.");
	RegConsoleCmd("sm_3rdon",		CmdTP_On,		"Turns thirdperson view on.");
	RegConsoleCmd("sm_3rd",			CmdThird,		"Toggles thirdperson view.");
	RegConsoleCmd("sm_tp",			CmdThird,		"Toggles thirdperson view.");
	RegConsoleCmd("sm_third",		CmdThird,		"Toggles thirdperson view.");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			g_bThirdView[i] = false;
			SetEntPropFloat(i, Prop_Send, "m_TimeForceExternalView", 0.0);
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_spawn",			Event_PlayerSpawn);
		HookEvent("round_end",				Event_RoundEnd,	EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",			Event_PlayerSpawn);
		UnhookEvent("round_end",			Event_RoundEnd,	EventHookMode_PostNoCopy);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bThirdView[client] = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
		g_bThirdView[i] = false;
}



// ====================================================================================================
//					COMMAND
// ====================================================================================================
public Action CmdTP_Off(int client, int args)
{
	if( client && IsPlayerAlive(client) )
	{
		SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);
		PrintToChat(client, "%s%t", CHAT_TAG, "Off");
	}
}

public Action CmdTP_On(int client, int args)
{
	if( client && IsPlayerAlive(client) )
	{
		SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
		PrintToChat(client, "%s%t", CHAT_TAG, "On");
	}
}

public Action CmdThird(int client, int args)
{
	// if( client && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	if( client && IsPlayerAlive(client) )
	{
		// Goto third
		if( g_bThirdView[client] == false )
		{
			g_bThirdView[client] = true;
			SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 99999.3);
			PrintToChat(client, "%s%t", CHAT_TAG, "On");
		}
		// Goto first
		else
		{
			g_bThirdView[client] = false;
			SetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView", 0.0);
			PrintToChat(client, "%s%t", CHAT_TAG, "Off");
		}
	}

	return Plugin_Handled;
}