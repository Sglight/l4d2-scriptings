#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define NULL_VELOCITY view_as<float>({0.0, 0.0, 0.0})

Handle hMaxSurvivors = INVALID_HANDLE;
Handle hMaxInfected = INVALID_HANDLE;

bool gameStarted;

int clientTimeout[MAXPLAYERS + 1] = 0; // 加载超时时间
int countDown; // 倒计时
bool isClientLoading[MAXPLAYERS + 1] = false;
bool isCountDownEnd = false;

//bool surClient[MAXPLAYERS + 1];


public Plugin myinfo =
{
	name 			= "Jointeam",
	author 			= "海洋空氣",
	description 	= "加入生还者 + 等待玩家读图加载 + 出门发药 + 过关重置生还状态 + 自杀",
	version 		= "1.3",
	url 			= "https://steamcommunity.com/id/larkspur2017/"
}

public void OnPluginStart()
{
	hMaxSurvivors = CreateConVar("ast_maxsurvivors", "4");
	hMaxInfected = CreateConVar("ast_maxinfected", "0");

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
	RegConsoleCmd("sm_suicide", Suicide_Cmd);
	RegConsoleCmd("sm_zs", Suicide_Cmd);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("mission_lost", Event_MissionLost);
	HookEvent("round_end", Event_MissionLost);
	HookEvent("map_transition", Event_MapTransition);

	LoadTranslations("smac.phrases");
}

public void OnMapStart()
{
	/****** Doorlock ******/
	gameStarted = false;
	countDown = -1;
	isCountDownEnd = false;
	GodMode(true);

	for (int i = 1; i <= MaxClients; ++i)
	{
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	PrecacheSound("npc/virgil/c3end52.wav");
	PrecacheSound("npc/virgil/beep_error01.wav");
	PrecacheSound("player/survivor/voice/coach/worldc2m2b06.wav");

	CreateTimer(1.0, LoadingTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT); // 开始无限循环判断是否全部加载完毕
}

public void OnClientPutInServer(int client)
{
	if ( !isClientValid(client) || gameStarted) return;

	/****** Doorlock ******/
	if ( isCountDownStoppedOrRunning() ) {
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}

	// 假装有 SMAC
	CreateTimer(10.0, Timer_WelcomeMsg, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
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
		ReturnPlayerToSaferoom(client, true);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		PrintHintTextToAll("等待其他玩家加载中...");
		return Plugin_Handled;
	}
	if (!isCountDownEnd)
	{
		ReturnPlayerToSaferoom(client, true);
		EmitSoundToClient(client, "ui/beep_error01.wav");
		return Plugin_Handled;
	}
	gameStarted = true;
	GodMode(false);

	/****** JoinTeam ******/
	SetConVarInt(FindConVar("director_no_survivor_bots"), 1);
	KickBots();

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
	int survivorCount = getHumanSurvivors();
	int maxSurvivor = GetConVarInt(hMaxSurvivors);
	if (client < 1 || IsFakeClient(client) || survivorCount >= maxSurvivor) return Plugin_Handled;
	if (gameStarted) {
		PrintHintText(client, "玩家已出安全区域，暂时无法加入游戏。");
		return Plugin_Handled;
	}
	while (getTotalSurvivors() < maxSurvivor) // 生还者人数（包含 BOT） < 4 时，生成 Bot 填满生还者队伍
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
	if (!gameStarted && action == MenuAction_Select) {
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
		FakeClientCommand(client, "jointeam %d", TEAM_INFECTED);
		return;
	}
	else if (team == TEAM_SURVIVORS && gameStarted && getHumanSurvivors() == 1)
	{
		PrintToChat(client, "\x04[AstMod] \x03请结束回合再旁观.");
		return;
	}
	ChangeClientTeam(client, 1);
	PrintToChatAll("\x04[AstMod] \x03%N \x01已旁观.", client);
	return;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	GodMode(true);
	gameStarted = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (isClientValid(i) && GetClientTeam(i) == TEAM_SPECTATORS)
		{
			FakeClientCommand(i, "jointeam %d", TEAM_INFECTED);
		}
	}
}

public void L4D_OnEnterGhostState(int client)
{
	if ( GetConVarInt(hMaxInfected) > 0 ) return;
	if ( isClientValid(client) ) {
		// CreateTimer(0.1, MoveToSpecTimer, client);
		ChangeClientTeam(client, TEAM_SPECTATORS);
	}
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	if (GetConVarInt(hMaxInfected) > 0)
		return Plugin_Continue;
	else return Plugin_Handled;
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

public Action Event_MissionLost(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarInt(FindConVar("director_no_survivor_bots"), 0);
}

public void GodMode(bool boolean)
{
	int flags = GetCommandFlags("god");
	SetCommandFlags("god", flags & ~FCVAR_NOTIFY);
	SetConVarInt(FindConVar("god"), boolean);
	SetCommandFlags("god", flags);
	SetConVarInt(FindConVar("sv_infinite_ammo"), boolean);
}

public void KickBots()
{
	for (int i = 1; i <= MaxClients; ++i) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsFakeClient(i)) {
			KickClient(i, "kick bots");
		}
	}
}

 int getTotalSurvivors() // total survivors, including bots
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

int getHumanSurvivors() // survivor players
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(isSurvivor(i))
			count++;
	}
	return count;
}

bool isClientValid(int client)
{ 	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

bool isSurvivor(int client)
{
	return isClientValid(client) && GetClientTeam(client) == TEAM_SURVIVORS;
}

bool SpawnFakeClientAndTeleport()
{
	if (gameStarted) return false;

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

public Action Timer_KickFakeBot(Handle timer, int fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/**
 * 这个插件是我参考了无数个插件做的。
 * 最早是因为现有的几个 doorlock 和 readyup 插件都不能满足我对准备状态的要求，所以参考其他插件写了一个。
 * 当时的要求有：准备状态玩家能动，门可以开，但是不能出门，需等待所有玩家进入服务器后才能出门，不用手动输入指令准备，准备状态无敌无限子弹，可以跳水，可以 return。
 * 后来干脆也把其他功能也都加上了，形成了这样一个大杂烩插件。
 * Jointeam 这部分功能包括加入和旁观指令，禁止生还在回合开始后加入生还，禁止加入特感，插件更新也基本是更新的这一部分，其他基本雷打不动。
 * 多次更新也导致了 Jointeam 部分代码冗余，也不知道是否有更好的办法添加生还者 AI。
 * 加入特感是最后加的功能，但是限制人数懒得写了，只是自己测试猴子瞬移到虚空的对策插件用的，有需要可以自行修改。
 * 个人关于玩家玩特感的想法，从最早的允许，到后来的禁止，再到现在认为可以让玩家玩 tank。
 * 限制特感人数的方法就是将允许加入特感的玩家的 indexId 给储存到数组里，然后在 L4D_OnEnterGhostState 遍历并判断。
 */

////////////////////////////////////////////////////
//                    Doorlock                    //
////////////////////////////////////////////////////

public Action Return_Cmd(int client, int args)
{
	if (client > 0 && !gameStarted && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		ReturnPlayerToSaferoom(client, true);
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
		char currentMap[64];
		GetCurrentMap( currentMap, sizeof(currentMap) );
		if ( StrContains(currentMap, "c2") == 0 || StrContains(currentMap, "dkr") == 0 ) {
			EmitSoundToAll("player/survivor/voice/coach/worldc2m2b06.wav");
		} else EmitSoundToAll("npc/virgil/c3end52.wav");
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("请等待：%d", 10 - countDown);
	}
	return Plugin_Continue;
}

public Action L4D_OnLedgeGrabbed(int client)
{
	if (client > 0 && !gameStarted && GetClientTeam(client) == TEAM_SURVIVORS) {
		L4D_ReviveSurvivor(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		L4D_ReviveSurvivor(client);
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
	}

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VELOCITY);
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
	ResetInventory(true);
}

public void giveStartingItem(const char strItemName[32])
{
    int startingItem;
    float clientOrigin[3];

    for (int client = 1; client <= MaxClients; client++)
	{
        if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2)
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
		if ( isClientValid(client) && GetClientTeam(client) == TEAM_SURVIVORS  && IsPlayerAlive(client)) {
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
			L4D_SetTempHealth(client, 0.0);
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
//                      SMAC                     //
///////////////////////////////////////////////////

public Action Timer_WelcomeMsg(Handle timer, any serial)
{
    int client = GetClientFromSerial(serial);

    if ( isClientValid(client) )
    {
        PrintToChat(client, "%t%t", "SMAC_Tag", "SMAC_WelcomeMsg");
    }

    return Plugin_Stop;
}