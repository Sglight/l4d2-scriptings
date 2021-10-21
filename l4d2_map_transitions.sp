#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2util>
#include <colors>

#pragma newdecls required

#define DEBUG 0

#define MAP_NAME_MAX_LENGTH 64
#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

StringMap hMapTransitionPair = null;

bool g_bHasTransitioned = false;

public Plugin myinfo = 
{
	name = "Map Transitions",
	author = "Derpduck, Forgetest",
	description = "Define map transitions to combine campaigns",
	version = "3-coop",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	CheckGame();
	LoadSDK();
	
	hMapTransitionPair = new StringMap();
	RegServerCmd("sm_add_map_transition", AddMapTransition);
	HookEvent("map_transition", Event_MapTransition);
}

void CheckGame()
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		SetFailState("Plugin 'Map Transitions' supports Left 4 Dead 2 only!");
	}
}

void LoadSDK()
{
	Handle conf = LoadGameConfigFile(LEFT4FRAMEWORK_GAMEDATA);
	if (conf == INVALID_HANDLE)
	{
		SetFailState("Could not load gamedata/%s.txt", LEFT4FRAMEWORK_GAMEDATA);
	}

	StartPrepSDKCall(SDKCall_GameRules);
	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "SetCampaignScores"))
	{
		SetFailState("Function 'SetCampaignScores' not found.");
	}
	
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	delete conf;
}

public Action Event_MapTransition(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(6.0, OnRoundEnd_Post);
}

public Action OnRoundEnd_Post(Handle timer)
{
	//Check if map has been registered for a map transition
	char currentMapName[MAP_NAME_MAX_LENGTH];
	char nextMapName[MAP_NAME_MAX_LENGTH];
	
	GetCurrentMap(currentMapName, sizeof(currentMapName));
	
	//We have a map to transition to
	if (hMapTransitionPair.GetString(currentMapName, nextMapName, sizeof(nextMapName)))
	{
		g_bHasTransitioned = true;
		
		#if DEBUG
			LogMessage("Map transitioned from: %s to: %s", currentMapName, nextMapName);
		#endif
		
		CPrintToChatAll("{olive}[MT]{default} Starting transition from: {blue}%s{default} to: {blue}%s", currentMapName, nextMapName);
		ForceChangeLevel(nextMapName, "Map Transitions");
	}
}

public void OnMapStart()
{
	//Set scores after a modified transition
	if (g_bHasTransitioned)
	{
		CreateTimer(8.0, OnMapStart_Post); //Clients have issues connecting if team swap happens exactly on map start, so we delay it
		g_bHasTransitioned = false;
	}
}

public Action OnMapStart_Post(Handle timer)
{
	// L4D2_FullRestart();
}

public Action AddMapTransition(int args)
{
	if (args != 2)
	{
		PrintToServer("Usage: sm_add_map_transition <starting map name> <ending map name>");
		LogError("Usage: sm_add_map_transition <starting map name> <ending map name>");
		return Plugin_Handled;
	}
	
	//Read map pair names
	char mapStart[MAP_NAME_MAX_LENGTH];
	char mapEnd[MAP_NAME_MAX_LENGTH];
	GetCmdArg(1, mapStart, sizeof(mapStart));
	GetCmdArg(2, mapEnd, sizeof(mapEnd));
	
	hMapTransitionPair.SetString(mapStart, mapEnd, true);
	
	return Plugin_Handled;
}