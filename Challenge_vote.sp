#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <nativevotes>

#define MENU_DISPLAY_TIME		15

int LimitHealth = 0;
int tempLimitHealth = 0;
//int tempSIClass = -1;
int tempTankDmg;
int tempSITimer;
bool bIsPouncing[MAXPLAYERS + 1];		  // if a hunter player is currently pouncing

Handle rehealth = INVALID_HANDLE;
Handle ratiodmg = INVALID_HANDLE;
Handle hSITimer = INVALID_HANDLE;
// Handle tz_hunter = INVALID_HANDLE;
// Handle tz_jockey = INVALID_HANDLE;
// Handle tz_charger = INVALID_HANDLE;
// Handle tz_smoker = INVALID_HANDLE;
// Handle tz_boomer = INVALID_HANDLE;
// Handle tz_spitter = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Difficulty Controller (Vote Version)",
	author = "海洋空氣",
	description = "Difficulty Controller for AstMod.",
	version = "1.6.6",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_tz", challenge, "打开难度控制系统菜单");
	//HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	//HookEvent("player_team", OnPlayerSwitchTeam, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Post);
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Post);
	
	rehealth = CreateConVar("tz_rehealth",       "0", "击杀特感回血开关");
	hSITimer = CreateConVar("tz_sitimer",       "1", "特感刷新速率");
	ratiodmg = FindConVar("ratio_damage");
	// tz_hunter = CreateConVar("tz_hunter",       "-1", "");
	// tz_jockey = CreateConVar("tz_jockey",        "-1", "");
	// tz_charger = CreateConVar("tz_charger",   "-1", "");
	// tz_smoker = CreateConVar("tz_smoker",   "-1", "");
	// tz_boomer = CreateConVar("tz_boomer",  "-1", "");
	// tz_spitter = CreateConVar("tz_spitter",       "-1", "");
}

/* public OnPlayerSwitchTeam(Handle event, char[] name, bool dontBroadcast)
{
	if (EasyDifficulty()) {
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client > 0 && !GetEventBool(event, "isbot") && GetEventInt(event, "team") == 2)
			ResetSettings();
	}
} */

// 开局自动弹出菜单
/* public OnRoundStart(Handle event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i))
			draw_function(i);
	}
}

public OnClientPutInServer(int client)
{
	draw_function(client);
} */

public void OnMapStart()
{
	PrecacheSound("ui/bigreward.wav");
}

public Action challenge(int client, int args)
{
	draw_function(client);
}

public Action draw_function(int client)
{
	// 创建面板
	char buffer[64];
	Menu menu = CreateMenu(MenuHandler);
	SetMenuTitle(menu, "难度控制 Difficulty Controller");
	SetMenuExitButton(menu, true);
	
	if (GetConVarBool(ratiodmg))
		Format(buffer, sizeof(buffer), "按特感血量扣血 [已启用]");
	else Format(buffer, sizeof(buffer), "按特感血量扣血");
	
	AddMenuItem(menu, "hp", buffer);
	
	Format(buffer, sizeof(buffer), "增减 tank 伤害 [%i]", GetConVarInt(FindConVar("vs_tank_damage")));
	AddMenuItem(menu, "td", buffer);
	
	AddMenuItem(menu, "st", "增减特感刷新速率");
	
	Format(buffer, sizeof(buffer), "增减特感基础伤害 [%i]", GetConVarInt(FindConVar("dma_dmg")));
	AddMenuItem(menu, "sd", buffer);
	
	if (GetConVarBool(rehealth))
		AddMenuItem(menu, "rh", "击杀特感回血 [已启用]");
	else AddMenuItem(menu, "rh", "击杀特感回血");
	
	AddMenuItem(menu, "wc", "天气控制");
	
	AddMenuItem(menu, "rs", "恢复默认设置");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
}

public int MenuHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		if (GetClientTeam(client) == 2) {
			switch (param)
			{
				case 0: {
					if (GetConVarBool(ratiodmg)) {
						SetConVarBool(ratiodmg, false);
					}
					else {
						SetConVarBool(ratiodmg, true);
					}
					draw_function(client);
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
						draw_function(client);
					}
				}
				case 4: {
					if (GetConVarBool(rehealth)) {
						SetConVarBool(rehealth, false);
						PrintToChatAll("\x04[SM] \x01有人关闭了击杀回血.");
					}
					else {
						SetConVarBool(rehealth, true);
						PrintToChatAll("\x04[SM] \x01有人打开了击杀回血.");
					}
					draw_function(client);
				} case 5:
					FakeClientCommand(client, "sm_weather");
				case 6:{
					ResetSettings();
					if (GetDifficulty() == 1) 
						SIDamage(12.0);
					draw_function(client);
				}
			}
		}
		else PrintToChat(client, "\x04[SM] \x01仅限生还者选择!");
	}
}

/*public Action Menu_LimitPermHealth(int client, int args) {
	Handle menu = CreateMenu(Menu_LimitPermHealthHandler);
	SetMenuTitle(menu, "保持实血");
	SetMenuExitBackButton(menu, true);
	switch (LimitHealth)
	{
		case 40:{
			AddMenuItem(menu, "ft", "✔40以上");
			AddMenuItem(menu, "st", "60以上");
			AddMenuItem(menu, "et", "80以上");
			AddMenuItem(menu, "nt", "90以上");
			AddMenuItem(menu, "gu", "放弃");
			//AddMenuItem(menu, "dd", "死亡之门模式");
		}
		case 60:{
			AddMenuItem(menu, "ft", "40以上");
			AddMenuItem(menu, "st", "✔60以上");
			AddMenuItem(menu, "et", "80以上");
			AddMenuItem(menu, "nt", "90以上");
			AddMenuItem(menu, "gu", "放弃");
			//AddMenuItem(menu, "dd", "死亡之门模式");
		}
		case 80:{
			AddMenuItem(menu, "ft", "40以上");
			AddMenuItem(menu, "st", "60以上");
			AddMenuItem(menu, "et", "✔80以上");
			AddMenuItem(menu, "nt", "90以上");
			AddMenuItem(menu, "gu", "放弃");
			//AddMenuItem(menu, "dd", "死亡之门模式");
		}
		case 90:{
			AddMenuItem(menu, "ft", "40以上");
			AddMenuItem(menu, "st", "60以上");
			AddMenuItem(menu, "et", "80以上");
			AddMenuItem(menu, "nt", "✔90以上");
			AddMenuItem(menu, "gu", "放弃");
			//AddMenuItem(menu, "dd", "死亡之门模式");
		}
		case 0:{
			AddMenuItem(menu, "ft", "40以上");
			AddMenuItem(menu, "st", "60以上");
			AddMenuItem(menu, "et", "80以上");
			AddMenuItem(menu, "nt", "90以上");
			AddMenuItem(menu, "gu", "✔放弃");
			//AddMenuItem(menu, "dd", "死亡之门模式");
		}
		case 1:{
			AddMenuItem(menu, "ft", "40以上");
			AddMenuItem(menu, "st", "60以上");
			AddMenuItem(menu, "et", "80以上");
			AddMenuItem(menu, "nt", "90以上");
			AddMenuItem(menu, "gu", "放弃");
			//AddMenuItem(menu, "dd", "✔死亡之门模式");
		}
	}
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public void Menu_LimitPermHealthHandler(Handle menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select) {
		switch (param)
		{
			case 0: {
				//LimitHealth = 40;
				TZ_CallVote(client, 1, 40);
			}
			case 1: {
				//LimitHealth = 60;
				TZ_CallVote(client, 1, 60);
			}
			case 2: {
				//LimitHealth = 80;
				TZ_CallVote(client, 1, 80);
			}
			case 3: {
				//LimitHealth = 90;
				TZ_CallVote(client, 1, 90);
			}
			case 4: {
				//LimitHealth = 0;
				TZ_CallVote(client, 1, 0);
			}
			// case 5: {
				// //LimitHealth = 0;
				// TZ_CallVote(client, 1, 1);
			// }
		}
		draw_function(client);
	}
	else if (action == MenuAction_Cancel) draw_function(client);
}*/

public void TZ_CallVote(int client, int param1, int param2)
{
	char buffer[64];
	Handle vote;
	switch (param1)
	{
		case 1: {
			Format(buffer, sizeof(buffer), "实血低于 [%i] 自动处死", param2);
			tempLimitHealth = param2;
			vote = NativeVotes_Create(LimitHealthHandler, NativeVotesType_Custom_YesNo);
		}
		case 2: {
			Format(buffer, sizeof(buffer), "增减 tank 伤害为 [%i]", param2);
			tempTankDmg = param2;
			vote = NativeVotes_Create(TankDmgHandler, NativeVotesType_Custom_YesNo);
		}
	}
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, buffer);
	//NativeVotes_DisplayToAll(vote, 15);
	NativeVotes_DisplayToTeam_Copy(vote, 2, MENU_DISPLAY_TIME);
}

public int LimitHealthHandler(Handle vote, MenuAction action, int client, int param)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_VoteCancel:
		{
			if (client == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (client == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				NativeVotes_DisplayPass(vote, "正在执行限制实血...");
				// Do something because it passed
				LimitHealth = tempLimitHealth;
			}
		}
	}
}

public Action Menu_TankDmg(int client, int args) {
	Handle menu = CreateMenu(Menu_TankDmgHandler);
	SetMenuTitle(menu, "增减 tank 伤害");
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
		switch (param)
		{
			case 0: {
				//SetConVarInt(FindConVar("vs_tank_damage"), 24);
				TZ_CallVote(client, 2, 24);
			}
			case 1: {
				//SetConVarInt(FindConVar("vs_tank_damage"), 36);
				TZ_CallVote(client, 2, 36);
			}
			case 2: {
				//SetConVarInt(FindConVar("vs_tank_damage"), 48);
				TZ_CallVote(client, 2, 48);
			}
			case 3: {
				//SetConVarInt(FindConVar("vs_tank_damage"), 100);
				TZ_CallVote(client, 2, 100);
			}
		}
		draw_function(client);
	}
	else if (action == MenuAction_Cancel) draw_function(client);
}

public int TankDmgHandler(Handle vote, MenuAction action, int client, int param)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_VoteCancel:
		{
			if (client == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (client == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				NativeVotes_DisplayPass(vote, "正在执行更改 Tank 伤害...");
				// Do something because it passed
				SetConVarInt(FindConVar("vs_tank_damage"), tempTankDmg);
			}
		}
	}
}

public Action Menu_SITimer(int client, int args)
{
	Handle menu = CreateMenu(Menu_SITimerHandler);
	SetMenuTitle(menu, "增减特感刷新速度");
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

public void TZ_CallVoteStr(int client, int param1, char[] param2)
{
	char buffer[64];
	Handle vote;
	switch (param1)
	{
		case 1: {
			Format(buffer, sizeof(buffer), "增减特感刷新速度为 [%s]", param2);
			vote = NativeVotes_Create(SITimerHandler, NativeVotesType_Custom_YesNo);
		}
	}
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, buffer);
	//NativeVotes_DisplayToAll(vote, 15);
	NativeVotes_DisplayToTeam_Copy(vote, 2, MENU_DISPLAY_TIME);
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
				Format(buffer, sizeof(buffer),"正常");
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
	}
}

public int SITimerHandler(Handle vote, MenuAction action, int client, int param)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_VoteCancel:
		{
			if (client == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			if (client == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				NativeVotes_DisplayPass(vote, "正在执行更改特感刷新速度...");
				// Do something because it passed
				SetConVarInt(hSITimer, tempSITimer);
				ServerCommand("sm_reloadscript");
			}
		}
	}
}

// public Action Menu_SpecialLimit(int client, int args) {
	// Handle menu = CreateMenu(Menu_SpecialLimitHandler);
	// SetMenuTitle(menu, "选择特感");
	// SetMenuExitBackButton(menu, true);
	// AddMenuItem(menu, "", "Hunter");
	// AddMenuItem(menu, "", "Jockey");
	// AddMenuItem(menu, "", "Charger");
	// AddMenuItem(menu, "", "Smoker");
	// AddMenuItem(menu, "", "Boomer");
	// AddMenuItem(menu, "", "Spitter");
	// }
	// DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	// return Plugin_Handled;
// }

// public int Menu_SpecialLimitHandler(Handle menu, MenuAction action, int client, int param)
// {
	// if (action == MenuAction_Select) {
		// Handle menu = CreateMenu(Menu_SILimitHandler);
		// switch (param) {
			// case 0: { //Hunter
				// tempSIClass = 1;
				// SetMenuTitle(menu, "增减 Hunter 数量");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
				// AddMenuItem(menu, "", "3");
				// AddMenuItem(menu, "", "4");
			// }
			// case 1: { // Jockey
				// tempSIClass = 2;
				// SetMenuTitle(menu, "增减 Jockey 数量");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
			// }
			// case 2: { // Charger
				// tempSIClass = 3;
				// SetMenuTitle(menu, "增减 Charger 数量");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
			// }
			// case 3: { // Smoker
				// tempSIClass = 4;
				// SetMenuTitle(menu, "增减 Smoker 数量");
				// AddMenuItem(menu, "", "0");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
			// }
			// case 4: { // Boomer
				// tempSIClass = 5;
				// SetMenuTitle(menu, "增减 Boomer 数量");
				// AddMenuItem(menu, "", "0");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
			// }
			// case 5: { // Spitter
				// tempSIClass = 6;
				// SetMenuTitle(menu, "增减 Spitter 数量");
				// AddMenuItem(menu, "", "0");
				// AddMenuItem(menu, "", "1");
				// AddMenuItem(menu, "", "2");
			// }
		// }
		// SetMenuExitBackButton(menu, true);
		// DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	// } else if (action == MenuAction_Cancel) draw_function(client);
// }

// public int Menu_SILimitHandler(Handle menu, MenuAction action, int client, int param)
// {
	// if (action == MenuAction_Select) {
		// switch (param) {
			// case 0: { 
				
				// TZ_CallVote2(client, 1, tempSIClass);
			// }
			// case 1: { 
				
			// }
			// case 2: { 
				
			// }
			// case 3: { 
				
			// }
		// }
		// SetMenuExitBackButton(menu, true);
		// DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	// } else if (action == MenuAction_Cancel) draw_function(client);
// }

// public void TZ_CallVote2(int client, int param1, int param2)
// {
	// charbuffer[64];
	// Handle vote;
	// switch (param1)
	// {
		// case 1: {
			// Format(buffer, sizeof(buffer), "实血低于 [%i] 自动处死", param2);
			// tempLimitHealth = param2;
			// vote = NativeVotes_Create(LimitHealthHandler, NativeVotesType_Custom_YesNo);
		// }
		// case 2: {
			// Format(buffer, sizeof(buffer), "增减 tank 伤害为 [%i]", param2);
			// tempTankDmg = param2;
			// vote = NativeVotes_Create(TankDmgHandler, NativeVotesType_Custom_YesNo);
		// }
	// }
	// NativeVotes_SetInitiator(vote, client);
	// NativeVotes_SetDetails(vote, buffer);
	// NativeVotes_DisplayToAll(vote, 15);
	// NativeVotes_DisplayToTeam_Copy(vote, 2, MENU_DISPLAY_TIME);
// }

// public LimitHealthHandler(Handle:vote, MenuAction:action, client, param)
// {
	// switch (action)
	// {
		// case MenuAction_End:
		// {
			// NativeVotes_Close(vote);
		// }
		
		// case MenuAction_VoteCancel:
		// {
			// if (client == VoteCancel_NoVotes)
			// {
				// NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			// }
			// else
			// {
				// NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			// }
		// }
		
		// case MenuAction_VoteEnd:
		// {
			// if (client == NATIVEVOTES_VOTE_NO)
			// {
				// NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			// }
			// else
			// {
				// NativeVotes_DisplayPass(vote, "正在执行限制实血...");
				// // Do something because it passed
				// LimitHealth = tempLimitHealth;
			// }
		// }
	// }
// }

public Action Menu_SIDamage(int client, int args) {
	Handle menu = CreateMenu(Menu_SIDamageHandler);
	SetMenuTitle(menu, "增减特感基础伤害");
	SetMenuExitBackButton(menu, true);
	int dmg = GetConVarInt(FindConVar("dma_dmg"));
	switch(dmg) {
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
		default: {
			AddMenuItem(menu, "", "8");
			AddMenuItem(menu, "", "✔12");
			AddMenuItem(menu, "", "24");
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
		draw_function(client);
	} else if (action == MenuAction_Cancel) draw_function(client);
}

public void ResetSettings()
{
	LimitHealth = 0;
	SetConVarInt(FindConVar("survivor_max_incapacitated_count"), 2);
	SetConVarInt(FindConVar("vs_tank_damage"), 24);
	SetConVarInt(FindConVar("ammo_m60_max"), 1);
	SetConVarBool(rehealth, false);
	ServerCommand("sm_reloadscript");
}

///////////////////////////
//           Event           //
//////////////////////////
public Action OnPlayerHurt(Handle event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(victim) == 2)
	{
		int HP = GetEntProp(victim, Prop_Data, "m_iHealth");
		if (HP < LimitHealth && LimitHealth > 0)
		{
			ForcePlayerSuicide(victim);
			PrintHintText(victim, "保持实血在%d以上的挑战失败", LimitHealth);
		}
	}
}

public void OnAbilityUse(Handle event, const char[] name, bool dontBroadcast)
{
	// track hunters pouncing
	int userId = GetEventInt(event, "userid");
	int user = GetClientOfUserId(userId);
	char abilityName[64];
	
	GetEventString(event,"ability",abilityName,sizeof(abilityName));
	
	if(IsClientAndInGame(user) && strcmp(abilityName,"ability_lunge",false) == 0 && !bIsPouncing[user])
	{
		bIsPouncing[user] = true;
		CreateTimer(0.1, groundTouchTimer, user, TIMER_REPEAT);
	}
}

public Action groundTouchTimer(Handle timer, int client)
{
	if(IsClientAndInGame(client) && (isGrounded(client) || !IsPlayerAlive(client)))
	{
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
	
	if(bIsPouncing[victim])
	{
		bIsPouncing[victim] = false;
	}
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarBool(rehealth)) {
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		bool headshot = GetEventBool(event, "headshot");
		char weapon[64];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		
		if (attacker == 0 || victim == 0 || GetClientTeam(attacker) != 2 || GetClientTeam(victim) != 3) return;
		
		int zombie = GetZombieClass(victim);
		int HP = GetEntProp(attacker, Prop_Data, "m_iHealth");
		int tHP = GetClientHealth(attacker);
		int addHP = 0;
		switch (zombie) {
			case 1: {} 		// Smoker
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
}

public void SIDamage(float damage)
{
	SetConVarFloat(FindConVar("dma_dmg"), damage);
}

stock int GetZombieClass(int client) { return GetEntProp(client, Prop_Send, "m_zombieClass"); }

stock bool IsClientAndInGame(int index) {
	return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

public int GetDifficulty() {
	int difficulty = GetConVarInt(FindConVar("das_fakedifficulty"));
	return difficulty;
}

stock bool NativeVotes_DisplayToTeam_Copy(Handle vote, int team, int time)
{
	NativeVotes_SetTeam(vote, team);

	int total;
	int[] players = new int[MaxClients];
	
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != team))
			continue;
		players[total++] = i;
	}
	
	return NativeVotes_Display(vote, players, total, time);
}