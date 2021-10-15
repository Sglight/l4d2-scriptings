#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
// #include <left4dhooks>

#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

public void OnPluginStart()
{
	RegConsoleCmd("sm_join", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_joingame", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_jg", JoinTeam_Cmd, "Moves you to the survivor team");
	RegConsoleCmd("sm_spectate", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_spec", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_s", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_away", Spectate_Cmd, "Moves you to the spectator team");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn");
	RegConsoleCmd("sm_kill", Suicide_Cmd);
	RegConsoleCmd("sm_die", Suicide_Cmd);
	RegConsoleCmd("sm_suicide", Suicide_Cmd);
	RegConsoleCmd("sm_zs", Suicide_Cmd);
	RegConsoleCmd("sm_fuck", Fuck_Cmd);
	RegConsoleCmd("sm_tank", Tank_Cmd);
}

////////////////////////////////////////////////////
//                    JoinTeam                    //
////////////////////////////////////////////////////

public Action JoinTeam_Cmd(int client, int args)
{
	if (!isClientValid(client)) return Plugin_Handled;
	if (GetClientTeam(client) == TEAM_SURVIVORS)
	{
		Menu_SwitchCharacters(client);
		return Plugin_Handled;
	}
	FakeClientCommand(client, "jointeam 2");
	return Plugin_Handled;
}

public Action Menu_SwitchCharacters(int client)
{
	// 创建面板
	Menu menu = CreateMenu(CharactersMenuHandler);
	SetMenuTitle(menu, "Switch Character");
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
	if ( !isClientValid(client) ) return;
	ChangeClientTeam(client, TEAM_SPECTATORS);
	PrintToChatAll("\x01Sibalnoma \x03%N \x01 has become a spectator!", client);
	return;
}

bool isClientValid(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	if (!IsClientInGame(client)) return false;
	if (IsFakeClient(client)) return false;
	return true;
}

////////////////////////////////////////////////////
//                    Doorlock                    //
////////////////////////////////////////////////////

public Action Return_Cmd(int client, int args)
{
	if (client > 0 && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
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

///////////////////////////////////////////////////
//         New Speical Commands Transfer         //
///////////////////////////////////////////////////

public Action Suicide_Cmd(int client, int args)
{
	FakeClientCommand(client, "say_team !killme");
}

public Action Tank_Cmd(int client, int args)
{
	FakeClientCommand(client, "say_team !t");
}

public Action Fuck_Cmd(int client, int args)
{
	char inputArg[8];
	if ( GetCmdArgs() != 1 ) {
		PrintToChat(client, "Syntax: sm_fuck <si classname>");
		return;
	}

	GetCmdArg(1, inputArg, sizeof(inputArg));
	if (StrEqual(inputArg, "all", false)) {
		for (int i = 1; i <= MaxClients; i++) {
			if ( IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED ) {
					ForcePlayerSuicide(i);
			}
		}
		PrintToChatAll("\x01Sibalnoma \x03%N \x01fuck all special infected!", client);
	} else {
		int fuckCount = 0;
		for (int i = 1; i <= MaxClients; i++) {
			if ( IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED ) {
				char siName[32];
				GetClientName(i, siName, sizeof(siName));
				if ( StrContains( siName, inputArg, false ) >= 0 ) {
					ForcePlayerSuicide(i);
					fuckCount++;
				}
			}
		}
		if (fuckCount) {
			PrintToChatAll("\x01Sibalnoma \x03%N \x01fuck all %s!", client, inputArg);
		} else {
			PrintToChat(client, "Nothing to fuck.");
		}
	}
}
