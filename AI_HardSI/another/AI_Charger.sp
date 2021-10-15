#pragma semicolon 1

#define ChargerBoostForward 120.0 // Bhop

ConVar g_hChargeProximity, g_hAimOffsetSensitivityCharger, g_hHealthThresholdCharger; 
int g_bShouldCharge[MAXPLAYERS + 1];

public void Charger_OnModuleStart() 
{
	// Charge proximity
	g_hChargeProximity = CreateConVar("ai_charge_proximity", "300", "How close a charger will approach before charging");	
	// Aim offset sensitivity
	g_hAimOffsetSensitivityCharger = CreateConVar("ai_aim_offset_sensitivity_charger",
									"20",
									"If the charger has a target, it will not straight pounce if the target's aim on the horizontal axis is within this radius",
									FCVAR_NONE,
									true, 0.0, true, 179.0);
	// Health threshold
	g_hHealthThresholdCharger = CreateConVar("ai_health_threshold_charger", "400", "Charger will charge if its health drops to this level");	
}

public void Charger_OnModuleEnd() 
{

}

/***********************************************************************************************************************************************************************************

																KEEP CHARGE ON COOLDOWN UNTIL WITHIN PROXIMITY

***********************************************************************************************************************************************************************************/

// Initialise spawned chargers
public Action Charger_OnSpawn(int charger) 
{
	g_bShouldCharge[charger] = false;
}

public Action Charger_OnPlayerRunCmd(int charger, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	static float LeftGroundMaxSpeed[MAXPLAYERS + 1];
	
	int flags = GetEntityFlags(charger);
	if(flags & FL_ONGROUND)
	{
		
	}
	else if(LeftGroundMaxSpeed[charger] == -1.0)
		LeftGroundMaxSpeed[charger] = GetEntPropFloat(charger, Prop_Data, "m_flMaxspeed");

	int target = GetClientAimTarget(charger, true);
	float dist = NearestSurvivorDistance(charger);
	if((buttons & IN_ATTACK2) && dist < 100.0 && ReadyAbility(charger))
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		if(IsSurvivor(target) && IsVisibleTo(charger, target) && !IsIncapacitated(target) && !IsPinned(target))
		{
			buttons |= IN_ATTACK;
			return Plugin_Changed;
		}
	}

	float Velocity[3];
	GetEntPropVector(charger, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

	if(buttons & IN_ATTACK)
	{
		vel[0] = 0.0;
		vel[1] = 0.0;
		vel[2] = 0.0;
	}
	else if(GetEntProp(charger, Prop_Send, "m_hasVisibleThreats") && g_hChargeProximity.IntValue + 10.0 < dist < 1000.0 && currentspeed > 175.0) 
	{
		if(flags & FL_ONGROUND)
		{
			float clientEyeAngles[3];
			GetClientEyeAngles(charger, clientEyeAngles);
			//buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			if(buttons & IN_FORWARD)
			{
				Client_Push(charger, clientEyeAngles, ChargerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
				
			if(buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(charger, clientEyeAngles, ChargerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVELEFT) 
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(charger, clientEyeAngles, ChargerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVERIGHT) 
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(charger, clientEyeAngles, ChargerBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
		}

		if(GetEntityMoveType(charger) & MOVETYPE_LADDER) 
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	else if(g_hChargeProximity.IntValue - 10.0 < dist < g_hChargeProximity.IntValue + 100.0 && currentspeed > 260.0)
	{
		if(flags & FL_ONGROUND)
		{
			if(LeftGroundMaxSpeed[charger] != -1.0)
			{
				float CurVelVec[3];
				GetEntPropVector(charger, Prop_Data, "m_vecAbsVelocity", CurVelVec);
				if(GetVectorLength(CurVelVec) > LeftGroundMaxSpeed[charger])
				{
					NormalizeVector(CurVelVec, CurVelVec);
					ScaleVector(CurVelVec, LeftGroundMaxSpeed[charger]);
					TeleportEntity(charger, NULL_VECTOR, NULL_VECTOR, CurVelVec);
				}
				LeftGroundMaxSpeed[charger] = -1.0;
			}
		}
	}

	float chargerPos[3];
	GetClientAbsOrigin(charger, chargerPos);
	int iSurvivorProximity = GetSurvivorProximity(chargerPos, target);
	//float iSurvivorProximity = ChargerNearestVisibleDistance(charger);
	int chargerHealth = GetEntProp(charger, Prop_Send, "m_iHealth");
	if(chargerHealth > g_hHealthThresholdCharger.IntValue && iSurvivorProximity > g_hChargeProximity.IntValue) 
	{	
		if(!g_bShouldCharge[charger]) 
		{ 				
			BlockCharge(charger);
			return Plugin_Changed;
		} 			
	} 
	else 
		g_bShouldCharge[charger] = true;

	return Plugin_Continue;
}

void BlockCharge(int charger) 
{
	int chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if(chargeEntity > 0)
		SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1);	
}

void Charger_OnCharge(int charger) 
{
	int aimTarget = GetClientAimTarget(charger, true);
	if(!IsSurvivor(aimTarget) || IsIncapacitated(aimTarget) || IsPinned(aimTarget) || IsTargetWatchingAttacker(charger, g_hAimOffsetSensitivityCharger.IntValue)) 
	{
		int newTarget;
		float newDist;

		static float vPos[3];
		int targets[MAXPLAYERS + 1];
		static int numClients;
		numClients = 0;
		static int i;

		GetClientEyePosition(charger, vPos);
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
				if(victim && victim != aimTarget && GetClientTeam(victim) == 2 && IsPlayerAlive(victim) && !IsIncapacitated(victim) && !IsPinned(victim))
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
		if(newTarget && newDist <= g_hChargeProximity.IntValue)
			aimTarget = newTarget;

		ChargePrediction(charger, aimTarget);
	}
}

void ChargePrediction(int charger, int survivor) 
{
	if(!IsBotCharger(charger) || !IsSurvivor(survivor)) 
		return;

	float survivorPos[3];
	float chargerPos[3];
	float attackDirection[3];
	float attackAngle[3];

	GetClientAbsOrigin(charger, chargerPos);
	GetClientAbsOrigin(survivor, survivorPos);
	MakeVectorFromPoints(chargerPos, survivorPos, attackDirection);
	GetVectorAngles(attackDirection, attackAngle);	
	TeleportEntity(charger, NULL_VECTOR, attackAngle, NULL_VECTOR); 
}

stock float ChargerNearestVisibleDistance(int client)
{
	static float vPos[3];
	int targets[MAXPLAYERS + 1];
	static int numClients;
	numClients = 0;
	static int i;
	
	GetClientEyePosition(client, vPos);
	
	numClients = GetClientsInRange(vPos, RangeType_Visibility, targets, MAXPLAYERS);

	if(numClients == 0)
		return -1.0;

	float[] dists = new float[MaxClients];
	static int counts;
	counts = 0;
	static float vTarg[3];
	float dist;
	int victim;
	
	for(i = 0; i < numClients; i++)
	{
		victim = targets[i];
		if(victim && GetClientTeam(victim) == 2 && IsPlayerAlive(victim))
		{
			GetClientAbsOrigin(victim, vTarg);
			dist = GetVectorDistance(vPos, vTarg);
			dists[counts++] = dist;
		}
	}

	SortFloats(dists, counts, Sort_Ascending);
	return dists[0];
}