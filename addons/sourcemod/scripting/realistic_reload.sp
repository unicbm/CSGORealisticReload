#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.3"

ConVar g_cvEnable;
ConVar g_cvHumans;
ConVar g_cvBots;
ConVar g_cvAlignReserve;
ConVar g_cvExcludeShotguns;

int g_iAppliedReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadClip[MAXPLAYERS + 1];

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
	g_cvAlignReserve = CreateConVar("sm_realistic_reload_align_reserve", "1", "Align reserve ammo to each weapon's default reserve cadence after reload.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvExcludeShotguns = CreateConVar("sm_realistic_reload_exclude_shotguns", "1", "Keep shell-by-shell shotgun reload behavior unchanged.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

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
		TryApplyRealisticReload(client);

	return Plugin_Continue;
}

void TryApplyRealisticReload(int client)
{
	if (!g_cvEnable.BoolValue)
	{
		ClearRealisticReloadState(client);
		return;
	}

	bool isBot = IsFakeClient(client);
	if (isBot && !g_cvBots.BoolValue)
	{
		ClearRealisticReloadState(client);
		return;
	}
	if (!isBot && !g_cvHumans.BoolValue)
	{
		ClearRealisticReloadState(client);
		return;
	}

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(weapon))
	{
		ClearRealisticReloadState(client);
		return;
	}

	if (!HasEntProp(weapon, Prop_Data, "m_iClip1") || !HasEntProp(weapon, Prop_Data, "m_bInReload"))
	{
		ClearRealisticReloadState(client);
		return;
	}

	bool inReload = !!GetEntProp(weapon, Prop_Data, "m_bInReload");
	int weaponRef = EntIndexToEntRef(weapon);
	if (!inReload)
	{
		FinishPendingRealisticReload(client, weaponRef, weapon);
		g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
		return;
	}

	if (g_iAppliedReloadWeaponRef[client] == weaponRef)
		return;

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
	{
		ClearRealisticReloadState(client);
		return;
	}

	if (g_cvExcludeShotguns.BoolValue && IsRealisticReloadShotgun(classname))
	{
		ClearRealisticReloadState(client);
		return;
	}

	int maxClip = GetRealisticReloadMaxClip(classname);
	if (maxClip <= 0)
	{
		ClearRealisticReloadState(client);
		return;
	}

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip <= 0 || clip >= maxClip)
	{
		ClearRealisticReloadState(client);
		return;
	}

	int reserve = GetRealisticReloadReserveAmmo(client, weapon);
	if (reserve <= 0)
	{
		ClearRealisticReloadState(client);
		return;
	}

	int missing = maxClip - clip;
	int reserveBeforeEngineLoad;
	int pendingFinalClip = 0;

	if (reserve < maxClip)
		pendingFinalClip = reserve;

	if (g_cvAlignReserve.BoolValue)
	{
		int targetReserveAfterReload = reserve - maxClip;
		if (targetReserveAfterReload < 0)
			targetReserveAfterReload = 0;
		targetReserveAfterReload = AlignRealisticReloadReserve(targetReserveAfterReload, maxClip, GetRealisticReloadMaxReserve(classname));

		reserveBeforeEngineLoad = targetReserveAfterReload + missing;
		if (reserveBeforeEngineLoad > reserve)
			reserveBeforeEngineLoad = reserve;
	}
	else
	{
		int extraReserve = reserve - missing;
		if (extraReserve <= 0)
		{
			reserveBeforeEngineLoad = reserve;
		}
		else
		{
			int penalty = clip;
			if (penalty > extraReserve)
				penalty = extraReserve;

			reserveBeforeEngineLoad = reserve - penalty;
		}
	}

	bool adjustFinalClip = pendingFinalClip > 0 && pendingFinalClip < maxClip;
	if (reserveBeforeEngineLoad >= reserve && !adjustFinalClip)
		return;

	if (reserveBeforeEngineLoad < reserve)
		SetRealisticReloadReserveAmmo(client, weapon, reserveBeforeEngineLoad);

	g_iAppliedReloadWeaponRef[client] = weaponRef;

	if (adjustFinalClip)
	{
		g_iPendingReloadWeaponRef[client] = weaponRef;
		g_iPendingReloadClip[client] = pendingFinalClip;
	}
	else
	{
		g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
		g_iPendingReloadClip[client] = 0;
	}
}

void FinishPendingRealisticReload(int client, int weaponRef, int weapon)
{
	if (g_iPendingReloadWeaponRef[client] == INVALID_ENT_REFERENCE)
		return;

	if (g_iPendingReloadWeaponRef[client] != weaponRef)
	{
		g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
		g_iPendingReloadClip[client] = 0;
		return;
	}

	int pendingClip = g_iPendingReloadClip[client];
	g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadClip[client] = 0;

	if (pendingClip <= 0 || !HasEntProp(weapon, Prop_Data, "m_iClip1"))
		return;

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip > pendingClip)
	{
		SetEntProp(weapon, Prop_Data, "m_iClip1", pendingClip);
		SetRealisticReloadReserveAmmo(client, weapon, 0);
	}
}

void ClearRealisticReloadState(int client)
{
	g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadClip[client] = 0;
}

int AlignRealisticReloadReserve(int reserve, int maxClip, int maxReserve)
{
	if (reserve <= 0)
		return 0;

	if (maxClip <= 0 || maxReserve <= 0)
		return reserve;

	int remainder = maxReserve % maxClip;
	if (remainder == 0)
		return (reserve / maxClip) * maxClip;

	if (reserve < remainder)
		return 0;

	return remainder + (((reserve - remainder) / maxClip) * maxClip);
}

int GetRealisticReloadReserveAmmo(int client, int weapon)
{
	int reserve = 0;
	int playerReserve = 0;
	int sendReserve = -1;
	int dataReserve = -1;

	if (GetWeaponPlayerAmmo(client, weapon, playerReserve))
		reserve = playerReserve;

	if (HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
	{
		sendReserve = GetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
		if (sendReserve > reserve)
			reserve = sendReserve;
	}

	if (HasEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount"))
	{
		dataReserve = GetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount");
		if (dataReserve > reserve)
			reserve = dataReserve;
	}

	return reserve;
}

void SetRealisticReloadReserveAmmo(int client, int weapon, int reserve)
{
	SetWeaponPlayerAmmo(client, weapon, reserve);

	if (HasEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
		SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", reserve);

	if (HasEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount"))
		SetEntProp(weapon, Prop_Data, "m_iPrimaryReserveAmmoCount", reserve);
}

bool GetWeaponPlayerAmmo(int client, int weapon, int &primaryAmmo)
{
	int ammoOffset = FindDataMapInfo(client, "m_iAmmo");
	if (ammoOffset == -1 || !HasEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType"))
	{
		primaryAmmo = 0;
		return false;
	}

	int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
	if (ammoType < 0)
	{
		primaryAmmo = 0;
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
	if (strcmp(classname, "weapon_awp", false) == 0) return 5;
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
	if (strcmp(classname, "weapon_m4a1_silencer", false) == 0) return 20;
	if (strcmp(classname, "weapon_usp_silencer", false) == 0) return 12;
	if (strcmp(classname, "weapon_cz75a", false) == 0) return 12;
	if (strcmp(classname, "weapon_revolver", false) == 0) return 8;

	return 0;
}

int GetRealisticReloadMaxReserve(const char[] classname)
{
	if (strcmp(classname, "weapon_deagle", false) == 0) return 35;
	if (strcmp(classname, "weapon_elite", false) == 0) return 120;
	if (strcmp(classname, "weapon_fiveseven", false) == 0) return 100;
	if (strcmp(classname, "weapon_glock", false) == 0) return 120;
	if (strcmp(classname, "weapon_ak47", false) == 0) return 90;
	if (strcmp(classname, "weapon_aug", false) == 0) return 90;
	if (strcmp(classname, "weapon_awp", false) == 0) return 40;
	if (strcmp(classname, "weapon_famas", false) == 0) return 90;
	if (strcmp(classname, "weapon_g3sg1", false) == 0) return 90;
	if (strcmp(classname, "weapon_galilar", false) == 0) return 90;
	if (strcmp(classname, "weapon_m249", false) == 0) return 200;
	if (strcmp(classname, "weapon_m4a1", false) == 0) return 90;
	if (strcmp(classname, "weapon_mac10", false) == 0) return 100;
	if (strcmp(classname, "weapon_p90", false) == 0) return 100;
	if (strcmp(classname, "weapon_mp5sd", false) == 0) return 120;
	if (strcmp(classname, "weapon_ump45", false) == 0) return 100;
	if (strcmp(classname, "weapon_bizon", false) == 0) return 120;
	if (strcmp(classname, "weapon_negev", false) == 0) return 200;
	if (strcmp(classname, "weapon_tec9", false) == 0) return 90;
	if (strcmp(classname, "weapon_hkp2000", false) == 0) return 52;
	if (strcmp(classname, "weapon_mp7", false) == 0) return 120;
	if (strcmp(classname, "weapon_mp9", false) == 0) return 120;
	if (strcmp(classname, "weapon_p250", false) == 0) return 26;
	if (strcmp(classname, "weapon_scar20", false) == 0) return 90;
	if (strcmp(classname, "weapon_sg556", false) == 0) return 90;
	if (strcmp(classname, "weapon_ssg08", false) == 0) return 90;
	if (strcmp(classname, "weapon_m4a1_silencer", false) == 0) return 80;
	if (strcmp(classname, "weapon_usp_silencer", false) == 0) return 24;
	if (strcmp(classname, "weapon_cz75a", false) == 0) return 12;
	if (strcmp(classname, "weapon_revolver", false) == 0) return 8;

	return 0;
}

bool IsValidAliveClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
