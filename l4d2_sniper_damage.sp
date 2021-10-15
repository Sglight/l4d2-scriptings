#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d2weapons>

#define HITGROUP_GENERIC        0
#define HITGROUP_HEAD           1
#define HITGROUP_CHEST          2
#define HITGROUP_STOMACH        3
#define HITGROUP_LEFTARM        4
#define HITGROUP_RIGHTARM       5
#define HITGROUP_LEFTLEG        6
#define HITGROUP_RIGHTLEG       7
#define HITGROUP_GEAR           10

new bool:bLateLoad;

new Handle:hScoutDmg = INVALID_HANDLE;
new Handle:hAWPDmg = INVALID_HANDLE;
new Handle:hScoutTankDmg  = INVALID_HANDLE;
new Handle:hAWPTankDmg = INVALID_HANDLE;
// new Handle:hMeleeTankDmg = INVALID_HANDLE;

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax )
{
	bLateLoad = late;
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "L4D2 Sniper Damage",
	author = "Visor",
	description = "Remove Scout's stomach hitgroup multiplier against hunters",
	version = "1.0",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public OnPluginStart()
{
	hScoutDmg = CreateConVar("sm_weapon_damage_scout", "125", "Scout Damage", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, false);
	hAWPDmg = CreateConVar("sm_weapon_damage_awp", "145", "AWP Damage", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, false);
	hScoutTankDmg = CreateConVar("sm_weapon_damage_scout_tank", "150", "Scout Damage", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, false);
	hAWPTankDmg = CreateConVar("sm_weapon_damage_awp_tank", "175", "AWP Damage", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, false);
	// hMeleeTankDmg = CreateConVar("sm_melee_tank_damage", "300", "Melee Tank Damage", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, false);
	
	if (bLateLoad)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
}

public Action:TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if (!IsSurvivor(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;

	new weapon = GetClientActiveWeapon(attacker);
	/*
	if (IsMelee(weapon) && IsTank(victim))
	{
		damage = GetConVarInt(hMeleeTankDmg) * 1.0;
		return Plugin_Changed;
	}
	*/
	if (!IsSniper(weapon))
		return Plugin_Continue;
	if (IsTank(victim))
	{
		damage = GetWeaponTankDamageValue(weapon) *  1.0;
		return Plugin_Changed;
	}
	
	if (hitgroup == HITGROUP_STOMACH)
	{
		damage = GetWeaponDamageValue(weapon) / 1.25;
		return Plugin_Changed;
	} else if (hitgroup == HITGROUP_HEAD)
	{
		damage = GetWeaponDamageValue(weapon) * 4.0;
		return Plugin_Changed;
	} else 
	{
		damage = GetWeaponDamageValue(weapon) * 1.0;
		return Plugin_Changed;
	}
}

GetClientActiveWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

GetWeaponDamageValue(weapon)
{
	decl String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	if (StrEqual(classname, "weapon_sniper_scout"))
		return GetConVarInt(hScoutDmg);
	else return GetConVarInt(hAWPDmg);
}

GetWeaponTankDamageValue(weapon)
{
	decl String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	if (StrEqual(classname, "weapon_sniper_scout"))
		return GetConVarInt(hScoutTankDmg);
	else return GetConVarInt(hAWPTankDmg);
}

bool:IsSniper(weapon)
{
	decl String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	return StrEqual(classname, "weapon_sniper_scout") || StrEqual(classname, "weapon_sniper_awp");
}
/*
bool:IsMelee(weapon)
{
	decl String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	return StrEqual(classname, "melee");
}
*/
bool:IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}
/*
bool:IsHunter(client)
{
	return (client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetZombieClass(client) == 3
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1);
}
*/

bool:IsTank(client)
{
	return (client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetZombieClass(client) == 8
		&& GetEntProp(client, Prop_Send, "m_isGhost") != 1);
}

stock GetZombieClass(client) return GetEntProp(client, Prop_Send, "m_zombieClass");