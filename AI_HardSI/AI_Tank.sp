#pragma semicolon 1

#define BoostForward 60.0

Handle hCvarTankBhop;
Handle hCvarTankRock;

// Bibliography: 
// TGMaster, Chanz - Infinite Jumping

public void Tank_OnModuleStart() {
	hCvarTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
	hCvarTankRock = CreateConVar("ai_tank_rock", "1", "Flag to enable rock throw on AI tanks");
}

public void Tank_OnModuleEnd() {
}

// Tank bhop and blocking rock throw
public Action Tank_OnPlayerRunCmd( int tank, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon ) {
	if (!GetConVarBool(hCvarTankRock)) {
		buttons &= ~IN_ATTACK2;
	}
	
	if (buttons & IN_ATTACK2) {
		delayStart(tank, 3);
		delayStart(tank, 4);
	}
	
	if (delayExpired(tank, 4, 0.25) && !delayExpired(tank, 3, 4.0)) {
		int target = GetClientAimTarget(tank, true);
		if (target > 0 && isVisibleTo(tank, target)) {
			// BOTが狙っているターゲットが見えている場合
		} else {
			// 見えて無い場合はタンクから見える範囲で一番近い生存者を検索
			int new_target = -1;
			float min_dist = 100000.0;
			float self_pos[3], target_pos[3];
			
			GetClientAbsOrigin(tank, self_pos);
			for (int i = 1; i <= MaxClients; ++i) {
				if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapacitated(i) && isVisibleTo(tank, i)) {
					float dist;
				
					GetClientAbsOrigin(i, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) {
						min_dist = dist;
						new_target = i;
					}
				}
			}
			if (new_target > 0) {
				// 新たなターゲットに照準を合わせる
				if (angles[2] == 0.0) {
					float aim_angles[3];
					computeAimAngles(tank, new_target, aim_angles, AimTarget_Chest);
					aim_angles[2] = 0.0;
					TeleportEntity(tank, NULL_VECTOR, aim_angles, NULL_VECTOR);
					return Plugin_Changed;
				}
			}
		}
	}
	
	if( view_as<bool>( GetConVarBool(hCvarTankBhop) ) ) {
		int flags = GetEntityFlags(tank);
		
		// Get the player velocity:
		float fVelocity[3];
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", fVelocity);
		float currentspeed = SquareRoot(Pow(fVelocity[0],2.0)+Pow(fVelocity[1],2.0));
		//PrintCenterTextAll("Tank Speed: %.1f", currentspeed);
		
		// Get Angle of Tank
		float clientEyeAngles[3];
		GetClientEyeAngles(tank,clientEyeAngles);
		
		// LOS and survivor proximity
		float tankPos[3];
		GetClientAbsOrigin(tank, tankPos);
		int iSurvivorsProximity = GetSurvivorProximity(tankPos);
		bool bHasSight = view_as<bool>( GetEntProp(tank, Prop_Send, "m_hasVisibleThreats") ); //Line of sight to survivors
		
		// Near survivors
		if( bHasSight && iSurvivorsProximity < 130 && currentspeed > 220.0 ) {
			buttons |= IN_FORWARD;
			buttons |= IN_JUMP;
			buttons |= IN_ATTACK;
		}
		
		if( bHasSight && (500 > iSurvivorsProximity > 170) && currentspeed > 220.0 ) { // Random number to make bhop?
			if (flags & FL_ONGROUND) {
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				if(buttons & IN_FORWARD) {
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}	
				
				if(buttons & IN_BACK) {
					clientEyeAngles[1] += 180.0;
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
				
				if(buttons & IN_MOVELEFT) {
					clientEyeAngles[1] += 90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
				
				if(buttons & IN_MOVERIGHT) {
					clientEyeAngles[1] += -90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
			}
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(tank) & MOVETYPE_LADDER) {
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}
		
		// Far away
		/*if( bHasSight && iSurvivorsProximity > 400 && currentspeed > 190.0) { // Random number to make bhop?
			buttons &= ~IN_ATTACK2;	// Block throwing rock
			if (flags & FL_ONGROUND) {
				buttons |= IN_DUCK;
				buttons |= IN_JUMP;
				
				if(buttons & IN_FORWARD) {
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}	
				
				if(buttons & IN_BACK) {
					clientEyeAngles[1] += 180.0;
					Client_Push( tank, clientEyeAngles, BoostForwardSlow, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
						
				if(buttons & IN_MOVELEFT) {
					clientEyeAngles[1] += 90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
						
				if(buttons & IN_MOVERIGHT) {
					clientEyeAngles[1] += -90.0;
					Client_Push( tank, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None} ) );
				}
			}
			//Block Jumping and Crouching when on ladder
			if (GetEntityMoveType(tank) & MOVETYPE_LADDER) {
				buttons &= ~IN_JUMP;
				buttons &= ~IN_DUCK;
			}
		}*/
	}
	return Plugin_Continue;	
}

public Action L4D2_OnSelectTankAttack(int client, int& sequence) {
	if (IsFakeClient(client) && sequence == 50) {
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Changed;
}
/*
stock CTerrorPlayer_WarpToValidPositionIfStuck(client)
{
	static Handle:WarpToValidPositionSDKCall = INVALID_HANDLE;
	if (WarpToValidPositionSDKCall == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, WARPTOVALIDPOSITION_SIG, 0))
		{
			return;
		}

		WarpToValidPositionSDKCall = EndPrepSDKCall();
		if (WarpToValidPositionSDKCall == INVALID_HANDLE)
		{
			return;
		}
	}

	SDKCall(WarpToValidPositionSDKCall, client, 0);
}*/