#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

public Plugin myinfo =
{
	name = "L4D2 Door Lock",
	author = "海洋空氣",
	description = "等待所有玩家读图完毕。",
	version = "1.1",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

int clientTimeout[MAXPLAYERS + 1] = 0; // 加载超时时间
int countDown; // 倒计时

bool isClientLoading[MAXPLAYERS + 1] = false;
bool isCountDownEnd = false;

public void OnPluginStart()
{
	HookEvent("round_start", DL_Event_RoundStart);
}

public void OnMapStart()
{
	countDown = -1;
	isCountDownEnd = false;
	for (int i = 0; i <= MaxClients; i++)
	{
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	
	PrecacheSound("npc/virgil/c3end52.wav");
	PrecacheSound("npc/virgil/beep_error01.wav");
	
	CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT); // 开始无限循环判断是否全部加载完毕
}

public void OnClientDisconnect(int client)
{
	isClientLoading[client] = false;
	clientTimeout[client] = 0;
}

public void OnClientPutInServer(int client)
{
	if (isClientValid(client) && isCountDownStoppedOrRunning())
	{
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}
}

public void DL_Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	ReturnTeamToSaferoom(2);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (!isFinishedLoading())
	{
		ReturnToSaferoom(client);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		PrintHintTextToAll("等待其他玩家加载中...");
		return Plugin_Handled;
	}
	if (!isCountDownEnd)
	{
		ReturnToSaferoom(client);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action LoadingTimer(Handle timer)
{
	if (isFinishedLoading())
	{
		countDown = 0;
		CreateTimer(1.0, StartTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
		return Plugin_Stop;
	}
	else
	{
		for (int i = 0; i <= MAXPLAYERS; i++)
		{
			if (clientTimeout[i] >= 90)
			{
				KickClient(i, "连接超时。");
				isClientLoading[i] = false;
				clientTimeout[i] = 0;
			}
		}
		countDown = -1;
	}
	return Plugin_Continue;
}

public Action StartTimer(Handle timer)
{
	if (countDown++ >= 10)
	{
		countDown = 0;
		PrintHintTextToAll("Go!", 10 - countDown);
		isCountDownEnd = true;
		EmitSoundToAll("npc/virgil/c3end52.wav");
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("请等待：%d", 10 - countDown);
	}
	return Plugin_Continue;
}

void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags;
	int give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

void ReturnTeamToSaferoom(int team)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	int give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

void ReturnToSaferoom(int client)
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	int give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	if (IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client, true);
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

bool isAnyClientLoading()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (isClientLoading[i]) return true;
	}

	return false;
}

bool isFinishedLoading()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (!IsClientInGame(i) && !IsFakeClient(i))
			{
				clientTimeout[i]++;
				if (isClientLoading[i])
				{
					if (clientTimeout[i] == 1)
					{
						isClientLoading[i] = true;
					}
				}
				
				if (clientTimeout[i] == 90)
				{
					isClientLoading[i] = false;
				}
			}
			else
			{
				isClientLoading[i] = false;
			}
		}
		
		else isClientLoading[i] = false;
	}
	
	return !isAnyClientLoading();
}

bool isClientValid(int client)
{ 	if (client <= 0) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

bool isCountDownStoppedOrRunning()
{
	return countDown != 0;
}
