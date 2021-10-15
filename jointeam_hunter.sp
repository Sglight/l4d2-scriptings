#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

#define MAXSURVIVORS 4

bool gameStarted;

int clientTimeout[MAXPLAYERS] = 0; // 加载超时时间
int countDown; // 倒计时
bool isClientLoading[MAXPLAYERS] = false;
bool isCountDownEnd = false;

//bool surClient[MAXPLAYERS + 1];

//int playerSecondaryWeapon[MAXPLAYERS];


public Plugin myinfo =
{
	name 			= "Jointeam",
	author 			= "海洋空氣",
	description 	= "加入生还者 + 等待玩家读图加载 + 出门发药 + 过关重置生还状态 + 自杀",
	version 		= "1.1",
	url 			= "https://steamcommunity.com/id/larkspur2017/"
}

public void OnPluginStart()
{
	// RegConsoleCmd("sm_addbot", AddBot_Cmd, "Attempt to add and teleport a survivor bot");
	RegConsoleCmd("sm_join", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_joingame", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_jg", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_spectate", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_spec", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_s", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_away", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_kill", Suicide_Cmd);
	RegConsoleCmd("sm_die", Suicide_Cmd);
	RegConsoleCmd("sm_stuck", Suicide_Cmd);
	RegConsoleCmd("sm_suicide", Suicide_Cmd);
	RegonsoleCmd("sm_zs", Suicide_Cmd);

	HookEvent("round_start", Event_RoundStart);
	// HookEvent("mission_lost", Event_MissionLost);
	// HookEvent("round_end", Event_MissionLost);
	HookEvent("map_transition", Event_MapTransition);
	// HookEvent("player_bot_replace", Event_BotReplacedPlayer);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);

	HookConVarChange(FindConVar("z_hunter_limit"), ResetConvar);
}

public void OnMapStart()
{
	/****** Doorlock ******/
	gameStarted = false;
	countDown = -1;
	isCountDownEnd = false;
	SetConVarInt(FindConVar("god"),1);
	SetConVarInt(FindConVar("sv_infinite_ammo"),1);
	for (int i = 1; i <= MaxClients; ++i)
	{
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	PrecacheSound("npc/virgil/c3end52.wav");
	PrecacheSound("npc/virgil/beep_error01.wav");

	CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT); // 开始无限循环判断是否全部加载完毕
}

public void OnClientPutInServer(int client)
{
	if (!isClientValid(client) || gameStarted) return;

	/******  Doorlock ******/
	if (isCountDownStoppedOrRunning())
	{
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}
}

public void OnClientDisconnect(int client)
{
	/****** Doorlock ******/
	isClientLoading[client] = false;
	clientTimeout[client] = 0;
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	/******  Doorlock ******/
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
	gameStarted = true;
	SetConVarInt(FindConVar("god"),0);
	SetConVarInt(FindConVar("sv_infinite_ammo"),0);

	/****** JoinTeam ******/
	//SetConVarInt(FindConVar("director_no_survivor_bots"), 1);
	//KickBots();

	/****** StartingPills ******/
	ResetInventory(false);
	giveStartingItem("weapon_pain_pills");
	return Plugin_Continue;
}

////////////////////////////////////////////////////
//                    JoinTeam                    //
////////////////////////////////////////////////////

public Action JoinTeam_Cmd(int client, int args)
{
	int SurvivorCount = Survivors();
	if (!isClientValid(client) || SurvivorCount >= MAXSURVIVORS) return Plugin_Handled;

	while (TotalSurvivors() < MAXSURVIVORS) // 生还者人数（包含 BOT） < 4 时，生成 Bot 填满生还者队伍
	{
		SpawnFakeClientAndTeleport();
	}
	CreateTimer(0.7, MoveToSurTimer, client);
	return Plugin_Handled;
}

public Action Menu_SwitchCharacters(int client)
{
	// 创建面板
	Menu menu = CreateMenu(CharactersMenuHandler);
	SetMenuTitle(menu, "切换人物");
	SetMenuExitButton(menu, true);

	// 添加空闲AI到面板
	int j = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			char id[32];
			char BotName[32];
			char sMenuEntry[8];
			GetClientName(i, BotName, sizeof(BotName));
			GetClientAuthId(i, AuthId_Steam3, id, sizeof(id));
			if (StrEqual(id, "BOT")  && GetClientTeam(i) == TEAM_SURVIVORS)
			{
				GetClientName(i, BotName, sizeof(BotName));
				IntToString(j, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, BotName);
				j++;
			}
		}
	}
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int CharactersMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		char BotName[32];
		GetMenuItem(menu, param, BotName, sizeof(BotName), _,BotName, sizeof(BotName));
		ChangeClientTeam(client, 1);
		ClientCommand(client, "jointeam 2 %s", BotName);
	}
}

public Action Spectate_Cmd(int client, int args)
{
	if (!isClientValid(client)) return;
	int team = GetClientTeam(client);
	if (team == TEAM_SPECTATORS)
	{
		FakeClientCommand(client, "jointeam 3");
		return;
	}
	ChangeClientTeam(client, 1);
	PrintToChatAll("\x04[AstMod] \x03%N \x01已旁观.", client);
	return;
}


public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int newteam = GetEventInt(event, "team");
	bool disconnect = GetEventBool(event, "disconnect");

	if (disconnect) return;

	if (isClientValid(client))
	{
		if (newteam == TEAM_INFECTED)
		{
			CreateTimer(0.1, MoveToSpecTimer, client);
		}
	}
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarInt(FindConVar("god"),1);
	SetConVarInt(FindConVar("sv_infinite_ammo"),1);
	gameStarted = false;

	// for (int i = 1; i <= MaxClients; i++)
	// {
	// 	if (isClientValid(i) && GetClientTeam(i) == TEAM_SPECTATORS)
	// 	{
	// 		FakeClientCommand(i, "jointeam 3");
	// 	}
	// }


}

public void OnGameFrame() {
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_INFECTED) // 检查感染者
		{
			// if (gameStarted || getHumanSurvivors() > MAXSURVIVORS)
			// {
			CreateTimer(0.5, MoveToSpecTimer, i);
			// }
			// else
			// {
			// 	CreateTimer(1.0, MoveToSurTimer, i);
			// }
		}
	}
}

public Action MoveToSpecTimer(Handle timer, int client)
{
	if (!isClientValid(client)) return;
	ChangeClientTeam(client, TEAM_SPECTATORS);
}

public Action MoveToSurTimer(Handle timer, int client)
{
	if (!isClientValid(client)) return;
	if (GetClientTeam(client) == TEAM_SURVIVORS)
	{
		Menu_SwitchCharacters(client);
		return;
	}
	FakeClientCommand(client, "jointeam 2");
}

/* public Action Event_MissionLost(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
} */

/* public Action Event_BotReplacedPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	int ljbot = GetClientOfUserId(GetEventInt(event, "bot"));

	if(GetClientTeam(ljbot) == TEAM_SURVIVORS) {
		if(gameStarted) {
			if (!Survivors())
			{
				PrintToChatAll("\x04[AstMod] \x01检测到无玩家在生还者队伍中, 自动处死 AI.");
				ForcePlayerSuicide(ljbot);
			} else
			{
				KickClient(ljbot, "kick bots");
			}
		}
	}
} */

/* public Action SlayBot(Handle timer)
{
	for(int i = 1; i <= MaxClients; ++i)
	{
		if(isSurvivorPlayer(i))
		{
			if (!Survivors())
			{
				PrintToChatAll("\x04[SM] \x01检测到无玩家在生还者队伍中, 自动处死 AI.");
				ForcePlayerSuicide(i);
			}
			else
			{
				KickClient(i, "kick bots");
			}
		}
	}
} */

/* public void KickBots()
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i))
		{
			KickClient(i,"kick bots");
		}
	}
} */

 int TotalSurvivors() // total survivors, including bots
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS))
				count++;
		}
	}
	return count;
}

int Survivors() // survivor players
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(isSurvivorPlayer(i))
			count++;
	}
	return count;
}

bool isClientValid(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

bool isSurvivorPlayer(int client)
{
	return isClientValid(client) && GetClientTeam(client) == TEAM_SURVIVORS;
}

bool SpawnFakeClientAndTeleport()
{
	bool fakeclientKicked = false;

	// create fakeclient
	int fakeclient = CreateFakeClient("FakeClient");

	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS);

		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{
				// teleport client to the position of any active alive player
				/*for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && IsPlayerAlive(i) && i != fakeclient)
					{
						// get the position coordinates of any active alive player
						float teleportOrigin[3];
						GetClientAbsOrigin(i, teleportOrigin);
						TeleportEntity(fakeclient, teleportOrigin, NULL_VECTOR, NULL_VECTOR);
						break;
					}
				}*/

				for (int slot = 0; slot < 5; ++slot) {  // 清空所有
					DeleteInventoryItem(fakeclient, slot);
				}
				BypassAndExecuteCommand(fakeclient, "give", "pistol"); // 发手枪

				// kick the fake client to make the bot take over
				CreateTimer(0.3, Timer_KickFakeBot, fakeclient, TIMER_REPEAT);
				fakeclientKicked = true;
			}
		}
		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient");
	}
	return fakeclientKicked;
}

public Action Timer_KickFakeBot(Handle timer, any fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

////////////////////////////////////////////////////
//                    Doorlock                    //
////////////////////////////////////////////////////

public Action Return_Cmd(int client, int args)
{
	if (client > 0
			&& !gameStarted
			&& GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
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
		PrintHintTextToAll("Go!");
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
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (isClientLoading[i]) return true;
	}

	return false;
}

bool isFinishedLoading()
{
	for (int i = 1; i <= MaxClients; ++i)
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

bool isCountDownStoppedOrRunning()
{
	return countDown != 0;
}


//////////////////////////////////////////////////////////////////////////
//                    StartingPills + Survivor Reset                    //
//////////////////////////////////////////////////////////////////////////

public Action Event_MapTransition(Handle event, char[] name, bool dontBroadcast)
{
	ResetInventory(false);


}

public void giveStartingItem(const char strItemName[32])
{
    int startingItem;
    float clientOrigin[3];

    for (int client = 1; client <= MaxClients; client++)
	{
        if (IsClientInGame(client) && GetClientTeam(client) == 2)
		{
            startingItem = CreateEntityByName(strItemName);
            GetClientAbsOrigin(client, clientOrigin);
            TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
            DispatchSpawn(startingItem);
            EquipPlayerWeapon(client, startingItem);
        }
    }
}

public void ResetInventory(bool resetWeapon) {
	for (int client = 1; client <= MaxClients; ++client) {
		if ( IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client)) {
			// Reset survivor inventories so they only hold dual pistols
			if (resetWeapon) {
				for (int slot = 0; slot < 5; ++slot) {  // 清空所有
					DeleteInventoryItem(client, slot);
				}
				BypassAndExecuteCommand(client, "give", "pistol"); // 发手枪
			} else {
				for (int slot = 3; slot < 5; ++slot) {  // 清空医疗物品
					DeleteInventoryItem(client, slot);
				}
			}
			// 回血
			BypassAndExecuteCommand(client, "give", "health"); // 清除特殊状态
			SetEntityHealth(client, 100);
			SetEntityTempHealth(client, 0);
		}
	}
}

public void DeleteInventoryItem(int client, int slot) {
	int item = GetPlayerWeaponSlot(client, slot);
	if (item > 0) {
		RemovePlayerItem(client, item);
		RemoveEdict(item);
	}
}

public void SetEntityTempHealth(int client, int hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	float newOverheal = hp * 1.0; // prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal);
}

public void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

///////////////////////////////////////////////////
//                    Suicide                    //
///////////////////////////////////////////////////

public Action Suicide_Cmd(int client, int args)
{
	if(!client || !IsPlayerAlive(client))
		return Plugin_Handled;

	if(!gameStarted)
	{
		PrintToChat(client, "回合未开始！");
		return Plugin_Handled;
	}

	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

///////////////////////////////////////////////////
//                  ResetConvar                  //
///////////////////////////////////////////////////

public void ResetConvar(ConVar convar, const char[] oldvalue, const char[] newvalue)
{
	int iNewValue = StringToInt(newvalue, 10);
	if (iNewValue < 3)
	{
		char path[32];
		int hunterLimit = StringToInt(oldvalue, 10);
		Format(path, sizeof(path), "cmt/%dht.cfg", hunterLimit);
		ServerCommand("exec \"%s\"", path);
	}
}
