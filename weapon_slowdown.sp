/**
 * Wingman 配套插件，功能也很简单，要改部分武器的最大行走速度就直接使用 weapon attributes，不用额外加 cvar。
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

Handle hEnable;
Handle hSpeedUpEnable;
Handle hSpeedUpInterval;

float fSpeedUpTimer[MAXPLAYERS];

public Plugin myinfo = 
{
    name             = "Weapon Slowdown",
    author             = "海洋空氣",
    description     = "Player will get different speed when they equip different weapon.",
    version         = "1.0",
    url             = "https://steamcommunity.com/id/larkspur2017/"
}

public void OnPluginStart()
{
    hEnable = CreateConVar("weaponslowdown_enable","1", "持枪减速开关。");
    hSpeedUpEnable = CreateConVar("weaponslowdown_kill_speedup_enable","1", "击杀特感恢复原速度。");
    hSpeedUpInterval = CreateConVar("weaponslowdown_kill_speedup_interval","10.0", "击杀特感恢复原速度的时长。");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnWeaponSwitchPost(int client, int weapon)
{
    if (!GetConVarBool(hEnable) || !IsSurvivor(client)) return;
    if (fSpeedUpTimer[client] > 0.0) return; // 加速状态，停止减速
    char sWeaponName[64];
    float fWeaponSpeed;
    float fFactor;
    GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));

    if (!L4D2_IsValidWeapon(sWeaponName)) return;

    fWeaponSpeed = GetWeaponMaxPlayerSpeed(sWeaponName);
    fFactor = CalculateFactor(fWeaponSpeed);
    SetPlayerSpeedFactor(client, fFactor);
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
    if(!hSpeedUpEnable) return;
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    if (IsSurvivor(attacker) && IsInfected(victim)) {
        SetPlayerSpeedFactor(attacker, 1.0);
        fSpeedUpTimer[attacker] = GetConVarFloat(hSpeedUpInterval);
        CreateTimer(1.0, Timer_ResetSpeed, attacker, TIMER_REPEAT);
    }
}

public Action Timer_ResetSpeed(Handle timer, int client)
{
    if (fSpeedUpTimer[client] <= 0.0) {
        char sWeaponName[64];
        float fWeaponSpeed;
        float fFactor;
        GetClientWeapon(client, sWeaponName, sizeof(sWeaponName));

        if (!L4D2_IsValidWeapon(sWeaponName)) return Plugin_Stop;

        fWeaponSpeed = GetWeaponMaxPlayerSpeed(sWeaponName);
        fFactor = CalculateFactor(fWeaponSpeed);
        SetPlayerSpeedFactor(client, fFactor);
        return Plugin_Stop;
    } else {
        fSpeedUpTimer[client]--;
        return Plugin_Continue;
    }
}

float GetWeaponMaxPlayerSpeed(char[] sWeaponName)
{
    return L4D2_GetFloatWeaponAttribute(sWeaponName, L4D2FWA_MaxPlayerSpeed) - 30.0;
}

float CalculateFactor(float fWeaponSpeed)
{
    // return FloatDiv(fWeaponSpeed, 220.0);
    return fWeaponSpeed / 220.0;
}

void SetPlayerSpeedFactor(int client, float factor)
{
    SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", factor);
    SetEntityGravity(client, 2 - factor);
}

bool IsSurvivor(int client)
{
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientConnected(client)) return false;
    if (!IsClientInGame(client)) return false;
    if (GetClientTeam(client) != 2) return false;
    return true;
}

bool IsInfected(int client)
{
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientConnected(client)) return false;
    if (!IsClientInGame(client)) return false;
    if (GetClientTeam(client) != 3) return false;
    return true;
}