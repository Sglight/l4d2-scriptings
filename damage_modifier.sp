#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2_skill_detect>
#include <left4dhooks>
#include <colors>

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

char SI_Names[][] =
{
	"Unknown",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
	"Not SI"
};

Handle hCvarDmgThreshold = INVALID_HANDLE;
Handle hTongueCutSlayEnable = INVALID_HANDLE;
Handle hDmgThreshold = INVALID_HANDLE;
Handle hRatioDamage = INVALID_HANDLE;

bool bIsUsingAbility[MAXPLAYERS + 1];
float fDmgPrint = 0.0;

public Plugin myinfo =
{
	name = "Damage Modify For AstMod",
	author = "海洋空氣",
	description = "Modify damage (hunter, jockey, smoker, charger) on single player mode.",
	version = "1.3",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	hCvarDmgThreshold = CreateConVar("sm_1v1_dmgthreshold", "1", "Amount of damage done (at once) before SI suicides.");
	hTongueCutSlayEnable = CreateConVar("dma_cutslay", "1", "砍舌处死开关");
	hDmgThreshold = CreateConVar("dma_dmg", "12.0", "被控扣血数值");
	hRatioDamage = CreateConVar("ratio_damage", "0", "按比例扣血开关");

	HookEvent("ability_use", OnAbilityUse);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("tongue_release", OnTongueRelease);

	// 牛起身无敌修复
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);
}

public void OnClientPutInServer(int client)
{
	if (client > 0 && client < MaxClients)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (client > 0 && client < MaxClients)
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnAbilityUse(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	char ability[64];
	GetEventString(event, "ability", ability, sizeof(ability));
	if (strcmp(ability,"ability_tongue", false) == 0 && !bIsUsingAbility[client]) {
		bIsUsingAbility[client] = true;
		CreateTimer(2.0, Timer_ResetAbility, client);
	}
}

public Action Timer_ResetAbility(Handle timer, int client)
{
	bIsUsingAbility[client] = false;
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(client) && GetZombieClass(client) == ZC_SMOKER) {
		bIsUsingAbility[client] = false;
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTongueRelease(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(client) && GetZombieClass(client) == ZC_SMOKER)
		bIsUsingAbility[client] = false;
}

public int OnTongueCut(int survivor, int smoker)
{
	if (GetConVarBool(hTongueCutSlayEnable) == true) {
		ForcePlayerSuicide(smoker);
		char weapon[32];
		GetClientWeapon(survivor, weapon, sizeof(weapon));
		SendDeathMessage(survivor, smoker, weapon, false);
	}
	return 0;
}

// While a Charger is carrying a Survivor, undo any friendly fire done to them
// since they are effectively pinned and pinned survivors are normally immune to FF
public Action Event_ChargerCarryStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = true;
	return Plugin_Continue;
}

// End immunity about one second after the carry ends
// (there is some time between carryend and pummelbegin,
// but pummelbegin does not always get called if the charger died first, so it is unreliable
public Action Event_ChargerPummelStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = false;
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if ( !IsClientAndInGame(victim) || !IsClientAndInGame(attacker) ) return Plugin_Handled;

	if (GetClientTeam(victim) == TEAM_INFECTED && GetZombieClass(victim) == ZC_SMOKER && bIsUsingAbility[victim]) { // 秒舌头
		damage = 250.0;
		return Plugin_Changed;
	}
	if ( GetClientTeam(attacker) == TEAM_INFECTED &&
	( GetZombieClass(attacker) == ZC_SMOKER ||
	GetZombieClass(attacker) == ZC_HUNTER ||
	GetZombieClass(attacker) == ZC_JOCKEY ||
	GetZombieClass(attacker) == ZC_CHARGER ) ) { // 舌ht猴牛
		float fdamage;
		if (GetConVarBool(hRatioDamage)) { // 开关打开时
			int iHP = GetEntProp(attacker, Prop_Data, "m_iHealth"); // 获取特感血量
			int iHPmax = GetEntProp(attacker, Prop_Data, "m_iMaxHealth"); // 获取特感满血血量
			float fiHP = float(iHP); // 转成浮点型
			float fiHPmax = float(iHPmax);
			float ratio = fiHP / fiHPmax;
			fdamage = GetConVarFloat(hDmgThreshold) * ratio;
			if (fdamage < 1.0) { // 避免无伤害不处死特感
				fdamage = 1.0;
			}
		} else {
			fdamage = GetConVarFloat(hDmgThreshold);
		}
		//fDmgPrint = RoundFloat(fdamage);
		fDmgPrint = fdamage;
		damage = fdamage;

		if (GetZombieClass(attacker) == ZC_CHARGER && bIsUsingAbility[attacker]) { // 牛撞停不造成伤害，防止过早处死导致pummel end事件不触发，进而导致起身没有无敌。
			damage = 0.0;
		}
		return Plugin_Changed;
	}
	else return Plugin_Continue;
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientAndInGame(attacker) || !IsClientAndInGame(victim)) return;

	int damage = GetEventInt(event, "dmg_health");
	int zombie_class = GetZombieClass(attacker);

	if (GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVOR && zombie_class != ZC_TANK && damage >= GetConVarInt(hCvarDmgThreshold))
	{
		int remaining_health = GetClientHealth(attacker);

		ForcePlayerSuicide(attacker);
		CPrintToChatAll("[{olive}AstMod{default}] {red}%N{default}({green}%s{default}) 还剩下 {olive}%d{default} 血! 造成了 {olive}%2.1f{default} 点伤害!", attacker, SI_Names[zombie_class], remaining_health, fDmgPrint);
	}
}

stock bool isInfected(int client) {
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED;
}

stock int GetZombieClass(int client) { return GetEntProp(client, Prop_Send, "m_zombieClass"); }

stock bool IsClientAndInGame(int index) {
	if (index > 0 && index < MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

void SendDeathMessage(int attacker, int victim, const char[] weapon, bool headshot)
{
    Event event = CreateEvent("player_death");
    if (event == null)
    {
        return;
    }

    event.SetInt("userid", GetClientUserId(victim));
    event.SetInt("attacker", GetClientUserId(attacker));
    event.SetString("weapon", weapon);
    event.SetBool("headshot", headshot);
    event.Fire();
}