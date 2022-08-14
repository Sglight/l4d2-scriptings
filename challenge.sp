#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <sdkhooks>
#include <l4d2_skill_detect>
#include <left4dhooks>
#include <colors>

#define MENU_DISPLAY_TIME		15

#define TEAM_SPECTATORS         1
#define TEAM_SURVIVORS          2
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

char SI_Names[][] =
{
	"Unknown",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
	"Not SI"
};

int tempTankDmg;
int tempSITimer;
int tempTankBhop;
int tempTankRock;
int tempPlayerInfected;
int tempPlayerTank;
int tempM2HunterFlag;
int tempMorePills;
int tempKillMapPills;

bool bIsPouncing[MAXPLAYERS + 1];		  // if a hunter player is currently pouncing
bool bIsUsingAbility[MAXPLAYERS + 1];
float fDmgPrint = 0.0;

Handle hRehealth = INVALID_HANDLE;
Handle hSITimer = INVALID_HANDLE;
Handle g_hVote = INVALID_HANDLE;

Handle hDmgModifyEnable = INVALID_HANDLE;
Handle hDmgThreshold = INVALID_HANDLE;
Handle hRatioDamage = INVALID_HANDLE;
Handle hFastGetup = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Amethyst Challenge",
	author = "海洋空氣",
	description = "Difficulty Controller for Amethyst Mod.",
	version = "2.1",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_tz", challengeRequest, "打开难度控制系统菜单");
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Post);
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Post);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("tongue_release", OnTongueRelease);
	HookEvent("tongue_broke_bent", OnTongueRelease);
	HookEvent("tongue_pull_stopped", OnTonguePullStopped);

	// 牛起身无敌修复
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);

	hRehealth = CreateConVar("ast_rehealth",       "0", "击杀特感回血开关");
	hSITimer = CreateConVar("ast_sitimer",       "1", "特感刷新速率");
	hDmgModifyEnable = CreateConVar("ast_dmgmodify", "1", "伤害修改总开关");
	hDmgThreshold = CreateConVar("ast_dma_dmg", "12.0", "被控扣血数值");
	hRatioDamage = CreateConVar("ast_ratio_damage", "0", "按比例扣血开关");
	hFastGetup = CreateConVar("ast_fast_getup", "1", "快速起身开关");

	RegConsoleCmd("sm_laser", laserCommand, "激光瞄准器开关");
}

public Action challengeRequest(int client, int args)
{
	if (client) {
		drawPanel(client);
	}
	return Plugin_Handled;
}

public Action drawPanel(int client)
{
	// 创建面板
	char buffer[64];
	Menu menu = CreateMenu(MenuHandler);
	SetMenuTitle(menu, "难度控制 Difficulty Controller");
	SetMenuExitButton(menu, true);

	// 1  0
	if (GetConVarBool(hRatioDamage))
		Format(buffer, sizeof(buffer), "按特感血量扣血 [已启用]");
	else Format(buffer, sizeof(buffer), "按特感血量扣血");
	AddMenuItem(menu, "hp", buffer);

	// 2  1
	Format(buffer, sizeof(buffer), "修改 Tank 伤害 [%i]", GetConVarInt(FindConVar("vs_tank_damage")));
	AddMenuItem(menu, "td", buffer);

	// 3  2
	AddMenuItem(menu, "st", "修改特感刷新速率");

	// 4  3
	Format(buffer, sizeof(buffer), "修改特感基础伤害 [%i]", GetConVarInt(hDmgThreshold));
	AddMenuItem(menu, "sd", buffer);

	// 5  4
	if (GetConVarBool(hRehealth))
		AddMenuItem(menu, "rh", "击杀特感回血 [已启用]");
	else AddMenuItem(menu, "rh", "击杀特感回血");

	// 6  5
	AddMenuItem(menu, "wc", "天气控制");

	// 7  6
	AddMenuItem(menu, "rs", "恢复默认设置");

	// 翻页
	// 1  7
	AddMenuItem(menu, "", "额外发药设定");

	// 2  8
	AddMenuItem(menu, "", "枪械参数设定（待定）");

	// 3  9
	AddMenuItem(menu, "", "Tank 设定");

	// 4  10
	AddMenuItem(menu, "", "推 Hunter 设定");

	// 5  11
	AddMenuItem(menu, "", "玩家特感设定");

	// 6  12
	AddMenuItem(menu, "", "激光瞄准器");

	// 7  13
	AddMenuItem(menu, "rs", "恢复默认设置");


	DisplayMenu(menu, client, MENU_DISPLAY_TIME);

	// 清除已选未投票状态
	ConVar hM2HunterWeapon = FindConVar("weapon_allow_m2_hunter");
	char sM2HunterWeapon[256];
	GetConVarString(hM2HunterWeapon, sM2HunterWeapon, sizeof(sM2HunterWeapon));

	char sWeaponSMG[64] = "weapon_smg,weapon_smg_silenced";
	char sWeaponSG[64] = "weapon_pumpshotgun,shotgun_chrome";
	char sWeaponSniper[64] = "weapon_sniper_scout";
	// 0 完全禁止，1 允许机枪，2 允许喷子，4 允许狙击
	tempM2HunterFlag = 0;
	if (StrContains(sM2HunterWeapon, sWeaponSMG) >= 0) {
		tempM2HunterFlag += 1;
	}
	if ((StrContains(sM2HunterWeapon, sWeaponSG) >= 0)) {
		tempM2HunterFlag += 2;
	}
	if ((StrContains(sM2HunterWeapon, sWeaponSniper) >= 0)) {
		tempM2HunterFlag += 4;
	}
	return Plugin_Handled;
}

public int MenuHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param) {
			case 0: {
				if (GetClientTeam(client) != TEAM_SURVIVORS) {
					PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
					return 1;
				}
				if (GetConVarBool(hRatioDamage)) {
					SetConVarBool(hRatioDamage, false);
				}
				else {
					SetConVarBool(hRatioDamage, true);
				}
				drawPanel(client);
			}
			case 1: {
				Menu_TankDmg(client, false);
			}
			case 2: {
				Menu_SITimer(client, false);
			}
			case 3: {
				if (GetDifficulty() == 1)
					Menu_SIDamage(client, false);
				else {
					PrintToChat(client, "\x04[SM] \x01当前模式不支持调整特感伤害.");
					drawPanel(client);
				}
			}
			case 4: {
				if (GetClientTeam(client) != TEAM_SURVIVORS) {
					PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
					return 1;
				}
				if (GetConVarBool(hRehealth)) {
					SetConVarBool(hRehealth, false);
					PrintToChatAll("\x04[SM] \x01有人关闭了击杀回血.");
				}
				else {
					SetConVarBool(hRehealth, true);
					PrintToChatAll("\x04[SM] \x01有人打开了击杀回血.");
				}
				drawPanel(client);
			} case 5: {
				FakeClientCommand(client, "sm_weather");
			}
			case 6: {
				if (GetClientTeam(client) != TEAM_SURVIVORS) {
					PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
					return 1;
				}
				ResetSettings();
				if (GetDifficulty() == 1)
					SIDamage(12.0);
				drawPanel(client);
			}
			case 7: {
				Menu_MorePills(client, false);
				drawPanel(client);
			}
			case 8: { // 枪械 / 待定
				PrintToChat(client, "此项待定");
				drawPanel(client);
			}
			case 9: { // Tank
				Menu_Tank(client, false);
			}
			case 10: { // 推 ht
				Menu_HunterM2(client, false);
			}
			case 11: { // 玩家特感
				Menu_PlayerInfected(client, false);
			}
			case 12: { // 激光
				// 开、关
				if (GetClientTeam(client) != TEAM_SURVIVORS) {
					PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
					return 1;
				}
				Menu_Laser(client, false);
			}
			case 13: {
				if (GetClientTeam(client) != TEAM_SURVIVORS) {
					PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
					return 1;
				}
				ResetSettings();
				if (GetDifficulty() == 1)
					SIDamage(12.0);
				drawPanel(client);
			}
		}
	}
	return 1;
}

public Action Menu_TankDmg(int client, int args)
{
	Handle menu = CreateMenu(Menu_TankDmgHandler);
	SetMenuTitle(menu, "修改 tank 伤害");
	SetMenuExitBackButton(menu, true);
	int tankdmg = GetConVarInt(FindConVar("vs_tank_damage"));
	switch (tankdmg)
	{
		case 24:{
			AddMenuItem(menu, "tf", "✔24");
			AddMenuItem(menu, "ts", "36");
			AddMenuItem(menu, "fe", "48");
			AddMenuItem(menu, "oh", "100");
		}
		case 36:{
			AddMenuItem(menu, "tf", "24");
			AddMenuItem(menu, "ts", "✔36");
			AddMenuItem(menu, "fe", "48");
			AddMenuItem(menu, "oh", "100");
		}
		case 48:{
			AddMenuItem(menu, "tf", "24");
			AddMenuItem(menu, "ts", "36");
			AddMenuItem(menu, "fe", "✔48");
			AddMenuItem(menu, "oh", "100");
		}
		case 100:{
			AddMenuItem(menu, "tf", "24");
			AddMenuItem(menu, "ts", "36");
			AddMenuItem(menu, "fe", "48");
			AddMenuItem(menu, "oh", "✔100");
		}
	}
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_TankDmgHandler(Handle vote, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param) {
			case 0: {
				TZ_CallVote(client, 1, 24);
			}
			case 1: {
				TZ_CallVote(client, 1, 36);
			}
			case 2: {
				TZ_CallVote(client, 1, 48);
			}
			case 3: {
				TZ_CallVote(client, 1, 100);
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public void TZ_CallVote(int client, int target, int value)
{
	if (GetClientTeam(client) != TEAM_SURVIVORS) {
		PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
		return;
	}

	if ( IsNewBuiltinVoteAllowed() ) {
		int iNumPlayers;
		int iPlayers[MAXPLAYERS];
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != TEAM_SURVIVORS)) {
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}

		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

		switch (target) {
			case 1: { // Tank 伤害
				Format(sBuffer, sizeof(sBuffer), "修改 Tank 伤害为 [%i]", value);
				tempTankDmg = value;
				SetBuiltinVoteResultCallback(g_hVote, TankDmgVoteResultHandler);
			}
			case 2: { // Tank 连跳
				value ? Format(sBuffer, sizeof(sBuffer), "开启 Tank 连跳") : Format(sBuffer, sizeof(sBuffer), "关闭 Tank 连跳");
				tempTankBhop = value;
				SetBuiltinVoteResultCallback(g_hVote, TankBhopVoteResultHandler);
			}
			case 3: { // Tank 石头
				value ? Format(sBuffer, sizeof(sBuffer), "开启 Tank 丢石头") : Format(sBuffer, sizeof(sBuffer), "关闭 Tank 丢石头");
				tempTankRock = value;
				SetBuiltinVoteResultCallback(g_hVote, TankRockVoteResultHandler);
			}
			case 4: { // 玩家特感
				if (value == 0) {
					Format(sBuffer, sizeof(sBuffer), "禁止玩家加入特感");
				} else {
					Format(sBuffer, sizeof(sBuffer), "允许 %d 名玩家加入特感", value);
				}
				tempPlayerInfected = value;
				SetBuiltinVoteResultCallback(g_hVote, PlayerInfectedVoteResultHandler);
			}
			case 5: { // 玩家 Tank
				value ? Format(sBuffer, sizeof(sBuffer), "禁止玩家扮演 Tank") : Format(sBuffer, sizeof(sBuffer), "允许玩家扮演 Tank");
				tempPlayerTank = value;
				SetBuiltinVoteResultCallback(g_hVote, PlayerTankVoteResultHandler);
			}
			case 6: { // 推 Hunter
				if (tempM2HunterFlag == 0) {
					Format(sBuffer, sizeof(sBuffer), "禁止所有武器推 Hunter");
				} else {
					Format(sBuffer, sizeof(sBuffer), "允许");
					if (tempM2HunterFlag & 1) {
						Format(sBuffer, sizeof(sBuffer), "%s 机枪", sBuffer);
					}
					if (tempM2HunterFlag & 2) {
						Format(sBuffer, sizeof(sBuffer), "%s 喷子", sBuffer);
					}
					if (tempM2HunterFlag & 4) {
						Format(sBuffer, sizeof(sBuffer), "%s 狙击", sBuffer);
					}
					Format(sBuffer, sizeof(sBuffer), "%s 推 Hunter", sBuffer);
				}
				SetBuiltinVoteResultCallback(g_hVote, M2HunterVoteResultHandler);
			}
			case 7: { // 额外发药
				value ? Format(sBuffer, sizeof(sBuffer), "开启额外发药") : Format(sBuffer, sizeof(sBuffer), "关闭额外发药");
				tempMorePills = value;
				SetBuiltinVoteResultCallback(g_hVote, MorePillsVoteResultHandler);
			}
			case 8: { // 删除地图药
				value ? Format(sBuffer, sizeof(sBuffer), "删除地图药（下回合生效）") : Format(sBuffer, sizeof(sBuffer), "保留地图药（下回合生效）");
				tempKillMapPills = value;
				SetBuiltinVoteResultCallback(g_hVote, KillMapPillsVoteResultHandler);
			}
		}

		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
		FakeClientCommand(client, "Vote Yes");
	}
}

public int TankDmgVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 伤害...");
				SetConVarInt(FindConVar("vs_tank_damage"), tempTankDmg);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int TankBhopVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 连跳...");
				SetConVarInt(FindConVar("ai_tank_bhop"), tempTankBhop);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int TankRockVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 丢石头...");
				SetConVarInt(FindConVar("ai_tank_rock"), tempTankRock);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int PlayerInfectedVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				Format(sBuffer, sizeof(sBuffer), "正在更改特感玩家数量为 %d ...", tempPlayerInfected);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_maxinfected"), tempPlayerInfected);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int PlayerTankVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempPlayerTank == 0 ? Format(sBuffer, sizeof(sBuffer), "禁止") : Format(sBuffer, sizeof(sBuffer), "允许");
				Format(sBuffer, sizeof(sBuffer), "%s玩家扮演 Tank", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_allowhumantank"), tempPlayerTank);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int M2HunterVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在修改推 Hunter 设定 ...");

				char sWeaponSMG[64] = "weapon_smg,weapon_smg_silenced";
				char sWeaponSG[64] = "weapon_pumpshotgun,shotgun_chrome";
				char sWeaponSniper[64] = "weapon_sniper_scout";
				char sBuffer[256];

				if (tempM2HunterFlag & 1) {
					Format(sBuffer, sizeof(sBuffer), "%s%s,", sBuffer, sWeaponSMG);
				}
				if (tempM2HunterFlag & 2) {
					Format(sBuffer, sizeof(sBuffer), "%s%s,", sBuffer, sWeaponSG);
				}
				if (tempM2HunterFlag & 4) {
					Format(sBuffer, sizeof(sBuffer), "%s%s,", sBuffer, sWeaponSniper);
				}

				SetConVarString(FindConVar("weapon_allow_m2_hunter"), sBuffer);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int MorePillsVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempMorePills == 0 ? Format(sBuffer, sizeof(sBuffer), "关闭") : Format(sBuffer, sizeof(sBuffer), "开启");
				Format(sBuffer, sizeof(sBuffer), "正在 %s 额外发药...", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				SetConVarInt(FindConVar("ast_pills_enabled"), tempMorePills);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int KillMapPillsVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				tempKillMapPills == 0 ? Format(sBuffer, sizeof(sBuffer), "保留") : Format(sBuffer, sizeof(sBuffer), "删除");
				Format(sBuffer, sizeof(sBuffer), "已设置为 %s 地图药", sBuffer);
				DisplayBuiltinVotePass(vote, sBuffer);
				// SetConVarInt(FindConVar("ast_pills_map_kill"), tempKillMapPills);
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public int VoteHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
			return 1;
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail( vote, view_as<BuiltinVoteFailReason>(param1) );
			return 0;
		}
	}
	return 0;
}

public Action Menu_SITimer(int client, int args)
{
	Handle menu = CreateMenu(Menu_SITimerHandler);
	SetMenuTitle(menu, "修改特感刷新速度");
	SetMenuExitBackButton(menu, true);
	int SITimer = GetConVarInt(hSITimer);
	switch (SITimer)
	{
		case 0: {
			AddMenuItem(menu, "", "✔较慢");
			AddMenuItem(menu, "", "默认");
			AddMenuItem(menu, "", "较快");
			AddMenuItem(menu, "", "特感速递？");
		}
		case 1: {
			AddMenuItem(menu, "", "较慢");
			AddMenuItem(menu, "", "✔默认");
			AddMenuItem(menu, "", "较快");
			AddMenuItem(menu, "", "特感速递？");
		}
		case 2: {
			AddMenuItem(menu, "", "较慢");
			AddMenuItem(menu, "", "默认");
			AddMenuItem(menu, "", "✔较快");
			AddMenuItem(menu, "", "特感速递？");
		}
		case 3: {
			AddMenuItem(menu, "", "较慢");
			AddMenuItem(menu, "", "默认");
			AddMenuItem(menu, "", "较快");
			AddMenuItem(menu, "", "✔特感速递？");
		}
	}
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SITimerHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		char buffer[64];
		switch (param)
		{
			case 0: {
				tempSITimer = 0;
				Format(buffer, sizeof(buffer),"较慢");
				TZ_CallVoteStr(client, 1, buffer);
			}
			case 1: {
				tempSITimer = 1;
				Format(buffer, sizeof(buffer),"默认");
				TZ_CallVoteStr(client, 1, buffer);
			}
			case 2: {
				tempSITimer = 2;
				Format(buffer, sizeof(buffer),"较快");
				TZ_CallVoteStr(client, 1, buffer);
			}
			case 3: {
				tempSITimer = 3;
				Format(buffer, sizeof(buffer),"特感速递？");
				TZ_CallVoteStr(client, 1, buffer);
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public void TZ_CallVoteStr(int client, int target, char[] param1)
{
	if (GetClientTeam(client) != TEAM_SURVIVORS) {
		PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
		return;
	}

	if ( IsNewBuiltinVoteAllowed() ) {
		int iNumPlayers;
		int iPlayers[MAXPLAYERS];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != TEAM_SURVIVORS))
			{
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}

		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		switch (target) {
			case 1: {
				Format(sBuffer, sizeof(sBuffer), "修改特感刷新速度为 [%s]", param1);
				SetBuiltinVoteResultCallback(g_hVote, SITimerVoteResultHandler);
			}
		}

		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
		FakeClientCommand(client, "Vote Yes");
	}
}

public int SITimerVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改特感刷新速率...");
				SetConVarInt(hSITimer, tempSITimer);
				ServerCommand("sm_reloadscript");
				return 1;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return 0;
}

public Action Menu_SIDamage(int client, int args)
{
	Handle menu = CreateMenu(Menu_SIDamageHandler);
	int dmg = GetConVarInt(hDmgThreshold);
	SetMenuTitle(menu, "修改特感基础伤害");
	SetMenuExitBackButton(menu, true);
	switch (dmg) {
		case 8: {
			AddMenuItem(menu, "", "✔8");
			AddMenuItem(menu, "", "12");
			AddMenuItem(menu, "", "24");
		}
		case 12: {
			AddMenuItem(menu, "", "8");
			AddMenuItem(menu, "", "✔12");
			AddMenuItem(menu, "", "24");
		}
		case 24: {
			AddMenuItem(menu, "", "8");
			AddMenuItem(menu, "", "12");
			AddMenuItem(menu, "", "✔24");
		}
	}
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SIDamageHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch(param) {
			case 0:
				SIDamage(8.0);
			case 1:
				SIDamage(12.0);
			case 2:
				SIDamage(24.0);
			default:
				SIDamage(12.0);
		}
		drawPanel(client);
	} else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public void ResetSettings()
{
	SetConVarInt(FindConVar("vs_tank_damage"), 24);
	SetConVarInt(FindConVar("ast_sitimer"), 1);
	SetConVarBool(hRehealth, false);
	ServerCommand("sm_reloadscript");
}

public Action Menu_MorePills(int client, int args)
{
	// 开关，删除地图药
	Handle menu = CreateMenu(Menu_MorePillsHandler);
	SetMenuTitle(menu, "额外发药设定");
	SetMenuExitBackButton(menu, true);

	char sBuffer[32];
	bool bPillsEnabled = GetConVarBool(FindConVar("ast_pills_enabled"));
	bPillsEnabled ? Format(sBuffer, sizeof(sBuffer), "✔自动发药") : Format(sBuffer, sizeof(sBuffer), "自动发药");
	AddMenuItem(menu, "", sBuffer);

	bool bPillsMapKill = GetConVarBool(FindConVar("ast_pills_map_kill"));
	bPillsMapKill ? Format(sBuffer, sizeof(sBuffer), "✔删除地图药") : Format(sBuffer, sizeof(sBuffer), "删除地图药");
	AddMenuItem(menu, "", sBuffer);

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_MorePillsHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				bool bPillsEnabled = GetConVarBool(FindConVar("ast_pills_enabled"));

				if (bPillsEnabled) {
					TZ_CallVote(client, 7, 0);
				} else {
					TZ_CallVote(client, 7, 1);
				}
			}
			case 1: {
				bool bPillsMapKill = GetConVarBool(FindConVar("ast_pills_map_kill"));
				if (bPillsMapKill) {
					TZ_CallVote(client, 8, 0);
				} else {
					TZ_CallVote(client, 8, 1);
				}
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public Action Menu_Tank(int client, int args)
{
	// 连跳，石头
	Handle menu = CreateMenu(Menu_TankHandler);
	SetMenuTitle(menu, "Tank 设定");
	SetMenuExitBackButton(menu, true);

	char sBuffer[32];
	bool bAITankBhop = GetConVarBool(FindConVar("ai_tank_bhop"));
	bAITankBhop ? Format(sBuffer, sizeof(sBuffer), "✔连跳") : Format(sBuffer, sizeof(sBuffer), "连跳");
	AddMenuItem(menu, "", sBuffer);

	bool bAITankRock = GetConVarBool(FindConVar("ai_tank_rock"));
	bAITankRock ? Format(sBuffer, sizeof(sBuffer), "✔石头") : Format(sBuffer, sizeof(sBuffer), "石头");
	AddMenuItem(menu, "", sBuffer);

	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_TankHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				bool bAITankBhop = GetConVarBool(FindConVar("ai_tank_bhop"));

				if (bAITankBhop) {
					TZ_CallVote(client, 2, 0);
					// SetConVarInt(hAITankBhop, 0);
				} else {
					TZ_CallVote(client, 2, 1);
					// SetConVarInt(hAITankBhop, 1);
				}
			}
			case 1: {
				bool bAITankRock = GetConVarBool(FindConVar("ai_tank_rock"));
				if (bAITankRock) {
					TZ_CallVote(client, 3, 0);
				} else {
					TZ_CallVote(client, 3, 1);
				}
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public Action Menu_HunterM2(int client, int args)
{
	// 完全禁，允许机枪推，允许喷子推，允许狙击推
	Handle menu = CreateMenu(Menu_HunterM2Handler);
	SetMenuTitle(menu, "推 Hunter 设定");
	SetMenuExitBackButton(menu, true);

	tempM2HunterFlag & 1 ?
		AddMenuItem(menu, "", "✔允许机枪推") : AddMenuItem(menu, "", "允许机枪推");
	tempM2HunterFlag & 2 ?
		AddMenuItem(menu, "", "✔允许喷子推") : AddMenuItem(menu, "", "允许喷子推");
	tempM2HunterFlag & 4 ?
		AddMenuItem(menu, "", "✔允许狙击推") : AddMenuItem(menu, "", "允许狙击推");

	AddMenuItem(menu, "", "发起投票");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_HunterM2Handler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				if (tempM2HunterFlag & 1) { // 当前允许机枪推
					tempM2HunterFlag -= 1;
				} else {
					tempM2HunterFlag += 1;
				}
			}
			case 1: {
				if (tempM2HunterFlag & 2) { // 当前允许喷子推
					tempM2HunterFlag -= 2;
				} else {
					tempM2HunterFlag += 2;
				}
			}
			case 2: {
				if (tempM2HunterFlag & 4) { // 当前允许狙击推
					tempM2HunterFlag -= 4;
				} else {
					tempM2HunterFlag += 4;
				}
			}
			case 3: {
				TZ_CallVote(client, 6, 0);
			}
		}
		Menu_HunterM2(client, false);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public Action Menu_PlayerInfected(int client, int args)
{
	Handle menu = CreateMenu(Menu_PlayerInfectedHandler);
	SetMenuTitle(menu, "玩家特感设定");
	SetMenuExitBackButton(menu, true);
	switch (GetConVarInt(FindConVar("ast_maxinfected"))) {
		case 0: {
			AddMenuItem(menu, "", "✔禁止玩家加入特感");
			AddMenuItem(menu, "", "允许 1 名玩家加入特感");
			AddMenuItem(menu, "", "允许 2 名玩家加入特感");
			AddMenuItem(menu, "", "允许 3 名玩家加入特感");
			AddMenuItem(menu, "", "允许 4 名玩家加入特感");
		}
		case 1: {
			AddMenuItem(menu, "", "禁止玩家加入特感");
			AddMenuItem(menu, "", "✔允许 1 名玩家加入特感");
			AddMenuItem(menu, "", "允许 2 名玩家加入特感");
			AddMenuItem(menu, "", "允许 3 名玩家加入特感");
			AddMenuItem(menu, "", "允许 4 名玩家加入特感");
		}
		case 2: {
			AddMenuItem(menu, "", "禁止玩家加入特感");
			AddMenuItem(menu, "", "允许 1 名玩家加入特感");
			AddMenuItem(menu, "", "✔允许 2 名玩家加入特感");
			AddMenuItem(menu, "", "允许 3 名玩家加入特感");
			AddMenuItem(menu, "", "允许 4 名玩家加入特感");
		}
		case 3: {
			AddMenuItem(menu, "", "禁止玩家加入特感");
			AddMenuItem(menu, "", "允许 1 名玩家加入特感");
			AddMenuItem(menu, "", "允许 2 名玩家加入特感");
			AddMenuItem(menu, "", "✔允许 3 名玩家加入特感");
			AddMenuItem(menu, "", "允许 4 名玩家加入特感");
		}
		case 4: {
			AddMenuItem(menu, "", "禁止玩家加入特感");
			AddMenuItem(menu, "", "允许 1 名玩家加入特感");
			AddMenuItem(menu, "", "允许 2 名玩家加入特感");
			AddMenuItem(menu, "", "允许 3 名玩家加入特感");
			AddMenuItem(menu, "", "✔允许 4 名玩家加入特感");
		}
	}
	switch (GetConVarInt(FindConVar("ast_allowhumantank"))) {
		case 0: {
			AddMenuItem(menu, "", "✔禁止玩家扮演 Tank");
			AddMenuItem(menu, "", "允许玩家扮演 Tank");
		}
		case 1: {
			AddMenuItem(menu, "", "禁止玩家扮演 Tank");
			AddMenuItem(menu, "", "✔允许玩家扮演 Tank");
		}
	}
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_PlayerInfectedHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		// switch (param)
		// {
		// 	case 0: {
		// 		TZ_CallVote(client, 4, 0);
		// 	}
		// 	case 1: {
		// 		TZ_CallVote(client, 4, 1);
		// 	}
		// 	case 2: {
		// 		TZ_CallVote(client, 4, 2);
		// 	}
		// 	case 3: {
		// 		TZ_CallVote(client, 4, 3);
		// 	}
		// 	case 4: {
		// 		TZ_CallVote(client, 4, 4);
		// 	}
		// 	case 5: {
		// 		TZ_CallVote(client, 5, 0);
		// 	}
		// 	case 6: {
		// 		TZ_CallVote(client, 5, 1);
		// 	}
		// }
		if (param >= 0 && param <= 4) {
			TZ_CallVote(client, 4, param);
		} else if (param >= 5 && param <= 6) {
			TZ_CallVote(client, 5, param - 5);
		}
		DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

public Action laserCommand(int client, int args) {
	if (!IsClientAndInGame(client) || GetClientTeam(client) != TEAM_SURVIVORS) return Plugin_Handled;
	ToggleLaser(client, true);
	return Plugin_Handled;
}

public void ToggleLaser(int client, bool on) {
	if (on){
		BypassAndExecuteCommand(client, "upgrade_add", "LASER_SIGHT");
	} else {
		BypassAndExecuteCommand(client, "upgrade_remove", "LASER_SIGHT");
	}
}

public Action Menu_Laser(int client, int args)
{
	Handle menu = CreateMenu(Menu_LaserHandler);
	SetMenuTitle(menu, "激光瞄准器");
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "", "为当前武器安装激光瞄准器");
	AddMenuItem(menu, "", "为当前武器卸载激光瞄准器");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_LaserHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				ToggleLaser(client, true);
			}
			case 1: {
				ToggleLaser(client, false);
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
	return 1;
}

///////////////////////////
//           Event           //
//////////////////////////

public void OnAbilityUse(Handle event, const char[] name, bool dontBroadcast)
{
	// track hunters pouncing
	int userId = GetEventInt(event, "userid");
	int user = GetClientOfUserId(userId);
	char abilityName[64];

	GetEventString(event,"ability",abilityName,sizeof(abilityName));

	if( IsClientAndInGame(user) )
	{
		if ( StrEqual(abilityName,"ability_lunge",false) && !bIsPouncing[user] ) {
			bIsPouncing[user] = true;
			CreateTimer(0.1, groundTouchTimer, user, TIMER_REPEAT);
		}
		if ( StrEqual(abilityName, "ability_tongue", false) && !bIsUsingAbility[user] ) {
			bIsUsingAbility[user] = true;
			CreateTimer(2.0, Timer_ResetTongue, user);
		}
	}
}

public Action groundTouchTimer(Handle timer, int client)
{
	if( IsClientAndInGame(client) && ( isGrounded(client) || !IsPlayerAlive(client) ) ) {
		// Reached the ground or died in mid-air
		bIsPouncing[client] = false;
		KillTimer(timer);
	}
	return Plugin_Continue;
}

public bool isGrounded(int client)
{
	return (GetEntProp(client,Prop_Data,"m_fFlags") & FL_ONGROUND) > 0;
}

public void OnPlayerShoved(Handle event, const char[] name, bool dontBroadcast)
{
	// get hunter player
	int victimId = GetEventInt(event, "userId");
	int victim = GetClientOfUserId(victimId);

	if(bIsPouncing[victim]) {
		bIsPouncing[victim] = false;
	}
}

public Action Timer_ResetTongue(Handle timer, int client)
{
	bIsUsingAbility[client] = false;
	return Plugin_Continue;
}

public Action OnTongueRelease(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(client) && GetZombieClass(client) == ZC_SMOKER)
		bIsUsingAbility[client] = false;
	return Plugin_Continue;
}

public Action OnTonguePullStopped(Handle event, const char[] name, bool dontBroadcast)
{
	int smoker = GetClientOfUserId(GetEventInt(event, "smoker"));
	if (isInfected(smoker) && GetZombieClass(smoker) == ZC_SMOKER)
		bIsUsingAbility[smoker] = false;
	return Plugin_Continue;
}

public void OnTongueCut(int survivor, int smoker)
{
	if ( GetConVarBool(hDmgModifyEnable) ) {
		ForcePlayerSuicide(smoker);

		char weapon[32];
		GetClientWeapon(survivor, weapon, sizeof(weapon));
		ReplaceString(weapon, sizeof(weapon), "weapon_", "", false);
		SendDeathMessage(survivor, smoker, weapon, true);
	}
}

void SendDeathMessage(int attacker, int victim, const char[] weapon, bool headshot)
{
    Event event = CreateEvent("player_death");
    if (event == null)
    {
        return;
    }

    event.SetInt("userid", GetClientUserId(victim));
    event.SetInt("attacker", GetClientUserId(attacker));
    event.SetString("weapon", weapon);
    event.SetBool("headshot", headshot);
    event.Fire();
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (GetConVarBool(hRehealth)) {
		bool headshot = GetEventBool(event, "headshot");
		char weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));

		if (attacker == 0 || victim == 0 || GetClientTeam(attacker) == TEAM_SPECTATORS) return Plugin_Handled;

		int zombie = GetZombieClass(victim);
		int HP = GetEntProp(attacker, Prop_Data, "m_iHealth");
		int tHP = GetClientHealth(attacker);
		int addHP = 0;
		switch (zombie) {
			case 1: {
				addHP++;
			} 		// Smoker
			case 2: {} 		// Boomer
			case 3: { 		// Hunter
				if (StrEqual(weapon, "pistol_magnum", false) ||
				StrEqual(weapon, "pistol", false) ||
				StrEqual(weapon, "smg",false) ||
				StrEqual(weapon, "smg_silenced", false) ) {
					addHP += 2;
				}
				else if (StrEqual(weapon, "pumpshotgun", false) ||
				StrEqual(weapon, "shotgun_chrome", false) ||
				StrEqual(weapon, "sniper_scout", false) ) {
					addHP++;
				}
				if (bIsPouncing[victim]) addHP++;
				bIsPouncing[victim] = false;
			}
			case 4: {}		// Spitter
			case 5: { 			// Jockey
				addHP++;
			}
			case 6: { 			// Charger
				addHP++;
			}
			case 7: {} 		// Witch
			case 8: {} 		// Tank
		} // switch
		// 额外加血，降低难度
		if (zombie > 0 && headshot) addHP++; // 爆头额外加血
		if (40 < HP < 70)
			addHP += 2;
		else if (HP > 20)
			addHP += 3;
		else if (HP <= 10 && tHP < 40)
			addHP += 7;
		SetEntProp(attacker, Prop_Data, "m_iHealth", HP + addHP);
		//PrintToChat(attacker, "击杀 %i, 获得 addHP 点血量.");

		if (HP + addHP > 100) // 血量上限 100
			SetEntProp(attacker, Prop_Data, "m_iHealth", 100);
	}

	if ( isInfected(victim) ) {
		bIsUsingAbility[victim] = false;
		SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	return Plugin_Continue;
}

// While a Charger is carrying a Survivor, undo any friendly fire done to them
// since they are effectively pinned and pinned survivors are normally immune to FF
public Action Event_ChargerCarryStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = true;
	return Plugin_Continue;
}

// End immunity about one second after the carry ends
// (there is some time between carryend and pummelbegin,
// but pummelbegin does not always get called if the charger died first, so it is unreliable
public Action Event_ChargerPummelStart(Handle event, const char[] name, bool dontBroadcast)
{
	int charger = GetClientOfUserId(GetEventInt(event, "userid"));
	bIsUsingAbility[charger] = false;
	return Plugin_Continue;
}

public void SIDamage(float damage)
{
	SetConVarFloat(hDmgThreshold, damage);
}

stock int GetZombieClass(int client) {
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool IsClientAndInGame(int index) {
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

public int GetDifficulty() {
	int difficulty = GetConVarInt(FindConVar("das_fakedifficulty"));
	return difficulty;
}

public void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

/**
 * 这个插件刚开始是设计了很多自定义选项，后来删减了很多，
 * 如果闲着无聊往前几个版本翻源码也会看到那些注释掉的代码。
 * 删减的原因也很简单，一是我自己看不出差别，二是功能很少人使用，占着个位置，导致其他选项需要翻页，是我不想看到的。
 * 原本的 Challenge 和 Damage Modifier 两个插件耦合度非常高，导致某次更新后出现插件顺序问题导致不能正常读取，所以后来也是整合了两个插件。
 * 回血的爆 ht 部分可以改成直接使用 Skill Detect 判断，跟砍舌处死一样的，不用额外写这一堆代码判断状态。
 */

///////////////////////////////////////////////////
//                Damage Modifier                //
///////////////////////////////////////////////////

// 插件重读的时候也重新 Hook
public void OnMapStart() {
	for (int i = 1; i < MaxClients; i++) {
		if (!IsValidEntity(i)) return;
		SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnClientPutInServer(int client)
{
	if ( client > 0 && client < MaxClients)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (client > 0 && client < MaxClients)
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if ( !GetConVarBool(hDmgModifyEnable) ) return Plugin_Continue;

	if ( !IsClientAndInGame(victim) || !IsClientAndInGame(attacker) ) return Plugin_Continue;

	if (GetClientTeam(victim) == TEAM_INFECTED && GetZombieClass(victim) == ZC_SMOKER && bIsUsingAbility[victim]) { // 秒舌头
		damage = 250.0;
		return Plugin_Changed;
	}
	if ( GetClientTeam(attacker) == TEAM_INFECTED &&
		( GetZombieClass(attacker) == ZC_SMOKER ||
		GetZombieClass(attacker) == ZC_HUNTER ||
		GetZombieClass(attacker) == ZC_JOCKEY ||
		GetZombieClass(attacker) == ZC_CHARGER ) ) { // 舌ht猴牛
		float fdamage = GetConVarFloat(hDmgThreshold);
		if ( GetConVarBool(hRatioDamage) ) { // 按特感比例扣血
			int iHP = GetEntProp(attacker, Prop_Data, "m_iHealth"); // 获取特感血量
			int iHPmax = GetEntProp(attacker, Prop_Data, "m_iMaxHealth"); // 获取特感满血血量
			float fiHP = float(iHP); // 转成浮点型
			float fiHPmax = float(iHPmax);
			float ratio = fiHP / fiHPmax;
			fdamage = GetConVarFloat(hDmgThreshold) * ratio;
			if (fdamage < 1.0) { // 避免无伤害不处死特感
				fdamage = 1.0;
			}
		}
		fDmgPrint = fdamage;
		damage = fdamage;

		if (GetZombieClass(attacker) == ZC_HUNTER && GetEntityMoveType(victim) & MOVETYPE_LADDER) { // 在梯子上被扑
			damage = 0.0;
		}

		if (GetZombieClass(attacker) == ZC_CHARGER && bIsUsingAbility[attacker]) { // 牛撞停不造成伤害，防止过早处死导致pummel end事件不触发，进而导致起身没有无敌。
			damage = 0.0;
		}
		return Plugin_Changed;
	}
	else return Plugin_Continue;
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if ( !GetConVarBool(hDmgModifyEnable) ) return Plugin_Handled;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientAndInGame(attacker) || !IsClientAndInGame(victim)) return Plugin_Handled;

	int damage = GetEventInt(event, "dmg_health");
	int zombie_class = GetZombieClass(attacker);

	if (GetClientTeam(attacker) == TEAM_INFECTED && GetClientTeam(victim) == TEAM_SURVIVORS && zombie_class != ZC_TANK && damage > 0)
	{
		int remaining_health = GetClientHealth(attacker);
		ForcePlayerSuicide(attacker);
		CPrintToChatAll("[{olive}AstMod{default}] {red}%N{default}({green}%s{default}) 还剩下 {olive}%d{default} 血! 造成了 {olive}%2.1f{default} 点伤害!", attacker, SI_Names[zombie_class], remaining_health, fDmgPrint);
		if ( GetConVarBool(hFastGetup) && (GetZombieClass(attacker) == ZC_HUNTER || GetZombieClass(attacker) == ZC_CHARGER) ) {
            _CancelGetup(victim);
        }
	}
	return Plugin_Continue;
}

stock bool isInfected(int client) {
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_INFECTED;
}

// Gets players out of pending animations, i.e. sets their current frame in the animation to 1000.
stock void _CancelGetup(int client) {
    CreateTimer(0.4, CancelGetup, client);
}

public Action CancelGetup(Handle timer, int client) {
    SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0); // Jumps to frame 1000 in the animation, effectively skipping it.
    return Plugin_Continue;
}