#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

float pos1[MAXPLAYERS][3];
float pos2[MAXPLAYERS][3];
bool bride[MAXPLAYERS];

// 被猴子套，一秒内移动距离超过一定值时，将猴子和生还者瞬移到前一秒的位置
// shabi bug，不知道什么原因导致的，非常怀疑是 The Last Stand 更新后传送机制的 bug，因为是用的游戏自带的传送机制，其他插件应该不太可能会出现这个问题。
// !fuck jockey，建议加入此指令。
// 对策插件也是无奈之举，如果有人能发现是什么原因并修复就可以把这个插件给删了。
// 至于为什么不用插件版的传送，主要还是难度问题。


public void OnPluginStart()
{
    HookEvent("jockey_ride", Event_JockeyRide, EventHookMode_PostNoCopy);
    HookEvent("jockey_ride_end", Event_JockeyRideEnd, EventHookMode_PostNoCopy);
}

public Action Event_JockeyRide(Handle event, const char[] name, bool dontBroadcast)
{
    int jockey = GetClientOfUserId(GetEventInt(event, "userid"));
    int victim = GetClientOfUserId(GetEventInt(event, "victim"));

    if ( !isClientValid(jockey) || !isClientValid(victim) ) return;

    bride[victim] = true;
    // PrintToChatAll("jockey_ride, %d ride %d", jockey, victim);

    GetClientAbsOrigin(victim, pos1[victim]);
    // PrintToChatAll("victim origin position: %f, %f, %f", pos1[victim][0], pos1[victim][1], pos1[victim][2]);

    CreateTimer(1.0, Timer_CheckPos, victim, TIMER_REPEAT);
}

public Action Timer_CheckPos(Handle timer, int victim)
{
    if (!isClientValid(victim)) return Plugin_Stop;
    if ( !bride[victim] ) return Plugin_Stop;

    GetClientAbsOrigin(victim, pos2[victim]);
    // PrintToChatAll("victim second position: %f, %f, %f", pos2[victim][0], pos2[victim][1], pos2[victim][2]);
    float distance = GetVectorDistance(pos1[victim], pos2[victim], false);
    if (distance > 500.0) {
        // Normal distance on ground is 200, consider about gravity and other factors, add it to 500;
        // PrintToChatAll("%N has been ridden away, distance: %f", victim, distance);
        TeleportEntity(victim, pos1[victim], NULL_VECTOR, NULL_VECTOR);
    } else {
        // PrintToChatAll("normal condition, distance: %f", distance);
        pos1[victim] = pos2[victim];
    }
    return Plugin_Continue;
}

public Action Event_JockeyRideEnd(Handle event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "victim"));
    bride[victim] = false;
    // PrintToChatAll("jockey ride end.");
}

bool isClientValid(int client)
{ 	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	return true;
}