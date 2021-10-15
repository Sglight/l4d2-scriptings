#include <sourcemod>
#include <sdktools>
//#include <sdkhooks>
//#include <l4d2util>
#include <l4d2_direct>
#include <left4downtown>
#include <l4d2_saferoom_detect>

#pragma newdecls required

Handle gameMode;

int aliveClient = -1;

public Plugin myinfo =
{
	name = "[L4D2] Versus-Like coop",
	author = "海洋空氣",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	gameMode = FindConVar("mp_gamemode");
	HookEvent("door_close", Event_DoorClose, EventHookMode_Pre);
	HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
	HookEvent("mission_lost",  Event_MissionLost, EventHookMode_Post);
	//HookEvent("round_end",  Event_MissionLost, EventHookMode_Post);
	HookEvent("round_start",  Event_RoundStart, EventHookMode_Post);
	//HookEvent("versus_round_start", RoundStart_Event, EventHookMode_Post);
}

/*
public Action RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
	PrintToChatAll("m_bInSecondHalfOfRound: %d", GameRules_GetProp("m_bInSecondHalfOfRound"));
	PrintToChatAll("m_bAreTeamsFlipped: %d", GameRules_GetProp("m_bAreTeamsFlipped"));
	GameRules_SetProp("m_bInSecondHalfOfRound", 1);
	GameRules_SetProp("m_bAreTeamsFlipped", 1);
	PrintToChatAll("m_bInSecondHalfOfRound: %d", GameRules_GetProp("m_bInSecondHalfOfRound"));
	PrintToChatAll("m_bAreTeamsFlipped: %d", GameRules_GetProp("m_bAreTeamsFlipped"));
}*/

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	aliveClient = -1;
	
	if (!InSecondHalfOfRound())
	{
		L4D3_ScenarioEnd(1);
	}
	
	PrintToChatAll("m_bInSecondHalfOfRound: %d", GameRules_GetProp("m_bInSecondHalfOfRound"));
}
public Action Event_PlayerIncap(Handle event, const char[] name, bool dontBroadcast)
{
	//if (!InSecondHalfOfRound()) return;
	
	if (IsTeamImmobilised())
	{
		SetCoop();
	}
}

public Action Event_DoorClose(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	bool checkpoint = GetEventBool(event, "checkpoint");
	if (checkpoint && client > 0 && SAFEDETECT_IsPlayerInEndSaferoom(client))
	{
		//CreateTimer(0.1, SetCoopTimer);
		//SetCoop();
		aliveClient = client;
		
		//GameRules_SetProp("m_bInSecondHalfOfRound", 1, 4, 0, true);
		//SetConVarString(gameMode, "coop");
	}
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	PrintToChatAll("m_bInSecondHalfOfRound: %d", GameRules_GetProp("m_bInSecondHalfOfRound"));
	if (!InSecondHalfOfRound() || aliveClient > 0) 
	{
		//L4D2_SetVersusCampaignScores({1000, 2000});
		//ShowRoundEndScores(1, 2, 3, 4, false);
		//L4D2Direct_DirectorEndScenario();
		//SetVersusRoundInProgress(false);
		//FireMatchEndEvent(0);
		return Plugin_Continue;
		//return Plugin_Handled;
	}
	else {
		SetCoop();
		return Plugin_Handled;
	}
}

public Action Event_MissionLost(Handle event, const char[] name, bool dontBroadcast)
{
	//if (!InSecondHalfOfRound()) return;
	
	SetCoop();
}

public void SetCoop()
{
	SetConVarString(gameMode, "coop");
	CreateTimer(2.0, SetVersusTimer);
}

/*public Action SetCoopTimer(Handle timer)
{
	SetConVarString(gameMode, "coop");
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		if ((client > 0 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))) // 生还活着（在终点安全室）
		{
			return;
		}
		else
		{
			CreateTimer(1.0, SetVersusTimer);
			return;
		}
	}
	//aliveClient = -1;
}*/

public Action SetVersusTimer(Handle timer)
{
	SetConVarString(gameMode, "versus");
}

int InSecondHalfOfRound() {
    return GameRules_GetProp("m_bInSecondHalfOfRound");
}

public void SetVersusRoundInProgress(bool inProgress)
{
	Address pRoundInProgress = Address_Null;
	if (pRoundInProgress == Address_Null)
	{
		int offset = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirectorVersusMode::m_bVersusRoundInProgress");
		if (offset == -1)
		{
			SetFailState("Failed to read CDirectorVersusMode::m_bVersusRoundInProgress offset");
		}
		pRoundInProgress = L4D2Direct_GetCDirectorVersusMode() + view_as<Address>(offset);
		//pRoundInProgress = L4D2Direct_GetCDirector() + view_as<Address>(offset);
	}
	StoreToAddress(pRoundInProgress, inProgress ? 1 : 0, NumberType_Int8);
}

// Campaign score 1 (pre),
// Campaign score 2 (pre),
// Chapter score 1,
// Chapter score 2,
// Show tiebreak
public void ShowRoundEndScores(int t1,int t2,int c1,int c2,bool tiebreak)
{
	int iTiebreak = tiebreak ? 1 : 0;
	Handle scoreKv = CreateKeyValues("scores");
	KvSetNum(scoreKv, "t1", t1);
	KvSetNum(scoreKv, "t2", t2);
	KvSetNum(scoreKv, "c1", c1);
	KvSetNum(scoreKv, "c2", c2);
	KvSetNum(scoreKv, "tiebreak", iTiebreak);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowVGUIPanel(i, "fullscreen_vs_scoreboard", scoreKv);
		}
	}
}

// 0: tie
// 1: team 0/1
// 2: team 1/2
public void FireMatchEndEvent(int winner)
{
	Handle event = CreateEvent("versus_match_finished");
	SetEventInt(event, "winners", winner);
	FireEvent(event);
}

public void L4D3_EndVersusModeRound()
{
	Handle svEndVSRound = INVALID_HANDLE;
	Handle svGameData = LoadGameConfigFile("left4downtown.l4d2");
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(svGameData, SDKConf_Signature, "EndVersusModeRound");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	svEndVSRound = EndPrepSDKCall();
	if (svEndVSRound == null)
	{
		SetFailState("[SV] 'EndVersusModeRound' Signature Broken!");
	}
	SDKCall(svEndVSRound);
}
public void L4D3_ScenarioEnd(int target)
{
	int bits = GetUserFlagBits(target);
	int flags = GetCommandFlags("director_force_versus_start");
	SetUserFlagBits(target, ADMFLAG_ROOT);
	SetCommandFlags("director_force_versus_start", flags & ~FCVAR_CHEAT);
	FakeClientCommand(target, "director_force_versus_start");
	
	flags = GetCommandFlags("scenario_end");
	SetCommandFlags("scenario_end", flags & ~FCVAR_CHEAT);
	FakeClientCommand(target, "scenario_end");
	SetUserFlagBits(target, bits);
	SetCommandFlags("scenario_end", flags);
}

public void L4D2Direct_DirectorEndScenario()
{
	static Handle DirectorEndScenario = INVALID_HANDLE;

	if (DirectorEndScenario == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Raw);
		
		if (!PrepSDKCall_SetFromConf(L4D2Direct_GetGameConf(), SDKConf_Signature, "CDirector::EndScenario"))
		{
			return;
		}
		DirectorEndScenario = EndPrepSDKCall();
		
		if (DirectorEndScenario == INVALID_HANDLE)
		{
			return;
		}
	}
	
	SDKCall(DirectorEndScenario, L4D2Direct_GetCDirector());
}

bool IsTeamImmobilised()
{
	bool bIsTeamImmobilised = true;
	int client = 1;
	while (client < MaxClients)
	{
		if (IsSurvivor(client) && IsPlayerAlive(client))
		{
			if (!IsIncapacitated(client))
			{
				bIsTeamImmobilised = false;
				return bIsTeamImmobilised;
			}
		}
		client++;
	}
	return bIsTeamImmobilised;
}

bool IsIncapacitated(int client)
{
	bool bIsIncapped;
	if (IsSurvivor(client))
	{
		if (0 < GetEntProp(client, view_as<PropType>(0), "m_isIncapacitated", 4, 0)) 
		{
			bIsIncapped = true;
		}
		if (!IsPlayerAlive(client))
		{
			bIsIncapped = true;
		}
	}
	return bIsIncapped;
}

bool IsSurvivor(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 2;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}