/**
 * 哈哈，这是个没实装的插件，启发于 Apex Legends 的标记。
 * 现在也是能标记，但是光圈不会消失。
 * 两种情况使光圈消失，一是时间到了，二是物品被捡起了。
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

int OUR_COLOR[3] = 255;
int showEntity[MAXPLAYERS + 1];
bool allowSelect[MAXPLAYERS + 1];
enum L4D2GlowType 
{ 
    L4D2Glow_None = 0, 
    L4D2Glow_OnUse, 
    L4D2Glow_OnLookAt, 
    L4D2Glow_Constant 
} 

public Plugin myinfo =
{
    name = "[L4D2] Highlight entity when client click zoom",
    author = "海洋空氣",
    description = "",
    version = "0.1",
    url = "https://steamcommunity.com/id/larkspur2017/"
};

public void OnPluginStart()
{
    OUR_COLOR[0] = 0;
    OUR_COLOR[1] = 255;
    OUR_COLOR[2] = 0;

    for (int i = 1; i <= MaxClients; ++i)
    {
        allowSelect[i] = true;
        showEntity[i] = -1;
    }
    HookEvent("use_target", Event_UseTarget);
}

public void OnClientPutInServer(int client)
{
    // SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanSwitchTo);
}

public Action Event_UseTarget(Handle event, const char[] name, bool dontBroadcast)
{
    PrintToChatAll("Event_UseTarget");
}

/* public Action OnWeaponCanSwitchTo(int client, int weapon)
{
    PrintToChatAll("%N, weapon: %d", client, weapon);
} */

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsValidClient(client)) return;
    if (!allowSelect[client]) return;
    // if (buttons == IN_ZOOM)
    if (impulse == 201 || buttons == IN_ZOOM)
    {
        int entity = GetClientAimTarget(client, false); // 获取玩家瞄准的实体
        if (!IsValidEntity(entity)) return;

        if (showEntity[client] != -1)
        {
            ResetGlow(entity); // 已选中实体，先清除原光圈
        }
        char entityClass[64];
        GetEntityClassname(entity, entityClass, sizeof(entityClass));
        if (StrContains(entityClass, "weapon") < 0) return;
        L4D2_SetEntGlow(entity, L4D2Glow_Constant, 3250, 0, OUR_COLOR, false);
        // PrintToChatAll("%s", entityClass);
        PrintToChatAll("%N pinged %s(%d)", client, entityClass, entity);
        allowSelect[client] = false;
        showEntity[client] = entity;
        CreateTimer(1.0, Timer_EnableSelect, client);
        CreateTimer(10.0, Timer_ResetGlow, entity);
    }
}

public Action Timer_EnableSelect(Handle timer, int client)
{
    allowSelect[client] = true;
}

public Action Timer_ResetGlow(Handle timer, int entity)
{
    ResetGlow(entity);
}

public void ResetGlow(int entity)
{
    L4D2_SetEntGlow(entity, L4D2Glow_None, 0, 0, OUR_COLOR, false);
    for (int i = 1; i <= MaxClients; ++i) // 清除所有标记该实体的玩家的标记
    {
        if (showEntity[i] == entity)
        {
            showEntity[i] = -1;
        }
    }
}

/**
 * Set entity glow type.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
void L4D2_SetEntGlow_Type(int entity, L4D2GlowType type)
{
    SetEntProp(entity, Prop_Send, "m_iGlowType", view_as<int>(type));
}

/**
 * Set entity glow range.
 *
 * @param entity        Entity index.
 * @parma range            Glow range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
void L4D2_SetEntGlow_Range(int entity, int range)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
}

/**
 * Set entity glow min range.
 *
 * @param entity        Entity index.
 * @parma minRange        Glow min range.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
void L4D2_SetEntGlow_MinRange(int entity, int minRange)
{
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
}

/**
 * Set entity glow color.
 *
 * @param entity        Entity index.
 * @parma colorOverride    Glow color, RGB.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
void L4D2_SetEntGlow_ColorOverride(int entity, int colorOverride[3])
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
}

/**
 * Set entity glow flashing state.
 *
 * @param entity        Entity index.
 * @parma flashing        Whether glow will be flashing.
 * @noreturn
 * @error                Invalid entity index or entity does not support glow.
 */
void L4D2_SetEntGlow_Flashing(int entity, bool flashing)
{
    SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
bool L4D2_SetEntGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
    char netclass[128];
    GetEntityNetClass(entity, netclass, 128);

    int offset = FindSendPropInfo(netclass, "m_iGlowType");
    if (offset < 1)
    {
        return false;    
    }

    L4D2_SetEntGlow_Type(entity, type);
    L4D2_SetEntGlow_Range(entity, range);
    L4D2_SetEntGlow_MinRange(entity, minRange);
    L4D2_SetEntGlow_ColorOverride(entity, colorOverride);
    L4D2_SetEntGlow_Flashing(entity, flashing);
    return true;
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client);
}