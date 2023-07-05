/*
*	VScript File Replacer
*	Copyright (C) 2023 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.16"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2 & CS:GO & NMRiH] VScript File Replacer
*	Author	:	SilverShot
*	Descrp	:	Replaces any VScript file with a custom one. Modify lines or the whole file.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318024
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.16 (10-Mar-2023)
	- Changed command "sm_vs_dump" to display the number of scripts dumped.
	- Fixed error when no VScript files or directories exist. Thanks to "Sreaper" for reporting.

1.15 (20-Dec-2022)
	- Added support for Team Fortress 2.
	- GameData file and plugin updated.

1.14 (15-Oct-2022)
	- Added an include file for other plugins to require this plugin.
	- Added registering the plugin library as "vscript_replacer" for plugins to detect.

1.13 (15-Jul-2022)
	- Increased buffer size. Thanks to "Psyk0tik" for reporting.

1.12 (03-Jun-2022)
	- Added support for "NMRiH" game. Thanks to "Dysphie" for the signatures.
	- GameData file and plugin updated.

1.11 (07-Oct-2021)
	- Fixed compile errors on SourcecMod version 1.11. Thanks to "Hajitek Majitek" for reporting.
	- Thanks to "asherkin" for helping fix.

1.10a (10-Apr-2021)
	- Minor change to "vscript_replacer.cfg" for demonstrating regex in map names. Thanks to "Tonblader" for reporting.

1.10 (04-Mar-2021)
	- Added ConVar "vscript_replacer_debug" to enable debugging with options for verbose debugging and printing to chat or server.
	- ConVar config is saved as "vscript_replacer.cfg" filename in your servers standard "cfg/sourcemods" folder.

1.9 (30-Sep-2020)
	- Increased MAX_BUFFER size to support largest known VScript file sizes.

1.8 (20-Jul-2020)
	- Fixed overrides not working. Not sure why this went undetected for so long.

1.7 (10-May-2020)
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.6 (05-May-2020)
	- Added forward "OnVScriptExecuted" to notify plugins when a script is executed (allows blocking or changing).
	- Changed script names to be case insensitive.
	- Fixed leaking handle when searching through directories.
	- Various small changes.

1.5 (03-Feb-2020)
	- Fixed previous update breaking support for scripts within folders. Thanks to "Marttt" for reporting.

1.4 (22-Jan-2020)
	- Added RegEx support for matching multiple script names.
	- Updated "data/vscript_replacer.cfg" to fix Helms Deep patches. All working now.

1.3 (18-Jan-2020)
	- Changed command "sm_vs_exec" to use a logic_script instead, due to script_execute requiring sv_cheats.
	- Fixed not loading scripts where the filename is matched using RegEx. Thanks to "dustinandband" for reporting.
	- Fixed error when reporting duplicate keys in config.
	- Updated "data/vscript_replacer.cfg" to fix Helms Deep patches and added various critical cvars being changed.

1.2 (16-Jan-2020)
	- Added command "sm_vs_exec" to execute a VScript file. This is a wrapper to the function "script_execute".
	- Fixed not using the specified "override" filename. Thanks to "xZk" for reporting.

1.1b (11-Nov-2019)
	- Edited "data/vscripts_override.cfg" data config adding more Helms Deep fixes.
	- No plugin changes.

1.1 (01-Nov-2019)
	- Added command "sm_vs_listen" to print to server console the names of scripts being executed.
	- Fixed command "sm_vs_dump" from copying files from the dump folder.

1.0 (10-Aug-2019)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following scripts.

*	ICE encryption algorithm:
*	Written by Matthew Kwan - December 1996
*	http://www.darkside.com.au/ice/
*
*	Converted from JavaScript to SourcePawn by SilverShot - 19 June 2019

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

// To read/write entire files with char[] buffer via SDKCall for ICE enc/dec (removed before release).
// Without this server receives: "[SM] Exception reported: Instruction contained invalid parameter".
// The largest Valve VScript file I've seen was ~280 KB.
// If you require more please notify me, increase and recompile.
// This is 400 KB (400 * 1024) - only used when saving/decrypting/encrypting files and cleared after.
#define MAX_BUFFER 409600
#pragma dynamic MAX_BUFFER

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <regex>

#define GAMEDATA				"vscript_replacer"
#define CONFIG_DATA				"data/vscripts_override.cfg"
#define MAX_STRING_LENGTH		8192

Handle g_hForwardOnVScript;
StringMap gOverrideCustom;		// "override" script names.
ArrayList gOverrideConfig;		// List of scripts loaded from "vscripts_override.cfg" - includes regex names.
ArrayList gOverrideScripts;		// List of scripts to override generated from above list.
ArrayList gOverrideValues;		// List of values to replace in the scripts
EngineVersion gEngine;
bool g_bLoadNewMap, g_bListen;
ConVar g_hCvarDebug;

// ICE vars
bool g_IceKey;
char g_sICEKey[16];
const int ICE_rounds = 8;
const int ICE_blocks = 8;



// ====================================================================================================
//					PLUGIN INFO
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2 & CS:GO & NMRiH] VScript File Replacer",
	author = "SilverShot",
	description = "Replaces any VScript file with a custom one. Modify lines or the whole file.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318024"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gEngine = GetEngineVersion();
	if( gEngine != Engine_Left4Dead2 && gEngine != Engine_CSGO && gEngine != Engine_TF2 && gEngine != Engine_SDK2013 )
	{
		strcopy(error, err_max, "Your game is unsupported by this plugin.");
		return APLRes_SilentFailure;
	}

	if( gEngine == Engine_SDK2013 )
	{
		char sFolder[PLATFORM_MAX_PATH];
		GetGameFolderName(sFolder, sizeof(sFolder));
		if( strcmp(sFolder, "nmrih") )
		{
			strcopy(error, err_max, "Your game is unsupported by this plugin.");
			return APLRes_SilentFailure;
		}
	}

	RegPluginLibrary("vscript_replacer");

	return APLRes_Success;
}



// ====================================================================================================
//					PLUGIN START
// ====================================================================================================
public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	if( GameConfGetKeyValue(hGameData, "ICEKey", g_sICEKey, sizeof(g_sICEKey)) )
	{
		g_IceKey = true;

		ICE_spBoxInit();
		ICE_IceKeySet(g_sICEKey);
	}



	// ====================================================================================================
	// DETOURS
	// ====================================================================================================
	Handle hDetour = DHookCreateFromConf(hGameData, "VScriptServerCompileScript");
	if( !hDetour ) SetFailState("Failed to find \"VScriptServerCompileScript\" signature.");
	if( !DHookEnableDetour(hDetour, false, VScriptServerCompileScript) ) SetFailState("Failed to detour \"VScriptServerCompileScript\".");
	delete hGameData;
	delete hDetour;



	// ====================================================================================================
	// OTHER
	// ====================================================================================================
	// Forward
	g_hForwardOnVScript = CreateGlobalForward("OnVScriptExecuted", ET_Event, Param_String, Param_String, Param_Cell);

	// Cvars
	g_hCvarDebug = CreateConVar(	"vscript_replacer_debug",		"0",				"0=Off. 1=Print to server. 2=Print to chat. 4=Verbose logging. Add numbers together.", FCVAR_NOTIFY);
	CreateConVar(					"vscript_replacer_version",		PLUGIN_VERSION,		"VScript File Replacer plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "vscript_replacer");

	// Load config
	ResetPlugin();



	// ====================================================================================================
	// COMMANDS
	// ====================================================================================================
	RegAdminCmd("sm_vs_dump",			CmdDump,		ADMFLAG_ROOT, "Dumps all found VScripts from the servers /scripts/vscripts/ file system to /scripts/vscripts/vscripts_dump/. Automatically decodes if required.");
	RegAdminCmd("sm_vs_encrypt",		CmdEncrypt,		ADMFLAG_ROOT, "Usage: sm_vs_encrpt <filename.nut>. Encode the specified script, must be inside the servers /scripts/vscripts/ folder, include the extension.");
	RegAdminCmd("sm_vs_exec",			CmdExec,		ADMFLAG_ROOT, "Usage: sm_vs_exec <filename>. Executes a VScript file. Uses a logic_script instead of requiring sv_cheats like script_execute.");
	RegAdminCmd("sm_vs_file",			CmdFile,		ADMFLAG_ROOT, "Usage: sm_vs_file <filename>. Extracts the specified VScript from the Valve file system to the servers /scripts/vscripts/vscripts_dump/ folder. Automatically decodes if required.");
	RegAdminCmd("sm_vs_list",			CmdList,		ADMFLAG_ROOT, "Show data config tree of modified scripts for the current map.");
	RegAdminCmd("sm_vs_listen",			CmdListen,		ADMFLAG_ROOT, "Toggle printing to server console the names of scripts being executed.");
	RegAdminCmd("sm_vs_reload",			CmdReload,		ADMFLAG_ROOT, "Reloads the data config. This also replaces files in the override folder.");
}

public void OnMapStart()
{
	if( g_bLoadNewMap ) ResetPlugin();
}

public void OnMapEnd()
{
	g_bLoadNewMap = true;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
Action CmdDump(int client, int args)
{
	float time = GetEngineTime();

	// Loop through VScripts files/folders.
	ArrayList aVScriptList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	RecursiveSearchDirs(aVScriptList, "scripts/vscripts");

	// Loop files and save
	int total;
	bool ICE;
	char sPath[PLATFORM_MAX_PATH];

	for( int i = 0; i < aVScriptList.Length; i++ )
	{
		aVScriptList.GetString(i, sPath, sizeof(sPath));

		// Avoid copying our dirs
		if(
			strncmp(sPath[16], "/vscripts_dump/", 15) == 0 ||
			strncmp(sPath[16], "/vscripts_custom/", 17) == 0 ||
			strncmp(sPath[16], "/vscripts_override/", 19) == 0
		) continue;

		// Matches .nuc or .nut
		int len = strlen(sPath);
		if( len > 4 &&
			sPath[len - 4] == '.' &&
			sPath[len - 3] == 'n' &&
			sPath[len - 2] == 'u'
		)
		{
			if( sPath[len - 1] == 'c' )
				ICE = true;
			else if( sPath[len - 1] == 't' )
				ICE = false;
			else continue;
		}
		else continue;

		total++;
		SaveFile(null, "", sPath, ICE, true);
	}

	delete aVScriptList;
	ReplyToCommand(client, "Dumped %d VScripts to servers /scripts/vscripts/vscripts_dump/ folder. Took %f seconds.", total, GetEngineTime() - time);
	return Plugin_Handled;
}

Action CmdEncrypt(int client, int args)
{
	if( args != 1 )
	{
		ReplyToCommand(client, "[SM] Usage: sm_vs_encrpt <filename.nut>");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	char sDest[PLATFORM_MAX_PATH];
	GetCmdArg(1, sPath, sizeof(sPath));

	// Check for VScript
	Format(sDest, sizeof(sDest), "scripts/vscripts/vscripts_dump/%s", sPath);
	Format(sPath, sizeof(sPath), "scripts/vscripts/%s", sPath);

	if( FileExists(sPath, true, NULL_STRING) )
	{
		if( ICE_EncDec(sPath, sDest, true) )
			ReplyToCommand(client, "Saved to /%s folder.", sDest);
		else
			ReplyToCommand(client, "[SM] Failed to encrypt.");
	}
	else
	{
		ReplyToCommand(client, "[SM] Cannot find vscript.");
	}

	return Plugin_Handled;
}

Action CmdExec(int client, int args)
{
	if( args != 1 )
	{
		ReplyToCommand(client, "[SM] Usage: sm_vs_exec <filename>");
		return Plugin_Handled;
	}

	// Games inbuilt method to execute VScripts. In L4D2 "script_execute" causes a memory leak, so using an entity instead.
	// Using an entity would probably prevent the script executing during hibernation, not sure if command would work then either though.
	// char sFile[PLATFORM_MAX_PATH];
	// GetCmdArg(1, sFile, sizeof(sFile));
	// ServerCommand("script_execute %s", sFile);

	int entity = CreateEntityByName("logic_script");
	if( entity != -1 )
	{
		char sFile[PLATFORM_MAX_PATH];
		GetCmdArg(1, sFile, sizeof(sFile));
		DispatchSpawn(entity);
		SetVariantString(sFile);
		AcceptEntityInput(entity, "RunScriptFile");
		RemoveEdict(entity);
	}

	return Plugin_Handled;
}

Action CmdFile(int client, int args)
{
	if( args != 1 )
	{
		ReplyToCommand(client, "[SM] Usage: sm_vs_file <filename>");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	char sFile[PLATFORM_MAX_PATH];
	GetCmdArg(1, sFile, sizeof(sFile));

	// Check for encrypted VScript
	Format(sPath, sizeof(sPath), "scripts/vscripts/%s.nuc", sFile);
	if( FileExists(sPath, true, NULL_STRING) )
	{
		// Decrypt
		SaveFile(null, "", sPath, true, true);
	} else {
		// Check for decrypted
		Format(sPath, sizeof(sPath), "scripts/vscripts/%s.nut", sFile);
		if( FileExists(sPath, true, NULL_STRING) )
		{
			// Save decrypted
			SaveFile(null, "", sPath, false, true);
		}
		else
		{
			ReplyToCommand(client, "[SM] Error: failed to find \"%s\" VScript.", sFile);
			return Plugin_Handled;
		}
	}

	ReplyToCommand(client, "Saved \"%s\" to servers /scripts/vscripts/vscripts_dump/ folder.", sFile);
	return Plugin_Handled;
}

Action CmdList(int client, int args)
{
	char section[PLATFORM_MAX_PATH];
	char custom[PLATFORM_MAX_PATH];

	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== VSCRIPT OVERRIDES =====");
	ReplyToCommand(client, "=============================");

	for( int x = 0; x < gOverrideScripts.Length; x++ )
	{
		// Script names
		gOverrideScripts.GetString(x, section, sizeof(section));
		if( gOverrideCustom.GetString(section, custom, sizeof(custom)) )
			ReplyToCommand(client, "%d) \"%s\" with \"%s\"", x+1, section, custom);
		else
			ReplyToCommand(client, "%d) \"%s\"", x+1, section);

		/*
		// Print script find-replace values. Uncomment section below to enable. Also remove the cleanup of gOverrideValues in ResetPlugin.
		// Works: but spammy with string replacements, also gOverrideValues is not required so keeping that data for this is simply wasted resources.
		// Also requires you to remove the "Array no longer required" section from ResetPlugin to enable.
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];

		ArrayList aHand = gOverrideValues.Get(x);
		int size = aHand.Length;
		for( int i = 0; i < size; i+=2 )
		{
			aHand.GetString(i, key, sizeof(key));
			aHand.GetString(i+1, value, sizeof(value));
			ReplyToCommand(client, "... %s %s", key, value);
		}

		ReplyToCommand(client, "");
		// */
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}

Action CmdReload(int client, int args)
{
	float time = GetEngineTime();
	ResetPlugin();
	ReplyToCommand(client, "Reloaded VScript Replacements. Took %f seconds.", GetEngineTime() - time);
	return Plugin_Handled;
}

Action CmdListen(int client, int args)
{
	g_bListen = !g_bListen;

	if( client )
	{
		if( g_bListen )
			ReplyToCommand(client, "VScript output is printed to server console.");
		ReplyToCommand(client, "VSCRIPT: Listening %s.", g_bListen ? "started" : "stopped");
	}
	PrintToServer("--- VSCRIPT: Listening %s.", g_bListen ? "started" : "stopped");
	return Plugin_Handled;
}



// ====================================================================================================
//					DETOUR
// ====================================================================================================
MRESReturn VScriptServerCompileScript(Handle hReturn, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Get script name
	static char pszScriptOverride[PLATFORM_MAX_PATH];
	static char pszScriptName[PLATFORM_MAX_PATH];
	static char pszScriptFwd[PLATFORM_MAX_PATH];
	pszScriptOverride[0] = 0;
	pszScriptFwd[0] = 0;

	DHookGetParamString(hParams, 1, pszScriptName, sizeof(pszScriptName));
	StrToLowerCase(pszScriptName, pszScriptName, sizeof(pszScriptName));
	ReplaceString(pszScriptName, sizeof(pszScriptName), ".nut", "", false);

	// Match overrides
	int index = gOverrideScripts.FindString(pszScriptName);
	if( index != -1 )
	{
		if( gOverrideCustom.GetString(pszScriptName, pszScriptOverride, sizeof(pszScriptOverride)) )
			Format(pszScriptOverride, sizeof(pszScriptOverride), "vscripts_override/%s", pszScriptOverride);
		else
			Format(pszScriptOverride, sizeof(pszScriptOverride), "vscripts_override/%s", pszScriptName);

		if( g_bListen )
		{
			PrintToServer("--- VSCRIPT: Overriding script: <%s> <%s>", pszScriptName, pszScriptOverride);

			if( g_hCvarDebug.IntValue & 2 )
				PrintToChatAll("--- VSCRIPT: Overriding script: <%s> <%s>", pszScriptName, pszScriptOverride);
		}

		strcopy(pszScriptFwd, sizeof(pszScriptFwd), pszScriptOverride);

		// Forward override VScript
		Action aResult = Plugin_Continue;
		Call_StartForward(g_hForwardOnVScript);
		Call_PushString(pszScriptName);
		Call_PushStringEx(pszScriptFwd, sizeof(pszScriptFwd), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(true);
		Call_Finish(aResult);

		switch( aResult )
		{
			case Plugin_Handled:
			{
				if( g_bListen )
				{
					PrintToServer("--- VSCRIPT: FWD blocked override script: <%s> <%s>", pszScriptName, pszScriptOverride);
					if( g_hCvarDebug.IntValue & 2 )
						PrintToChatAll("--- VSCRIPT: FWD blocked override script: <%s> <%s>", pszScriptName, pszScriptOverride);
				}

				DHookSetReturn(hReturn, 0);
				return MRES_Supercede;
			}

			case Plugin_Changed:
			{
				if( g_bListen )
				{
					PrintToServer("--- VSCRIPT: FWD changed override script: <%s> <%s> to <%s>", pszScriptName, pszScriptOverride, pszScriptFwd);
					if( g_hCvarDebug.IntValue & 2 )
					PrintToChatAll("--- VSCRIPT: FWD changed override script: <%s> <%s> to <%s>", pszScriptName, pszScriptOverride, pszScriptFwd);
				}

				strcopy(pszScriptOverride, sizeof(pszScriptOverride), pszScriptFwd);
			}
		}

		DHookSetParamString(hParams, 1, pszScriptOverride);
		return MRES_ChangedHandled;
	} else {
		// Forward VScript
		Action aResult = Plugin_Continue;
		Call_StartForward(g_hForwardOnVScript);
		Call_PushString(pszScriptName);
		Call_PushStringEx(pszScriptOverride, sizeof(pszScriptOverride), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Call_PushCell(false);
		Call_Finish(aResult);

		switch( aResult )
		{
			case Plugin_Handled:
			{
				if( g_bListen )
				{
					PrintToServer("--- VSCRIPT: FWD blocked script: <%s>", pszScriptName);
					if( g_hCvarDebug.IntValue & 2 )
						PrintToChatAll("--- VSCRIPT: FWD blocked script: <%s>", pszScriptName);
				}

				DHookSetReturn(hReturn, 0);
				return MRES_Supercede;
			}

			case Plugin_Changed:
			{
				if( g_bListen )
				{
					PrintToServer("--- VSCRIPT: FWD changed script: <%s> to <%s>", pszScriptName, pszScriptOverride);
					if( g_hCvarDebug.IntValue & 2 )
						PrintToChatAll("--- VSCRIPT: FWD changed script: <%s> to <%s>", pszScriptName, pszScriptOverride);
				}

				DHookSetParamString(hParams, 1, pszScriptOverride);
				return MRES_ChangedHandled;
			}
		}
	}

	// Listen
	if( g_bListen )
	{
		PrintToServer("--- VSCRIPT: Exec: <%s>", pszScriptName);
		if( g_hCvarDebug.IntValue & 2 )
			PrintToChatAll("--- VSCRIPT: Exec: <%s>", pszScriptName);
	}

	return MRES_Ignored;
}



// ====================================================================================================
//					RESET PLUGIN
// ====================================================================================================
void ResetPlugin()
{
	g_bLoadNewMap = false;

	// Clear array of script names
	if( gOverrideScripts != null )
		gOverrideScripts.Clear();
	else
		gOverrideScripts = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	if( gOverrideConfig != null )
		gOverrideConfig.Clear();
	else
		gOverrideConfig = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	// Array of scripts to override
	delete gOverrideCustom;
	gOverrideCustom = CreateTrie();

	// Array of values to replace
	gOverrideValues = new ArrayList();

	// Load again
	LoadConfig();

	// Save replaced scripts
	SaveOverrides();

	// Array no longer required
	ArrayList aHand;
	int size = gOverrideValues.Length;
	for( int i = 0; i < size; i++ )
	{
		aHand = gOverrideValues.Get(i);
		delete aHand;
	}
	delete gOverrideValues;
}



// ====================================================================================================
//					SAVE OVERRIDES
// ====================================================================================================
void SaveOverrides()
{
	// Vars
	char sFile[PLATFORM_MAX_PATH];
	char sPath[PLATFORM_MAX_PATH];
	char sTemp[PLATFORM_MAX_PATH];
	ArrayList aVScriptList;
	ArrayList aHand;



	// Create folders
	sPath = "scripts/vscripts";
	if( DirExists(sPath) == false )
		CreateDirectory(sPath, 511);

	sPath = "scripts/vscripts/vscripts_custom";
	if( DirExists(sPath) == false )
		CreateDirectory(sPath, 511);

	sPath = "scripts/vscripts/vscripts_override";
	if( DirExists(sPath) == false )
		CreateDirectory(sPath, 511);



	// Create files
	File hFile;

	sPath = "scripts/vscripts/vscripts_custom/_CUSTOM_FILES_HERE";
	if( !FileExists(sPath) )
	{
		hFile = OpenFile(sPath, "wb");
		delete hFile;
	}

	sPath = "scripts/vscripts/vscripts_override/_DO_NOT_USE_FOLDER";
	if( !FileExists(sPath) )
	{
		hFile = OpenFile(sPath, "wb");
		delete hFile;
	}



	// Loop through "override" scripts then all other scripts to override and replace strings
	bool overrideFirst = true;
	int index;

	for( int x = 0; x < gOverrideConfig.Length; x++ )
	{
		// Script filename
		gOverrideConfig.GetString(x, sFile, sizeof(sFile));

		// Debug
		if( g_hCvarDebug.IntValue & 4 )
		{
			if( g_hCvarDebug.IntValue & 1 )
			{
				PrintToServer("--- VSCRIPT: Replacer File: %s.", sFile);
			}
			if( g_hCvarDebug.IntValue & 2 )
			{
				PrintToChatAll("--- VSCRIPT: Replacer File: %s.", sFile);
			}
		}

		// Check for "override" key in each scripts values from config.
		aHand = gOverrideValues.Get(x);

		// Check for "override" files
		if( overrideFirst )
		{
			index = aHand.FindString("override");

			// Found
			if( index != -1 )
			{
				// Get custom script name
				aHand.GetString(index + 1, sPath, sizeof(sPath));
				StrToLowerCase(sPath, sPath, sizeof(sPath));
				gOverrideCustom.SetString(sFile, sPath);

				// Debug
				if( g_hCvarDebug.IntValue & 4 )
				{
					if( g_hCvarDebug.IntValue & 1 )
					{
						PrintToServer("--- VSCRIPT: Replacer Path: %s.", sPath);
					}
					if( g_hCvarDebug.IntValue & 2 )
					{
						PrintToChatAll("--- VSCRIPT: Replacer Path: %s.", sPath);
					}
				}

				// Save to vscripts/vscripts_override folder
				strcopy(sTemp, sizeof(sTemp), sFile);
				Format(sPath, sizeof(sPath), "scripts/vscripts/vscripts_custom/%s.nut", sPath);
				SaveFile(aHand, sTemp, sPath);
			}

			// Exit override searching loop, re-loop with non-override files
			if( x + 1 == gOverrideConfig.Length)
			{
				overrideFirst = false;
				x = -1;
			}
		} else {
			// Regex search for file
			index = aHand.FindString("regex");
			if( index != -1 )
			{
				aHand.GetString(index + 1, sPath, sizeof(sPath)); // Re-using sPath
				if( StringToInt(sPath) == 2 ) // Regex string search only
					index = -1;
			}

			// Regex match file
			if( index != -1 )
			{
				// Only generate full VScript list once in loop
				if( aVScriptList == null )
				{
					aVScriptList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

					// Loop through VScripts files/folders.
					RecursiveSearchDirs(aVScriptList, "scripts/vscripts");
				}

				// Find override script within all found VScripts
				for( int i = 0; i < aVScriptList.Length; i++ )
				{
					aVScriptList.GetString(i, sPath, sizeof(sPath)); // Re-using sPath
					if( SimpleRegexMatch(sPath, sFile) > 0 )
					{
						// Remove extension
						int pos = FindCharInString(sPath, '.', true);
						sPath[pos] = '\x0';

						strcopy(sTemp, sizeof(sTemp), sPath[17]); // After "scripts/vscripts/"

						// Has override file? Edit that instead
						if( gOverrideCustom.GetString(sTemp, sPath, sizeof(sPath)) )
						{
							Format(sPath, sizeof(sPath), "scripts/vscripts/vscripts_override/%s.nuc", sPath);
						}
						// Already modified? Re-run replacements
						else if( gOverrideScripts.FindString(sTemp) != -1 )
						{
							Format(sPath, sizeof(sPath), "scripts/vscripts/vscripts_override/%s.nuc", sTemp);
						} else {
							Format(sPath, sizeof(sPath), "scripts/vscripts/%s.nuc", sTemp);
						}

						ValidateFileSave(aHand, sPath, sTemp);
					}
				}
			} else {
				// Has override file? Edit that instead
				if( gOverrideCustom.GetString(sFile, sPath, sizeof(sPath)) )
				{
					Format(sPath, sizeof(sPath), "scripts/vscripts/vscripts_override/%s.nuc", sPath);
				} else {
					Format(sPath, sizeof(sPath), "scripts/vscripts/%s.nuc", sFile);
				}

				ValidateFileSave(aHand, sPath, sFile);
			}
		}
	}

	gOverrideConfig.Clear();
	delete aVScriptList;
}

void ValidateFileSave(ArrayList aHand, char sPath[PLATFORM_MAX_PATH], const char sFile[PLATFORM_MAX_PATH])
{
	// Check for encrypted VScript
	if( FileExists(sPath, true, NULL_STRING) )
	{
		// Decrypt
		SaveFile(aHand, sFile, sPath, true);
	} else {
		// Check for decrypted
		sPath[strlen(sPath) - 1] = 't';

		if( FileExists(sPath, true, NULL_STRING) )
		{
			// Save decrypted
			SaveFile(aHand, sFile, sPath);
		} else {
			LogError("Missing file: Cannot find VScript \"%s\" to override.", sPath);
			return;
		}
	}
}

void SaveFile(ArrayList aHand, const char[] sFile, const char[] filename, bool ICE = false, bool dump = false)
{
	// Open .nuc/.nut
	File hFile = OpenFile(filename, "rb", true, NULL_STRING);
	if( hFile == null )
	{
		LogError("Failed to open file for reading: \"%s\"", filename);
		return;
	}

	// Load file
	char buffer[MAX_BUFFER];
	int len = FileSize(filename, true, NULL_STRING);
	hFile.ReadString(buffer, sizeof(buffer), len);
	delete hFile;

	// Decode
	if( ICE && g_IceKey )
	{
		int bytes[9];
		int bytesLeft = len;

		// Decode in 8 byte blocks
		while( bytesLeft >= ICE_blocks )
		{
			ICE_decrypt(buffer[len - bytesLeft], bytes);

			// Overwrite buffer with parsed data
			for( int i = 0; i < ICE_blocks; i++ )
			{
				buffer[len - bytesLeft + i] = bytes[i];
			}

			bytesLeft -= ICE_blocks;
		}
	}

	// Make our edits
	if( aHand != null )
	{
		int size = aHand.Length;
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];

		// Check if RegEx search required
		Regex regex;
		bool doRegex;
		char error[256];

		len = aHand.FindString("regex");
		if( len != -1 )
		{
			aHand.GetString(len+1, value, sizeof(value));
			if( StringToInt(value) > 1 )
				doRegex = true;
		}

		for( int i = 0; i < size; i+=2 )
		{
			aHand.GetString(i, key, sizeof(key));
			aHand.GetString(i+1, value, sizeof(value));

			// Don't replace the reserved "override" and "regex" keys
			if( strcmp(key, "override") && strcmp(key, "regex") )
			{
				// RegEx search string
				if( doRegex )
				{
					regex = new Regex(key, 0, error, sizeof(error));
					if( regex == null )
					{
						LogError("[VScript Replacer] Error with search value: \"%s\". Regex error: %s", key, error);
					} else {
						while( (len = regex.Match(buffer)) > 0 )
						{
							if( regex.GetSubString(0, key, sizeof(key)) )
							{
								ReplaceString(buffer, sizeof(buffer), key, "_SILVERS_REPLACE_IDENT_");
							}
						}

						// MatchRegex only returns 2 matches, which is why the MatchRegex is in a loop.
						// Because it parses the buffer several times we avoid an endless loop if the replacement string would also match.
						ReplaceString(buffer, sizeof(buffer), "_SILVERS_REPLACE_IDENT_", value);
						delete regex;
					}
				}
				else
				{
					// Standard find-replace string.
					ReplaceString(buffer, sizeof(buffer), key, value);
				}
			}
		}
	}

	// Change path
	char sPath[PLATFORM_MAX_PATH];
	strcopy(sPath, sizeof(sPath), filename);
	ReplaceString(sPath, sizeof(sPath), ".nuc", ".nut");

	// Saving to specific folders
	if( dump )
	{
		ReplaceString(sPath, sizeof(sPath), "scripts/vscripts/", "scripts/vscripts/vscripts_dump/");
	}
	else
	{
		if( ReplaceString(sPath, sizeof(sPath), "scripts/vscripts/vscripts_custom/", "scripts/vscripts/vscripts_override/") == 0 )
			if( strncmp(sPath, "scripts/vscripts/vscripts_override/", 35) )
				ReplaceString(sPath, sizeof(sPath), "scripts/vscripts/", "scripts/vscripts/vscripts_override/");
	}

	// Save to file.
	CreateDirs(sPath);

	hFile = OpenFile(sPath, "wb");
	if( hFile == null )
	{
		LogError("Failed to open file for saving: \"%s\"", sPath);
		return;
	}

	if( !dump )
	{
		if( gOverrideScripts.FindString(sFile) == -1 )
		{
			gOverrideScripts.PushString(sFile);
			hFile.WriteString("//--------------------------------------------------\n// This file is auto generated do not hand edit!\n//--------------------------------------------------\n\n", false);
		}
	}

	hFile.WriteString(buffer, false);
	delete hFile;
}

void RecursiveSearchDirs(ArrayList aVScriptList, const char[] sDir)
{
	char sPath[PLATFORM_MAX_PATH];
	DirectoryListing hDir;
	FileType type;

	hDir = OpenDirectory(sDir, true, NULL_STRING);
	if( !hDir ) return;

	// Loop through files
	while( hDir.GetNext(sPath, sizeof(sPath), type) )
	{
		// Ignore "." and ".."
		if( strcmp(sPath, ".") && strcmp(sPath, "..") )
		{
			// Avoid our dirs
			if(
				strncmp(sDir[16], "/vscripts_dump", 14) == 0 ||
				strncmp(sDir[16], "/vscripts_custom", 16) == 0 ||
				strncmp(sDir[16], "/vscripts_override", 18) == 0
			) continue;

			// Unknown filetype = Valve file system
			if( type == FileType_Unknown )
			{
				// Matches .nuc or .nut
				int len = strlen(sPath);
				if( len > 4 &&
					sPath[len - 4] == '.' &&
					sPath[len - 3] == 'n' &&
					sPath[len - 2] == 'u'
				)
				{
					// Save file
					Format(sPath, sizeof(sPath), "%s/%s", sDir, sPath);
					aVScriptList.PushString(sPath);
				} else {
					// Another directory?
					Format(sPath, sizeof(sPath), "%s/%s", sDir, sPath);
					if( DirExists(sPath, true) )
					{
						// Add these files too
						RecursiveSearchDirs(aVScriptList, sPath);
					}
				}
			}
			else if( type == FileType_Directory )
			{
				// Add these files too
				Format(sPath, sizeof(sPath), "%s/%s", sDir, sPath);
				RecursiveSearchDirs(aVScriptList, sPath);
			}
			else if( type == FileType_File )
			{
				// Matches .nuc or .nut
				int len = strlen(sPath);
				if( len > 4 &&
					sPath[len - 4] == '.' &&
					sPath[len - 3] == 'n' &&
					sPath[len - 2] == 'u'
				)
				{
					if( sPath[len - 1] != 'c' && sPath[len - 1] != 't' )
						continue;

					Format(sPath, sizeof(sPath), "%s/%s", sDir, sPath);
					aVScriptList.PushString(sPath);
				}
			}
		}
	}

	delete hDir;
}

// Given a filename, create all missing folders and sub-folders to the path
void CreateDirs(const char[] sFile)
{
	char sPath[PLATFORM_MAX_PATH];
	char sPart[PLATFORM_MAX_PATH];
	char sDir[PLATFORM_MAX_PATH];
	strcopy(sPath, sizeof(sPath), sFile);

	int pos;
	while( (pos = SplitString(sPath, "/", sPart, sizeof(sPart))) != -1 )
	{
		strcopy(sPath, sizeof(sPath), sPath[pos]);
		StrCat(sDir, sizeof(sDir), "/");
		StrCat(sDir, sizeof(sDir), sPart);

		if( DirExists(sDir) == false )
		{
			CreateDirectory(sDir, 511);
		}
	}
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
bool g_bAllowSection;
int g_iSectionLevel;

void LoadConfig()
{
	g_bAllowSection = false;
	g_iSectionLevel = 0;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( FileExists(sPath) )
		ParseConfigFile(sPath);
}

bool ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line, col;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		if( parser.GetErrorString(result, error, sizeof(error)) )
			SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
		else
			SetFailState("Unable to load config. Bad format? Check for missing { } etc.");
	}

	delete parser;
	return (result == SMCError_Okay);
}

SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_iSectionLevel++;

	// Debug
	if( g_hCvarDebug.IntValue & 4 )
	{
		if( g_hCvarDebug.IntValue & 1 )
		{
			PrintToServer("--- VSCRIPT: Section: <%s>", section);
		}
		if( g_hCvarDebug.IntValue & 2 )
		{
			PrintToChatAll("--- VSCRIPT: Section: <%s>", section);
		}
	}

	static char sMap[PLATFORM_MAX_PATH];
	sMap[0] = 0;

	// Map names
	if( g_iSectionLevel == 2 )
	{
		g_bAllowSection = false;

		GetCurrentMap(sMap, sizeof(sMap));

		// Debug
		if( g_hCvarDebug.IntValue & 4 )
		{
			if( g_hCvarDebug.IntValue & 1 )
			{
				PrintToServer("--- VSCRIPT: sMap: <%s>", sMap);
			}
			if( g_hCvarDebug.IntValue & 2 )
			{
				PrintToChatAll("--- VSCRIPT: sMap: <%s>", sMap);
			}
		}

		// Match
		if( SimpleRegexMatch(sMap, section) > 0 )
		{
			g_bAllowSection = true;
		}
	}

	// Script names
	if( g_bAllowSection && g_iSectionLevel == 3 )
	{
		StrToLowerCase(section, sMap, sizeof(sMap));

		// Unique
		if( gOverrideConfig.FindString(sMap) == -1 )
		{
			// Store script name
			gOverrideConfig.PushString(sMap);

			// ArrayList to store values
			ArrayList aHand = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
			gOverrideValues.Push(aHand);
		} else {
			g_bAllowSection = false;
			LogError("Duplicate script name: \"%s\" detected. Please fix your config.", sMap);
		}
	}

	return SMCParse_Continue;
}

SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// Debug
	if( g_hCvarDebug.IntValue & 4 )
	{
		if( g_hCvarDebug.IntValue & 1 )
		{
			PrintToServer("--- VSCRIPT: key: <%s>", key);
			PrintToServer("--- VSCRIPT: value: <%s>", value);
		}
		if( g_hCvarDebug.IntValue & 2 )
		{
			PrintToChatAll("--- VSCRIPT: key: <%s>", key);
			PrintToChatAll("--- VSCRIPT: value: <%s>", value);
		}
	}

	if( g_bAllowSection )
	{
		if( g_iSectionLevel == 3 )
		{
			// Handle to current section being read
			ArrayList aHand = gOverrideValues.Get(gOverrideValues.Length - 1);

			// Verify unique key
			int index = aHand.FindString(key);
			if( index == -1 )
			{
				aHand.PushString(key);
				aHand.PushString(value);
			} else {
				char section[64];
				gOverrideConfig.GetString(gOverrideConfig.Length - 1, section, sizeof(section));
				LogError("Duplicate key: \"%s\" detected in \"%s\". Please fix your config.", key, section);
			}
		}
	}

	return SMCParse_Continue;
}

SMCResult Config_EndSection(Handle parser)
{
	g_iSectionLevel--;
	return SMCParse_Continue;
}

void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the VScripts Override config.");
}

void StrToLowerCase(const char[] input, char[] output, int maxlength)
{
	int pos;
	while( input[pos] != 0 && pos < maxlength )
	{
		output[pos] = CharToLower(input[pos]);
		pos++;
	}

	output[pos] = 0;
}



// ====================================================================================================
//					ICE ENCRYPTION
// ====================================================================================================
// ICE vars
int keySchedule[8][3];
int spBox[4][1024];

int sMod[][] =
{
	{333, 313, 505, 369},
	{379, 375, 319, 391},
	{361, 445, 451, 397},
	{397, 425, 395, 505}
};

int sXor[][] =
{
	{0x83, 0x85, 0x9B, 0xCD},
	{0xCC, 0xA7, 0xAD, 0x41},
	{0x4B, 0x2E, 0xD4, 0x33},
	{0xEA, 0xCB, 0x2E, 0x04}
};

int pBox[] =
{
	0x00000001, 0x00000080, 0x00000400, 0x00002000,
	0x00080000, 0x00200000, 0x01000000, 0x40000000,
	0x00000008, 0x00000020, 0x00000100, 0x00004000,
	0x00010000, 0x00800000, 0x04000000, 0x20000000,
	0x00000004, 0x00000010, 0x00000200, 0x00008000,
	0x00020000, 0x00400000, 0x08000000, 0x10000000,
	0x00000002, 0x00000040, 0x00000800, 0x00001000,
	0x00040000, 0x00100000, 0x02000000, 0x80000000
};

int keyrot[] =
{
	0, 1, 2, 3, 2, 1, 3, 0,
	1, 3, 2, 0, 3, 1, 0, 2
};

// Convert file (encrypt/decrypt)
bool ICE_EncDec(char sPath[PLATFORM_MAX_PATH], char sDest[PLATFORM_MAX_PATH], bool encrypt)
{
	if( FileExists(sPath, true, NULL_STRING) )
	{
		File hFile = OpenFile(sPath, "rb", true, NULL_STRING);
		if( hFile != null )
		{
			// READ
			int len = FileSize(sPath, true, NULL_STRING);
			char buffer[MAX_BUFFER];

			hFile.ReadString(buffer, sizeof(buffer), len);
			delete hFile;

			// WRITE
			hFile = OpenFile(sDest, "wb");
			if( hFile != null )
			{
				// DO
				int bytes[9];
				int bytesLeft = len;

				while( bytesLeft >= ICE_blocks )
				{
					if( encrypt )
						ICE_encrypt(buffer[len - bytesLeft], bytes);
					else
						ICE_decrypt(buffer[len - bytesLeft], bytes);

					// Write binary, to include null bytes
					hFile.Write(bytes, ICE_blocks, 1);

					// Overwrite buffer with parsed data
					for( int i = 0; i < ICE_blocks; i++ )
					{
						buffer[len - bytesLeft + i] = bytes[i];
					}

					bytesLeft -= ICE_blocks;
				}

				// The end chunk doesn't get an encryption...
				hFile.WriteString(buffer[len - bytesLeft], false);

				delete hFile;
				return true;
			}
		}
	}

	return false;
}

// Initialise the substitution/permutation boxes.
void ICE_spBoxInit()
{
	int col, row, x;

	for( int i = 0; i < 1024; i++ )
	{
		col = (i >>> 1) & 0xFF;
		row = (i & 0x1) | ((i & 0x200) >>> 8);

		x = ICE_gf_exp7 (col ^ sXor[0][row], sMod[0][row]) << 24;
		spBox[0][i] = ICE_perm32 (x);

		x = ICE_gf_exp7 (col ^ sXor[1][row], sMod[1][row]) << 16;
		spBox[1][i] = ICE_perm32 (x);

		x = ICE_gf_exp7 (col ^ sXor[2][row], sMod[2][row]) << 8;
		spBox[2][i] = ICE_perm32 (x);

		x = ICE_gf_exp7 (col ^ sXor[3][row], sMod[3][row]);
		spBox[3][i] = ICE_perm32 (x);
	}
}

// 8-bit Galois Field exponentiation.
// Raise the base to the power of 7, modulo m.
int ICE_gf_exp7(int b, int m)
{
	if( b == 0 ) return 0;

	int x;
	x = ICE_gf_mult (b, b, m);
	x = ICE_gf_mult (b, x, m);
	x = ICE_gf_mult (x, x, m);
	return ICE_gf_mult(b, x, m);
}

// 8-bit Galois Field multiplication of a by b, modulo m.
// Just like arithmetic multiplication, except that
// additions and subtractions are replaced by XOR.
int ICE_gf_mult(int a, int b, int m)
{
	int res;

	while( b != 0 )
	{
		if( (b & 1) != 0 )
			res ^= a;

		a <<= 1;
		b >>>= 1;

		if( a >= 256 )
			a ^= m;
	}

	return res;
}

// Carry out the ICE 32-bit permutation.
int ICE_perm32(int x)
{
	int res, i;

	while( x != 0 )
	{
		if( (x & 1) != 0 )
			res |= pBox[i];
		i++;
		x >>>= 1;
	}

	return res;
}

// Set 8 rounds [n, n+7] of the key schedule of an ICE key.
void ICE_scheduleBuild(int[] kb, int n, int krot_idx)
{
	int i, j, k, kr, curr_sk, curr_kb, bit, subkey[3];

	for( i = 0; i < 8; i++ )
	{
		kr = keyrot[krot_idx + i];
		subkey = keySchedule[n + i];

		for( j = 0; j < 3; j++ )
			keySchedule[n + i][j] = 0;

		for( j = 0; j < 15; j++ )
		{
			curr_sk = j % 3;

			for( k = 0; k < 4; k++ )
			{
				curr_kb = kb[(kr + k) & 3];
				bit = curr_kb & 1;

				subkey[curr_sk] = (subkey[curr_sk] << 1) | bit;
				keySchedule[n + i][curr_sk] = (keySchedule[n + i][curr_sk] << 1) | bit;
				kb[(kr + k) & 3] = (curr_kb >>> 1) | ((bit ^ 1) << 15);
			}
		}
	}
}

// Set the key schedule of an ICE key.
void ICE_IceKeySet(char[] key)
{
	int i, kb[4];

	for( i = 0; i < 4; i++ )
		kb[3 - i] = ((view_as<int>(key[i*2]) & 0xFF) << 8) | (view_as<int>(key[i*2 + 1]) & 0xFF);

	ICE_scheduleBuild (kb, 0, 0);
}

// The single round ICE f function.
int ICE_roundFunc(int p, int subkey[3])
{
	int tl, tr;
	int al, ar;

	tl = ((p >>> 16) & 0x3FF) | (((p >>> 14) | (p << 18)) & 0xFFC00);
	tr = (p & 0x3FF) | ((p << 2) & 0xFFC00);

	al = subkey[2] & (tl ^ tr);
	ar = al ^ tr;
	al ^= tl;

	al ^= subkey[0];
	ar ^= subkey[1];

	return spBox[0][al >>> 10] | spBox[1][al & 0x3FF]
		| spBox[2][ar >>> 10] | spBox[3][ar & 0x3FF];
}

// Encrypt a block of 8 bytes of data.
void ICE_encrypt(char[] plaintext, int ciphertext[9])
{
	int i, l, r;

	for( i = 0; i < 4; i++ )
	{
		l |= (plaintext[i] & 0xFF) << (24 - i*8);
		r |= (plaintext[i + 4] & 0xFF) << (24 - i*8);
	}

	for( i = 0; i < ICE_rounds; i += 2 )
	{
		l ^= ICE_roundFunc (r, keySchedule[i]);
		r ^= ICE_roundFunc (l, keySchedule[i + 1]);
	}

	for( i = 0; i < 4; i++ )
	{
		ciphertext[3 - i] = (r & 0xFF);
		ciphertext[7 - i] = (l & 0xFF);

		r >>>= 8;
		l >>>= 8;
	}
}

// Decrypt a block of 8 bytes of data.
void ICE_decrypt(char[] ciphertext, int plaintext[9])
{
	int i, l, r;

	for( i = 0; i < 4; i++ )
	{
		l |= (ciphertext[i] & 0xFF) << (24 - i*8);
		r |= (ciphertext[i + 4] & 0xFF) << (24 - i*8);
	}

	for( i = ICE_rounds - 1; i > 0; i -= 2 )
	{
		l ^= ICE_roundFunc (r, keySchedule[i]);
		r ^= ICE_roundFunc (l, keySchedule[i - 1]);
	}

	for( i = 0; i < 4; i++ )
	{
		plaintext[3 - i] = (r & 0xFF);
		plaintext[7 - i] = (l & 0xFF);

		r >>>= 8;
		l >>>= 8;
	}
}