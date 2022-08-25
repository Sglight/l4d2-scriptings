// Thanks to Thraka 

#include <sourcemod>
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2"

public Plugin myinfo = 
{
	name = "Confogl Autoloader",
	author = "D4rKr0W, 海洋空氣",
	description = "Executes confogl whenever a versus/teamversus lobby connects or the gamemode is switched to versus/teamversus",
	version = PLUGIN_VERSION,
	url = "http://code.google.com/p/confogl"
}

ConVar hAutoloaderConfig;
ConVar hCurrentConfig;

public void OnPluginStart()
{
	CreateConVar("confogl_loader_ver", PLUGIN_VERSION, "Version of confogl autoloader plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	hAutoloaderConfig = CreateConVar("confogl_autoloader_config", "", "Config to launch with the autoloader");
	hCurrentConfig = CreateConVar("confogl_current_config", "", "Current config");
}

public void OnMapStart()
{
	ExecuteConfig();
}

void ExecuteConfig()
{
	char sConfigBuffer[PLATFORM_MAX_PATH];
	hAutoloaderConfig.GetString(sConfigBuffer, sizeof(sConfigBuffer));
	char sCurrentConfig[PLATFORM_MAX_PATH];
	hCurrentConfig.GetString(sCurrentConfig, sizeof(sCurrentConfig));

	if (strcmp(sConfigBuffer, sCurrentConfig) == 0 || strlen(sConfigBuffer) == 0) return;

	ServerCommand("sm_forcematch %s", sConfigBuffer);
}