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
Handle hSharpenAllMelee = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Challenge Amethyst",
	author = "海洋空氣",
	description = "Difficulty Controller for Amethyst Mod.",
	version = "1.9",
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

	// 牛起身无敌修复
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_pummel_start", Event_ChargerPummelStart, EventHookMode_Post);

	hRehealth = CreateConVar("ast_rehealth",       "0", "击杀特感回血开关");
	hSITimer = CreateConVar("ast_sitimer",       "1", "特感刷新速率");

	hDmgModifyEnable = CreateConVar("ast_dmgmodify", "1", "伤害修改总开关");
	hDmgThreshold = CreateConVar("ast_dma_dmg", "12.0", "被控扣血数值");
	hRatioDamage = CreateConVar("ast_ratio_damage", "0", "按比例扣血开关");
	hFastGetup = CreateConVar("ast_fast_getup", "1", "快速起身开关");
	hSharpenAllMelee = CreateConVar("ast_sharpen_melee", "1", "所有近战都是锐器");
}

public Action challengeRequest(int client, int args)
{
	if (client) {
		drawPanel(client);
	}
}

public Action drawPanel(int client)
{
	// 创建面板
	char buffer[64];
	Menu menu = CreateMenu(MenuHandler);
	SetMenuTitle(menu, "难度控制 Difficulty Controller");
	SetMenuExitButton(menu, true);

	// 1
	if (GetConVarBool(hRatioDamage))
		Format(buffer, sizeof(buffer), "按特感血量扣血 [已启用]");
	else Format(buffer, sizeof(buffer), "按特感血量扣血");
	AddMenuItem(menu, "hp", buffer);

	// 2
	Format(buffer, sizeof(buffer), "修改 Tank 伤害 [%i]", GetConVarInt(FindConVar("vs_tank_damage")));
	AddMenuItem(menu, "td", buffer);

	// 3
	AddMenuItem(menu, "st", "修改特感刷新速率");

	// 4
	Format(buffer, sizeof(buffer), "修改特感基础伤害 [%i]", GetConVarInt(hDmgThreshold));
	AddMenuItem(menu, "sd", buffer);

	// 5
	if (GetConVarBool(hRehealth))
		AddMenuItem(menu, "rh", "击杀特感回血 [已启用]");
	else AddMenuItem(menu, "rh", "击杀特感回血");

	// 6
	AddMenuItem(menu, "wc", "天气控制");

	// 7
	AddMenuItem(menu, "rs", "恢复默认设置");

	// 翻页
	// 1
	AddMenuItem(menu, "", "猎头者");

	// 2
	AddMenuItem(menu, "", "枪械参数设定");

	// 3
	AddMenuItem(menu, "", "Tank 设定");

	// 4
	AddMenuItem(menu, "", "推 Hunter 设定");

	// 5
	AddMenuItem(menu, "", "玩家特感设定");

	// 6
	AddMenuItem(menu, "", "");

	// 7
	AddMenuItem(menu, "rs", "恢复默认设置");


	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
}

public int MenuHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		if (GetClientTeam(client) == TEAM_SURVIVORS) {
			switch (param) {
				case 0: {
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
				case 6:{
					ResetSettings();
					if (GetDifficulty() == 1)
						SIDamage(12.0);
					drawPanel(client);
				}
			}
		}
		else PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
	}
}

public Action Menu_TankDmg(int client, int args)
{
	Handle menu = CreateMenu(Menu_TankDmgHandler);
	int tankdmg = GetConVarInt(FindConVar("vs_tank_damage"));
	SetMenuTitle(menu, "修改 tank 伤害 [%d]", tankdmg);
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "tf", "24");
	AddMenuItem(menu, "ts", "36");
	AddMenuItem(menu, "fe", "48");
	AddMenuItem(menu, "oh", "100");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_TankDmgHandler(Handle vote, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				TZ_CallVote(client, 24);
			}
			case 1: {
				TZ_CallVote(client, 36);
			}
			case 2: {
				TZ_CallVote(client, 48);
			}
			case 3: {
				TZ_CallVote(client, 100);
			}
		}
		drawPanel(client);
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
}

public void TZ_CallVote(int client, int param1)
{
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
		Format(sBuffer, sizeof(sBuffer), "修改 Tank 伤害为 [%i]", param1);
		tempTankDmg = param1;

		g_hVote = CreateBuiltinVote(TankDmgHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, TankDmgVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
	}
}

public int TankDmgVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				DisplayBuiltinVotePass(vote, "正在更改 Tank 伤害...");
				SetConVarInt(FindConVar("vs_tank_damage"), tempTankDmg);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public int TankDmgHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail( vote, view_as<BuiltinVoteFailReason>(param1) );
		}
	}
}

public Action Menu_SITimer(int client, int args)
{
	Handle menu = CreateMenu(Menu_SITimerHandler);
	char buffer[16];
	int SITimer = GetConVarInt(hSITimer);
	switch(SITimer) {
		case 0: {
			Format(buffer, sizeof(buffer),"较慢");
		}
		case 1: {
			Format(buffer, sizeof(buffer),"默认");
		}
		case 2: {
			Format(buffer, sizeof(buffer),"较快");
		}
		case 3: {
			Format(buffer, sizeof(buffer),"特感速递？");
		}
	}
	SetMenuTitle(menu, "修改特感刷新速度 [%s]", buffer);
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "0", "较慢");
	AddMenuItem(menu, "1", "默认");
	AddMenuItem(menu, "2", "较快");
	AddMenuItem(menu, "3", "特感速递？");
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
				TZ_CallVoteStr(client, buffer);
			}
			case 1: {
				tempSITimer = 1;
				Format(buffer, sizeof(buffer),"默认");
				TZ_CallVoteStr(client, buffer);
			}
			case 2: {
				tempSITimer = 2;
				Format(buffer, sizeof(buffer),"较快");
				TZ_CallVoteStr(client, buffer);
			}
			case 3: {
				tempSITimer = 3;
				Format(buffer, sizeof(buffer),"特感速递？");
				TZ_CallVoteStr(client, buffer);
			}
		}
	}
	else if (action == MenuAction_Cancel) drawPanel(client);
}

public void TZ_CallVoteStr(int client, char[] param1)
{
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
		Format(sBuffer, sizeof(sBuffer), "修改特感刷新速度为 [%s]", param1);

		g_hVote = CreateBuiltinVote(SITimerHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, SITimerVoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, MENU_DISPLAY_TIME);
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
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public int SITimerHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1) );
		}
	}
}

public Action Menu_SIDamage(int client, int args)
{
	Handle menu = CreateMenu(Menu_SIDamageHandler);
	int dmg = GetConVarInt(hDmgThreshold);
	SetMenuTitle(menu, "修改特感基础伤害 [%d]", dmg);
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "", "8");
	AddMenuItem(menu, "", "12");
	AddMenuItem(menu, "", "24");
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
}

public void ResetSettings()
{
	SetConVarInt(FindConVar("vs_tank_damage"), 24);
	SetConVarInt(FindConVar("ast_sitimer"), 1);
	SetConVarBool(hRehealth, false);
	ServerCommand("sm_reloadscript");
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
		if ( strcmp(abilityName,"ability_lunge",false) == 0 && !bIsPouncing[user] ) {
			bIsPouncing[user] = true;
			CreateTimer(0.1, groundTouchTimer, user, TIMER_REPEAT);
		}
		if ( strcmp(abilityName, "ability_tongue", false) == 0 && !bIsUsingAbility[user] ) {
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
}

public Action OnTongueRelease(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (isInfected(client) && GetZombieClass(client) == ZC_SMOKER)
		bIsUsingAbility[client] = false;
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

		if (attacker == 0 || victim == 0 || GetClientTeam(attacker) == TEAM_SPECTATORS) return;

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
				if (strcmp(weapon, "pistol_magnum", false) == 0 || strcmp(weapon, "pistol", false) == 0|| strcmp(weapon, "smg",false) == 0 || strcmp(weapon, "smg_silenced", false) == 0)
					addHP += 2;
				else if (strcmp(weapon, "pumpshotgun", false) == 0 || strcmp(weapon, "shotgun_chrome", false) == 0 || strcmp(weapon, "sniper_scout", false) == 0)
					addHP++;
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

stock int GetZombieClass(int client) { return GetEntProp(client, Prop_Send, "m_zombieClass"); }

stock bool IsClientAndInGame(int index) {
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

public int GetDifficulty() {
	int difficulty = GetConVarInt(FindConVar("das_fakedifficulty"));
	return difficulty;
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
	if ( !GetConVarBool(hDmgModifyEnable) ) return;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientAndInGame(attacker) || !IsClientAndInGame(victim)) return;

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