#pragma semicolon 1

#include <sdktools>
#define DEBUG_HUNTER_AIM 0
#define DEBUG_HUNTER_RNG 0
#define DEBUG_HUNTER_ANGLE 0

#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2

// Vanilla Cvars
ConVar g_hHunterCommittedAttackRange;
ConVar g_hHunterPounceReadyRange;
ConVar g_hHunterLeapAwayGiveUpRange; 
ConVar g_hHunterPounceMaxLoftAngle; 
ConVar g_hLungeInterval; 
// Gaussian random number generator for pounce angles
ConVar g_hPounceAngleMean;
ConVar g_hPounceAngleStd; // standard deviation
// Pounce vertical angle
ConVar g_hPounceVerticalAngle;
// Distance at which hunter begins pouncing fast
ConVar g_hFastPounceProximity; 
// Distance at which hunter considers pouncing straight
ConVar g_hStraightPounceProximity;
// Aim offset(degrees) sensitivity
ConVar g_hAimOffsetSensitivityHunter;
// Wall detection
ConVar g_hWallDetectionDistance;

bool g_bHasQueuedLunge[MAXPLAYERS + 1];

public void Hunter_OnModuleStart() 
{
	// Set aggressive hunter cvars		
	g_hHunterCommittedAttackRange = FindConVar("hunter_committed_attack_range"); // range at which hunter is committed to attack	
	g_hHunterPounceReadyRange = FindConVar("hunter_pounce_ready_range"); // range at which hunter prepares pounce	
	g_hHunterLeapAwayGiveUpRange = FindConVar("hunter_leap_away_give_up_range"); // range at which shooting a non-committed hunter will cause it to leap away	
	g_hLungeInterval = FindConVar("z_lunge_interval"); // cooldown on lunges
	g_hHunterPounceMaxLoftAngle = FindConVar("hunter_pounce_max_loft_angle"); // maximum vertical angle hunters can pounce
	g_hHunterCommittedAttackRange.SetInt(10000);
	g_hHunterPounceReadyRange.SetInt(500);
	g_hHunterLeapAwayGiveUpRange.SetInt(0); 
	g_hHunterPounceMaxLoftAngle.SetInt(0);
	FindConVar("z_pounce_damage_interrupt").SetInt(150);

	// proximity to nearest survivor when plugin starts to force hunters to lunge ASAP
	g_hFastPounceProximity = CreateConVar("ai_fast_pounce_proximity", "1000", "At what distance to start pouncing fast");
	
	// Verticality
	g_hPounceVerticalAngle = CreateConVar("ai_pounce_vertical_angle", "7.0", "Vertical angle to which AI hunter pounces will be restricted");
	
	// Pounce angle
	g_hPounceAngleMean = CreateConVar("ai_pounce_angle_mean", "10", "Mean angle produced by Gaussian RNG");
	g_hPounceAngleStd = CreateConVar("ai_pounce_angle_std", "20", "One standard deviation from mean as produced by Gaussian RNG");
	g_hStraightPounceProximity = CreateConVar("ai_straight_pounce_proximity", "200", "Distance to nearest survivor at which hunter will consider pouncing straight");
	
	// Aim offset sensitivity
	g_hAimOffsetSensitivityHunter = CreateConVar("ai_aim_offset_sensitivity_hunter",
									"30",
									"If the hunter has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0);
	// How far in front of hunter to check for a wall
	g_hWallDetectionDistance = CreateConVar("ai_wall_detection_distance", "-1", "How far in front of himself infected bot will check for a wall. Use '-1' to disable feature");
}

public void Hunter_OnModuleEnd() 
{
	// Reset aggressive hunter cvars
	g_hHunterCommittedAttackRange.RestoreDefault();
	g_hHunterPounceReadyRange.RestoreDefault();
	g_hHunterLeapAwayGiveUpRange.RestoreDefault();
	g_hHunterPounceMaxLoftAngle.RestoreDefault();
	FindConVar("z_pounce_damage_interrupt").RestoreDefault();
}

public Action Hunter_OnSpawn(int botHunter) 
{
	DelayStart(botHunter, 0);
	g_bHasQueuedLunge[botHunter] = false;
}

/***********************************************************************************************************************************************************************************

																		FAST POUNCING

***********************************************************************************************************************************************************************************/
public Action Hunter_OnPlayerRunCmd(int hunter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	buttons &= ~IN_ATTACK2; // block scratches

	if(GetEntProp(hunter, Prop_Send, "m_hasVisibleThreats") == 0)
		return Plugin_Continue;

	int flags = GetEntityFlags(hunter); //Proceed if the hunter is in a position to pounce
	if((flags & FL_DUCKING) && (flags & FL_ONGROUND)) 
	{
		float dist = NearestSurvivorDistance(hunter); //Start fast pouncing if close enough to survivors
		if(dist < g_hFastPounceProximity.IntValue) 
		{
			buttons &= ~IN_ATTACK; // release attack button; precautionary					
			// Queue a pounce/lunge
			if(!g_bHasQueuedLunge[hunter]) 
			{// check lunge interval timer has not already been initiated
				g_bHasQueuedLunge[hunter] = true; // block duplicate lunge interval timers
				DelayStart(hunter, 0);
			} 
			else if(DelayExpired(hunter, 0, g_hLungeInterval.FloatValue)) 
			{ // end of lunge interval; lunge!
				buttons |= IN_ATTACK;
				g_bHasQueuedLunge[hunter] = false; // unblock lunge interval timer
			} // else lunge queue is being processed
		}
	}
	return Plugin_Changed;
}

/***********************************************************************************************************************************************************************************

																	POUNCING AT AN ANGLE TO SURVIVORS

***********************************************************************************************************************************************************************************/

public Action Hunter_OnPounce(int botHunter) 
{	
	int entLunge = GetEntPropEnt(botHunter, Prop_Send, "m_customAbility"); // get the hunter's lunge entity				
	static float lungeVector[3]; 
	GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector); // get the vector from the lunge entity
	
	// Avoid pouncing straight forward if there is a wall close in front
	static float hunterPos[3];
	static float hunterAngle[3];
	GetClientAbsOrigin(botHunter, hunterPos);
	GetClientEyeAngles(botHunter, hunterAngle); 
	// Fire traceray in front of hunter 
	static Handle trace;
	trace = TR_TraceRayFilterEx(hunterPos, hunterAngle, MASK_PLAYERSOLID, RayType_Infinite, TracerayFilter, botHunter);
	static float impactPos[3];
	TR_GetEndPosition(impactPos);
	delete trace;

	// Check first object hit
	if(GetVectorDistance(hunterPos, impactPos) < g_hWallDetectionDistance.FloatValue) 
	{ // wall detected in front
		if(GetRandomInt(0, 1)) 
			AngleLunge(entLunge, 45.0);
		else 
			AngleLunge(entLunge, 315.0);
		
		#if DEBUG_HUNTER_AIM
			PrintToChatAll("Pouncing sideways to avoid wall");
		#endif
		
	} 
	else 
	{
		// Angle pounce if survivor is watching the hunter approach
		GetClientAbsOrigin(botHunter, hunterPos);		
		if(IsTargetWatchingAttacker(botHunter, g_hAimOffsetSensitivityHunter.IntValue) && GetSurvivorProximity(hunterPos) > g_hStraightPounceProximity.IntValue) 
		{			
			float pounceAngle = GaussianRNG(g_hPounceAngleMean.FloatValue, g_hPounceAngleStd.FloatValue);
			AngleLunge(entLunge, pounceAngle);
			LimitLungeVerticality(entLunge);

			#if DEBUG_HUNTER_AIM
				int target = GetClientAimTarget(botHunter);
				if(IsSurvivor(target)) 
				{
					char targetName[32];
					FormatEx(targetName, sizeof(targetName), "%N", target);
					PrintToChatAll("The aim of hunter's target(%s) is %f degrees off", targetName, GetPlayerAimOffset(target, botHunter));
					PrintToChatAll("Angling pounce to throw off survivor");
				} 
					
			#endif			
		}
	
	}
}

stock bool TracerayFilter(int impactEntity, int contentMask, any rayOriginEntity) 
{
	return impactEntity != rayOriginEntity;
}

// Credits to High Cookie and Standalone for working out the math behind hunter lunges
void AngleLunge(int lungeEntity, float turnAngle) 
{	
	// Get the original lunge's vector
	static float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
    
    // Create a new vector of the desired angle from the original
	turnAngle = DegToRad(turnAngle); // convert angle to radian form
	float forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);	
}

// Stop pounces being too high
void LimitLungeVerticality(int lungeEntity) 
{
	// Get vertical angle restriction
	float vertAngle = g_hPounceVerticalAngle.FloatValue;
	// Get the original lunge's vector
	static float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
	
	vertAngle = DegToRad(vertAngle);	
	static float flatLunge[3];
	// First rotation
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	// Second rotation
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}

/** 
 * Thanks to Newteee:
 * Random number generator fit to a bellcurve. Function to generate Gaussian Random Number fit to a bellcurve with a specified mean and std
 * Uses Polar Form of the Box-Muller transformation
*/
float GaussianRNG(float mean, float std) 
{	 	
	// Randomising positive/negative
	float chanceToken = GetRandomFloat(0.0, 1.0);
	int signBit;	
	if(chanceToken >= 0.5) 
		signBit = POSITIVE;
	else 
		signBit = NEGATIVE;   
	
	float x1;
	float x2;
	float w;
	// Box-Muller algorithm
	do{
	    // Generate random number
	    float random1 = GetRandomFloat(0.0, 1.0);	// Random number between 0 and 1
	    float random2 = GetRandomFloat(0.0, 1.0);	// Random number between 0 and 1
	 
	    x1 = 2.0 * random1 - 1.0;
	    x2 = 2.0 * random2 - 1.0;
	    w = x1 * x1 + x2 * x2;
	 
	}while(w >= 1.0); 
	float e = 2.71828;
	w = SquareRoot(-2.0 * Logarithm(w, e) / w); 

	// Random normal variable
	float y1 = x1 * w;
	float y2 = x2 * w;
	 
	// Random gaussian variable with std and mean
	float z1 = y1 * std + mean;
	float z2 = y2 * std - mean;
	
	#if DEBUG_HUNTER_RNG	
		if(signBit == NEGATIVE)
			PrintToChatAll("Angle: %f", z1);
		else 
			PrintToChatAll("Angle: %f", z2);
	#endif
	
	// Output z1 or z2 depending on sign
	if(signBit == NEGATIVE)
		return z1;
	else 
		return z2;
}