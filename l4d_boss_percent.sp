#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

public Plugin:myinfo =
{
	name = "L4D2 Boss Flow Announce (Back to roots edition)",
	author = "ProdigySim, Jahze, Stabby, CircleSquared, CanadaRox, Visor",
	version = "1.6.1",
	description = "Announce boss flow percents!",
	url = "https://github.com/ConfoglTeam/ProMod"
};

new iWitchPercent = 0;
new iTankPercent = 0;

new Handle:g_hVsBossBuffer;
//new Handle:hCvarPrintToEveryone;
//new Handle:hCvarTankPercent;
//new Handle:hCvarWitchPercent;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("UpdateBossPercents", Native_UpdateBossPercents);
	RegPluginLibrary("l4d_boss_percent");
	return APLRes_Success;
}

public OnPluginStart()
{
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");

	//hCvarPrintToEveryone = CreateConVar("l4d_global_percent", "1", "Display boss percentages to entire team when using commands", FCVAR_PLUGIN);
	//hCvarTankPercent = CreateConVar("l4d_tank_percent", "1", "Display Tank flow percentage in chat", FCVAR_PLUGIN);
	//hCvarWitchPercent = CreateConVar("l4d_witch_percent", "1", "Display Witch flow percentage in chat", FCVAR_PLUGIN);

	RegConsoleCmd("sm_boss", BossCmd);
	RegConsoleCmd("sm_tank", BossCmd);
	RegConsoleCmd("sm_witch", BossCmd);
	RegConsoleCmd("sm_cur", BossCmd);
	RegConsoleCmd("sm_current", BossCmd);

	// HookEvent("player_left_start_area", LeftStartAreaEvent, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStartEvent, EventHookMode_PostNoCopy);
	
	AddCommandListener(SetTank_Listener, "sm_settank");
	AddCommandListener(SetTank_Listener, "sm_setwitch");
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	PrintBossPercents();
}

public Action:SetTank_Listener(client, const String:command[], argc)
{
	CreateTimer(0.1, SaveBossFlows);
}

public RoundStartEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, SaveBossFlows);
}

public Native_UpdateBossPercents(Handle:plugin, numParams)
{
	CreateTimer(0.1, SaveBossFlows);
	return true;
}

public Action:SaveBossFlows(Handle:timer)
{
	if (!InSecondHalfOfRound())
	{
		iWitchPercent = 0;
		iTankPercent = 0;

		if (L4D2Direct_GetVSWitchToSpawnThisRound(0))
		{
			iWitchPercent = RoundToNearest(GetWitchFlow(0)*100.0);
		}
		if (L4D2Direct_GetVSTankToSpawnThisRound(0))
		{
			iTankPercent = RoundToNearest(GetTankFlow(0)*100.0);
		}
	}
	else
	{
		if (iWitchPercent != 0)
		{
			iWitchPercent = RoundToNearest(GetWitchFlow(1)*100.0);
		}
		if (iTankPercent != 0)
		{
			iTankPercent = RoundToNearest(GetTankFlow(1)*100.0);
		}
	}
}

stock PrintBossPercents()
{
	new boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	if (iTankPercent)
		PrintToChatAll("\x01<\x05当前\x01> \x04%d%%    \x01<\x05Tank\x01> \x04%d%%    \x01<\x05Witch\x01> \x04%d%", boss_proximity, iTankPercent, iWitchPercent);
	else
		PrintToChatAll("\x01<\x05当前\x01> \x04%d%%    \x01<\x05Tank\x01> \x04固定Tank    \x01<\x05Witch\x01> \x04%i%", boss_proximity, iTankPercent, iWitchPercent);
}

public Action:BossCmd(client, args)
{
	PrintBossPercents();
	return Plugin_Handled;
}

stock Float:GetTankFlow(round)
{
	return L4D2Direct_GetVSTankFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetWitchFlow(round)
{
	return L4D2Direct_GetVSWitchFlowPercent(round) -
		( Float:GetConVarInt(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance() );
}

stock Float:GetBossProximity()
{
	new Float:proximity = GetMaxSurvivorCompletion() + GetConVarFloat(g_hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
	return proximity;
}

stock Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i))
		{
			flow = MAX(flow, L4D2Direct_GetFlowDistance(i));
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}