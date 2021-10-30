#include <sourcemod>
#include <left4dhooks>

#pragma newdecls required

ConVar hMobInterval;
ConVar hDebug;
bool bAllowSpawnMobs = true;

public void OnPluginStart()
{
	hMobInterval = CreateConVar("mob_spawn_block_interval", "8.0");
	hDebug = CreateConVar("mob_spawn_debug", "0");
}

public Action L4D_OnSpawnMob(int &amount)
{
	int mobSize = GetConVarInt(FindConVar("z_mega_mob_size"));
	float mobInterval = GetConVarFloat(hMobInterval);
	bool iDebug = GetConVarBool(hDebug);
	if (iDebug) {
		PrintToChatAll("mob original amount: %d", amount);
	}
	if (bAllowSpawnMobs) {
		if (amount > mobSize) {
			amount = mobSize;
		}
		bAllowSpawnMobs = false;
		if (iDebug) {
			PrintToChatAll("mob altered amount: %d", amount);
		}
		CreateTimer(mobInterval, MobsIntervalTimer);
		return Plugin_Changed;
	} else {
		return Plugin_Handled;
	}
}

public Action MobsIntervalTimer(Handle timer, int client)
{
	bAllowSpawnMobs = true;
}