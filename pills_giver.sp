#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle hPillsEnabled;
Handle hPillsSurvivor;
Handle hPillsTeam;
Handle hPillsMapKill;
Handle hPillsDelay;

int gavePillsSurvivorCount[MAXPLAYERS];

public Plugin myinfo =
{
	name = "Pills Giver",
	author = "海洋空氣",
	description = "give more pills to survivors",
	version = "1.0",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	hPillsEnabled = CreateConVar("ast_pills_enabled", "0", "发药开关", FCVAR_PROTECTED, true, 0.0, false);
	hPillsSurvivor = CreateConVar("ast_pills_survivor", "1", "个人发药次数，-1 不限制，0 不发药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsTeam = CreateConVar("ast_pills_team", "4", "团队发药次数，-1 不限制，0 不发药", FCVAR_PROTECTED, true, 0.0, false);
	// hPillsMapKill = CreateConVar("ast_pills_map_kill", "0", "删除地图刷的药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsDelay = CreateConVar("ast_pills_delay", "5.0", "发药延迟时间", FCVAR_PROTECTED, true, 0.0, false);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("weapon_drop", Event_WeaponDrop, EventHookMode_Post);
	// HookEvent("weapon_given", Event_WeaponGive, EventHookMode_Post);
}

public Action Event_WeaponDrop(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(hPillsEnabled))
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		char weapon[32];
		GetEventString(event, "item", weapon, sizeof(weapon));
		if (StrEqual(weapon, "pain_pills", false))
		{
			float delay = GetConVarFloat(hPillsDelay);
			CreateTimer(delay, Timer_GivePill, client);
		}
	}
	return Plugin_Handled;
}

public Action Timer_GivePill(Handle timer, int client)
{
	int currentWeapon = GetPlayerWeaponSlot(client, 4);
	if ( ( GetConVarInt(hPillsSurvivor) == -1 || gavePillsSurvivorCount[client] < GetConVarInt(hPillsSurvivor) ) && 
	( GetConVarInt(hPillsTeam) == -1 || GetGavePillsTeamCount() < GetConVarInt(hPillsTeam) ) && 
	currentWeapon == -1 && IsPlayerAlive(client)) {
		int pill = CreateEntityByName("weapon_pain_pills");
		float clientOrigin[3];
		GetClientAbsOrigin(client, clientOrigin);
		clientOrigin[2] += 10.0;
		TeleportEntity(pill, clientOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(pill);
		EquipPlayerWeapon(client, pill);
		gavePillsSurvivorCount[client]++;

		// Call Event
		Handle hFakeEvent = CreateEvent("weapon_given");
		SetEventInt(hFakeEvent, "userid", GetClientUserId(client));
		SetEventInt(hFakeEvent, "giver", GetClientUserId(client));
		SetEventInt(hFakeEvent, "weapon", view_as<int>(15));
		SetEventInt(hFakeEvent, "weaponentid", pill);
		
		FireEvent(hFakeEvent);
	}
	return Plugin_Handled;
}

public int GetGavePillsTeamCount()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2) {
			count += gavePillsSurvivorCount[client];
		}
	}
	return count;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++) {
		gavePillsSurvivorCount[client] = 0;
	}

	// if ( GetConVarBool(hPillsMapKill) ) {
	// 	CreateTimer(5.0, Timer_KillMapPills, _, TIMER_FLAG_NO_MAPCHANGE);
	// }
	return Plugin_Handled;
}

// 实体名称为 weapon_spawn，连带着武器一起删
// Action Timer_KillMapPills(Handle timer)
// {
// 	char classname[128];
// 	int entityCount = GetEntityCount();

// 	for (int i = 1; i <= entityCount; i++)
// 	{
// 		if (!IsValidEntity(i)) { continue; }

// 		// check item type
// 		GetEntityClassname(i, classname, sizeof(classname));

// 		if ( StrContains(classname, "weapon_pain_pills") != -1 || 
// 		StrContains(classname, "weapon_item") != -1 || 
// 		StrContains(classname, "weapon_first_aid_kit") != -1 || 
// 		StrContains(classname, "weapon_defibrillator") != -1 || 
// 		StrContains(classname, "weapon_adrenaline") != -1 ) { // 开局应该不用判断药是不是在手上吧
// 			PrintToChatAll("KillMapPills, entity: %d, classname: %s", i, classname);
// 			// AcceptEntityInput(i, "Kill");
// 			RemoveEntity(i);
// 		}
// 	}
// 	return Plugin_Handled;
// }