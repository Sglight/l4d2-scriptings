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
	int entity = CreateEntityByName("logic_script");
	if( entity != -1 )
	{
		char sFile[PLATFORM_MAX_PATH];
		if( args != 1 ) {
			sFile = "versus.nut"; // 暂时用于测试，后续不支持无参数指令
		} else {
			GetCmdArg(1, sFile, sizeof(sFile));
		}
		DispatchSpawn(entity);
		SetVariantString(sFile);
		AcceptEntityInput(entity, "RunScriptFile");
		RemoveEdict(entity);
	}

	return Plugin_Handled;
}