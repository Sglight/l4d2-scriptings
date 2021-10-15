#pragma semicolon 1

#define JockeyBoostForward 80.0 // Bhop

ConVar g_hJockeyLeapRange;
ConVar g_hHopActivationProximity;
ConVar g_hJockeyStumbleRadius;
ConVar g_hJockeyLeapAgain;

//Bibliography: "hunter pounce push" by "Pan XiaoHai & Marcus101RR & AtomicStryker"
public void Jockey_OnModuleStart() 
{
	g_hHopActivationProximity = CreateConVar("ai_hop_activation_proximity", "800", "How close a jockey will approach before it starts hopping");
	g_hJockeyStumbleRadius = CreateConVar("ai_jockey_stumble_radius", "50", "Stumble radius of a jockey landing a ride");
	 
	g_hJockeyLeapRange = FindConVar("z_jockey_leap_range");
	g_hJockeyLeapRange.SetInt(1000); 
	g_hJockeyLeapAgain = FindConVar("z_jockey_leap_again_timer");
	g_hJockeyLeapAgain.SetFloat(0.1);
	FindConVar("z_leap_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_force_attach_distance").SetFloat(250.0);
	FindConVar("z_leap_far_attach_delay").SetFloat(0.0);
	FindConVar("z_leap_max_distance").SetFloat(600.0);
	FindConVar("z_leap_power").SetFloat(450.0);
	
	HookEvent("jockey_ride", OnJockeyRide);
}

public void Jockey_OnModuleEnd() 
{
	g_hJockeyLeapRange.RestoreDefault();
	g_hJockeyLeapAgain.RestoreDefault();
	FindConVar("z_leap_attach_distance").RestoreDefault();
	FindConVar("z_leap_force_attach_distance").RestoreDefault();
	FindConVar("z_leap_far_attach_delay").RestoreDefault();
	FindConVar("z_leap_max_distance").RestoreDefault();
	FindConVar("z_leap_power").RestoreDefault();
}

/***********************************************************************************************************************************************************************************

																	HOPS: ALTERNATING LEAP AND JUMP

***********************************************************************************************************************************************************************************/

public Action Jockey_OnPlayerRunCmd(int jockey, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, bool hasBeenShoved) 
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];

	float Velocity[3];
	GetEntPropVector(jockey, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

	int flags = GetEntityFlags(jockey);
	if(flags & FL_ONGROUND)
	{
		
	}
	else if(LeftGroundMaxSpeed[jockey] == -1.0)
		LeftGroundMaxSpeed[jockey] = GetEntPropFloat(jockey, Prop_Data, "m_flMaxspeed");

	if(GetEntProp(jockey, Prop_Send, "m_hasVisibleThreats") == 0 || hasBeenShoved)
		return Plugin_Continue;

	float dist = NearestSurvivorDistance(jockey);
	if(currentspeed > 130.0)
	{
		if(dist < g_hHopActivationProximity.FloatValue) 
		{
			if(flags & FL_ONGROUND)
			{
				if(dist < 250.0 && DelayExpired(jockey, 0, g_hJockeyLeapAgain.FloatValue))
				{
					if(LeftGroundMaxSpeed[jockey] != -1.0 && currentspeed > 250.0)
					{
						float CurVelVec[3];
						GetEntPropVector(jockey, Prop_Data, "m_vecAbsVelocity", CurVelVec);
						if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[jockey])
						{
							NormalizeVector(CurVelVec, CurVelVec);
							ScaleVector(CurVelVec, LeftGroundMaxSpeed[jockey]);
							TeleportEntity(jockey, NULL_VECTOR, NULL_VECTOR, CurVelVec);
						}
						LeftGroundMaxSpeed[jockey] = -1.0;
					}

					if(GetState(jockey, 0) == IN_JUMP)
					{
						bool IsWatchingJockey = IsTargetWatchingAttacker(jockey, 20);
						if(angles[2] == 0.0 && IsWatchingJockey) 
						{
							angles = angles;
							angles[0] = GetRandomFloat(-50.0,-10.0);
							TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
						}

						buttons |= IN_ATTACK;
						SetState(jockey, 0, IN_ATTACK);
					}
					else 
					{
						if(angles[2] == 0.0) 
						{
							angles[0] = GetRandomFloat(-10.0, 0.0);
							TeleportEntity(jockey, NULL_VECTOR, angles, NULL_VECTOR);
						}

						buttons |= IN_JUMP;
						switch(GetRandomInt(0, 2)) 
						{
							case 0:
								buttons |= IN_DUCK;
							case 1:
								buttons |= IN_ATTACK2;
						}
						SetState(jockey, 0, IN_JUMP);
					}
				}
				else
				{
					float clientEyeAngles[3];
					GetClientEyeAngles(jockey, clientEyeAngles);
					//buttons |= IN_DUCK;
					buttons |= IN_JUMP;
					SetState(jockey, 0, IN_JUMP);
					if(buttons & IN_FORWARD)
					{
						Client_Push(jockey, clientEyeAngles, JockeyBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
					}
				
					if(buttons & IN_BACK)
					{
						clientEyeAngles[1] += 180.0;
						Client_Push(jockey, clientEyeAngles, JockeyBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
					}
					
					if(buttons & IN_MOVELEFT) 
					{
						clientEyeAngles[1] += 90.0;
						Client_Push(jockey, clientEyeAngles, JockeyBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
					}
						
					if(buttons & IN_MOVERIGHT) 
					{
						clientEyeAngles[1] += -90.0;
						Client_Push(jockey, clientEyeAngles, JockeyBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
					}
				}
			}

			if(GetEntityMoveType(jockey) & MOVETYPE_LADDER) 
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
	}

	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																	DEACTIVATING HOP DURING SHOVES

***********************************************************************************************************************************************************************************/
// Disable hopping when shoved
public void Jockey_OnShoved(int botJockey) 
{
	DelayStart(botJockey, 0);
}

/***********************************************************************************************************************************************************************************

																		JOCKEY STUMBLE

***********************************************************************************************************************************************************************************/

public void OnJockeyRide(Event event, const char[] name, bool dontBroadcast) 
{	
	if(IsCoop()) 
	{
		int attacker = GetClientOfUserId(event.GetInt("userid"));  
		int victim = GetClientOfUserId(event.GetInt("victim"));  
		if(attacker > 0 && victim > 0) 
			StumbleBystanders(victim, attacker);
	}	
}

bool IsCoop() 
{
	static char sGameMode[16];
	sGameMode[0] = 0;
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));
	return strcmp(sGameMode, "versus", false) != 0 && strcmp(sGameMode, "scavenge", false) != 0;
}

void StumbleBystanders(int pinnedSurvivor, int pinner) 
{
	static float pinnedSurvivorPos[3];
	static float pos[3];
	static float dir[3];
	GetClientAbsOrigin(pinnedSurvivor, pinnedSurvivorPos);
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
		{
			if(i != pinnedSurvivor && i != pinner && !IsPinned(i)) 
			{
				GetClientAbsOrigin(i, pos);
				SubtractVectors(pos, pinnedSurvivorPos, dir);
				if(GetVectorLength(dir) <= g_hJockeyStumbleRadius.FloatValue) 
				{
					NormalizeVector(dir, dir); 
					L4D_StaggerPlayer(i, pinnedSurvivor, dir);
				}
			}
		} 
	}
}

stock float modulus(float a, float b) 
{
	while(a > b)
		a -= b;
	return a;
}