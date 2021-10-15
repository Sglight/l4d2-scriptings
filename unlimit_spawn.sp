#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Action L4D_OnIsTeamFull(int team, bool &full)
{
    if (team == 3) {
        PrintToChatAll("L4D_OnIsTeamFull, 3");
        full = false;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}