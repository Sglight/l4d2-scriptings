#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"v1.2.5"

//Define the wait time after round before changing to the next map in each game mode
#define WAIT_TIME_BEFORE_SWITCH_COOP			6.0
#define WAIT_TIME_BEFORE_SWITCH_VERSUS			6.0

//Define Game Modes
#define GAMEMODE_UNKNOWN	-1
#define GAMEMODE_COOP 		0
#define GAMEMODE_VERSUS 	1
#define GAMEMODE_SCAVENGE 	2
#define GAMEMODE_SURVIVAL 	3

#define SOUND_NEW_VOTE_START	"ui/Beep_SynthTone01.wav"
#define SOUND_NEW_VOTE_WINNER	"ui/alert_clink.wav"

#define STRING_MAX_LENGTH 64

//Global Variables
int g_iGameMode;					//Integer to store the gamemode

//Campaign and map strings/names
ArrayList g_arrayCampaignFirstMap;
ArrayList g_arrayDisplayName;
int g_iCampaignCount = 0;

//Voting Variables
float g_fNextMapAdInterval = 300.0;						//Interval for ACS next map advertisement
bool g_bClientShownVoteAd[MAXPLAYERS + 1];				//If the client has seen the ad already
bool g_bClientVoted[MAXPLAYERS + 1];					//If the client has voted on a map
int g_iClientVote[MAXPLAYERS + 1];							//The value of the clients vote
int g_iWinningMapIndex;										//Winning map/campaign's index
int g_iWinningMapVotes;										//Winning map/campaign's number of votes
Handle g_hMenu_Vote[MAXPLAYERS + 1]	= {INVALID_HANDLE, ...};	//Handle for each players vote menu

// KeyValues
KeyValues g_hKvMaps;

Handle hSDKC_IsMissionFinalMap = INVALID_HANDLE;

void SetupMapKvStrings()
{
	char sBuffer[64];
	g_hKvMaps = CreateKeyValues("acs_maps");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/acs_maps.txt");
	if (!FileToKeyValues(g_hKvMaps, sBuffer))
	{
		SetFailState("Couldn't load configs/acs_maps.txt!");
	}

	g_arrayCampaignFirstMap = new ArrayList(STRING_MAX_LENGTH);
	g_arrayDisplayName = new ArrayList(STRING_MAX_LENGTH);
	
	GetMapsList(g_arrayCampaignFirstMap, g_arrayDisplayName);
}

bool GetMapsList(ArrayList arrayCampaignFirstMap, ArrayList arrayDisplayName)
{
	KvRewind(g_hKvMaps);
	if (KvGotoFirstSubKey(g_hKvMaps))
	{
		do {
			char strCampaignFirstMap[STRING_MAX_LENGTH];
			char strDisplayName[STRING_MAX_LENGTH];
			g_hKvMaps.GetSectionName(strCampaignFirstMap, STRING_MAX_LENGTH);
			g_hKvMaps.GetString("display_name", strDisplayName, STRING_MAX_LENGTH);

			arrayCampaignFirstMap.PushString(strCampaignFirstMap);
			arrayDisplayName.PushString(strDisplayName);

			g_iCampaignCount++;
		} while (KvGotoNextKey(g_hKvMaps));
	}
	return false;
}

/*======================================================================================
#####################             P L U G I N   I N F O             ####################
======================================================================================*/

public Plugin myinfo =
{
	name = "Automatic Campaign Switcher (ACS)",
	author = "Chris Pringle, 海洋空氣",
	description = "Automatically switches to the next campaign when the previous campaign is over",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=156392"
}

/*======================================================================================
#################             O N   P L U G I N   S T A R T            #################
======================================================================================*/

public void OnPluginStart()
{
	Handle g_hDHooksConf = LoadGameConfigFile("left4dhooks.l4d2");
	if(g_hDHooksConf == INVALID_HANDLE) {
		SetFailState("Couldn't find \"gamedata/left4dhooks.l4d2.txt\". Please, check that it is installed correctly.");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hDHooksConf, SDKConf_Signature, "CTerrorGameRules::IsMissionFinalMap");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	hSDKC_IsMissionFinalMap = EndPrepSDKCall();
	if(hSDKC_IsMissionFinalMap == INVALID_HANDLE)
		PrintToServer("Failed to find CTerrorGameRules::IsMissionFinalMap signature.");

	//Get the strings for all of the maps that are in rotation
	SetupMapKvStrings();

	//Create custom console variables
	CreateConVar("acs_version", PLUGIN_VERSION, "Version of Automatic Campaign Switcher (ACS) on this server", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("finale_win", Event_FinaleWin);
	HookEvent("player_disconnect", Event_PlayerDisconnect);

	//Register custom console commands
	RegConsoleCmd("mapvote", MapVote);
	RegConsoleCmd("mapvotes", DisplayCurrentVotes);
}

public Action ACSTest(int iClient, int args)
{
	GetMapsList(g_arrayCampaignFirstMap, g_arrayDisplayName);
	for (int i = 0; i < g_arrayCampaignFirstMap.Length; i++) {
		char sBuffer[STRING_MAX_LENGTH];
		g_arrayCampaignFirstMap.GetString(i, sBuffer, STRING_MAX_LENGTH);
		PrintToServer("arrayCampaignFirstMap: %s", sBuffer);
		g_arrayDisplayName.GetString(i, sBuffer, STRING_MAX_LENGTH);
		PrintToServer("arrayDisplayName: %s", sBuffer);
	}
	return Plugin_Continue;
}

public bool L4D_IsMissionFinalMap(){
  return view_as<bool>(hSDKC_IsMissionFinalMap == INVALID_HANDLE ? -1 : SDKCall(hSDKC_IsMissionFinalMap));
}

/*======================================================================================
#################                     E V E N T S                      #################
======================================================================================*/

public void OnMapStart()
{
	//Set all the menu handles to invalid
	CleanUpMenuHandles();

	//Set the game mode
	FindGameMode();

	//Precache sounds
	PrecacheSound(SOUND_NEW_VOTE_START);
	PrecacheSound(SOUND_NEW_VOTE_WINNER);


	//Display advertising for the next campaign or map
	CreateTimer(g_fNextMapAdInterval, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);

	ResetAllVotes();				//Reset every player's vote
}

//Event fired when a finale is won
public Action Event_FinaleWin(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	//Change to the next campaign
	if(g_iGameMode == GAMEMODE_COOP)
		CheckMapForChange();

	return Plugin_Continue;
}

//Event fired when a player disconnects from the server
public Action Event_PlayerDisconnect(Handle hEvent, const char[] strName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

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
void FindGameMode()
{
	//Get the gamemode string from the game
	char strGameMode[20];
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
void CheckMapForChange()
{
	if(L4D_IsMissionFinalMap())
	{
		//Check to see if someone voted for a campaign, if so, then change to the winning campaign
		if(g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0)
		{
			char strCampaignFirstMap[STRING_MAX_LENGTH];
			char strDisplayName[STRING_MAX_LENGTH];
			g_arrayCampaignFirstMap.GetString(g_iWinningMapIndex, strCampaignFirstMap, STRING_MAX_LENGTH);
			g_arrayDisplayName.GetString(g_iWinningMapIndex, strDisplayName, STRING_MAX_LENGTH);
			if(IsMapValid(strCampaignFirstMap) == true)
			{
				PrintToChatAll("\x03[ACS] \x05切换至票数最多的地图: \x04%s", strDisplayName);

				if(g_iGameMode == GAMEMODE_VERSUS)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, g_iWinningMapIndex);
				else if(g_iGameMode == GAMEMODE_COOP)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, g_iWinningMapIndex);

				return;
			}
			else
			{
				PrintToChatAll("地图不存在");
				LogError("Error: %s is an invalid map name, attempting normal map rotation.", strCampaignFirstMap);
			}
		}

		//If no map was chosen in the vote, then go random map
		int iMapIndex = RandomMap();
		char strCampaignFirstMap[STRING_MAX_LENGTH];
		char strDisplayName[STRING_MAX_LENGTH];
		g_arrayCampaignFirstMap.GetString(iMapIndex, strCampaignFirstMap, STRING_MAX_LENGTH);
		g_arrayDisplayName.GetString(iMapIndex, strDisplayName, STRING_MAX_LENGTH);

		if(IsMapValid(strCampaignFirstMap) == true)
		{
			PrintToChatAll("\x03[ACS] \x05切换至地图 \x04%s", strDisplayName);

			if(g_iGameMode == GAMEMODE_VERSUS)
				CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, iMapIndex);
			else if(g_iGameMode == GAMEMODE_COOP)
				CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, iMapIndex);
		}
		else
			LogError("Error: %s is an invalid map name, unable to switch map.", strCampaignFirstMap);

		return;
	}
}

public int RandomMap()
{
	int iCampaignIndex = GetRandomInt(1, 13);
	if (iCampaignIndex == 1)
		iCampaignIndex = 13;
	return iCampaignIndex;
}

//Change campaign to its index
public Action Timer_ChangeCampaign(Handle timer, int iCampaignIndex)
{
	// 随机官图
	if(iCampaignIndex == 1) {
		iCampaignIndex = RandomMap();
	}

	char strCampaignFirstMap[STRING_MAX_LENGTH];
	g_arrayCampaignFirstMap.GetString(iCampaignIndex, strCampaignFirstMap, STRING_MAX_LENGTH);

	ServerCommand("changelevel %s", strCampaignFirstMap);	//Change the campaign

	return Plugin_Stop;
}

/*======================================================================================
#################            A C S   A D V E R T I S I N G             #################
======================================================================================*/

public Action Timer_AdvertiseNextMap(Handle timer, int iMapIndex)
{
	//If next map advertising is enabled, display the text and start the timer again
	DisplayNextMapToAll();
	CreateTimer(g_fNextMapAdInterval, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Stop;
}

void DisplayNextMapToAll()
{
	//If there is a winner to the vote display the winner if not display the next map in rotation
	if(g_iWinningMapIndex >= 0) {
		char strDisplayName[STRING_MAX_LENGTH];
		g_arrayDisplayName.GetString(g_iWinningMapIndex, strDisplayName, STRING_MAX_LENGTH);
		PrintToChatAll("\x03[ACS] \x05下一张地图是 \x04%s", strDisplayName);
	}
	else
	{
		PrintToChatAll("\x03[ACS] \x05无人投票，章节结束将更换至\x04随机官图");
	}
}

/*======================================================================================
#################              V O T I N G   S Y S T E M               #################
======================================================================================*/

/*======================================================================================
################             P L A Y E R   C O M M A N D S              ################
======================================================================================*/

//Command that a player can use to vote/revote for a map/campaign
public Action MapVote(int iClient, int args)
{
	if(L4D_IsMissionFinalMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05只能在救援关投票哦~");
		return Plugin_Handled;
	}

	//Open the vote menu for the client if they arent using the server console
	if(iClient < 1)
		PrintToServer("You cannot vote for a map from the server console, use the in-game chat.");
	else
		VoteMenuDraw(iClient);
	return Plugin_Continue;
}

//Command that a player can use to see the total votes for all maps/campaigns
public Action DisplayCurrentVotes(int iClient, int args)
{
	if(L4D_IsMissionFinalMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05只能在救援关投票哦~");
		return Plugin_Handled;
	}

	int iPlayer, iMap;

	//Get the total number of maps for the current game mode
	// iNumberOfMaps = NUMBER_OF_CAMPAIGNS;

	//Display to the client the current winning map
	if(g_iWinningMapIndex != -1)
	{
		char strDisplayName[STRING_MAX_LENGTH];
		g_arrayDisplayName.GetString(g_iWinningMapIndex, strDisplayName, STRING_MAX_LENGTH);
		PrintToChat(iClient, "\x03[ACS] \x05当前票数最多: \x04%s.", strDisplayName);
	}
	else
		PrintToChat(iClient, "\x03[ACS] \x05还没有人投票，输入 !mapvote 进行投票.");

	//Loop through all maps and display the ones that have votes
	int[] iMapVotes = new int[g_iCampaignCount];

	for(iMap = 0; iMap < g_iCampaignCount; iMap++)
	{
		iMapVotes[iMap] = 0;

		//Tally votes for the current map
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;

		//Display this particular map and its amount of votes it has to the client
		if(iMapVotes[iMap] > 0)
		{
			char strDisplayName[STRING_MAX_LENGTH];
			g_arrayDisplayName.GetString(iMap, strDisplayName, STRING_MAX_LENGTH);
			PrintToChat(iClient, "\x04          %s: \x05%d 票.", strDisplayName, iMapVotes[iMap]);
		}
	}
	return Plugin_Continue;
}

/*======================================================================================
###############                   V O T E   M E N U                       ##############
======================================================================================*/

public void OnClientPutInServer(int client)
{
	if (L4D_IsMissionFinalMap() == true)
		for(int iClient = 1;iClient <= MaxClients; iClient++)
		{
			if(g_bClientShownVoteAd[iClient] == false && g_bClientVoted[iClient] == false && IsClientInGame(iClient) == true && IsFakeClient(iClient) == false)
			{
				VoteMenuDraw(iClient);
				g_bClientShownVoteAd[iClient] = true;
			}
		}
}

//Draw the menu for voting
public Action VoteMenuDraw(int iClient)
{
	if(iClient < 1 || IsClientInGame(iClient) == false || IsFakeClient(iClient) == true)
		return Plugin_Handled;

	//Create the menu
	g_hMenu_Vote[iClient] = CreateMenu(VoteMenuHandler);

	//Populate the menu with the maps in rotation for the corresponding game mode

	SetMenuTitle(g_hMenu_Vote[iClient], "投票选择下一张地图\n ");

	for(int iCampaign = 0; iCampaign < g_iCampaignCount; iCampaign++)
	{
		char strDisplayName[STRING_MAX_LENGTH];
		g_arrayDisplayName.GetString(iCampaign, strDisplayName, STRING_MAX_LENGTH);
		AddMenuItem(g_hMenu_Vote[iClient], strDisplayName, strDisplayName);
	}

	//Add an exit button
	SetMenuExitButton(g_hMenu_Vote[iClient], false);

	//And finally, show the menu to the client
	DisplayMenu(g_hMenu_Vote[iClient], iClient, MENU_TIME_FOREVER);

	//Play a sound to indicate that the user can vote on a map
	EmitSoundToClient(iClient, SOUND_NEW_VOTE_START);

	return Plugin_Handled;
}

//Handle the menu selection the client chose for voting
public int VoteMenuHandler(Handle hMenu, MenuAction maAction, int iClient, int iItemNum)
{
	if(maAction == MenuAction_Select)
	{
		g_bClientVoted[iClient] = true;

		//Set the players current vote
		g_iClientVote[iClient] = iItemNum;

		//Check to see if theres a new winner to the vote
		SetTheCurrentVoteWinner();

		//Display the appropriate message to the voter
		if(iItemNum == 0)
			PrintToChat(iClient, "\x03[ACS] \x05你还没有投票. 请输入: \x04!mapvote \x05进行投票");
		else {
			char strDisplayName[STRING_MAX_LENGTH];
			g_arrayDisplayName.GetString(iItemNum, strDisplayName, STRING_MAX_LENGTH);
			PrintToChat(iClient, "\x03[ACS] \x05你已经投票:  \x04%s.\n           \x05更改投票请输入: \x04!mapvote\n           \x05查看目前票数请输入: \x04!mapvotes", strDisplayName);
		}
	}
	return 1;
}

//Resets all the menu handles to invalid for every player, until they need it again
void CleanUpMenuHandles()
{
	for(int iClient = 0; iClient <= MAXPLAYERS; iClient++)
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
void ResetAllVotes()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
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
void SetTheCurrentVoteWinner()
{
	int iPlayer, iMap, iNumberOfMaps;

	//Store the current winnder to see if there is a change
	int iOldWinningMapIndex = g_iWinningMapIndex;

	//Get the total number of maps for the current game mode
	// iNumberOfMaps = NUMBER_OF_CAMPAIGNS;

	//Loop through all maps and get the highest voted map
	// int iMapVotes[NUMBER_OF_CAMPAIGNS] = {0, ...};
	int[] iMapVotes = new int[g_iCampaignCount];
	int iCurrentlyWinningMapVoteCounts = 0;
	bool bSomeoneHasVoted = false;

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
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(IsClientInGame(iPlayer) == true && IsFakeClient(iPlayer) == false)
				EmitSoundToClient(iPlayer, SOUND_NEW_VOTE_WINNER);

		//Show message to all the players of the new vote winner
		char strDisplayName[STRING_MAX_LENGTH];
		g_arrayDisplayName.GetString(g_iWinningMapIndex, strDisplayName, STRING_MAX_LENGTH);
		PrintToChatAll("\x03[ACS] \x04%s \x05当前票数最多.", strDisplayName);
	}
}