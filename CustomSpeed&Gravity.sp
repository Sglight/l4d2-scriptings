/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <sdkhooks>

#define KnifeSpeed 1.2
#define KnifeGravity 0.8

public Plugin:myinfo = 
{
	name = "CustomSpeed&Gravity",
	author = "apocalyptic",
	description = "gives player your custom speed and gravity when he is holding a knife",
	version = "1.0",
	url = "<- URL ->"
}

public OnClientPutInServer(client) 
{ 
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost) 
} 

public OnClientDisconnect(client) 
{ 
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost) 
}  

public OnWeaponSwitchPost(client, weapon) 
{
	new String:Wpn[24] 
	GetClientWeapon(client,Wpn,24)
	if (StrEqual(Wpn,"weapon_knife"))
	{
		SetClientSpeed(client,KnifeSpeed)
		SetEntityGravity(client,KnifeGravity)
	}
	else
	{
		SetClientSpeed(client,1.0)
		SetEntityGravity(client,1.0)
	}
} 

public SetClientSpeed(client,Float:speed) 
{ 
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue",speed)
}  