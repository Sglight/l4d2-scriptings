#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <smlib>

#include "includes/hardcoop_util.sp"
#include "modules/AI_Smoker.sp"
#include "modules/AI_Boomer.sp"
#include "modules/AI_Hunter.sp"
#include "modules/AI_Spitter.sp"
#include "modules/AI_Charger.sp"
#include "modules/AI_Jockey.sp"
#include "modules/AI_Tank.sp"
#include "modules/AI_Witch.sp"

Handle g_hTimer;

ConVar g_hAssaultReminderInterval;

bool g_bHasBeenShoved[MAXPLAYERS + 1]; // shoving resets SI movement 

public Plugin myinfo = 
{
	name = "AI: Hard SI",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() 
{
	g_hAssaultReminderInterval = CreateConVar( "ai_assault_reminder_interval", "2.0", "Frequency(sec) at which the 'nb_assault' command is fired to make SI attack" );
	
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", InitialiseSpecialInfected);
	HookEvent("ability_use", OnAbilityUse); 
	HookEvent("player_shoved", OnPlayerShoved);
	HookEvent("player_jump", OnPlayerJump);

	Smoker_OnModuleStart();
	Hunter_OnModuleStart();
	Spitter_OnModuleStart();
	Boomer_OnModuleStart();
	Charger_OnModuleStart();
	Jockey_OnModuleStart();
	Tank_OnModuleStart();
	Witch_OnModuleStart();
}

public void OnPluginEnd() 
{
	Smoker_OnModuleEnd();
	Hunter_OnModuleEnd();
	Spitter_OnModuleEnd();
	Boomer_OnModuleEnd();
	Charger_OnModuleEnd();
	Jockey_OnModuleEnd();
	Tank_OnModuleEnd();
	Witch_OnModuleEnd();
}

/***********************************************************************************************************************************************************************************

																	KEEP SI AGGRESSIVE
																	
***********************************************************************************************************************************************************************************/
public void OnMapEnd()
{
	delete g_hTimer;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	InitStatus();
	delete g_hTimer;
	g_hTimer = CreateTimer(g_hAssaultReminderInterval.FloatValue, Timer_ForceInfectedAssault, _, TIMER_REPEAT);
}

public Action Timer_ForceInfectedAssault(Handle timer)
{
	CheatCommand("nb_assault");
}

/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(GetClientTeam(client) != 3 || !IsFakeClient(client) || !IsPlayerAlive(client) || IsGhost(client))
		return Plugin_Continue;

	switch(GetInfectedClass(client)) 
	{
		case L4D2Infected_Smoker:
			return Smoker_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
			
		case L4D2Infected_Hunter:
		{
			if(!g_bHasBeenShoved[client]) 
				return Hunter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
		}		

		case L4D2Infected_Spitter:
			return Spitter_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);

		case L4D2Infected_Charger:
			return Charger_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
			
		case L4D2Infected_Jockey:
			return Jockey_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon, g_bHasBeenShoved[client]);
				
		case L4D2Infected_Boomer:
			return Boomer_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);

		case L4D2Infected_Tank:
			return Tank_OnPlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
	}

	if(buttons & IN_ATTACK)
		UpdateSIAttackTime();

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/
public Action InitialiseSpecialInfected(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotInfected(client)) 
	{
		g_bHasBeenShoved[client] = false;
		switch(GetInfectedClass(client)) 
		{
			case L4D2Infected_Hunter:
				Hunter_OnSpawn(client);

			case L4D2Infected_Charger: 
				Charger_OnSpawn(client);
		}
	}
}

public Action OnAbilityUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotInfected(client)) 
	{
		g_bHasBeenShoved[client] = false;
		static char sAbilityName[32];
		sAbilityName[0] = 0;
		event.GetString("ability", sAbilityName, sizeof(sAbilityName));
		if(strcmp(sAbilityName, "ability_lunge") == 0) 
			Hunter_OnPounce(client); 
		else if(strcmp(sAbilityName, "ability_charge") == 0) 
			Charger_OnCharge(client);
		/*else if(strcmp(sAbilityName, "ability_spit") == 0) 
			CreateTimer(0.5, Timer_Suicide, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);*/
		else if(strcmp(sAbilityName, "ability_vomit") == 0)
			Boomer_OnVomit(client);
	}
}
/*
public Action OnTongueRelease(Event event, const char[] name, bool dontBroadcast) 
{
	int userid = event.GetInt("userid");
	if(IsBotInfected(GetClientOfUserId(userid))) 
		CreateTimer(0.5, Timer_Suicide, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Suicide(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(client && IsClientInGame(client))
		ForcePlayerSuicide(client);
}
*/

public Action OnPlayerShoved(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotInfected(client)) 
	{
		g_bHasBeenShoved[client] = true;
		switch(GetInfectedClass(client))
		{
			case L4D2Infected_Jockey:
				Jockey_OnShoved(client);

			case L4D2Infected_Boomer:
				Boomer_OnShoved(client);
				
			/*case L4D2Infected_Spitter:
				Spitter_OnShoved(client);*/
		}
	}
}

public Action OnPlayerJump(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsBotInfected(client))  
		g_bHasBeenShoved[client] = false;
} 

/***********************************************************************************************************************************************************************************

																	TRACKING SURVIVORS' AIM

***********************************************************************************************************************************************************************************/

/**
	Determines whether an attacking SI is being watched by the survivor
	@return: true if the survivor's crosshair is within the specified radius
	@param attacker: the client number of the attacking SI
	@param offsetThreshold: the radius(degrees) of the cone of detection around the straight line from the attacked survivor to the SI
**/
bool IsTargetWatchingAttacker(int attacker, int offsetThreshold) 
{
	static bool isWatching;
	isWatching = true;
	if(GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker)) 
	{ // SI continue to hold on to their targets for a few seconds after death
		int target = GetClientAimTarget(attacker);
		if(IsSurvivor(target)) 
		{
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if(aimOffset <= offsetThreshold) 
				isWatching = true;
			else 
				isWatching = false;
		} 
	}	
	return isWatching;
}

/**
	Calculates how much a player's aim is off another player
	@return: aim offset in degrees
	@attacker: considers this player's eye angles
	@target: considers this player's position
	Adapted from code written by Guren with help from Javalia
**/
float GetPlayerAimOffset(int attacker, int target) 
{
	if(!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
		ThrowError("Client is not Alive."); 
	if(!IsClientInGame(target) || !IsPlayerAlive(target))
		ThrowError("Target is not Alive.");
		
	static float attackerPos[3], targetPos[3];
	static float aimVector[3], directVector[3];

	// Get the unit vector representing the attacker's aim
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0; // Restrict pitch and roll, consider yaw only (angles on horizontal plane)
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR); // extract the forward vector[3]
	NormalizeVector(aimVector, aimVector); // convert into unit vector
	
	// Get the unit vector representing the vector between target and attacker
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0; // Restrict to XY coordinates
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	// Calculate the angle between the two unit vectors
	return RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
}