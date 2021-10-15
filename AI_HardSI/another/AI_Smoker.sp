#pragma semicolon 1

#define SMOKER_TONGUE_DELAY 1.0

ConVar g_hTongueDelay, g_hSmokerHealth, g_hChokeDamageInterrupt, g_hTongueRange;

public void Smoker_OnModuleStart() 
{
	// Smoker health
	g_hSmokerHealth = FindConVar("z_gas_health");
	g_hSmokerHealth.AddChangeHook(OnSmokerHealthChanged); 
    
	// Damage required to kill a smoker that is pulling someone
	g_hChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
	g_hChokeDamageInterrupt.SetInt(g_hSmokerHealth.IntValue); // default 50
	g_hChokeDamageInterrupt.AddChangeHook(OnTongueCvarChange);    
	// Delay before smoker shoots its tongue
	g_hTongueDelay = FindConVar("smoker_tongue_delay"); 
	g_hTongueDelay.SetFloat(SMOKER_TONGUE_DELAY); // default 1.5
	g_hTongueDelay.AddChangeHook(OnTongueCvarChange);
	g_hTongueRange = FindConVar("tongue_range");
}

public void Smoker_OnModuleEnd() 
{
	g_hChokeDamageInterrupt.RestoreDefault();
	g_hTongueDelay.RestoreDefault();
}

// Game tries to reset these cvars
public void OnTongueCvarChange(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_hTongueDelay.SetFloat(SMOKER_TONGUE_DELAY);	
	g_hChokeDamageInterrupt.SetInt(g_hSmokerHealth.IntValue);
}

// Update choke damage interrupt to match smoker max health
public void OnSmokerHealthChanged(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_hChokeDamageInterrupt.SetInt(g_hSmokerHealth.IntValue);
}

#define SMOKER_ATTACK_SCAN_DELAY     0.5
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE	   300.0
stock Action Smoker_OnPlayerRunCmd(int smoker, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(buttons & IN_ATTACK) 
	{
		// botのトリガーはそのまま処理する
	} 
	else if(DelayExpired(smoker, 0, SMOKER_ATTACK_SCAN_DELAY) && GetEntityMoveType(smoker) != MOVETYPE_LADDER)
	{
		DelayStart(smoker, 0);
		/* 他のSIが攻撃しているかターゲットからAIMを受けている場合に
		   舌が届く距離にターゲットがいたら即攻撃する */

		// botがターゲットしている生存者を取得
		int target = GetClientAimTarget(smoker, true);
		if(IsSurvivor(target) && IsVisibleTo(smoker, target)) 
		{
			// 生存者で見えてたら
			static float target_pos[3];
			static float self_pos[3];
			static float dist;

			GetClientAbsOrigin(smoker, self_pos);
			GetClientAbsOrigin(target, target_pos);
			// ターゲットとの距離を計算
			dist = GetVectorDistance(self_pos, target_pos);
			if(dist < SMOKER_MELEE_RANGE) 
			{
				// ターゲットと近すぎる場合もうダメなので即攻撃する
				buttons |= IN_ATTACK|IN_ATTACK2; // 舌がないことがあるので殴りも入れる
				return Plugin_Changed;
			} 
			else if(dist < g_hTongueRange.FloatValue) 
			{
				// 舌が届く範囲にターゲットがいる場合
				if(GetGameTime() - getSIAttackTime() < SMOKER_ATTACK_TOGETHER_LIMIT) 
				{
					// 最近SIが攻撃してたらチャンスっぽいので即攻撃する
					buttons |= IN_ATTACK;
					return Plugin_Changed;
				} 
				else 
				{
					int target_aim = GetClientAimTarget(target, true);
					if(target_aim == smoker) 
					{
						// ターゲットがこっちにAIMを向けてたら即攻撃する
						buttons |= IN_ATTACK;
						return Plugin_Changed;
					}
				}
				// 他はbotに任せる
			}
		}
	}

	return Plugin_Continue;
}