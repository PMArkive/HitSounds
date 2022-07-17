#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csgocolors_fix>
#include <clientprefs>

Cookie g_hVolume;
Cookie g_hHitsound_cookie; // [Hitsounds][Detailed][Boss]

#define DEFAULT_VOLUME 0.5
float g_fHitVolumeSound[MAXPLAYERS+1] = {DEFAULT_VOLUME, ...};
bool g_bBossHitsound[MAXPLAYERS+1] = {false, ...};
bool g_bHearSound[MAXPLAYERS+1] = {false, ...};
bool g_bDetailedHitsound[MAXPLAYERS+1] = {false, ...};

ConVar g_cvHitsound;
ConVar g_cvHitsoundHead;
ConVar g_cvHitsoundBody;
ConVar g_cvHitsoundKill;
char g_sHitsoundPath[PLATFORM_MAX_PATH];
char g_sHitsoundHeadPath[PLATFORM_MAX_PATH];
char g_sHitsoundBodyPath[PLATFORM_MAX_PATH];
char g_sHitsoundKillPath[PLATFORM_MAX_PATH];

bool g_bLate = false;

public Plugin myinfo = 
{
	name        = "HitSounds v2",
	author      = "koen, tilgep (Original: nano, maxime1907)",
	description = "Play hitsounds when shooting at entities or other players",
	version     = "2.4.0",
	url         = "https://steamcommunity.com/id/fungame1224/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Translation File
	LoadTranslations("hitsounds.phrases");

	// Hitsound Convars
	g_cvHitsound = CreateConVar("sm_hitsound_path", "hitmarker/hitmarker.mp3", "File location of normal hitsound relative to sound folder.");
	g_cvHitsoundHead = CreateConVar("sm_hitsound_head_path", "hitmarker/headshot.mp3", "File location of head hitsound relative to sound folder.");
	g_cvHitsoundBody = CreateConVar("sm_hitsound_body_path", "hitmarker/bodyshot.mp3", "File location of body hitsound relative to sound folder.");
	g_cvHitsoundKill = CreateConVar("sm_hitsound_kill_path", "hitmarker/killshot.mp3", "File location of kill hitsound relative to sound folder.");
	AutoExecConfig(true, "Hitsounds");
	
	// Client cookies
	g_hHitsound_cookie = RegClientCookie("hitmarker_cookies", "[HitSounds] Cookies for hitsound settings", CookieAccess_Private);
	g_hVolume = RegClientCookie("hitsound_volume", "Volume of hitsound", CookieAccess_Private);

	// Add HitSound menu to !settings cookie menu
	SetCookieMenuItem(CookieMenu_HitMarker, INVALID_HANDLE, "Hit Sound Settings");

	// Hook onto entities so plugin detects when we hit a boss (or a breakable)
	HookEntityOutput("func_physbox", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("func_breakable", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("math_counter", "OutValue", Hook_EntityOnDamage);

	// Hook onto when we hit zombies
	HookEvent("player_hurt", Hook_EventOnDamage);

	//Console Commands
	RegConsoleCmd("sm_hits", Command_HitMarker, "Bring up Hitsound Settings Menu");
	RegConsoleCmd("sm_hitsound", Command_HitMarker, "Bring up Hitsound Settings Menu");
	RegConsoleCmd("sm_hitsounds", Command_HitMarker, "Bring up Hitsound Settings Menu");
	RegConsoleCmd("sm_hsvol", Command_Vol, "Change hitsound volume");
	RegConsoleCmd("sm_hitsoundstyle", Command_Style, "Toggle between simple and detailed hitsounds");

	// Late load
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && AreClientCookiesCached(i)) OnClientCookiesCached(i);
		}
	}
}

public void OnPluginEnd()
{
	// Late unload
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i))
				OnClientDisconnect(i);
		}
	}
}

public void OnMapStart()
{
	PrecacheSounds();
	GetConVarString(g_cvHitsound, g_sHitsoundPath, sizeof(g_sHitsoundPath));
	GetConVarString(g_cvHitsoundBody, g_sHitsoundBodyPath, sizeof(g_sHitsoundBodyPath));
	GetConVarString(g_cvHitsoundHead, g_sHitsoundHeadPath, sizeof(g_sHitsoundHeadPath));
	GetConVarString(g_cvHitsoundKill, g_sHitsoundKillPath, sizeof(g_sHitsoundKillPath));
}

public void OnClientDisconnect(int client)
{
	SetClientCookies(client);
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

/* ---------------[ Plugin Commands ]--------------- */
public Action Command_HitMarker(int client, int args)
{
	DisplayCookieMenu(client);
	CPrintToChat(client, "%t", "Command Usage", "Prefix");
	return Plugin_Handled;
}

public Action Command_Vol(int client, int args)
{
	if (args == 0)
	{
		DisplayCookieMenu(client);
		CPrintToChat(client, "%t", "Command Usage", "Prefix");
		return Plugin_Handled;
	}

	char sBuffer[16];
	GetCmdArg(1, sBuffer, sizeof(sBuffer));

	float input;

	if (strlen(sBuffer) > 0)
		input = StringToFloat(sBuffer);

	if (input < 0.0)
	{
		input = 0.0;
		CPrintToChat(client, "Min Limit", "Prefix");
	}
	else if (input > 1.0)
	{
		input = 1.0;
		CPrintToChat(client, "Max Limit", "Prefix");
	}

	g_fHitVolumeSound[client] = input;
	CPrintToChat(client, "%t", "Volume Change", "Prefix", input);
	return Plugin_Continue;
}

public Action Command_Style(int client, int args)
{
	g_bDetailedHitsound[client] = !g_bDetailedHitsound[client];
	CPrintToChat(client, "%t", "Detailed Hitsound Toggle", "Prefix", g_bDetailedHitsound[client] ? "{green}enabled" : "{red}disabled");
	return Plugin_Handled;
}

/* ---------------[ Client Menu ]--------------- */
public void CookieMenu_HitMarker(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			DisplayCookieMenu(client);
		}
	}
}

public void DisplayCookieMenu(int client)
{
	Menu menu = new Menu(MenuHandler_HitMarker, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	SetMenuTitle(menu, "Hit Sound Settings:");
	AddMenuItem(menu, "zombie", "Toggle zombie hitsounds");
	AddMenuItem(menu, "boss", "Toggle boss hitsounds");
	AddMenuItem(menu, "detailed", "Toggle detailed hitounds");
	AddMenuItem(menu, "vol", "Change volume of hitsound");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_HitMarker(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			if (param1 != MenuEnd_Selected)
				delete menu;
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowCookieMenu(param1);
		}
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					g_bHearSound[param1] = !g_bHearSound[param1];
				}
				case 1:
				{
					g_bBossHitsound[param1] = !g_bBossHitsound[param1];
				}
				case 2:
				{
					g_bDetailedHitsound[param1] = !g_bDetailedHitsound[param1];
				}
				case 3:
				{
					g_fHitVolumeSound[param1] = g_fHitVolumeSound[param1] - 0.1;
					if (g_fHitVolumeSound[param1] <= 0.0)
						g_fHitVolumeSound[param1] = 1.0; 
					DisplayCookieMenu(param1);
				}
				default: return 0;
			}
			DisplayMenu(menu, param1, MENU_TIME_FOREVER);
		}
		case MenuAction_DisplayItem:
		{
			char sBuffer[32];
			switch (param2)
			{
				case 0:
				{
					Format(sBuffer, sizeof(sBuffer), "Zombie Hitsounds: %s", g_bHearSound[param1] ? "Enabled" : "Disabled");
				}
				case 1:
				{
					Format(sBuffer, sizeof(sBuffer), "Boss Hitsounds: %s", g_bBossHitsound[param1] ? "Enabled" : "Disabled");
				}
				case 2:
				{
					Format(sBuffer, sizeof(sBuffer), "Detailed Hitsound: %s", g_bDetailedHitsound[param1] ? "Enabled" : "Disabled");
				}
				case 3:
				{
					Format(sBuffer, sizeof(sBuffer), "Hitsound Volume: %.2f", g_fHitVolumeSound[param1]);
				}
			}
			return RedrawMenuItem(sBuffer);
		}
	}
	return 0;
}

/* ---------------[ Event Hooks ]--------------- */
public void Hook_EntityOnDamage(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidClient(activator))
		return;
	
	if (g_bBossHitsound[activator] && g_fHitVolumeSound[activator] != 0.0)
		EmitSoundToClient(activator, g_sHitsoundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[activator]);
}

public void Hook_EventOnDamage(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iHitgroup = GetEventInt(event, "hitgroup");
	int iHP = GetEventInt(event, "health");
	
	if (!IsValidClient(iAttacker))
		return;
	if (iVictim == iAttacker)
		return;
	
	if (g_bHearSound[iAttacker] && g_fHitVolumeSound[iAttacker] != 0.0)
	{
		if (g_bDetailedHitsound[iAttacker])
		{
			if (iHP == 0)
				EmitSoundToClient(iAttacker, g_sHitsoundKillPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
			else if (iHitgroup == 1)
				EmitSoundToClient(iAttacker, g_sHitsoundHeadPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
			else
				EmitSoundToClient(iAttacker, g_sHitsoundBodyPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
		}
		else EmitSoundToClient(iAttacker, g_sHitsoundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
	}
}

/* ---------------[ Stock Functions ]--------------- */
stock bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;
	return true;
}

stock void PrecacheSounds()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	// Boss Hitmarker Sound
	GetConVarString(g_cvHitsound, g_sHitsoundPath, sizeof(g_sHitsoundPath));
	PrecacheSound(g_sHitsoundPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundPath);
	AddFileToDownloadsTable(sBuffer);
	
	// Body Shot Sound
	GetConVarString(g_cvHitsoundBody, g_sHitsoundHeadPath, sizeof(g_sHitsoundHeadPath));
	PrecacheSound(g_sHitsoundPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundHeadPath);
	AddFileToDownloadsTable(sBuffer);
	
	// Head Shot Sound
	GetConVarString(g_cvHitsoundHead, g_sHitsoundBodyPath, sizeof(g_sHitsoundBodyPath));
	PrecacheSound(g_sHitsoundPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundBodyPath);
	AddFileToDownloadsTable(sBuffer);
	
	// Kill Shot Sound
	GetConVarString(g_cvHitsoundKill, g_sHitsoundKillPath, sizeof(g_sHitsoundKillPath));
	PrecacheSound(g_sHitsoundPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundKillPath);
	AddFileToDownloadsTable(sBuffer);
}

/* ---------------[ Client Cookies ]--------------- */
public void ReadClientCookies(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hHitsound_cookie, sValue, sizeof(sValue));

	if (sValue[0] != '\0')
	{
		char sTemp[2];

		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[0]);
		g_bHearSound[client] = StrEqual(sTemp, "1");

		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[1]);
		g_bDetailedHitsound[client] = StrEqual(sTemp, "1");

		FormatEx(sTemp, sizeof(sTemp), "%c", sValue[2]);
		g_bBossHitsound[client] = StrEqual(sTemp, "1");
	}
	else
	{
		g_bHearSound[client] = true;
		g_bDetailedHitsound[client] = false;
		g_bBossHitsound[client] = true;
	}

	GetClientCookie(client, g_hVolume, sValue, sizeof(sValue));
	if (!StrEqual(sValue, "")) g_fHitVolumeSound[client] = StringToFloat(sValue);
	else g_fHitVolumeSound[client] = DEFAULT_VOLUME;
}

public void SetClientCookies(int client)
{
	char sValue[8];
	FormatEx(sValue, sizeof(sValue), "%b%b%b", g_bHearSound[client], g_bDetailedHitsound[client], g_bBossHitsound[client]);
	SetClientCookie(client, g_hHitsound_cookie, sValue);

	FormatEx(sValue, sizeof(sValue), "%.2f", g_fHitVolumeSound[client]);
	SetClientCookie(client, g_hVolume, sValue);
}
