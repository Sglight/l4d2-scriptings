/**
 * 启发于 Anne 的对抗模式战役机制，之前也是用他的那套，后来因为想公开插件，他这套东西是不公开的，所以自己写了这个东西。
 * 带来了不少的 bug，但也都能解决，比较麻烦而已，典型的就是 第一回合是 versus，后面几个回合都是 coop，所以 stripper 写起来会很麻烦，
 * 有些地图是对抗和战役两套模式，像闪电突袭2的 m2，一张战役图，一张对抗图，要在 m1 战役模式下也把换图给定向对抗的 m2。
 * 总的来说利大于弊，但是更希望以后能有直接在战役模式下使用对抗特性。
 * 对抗特性有：tank 一拍多，打中人后没有捶胸口捶地板的动作，口水点油（这个 AI 特感好像不能实现），推 ht 猴子 fov 等。
 *
 * 战役 Tank 一拍多：https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_sweep_fist_patch
 * 战役 Tank 打人后无庆祝动作：https://forums.alliedmods.net/showthread.php?t=319029
 * 口水点油：forward Action L4D2_CInsectSwarm_CanHarm(int acid, int spitter, int entity)
 * fov for coop：
 */

#include <sourcemod>
#include <left4dhooks>

#pragma newdecls required

ConVar hGameMode;

public Plugin myinfo =
{
	name = "[L4D2] Versus-Like coop",
	author = "海洋空氣",
	description = "",
	version = "1.1",
	url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
	hGameMode = FindConVar("mp_gamemode");

	HookEvent("round_start",  Event_RoundStart, EventHookMode_Pre);
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(hGameMode, "coop");
	return Plugin_Continue;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarString(hGameMode, "versus");
	return Plugin_Continue;
}