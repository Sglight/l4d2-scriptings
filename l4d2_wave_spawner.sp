#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle hSpawnStarted;

bool bIsRoundStarted = false;

public void OnPluginStart()
{
    RegConsoleCmd("starttest", starttest);
    RegConsoleCmd("stoptest", stoptest);

    hSpawnStarted = CreateConVar("wave_spawn_start", "0");

    HookEvent("versus_round_start", Event_VSRoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public Action starttest(int client,int args)
{
	CheatCommand("script_reload_code", "versus.nut");
	CheatCommand("script_reload_code", "coop.nut");
}

public Action stoptest(int client,int args)
{
	CheatCommand("script_reload_code", "versus.nut");
	CheatCommand("script_reload_code", "coop.nut");
}

public Action Event_VSRoundStart(Handle event, char[] name, bool dontBroadcast)
{
    hSpawnStarted
}

public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
    
}

public Action Timer_Toggle(Handle timer, int limit)
{
    SetConVarBool(hSpawnStarted, !GetConVarBool(hSpawnStarted));
}

public void CheatCommand(char[] strCommand, char[] strParam1)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientInGame(client))
		{
			int flags = GetCommandFlags(strCommand);
			SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
			FakeClientCommand(client, "%s %s", strCommand, strParam1);
			SetCommandFlags(strCommand, flags);
		}
	}
}