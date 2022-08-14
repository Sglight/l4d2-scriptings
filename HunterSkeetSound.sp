#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_skill_detect>

/**
 * 装逼是游戏第一动力。
 * 受落子视频的启发，爆 ht 带嘟嘟音效，实际打起来也非常带感。
 * 这个也没什么好说的。
 */

public void OnMapStart()
{
	PrecacheSound("ui/bigreward.wav");
}

public void OnSkeet(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetMelee(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetGL(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetSniper(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetMeleeHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public void OnSkeetSniperHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

stock void PlaySkeetSoundToClient(int client) {
	if ( !IsClientAndInGame(client) ) return;
	EmitSoundToClient(client, "ui/bigreward.wav", client);
}

stock bool IsClientAndInGame(int index) {
	return ( index > 0 && index <= MaxClients + 1 && IsClientInGame(index) );
}
