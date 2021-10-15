#pragma semicolon 1
// #define SMOKER_TONGUE_DELAY 0.0 // 默认 1.0

// new Handle:hCvarTongueDelay;
// new Handle:hCvarSmokerHealth;
// new Handle:hCvarChokeDamageInterrupt;

// public Smoker_OnModuleStart() {
	 // // Smoker health
    // hCvarSmokerHealth = FindConVar("z_gas_health");
    // HookConVarChange(hCvarSmokerHealth, ConVarChanged:OnSmokerHealthChanged); 
    
    // // Damage required to kill a smoker that is pulling someone
    // hCvarChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
    // SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth)); // default 50
    // HookConVarChange(hCvarChokeDamageInterrupt, ConVarChanged:OnTongueCvarChange);   
	
    // // Delay before smoker shoots its tongue
    // hCvarTongueDelay = FindConVar("smoker_tongue_delay"); 
    // SetConVarFloat(hCvarTongueDelay, SMOKER_TONGUE_DELAY); // default 1.5
    // HookConVarChange(hCvarTongueDelay, ConVarChanged:OnTongueCvarChange);
// }

// public Smoker_OnModuleEnd() {
	// ResetConVar(hCvarChokeDamageInterrupt);
	// ResetConVar(hCvarTongueDelay);
// }

// // Game tries to reset these cvars
// public OnTongueCvarChange() {
	// SetConVarFloat(hCvarTongueDelay, SMOKER_TONGUE_DELAY);	
	// SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
// }

// // Update choke damage interrupt to match smoker max health
// public Action:OnSmokerHealthChanged() {
	// SetConVarInt(hCvarChokeDamageInterrupt, GetConVarInt(hCvarSmokerHealth));
// }

public Action Smoker_OnPlayerRunCmd( int smoker, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon ) {	
	float Pos[3];
	GetClientAbsOrigin(smoker, Pos);
	int iSurvivorsProximity = GetSurvivorProximity(Pos);
	//new bool:bHasSight = bool:GetEntProp(smoker, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
	
	// Get Angle of Smoker
	//decl Float:clientEyeAngles[3];
	//GetClientEyeAngles(smoker, clientEyeAngles);
	
	if (iSurvivorsProximity < 100) {
		buttons |= IN_ATTACK;
		buttons |= IN_ATTACK2;
	}
	return Plugin_Changed;
}