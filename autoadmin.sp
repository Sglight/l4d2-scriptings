#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = { 
    name = "Add non-admins to admin group public", 
    author = "Bacardi", 
    description = "Automatically add non-admins to admin group public", 
    version = "0.1", 
    url = "-" 
}; 

public void OnClientPostAdminCheck(int client) 
{ 
    if (!IsFakeClient(client) && GetUserAdmin(client) == INVALID_ADMIN_ID) 
    { 
        GroupId id = FindAdmGroup("public"); // Need create admin group called "public" in admin_groups.cfg 

        if (id == INVALID_GROUP_ID) 
        { 
            // Didn't find admin group "public" from admin_groups.cfg 
            return; 
        } 

        AdminId admin = CreateAdmin(); 
        SetUserAdmin(client, admin, true); 
        AdminInheritGroup(admin, id); 
    } 
} 