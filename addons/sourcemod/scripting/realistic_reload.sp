#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.0-debug1"

ConVar g_cvEnable;
ConVar g_cvHumans;
ConVar g_cvBots;
ConVar g_cvAlignReserve;
ConVar g_cvExcludeShotguns;
ConVar g_cvDebug;

int g_iAppliedReloadWeaponRef[MAXPLAYERS + 1];
int g_iDebugWeaponRef[MAXPLAYERS + 1];
int g_iDebugClip[MAXPLAYERS + 1];
int g_iDebugSendReserve[MAXPLAYERS + 1];
int g_iDebugDataReserve[MAXPLAYERS + 1];
int g_iDebugPlayerReserve[MAXPLAYERS + 1];
int g_iDebugButtons[MAXPLAYERS + 1];
bool g_bDebugInReload[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Realistic Reload",
	author = "uni",
	description = "Discards partial magazines by deducting reserve ammo when reloading.",
	version = PLUGIN_VERSION,
	url = "https://github.com/unicbm/CSGORealisticReload"
};

public void OnPluginStart()
{
	g_cvEnable = CreateConVar("sm_realistic_reload_enable", "1", "Enable realistic reload reserve deduction.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvHumans = CreateConVar("sm_realistic_reload_humans", "1", "Apply realistic reload to human players.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvBots = CreateConVar("sm_realistic_reload_bots", "1", "Apply realistic reload to bots.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvAlignReserve = CreateConVar("sm_realistic_reload_align_reserve", "1", "Align reserve ammo to full-magazine multiples after reload.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvExcludeShotguns = CreateConVar("sm_realistic_reload_exclude_shotguns", "1", "Keep shell-by-shell shotgun reload behavior unchanged.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDebug = CreateConVar("sm_realistic_reload_debug", "1", "Print realistic reload debug lines to the player's console.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig(true, "realistic_reload");

	for (int client = 1; client <= MaxClients; client++)
		ClearRealisticReloadState(client);
}

public void OnClientPutInServer(int client)
{
	ClearRealisticReloadState(client);
}

public void OnClientDisconnect(int client)
{
	ClearRealisticReloadState(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidAliveClient(client))
	{
		TryApplyRealisticReload(client, buttons, cmdnum, tickcount);
	}
	else if (client > 0 && client <= MaxClients)
	{
		ClearRealisticReloadState(client);
	}

	return Plugin_Continue;
}

void TryApplyRealisticReload(int client, int buttons, int cmdnum, int tickcount)
{
	if (!g_cvEnable.BoolValue)
		return;

	bool isBot = IsFakeClient(client);
	if (isBot && !g_cvBots.BoolValue)
		return;
	if (!isBot && !g_cvHumans.BoolValue)
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
		return;

	if (!HasEntProp(weapon, Prop_Data, "m_iClip1") || !HasEntProp(weapon, Prop_Data, "m_bInReload"))
		return;

	bool inReload = !!GetEntProp(weapon, Prop_Data, "m_bInReload");
	int weaponRef = EntIndexToEntRef(weapon);
	DebugMaybePrintState(client, weapon, "cmd", buttons, cmdnum, tickcount, -1, -1, -1, -1, false, false);
	if (!inReload)
	{
		g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
		return;
	}

	if (g_iAppliedReloadWeaponRef[client] == weaponRef)
		return;

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		return;

	if (g_cvExcludeShotguns.BoolValue && IsRealisticReloadShotgun(classname))
		return;

	int maxClip = GetRealisticReloadMaxClip(classname);
	if (maxClip <= 0)
	{
		DebugMaybePrintState(client, weapon, "skip_unknown_weapon", buttons, cmdnum, tickcount, maxClip, -1, -1, -1, false, true);
		return;
	}

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip <= 0 || clip >= maxClip)
	{
		DebugMaybePrintState(client, weapon, "skip_empty_or_full", buttons, cmdnum, tickcount, maxClip, -1, -1, -1, false, true);
		return;
	}

	int reserve = GetRealisticReloadReserveAmmo(client, weapon);
	if (reserve <= 0)
	{
		DebugMaybePrintState(client, weapon, "skip_no_reserve", buttons, cmdnum, tickcount, maxClip, reserve, -1, -1, false, true);
		return;
	}

	int missing = maxClip - clip;
	int reserveBeforeEngineLoad;

	if (g_cvAlignReserve.BoolValue)
	{
		int targetReserveAfterReload = reserve - maxClip;
		if (targetReserveAfterReload < 0)
			targetReserveAfterReload = 0;
		targetReserveAfterReload = (targetReserveAfterReload / maxClip) * maxClip;

		reserveBeforeEngineLoad = targetReserveAfterReload + missing;
		if (reserveBeforeEngineLoad > reserve)
			reserveBeforeEngineLoad = reserve;
	}
	else
	{
		int extraReserve = reserve - missing;
		if (extraReserve <= 0)
		{
			DebugMaybePrintState(client, weapon, "skip_no_extra_reserve", buttons, cmdnum, tickcount, maxClip, reserve, missing, -1, false, true);
			return;
		}

		int penalty = clip;
		if (penalty > extraReserve)
			penalty = extraReserve;

		reserveBeforeEngineLoad = reserve - penalty;
	}

	if (reserveBeforeEngineLoad >= reserve)
	{
		DebugMaybePrintState(client, weapon, "skip_no_penalty", buttons, cmdnum, tickcount, maxClip, reserve, missing, reserveBeforeEngineLoad, false, true);
		return;
	}

	DebugMaybePrintState(client, weapon, "apply_before", buttons, cmdnum, tickcount, maxClip, reserve, missing, reserveBeforeEngineLoad, true, true);
	SetRealisticReloadReserveAmmo(client, weapon, reserveBeforeEngineLoad);
	DebugMaybePrintState(client, weapon, "apply_after", buttons, cmdnum, tickcount, maxClip, GetRealisticReloadReserveAmmo(client, weapon), missing, reserveBeforeEngineLoad, true, true);
	g_iAppliedReloadWeaponRef[client] = weaponRef;
}

void ClearRealisticReloadState(int client)
{
	g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iDebugWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iDebugClip[client] = -1;
	g_iDebugSendReserve[client] = -1;
	g_iDebugDataReserve[client] = -1;
	g_iDebugPlayerReserve[client] = -1;
	g_iDebugButtons[client] = 0;
	g_bDebugInReload[client] = false;
}

void DebugMaybePrintState(int client, int weapon, const char[] reason, int buttons, int cmdnum, int tickcount, int maxClip, int reserveUsed, int missing, int targetReserve, bool applied, bool force)
{
	if (!g_cvDebug.BoolValue)
		return;

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		strcopy(classname, sizeof(classname), "<unknown>");

	int clip = HasEntProp(weapon, Prop_Data, "m_iClip1") ? GetEntProp(weapon, Prop_Data, "m_iClip1") : -1;
	bool inReload = HasEntProp(weapon, Prop_Data, "m_bInReload") && GetEntProp(weapon, Prop_Data, "m_bInReload") != 0;
	int sendReserve = HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount") ? GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount") : -1;
	int dataReserve = HasEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount") ? GetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount") : -1;
	int playerReserve = -1;
	int ammoType = -1;
	GetWeaponPlayerAmmoDebug(client, weapon, playerReserve, ammoType);

	int defIndex = HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
	if (maxClip < 0)
		maxClip = GetRealisticReloadMaxClip(classname);
	if (reserveUsed < 0)
		reserveUsed = GetRealisticReloadReserveAmmo(client, weapon);

	int weaponRef = EntIndexToEntRef(weapon);
	bool wantsReload = (buttons & IN_RELOAD) != 0;
	bool wantsAttack = (buttons & IN_ATTACK) != 0;
	bool wasInteresting = g_bDebugInReload[client] || (g_iDebugButtons[client] & IN_RELOAD) != 0;
	bool isInteresting = wantsReload || inReload || wasInteresting;
	bool changed = weaponRef != g_iDebugWeaponRef[client]
		|| clip != g_iDebugClip[client]
		|| inReload != g_bDebugInReload[client]
		|| sendReserve != g_iDebugSendReserve[client]
		|| dataReserve != g_iDebugDataReserve[client]
		|| playerReserve != g_iDebugPlayerReserve[client]
		|| wantsReload != ((g_iDebugButtons[client] & IN_RELOAD) != 0);

	if (force || (isInteresting && changed))
	{
		DebugPrint(client,
			"[RRDBG] reason=%s time=%.3f cmd=%d tick=%d wantsR=%d attack=%d inReload=%d applied=%d weapon=%d ref=%d class=%s def=%d clip=%d maxClip=%d reserveUsed=%d targetReserve=%d missing=%d sendReserve=%d dataReserve=%d playerReserve=%d ammoType=%d",
			reason,
			GetGameTime(),
			cmdnum,
			tickcount,
			wantsReload ? 1 : 0,
			wantsAttack ? 1 : 0,
			inReload ? 1 : 0,
			applied ? 1 : 0,
			weapon,
			weaponRef,
			classname,
			defIndex,
			clip,
			maxClip,
			reserveUsed,
			targetReserve,
			missing,
			sendReserve,
			dataReserve,
			playerReserve,
			ammoType);
	}

	g_iDebugWeaponRef[client] = weaponRef;
	g_iDebugClip[client] = clip;
	g_bDebugInReload[client] = inReload;
	g_iDebugSendReserve[client] = sendReserve;
	g_iDebugDataReserve[client] = dataReserve;
	g_iDebugPlayerReserve[client] = playerReserve;
	g_iDebugButtons[client] = buttons;
}

void DebugPrint(int client, const char[] format, any ...)
{
	char message[512];
	VFormat(message, sizeof(message), format, 3);

	if (IsClientInGame(client) && !IsFakeClient(client))
		PrintToConsole(client, "%s", message);
	else
		PrintToServer("%s", message);
}

int GetRealisticReloadReserveAmmo(int client, int weapon)
{
	if (HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
		return GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");

	if (HasEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount"))
		return GetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount");

	int reserve = 0;
	GetWeaponPlayerAmmo(client, weapon, reserve);
	return reserve;
}

void SetRealisticReloadReserveAmmo(int client, int weapon, int reserve)
{
	if (HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
	{
		SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", reserve);
		return;
	}

	if (HasEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount"))
	{
		SetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount", reserve);
		return;
	}

	SetWeaponPlayerAmmo(client, weapon, reserve);
}

void GetWeaponPlayerAmmo(int client, int weapon, int &primaryAmmo)
{
	int ammoOffset = FindDataMapInfo(client, "m_iAmmo");
	if (ammoOffset == -1 || !HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
	{
		primaryAmmo = 0;
		return;
	}

	int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
	if (ammoType < 0)
	{
		primaryAmmo = 0;
		return;
	}

	primaryAmmo = GetEntData(client, ammoOffset + (ammoType * 4));
}

bool GetWeaponPlayerAmmoDebug(int client, int weapon, int &primaryAmmo, int &ammoType)
{
	int ammoOffset = FindDataMapInfo(client, "m_iAmmo");
	if (ammoOffset == -1 || !HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
	{
		primaryAmmo = -1;
		ammoType = -1;
		return false;
	}

	ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
	if (ammoType < 0)
	{
		primaryAmmo = -1;
		return false;
	}

	primaryAmmo = GetEntData(client, ammoOffset + (ammoType * 4));
	return true;
}

void SetWeaponPlayerAmmo(int client, int weapon, int primaryAmmo)
{
	int ammoOffset = FindDataMapInfo(client, "m_iAmmo");
	if (ammoOffset == -1 || !HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
		return;

	int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
	if (ammoType < 0)
		return;

	SetEntData(client, ammoOffset + (ammoType * 4), primaryAmmo, 4, true);
}

bool IsRealisticReloadShotgun(const char[] classname)
{
	if (strcmp(classname, "weapon_mag7", false) == 0)
		return true;
	if (strcmp(classname, "weapon_nova", false) == 0)
		return true;
	if (strcmp(classname, "weapon_sawedoff", false) == 0)
		return true;
	if (strcmp(classname, "weapon_xm1014", false) == 0)
		return true;

	return false;
}

int GetRealisticReloadMaxClip(const char[] classname)
{
	if (strcmp(classname, "weapon_deagle", false) == 0) return 7;
	if (strcmp(classname, "weapon_elite", false) == 0) return 30;
	if (strcmp(classname, "weapon_fiveseven", false) == 0) return 20;
	if (strcmp(classname, "weapon_glock", false) == 0) return 20;
	if (strcmp(classname, "weapon_ak47", false) == 0) return 30;
	if (strcmp(classname, "weapon_aug", false) == 0) return 30;
	if (strcmp(classname, "weapon_awp", false) == 0) return 10;
	if (strcmp(classname, "weapon_famas", false) == 0) return 25;
	if (strcmp(classname, "weapon_g3sg1", false) == 0) return 20;
	if (strcmp(classname, "weapon_galilar", false) == 0) return 35;
	if (strcmp(classname, "weapon_m249", false) == 0) return 100;
	if (strcmp(classname, "weapon_m4a1", false) == 0) return 30;
	if (strcmp(classname, "weapon_mac10", false) == 0) return 30;
	if (strcmp(classname, "weapon_p90", false) == 0) return 50;
	if (strcmp(classname, "weapon_mp5sd", false) == 0) return 30;
	if (strcmp(classname, "weapon_ump45", false) == 0) return 25;
	if (strcmp(classname, "weapon_bizon", false) == 0) return 64;
	if (strcmp(classname, "weapon_negev", false) == 0) return 150;
	if (strcmp(classname, "weapon_tec9", false) == 0) return 18;
	if (strcmp(classname, "weapon_hkp2000", false) == 0) return 13;
	if (strcmp(classname, "weapon_mp7", false) == 0) return 30;
	if (strcmp(classname, "weapon_mp9", false) == 0) return 30;
	if (strcmp(classname, "weapon_p250", false) == 0) return 13;
	if (strcmp(classname, "weapon_scar20", false) == 0) return 20;
	if (strcmp(classname, "weapon_sg556", false) == 0) return 30;
	if (strcmp(classname, "weapon_ssg08", false) == 0) return 10;
	if (strcmp(classname, "weapon_m4a1_silencer", false) == 0) return 25;
	if (strcmp(classname, "weapon_usp_silencer", false) == 0) return 12;
	if (strcmp(classname, "weapon_cz75a", false) == 0) return 12;
	if (strcmp(classname, "weapon_revolver", false) == 0) return 8;

	return 0;
}

bool IsValidAliveClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
