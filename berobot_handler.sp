#define PLUGIN_NAME "Giant Robot Plugin Handler"
#define PLUGIN_DESCRIPTION "Handles backstab modifier as well as other functions for the giant robot plugins"
#define PLUGIN_AUTHOR "Fragancia & Heavy Is GPS"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_URL "Balancemod.tf"

#include <morecolors_newsyntax>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf_ontakedamage>

// #include <stocksoup/memory>
// #include <stocksoup/tf/entity_prop_stocks>
// #include <stocksoup/tf/tempents_stocks>
// #include <stocksoup/tf/weapon>



#include <dhooks>
#include <tf2attributes>

#pragma newdecls required
#pragma semicolon 1

enum //Convar names
{
    CV_flSpyBackStabModifier,
    CV_bDebugMode,
    CV_flYoutuberMode,
    CV_PluginVersion
}
/* Global Variables */

/* Global Handles */

//Handle g_hGameConf;

/* Dhooks */

/* Convar Handles */

ConVar g_cvCvarList[CV_PluginVersion + 1];

/* Convar related global variables */

bool g_cv_bDebugMode;

bool g_cv_BlockTeamSwitch = false;

bool g_cv_Volunteered[MAXPLAYERS + 1];

float g_CV_flSpyBackStabModifier;
float g_CV_flYoutuberMode;

int g_Volunteercount = 0;
int g_RoboCap = 6;

ArrayList g_Volunteers;

// Handle g_SDKCallInternalGetEffectBarRechargeTime;
// Handle g_SDKCallIsBaseEntityWeapon;

//In Global Scope

Handle g_hRegen;
Handle g_hGameConf;

//In OnPluginStart


// Global scope


public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};
public void OnPluginStart()
{
    /* Convars */


    g_cvCvarList[CV_PluginVersion] = CreateConVar("bm_yt_v_mvm_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_CHEAT);
    g_cvCvarList[CV_bDebugMode] = CreateConVar("bm_yt_v_mvm_debug", "1", "Enable Debugging for Market Garden and Reserve Shooter damage", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvCvarList[CV_flSpyBackStabModifier] = CreateConVar("bm_yt_mvm_backstab_reduction", "500.0", "Backstab damage");
    g_cvCvarList[CV_flYoutuberMode] = CreateConVar("bm_yt_mode", "0", "Uses youtuber mode for the official mode to set youtubers as the proper classes");

    /* Convar global variables init */

    g_cv_bDebugMode = GetConVarBool(g_cvCvarList[CV_bDebugMode]);
    g_CV_flSpyBackStabModifier = GetConVarFloat(g_cvCvarList[CV_flSpyBackStabModifier]);
    g_CV_flYoutuberMode = GetConVarFloat(g_cvCvarList[CV_flYoutuberMode]);


    /* Convar Change Hooks */

    g_cvCvarList[CV_bDebugMode].AddChangeHook(CvarChangeHook);
    g_cvCvarList[CV_flSpyBackStabModifier].AddChangeHook(CvarChangeHook);
    g_cvCvarList[CV_flYoutuberMode].AddChangeHook(CvarChangeHook);

    RegAdminCmd("sm_gr_start", Command_YT_Robot_Start, ADMFLAG_SLAY, "Sets up the team and starts the robot");
    RegConsoleCmd("sm_volunteer", Command_Volunteer, "Volunters you to be a giant robot");

    g_Volunteers = new ArrayList(ByteCountToCells(g_RoboCap));

    g_cv_BlockTeamSwitch = false;
    for(int i = 0; i < MAXPLAYERS; i++)
    {
        g_cv_Volunteered[i] = false;
    }

    g_hGameConf = LoadGameConfigFile("sm-tf2.games");
    if(g_hGameConf == null)
        SetFailState("Failed to setup gamedata!");

    g_hRegen = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
    if(g_hRegen == null)
        SetFailState("Failed to setup OnRegenerate hook!");

    if(!DHookSetFromConf(g_hRegen, g_hGameConf, SDKConf_Signature, "Regenerate"))
        SetFailState("Failed to config Regenerate signature!");

    DHookAddParam(g_hRegen, HookParamType_Bool);

    if(!DHookEnableDetour(g_hRegen, false, OnRegenerate))
        SetFailState("Failed to detour OnRegenerate!");

    delete g_hGameConf;
}

/* Publics */

public MRESReturn OnRegenerate(int pThis, Handle hReturn, Handle hParams)
{
    //int client = GetClientOfUserId(GetEventInt(pThis, "userid"));
    //Write the code you want here, consult dhooks.inc for return types and so on
    // PrintToChatAll("MRESReturn trigger");
    if(isMiniBoss(pThis))
        return MRES_Supercede;

    return MRES_Ignored;
}


public void CvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    if(convar == g_cvCvarList[CV_bDebugMode])
        g_cv_bDebugMode = view_as<bool>(StringToInt(sNewValue));
    if(convar == g_cvCvarList[CV_flSpyBackStabModifier])
        g_CV_flSpyBackStabModifier = StringToFloat(sNewValue);
    if(convar == g_cvCvarList[CV_flYoutuberMode])
        g_CV_flYoutuberMode = StringToFloat(sNewValue);
}

/* Plugin Exclusive Functions */
public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom, CritType &critType)
{
    if(IsValidClient(victim))
    {
        if(IsValidClient(attacker))
        {
            TFClassType iClass = TF2_GetPlayerClass(attacker);
            if(iClass == TFClass_Spy)
            {
                // Checks if boss is on
                if(g_cv_bDebugMode)
                    //   PrintToChatAll("Attacker was spy");
                    if(isMiniBoss(victim) && damagecustom == TF_CUSTOM_BACKSTAB)
                    {
                        damage = g_CV_flSpyBackStabModifier;
                        if(g_cv_bDebugMode)
                            //    PrintToChatAll("Set damage to %f", damage);
                            return Plugin_Changed;
                    }
            }
        }
    }
    return Plugin_Continue;
}

// intercept and block client jointeam command if required
public Action Command_YT_Robot_Start(int client, int args)
{
    if(!g_cv_BlockTeamSwitch)
    {
        PrintToChat(client, "[SM] Starting Giant Robot Event mode");
        g_cv_BlockTeamSwitch = true;
        ServerCommand("mp_forceautoteam 0");
        ServerCommand("mp_teams_unbalance_limit 0");
        ServerCommand("mp_disable_respawn_times 1");
        ServerCommand("sm_cvar tf_dropped_weapon_lifetime 0");
    }
    else
    {
        g_cv_BlockTeamSwitch = false;
        PrintToChat(client, "[SM] Stopping Giant Robot Event mode");
        ServerCommand("mp_forceautoteam 1");
        ServerCommand("sm_cvar tf_dropped_weapon_lifetime 30");
        ServerCommand("mp_teams_unbalance_limit 1");
        ServerCommand("mp_disable_respawn_times 0");
    }

    if(g_cv_BlockTeamSwitch)
    {

        if(g_CV_flYoutuberMode)
        {
            ServerCommand("sm_ct @all red");
            ServerCommand("sm_ct @blue red");

            //Loops through all players and checks if the set ID's are present. Then sets them on blue while the rest is red
            for(int i = 1; i < MAXPLAYERS; i++)
            {

                if(IsClientInGame(i) && IsValidClient(i))
                {

                    char sSteamID[64];
                    GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
                    int playerID = GetClientUserId(i);

                    //PrintToChatAll("Looping on %i", playerID);
                    //Hardcoding
                    //GPS
                    if(StrEqual(sSteamID, "76561197963998743"))
                    {
                        ServerCommand("sm_begps #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }

                    //Bearded
                    if(StrEqual(sSteamID, "76561198031657211"))
                    {
                        ServerCommand("sm_bebearded #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }


                    //ArraySeven
                    if(StrEqual(sSteamID, "76561198013749611"))
                    {
                        ServerCommand("sm_bearray #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }

                    //Uncle Dane
                    if(StrEqual(sSteamID, "76561198057999536"))
                    {
                        ServerCommand("sm_bedane #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }

                    //Agro
                    if(StrEqual(sSteamID, "76561197970498549"))
                    {
                        ServerCommand("sm_beagro #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }

                    //Solar
                    if(StrEqual(sSteamID, "76561198070962612"))
                    {
                        ServerCommand("sm_besolar #%i", playerID);
                        ServerCommand("sm_ct #%i blue", playerID);
                    }
                }
            }

            // ServerCommand("sm_begps %i", i);
            // ServerCommand("sm_bebearded %i", i);
            // ServerCommand("sm_bearray %i", i);
            // ServerCommand("sm_besolar %i", i);
            // ServerCommand("sm_beagro %i", i);
            // ServerCommand("sm_bedane %i", i);


            //PrintToChat(client, "AuthId_SteamID64 = %s", sSteamID);

            // int SteamID64;
            // Format(sSteamID, sizeof SteamID64, "%i %s", SteamID64, sSteamID);

            //PrintToChatAll("SteamID64 %i", SteamID64);


            //
        }
        else
        {

            for(int i = 1; i < MAXPLAYERS; i++)
            {

                if(IsClientInGame(i) && IsValidClient(i))
                {
                    char sSteamID[64];
                    GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
                    int playerID = GetClientUserId(i);

                    ServerCommand("sm_ct #%i red", playerID);
                }
            }
            // Go through all the volunteers
            // for(int i = 1; i < MAXPLAYERS; i++)
            // {

            //    char sSteamID[64];
            //    GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
            //     int playerID = GetClientUserId(i);

            //     if(IsClientInGame(i) && IsValidClient(i) && g_cv_Volunteered[i])
            //     {
            //        ServerCommand("sm_begps #%i", playerID);
            //        ServerCommand("sm_ct #%i blue", playerID);
            //     }
            // }
        }
    }
}

public Action Command_Volunteer(int client, int args)
{

    if(g_RoboCap == g_Volunteers.Length)
    {

        MC_PrintToChatEx(client, client, "{teamcolor}The max amount of %i robots has been reached", g_RoboCap);

        return Plugin_Handled;
    }

    if(!g_cv_Volunteered[client])
    {
        g_cv_Volunteered[client] = true;

        g_Volunteers.Push(client);

        //PrintToChat(client, "You have volunteered to be a giant robot");
    }
    else //Remove from volunteer list
    {
        g_cv_Volunteered[client] = false;

        int index = FindValueInArray(g_Volunteers, client);
        g_Volunteers.Erase(index);

        MC_PrintToChatEx(client, client, "{teamcolor}You are not volunteering to be a giant robot anymore");
    }

    for(int i = 0; i < g_Volunteers.Length; i++)
    {

        int clientId = g_Volunteers.Get(i);
        if(IsValidClient(clientId) && IsClientInGame(clientId))
        {

            MC_PrintToChatAllEx(client, "{teamcolor}%N {default}has volunteered to be a giant robot", clientId);
        }
    }

    PrintToChatAll("%i arraylength", g_Volunteers.Length);
}

public Action OnClientCommand(int client, int args)
{
    char cmd[16];

    /* Get the argument */
    GetCmdArg(0, cmd, sizeof(cmd));

    TFTeam iTeam = view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_iTeamNum"));

    if(strcmp(cmd, "jointeam", true) == 0)
    {

        if(g_cv_BlockTeamSwitch)
        {
            PrintToChat(client, "[SM] Event mode activated: You are not currently allowed to change teams.");

            //If someone joins while the event is going, set correct player team

            if(iTeam == TFTeam_Unassigned)
            {

                //Add logic here to determine which team is bot team
                ChangeClientTeam(client, TFTeam_Red);
                TF2_SetPlayerClass(client, TFClass_Heavy);
                TF2_RespawnPlayer(client);
            }

            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}


bool isMiniBoss(int client)
{

    if(IsValidClient(client))
    {

        if(GetEntProp(client, Prop_Send, "m_bIsMiniBoss") == 1)
        {
            if(g_cv_bDebugMode)
                //     PrintToChatAll("Was mini boss");
                return true;
        }
        else
        {
            if(g_cv_bDebugMode)
                //    PrintToChatAll("Was not mini boss");
                return false;
        }
    }
    return false;
}


/* Stocks */
stock bool IsValidClient(int client, bool replaycheck = true)
{
    if(client <= 0 || client > MaxClients)
        return false;
    if(!IsClientInGame(client))
        return false;
    if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
        return false;
    if(replaycheck)
    {
        if(IsClientSourceTV(client) || IsClientReplay(client))
            return false;
    }
    return true;
}