#pragma semicolon 1

#define BoostForwardBoomer 90.0

Handle hCvarBoomerExposedTimeTolerance;
Handle hCvarBoomerVomitDelay;
Handle sdkVomitSurvivor;
Handle hAllowBhop;

bool bCanVomit[MAXPLAYERS];

public void Boomer_OnModuleStart() {
	hCvarBoomerExposedTimeTolerance = FindConVar("boomer_exposed_time_tolerance");	
	hCvarBoomerVomitDelay = FindConVar("boomer_vomit_delay");
	hAllowBhop = CreateConVar("ai_boomer_bhop", "1", "Flag to enable bhop facsimile on AI Boomers");

	SetConVarFloat(hCvarBoomerExposedTimeTolerance, 10000.0);
	SetConVarFloat(hCvarBoomerVomitDelay, 0.1);
	
	Handle g_hGameConf = LoadGameConfigFile("left4dhooks.l4d2");
	if(g_hGameConf == INVALID_HANDLE)
	{
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer::OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkVomitSurvivor = EndPrepSDKCall();
	if(sdkVomitSurvivor == INVALID_HANDLE)
	{
		SetFailState("Unable to find the \"CTerrorPlayer::OnVomitedUpon\" signature, check the file version!");
	}
}

public void Boomer_OnModuleEnd() {
	ResetConVar(hCvarBoomerExposedTimeTolerance);
	ResetConVar(hCvarBoomerVomitDelay);
}

public Action Boomer_OnPlayerRunCmd( int boomer, int& buttons, float vel[3], float angles[3] ) {
	int flags = GetEntityFlags(boomer);
	float vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));
	bool bBoomerBhop = GetConVarBool(hAllowBhop);
	
	// Get Angle of Boomer
	float clientEyeAngles[3];
	GetClientEyeAngles(boomer,clientEyeAngles);
	
	// LOS and survivor proximity
	float boomerPos[3];
	GetClientAbsOrigin(boomer, boomerPos);
	int targetSurvivor = GetClosestSurvivor( boomerPos );
	int iSurvivorsProximity = GetSurvivorProximity(boomerPos, targetSurvivor);
	bool bHasSight = view_as<bool>( GetEntProp(boomer, Prop_Send, "m_hasVisibleThreats") ); //Line of sight to survivors
	
	float targetPos[3];
	GetClientAbsOrigin(targetSurvivor, targetPos);
	float straightVector[3];
	straightVector[0] = targetPos[0] - boomerPos[0];
	straightVector[1] = targetPos[1] - boomerPos[1];
	straightVector[2] = targetPos[2] - boomerPos[2];

	// Near survivors 开始喷吐
	if( flags & FL_ONGROUND && bHasSight && iSurvivorsProximity <= vomit_range && bCanVomit[boomer] ) {
		buttons |= IN_FORWARD;
		buttons |= IN_ATTACK;
	}
	
	if (bBoomerBhop) {
		if( bHasSight && (iSurvivorsProximity > vomit_range - 100)) { // Random number to make bhop?
			buttons &= ~IN_ATTACK;
			buttons |= IN_FORWARD;
			//buttons &= ~IN_BACK;
			//buttons &= ~IN_MOVELEFT;
			//buttons &= ~IN_MOVERIGHT;
			if (flags & FL_ONGROUND) {
				buttons |= IN_JUMP;
				TeleportEntity(boomer, NULL_VECTOR, NULL_VECTOR, straightVector);
				Client_Push( boomer, clientEyeAngles, BoostForwardBoomer);
				// if(buttons & IN_FORWARD) {
				// 	Client_Push( boomer, clientEyeAngles, BoostForwardBoomer, view_as<VelocityOverride>( {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				// }
				
				// if(buttons & IN_BACK) {
				// 	clientEyeAngles[1] += 180.0;
				// 	Client_Push( boomer, clientEyeAngles, BoostForwardBoomer, view_as<VelocityOverride>( {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				// }
				
				// if(buttons & IN_MOVELEFT) {
				// 	clientEyeAngles[1] += 90.0;
				// 	Client_Push( boomer, clientEyeAngles, BoostForwardBoomer, view_as<VelocityOverride>( {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				// }
				
				// if(buttons & IN_MOVERIGHT) {
				// 	clientEyeAngles[1] += -90.0;
				// 	Client_Push( boomer, clientEyeAngles, BoostForwardBoomer, view_as<VelocityOverride>( {VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				// }
			}
			//Block Jumping and Crouching when on ladder
			else if (GetEntityMoveType(boomer) & MOVETYPE_LADDER) {
				buttons &= ~IN_JUMP;
			}
			else buttons |= IN_FORWARD;
		}
	}

	// 强行被吐
	if (buttons & IN_ATTACK && bCanVomit[boomer]) {
		if (!IsPlayerAlive(boomer) || !bCanVomit[boomer]) return Plugin_Handled;

		bCanVomit[boomer] = false;
		float vomit_interval = GetConVarFloat(FindConVar("z_vomit_interval"));
		float self_pos[3], target_pos[3];
		GetClientAbsOrigin(boomer, self_pos);
		for (int target = 1; target <= MaxClients; ++target) {
			if (IsSurvivor(target) && IsPlayerAlive(target) && isVisibleTo(boomer, target)) {
				float dist;
				GetClientAbsOrigin(target, target_pos);
				dist = GetVectorDistance(self_pos, target_pos);
				if (dist <= vomit_range)
				{
					VomitPlayer(target, boomer);
				}
			}
		}

		CreateTimer( vomit_interval, Timer_VomitCooldown, boomer, TIMER_FLAG_NO_MAPCHANGE) ;
	}
	return Plugin_Changed;
}

// public Action Timer_VomitPlayers(Handle timer, int boomer)
// {
// 	if (!IsPlayerAlive(boomer) || !bCanVomit[boomer]) return;

// 	float vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));

// 	bCanVomit[boomer] = false;
// 	float vomit_interval = GetConVarFloat(FindConVar("z_vomit_interval"));
// 	float self_pos[3], target_pos[3];
// 	GetClientAbsOrigin(boomer, self_pos);
// 	for (int target = 1; target <= MaxClients; ++target) {
// 		if (IsSurvivor(target) && IsPlayerAlive(target) && isVisibleTo(boomer, target)) {
// 			float dist;
// 			GetClientAbsOrigin(target, target_pos);
// 			dist = GetVectorDistance(self_pos, target_pos);
// 			if (dist <= vomit_range)
// 			{
// 				VomitPlayer(target, boomer);
// 			}
// 		}
// 	}
	
// 	CreateTimer( vomit_interval, Timer_VomitCooldown, boomer, TIMER_FLAG_NO_MAPCHANGE) ;
// }

public void VomitPlayer(int target, int boomer)
{
	if (IsSurvivor(target) && IsPlayerAlive(target) )
		SDKCall(sdkVomitSurvivor, target, boomer, true);
}

// Disable vomits on spawned boomers
public Action Boomer_OnSpawn(int botBoomer) {
	bCanVomit[botBoomer] = false;
	CreateTimer( 1.0, Timer_VomitCooldown, botBoomer, TIMER_FLAG_NO_MAPCHANGE) ;
	return Plugin_Handled;
}

// Disable voimits when shoved
public void Boomer_OnShoved(int botBoomer) {
	bCanVomit[botBoomer] = false;
	CreateTimer( 1.5, Timer_VomitCooldown, botBoomer, TIMER_FLAG_NO_MAPCHANGE) ;
}

public Action Timer_VomitCooldown(Handle timer, int boomer) {
	bCanVomit[boomer] = true;
	return Plugin_Continue;
}

/*public Action:Timer_BoomerAngle( Handle: timer, any:boomer )
{
	new new_target = -1;
	float vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));
	float self_pos[3], Float:target_pos[3];
	
	GetClientAbsOrigin(boomer, self_pos);
	for (new i = 1; i <= MaxClients; ++i) {
		if (IsSurvivor(i) && IsPlayerAlive(i) && isVisibleTo(boomer, i)) {
			float dist;
			GetClientAbsOrigin(i, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist <= vomit_range)
			{
				new_target = i;
				if (new_target > 0) {
					float aim_angles[3];
					computeAimAngles(boomer, new_target, aim_angles, AimTarget_Eye);
					aim_angles[2] = 0.0;
					TeleportEntity(boomer, NULL_VECTOR, aim_angles, NULL_VECTOR);
				}
			}
		}
	}
}*/
