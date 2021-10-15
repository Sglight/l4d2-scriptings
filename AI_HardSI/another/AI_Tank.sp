#pragma semicolon 1

#define TankBoostForward 80.0 // Bhop

ConVar g_hTankBhop, g_hTank_Throw_Force, g_hTank_Attack_Range;

// Bibliography: 
// TGMaster, Chanz - Infinite Jumping

public void Tank_OnModuleStart()
{
	g_hTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
	FindConVar("tank_ground_pound_duration").SetFloat(0.1);
	g_hTank_Throw_Force = FindConVar("z_tank_throw_force");
	g_hTank_Throw_Force.SetInt(1200);
	//FindConVar("tank_throw_min_interval").SetInt(3);
	FindConVar("tank_throw_max_loft_angle").SetInt(90);
	g_hTank_Attack_Range = FindConVar("tank_attack_range");
}

public void Tank_OnModuleEnd() 
{
	FindConVar("tank_ground_pound_duration").RestoreDefault();
	g_hTank_Throw_Force.RestoreDefault();
	//FindConVar("tank_throw_min_interval").RestoreDefault();
	FindConVar("tank_throw_max_loft_angle").RestoreDefault();
}

#define TANK_MELEE_SCAN_DELAY 0.25
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25
// Tank bhop and blocking rock throw
public Action Tank_OnPlayerRunCmd(int tank, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];

	int flags = GetEntityFlags(tank);
	if(flags & FL_ONGROUND)
	{
		
	}
	else if(LeftGroundMaxSpeed[tank] == -1.0)
		LeftGroundMaxSpeed[tank] = GetEntPropFloat(tank, Prop_Data, "m_flMaxspeed");

	if(g_hTankBhop.BoolValue) 
	{
		float Velocity[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", Velocity);
		float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

		float dist = NearestSurvivorDistance(tank);
		if(buttons & IN_ATTACK)
		{
			if(flags & FL_ONGROUND)
			{
				if(LeftGroundMaxSpeed[tank] != -1.0 && dist < g_hTank_Attack_Range.FloatValue + 100.0 && currentspeed > 250.0)
				{
					float CurVelVec[3];
					GetEntPropVector(tank, Prop_Data, "m_vecAbsVelocity", CurVelVec);
					if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[tank])
					{
						NormalizeVector(CurVelVec, CurVelVec);
						ScaleVector(CurVelVec, LeftGroundMaxSpeed[tank]);
						TeleportEntity(tank, NULL_VECTOR, NULL_VECTOR, CurVelVec);
					}
					LeftGroundMaxSpeed[tank] = -1.0;
				}
			}
		}
		else if(GetEntProp(tank, Prop_Send, "m_hasVisibleThreats") && g_hTank_Attack_Range.FloatValue + 45.0 < dist < 676.0 && currentspeed > 190.0) 
		{
			if(flags & FL_ONGROUND) 
			{
				float clientEyeAngles[3];
				GetClientEyeAngles(tank, clientEyeAngles);
				buttons &= ~IN_ATTACK2;
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				if(buttons & IN_FORWARD)
				{
					Client_Push(tank, clientEyeAngles, TankBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
				
				if(buttons & IN_BACK)
				{
					clientEyeAngles[1] += 180.0;
					Client_Push(tank, clientEyeAngles, TankBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
						
				if(buttons & IN_MOVELEFT) 
				{
					clientEyeAngles[1] += 90.0;
					Client_Push(tank, clientEyeAngles, TankBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
						
				if(buttons & IN_MOVERIGHT) 
				{
					clientEyeAngles[1] += -90.0;
					Client_Push(tank, clientEyeAngles, TankBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
				}
			}

			if(GetEntityMoveType(tank) & MOVETYPE_LADDER) 
			{
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
		else if(dist < g_hTank_Attack_Range.FloatValue + 100.0 && currentspeed > 250.0)
		{
			if(flags & FL_ONGROUND)
			{
				if(LeftGroundMaxSpeed[tank] != -1.0)
				{
					float CurVelVec[3];
					GetEntPropVector(tank, Prop_Data, "m_vecAbsVelocity", CurVelVec);
					if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[tank])
					{
						NormalizeVector(CurVelVec, CurVelVec);
						ScaleVector(CurVelVec, LeftGroundMaxSpeed[tank]);
						TeleportEntity(tank, NULL_VECTOR, NULL_VECTOR, CurVelVec);
					}
					LeftGroundMaxSpeed[tank] = -1.0;
				}
			}
		}
	}

	if(buttons & IN_ATTACK2)
	{
		g_hTank_Throw_Force.SetInt(1200);
		DelayStart(tank, 1);
		DelayStart(tank, 2);
	}

	if(DelayExpired(tank, 1, TANK_ROCK_AIM_DELAY) && !DelayExpired(tank, 2, TANK_ROCK_AIM_TIME))
	{
		int target = GetClientAimTarget(tank, true);
		if(target > 0 && IsOldVisibleTo(tank, target))
		{
		
		}
		else 
		{
			int newTarget = NearestVisibleSurvivor(tank);
			if(newTarget > 0) 
			{
				if(angles[2] == 0.0) 
				{
					float aim_angles[3];
					ComputeAimAngles(tank, newTarget, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(tank, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}

	if(GetEntityMoveType(tank) != MOVETYPE_LADDER && (GetEntityFlags(tank) & FL_ONGROUND))
	{
		if(DelayExpired(tank, 0, TANK_MELEE_SCAN_DELAY)) 
		{
			DelayStart(tank, 0);
			if(NearestActiveSurvivorDistance(tank) < g_hTank_Attack_Range.FloatValue * 0.95) 
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;	
}

public Action L4D2_OnSelectTankAttack(int tank, int &sequence) 
{
	if(IsFakeClient(tank) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}