#pragma semicolon 1
#include <sourcemod>

Handle emptyChangeMap = INVALID_HANDLE;
float lastDisconnectTime;
char g_strCampaignFirstMap[13][32];

#define RESTART_DELAY_EMPTY_SERVER 3.0

public void OnPluginStart()
{
	emptyChangeMap = CreateConVar("sv_emptychangemap", "1", "0|1");
	RegAdminCmd("sv_restart", RestartServer, ADMFLAG_ROOT);
}

// 服务器没人时自动刷新
public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client) && IsFakeClient(client)) return;
	float currenttime = GetGameTime();
	if (lastDisconnectTime == currenttime) return;
	CreateTimer(RESTART_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}

public Action IsNobodyConnected(Handle timer, float timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime)
	{
		return Plugin_Stop;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return Plugin_Stop;
		}
	}
	if (GetConVarBool(emptyChangeMap))
	{
		SetupMapStrings();
		ServerCommand("changelevel %s", g_strCampaignFirstMap[RadomMap()]);
	}
	return Plugin_Stop;
}

public int RadomMap()
{
	new RandomInt = GetRandomInt(0, 12);
	return RandomInt;
}

public void SetupMapStrings()
{
	Format(g_strCampaignFirstMap[0], 32, "c1m1_hotel");
	Format(g_strCampaignFirstMap[1], 32, "c14m1_junkyard");
	Format(g_strCampaignFirstMap[2], 32, "c3m1_plankcountry");
	Format(g_strCampaignFirstMap[3], 32, "c4m1_milltown_a");
	Format(g_strCampaignFirstMap[4], 32, "c5m1_waterfront");
	Format(g_strCampaignFirstMap[5], 32, "c6m1_riverbank");
	Format(g_strCampaignFirstMap[6], 32, "c7m1_docks");
	Format(g_strCampaignFirstMap[7], 32, "c8m1_apartment");
	Format(g_strCampaignFirstMap[8], 32, "c9m1_alleys");
	Format(g_strCampaignFirstMap[9], 32, "c10m1_caves");
	Format(g_strCampaignFirstMap[10], 32, "c11m1_greenhouse");
	Format(g_strCampaignFirstMap[11], 32, "c12m1_hilltop");
	Format(g_strCampaignFirstMap[12], 32, "c13m1_alpinecreek");
}

public Action RestartServer(int client, int args) {
	ServerCommand("sv_cheats 1;sv_crash;sv_cheats 0");
}