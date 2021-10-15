#pragma semicolon 1

#define SpitterBoostForward 100.0 // Bhop
#define SPITTER_SPIT_DELAY 1.0

public void Spitter_OnModuleStart() 
{

}

public void Spitter_OnModuleEnd() 
{

}

public Action Spitter_OnPlayerRunCmd(int spitter, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) 
{
	if(buttons & IN_ATTACK) 
	{
		if(DelayExpired(spitter, 0, SPITTER_SPIT_DELAY)) 
		{
			DelayStart(spitter, 0);
			buttons |= IN_JUMP;
			return Plugin_Changed;
		}
	}

	static float Velocity[3];
	GetEntPropVector(spitter, Prop_Data, "m_vecVelocity", Velocity);
	float currentspeed = SquareRoot(Pow(Velocity[0], 2.0) + Pow(Velocity[1], 2.0));

	float dist = NearestSurvivorDistance(spitter);
	if(dist < 1000.0 && currentspeed > 150.0) 
	{
		if(GetEntityFlags(spitter) & FL_ONGROUND)
		{
			static float clientEyeAngles[3];
			GetClientEyeAngles(spitter, clientEyeAngles);
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			if(buttons & IN_FORWARD)
			{
				Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
				
			if(buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVELEFT) 
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
						
			if(buttons & IN_MOVERIGHT) 
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(spitter, clientEyeAngles, SpitterBoostForward, view_as<VelocityOverride>({VelocityOvr_None, VelocityOvr_None, VelocityOvr_None}));
			}
		}

		if(GetEntityMoveType(spitter) & MOVETYPE_LADDER) 
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}

	return Plugin_Continue;
}
/*
public void Spitter_OnShoved(int botSpitter) 
{
	SetGodMode(botSpitter, 1.0);
}

void SetGodMode(int client, float duration)
{
	if(!IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1); // god mode
	
	if(duration > 0.0) 
		CreateTimer(duration, Timer_mortal, GetClientUserId(client));
}

public Action Timer_mortal(Handle timer, int client)
{
	client = GetClientOfUserId(client);

	if(!client || !IsClientInGame(client))
		return;

	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); // mortal
}*/