#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>

int SpecClient;
Handle g_hVote = INVALID_HANDLE;

public void OnPluginStart()
{
	RegConsoleCmd("sm_votespec", VoteSpec, "Vote player to spectator.");
}

public Action VoteSpec(int client, int args)
{
	draw_function(client);
}

public Action draw_function(int client)
{
	// 创建面板
	Handle menu = CreateMenu(MenuHandler);
	SetMenuTitle(menu, "投票将玩家移至旁观");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	char userid[12];
	char name[32];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) {
			if (GetClientTeam(i) == 2) {
				IntToString(GetClientUserId(i), userid, sizeof(userid));
				GetClientName(i, name, sizeof(name));
				AddMenuItem(menu, userid, name);
			}
		}
	}
	DisplayMenu(menu, client, 15);
	return Plugin_Handled;
}

public int MenuHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select) {
		char sInfo[64];
		GetMenuItem(menu, itempos, sInfo, 64);
		SpecClient = GetClientOfUserId(StringToInt(sInfo, 10));
		CallVote(cindex);
	}
}

public void CallVote(int client)
{
	if ( IsNewBuiltinVoteAllowed() ) {
		int iNumPlayers;
		int iPlayers[MAXPLAYERS];
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) != 2)) {
				continue;
			}
			iPlayers[iNumPlayers++] = i;
		}

		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "将 %N 移至旁观", SpecClient);

		g_hVote = CreateBuiltinVote(VoteSpecHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 15);
	}
}

public int VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++) {
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES) {
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2)) {
				char sBuffer[64];
				Format(sBuffer, sizeof(sBuffer), "已将 %N 移至旁观", SpecClient);
				DisplayBuiltinVotePass(vote, sBuffer);
				ChangeClientTeam(SpecClient, 1);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public int VoteSpecHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action) {
		case BuiltinVoteAction_End: {
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel: {
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1) );
		}
	}
}

