/**
 * 启发于 Anne 的对抗模式战役机制，之前也是用他的那套，后来因为想公开插件，他这套东西是不公开的，所以自己写了这个东西。
 * 带来了不少的 bug，但也都能解决，比较麻烦而已，典型的就是 第一回合是 versus，后面几个回合都是 coop，所以 stripper 写起来会很麻烦，
 * 有些地图是对抗和战役两套模式，像闪电突袭2的 m2，一张战役图，一张对抗图，要在 m1 战役模式下也把换图给定向对抗的 m2。
 * 总的来说利大于弊，但是更希望以后能有直接在战役模式下使用对抗特性。
 * 对抗特性有：tank 一拍多，打中人后没有捶胸口捶地板的动作，口水点油（这个 AI 特感好像不能实现），推 ht 猴子 fov 等。
 * 刚看了下代码发现 L4D2_OnEndVersusModeRound 下的 if 条件像是在放屁，如果不需要的话也能减少个引用，懒得试了。 
 */

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma newdecls required

Handle gameMode;

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
	gameMode = FindConVar("mp_gamemode");
	HookEvent("round_start",  Event_RoundStart, EventHookMode_Pre);
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	SetConVarString(gameMode, "coop");
	return Plugin_Handled;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	SetConVarString(gameMode, "versus");
}