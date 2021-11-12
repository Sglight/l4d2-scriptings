#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Cvar Lock",
	author = "Confogl Team, 闲月疏云",
	description = "服务器参数设置及锁定",
	version = "1.0"
}

enum CLEntry
{
	Handle:h_Cvar,
	String:s_Val[64],
	b_CanAdminChange = 1
}

new Handle:CvarSettingsArray;

public OnPluginStart()
{
	CvarSettingsArray = CreateArray(_:CLEntry);
	
	RegServerCmd("cl_add", OnAddCvar, "将一个变量添加至保护列表");
	RegAdminCmd("cl_change", OnChangeCvar, ADMFLAG_RCON, "改变变量值");
	RegAdminCmd("cl_view", OnViewCvar, ADMFLAG_RCON, "查看变量当前值和锁定值(如果有)");
	RegServerCmd("cl_reset", OnResetCvars, "重置所有变量");
}

public OnMapStart()
{
	new tmpEntry[CLEntry];
	for (new i; i < GetArraySize(CvarSettingsArray); i++)
	{
		GetArrayArray(CvarSettingsArray, i, tmpEntry[0]);
		SetConVarString(tmpEntry[h_Cvar], tmpEntry[s_Val]);
	}
	PrintToServer("所有变量已重置为锁定值");
}

public Action:OnAddCvar(args)
{
	if((args < 2) || (args > 3))
	{
		PrintToServer("命令格式: cl_add <变量名> <变量值> [是否允许管理员更改]");
		return Plugin_Handled;
	}
	
	new String:s_CvarName[64];
	GetCmdArg(1, s_CvarName, sizeof(s_CvarName));
	if(strlen(s_CvarName) >= 64)
	{
		LogMessage("变量名(%s)长度大于上限64！", s_CvarName, 64);
		return Plugin_Handled;
	}

	decl String:s_CvarVal[64];
	GetCmdArg(2, s_CvarVal, sizeof(s_CvarVal));
	if(strlen(s_CvarVal) >= 64)
	{
		LogMessage("变量值(%s)长度大于上限64！", s_CvarVal, 64);
		return Plugin_Handled;
	}

	decl String:s_CanAdminChange[1]
	GetCmdArg(3, s_CanAdminChange, sizeof(s_CanAdminChange));
	
	new Handle:h_CurCvar = FindConVar(s_CvarName);
	if(h_CurCvar == INVALID_HANDLE)
	{
		LogMessage("获取变量 %s 句柄失败！", s_CvarName);
		return Plugin_Handled;
	}

	if(IsCvarContain(s_CvarName) != 0)
	{
		PrintToServer("变量 %s 已被添加至保护列表，请勿重复操作", s_CvarName);
		return Plugin_Handled;
	}
	
	decl newEntry[CLEntry];
	newEntry[h_Cvar] = h_CurCvar;
	strcopy(newEntry[s_Val], 64, s_CvarVal);
	newEntry[b_CanAdminChange] = StringToInt(s_CanAdminChange);
	PushArrayArray(CvarSettingsArray, newEntry[0]);
	HookConVarChange(h_CurCvar, OnConVarChange);
	SetConVarString(h_CurCvar, s_CvarVal);

	return Plugin_Handled;
}

public Action:OnChangeCvar(client, args)
{
	if(args != 2)
	{
		ReplyToCommand(client, "命令格式: cl_change <cvar> <value>");
		return Plugin_Handled;
	}
	
	new String:s_CvarName[64];
	GetCmdArg(1, s_CvarName, sizeof(s_CvarName));
	new Handle:h_CurCvar = FindConVar(s_CvarName);
	if(h_CurCvar == INVALID_HANDLE)
	{
		ReplyToCommand(client, "获取变量 %s 句柄失败！", s_CvarName);
		return Plugin_Handled;
	}

	new index = IsCvarContain(s_CvarName);
	if(index != 0)
	{
		decl tmpEntry[CLEntry];
		GetArrayArray(CvarSettingsArray, index, tmpEntry[0]);
		if(tmpEntry[b_CanAdminChange] != 0)
		{
			decl String:s_NewVal[64];
			GetCmdArg(2, s_NewVal, sizeof(s_NewVal));
			strcopy(tmpEntry[s_Val], 64, s_NewVal);
			SetArrayArray(CvarSettingsArray, index, tmpEntry[0]);
			SetConVarString(h_CurCvar, s_NewVal);
			PrintToServer("被保护变量 %s 的值已锁定为 %s", s_CvarName, s_NewVal);
		}
		else
		{
			ReplyToCommand(client, "变量 %s 不允许更改！", s_CvarName);
		}
	}
	else
	{
		decl String:s_NewVal[64];
		GetCmdArg(2, s_NewVal, sizeof(s_NewVal));
		SetConVarString(h_CurCvar, s_NewVal);
		ReplyToCommand(client, "变量 %s 的值已修改为 %s", s_CvarName, s_NewVal);
	}
	return Plugin_Handled;
}

public Action:OnViewCvar(client, args)
{
	new String:s_CvarName[64];
	GetCmdArg(1, s_CvarName, sizeof(s_CvarName));
	new Handle:h_CurCvar = FindConVar(s_CvarName);
	if(h_CurCvar == INVALID_HANDLE)
	{
		ReplyToCommand(client, "获取变量 %s 句柄失败！", s_CvarName);
		return Plugin_Handled;
	}

	new index = IsCvarContain(s_CvarName);
	if(index != 0)
	{
		decl tmpEntry[CLEntry];
		GetArrayArray(CvarSettingsArray, index, tmpEntry[0]);
		ReplyToCommand(client, "变量 %s 的锁定值为：%s", s_CvarName, tmpEntry[s_Val]);
	}
	new String:s_CurVal[64];
	GetConVarString(h_CurCvar, s_CurVal, sizeof(s_CurVal));
	ReplyToCommand(client, "变量 %s 的当前值为：%s", s_CvarName, s_CurVal);

	return Plugin_Handled;
}

public Action:OnResetCvars(args)
{
	new tmpEntry[CLEntry];
	for (new i; i < GetArraySize(CvarSettingsArray); i++)
	{
		GetArrayArray(CvarSettingsArray, i, tmpEntry[0]);
		UnhookConVarChange(tmpEntry[h_Cvar], OnConVarChange);
	}
	ClearArray(CvarSettingsArray);
	PrintToServer("所有保护变量已被释放！");
	return Plugin_Handled;
}

public OnConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	decl String:s_CvarName[64];
	GetConVarName(convar, s_CvarName, sizeof(s_CvarName));
	new index = IsCvarContain(s_CvarName);
	if(index)
	{
		new tmpEntry[CLEntry];
		GetArrayArray(CvarSettingsArray, index, tmpEntry[0]);
		if(!StrEqual(tmpEntry[s_Val], newValue))
		{
			PrintToServer("尝试修改被保护参数 %s (从 %s 至 %s)，已被拦截", s_CvarName, tmpEntry[s_Val], newValue);
			SetConVarString(tmpEntry[h_Cvar], tmpEntry[s_Val]);
		}
	}
}

IsCvarContain(const String:cvar[])
{
	decl tmpEntry[CLEntry];
	decl String:s_CvarName[64];
	for(new i = 0;i < GetArraySize(CvarSettingsArray);i++)
	{
		GetArrayArray(CvarSettingsArray, i, tmpEntry[0]);
		GetConVarName(tmpEntry[h_Cvar], s_CvarName, 64);
		if(StrEqual(cvar, s_CvarName, false))
			return i;
	}
	return 0;
}