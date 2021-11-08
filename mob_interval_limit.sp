#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

ConVar hMobInterval;
ConVar hDebug;
ConVar hMegaMobSize;
ConVar hMobSpawnMinSize;
ConVar hMobSpawnMaxSize;
int iMegaMobSize;
int iMobSpawnMinSize;
int iMobSpawnMaxSize;
bool bAllowSpawnMobs = true;
bool bAllowMobsChange = true;

public void OnPluginStart()
{
	hMobInterval = CreateConVar("mob_spawn_block_interval", "8.0");
	hDebug = CreateConVar("mob_spawn_debug", "0");

	RegServerCmd("sm_mob_lock", LockMobs);
	RegServerCmd("sm_mob_unlock", UnlockMobs);

	hMegaMobSize = FindConVar("z_mega_mob_size");
	hMobSpawnMinSize = FindConVar("z_mob_spawn_min_size");
	hMobSpawnMaxSize = FindConVar("z_mob_spawn_max_size");

	HookConVarChange(hMegaMobSize, OnMobChanged);
	HookConVarChange(hMobSpawnMinSize, OnMobChanged);
	HookConVarChange(hMobSpawnMaxSize, OnMobChanged);
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

public Action LockMobs(int args)
{
	bAllowMobsChange = false;

	iMegaMobSize = GetConVarInt(hMegaMobSize);
	iMobSpawnMinSize = GetConVarInt(hMobSpawnMinSize);
	iMobSpawnMaxSize = GetConVarInt(hMobSpawnMaxSize);
}

public Action UnlockMobs(int args)
{
	bAllowMobsChange = true;
}

public void OnMobChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!bAllowMobsChange) {
		SetConVarInt(hMegaMobSize, iMegaMobSize);
		SetConVarInt(hMobSpawnMinSize, iMobSpawnMinSize);
		SetConVarInt(hMobSpawnMaxSize, iMobSpawnMaxSize);
	}
}