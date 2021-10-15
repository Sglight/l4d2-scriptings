#pragma semicolon 1

enum Angle_Vector {
	Pitch = 0,
	Yaw,
	Roll
};

Handle hCvarJockeyLeapRange; // vanilla cvar

Handle hCvarHopActivationProximity; // custom cvar
// Leaps
bool bCanLeap[MAXPLAYERS];
bool bDoNormalJump[MAXPLAYERS]; // used to alternate pounces and normal jumps
 // shoved jockeys will stop hopping

Handle hCvarJockeyStumbleRadius; // stumble radius of jockey ride

// Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"

public void Jockey_OnModuleStart() {
	// CONSOLE VARIABLES
	// jockeys will move to attack survivors within this range
	hCvarJockeyLeapRange = FindConVar("z_jockey_leap_range");
	SetConVarInt(hCvarJockeyLeapRange, 1000); 
	
	// proximity when plugin will start forcing jockeys to hop
	hCvarHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "500", "How close a jockey will approach before it starts hopping");
	
	// Jockey stumble
	HookEvent("jockey_ride", OnJockeyRide, EventHookMode_Pre); 
	hCvarJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a jockey landing a ride");
}

public void Jockey_OnModuleEnd() {
	ResetConVar(hCvarJockeyLeapRange);
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action Jockey_OnPlayerRunCmd(int jockey, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, bool hasBeenShoved) {
	float jockeyPos[3];
	GetClientAbsOrigin(jockey, jockeyPos);
	int iSurvivorsProximity = GetSurvivorProximity(jockeyPos);
	bool bHasLOS = view_as<bool>( GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats") ); // line of sight to any survivor
	
	// Start hopping if within range	
	if ( bHasLOS && (iSurvivorsProximity < GetConVarInt(hCvarHopActivationProximity)) ) {
		
		// Force them to hop 
		int flags = GetEntityFlags(jockey);
		
		// Alternate normal jump and pounces if jockey has not been shoved
		if ( (flags & FL_ONGROUND) && !hasBeenShoved ) { // jump/leap off cd when on ground (unless being shoved)
			if (bDoNormalJump[jockey]) {
				buttons |= IN_JUMP; // normal jump
				bDoNormalJump[jockey] = false;
			} else {
				if( bCanLeap[jockey] ) {
					buttons |= IN_ATTACK; // pounce leap
					bCanLeap[jockey] = false; // leap should be on cooldown
					float leapCooldown = float( GetConVarInt(FindConVar("z_jockey_leap_again_timer")) );
					CreateTimer(leapCooldown, Timer_LeapCooldown, jockey, TIMER_FLAG_NO_MAPCHANGE);
					bDoNormalJump[jockey] = true;
				} 			
			}
			
		} else { // midair, release buttons
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}		
		return Plugin_Changed;
	} 

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/

// Enable hopping on spawned jockeys
public Action Jockey_OnSpawn(int botJockey) {
	bCanLeap[botJockey] = true;
	return Plugin_Handled;
}

// Disable hopping when shoved
public void Jockey_OnShoved(int botJockey) {
	bCanLeap[botJockey] = false;
	int leapCooldown = GetConVarInt(FindConVar("z_jockey_leap_again_timer"));
	CreateTimer( float(leapCooldown), Timer_LeapCooldown, botJockey, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action Timer_LeapCooldown(Handle timer, int jockey) {
	bCanLeap[jockey] = true;
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public void OnJockeyRide(Handle event, const char[] name, bool dontBroadcast) {	
	if (IsCoop()) {
		int attacker = GetClientOfUserId(GetEventInt(event, "userid"));  
		int victim = GetClientOfUserId(GetEventInt(event, "victim"));  
		if(attacker > 0 && victim > 0) {
			StumbleBystanders(victim, attacker);
		} 
	}	
}

bool IsCoop() {
	char GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	return (!StrEqual(GameName, "versus", false) && !StrEqual(GameName, "scavenge", false));
}

void StumbleBystanders( int pinnedSurvivor, int pinner ) {
	float pinnedSurvivorPos[3];
	float pos[3];
	float dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	int radius = GetConVarInt(hCvarJockeyStumbleRadius);
	for( int i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && IsPlayerAlive(i) && IsSurvivor(i) ) {
			if( i != pinnedSurvivor && i != pinner && !IsPinned(i) ) {
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if( GetVectorLength(dir) <= float(radius) ) {
					NormalizeVector( dir, dir ); 
					L4D_StaggerPlayer( i, pinnedSurvivor, dir );
				}
			}
		} 
	}
}

stock float modulus(float a, float b) {
	while(a > b)
		a -= b;
	return a;
}