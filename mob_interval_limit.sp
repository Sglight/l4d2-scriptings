#include <sourcemod>
#include <left4dhooks>

#pragma newdecls required

ConVar hMobInterval;
bool bAllowSpawnMobs = true;

public void OnPluginStart()
{
	hMobInterval = CreateConVar("mob_spawn_block_interval", "8.0");
}

public Action L4D_OnSpawnMob(int &amount)
{
	int mobSize = GetConVarInt(FindConVar("z_mega_mob_size"));
	float mobInterval = GetConVarFloat(hMobInterval);
	if (bAllowSpawnMobs) {
		amount = mobSize;
		bAllowSpawnMobs = false;
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