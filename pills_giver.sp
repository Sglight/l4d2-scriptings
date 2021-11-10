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
	hPillsMapKill = CreateConVar("ast_pills_map_kill", "0", "删除地图刷的药", FCVAR_PROTECTED, true, 0.0, false);
	hPillsDelay = CreateConVar("ast_pills_delay", "5.0", "发药延迟时间", FCVAR_PROTECTED, true, 0.0, false);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("weapon_drop", Event_WeaponDrop, EventHookMode_Post);
	HookEvent("weapon_given", Event_WeaponGive, EventHookMode_Post);
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
}

public Action Event_WeaponGive(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(hPillsEnabled))
	{
		int client = GetClientOfUserId(GetEventInt(event, "giver"));
		int weapon = GetEventInt(event, "weapon");
		if (weapon == 15)
		{
			float delay = GetConVarFloat(hPillsDelay);
			CreateTimer(delay, Timer_GivePill, client);
		}
	}
}

public Action Timer_GivePill(Handle timer, int client)
{
	if ( ( GetConVarInt(hPillsSurvivor) == -1 || gavePillsSurvivorCount[client] < GetConVarInt(hPillsSurvivor) ) 
	&& GetGavePillsTeamCount() < GetConVarInt(hPillsTeam) ) {
		int pill = CreateEntityByName("weapon_pain_pills");
		EquipPlayerWeapon(client, pill);
		gavePillsSurvivorCount[client]++;
	}
}

public int GetGavePillsTeamCount()
{
	int count = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2) {
			count += gavePillsSurvivorCount[i];
		}
	}
	return count;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++) {
		gavePillsSurvivorCount[client] = 0;
	}

	if ( GetConVarBool(hPillsMapKill) ) {
		CreateTimer(1.0, Timer_KillMapPills, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action Timer_KillMapPills(Handle timer)
{
	char classname[128];
	int entityCount = GetEntityCount();

	for (int i = 1; i <= entityCount; i++)
	{
		if (!IsValidEntity(i)) { continue; }

		// check item type
		GetEdictClassname(i, classname, sizeof(classname));
		if ( StrEqual(classname, "weapon_pain_pills") ) { // 开局应该不用判断药是不是在手上吧
			AcceptEntityInput(i, "Kill");
		}
	}
}