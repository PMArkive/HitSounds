#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csgocolors_fix>
#include <clientprefs>

Handle g_hDetailedHitsounds = INVALID_HANDLE;
Handle g_hHearSound = INVALID_HANDLE;
Handle g_hVolume = INVALID_HANDLE;

#define DEFAULT_VOLUME 0.5
float g_fHitVolumeSound[MAXPLAYERS+1] = {DEFAULT_VOLUME, ...};
bool g_bHearSound[MAXPLAYERS+1] = {false, ...};
bool g_bDetailedHitsound[MAXPLAYERS+1] = {false, ...};

// Hitsound File Paths (Hardcoded for now... Will be changed to CVar)
#define SND_PATH_HITBOSS "hitmarker/hitmarker.mp3"
#define SND_PATH_HITHEAD "hitmarker/headshot.mp3"
#define SND_PATH_HITBODY "hitmarker/bodyshot.mp3"
#define SND_PATH_HITKILL "hitmarker/killshot.mp3"

bool g_bLate = false;

public Plugin myinfo = 
{
	name        = "HitSounds v2",
	author      = "koen, tilgep (Original: nano, maxime1907)",
	description = "Play hitsounds when shooting at entities or other players",
	version     = "2.1",
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
	
	// Client cookies
	g_hHearSound = RegClientCookie("hitmarker_sound", "Enable/Disable hitmarker sound effect", CookieAccess_Private);
	g_hVolume = RegClientCookie("hitsound_volume", "Volume of hitsound", CookieAccess_Private);
	g_hDetailedHitsounds = RegClientCookie("hitsound_advanced", "Hitsound style", CookieAccess_Private);

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

	AutoExecConfig(true);

	// Late load
	if (g_bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i)) OnClientPutInServer(i);
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
			if (IsClientConnected(i)) OnClientDisconnect(i);
		}
	}
}

public void OnMapStart()
{
	PrecacheSounds();
}

public void OnClientPutInServer(int client)
{
	if (AreClientCookiesCached(client)) ReadClientCookies(client);
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
	// int chars;

	if (strlen(sBuffer) > 0) input = StringToFloat(sBuffer);

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
	AddMenuItem(menu, NULL_STRING, "Hear a sound effect");
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
			if (param1 != MenuEnd_Selected) delete menu;
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack) ShowCookieMenu(param1);
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
					g_bDetailedHitsound[param1] = !g_bDetailedHitsound[param1];
				}
				case 2:
				{
					g_fHitVolumeSound[param1] = g_fHitVolumeSound[param1] - 0.1;
					if (g_fHitVolumeSound[param1] <= 0.0) g_fHitVolumeSound[param1] = 1.0; 
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
					Format(sBuffer, sizeof(sBuffer), "Hitsounds: %s", g_bHearSound[param1] ? "Enabled" : "Disabled");
				}
				case 1:
				{
					Format(sBuffer, sizeof(sBuffer), "Detailed Hitsound: %s", g_bDetailedHitsound[param1] ? "Enabled" : "Disabled");
				}
				case 2:
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
	if (!IsValidClient(activator)) return;
	
	if (g_bHearSound[activator] && g_fHitVolumeSound[activator] != 0.0)
		EmitSoundToClient(activator, SND_PATH_HITBOSS, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[activator]);
}

public void Hook_EventOnDamage(Event event, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int iVictim = GetClientOfUserId(GetEventInt(event, "userid"));
	int iHitgroup = GetEventInt(event, "hitgroup");
	int iHP = GetEventInt(event, "health");
	
	if (!IsValidClient(iAttacker)) return;
	if (iVictim == iAttacker) return;
	
	if (g_bHearSound[iAttacker] && g_fHitVolumeSound[iAttacker] != 0.0)
	{
		if (g_bDetailedHitsound[iAttacker]) {
			if (iHP == 0)
				EmitSoundToClient(iAttacker, SND_PATH_HITKILL, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
			else if (iHitgroup == 1)
				EmitSoundToClient(iAttacker, SND_PATH_HITHEAD, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
			else
				EmitSoundToClient(iAttacker, SND_PATH_HITBODY, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
		}
		else EmitSoundToClient(iAttacker, SND_PATH_HITBOSS, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fHitVolumeSound[iAttacker]);
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
	PrecacheSound(SND_PATH_HITBOSS, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SND_PATH_HITBOSS);
	AddFileToDownloadsTable(sBuffer);
	
	// Body Shot Sound
	PrecacheSound(SND_PATH_HITBODY, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SND_PATH_HITBODY);
	AddFileToDownloadsTable(sBuffer);
	
	// Head Shot Sound
	PrecacheSound(SND_PATH_HITHEAD, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SND_PATH_HITHEAD);
	AddFileToDownloadsTable(sBuffer);
	
	// Kill Shot Sound
	PrecacheSound(SND_PATH_HITKILL, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", SND_PATH_HITKILL);
	AddFileToDownloadsTable(sBuffer);
}

/* ---------------[ Client Cookies ]--------------- */
public void ReadClientCookies(int client)
{
	char sValue[8];

	GetClientCookie(client, g_hDetailedHitsounds, sValue, sizeof(sValue));
	g_bDetailedHitsound[client] = (sValue[0] == '\0' ? true : StringToInt(sValue) == 1);

	GetClientCookie(client, g_hHearSound, sValue, sizeof(sValue));
	g_bHearSound[client] = (sValue[0] == '\0' ? true : StringToInt(sValue) == 1);

	GetClientCookie(client, g_hVolume, sValue, sizeof(sValue));
	if (!StrEqual(sValue, "")) g_fHitVolumeSound[client] = StringToFloat(sValue);
	else g_fHitVolumeSound[client] = DEFAULT_VOLUME;
}

public void SetClientCookies(int client)
{
	char sValue[8];

	Format(sValue, sizeof(sValue), "%i", g_bDetailedHitsound[client]);
	SetClientCookie(client, g_hDetailedHitsounds, sValue);

	Format(sValue, sizeof(sValue), "%i", g_bHearSound[client]);
	SetClientCookie(client, g_hHearSound, sValue);

	Format(sValue, sizeof(sValue), "%.2f", g_fHitVolumeSound[client]);
	SetClientCookie(client, g_hVolume, sValue);
}
