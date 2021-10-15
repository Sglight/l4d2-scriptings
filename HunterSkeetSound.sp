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

public int OnSkeet(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetMelee(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetGL(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetSniper(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetMeleeHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

public int OnSkeetSniperHurt(int survivor, int hunter)
{
	PlaySkeetSoundToClient(survivor);
}

stock void PlaySkeetSoundToClient(int client) {
	if ( !IsClientAndInGame(client) ) return;
	EmitSoundToClient(client, "ui/bigreward.wav");
}

stock bool IsClientAndInGame(int index) {
	return ( index > 1 && index <= MaxClients && IsClientInGame(index) );
}
