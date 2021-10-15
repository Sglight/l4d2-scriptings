#pragma semicolon 1

#define BOMMER_SCAN_DELAY 0.5
#define BoomerBoostForward 150.0 // Bhop
#define VomitBoostForward 200.0 // Bhop

ConVar g_hBoomerExposedTimeTolerance, g_hBoomerVomitDelay, g_hVomit_Range;

public void Boomer_OnModuleStart() 
{
	g_hBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");	
	g_hBoomerVomitDelay = FindConVar("boomer_vomit_delay");	
	g_hBoomerExposedTimeTolerance.SetFloat(10000.0);
	g_hBoomerVomitDelay.SetFloat(0.01);
	FindConVar("z_boomer_near_dist").SetInt(1);
	FindConVar("z_vomit_fatigue").SetInt(1500);

	g_hVomit_Range = FindConVar("z_vomit_range");
}

public void Boomer_OnModuleEnd() 
{
	g_hBoomerExposedTimeTolerance.RestoreDefault();
	g_hBoomerVomitDelay.RestoreDefault();
	FindConVar("z_boomer_near_dist").RestoreDefault();
	FindConVar("z_vomit_fatigue").RestoreDefault();
}

public Action Boomer_OnPlayerRunCmd(int boomer, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];

	float Velocity[3];
	GetEntPropVector(boomer, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));
	float dist = NearestSurvivorDistance(boomer);
	float clientEyeAngles[3];
	GetClientEyeAngles(boomer, clientEyeAngles);
	int flags = GetEntityFlags(boomer);
	if(flags & FL_ONGROUND)
	{
		if(LeftGroundMaxSpeed[boomer] != -1.0 && !ReadyAbility(boomer))
		{
			float CurVelVec[3];
			GetEntPropVector(boomer, Prop_Data, "m_vecAbsVelocity", CurVelVec);
			if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[boomer])
			{
				NormalizeVector(CurVelVec, CurVelVec);
				ScaleVector(CurVelVec, LeftGroundMaxSpeed[boomer]);
				TeleportEntity(boomer, NULL_VECTOR, NULL_VECTOR, CurVelVec);
			}
			LeftGroundMaxSpeed[boomer] = -1.0;
		}
	}
	else if(LeftGroundMaxSpeed[boomer] == -1.0)
		LeftGroundMaxSpeed[boomer] = GetEntPropFloat(boomer, Prop_Data, "m_flMaxspeed");

	if(buttons & IN_ATTACK)
	{
		if((flags & FL_ONGROUND) && (dist < g_hVomit_Range.FloatValue + 300.0))
		{
			if(dist > g_hVomit_Range.FloatValue - 100.0)
			{
				//buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				if(buttons & IN_FORWARD)
				{
					Client_Push(boomer, clientEyeAngles, VomitBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
				
				if(buttons & IN_BACK)
				{
					clientEyeAngles[1] += 180.0;
					Client_Push(boomer, clientEyeAngles, VomitBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
						
				if(buttons & IN_MOVELEFT) 
				{
					clientEyeAngles[1] += 90.0;
					Client_Push(boomer, clientEyeAngles, VomitBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
						
				if(buttons & IN_MOVERIGHT) 
				{
					clientEyeAngles[1] += -90.0;
					Client_Push(boomer, clientEyeAngles, VomitBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
			}
		}
		return Plugin_Changed;
	}
	else if(0.8 * g_hVomit_Range.FloatValue < dist < 1000.0 && currentspeed > 160.0) 
	{
		if(flags & FL_ONGROUND)
		{
			//buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			if(buttons & IN_FORWARD)
			{
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
			/*	
			if(buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVELEFT) 
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVERIGHT) 
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(boomer, clientEyeAngles, BoomerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}*/
		}

		if(GetEntityMoveType(boomer) & MOVETYPE_LADDER) 
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}

	return Plugin_Continue;
}

void Boomer_OnVomit(int boomer) 
{
	int aimTarget = GetClientAimTarget(boomer, true);
	if(!IsSurvivor(aimTarget)) 
	{
		int newTarget;
		float newDist;

		static float vPos[3];
		int targets[MAXPLAYERS + 1];
		static int numClients;
		numClients = 0;
		static int i;

		GetClientEyePosition(boomer, vPos);
		numClients = GetClientsInRange(vPos, RangeType_Visibility, targets, MAXPLAYERS);

		if(numClients != 0)
		{
			static ArrayList aTargets;
			aTargets = new ArrayList(2);
			static float vTarg[3];
			static float dist;
			static int index;
			static int victim;
	
			for(i = 0; i < numClients; i++)
			{
				victim = targets[i];
				if(victim && victim != aimTarget && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
				{
					GetClientAbsOrigin(victim, vTarg);
					dist = GetVectorDistance(vPos, vTarg);
					index = aTargets.Push(dist);
					aTargets.Set(index, victim, 1);
				}
			}

			if(aTargets.Length != 0)
			{
				SortADTArray(aTargets, Sort_Ascending, Sort_Float);
				newDist = aTargets.Get(0, 0);
				newTarget = aTargets.Get(0, 1);
			}
			delete aTargets;
		}

		if(newTarget && newDist <= g_hVomit_Range.FloatValue) 
			aimTarget = newTarget;
	
		VomitPrediction(boomer, aimTarget);
	}
}

void VomitPrediction(int boomer, int survivor) 
{
	if(!IsBotBoomer(boomer) || !IsSurvivor(survivor)) 
		return;

	float survivorPos[3];
	float boomerPos[3];
	float attackDirection[3];
	float attackAngle[3];

	GetClientAbsOrigin(boomer, boomerPos);
	GetClientAbsOrigin(survivor, survivorPos);
	MakeVectorFromPoints(boomerPos, survivorPos, attackDirection);
	GetVectorAngles(attackDirection, attackAngle);	
	TeleportEntity(boomer, NULL_VECTOR, attackAngle, NULL_VECTOR); 
}

public void Boomer_OnShoved(int botBoomer) 
{
	ResetInfectedAbility(botBoomer, 0.1);
}