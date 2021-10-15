#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"v1.2.2"

//Define the number of campaigns and maps in rotation
#define NUMBER_OF_CAMPAIGNS			36		/* CHANGE TO MATCH THE TOTAL NUMBER OF CAMPAIGNS */
//#define NUMBER_OF_SCAVENGE_MAPS		13		/* CHANGE TO MATCH THE TOTAL NUMBER OF SCAVENGE MAPS */

//Define the wait time after round before changing to the next map in each game mode
#define WAIT_TIME_BEFORE_SWITCH_COOP			6.0
#define WAIT_TIME_BEFORE_SWITCH_VERSUS			6.0
//#define WAIT_TIME_BEFORE_SWITCH_SCAVENGE		11.0

//Define Game Modes
#define GAMEMODE_UNKNOWN	-1
#define GAMEMODE_COOP 		0
#define GAMEMODE_VERSUS 	1
#define GAMEMODE_SCAVENGE 	2
#define GAMEMODE_SURVIVAL 	3

#define DISPLAY_MODE_DISABLED	0
#define DISPLAY_MODE_HINT		1
#define DISPLAY_MODE_CHAT		2
#define DISPLAY_MODE_MENU		3

#define SOUND_NEW_VOTE_START	"ui/Beep_SynthTone01.wav"
#define SOUND_NEW_VOTE_WINNER	"ui/alert_clink.wav"


//Global Variables

new g_iGameMode;					//Integer to store the gamemode
//new g_iRoundEndCounter;				//Round end event counter for versus
//new g_iCoopFinaleFailureCount;		//Number of times the Survivors have lost the current finale
//new g_iMaxCoopFinaleFailures = 5;	//Amount of times Survivors can fail before ACS switches in coop
//new bool:g_bFinaleWon;				//Indicates whether a finale has be beaten or not

//Campaign and map strings/names
new String:g_strCampaignFirstMap[NUMBER_OF_CAMPAIGNS][64];		//Array of maps to switch to
new String:g_strCampaignLastMap[NUMBER_OF_CAMPAIGNS][64];		//Array of maps to switch from
new String:g_strCampaignName[NUMBER_OF_CAMPAIGNS][64];			//Array of names of the campaign
//new String:g_strScavengeMap[NUMBER_OF_SCAVENGE_MAPS][32];		//Array of scavenge maps
//new String:g_strScavengeMapName[NUMBER_OF_SCAVENGE_MAPS][32];	//Name of scaveenge maps

//Voting Variables
new bool:g_bVotingEnabled = true;							//Tells if the voting system is on
//new g_iVotingAdDisplayMode = DISPLAY_MODE_HINT;				//The way to advertise the voting system
//new Float:g_fVotingAdDelayTime = 1.0;						//Time to wait before showing advertising
new bool:g_bVoteWinnerSoundEnabled = true;					//Sound plays when vote winner changes
new g_iNextMapAdDisplayMode = DISPLAY_MODE_HINT;			//The way to advertise the next map
new Float:g_fNextMapAdInterval = 600.0;						//Interval for ACS next map advertisement
new bool:g_bClientShownVoteAd[MAXPLAYERS + 1];				//If the client has seen the ad already
new bool:g_bClientVoted[MAXPLAYERS + 1];					//If the client has voted on a map
new g_iClientVote[MAXPLAYERS + 1];							//The value of the clients vote
new g_iWinningMapIndex;										//Winning map/campaign's index
new g_iWinningMapVotes;										//Winning map/campaign's number of votes
new Handle:g_hMenu_Vote[MAXPLAYERS + 1]	= INVALID_HANDLE;	//Handle for each players vote menu

//Console Variables (CVars)
//new Handle:g_hCVar_VotingEnabled			= INVALID_HANDLE;
//new Handle:g_hCVar_VoteWinnerSoundEnabled	= INVALID_HANDLE;
//new Handle:g_hCVar_VotingAdMode				= INVALID_HANDLE;
//new Handle:g_hCVar_VotingAdDelayTime		= INVALID_HANDLE;
//new Handle:g_hCVar_NextMapAdMode			= INVALID_HANDLE;
//new Handle:g_hCVar_NextMapAdInterval		= INVALID_HANDLE;
//new Handle:g_hCVar_MaxFinaleFailures		= INVALID_HANDLE;

SetupMapStrings()
{
	//The following three variables are for all game modes except Scavenge.

	//*IMPORTANT* Before editing these change NUMBER_OF_CAMPAIGNS near the top
	//of this plugin to match the total number of campaigns or it will not
	//loop through all of them when the check is made to change the campaign.

	//First Maps of the Campaign
	Format(g_strCampaignFirstMap[0], 64, "c1m1_hotel");
	Format(g_strCampaignFirstMap[1], 64, "c2m1_highway");
	Format(g_strCampaignFirstMap[2], 64, "c3m1_plankcountry");
	Format(g_strCampaignFirstMap[3], 64, "c4m1_milltown_a");
	Format(g_strCampaignFirstMap[4], 64, "c5m1_waterfront");
	Format(g_strCampaignFirstMap[5], 64, "c6m1_riverbank");
	Format(g_strCampaignFirstMap[6], 64, "c7m1_docks");
	Format(g_strCampaignFirstMap[7], 64, "c8m1_apartment");
	Format(g_strCampaignFirstMap[8], 64, "c9m1_alleys");
	Format(g_strCampaignFirstMap[9], 64, "c10m1_caves");
	Format(g_strCampaignFirstMap[10], 64, "c11m1_greenhouse");
	Format(g_strCampaignFirstMap[11], 64, "c12m1_hilltop");
	Format(g_strCampaignFirstMap[12], 64, "c13m1_alpinecreek");
	Format(g_strCampaignFirstMap[13], 64, "c14m1_junkyard");
	Format(g_strCampaignFirstMap[14], 64, "dkr_m1_motel");
	Format(g_strCampaignFirstMap[15], 64, "dprm1_milltown_a");
	Format(g_strCampaignFirstMap[16], 64, "c5m1_darkwaterfront");
	Format(g_strCampaignFirstMap[17], 64, "cdta_01detour");
	Format(g_strCampaignFirstMap[18], 64, "l4d2_diescraper1_apartment_361");
	Format(g_strCampaignFirstMap[19], 64, "cwm1_intro");
	Format(g_strCampaignFirstMap[20], 64, "l4d2_stadium1_apartment");
	Format(g_strCampaignFirstMap[21], 64, "l4d_dbd2dc_anna_is_gone");
	Format(g_strCampaignFirstMap[22], 64, "aircrash");
	Format(g_strCampaignFirstMap[23], 64, "l4d_ihm01_forest");
	Format(g_strCampaignFirstMap[24], 64, "l4d_tbm_1");
	Format(g_strCampaignFirstMap[25], 64, "l4d2_bts01_forest");
	Format(g_strCampaignFirstMap[26], 64, "uz_crash");
	Format(g_strCampaignFirstMap[27], 64, "l4d2_city17_01");
	Format(g_strCampaignFirstMap[28], 64, "wfp1_track");
	Format(g_strCampaignFirstMap[29], 64, "srocchurch");
	Format(g_strCampaignFirstMap[30], 64, "uf1_boulevard");
	Format(g_strCampaignFirstMap[31], 64, "bloodtracks_01");
	Format(g_strCampaignFirstMap[32], 64, "jsarena201_town");
	Format(g_strCampaignFirstMap[33], 64, "death_sentence_1");
	Format(g_strCampaignFirstMap[34], 64, "ec01_outlets");
	Format(g_strCampaignFirstMap[35], 64, "l4d2_ff01_woods");

	//Last Maps of the Campaign
	Format(g_strCampaignLastMap[0], 64, "c1m4_atrium");
	Format(g_strCampaignLastMap[1], 64, "c2m5_concert");
	Format(g_strCampaignLastMap[2], 64, "c3m4_plantation");
	Format(g_strCampaignLastMap[3], 64, "c4m5_milltown_escape");
	Format(g_strCampaignLastMap[4], 64, "c5m5_bridge");
	Format(g_strCampaignLastMap[5], 64, "c6m3_port");
	Format(g_strCampaignLastMap[6], 64, "c7m3_port");
	Format(g_strCampaignLastMap[7], 64, "c8m5_rooftop");
	Format(g_strCampaignLastMap[8], 64, "c9m2_lots");
	Format(g_strCampaignLastMap[9], 64, "c10m5_houseboat");
	Format(g_strCampaignLastMap[10], 64, "c11m5_runway");
	Format(g_strCampaignLastMap[11], 64, "c12m5_cornfield");
	Format(g_strCampaignLastMap[12], 64, "c13m4_cutthroatcreek");
	Format(g_strCampaignLastMap[13], 64, "c14m2_lighthouse");
	Format(g_strCampaignLastMap[14], 64, "dkr_m5_stadium");
	Format(g_strCampaignLastMap[15], 64, "dprm5_milltown_escape");
	Format(g_strCampaignLastMap[16], 64, "c5m5_darkbridge");
	Format(g_strCampaignLastMap[17], 64, "cdta_05finalroad");
	Format(g_strCampaignLastMap[18], 64, "l4d2_diescraper4_top_361");
	Format(g_strCampaignLastMap[19], 64, "cwm4_building");
	Format(g_strCampaignLastMap[20], 64, "l4d2_stadium5_stadium");
	Format(g_strCampaignLastMap[21], 64, "l4d_dbd2dc_new_dawn");
	Format(g_strCampaignLastMap[22], 64, "bombshelter");
	Format(g_strCampaignLastMap[23], 64, "l4d_ihm05_lakeside");
	Format(g_strCampaignLastMap[24], 64, "l4d_tbm_5");
	Format(g_strCampaignLastMap[25], 64, "l4d2_bts06_school");
	Format(g_strCampaignLastMap[26], 64, "uz_escape");
	Format(g_strCampaignLastMap[27], 64, "l4d2_city17_05");
	Format(g_strCampaignLastMap[28], 64, "wfp4_commstation");
	Format(g_strCampaignLastMap[29], 64, "mnac");
	Format(g_strCampaignLastMap[30], 64, "uf4_airfield");
	Format(g_strCampaignLastMap[31], 64, "bloodtracks_04");
	Format(g_strCampaignLastMap[32], 64, "jsarena204_arena");
	Format(g_strCampaignLastMap[33], 64, "death_sentence_5");
	Format(g_strCampaignLastMap[34], 64, "ec05_quarry");
	Format(g_strCampaignLastMap[35], 64, "l4d2_ff05_station");

	//Campaign Names
	Format(g_strCampaignName[0], 64, "C1-死亡中心");
	Format(g_strCampaignName[1], 64, "给爷随机选张图");
	Format(g_strCampaignName[2], 64, "C3-沼泽激战");
	Format(g_strCampaignName[3], 64, "C4-暴风骤雨");
	Format(g_strCampaignName[4], 64, "C5-教区");
	Format(g_strCampaignName[5], 64, "C6-短暂时刻");
	Format(g_strCampaignName[6], 64, "C7-牺牲");
	Format(g_strCampaignName[7], 64, "C8-毫不留情");
	Format(g_strCampaignName[8], 64, "C9-坠机险途");
	Format(g_strCampaignName[9], 64, "C10-死亡丧钟");
	Format(g_strCampaignName[10], 64, "C11-静寂时分");
	Format(g_strCampaignName[11], 64, "C12-血腥收获");
	Format(g_strCampaignName[12], 64, "C13-刺骨寒溪");
	Format(g_strCampaignName[13], 64, "C14-临死一搏");
	Format(g_strCampaignName[14], 64, "Dark Carnival: Remix (C2改)");
	Format(g_strCampaignName[15], 64, "Hard Rain: Downpour (C4改)");
	Format(g_strCampaignName[16], 64, "Dark Parish (黑暗教区)");
	Format(g_strCampaignName[17], 64, "Detour Ahead  (迂回前进)");
	Format(g_strCampaignName[18], 64, "Diescraper (喋血蜃楼)");
	Format(g_strCampaignName[19], 64, "Carried off (绝境逢生)");
	Format(g_strCampaignName[20], 64, "Suicide Blitz 2 (闪电突袭2)");
	Format(g_strCampaignName[21], 64, "Dead Before Dawn DC (活死人黎明)");
	Format(g_strCampaignName[22], 64, "Heaven Can Wait Ⅱ (天堂可待 Ⅱ)");
	Format(g_strCampaignName[23], 64, "I Hate Mountains 2 (我爱大山 2)");
	Format(g_strCampaignName[24], 64, "The Bloody Moors (血腥荒野)");
	Format(g_strCampaignName[25], 64, "Back to school (回到学校)");
	Format(g_strCampaignName[26], 64, "Undead Zone (亡灵区)");
	Format(g_strCampaignName[27], 64, "City 17 (17 城)");
	Format(g_strCampaignName[28], 64, "White Forest (白森林)");
	Format(g_strCampaignName[29], 64, "Warcelona (巴塞罗那)");
	Format(g_strCampaignName[30], 64, "Urban Flight (城市航班)");
	Format(g_strCampaignName[31], 64, "Blood Tracks (血之轨迹)");
	Format(g_strCampaignName[32], 64, "Arena of the Dead (死亡竞技场)");
	Format(g_strCampaignName[33], 64, "Death Sentence (死刑)");
	Format(g_strCampaignName[34], 64, "Energy Crisis (能源危机)");
	Format(g_strCampaignName[35], 64, "Fatal Freight (致命货运站)");


	//The following string variables are only for Scavenge

	//*IMPORTANT* Before editing these change NUMBER_OF_SCAVENGE_MAPS
	//near the top of this plugin to match the total number of scavenge
	//maps, or it will not loop through all of them when changing maps.
	/*
	//Scavenge Maps
	Format(g_strScavengeMap[0], 32, "c8m1_apartment");
	Format(g_strScavengeMap[1], 32, "c8m5_rooftop");
	Format(g_strScavengeMap[2], 32, "c1m4_atrium");
	Format(g_strScavengeMap[3], 32, "c7m1_docks");
	Format(g_strScavengeMap[4], 32, "c7m2_barge");
	Format(g_strScavengeMap[5], 32, "c6m1_riverbank");
	Format(g_strScavengeMap[6], 32, "c6m2_bedlam");
	Format(g_strScavengeMap[7], 32, "c6m3_port");
	Format(g_strScavengeMap[8], 32, "c2m1_highway");
	Format(g_strScavengeMap[9], 32, "c3m1_plankcountry");
	Format(g_strScavengeMap[10], 32, "c4m1_milltown_a");
	Format(g_strScavengeMap[11], 32, "c4m2_sugarmill_a");
	Format(g_strScavengeMap[12], 32, "c5m2_park");

	//Scavenge Map Names
	Format(g_strScavengeMapName[0], 32, "Apartments");
	Format(g_strScavengeMapName[1], 32, "Rooftop");
	Format(g_strScavengeMapName[2], 32, "Mall Atrium");
	Format(g_strScavengeMapName[3], 32, "Brick Factory");
	Format(g_strScavengeMapName[4], 32, "Barge");
	Format(g_strScavengeMapName[5], 32, "Riverbank");
	Format(g_strScavengeMapName[6], 32, "Underground");
	Format(g_strScavengeMapName[7], 32, "Port");
	Format(g_strScavengeMapName[8], 32, "Motel");
	Format(g_strScavengeMapName[9], 32, "Plank Country");
	Format(g_strScavengeMapName[10], 32, "Milltown");
	Format(g_strScavengeMapName[11], 32, "Sugar Mill");
	Format(g_strScavengeMapName[12], 32, "Park");
	*/
}

/*======================================================================================
#####################             P L U G I N   I N F O             ####################
======================================================================================*/

public Plugin:myinfo =
{
	name = "Automatic Campaign Switcher (ACS)",
	author = "Chris Pringle",
	description = "Automatically switches to the next campaign when the previous campaign is over",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=156392"
}

/*======================================================================================
#################             O N   P L U G I N   S T A R T            #################
======================================================================================*/

public OnPluginStart()
{
	//Get the strings for all of the maps that are in rotation
	SetupMapStrings();

	//Create custom console variables
	CreateConVar("acs_version", PLUGIN_VERSION, "Version of Automatic Campaign Switcher (ACS) on this server", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//g_hCVar_VotingEnabled = CreateConVar("acs_voting_system_enabled", "1", "Enables players to vote for the next map or campaign [0 = DISABLED, 1 = ENABLED]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	//g_hCVar_VoteWinnerSoundEnabled = CreateConVar("acs_voting_sound_enabled", "1", "Determines if a sound plays when a new map is winning the vote [0 = DISABLED, 1 = ENABLED]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	//g_hCVar_VotingAdMode = CreateConVar("acs_voting_ad_mode", "1", "Sets how to advertise voting at the start of the map [0 = DISABLED, 1 = HINT TEXT, 2 = CHAT TEXT, 3 = OPEN VOTE MENU]\n * Note: This is only displayed once during a finale or scavenge map *", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	//g_hCVar_VotingAdDelayTime = CreateConVar("acs_voting_ad_delay_time", "1.0", "Time, in seconds, to wait after survivors leave the start area to advertise voting as defined in acs_voting_ad_mode\n * Note: If the server is up, changing this in the .cfg file takes two map changes before the change takes place *", FCVAR_PLUGIN, true, 0.1, false);
	//g_hCVar_NextMapAdMode = CreateConVar("acs_next_map_ad_mode", "1", "Sets how the next campaign/map is advertised during a finale or scavenge map [0 = DISABLED, 1 = HINT TEXT, 2 = CHAT TEXT]", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	//g_hCVar_NextMapAdInterval = CreateConVar("acs_next_map_ad_interval", "600.0", "The time, in seconds, between advertisements for the next campaign/map on finales and scavenge maps", FCVAR_PLUGIN, true, 60.0, false);
	//g_hCVar_MaxFinaleFailures = CreateConVar("acs_max_coop_finale_failures", "5", "The amount of times the survivors can fail a finale in Coop before it switches to the next campaign [0 = INFINITE FAILURES]", FCVAR_PLUGIN, true, 0.0, false);

	//Hook console variable changes
	//HookConVarChange(g_hCVar_VotingEnabled, CVarChange_Voting);
	//HookConVarChange(g_hCVar_VoteWinnerSoundEnabled, CVarChange_NewVoteWinnerSound);
	//HookConVarChange(g_hCVar_VotingAdMode, CVarChange_VotingAdMode);
	//HookConVarChange(g_hCVar_VotingAdDelayTime, CVarChange_VotingAdDelayTime);
	//HookConVarChange(g_hCVar_NextMapAdMode, CVarChange_NewMapAdMode);
	//HookConVarChange(g_hCVar_NextMapAdInterval, CVarChange_NewMapAdInterval);
	//HookConVarChange(g_hCVar_MaxFinaleFailures, CVarChange_MaxFinaleFailures);

	//Hook the game events
	//HookEvent("round_start", Event_RoundStart);
	//HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	//HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_FinaleWin);
	//HookEvent("scavenge_match_finished", Event_ScavengeMapFinished);
	HookEvent("player_disconnect", Event_PlayerDisconnect);

	//Register custom console commands
	RegConsoleCmd("mapvote", MapVote);
	RegConsoleCmd("mapvotes", DisplayCurrentVotes);
}

/*======================================================================================
##########           C V A R   C A L L B A C K   F U N C T I O N S           ###########
======================================================================================*/
/*
//Callback function for the cvar for voting system
public CVarChange_Voting(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//If the value was changed, then set it and display a message to the server and players
	if (StringToInt(strNewValue) == 1)
	{
		g_bVotingEnabled = true;
		PrintToServer("[ACS] ConVar changed: Voting System ENABLED");
		//PrintToChatAll("[ACS] ConVar changed: Voting System ENABLED");
	}
	else
	{
		g_bVotingEnabled = false;
		PrintToServer("[ACS] ConVar changed: Voting System DISABLED");
		//PrintToChatAll("[ACS] ConVar changed: Voting System DISABLED");
	}
}

//Callback function for enabling or disabling the new vote winner sound
public CVarChange_NewVoteWinnerSound(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//If the value was changed, then set it and display a message to the server and players
	if (StringToInt(strNewValue) == 1)
	{
		g_bVoteWinnerSoundEnabled = true;
		PrintToServer("[ACS] ConVar changed: New vote winner sound ENABLED");
		//PrintToChatAll("[ACS] ConVar changed: New vote winner sound ENABLED");
	}
	else
	{
		g_bVoteWinnerSoundEnabled = false;
		PrintToServer("[ACS] ConVar changed: New vote winner sound DISABLED");
		//PrintToChatAll("[ACS] ConVar changed: New vote winner sound DISABLED");
	}
}

//Callback function for how the voting system is advertised to the players at the beginning of the round
public CVarChange_VotingAdMode(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//If the value was changed, then set it and display a message to the server and players
	switch(StringToInt(strNewValue))
	{
		case 0:
		{
			g_iVotingAdDisplayMode = DISPLAY_MODE_DISABLED;
			PrintToServer("[ACS] ConVar changed: Voting display mode: DISABLED");
			//PrintToChatAll("[ACS] ConVar changed: Voting display mode: DISABLED");
		}
		case 1:
		{
			g_iVotingAdDisplayMode = DISPLAY_MODE_HINT;
			PrintToServer("[ACS] ConVar changed: Voting display mode: HINT TEXT");
			//PrintToChatAll("[ACS] ConVar changed: Voting display mode: HINT TEXT");
		}
		case 2:
		{
			g_iVotingAdDisplayMode = DISPLAY_MODE_CHAT;
			PrintToServer("[ACS] ConVar changed: Voting display mode: CHAT TEXT");
			//PrintToChatAll("[ACS] ConVar changed: Voting display mode: CHAT TEXT");
		}
		case 3:
		{
			g_iVotingAdDisplayMode = DISPLAY_MODE_MENU;
			PrintToServer("[ACS] ConVar changed: Voting display mode: OPEN VOTE MENU");
			//PrintToChatAll("[ACS] ConVar changed: Voting display mode: OPEN VOTE MENU");
		}
	}
}

//Callback function for the cvar for voting display delay time
public CVarChange_VotingAdDelayTime(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//Get the new value
	new Float:fDelayTime = StringToFloat(strNewValue);

	//If the value was changed, then set it and display a message to the server and players
	if (fDelayTime > 0.1)
	{
		g_fVotingAdDelayTime = fDelayTime;
		PrintToServer("[ACS] ConVar changed: Voting advertisement delay time changed to %f", fDelayTime);
		//PrintToChatAll("[ACS] ConVar changed: Voting advertisement delay time changed to %f", fDelayTime);
	}
	else
	{
		g_fVotingAdDelayTime = 0.1;
		PrintToServer("[ACS] ConVar changed: Voting advertisement delay time changed to 0.1");
		//PrintToChatAll("[ACS] ConVar changed: Voting advertisement delay time changed to 0.1");
	}
}

//Callback function for how ACS and the next map is advertised to the players during a finale
public CVarChange_NewMapAdMode(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//If the value was changed, then set it and display a message to the server and players
	switch(StringToInt(strNewValue))
	{
		case 0:
		{
			g_iNextMapAdDisplayMode = DISPLAY_MODE_DISABLED;
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: DISABLED");
			//PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: DISABLED");
		}
		case 1:
		{
			g_iNextMapAdDisplayMode = DISPLAY_MODE_HINT;
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: HINT TEXT");
			//PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: HINT TEXT");
		}
		case 2:
		{
			g_iNextMapAdDisplayMode = DISPLAY_MODE_CHAT;
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: CHAT TEXT");
			//PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: CHAT TEXT");
		}
	}
}

//Callback function for the interval that controls the timer that advertises ACS and the next map
public CVarChange_NewMapAdInterval(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//Get the new value
	new Float:fDelayTime = StringToFloat(strNewValue);

	//If the value was changed, then set it and display a message to the server and players
	if (fDelayTime > 60.0)
	{
		g_fNextMapAdInterval = fDelayTime;
		PrintToServer("[ACS] ConVar changed: Next map advertisement interval changed to %f", fDelayTime);
		//PrintToChatAll("[ACS] ConVar changed: Next map advertisement interval changed to %f", fDelayTime);
	}
	else
	{
		g_fNextMapAdInterval = 60.0;
		PrintToServer("[ACS] ConVar changed: Next map advertisement interval changed to 60.0");
		//PrintToChatAll("[ACS] ConVar changed: Next map advertisement interval changed to 60.0");
	}
}


//Callback function for the amount of times the survivors can fail a coop finale map before ACS switches
public CVarChange_MaxFinaleFailures(Handle:hCVar, const String:strOldValue[], const String:strNewValue[])
{
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue) == true)
		return;

	//Get the new value
	new iMaxFailures = StringToInt(strNewValue);

	//If the value was changed, then set it and display a message to the server and players
	if (iMaxFailures > 0)
	{
		g_iMaxCoopFinaleFailures = iMaxFailures;
		PrintToServer("[ACS] ConVar changed: Max Coop finale failures changed to %f", iMaxFailures);
		//PrintToChatAll("[ACS] ConVar changed: Max Coop finale failures changed to %f", iMaxFailures);
	}
	else
	{
		g_iMaxCoopFinaleFailures = 0;
		PrintToServer("[ACS] ConVar changed: Max Coop finale failures changed to 0");
		//PrintToChatAll("[ACS] ConVar changed: Max Coop finale failures changed to 0");
	}
}
*/

/*======================================================================================
#################                     E V E N T S                      #################
======================================================================================*/

public OnMapStart()
{
	//Execute config file
	//decl String:strFileName[64];
	//Format(strFileName, sizeof(strFileName), "Automatic_Campaign_Switcher_%s", PLUGIN_VERSION);
	//AutoExecConfig(true, strFileName);

	//Set all the menu handles to invalid
	CleanUpMenuHandles();

	//Set the game mode
	FindGameMode();

	//Precache sounds
	PrecacheSound(SOUND_NEW_VOTE_START);
	PrecacheSound(SOUND_NEW_VOTE_WINNER);


	//Display advertising for the next campaign or map
	if(g_iNextMapAdDisplayMode != DISPLAY_MODE_DISABLED)
		CreateTimer(g_fNextMapAdInterval, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);

	//g_iRoundEndCounter = 0;			//Reset the round end counter on every map start
	//g_iCoopFinaleFailureCount = 0;	//Reset the amount of Survivor failures
	//g_bFinaleWon = false;			//Reset the finale won variable
	ResetAllVotes();				//Reset every player's vote
}

/*
//Event fired when the Survivors leave the start area
public Action:Event_PlayerLeftStartArea(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	if(g_bVotingEnabled == true && OnFinaleOrScavengeMap() == true)
		CreateTimer(g_fVotingAdDelayTime, Timer_DisplayVoteAdToAll, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Continue;
}

//Event fired when the Round Ends
public Action:Event_RoundEnd(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	//Check to see if on a finale map, if so change to the next campaign after two rounds
	if(g_iGameMode == GAMEMODE_VERSUS && OnFinaleOrScavengeMap() == true)
	{
		g_iRoundEndCounter++;

		if(g_iRoundEndCounter >= 4)	//This event must be fired on the fourth time Round End occurs.
			CheckMapForChange();	//This is because it fires twice during each round end for
									//some strange reason, and versus has two rounds in it.
	}
	//If in Coop and on a finale, check to see if the surviors have lost the max amount of times
	else if(g_iGameMode == GAMEMODE_COOP && OnFinaleOrScavengeMap() == true &&
			g_iMaxCoopFinaleFailures > 0 && g_bFinaleWon == false &&
			++g_iCoopFinaleFailureCount >= g_iMaxCoopFinaleFailures)
	{
		CheckMapForChange();
	}

	return Plugin_Continue;
}
*/
//Event fired when a finale is won
public Action:Event_FinaleWin(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	//g_bFinaleWon = true;	//This is used so that the finale does not switch twice if this event
							//happens to land on a max failure count as well as this

	//Change to the next campaign
	if(g_iGameMode == GAMEMODE_COOP)
		CheckMapForChange();

	return Plugin_Continue;
}
/*
//Event fired when a map is finished for scavenge
public Action:Event_ScavengeMapFinished(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	//Change to the next Scavenge map
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		ChangeScavengeMap();

	return Plugin_Continue;
}
*/
//Event fired when a player disconnects from the server
public Action:Event_PlayerDisconnect(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if(iClient	< 1)
		return Plugin_Continue;

	//Reset the client's votes
	g_bClientVoted[iClient] = false;
	g_iClientVote[iClient] = -1;

	//Check to see if there is a new vote winner
	SetTheCurrentVoteWinner();

	return Plugin_Continue;
}

/*======================================================================================
#################              F I N D   G A M E   M O D E             #################
======================================================================================*/

//Find the current gamemode and store it into this plugin
FindGameMode()
{
	//Get the gamemode string from the game
	decl String:strGameMode[20];
	GetConVarString(FindConVar("mp_gamemode"), strGameMode, sizeof(strGameMode));

	//Set the global gamemode int for this plugin
	if(StrEqual(strGameMode, "coop"))
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "realism"))
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode,"versus"))
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "teamversus"))
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "scavenge"))
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "teamscavenge"))
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "survival"))
		g_iGameMode = GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation1"))		//Last Man On Earth
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation2"))		//Headshot!
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation3"))		//Bleed Out
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation4"))		//Hard Eight
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation5"))		//Four Swordsmen
		g_iGameMode = GAMEMODE_COOP;
	//else if(StrEqual(strGameMode, "mutation6"))	//Nothing here
	//	g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation7"))		//Chainsaw Massacre
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation8"))		//Ironman
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation9"))		//Last Gnome On Earth
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation10"))	//Room For One
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation11"))	//Healthpackalypse!
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation12"))	//Realism Versus
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation13"))	//Follow the Liter
		g_iGameMode = GAMEMODE_SCAVENGE;
	else if(StrEqual(strGameMode, "mutation14"))	//Gib Fest
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation15"))	//Versus Survival
		g_iGameMode = GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "mutation16"))	//Hunting Party
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation17"))	//Lone Gunman
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "mutation18"))	//Bleed Out Versus
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation19"))	//Taaannnkk!
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "mutation20"))	//Healing Gnome
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community1"))	//Special Delivery
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community2"))	//Flu Season
		g_iGameMode = GAMEMODE_COOP;
	else if(StrEqual(strGameMode, "community3"))	//Riding My Survivor
		g_iGameMode = GAMEMODE_VERSUS;
	else if(StrEqual(strGameMode, "community4"))	//Nightmare
		g_iGameMode = GAMEMODE_SURVIVAL;
	else if(StrEqual(strGameMode, "community5"))	//Death's Door
		g_iGameMode = GAMEMODE_COOP;
	else
		g_iGameMode = GAMEMODE_COOP;
}

/*======================================================================================
#################             A C S   C H A N G E   M A P              #################
======================================================================================*/

//Check to see if the current map is a finale, and if so, switch to the next campaign
CheckMapForChange()
{
	decl String:strCurrentMap[32];
	GetCurrentMap(strCurrentMap,32);					//Get the current map from the game

	for(new iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
	{
		if(StrEqual(strCurrentMap, g_strCampaignLastMap[iMapIndex]) == true)
		{
			//Check to see if someone voted for a campaign, if so, then change to the winning campaign
			if(g_bVotingEnabled == true && g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0)
			{
				if(IsMapValid(g_strCampaignFirstMap[g_iWinningMapIndex]) == true)
				{
					PrintToChatAll("\x03[ACS] \x05切换至票数最多的地图: \x04%s", g_strCampaignName[g_iWinningMapIndex]);

					if(g_iGameMode == GAMEMODE_VERSUS)
						CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, g_iWinningMapIndex);
					else if(g_iGameMode == GAMEMODE_COOP)
						CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, g_iWinningMapIndex);

					return;
				}
				else
					LogError("Error: %s is an invalid map name, attempting normal map rotation.", g_strCampaignFirstMap[g_iWinningMapIndex]);
			}

			//If no map was chosen in the vote, then go with the automatic map rotation

			if(iMapIndex == NUMBER_OF_CAMPAIGNS - 1)	//Check to see if its the end of the array
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0

			if(IsMapValid(g_strCampaignFirstMap[iMapIndex + 1]) == true)
			{
				PrintToChatAll("\x03[ACS] \x05切换至地图 \x04%s", g_strCampaignName[iMapIndex + 1]);

				if(g_iGameMode == GAMEMODE_VERSUS)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, iMapIndex + 1);
				else if(g_iGameMode == GAMEMODE_COOP)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, iMapIndex + 1);
			}
			else
				LogError("Error: %s is an invalid map name, unable to switch map.", g_strCampaignFirstMap[iMapIndex + 1]);

			return;
		}
	}
}
/*
//Change to the next scavenge map
ChangeScavengeMap()
{
	//Check to see if someone voted for a map, if so, then change to the winning map
	if(g_bVotingEnabled == true && g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0)
	{
		if(IsMapValid(g_strScavengeMap[g_iWinningMapIndex]) == true)
		{
			PrintToChatAll("\x03[ACS] \x05x05切换至票数最多的地图: \x04%s", g_strScavengeMapName[g_iWinningMapIndex]);

			CreateTimer(WAIT_TIME_BEFORE_SWITCH_SCAVENGE, Timer_ChangeScavengeMap, g_iWinningMapIndex);

			return;
		}
		else
			LogError("Error: %s is an invalid map name, attempting normal map rotation.", g_strScavengeMap[g_iWinningMapIndex]);
	}

	//If no map was chosen in the vote, then go with the automatic map rotation

	decl String:strCurrentMap[32];
	GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game

	//Go through all maps and to find which map index it is on, and then switch to the next map
	for(new iMapIndex = 0; iMapIndex < NUMBER_OF_SCAVENGE_MAPS; iMapIndex++)
	{
		if(StrEqual(strCurrentMap, g_strScavengeMap[iMapIndex]) == true)
		{
			if(iMapIndex == NUMBER_OF_SCAVENGE_MAPS - 1)//Check to see if its the end of the array
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0

			//Make sure the map is valid before changing and displaying the message
			if(IsMapValid(g_strScavengeMap[iMapIndex + 1]) == true)
			{
				PrintToChatAll("\x03[ACS] \x05x05切换至地图 \x04%s", g_strScavengeMapName[iMapIndex + 1]);

				CreateTimer(WAIT_TIME_BEFORE_SWITCH_SCAVENGE, Timer_ChangeScavengeMap, iMapIndex + 1);
			}
			else
				LogError("Error: %s is an invalid map name, unable to switch map.", g_strScavengeMap[iMapIndex + 1]);

			return;
		}
	}
}
*/

public int RandomMap(int iCampaignIndex)
{
	iCampaignIndex = GetRandomInt(1, 13);
	if (iCampaignIndex == 1)
		iCampaignIndex = 13;
	return iCampaignIndex;
}

//Change campaign to its index
public Action:Timer_ChangeCampaign(Handle:timer, any:iCampaignIndex)
{
	// 随机官图
	if(iCampaignIndex == 1) {
		RandomMap(iCampaignIndex);
	}

	ServerCommand("changelevel %s", g_strCampaignFirstMap[iCampaignIndex]);	//Change the campaign

	return Plugin_Stop;
}
/*
//Change scavenge map to its index
public Action:Timer_ChangeScavengeMap(Handle:timer, any:iMapIndex)
{
	ServerCommand("changelevel %s", g_strScavengeMap[iMapIndex]);			//Change the map

	return Plugin_Stop;
}
*/
/*======================================================================================
#################            A C S   A D V E R T I S I N G             #################
======================================================================================*/

public Action:Timer_AdvertiseNextMap(Handle:timer, any:iMapIndex)
{
	//If next map advertising is enabled, display the text and start the timer again
	if(g_iNextMapAdDisplayMode != DISPLAY_MODE_DISABLED)
	{
		DisplayNextMapToAll();
		CreateTimer(g_fNextMapAdInterval, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Stop;
}

DisplayNextMapToAll()
{
	//If there is a winner to the vote display the winner if not display the next map in rotation
	/*
	if(g_iWinningMapIndex >= 0)
	{
		if(g_iNextMapAdDisplayMode == DISPLAY_MODE_HINT)
		{
			//Display the map that is currently winning the vote to all the players using hint text
			if(g_iGameMode == GAMEMODE_SCAVENGE)
				PrintHintTextToAll("下一张地图是 %s", g_strScavengeMapName[g_iWinningMapIndex]);
			else
				PrintHintTextToAll("下一张地图是 %s", g_strCampaignName[g_iWinningMapIndex]);
		}
		else if(g_iNextMapAdDisplayMode == DISPLAY_MODE_CHAT)
		{
			//Display the map that is currently winning the vote to all the players using chat text
			if(g_iGameMode == GAMEMODE_SCAVENGE)
				PrintToChatAll("\x03[ACS] \x05下一张地图是 \x04%s", g_strScavengeMapName[g_iWinningMapIndex]);
			else
				PrintToChatAll("\x03[ACS] \x05下一张地图是 \x04%s", g_strCampaignName[g_iWinningMapIndex]);
		}
	}
	else
	{
		decl String:strCurrentMap[32];
		GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game

		if(g_iGameMode == GAMEMODE_SCAVENGE)
		{
			//Go through all maps and to find which map index it is on, and then switch to the next map
			for(new iMapIndex = 0; iMapIndex < NUMBER_OF_SCAVENGE_MAPS; iMapIndex++)
			{
				if(StrEqual(strCurrentMap, g_strScavengeMap[iMapIndex]) == true)
				{
					if(iMapIndex == NUMBER_OF_SCAVENGE_MAPS - 1)	//Check to see if its the end of the array
						iMapIndex = -1;								//If so, start the array over by setting to -1 + 1 = 0

					//Display the next map in the rotation in the appropriate way
					if(g_iNextMapAdDisplayMode == DISPLAY_MODE_HINT)
						PrintHintTextToAll("下一张地图是 %s", g_strScavengeMapName[iMapIndex + 1]);
					else if(g_iNextMapAdDisplayMode == DISPLAY_MODE_CHAT)
						PrintToChatAll("\x03[ACS] \x05下一张地图是 \x04%s", g_strScavengeMapName[iMapIndex + 1]);
				}
			}
		}
		else
		{*/
		//Go through all maps and to find which map index it is on, and then switch to the next map
		decl String:strCurrentMap[32];
		GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game
		for(new iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
		{
			if(StrEqual(strCurrentMap, g_strCampaignLastMap[iMapIndex]) == true)
			{
				if(iMapIndex == NUMBER_OF_CAMPAIGNS - 1)	//Check to see if its the end of the array
					iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0

				//Display the next map in the rotation in the appropriate way
				/*if(g_iNextMapAdDisplayMode == DISPLAY_MODE_HINT)
					PrintHintTextToAll("下一张地图是 %s", g_strCampaignName[iMapIndex + 1]);
				else if(g_iNextMapAdDisplayMode == DISPLAY_MODE_CHAT)*/
				PrintToChatAll("\x03[ACS] \x05下一张地图是 \x04%s", g_strCampaignName[iMapIndex + 1]);
			}
		}
}

/*======================================================================================
#################              V O T I N G   S Y S T E M               #################
======================================================================================*/

/*======================================================================================
################             P L A Y E R   C O M M A N D S              ################
======================================================================================*/

//Command that a player can use to vote/revote for a map/campaign
public Action:MapVote(iClient, args)
{
	if(g_bVotingEnabled == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05投票系统被意外关闭了,请联系管理员开启.");
		return;
	}

	if(OnFinaleOrScavengeMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05只能在救援关投票哦~");
		return;
	}

	//Open the vote menu for the client if they arent using the server console
	if(iClient < 1)
		PrintToServer("You cannot vote for a map from the server console, use the in-game chat.");
	else
		VoteMenuDraw(iClient);
}

//Command that a player can use to see the total votes for all maps/campaigns
public Action:DisplayCurrentVotes(iClient, args)
{
	if(g_bVotingEnabled == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05投票系统被意外关闭了,请联系管理员开启.");
		return;
	}

	if(OnFinaleOrScavengeMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05只能在救援关投票哦~");
		return;
	}

	decl iPlayer, iMap, iNumberOfMaps;

	//Get the total number of maps for the current game mode
	/*
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		iNumberOfMaps = NUMBER_OF_SCAVENGE_MAPS;
	else*/
	iNumberOfMaps = NUMBER_OF_CAMPAIGNS;

	//Display to the client the current winning map
	if(g_iWinningMapIndex != -1)
	{/*
		if(g_iGameMode == GAMEMODE_SCAVENGE)
			PrintToChat(iClient, "\x03[ACS] \x05当前票数最多: \x04%s.", g_strScavengeMapName[g_iWinningMapIndex]);
		else*/
		PrintToChat(iClient, "\x03[ACS] \x05当前票数最多: \x04%s.", g_strCampaignName[g_iWinningMapIndex]);
	}
	else
		PrintToChat(iClient, "\x03[ACS] \x05还没有人投票，输入 !mapvote 进行投票.");

	//Loop through all maps and display the ones that have votes
	new iMapVotes[iNumberOfMaps];

	for(iMap = 0; iMap < iNumberOfMaps; iMap++)
	{
		iMapVotes[iMap] = 0;

		//Tally votes for the current map
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;

		//Display this particular map and its amount of votes it has to the client
		if(iMapVotes[iMap] > 0)
		{/*
			if(g_iGameMode == GAMEMODE_SCAVENGE)
				PrintToChat(iClient, "\x04          %s: \x05%d 票.", g_strScavengeMapName[iMap], iMapVotes[iMap]);
			else*/
			PrintToChat(iClient, "\x04          %s: \x05%d 票.", g_strCampaignName[iMap], iMapVotes[iMap]);
		}
	}
}

/*======================================================================================
###############                   V O T E   M E N U                       ##############
======================================================================================*/

public OnClientPutInServer(client)
{
	if (OnFinaleOrScavengeMap() == true)
		for(new iClient = 1;iClient <= MaxClients; iClient++)
		{
			if(g_bClientShownVoteAd[iClient] == false && g_bClientVoted[iClient] == false && IsClientInGame(iClient) == true && IsFakeClient(iClient) == false)
			{
				VoteMenuDraw(iClient);
				g_bClientShownVoteAd[iClient] = true;
			}
		}
}

/*
//Timer to show the menu to the players if they have not voted yet
public Action:Timer_DisplayVoteAdToAll(Handle:hTimer, any:iData)
{
	if(g_bVotingEnabled == false || OnFinaleOrScavengeMap() == false)
		return Plugin_Stop;

	for(new iClient = 1;iClient <= MaxClients; iClient++)
	{
		if(g_bClientShownVoteAd[iClient] == false && g_bClientVoted[iClient] == false && IsClientInGame(iClient) == true && IsFakeClient(iClient) == false)
		{
			switch(g_iVotingAdDisplayMode)
			{
				case DISPLAY_MODE_MENU: VoteMenuDraw(iClient);
				case DISPLAY_MODE_HINT: PrintHintText(iClient, "投票下一张地图请输入: !mapvote\n查看目前票数请输入: !mapvotes");
				case DISPLAY_MODE_CHAT: PrintToChat(iClient, "\x03[ACS] \x05投票下一张地图请输入: \x04!mapvote\n           \x05查看目前票数请输入: \x04!mapvotes");
			}

			g_bClientShownVoteAd[iClient] = true;
		}
	}

	return Plugin_Stop;
}
*/

//Draw the menu for voting
public Action:VoteMenuDraw(iClient)
{
	if(iClient < 1 || IsClientInGame(iClient) == false || IsFakeClient(iClient) == true)
		return Plugin_Handled;

	//Create the menu
	g_hMenu_Vote[iClient] = CreateMenu(VoteMenuHandler);

	//Give the player the option of not choosing a map
	//AddMenuItem(g_hMenu_Vote[iClient], "option1", "弃权");

	//Populate the menu with the maps in rotation for the corresponding game mode
	/*if(g_iGameMode == GAMEMODE_SCAVENGE)
	{
		SetMenuTitle(g_hMenu_Vote[iClient], "投票选择下一张地图\n ");

		for(new iCampaign = 0; iCampaign < NUMBER_OF_SCAVENGE_MAPS; iCampaign++)
			AddMenuItem(g_hMenu_Vote[iClient], g_strScavengeMapName[iCampaign], g_strScavengeMapName[iCampaign]);
	}
	else
	{*/
	SetMenuTitle(g_hMenu_Vote[iClient], "投票选择下一张地图\n ");

	for(new iCampaign = 0; iCampaign < NUMBER_OF_CAMPAIGNS; iCampaign++)
		AddMenuItem(g_hMenu_Vote[iClient], g_strCampaignName[iCampaign], g_strCampaignName[iCampaign]);

	//Add an exit button
	SetMenuExitButton(g_hMenu_Vote[iClient], false);

	//And finally, show the menu to the client
	DisplayMenu(g_hMenu_Vote[iClient], iClient, MENU_TIME_FOREVER);

	//Play a sound to indicate that the user can vote on a map
	EmitSoundToClient(iClient, SOUND_NEW_VOTE_START);

	return Plugin_Handled;
}

//Handle the menu selection the client chose for voting
public VoteMenuHandler(Handle:hMenu, MenuAction:maAction, iClient, iItemNum)
{
	if(maAction == MenuAction_Select)
	{
		g_bClientVoted[iClient] = true;

		//Set the players current vote
		/*if(iItemNum == 0)
			g_iClientVote[iClient] = -1;
		else*/

		if (iItemNum == 1) {
			int random;
			random = GetRandomInt(1, 13);
			if (random == 1) {
				g_iClientVote[iClient] = 0;
			} else {
				g_iClientVote[iClient] = random;
			}
		} else {
			g_iClientVote[iClient] = iItemNum;// - 1;
		}

		//Check to see if theres a new winner to the vote
		SetTheCurrentVoteWinner();

		//Display the appropriate message to the voter
		/*if(iItemNum == 0)
			PrintToChat(iClient, "\x03[ACS] \x05你还没有投票. 请输入: \x04!mapvote");
		else if(g_iGameMode == GAMEMODE_SCAVENGE)
			PrintToChat(iClient, "你已经投票： %s. - 更改投票请输入: !mapvote - 查看目前票数请输入: !mapvotes", g_strScavengeMapName[iItemNum - 1]);*/
		//else
		PrintToChat(iClient, "\x03[ACS] \x05你已经投票:  \x04%s.\n           \x05更改投票请输入: \x04!mapvote.\n           \x05查看目前票数请输入: \x04!mapvotes.", g_strCampaignName[iItemNum]);
	}
}

//Resets all the menu handles to invalid for every player, until they need it again
CleanUpMenuHandles()
{
	for(new iClient = 0; iClient <= MAXPLAYERS; iClient++)
	{
		if(g_hMenu_Vote[iClient] != INVALID_HANDLE)
		{
			CloseHandle(g_hMenu_Vote[iClient]);
			g_hMenu_Vote[iClient] = INVALID_HANDLE;
		}
	}
}

/*======================================================================================
#########       M I S C E L L A N E O U S   V O T E   F U N C T I O N S        #########
======================================================================================*/

//Resets all the votes for every player
ResetAllVotes()
{
	for(new iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_bClientVoted[iClient] = false;
		g_iClientVote[iClient] = -1;

		//Reset so that the player can see the advertisement
		g_bClientShownVoteAd[iClient] = false;
	}

	//Reset the winning map to NULL
	g_iWinningMapIndex = -1;
	g_iWinningMapVotes = 0;
}

//Tally up all the votes and set the current winner
SetTheCurrentVoteWinner()
{
	decl iPlayer, iMap, iNumberOfMaps;

	//Store the current winnder to see if there is a change
	new iOldWinningMapIndex = g_iWinningMapIndex;

	//Get the total number of maps for the current game mode
	/*if(g_iGameMode == GAMEMODE_SCAVENGE)
		iNumberOfMaps = NUMBER_OF_SCAVENGE_MAPS;
	else*/
	iNumberOfMaps = NUMBER_OF_CAMPAIGNS;

	//Loop through all maps and get the highest voted map
	new iMapVotes[iNumberOfMaps], iCurrentlyWinningMapVoteCounts = 0, bool:bSomeoneHasVoted = false;

	for(iMap = 0; iMap < iNumberOfMaps; iMap++)
	{
		iMapVotes[iMap] = 0;

		//Tally votes for the current map
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;

		//Check if there is at least one vote, if so set the bSomeoneHasVoted to true
		if(bSomeoneHasVoted == false && iMapVotes[iMap] > 0)
			bSomeoneHasVoted = true;

		//Check if the current map has more votes than the currently highest voted map
		if(iMapVotes[iMap] > iCurrentlyWinningMapVoteCounts)
		{
			iCurrentlyWinningMapVoteCounts = iMapVotes[iMap];

			g_iWinningMapIndex = iMap;
			g_iWinningMapVotes = iMapVotes[iMap];
		}
	}

	//If no one has voted, reset the winning map index and votes
	//This is only for if someone votes then their vote is removed
	if(bSomeoneHasVoted == false)
	{
		g_iWinningMapIndex = -1;
		g_iWinningMapVotes = 0;
	}

	//If the vote winner has changed then display the new winner to all the players
	if(g_iWinningMapIndex > -1 && iOldWinningMapIndex != g_iWinningMapIndex)
	{
		//Send sound notification to all players
		if(g_bVoteWinnerSoundEnabled == true)
			for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
				if(IsClientInGame(iPlayer) == true && IsFakeClient(iPlayer) == false)
					EmitSoundToClient(iPlayer, SOUND_NEW_VOTE_WINNER);

		//Show message to all the players of the new vote winner
		/*if(g_iGameMode == GAMEMODE_SCAVENGE)
			PrintToChatAll("\x03[ACS] \x04%s \x05当前票数最多.", g_strScavengeMapName[g_iWinningMapIndex]);
		else*/
		PrintToChatAll("\x03[ACS] \x04%s \x05当前票数最多.", g_strCampaignName[g_iWinningMapIndex]);
	}
}

//Check if the current map is the last in the campaign if not in the Scavenge game mode
bool:OnFinaleOrScavengeMap()
{
	/*if(g_iGameMode == GAMEMODE_SCAVENGE)
		return true;

	if(g_iGameMode == GAMEMODE_SURVIVAL)
		return false;
	*/

	decl String:strCurrentMap[32];
	GetCurrentMap(strCurrentMap,32);			//Get the current map from the game

	//Run through all the maps, if the current map is a last campaign map, return true
	for(new iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
		if(StrEqual(strCurrentMap, g_strCampaignLastMap[iMapIndex]) == true)
			return true;

	return false;
}