// Thanks to Thraka 

#include <sourcemod>

#define PLUGIN_VERSION "1.1"

public Plugin:myinfo = 
{
	name = "Confogl Autoloader",
	author = "D4rKr0W",
	description = "Executes confogl whenever a versus/teamversus lobby connects or the gamemode is switched to versus/teamversus",
	version = PLUGIN_VERSION,
	url = "http://code.google.com/p/confogl"
}

new Handle:g_hGameMode;
new Handle:hAutoloaderConfig
new Handle:hAutoloaderPreExec

//coop,realism,survival,versus,teamversus,scavenge,teamscavenge

public OnPluginStart()
{
	g_hGameMode = FindConVar("mp_gamemode");
	
	CreateConVar("confogl_loader_ver", PLUGIN_VERSION, "Version of confogl autoloader plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	hAutoloaderConfig = CreateConVar("confogl_autoloader_config", "", "Config to launch with the autoloader");
	hAutoloaderPreExec = CreateConVar("confogl_autoloader_execcfg", "", "Config to exec before starting confogl");

	HookConVarChange(g_hGameMode, ConVarChange_GameMode);
}

public OnMapStart()
{
	ExecuteConfig();
}

public ConVarChange_GameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if ( !StrEqual(oldValue, newValue) )
	{
		ExecuteConfig();
	}
}

ExecuteConfig()
{
	decl String:sGameMode[16], String:sCommandBuffer[PLATFORM_MAX_PATH], String:sConfigBuffer[PLATFORM_MAX_PATH], String:sPreExecBuffer[PLATFORM_MAX_PATH];

	GetConVarString(g_hGameMode, sGameMode, sizeof(sGameMode));

	if ((StrEqual(sGameMode, "coop"))) {
		GetConVarString(hAutoloaderConfig, sConfigBuffer, sizeof(sConfigBuffer));
		GetConVarString(hAutoloaderPreExec, sPreExecBuffer, sizeof(sPreExecBuffer));

		ServerCommand("exec %s", sPreExecBuffer);
		ServerCommand("sm_resetmatch");
		Format(sCommandBuffer, sizeof(sCommandBuffer), "sm_forcematch %s", sConfigBuffer);
		ServerCommand(sCommandBuffer);	
	}
	else {
		ServerCommand("sm_resetmatch");	
	}
}