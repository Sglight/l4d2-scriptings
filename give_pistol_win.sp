#include <sourcemod>
#include <sdktools>

new grenade[MAXPLAYERS] = 0;

public Plugin:myinfo =
{
	name = "[L4D2] Shop and Economic System",
	author = "海洋空氣",
	description = "",
	version = "1.0",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public OnPluginStart() {
	HookEvent("player_team", evtPlayerTeam);
	
	RegConsoleCmd("sm_buy", BuyWeapons, "Open shop menu");
	RegConsoleCmd("sm_b", BuyWeapons, "Open shop menu");

}

public OnClientPutInServer(client)
{
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
		Menu_CreateWeaponMenu(client, false);
	}
}

public Action:BuyWeapons(client, args)
{
	if (client) {
		Menu_CreateWeaponMenu(client, false);
	}
}

public evtPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new newteam = GetEventInt(event, "team");
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && newteam == 2) {
		Menu_CreateWeaponMenu(client, false);
	}
}

public evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MAXPLAYERS; client++) {
		if (bIsSurvior(client)) {
			Menu_CreateWeaponMenu(client, false);
		}
		grenade[client] = 0;
	}
}

public Action:Menu_CreateWeaponMenu(client, args) {
	new String: title[64];
	new Handle:menu = CreateMenu(Menu_SpawnWeaponHandler);
	Format(title, sizeof(title), "白给武器    现金: infinite")
	SetMenuTitle(menu, title);
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "dp", "P2000 ($200)");
	AddMenuItem(menu, "pm", "Desert Eagle ($700)");
	AddMenuItem(menu, "sc", "Schmidt Scout ($2750)");
	AddMenuItem(menu, "awp", "AWP  ($4750)");
	AddMenuItem(menu, "hg", "HE Grenade  ($300)");
	DisplayMenu(menu, client, 30);
	return Plugin_Handled;
}

public Menu_SpawnWeaponHandler(Handle:menu, MenuAction:action, client, itempos) {
	if (action == MenuAction_Select) {
		if (GetClientTeam(client) == 2) {
			switch (itempos) {
				case 0: {
					Do_SpawnItem(client, "pistol");
				} case 1: {
					Do_SpawnItem(client, "pistol_magnum");
				} case 2: {
					Do_SpawnItem(client, "sniper_scout");
				} case 3: {
					Do_SpawnItem(client, "sniper_awp");
				} case 4: {
					if (grenade[client] < 1) {
						Do_SpawnItem(client, "pipe_bomb");
						grenade[client]++;
					} else {
						PrintHintText(client, "一回合仅能购买一颗雷~")
					}
				}
			}
		} else PrintHintText(client, "只有生还者才能买枪~")
		Menu_CreateWeaponMenu(client, false);
	} else if (action == MenuAction_End)
		CloseHandle(menu);
}

Do_SpawnItem(client, const String:type[]) {
	new String:feedback[64];
	Format(feedback, sizeof(feedback), "A %s has been spawned", type);
	if (client == 0) {
		ReplyToCommand(client, "Can not use this command from the console."); 
	} else {
		StripAndExecuteClientCommand(client, "give", type);
		//NotifyPlayers(client, feedback);
		LogAction(client, -1, "[NOTICE]: (%L) has spawned a %s", client, type);
	}
}

StripAndExecuteClientCommand(client, const String:command[], const String:arguments[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
}

bool: bIsSurvior(client) {
	return  client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2;
}