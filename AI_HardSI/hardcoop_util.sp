// Thanks to L4D2Util for many stock functions and enumerations

#pragma semicolon 1
#include <sourcemod>
#include <smlib>

#if defined HARDCOOP_UTIL_included
#endinput
#endif

#define HARDCOOP_UTIL_included

#define DEBUG_FLOW 0

#define TEAM_CLASS(%1) (%1 == ZC_SMOKER ? "smoker" : (%1 == ZC_BOOMER ? "boomer" : (%1 == ZC_HUNTER ? "hunter" :(%1 == ZC_SPITTER ? "spitter" : (%1 == ZC_JOCKEY ? "jockey" : (%1 == ZC_CHARGER ? "charger" : (%1 == ZC_WITCH ? "witch" : (%1 == ZC_TANK ? "tank" : "None"))))))))
#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))


enum L4D2_Team {
    L4D2Team_Spectator = 1,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum L4D2_Infected {
    L4D2Infected_Smoker = 1,
    L4D2Infected_Boomer,
    L4D2Infected_Hunter,
    L4D2Infected_Spitter,
    L4D2Infected_Jockey,
    L4D2Infected_Charger,
    L4D2Infected_Witch,
    L4D2Infected_Tank
};

// alternative enumeration
// Special infected classes
enum ZombieClass {
    ZC_NONE = 0, 
    ZC_SMOKER, 
    ZC_BOOMER, 
    ZC_HUNTER, 
    ZC_SPITTER, 
    ZC_JOCKEY, 
    ZC_CHARGER, 
    ZC_WITCH, 
    ZC_TANK, 
    ZC_NOTINFECTED
};

// 0=Anywhere, 1=Behind, 2=IT, 3=Specials in front, 4=Specials anywhere, 5=Far Away, 6=Above
enum SpawnDirection {
    ANYWHERE = 0,
    BEHIND,
    IT,
    SPECIALS_IN_FRONT,
    SPECIALS_ANYWHERE,
    FAR_AWAY,
    ABOVE   
};

// Velocity
enum VelocityOverride {
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

/***********************************************************************************************************************************************************************************

                                                                  		SURVIVORS
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client: client ID
 * @return bool
 */
stock bool IsSurvivor(int client) {
	if( IsValidClient(client) && view_as<L4D2_Team>( GetClientTeam(client) ) == L4D2Team_Survivor ) {
		return true;
	} else {
		return false;
	}
}

stock bool IsPinned(int client) {
	bool bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

/**
 * @return: The highest %map completion held by a survivor at the current point in time
 */
stock void GetMaxSurvivorCompletion() {
	float flow = 0.0;
	float tmp_flow;
	float origin[3];
	Address pNavArea;
	for ( int client = 1; client <= MaxClients; client++ ) {
		if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
			GetClientAbsOrigin(client, origin);
			tmp_flow = GetFlow(origin);
			flow = MAX(flow, tmp_flow);
		}
	}
	
	int current = RoundToNearest(flow * 100 / L4D2Direct_GetMapMaxFlowDistance());
		
		#if DEBUG_FLOW
			Client_PrintToChatAll( true, "Current: {G}%d%%", current );
		#endif
		
	return current;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
stock float GetFarthestSurvivorFlow() {
	float farthest_flow = 0.0;
	float origin[3];
	for (int client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            GetClientAbsOrigin(client, origin);
            float flow = GetFlow(origin);
            if ( flow > farthest_flow ) {
            	farthest_flow = flow;
            }
        }
    }
	return farthestFlow;
}

/**
 * Returns the average flow distance covered by each survivor
 */
stock float GetAverageSurvivorFlow() {
    int survivor_count = 0;
    float total_flow = 0.0;
    float origin[3];
    for (int client = 1; client <= MaxClients; client++) {
        if ( IsSurvivor(client) && IsPlayerAlive(client) ) {
            survivor_count++;
            GetClientAbsOrigin(client, origin);
            new Float:client_flow = GetFlow(origin);
            if ( GetFlow(origin) != -1.0 ) {
            	total_flow++;
            }
        }
    }
    return FloatDiv(totalFlow, float(survivor_count));
}

/**
 * Returns the flow distance from given point to closest alive survivor. 
 * Returns -1.0 if either the given point or the survivors as a whole are not upon a valid nav mesh
 */
stock void GetFlowDistToSurvivors(const float pos[3]) {
	int spawnpoint_flow;
	int lowest_flow_dist = -1;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow == -1) {
		return -1;
	}
	
	for ( int j = 0; j < MaxClients; j++ ) {
		if ( IsSurvivor(j) && IsPlayerAlive(j) ) {
			float origin[3];
			int flow_dist;
			
			GetClientAbsOrigin(j, origin);
			flow_dist = GetFlow(origin);
			
			// have we found a new valid(i.e. != -1) lowest flow_dist
			if ( flow_dist != -1 && FloatCompare(FloatAbs(float(flow_dist) - float(spawnpoint_flow)), float(lowest_flow_dist)) ==  -1 ) {
				lowest_flow_dist = flow_dist;
			}
		}
	}
	
	return lowest_flow_dist;
}

/**
 * Returns the flow distance of a given point
 */
 stock void GetFlow(const float o[3]) {
 	float origin[3]; //non constant var
 	origin[0] = o[0];
 	origin[1] = o[1];
 	origin[2] = o[2];
 	Address pNavArea;
 	pNavArea = L4D2Direct_GetTerrorNavArea(origin);
 	if ( pNavArea != Address_Null ) {
 		return RoundToNearest(L4D2Direct_GetTerrorNavAreaFlow(pNavArea));
 	} else {
 		return -1;
 	}
 }
 
/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsIncapacitated(int client) {
    return view_as<bool>( GetEntProp(client, Prop_Send, "m_isIncapacitated") );
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock int GetClosestSurvivor( float referencePos[3], int excludeSurvivor = -1 ) {
	float survivorPos[3];
	int closestSurvivor = GetRandomSurvivor();	
	if (closestSurvivor == 0) return 0;
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	int iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (int client = 1; client < MaxClients; client++) {
		if( IsSurvivor(client) && IsPlayerAlive(client) && client != excludeSurvivor ) {
			GetClientAbsOrigin( client, survivorPos );
			int iAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
			if( iClosestAbsDisplacement < 0 ) { // Start with the absolute displacement to the first survivor found:
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = client;
			} else if( iAbsDisplacement < iClosestAbsDisplacement ) { // closest survivor so far
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = client;
			}			
		}
	}
	return closestSurvivor;
}

/**
 * Returns the distance of the closest survivor or a specified survivor
 * @param referenceClient: the client from which to measure distance to survivor
 * @param specificSurvivor: the index of the survivor to be measured, -1 to search for distance to closest survivor
 * @return: the distance
 */
stock int GetSurvivorProximity( const float rp[3], int specificSurvivor = -1 ) {
	int targetSurvivor;
	float targetSurvivorPos[3];
	float referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	

	if( specificSurvivor > 0 && IsSurvivor(specificSurvivor) ) { // specified survivor
		targetSurvivor = specificSurvivor;		
	} else { // closest survivor		
		targetSurvivor = GetClosestSurvivor( referencePos );
	}
	
	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}

/** @return: the index to a random survivor */
stock int GetRandomSurvivor() {
	int survivors[MAXPLAYERS];
	int numSurvivors = 0;
	for( int i = 0; i < MAXPLAYERS; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
		    survivors[numSurvivors] = i;
		    numSurvivors++;
		}
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

/***********************************************************************************************************************************************************************************

                                                                   	SPECIAL INFECTED 
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * @return: the special infected class of the client
 */
stock L4D2_Infected GetInfectedClass(int client) {
    return view_as<L4D2_Infected>( GetEntProp(client, Prop_Send, "m_zombieClass") );
}

stock bool IsInfected(int client) {
    if (!IsClientInGame(client) || view_as<L4D2_Team>( GetClientTeam(client) ) != L4D2Team_Infected) {
        return false;
    }
    return true;
}

/**
 * @return: true if client is a special infected bot
 */
stock bool IsBotInfected(int client) {
    // Check the input is valid
    if (!IsValidClient(client))return false;
    
    // Check if player is a bot on the infected team
    if (IsInfected(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}

stock bool IsBotHunter(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == view_as<L4D2_Infected>( L4D2Infected_Hunter) );
}

stock bool IsBotCharger(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == view_as<L4D2_Infected>( L4D2Infected_Charger) );
}

stock bool IsBotJockey(int client) {
	return (IsBotInfected(client) && GetInfectedClass(client) == view_as<L4D2_Infected>( L4D2Infected_Jockey) );
}

// @return: the number of a particular special infected class alive in the game
stock void CountSpecialInfectedClass(ZombieClass targetClass) {
    int count = 0;
    for (int i = 1; i < MaxClients; i++) {
        if ( IsBotInfected(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i) ) {
            new playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (playerClass == _:targetClass) {
                count++;
            }
        }
    }
    return count;
}

// @return: the total special infected bots alive in the game
stock void CountSpecialInfectedBots() {
    int count = 0;
    for (int i = 1; i < MaxClients; i++) {
        if (IsBotInfected(i) && IsPlayerAlive(i)) {
            count++;
        }
    }
    return count;
}

stock void Client_Push(int client, float clientEyeAngle[3], float power, VelocityOverride override[3] = VelocityOvr_None) {
	float forwardVector[3];
	float newVel[3];
	
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	//PrintToChatAll("Tank velocity: %.2f", forwardVector[1]);
	
	Entity_GetAbsVelocity(client,newVel);
	
	for( int i = 0; i < 3; i++ ) {
		switch( override[i] ) {
			case VelocityOvr_Velocity: {
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity: {				
				if( newVel[i] < 0.0 ) {
					newVel[i] *= -1.0;
				}
			}
		}
		
		newVel[i] += forwardVector[i];
	}
	
	Entity_SetAbsVelocity(client,newVel);
}

/***********************************************************************************************************************************************************************************

                                                                       		TANK
                                                                    
***********************************************************************************************************************************************************************************/

/**
 *@return: true if client is a tank
 */
stock bool IsTank(int client) {
    return IsClientInGame(client)
        && GetClientTeam(client) == L4D2_Team:L4D2Team_Infected
        && GetInfectedClass(client) == L4D2_Infected:L4D2Infected_Tank;
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock void FindTankClient(int iTankClient) {
    for (int i = iTankClient < 0 ? 1 : iTankClient+1; i < MaxClients+1; i++) {
        if (IsTank(i)) {
            return i;
        }
    }
    
    return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool IsTankInPlay() {
    return bool:(FindTankClient(-1) != -1);
}

stock bool IsBotTank(int client) {
	// Check the input is valid
	if (!IsValidClient(client)) return false;
	// Check if player is on the infected team, a hunter, and a bot
	if (GetClientTeam(client) == L4D2_Team:L4D2Team_Infected) {
		L4D2_Infected zombieClass = L4D2_Infected:GetEntProp(client, Prop_Send, "m_zombieClass");
		if (zombieClass == L4D2_Infected:L4D2Infected_Tank) {
			if(IsFakeClient(client)) {
				return true;
			}
		}
	}
	return false; // otherwise
}

/***********************************************************************************************************************************************************************************

                                                                   			MISC
                                                                    
***********************************************************************************************************************************************************************************/

/**
 * Executes a cheat command through a dummy client
 *
 * @param command: The command to execute
 * @param argument1: Optional argument for command
 * @param argument2: Optional argument for command
 * @param dummyName: The name to use for the dummy client 
 *
**/
stock void CheatCommand( char[] commandName, char[] argument1 = "", char[] argument2 = "", bool doUseCommandBot = false ) {
    int flags = GetCommandFlags(commandName);       
    if ( flags != INVALID_FCVAR_FLAGS ) {
		int commandDummy = -1;
		if( doUseCommandBot ) {
			// Search for an existing bot named '[CommandBot]'
			for( int i = 1; i < MAXPLAYERS; i++ ) {
				if( IsValidClient(i) && IsClientInGame(i) && IsFakeClient(i) ) {
					char clientName[32];
					GetClientName( i, clientName, sizeof(clientName) );
					if( StrContains( clientName, "[CommandBot]", true ) != -1 ) {
						commandDummy = i;
					}
				}  		
			}
			// Create a command bot if necessary
			if ( !IsValidClient(commandDummy) || IsClientInKickQueue(commandDummy) ) { // Command bot may have been kicked by SMAC_Antispam.smx
			    commandDummy = CreateFakeClient("[CommandBot]");
			    if( IsValidClient(commandDummy) ) {
			    	ChangeClientTeam(commandDummy, view_as<int>( L4D2Team_Spectator) );	
			    } else {
			    	commandDummy = GetRandomSurvivor(); // wanted to use a bot, but failed; last resort
			    }			
			}
		} else {
			commandDummy = GetRandomSurvivor();
		}
		
		// Execute command
		if ( IsValidClient(commandDummy) ) {
		    int originalUserFlags = GetUserFlagBits(commandDummy);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(commandDummy, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(commandDummy, originalUserFlags);            
		} else {
			char pluginName[128];
			GetPluginFilename( INVALID_HANDLE, pluginName, sizeof(pluginName) );
			//LogError( "%s could not find or create a client through which to execute cheat command %s", pluginName, commandName );
		}   
    }
}

// Executes vscript code through the "script" console command
stock void ScriptCommand(char[] arguments, any ...) {
    // format vscript input
    char vscript[PLATFORM_MAX_PATH];
    VFormat(vscript, sizeof(vscript), arguments, 2);
    
    // Execute vscript input
    CheatCommand("script", vscript, "");
}

// Sets the spawn direction for SI, relative to the survivors
// Yet to test whether map specific scripts override this option, and if so, how to rewrite this script line
stock void SetSpawnDirection(SpawnDirection direction) {
    ScriptCommand("g_ModeScript.DirectorOptions.PreferredSpecialDirection<-%i", _:direction);   
}

/**
 * Returns true if the client ID is valid
 *
 * @param client: client ID
 * @return bool
 */
stock bool IsValidClient(int client) {
    if( client > 0 && client <= MaxClients && IsClientInGame(client) ) {
    	return true;
    } else {
    	return false;
    }    
}

stock bool IsGenericAdmin(int client) {
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false); 
}

// Kick dummy bot 
public Action Timer_KickBot(Handle timer, int client) {
	if (IsClientInGame(client) && (!IsClientInKickQueue(client))) {
		if (IsFakeClient(client))KickClient(client);
	}
}