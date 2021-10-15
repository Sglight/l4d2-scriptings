/**
 * 实现原理不明，也不知道有没有别的方法，总之能用就行了，也算是一个核心插件吧。
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	RegConsoleCmd("sm_reloadscript", Cmd_Reload, "Reload Script");
}

public Action Cmd_Reload(int client, int args)
{
	CheatCommand("script_reload_code", "versus.nut");
	CheatCommand("script_reload_code", "coop.nut");
}

public void CheatCommand(char[] strCommand, char[] strParam1)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientInGame(client))
		{
			int flags = GetCommandFlags(strCommand);
			SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
			FakeClientCommand(client, "%s %s", strCommand, strParam1);
			SetCommandFlags(strCommand, flags);
			return;
		}
	}
}