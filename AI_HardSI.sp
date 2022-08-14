#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <left4dhooks>

ConVar hCvarAssaultReminderInterval;
bool bHasBeenShoved[MAXPLAYERS]; // shoving resets SI movement 
float g_delay[MAXPLAYERS][8];

enum AimTarget {
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

#include "AI_HardSI/hardcoop_util.sp"
#include "AI_HardSI/AI_Smoker.sp"
#include "AI_HardSI/AI_Boomer.sp"
#include "AI_HardSI/AI_Hunter.sp"
#include "AI_HardSI/AI_Spitter.sp"
#include "AI_HardSI/AI_Charger.sp"
#include "AI_HardSI/AI_Jockey.sp"
#include "AI_HardSI/AI_Tank.sp"
#include "AI_HardSI/AI_Witch.sp"

public Plugin myinfo = 
{
	name = "AI: Hard SI",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.1",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	// Cvars
	hCvarAssaultReminderInterval = CreateConVar( "ai_assault_reminder_interval", "2", "Frequency(sec) at which the 'nb_assault' command is fired to make SI attack" );
	// Event hooks
	HookEvent("player_spawn", InitialiseSpecialInfected, EventHookMode_Pre);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre); 
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Pre);
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Pre);
	// Load modules
	// Smoker_OnModuleStart();
	Hunter_OnModuleStart();
	Spitter_OnModuleStart();
	Boomer_OnModuleStart();
	Charger_OnModuleStart();
	Jockey_OnModuleStart();
	Tank_OnModuleStart();
	Witch_OnModuleStart();
}

public void OnPluginEnd() {
	// Unload modules
	// Smoker_OnModuleEnd();
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

public Action L4D_OnFirstSurvivorLeftSafeArea(int firstSurvivor) {
	CreateTimer( float(GetConVarInt(hCvarAssaultReminderInterval)), Timer_ForceInfectedAssault, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	return Plugin_Continue;
}

public Action Timer_ForceInfectedAssault(Handle timer) {
	CheatCommand("nb_assault");
	return Plugin_Continue;
}


/***********************************************************************************************************************************************************************************

																		SI MOVEMENT
																	
***********************************************************************************************************************************************************************************/

// Modify SI movement
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon) {
	if( IsBotInfected(client) && IsPlayerAlive(client) ) { // bots continue to trigger this callback for a few seconds after death
		int botInfected = client;
		switch( view_as<int>(GetInfectedClass(botInfected)) ) {
			case (L4D2Infected_Smoker): {
				if( !bHasBeenShoved[botInfected] ) return Smoker_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}
			
			case (L4D2Infected_Hunter): {
				if( !bHasBeenShoved[botInfected] ) return Hunter_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}
			
			case (L4D2Infected_Charger): {
				return Charger_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}
			
			case (L4D2Infected_Jockey): {
				return Jockey_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon, bHasBeenShoved[botInfected] );
			}
			
			case (L4D2Infected_Tank): {
				return Tank_OnPlayerRunCmd( botInfected, buttons, impulse, vel, angles, weapon );
			}
			
			case (L4D2Infected_Boomer): {
				return Boomer_OnPlayerRunCmd( botInfected, buttons, vel, angles );
			}
			/* 
			case (L4D2Infected_Spitter): {
				return Spitter_OnPlayerRunCmd( botInfected, buttons, vel, angles );
			}
			 */
			default: {
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																		EVENT HOOKS

***********************************************************************************************************************************************************************************/

// Initialise relevant module flags for SI when they spawn
public Action InitialiseSpecialInfected(Handle event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		int botInfected = client;
		bHasBeenShoved[client] = false;
		// Process for SI class
		switch( GetInfectedClass(botInfected) ) {
		
			case (L4D2Infected_Hunter): {
				return Hunter_OnSpawn(botInfected);
			}
			
			case (L4D2Infected_Charger): {
				return Charger_OnSpawn(botInfected);
			}
			
			case (L4D2Infected_Jockey): {
				return Jockey_OnSpawn(botInfected);
			}
			
			case (L4D2Infected_Boomer): {
				return Boomer_OnSpawn(botInfected);
			}
			
			default: {
				return Plugin_Handled;	
			}				
		}
	}
	return Plugin_Handled;
}

// Modify hunter lunges and block smokers/spitters from fleeing after using their ability
public Action OnAbilityUse(Handle event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		int bot = client;
		bHasBeenShoved[bot] = false; // Reset shove status		
		// Process for different SI
		char abilityName[32];
		GetEventString(event, "ability", abilityName, sizeof(abilityName));
		if( StrEqual(abilityName, "ability_lunge") ) {
			return Hunter_OnPounce(bot);
		} else if( StrEqual(abilityName, "ability_charge") ) {
			Charger_OnCharge(bot);
		} /* else if( StrEqual(abilityName, "ability_spit") ) { // stop smokers and spitters running away
			CreateTimer(0.5, Timer_Suicide, any:client, TIMER_FLAG_NO_MAPCHANGE);
		}*/
	}
	return Plugin_Handled;
}

public Action OnTongueRelease(Handle event, char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(client) ) {
		CreateTimer(0.5, Timer_Suicide, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Action Timer_Suicide(Handle timer, int client) {
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

// Pause behaviour modification when shoved
public Action OnPlayerShoved(Handle event, char[] name, bool dontBroadcast) {
	int shovedPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(shovedPlayer) ) {
		bHasBeenShoved[shovedPlayer] = true;
		if( GetInfectedClass(shovedPlayer) == L4D2Infected_Jockey ) {
			Jockey_OnShoved(shovedPlayer);
		}
		else if ( GetInfectedClass(shovedPlayer) == L4D2Infected_Boomer ) {
			Boomer_OnShoved(shovedPlayer);
		}
	}
	return Plugin_Continue;	
}

// Re-enable forced hopping when a shoved jockey leaps again naturally
public Action OnPlayerJump(Handle event, char[] name, bool dontBroadcast) {
	int jumpingPlayer = GetClientOfUserId(GetEventInt(event, "userid"));
	if( IsBotInfected(jumpingPlayer) )  {
		bHasBeenShoved[jumpingPlayer] = false;
	}
	return Plugin_Continue;
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
bool IsTargetWatchingAttacker(int attacker, int offsetThreshold) {
	bool isWatching = true;
	if( GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker) ) { // SI continue to hold on to their targets for a few seconds after death
		int target = GetClientAimTarget(attacker);
		if( IsSurvivor(target) ) { 
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if( aimOffset <= offsetThreshold ) {
				isWatching = true;
			} else {
				isWatching = false;
			}		
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
float GetPlayerAimOffset(int attacker, int target) {
	if( !IsClientConnected(attacker) || !IsClientInGame(attacker) || !IsPlayerAlive(attacker) )
		ThrowError("Client is not Alive."); 
	if(!IsClientConnected(target) || !IsClientInGame(target) || !IsPlayerAlive(target) )
		ThrowError("Target is not Alive.");
		
	float attackerPos[3], targetPos[3];
	float aimVector[3], directVector[3];
	float resultAngle;
	
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
	resultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
	return resultAngle;
}

stock void delayStart(int client, int no)
{
	g_delay[client][no] = GetGameTime();
}

stock bool delayExpired(int client, int no, float delay)
{
	return GetGameTime() - g_delay[client][no] > delay;
}

stock bool isVisibleTo(int client, int target) {
	bool ret = false;
	float angles[3];
	float self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, angles);
	Handle trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		int hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

stock void computeAimAngles(int client, int target, float angles[3], AimTarget type = AimTarget_Eye) {
	float target_pos[3];
	float self_pos[3];
	float lookat[3];
	
	GetClientEyePosition(client, self_pos);
	switch (type) {
		case AimTarget_Eye: {
			GetClientEyePosition(target, target_pos);
		}
		case AimTarget_Body: {
			GetClientAbsOrigin(target, target_pos);
		}
		case AimTarget_Chest: {
			GetClientAbsOrigin(target, target_pos);
			target_pos[2] += 45.0; // このくらい
		}
	}
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}

public bool traceFilter(int entity, int mask, int self) {
	return entity != self;
}