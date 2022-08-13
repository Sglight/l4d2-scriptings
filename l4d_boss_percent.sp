#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

#define TEAM_SURVIVORS 2

public Plugin myinfo =
{
	name = "L4D2 Boss Flow Announce",
	author = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, Visor",
	version = "1.6.2",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

int iWitchPercent = 0;
int iTankPercent = 0;

ConVar g_hVsBossBuffer;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);
	RegConsoleCmd("sm_cur", BossCmd);
	RegConsoleCmd("sm_current", BossCmd);

	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);

	AddCommandListener(SetTank_Listener, "sm_settank");
	AddCommandListener(SetTank_Listener, "sm_setwitch");
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	PrintBossPercents();
	return Plugin_Continue;
}

public Action SetTank_Listener(int client, const char[] command, int argc)
{
	CreateTimer(0.1, SaveBossFlows);
	return Plugin_Continue;
}

public Action RoundStartEvent(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, SaveBossFlows);
	return Plugin_Continue;
}

public int Native_UpdateBossPercents(Handle plugin, int numParams)
{
	CreateTimer(0.1, SaveBossFlows);
	return true;
}

public Action SaveBossFlows(Handle timer)
{
	iWitchPercent = 0;
	iTankPercent = 0;

	if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
	{
		iWitchPercent = RoundToNearest(GetWitchFlow(0) * 100.0);
	}
	if (L4D2Direct_GetVSTankToSpawnThisRound(0))
	{
		iTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
	}
	return Plugin_Continue;
}

stock void PrintBossPercents()
{
	int boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	if (iTankPercent)
		PrintToChatAll("\x01<\x05Current\x01> \x04%d%%    \x01<\x05Tank\x01> \x04%d%%    \x01<\x05Witch\x01> \x04%d%", boss_proximity, iTankPercent, iWitchPercent);
	else
		PrintToChatAll("\x01<\x05Current\x01> \x04%d%%    \x01<\x05Tank\x01> \x04Static Tank    \x01<\x05Witch\x01> \x04%i%", boss_proximity, iTankPercent, iWitchPercent);
}

public Action BossCmd(int client, int args)
{
	PrintBossPercents();
	return Plugin_Continue;
}

stock float GetTankFlow(int round)
{
	return L4D2Direct_GetVSTankFlowPercent(round);
}

stock float GetWitchFlow(int round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round);
}

float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVsBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();

	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS) {
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}

	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}