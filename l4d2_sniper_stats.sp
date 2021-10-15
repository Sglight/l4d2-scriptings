/**
 * Wingman 配套插件，想法也很简单：提高玩家打狙的积极性 + 装逼是第一动力。
 * 有遇到一个问题，击杀 tank 的时候会触发好几次 player_hurt，所以加了 oldShots 来判断。
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

#define HITGROUP_GENERIC        0
#define HITGROUP_HEAD           1
#define HITGROUP_CHEST          2
#define HITGROUP_STOMACH        3
#define HITGROUP_LEFTARM        4
#define HITGROUP_RIGHTARM       5
#define HITGROUP_LEFTLEG        6
#define HITGROUP_RIGHTLEG       7
#define HITGROUP_GEAR           10

bool GameStarted;

int iShots[MAXPLAYERS + 1] = 0; // [总共开枪]
int oldShots[MAXPLAYERS + 1] = 0;
int iHitsSI[MAXPLAYERS + 1] = 0; // [命中特感]
int iHeadShotsSI[MAXPLAYERS + 1] = 0; // [爆头特感]
int iHitsCI[MAXPLAYERS + 1] = 0; // [命中特感]
int iHeadShotsCI[MAXPLAYERS + 1] = 0; // [爆头特感]

public Plugin myinfo =
{
	name = "[L4D2] Shot & Hit Counter",
	author = "海洋空氣",
	description = "",
	version = "0.1",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart() {
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("infected_hurt",Event_InfectedHurt, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("mission_lost", Event_MissionLost);
	HookEvent("round_end", Event_MissionLost);
	HookEvent("map_transition", Event_MissionLost);
}

public void OnMapStart()
{
	GameStarted = false;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	GameStarted = true;
}

public void Event_MissionLost(Handle event, const char[] name, bool dontBroadcast)
{
	GameStarted = false;
	
	for (int client = 1; client <= MaxClients; client++) {
		if (bIsSurvivor(client) && iShots[client] > 0) {
			CPrintToChatAll("{default}[Wingman] {olive}%N {default}在本回合一共开了 {olive}%d {default}枪, {olive}%d{red}[%d]{default}发命中特感, {olive}%d{red}[%d]{default}发命中小僵尸.", client, iShots[client], iHitsSI[client], iHeadShotsSI[client], iHitsCI[client], iHeadShotsCI[client]);
		}
		iShots[client] = 0;
		iHitsSI[client] = 0;
		iHeadShotsSI[client] = 0;
		iHitsCI[client] = 0;
		iHeadShotsCI[client] = 0;
	}
}

public void Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int victimId = GetClientOfUserId(GetEventInt(event, "userid"));
	int attackerId = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!bIsSurvivor(attackerId) || !bIsInfected(victimId)) return;
	char weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	int hitgroup = GetEventInt(event, "hitgroup");
	
	if (GameStarted && (StrContains(weapon, "pistol", false) >= 0 || StrContains(weapon, "sniper", false) >= 0 || StrContains(weapon, "hunting", false) >= 0)) {
		if (iShots[attackerId] != oldShots[attackerId]) {
			iHitsSI[attackerId]++;
			oldShots[attackerId] = iShots[attackerId];
		}
		if (hitgroup == HITGROUP_HEAD) {
			iHeadShotsSI[attackerId]++;
		}
	}
}

public void Event_InfectedHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int attackerId = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!bIsSurvivor(attackerId)) return;
	int hitgroup = GetEventInt(event, "hitgroup");
	char weapon[64];
	GetClientWeapon(attackerId, weapon, sizeof(weapon));
	
	if (GameStarted && (StrContains(weapon, "pistol", false) >= 0 || StrContains(weapon, "sniper", false) >= 0 || StrContains(weapon, "hunting", false) >= 0)) {
		if (iShots[attackerId] != oldShots[attackerId]) {
			iHitsCI[attackerId]++;
			oldShots[attackerId] = iShots[attackerId];
		}
		if (hitgroup == HITGROUP_HEAD) {
			iHeadShotsCI[attackerId]++;
		}
	}
}

public void Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int count = GetEventInt(event, "count");
	
	if (GameStarted && bIsSurvivor(client)) {
		char weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (StrContains(weapon, "pistol", false) >= 0 || StrContains(weapon, "sniper", false) >= 0)
		iShots[client] += count;
	}
}

bool bIsSurvivor(int client) {
	return  client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2;
}

bool bIsInfected(int client) {
	return  client > 0 && client <= MaxClients && GetClientTeam(client) == 3;
}