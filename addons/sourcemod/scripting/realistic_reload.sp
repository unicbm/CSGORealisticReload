#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.5"

ConVar g_cvEnable;
ConVar g_cvHumans;
ConVar g_cvBots;
ConVar g_cvExcludeShotguns;
ConVar g_cvDebug;

int g_iAppliedReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadStartClip[MAXPLAYERS + 1];
int g_iPendingReloadStartReserve[MAXPLAYERS + 1];
int g_iDebugLastWeaponRef[MAXPLAYERS + 1];
int g_iDebugLastClip[MAXPLAYERS + 1];
int g_iDebugLastReserve[MAXPLAYERS + 1];
bool g_bDebugLastInReload[MAXPLAYERS + 1];
bool g_bDebugLastStateKnown[MAXPLAYERS + 1];

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
	CreateConVar("sm_realistic_reload_align_reserve", "1", "Deprecated compatibility ConVar; runtime reload behavior ignores this value.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvExcludeShotguns = CreateConVar("sm_realistic_reload_exclude_shotguns", "1", "Keep shell-by-shell shotgun reload behavior unchanged.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDebug = CreateConVar("sm_realistic_reload_debug", "0", "Log reload timing diagnostics.", 0, true, 0.0, true, 1.0);

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
		TryApplyRealisticReload(client);
	}
	else if (client > 0 && client <= MaxClients)
	{
		ClearRealisticReloadState(client);
	}

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
	TraceRealisticReloadState(client, weapon);
	ResolvePendingRealisticReload(client, weapon);

	if (!IsValidEntity(weapon))
		return;

	if (!HasEntProp(weapon, Prop_Data, "m_iClip1") || !HasEntProp(weapon, Prop_Data, "m_bInReload"))
		return;

	bool inReload = !!GetEntProp(weapon, Prop_Data, "m_bInReload");
	int weaponRef = EntIndexToEntRef(weapon);
	if (!inReload)
	{
		if (g_iAppliedReloadWeaponRef[client] == weaponRef)
			g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
		return;
	}

	if (g_iAppliedReloadWeaponRef[client] == weaponRef)
		return;

	if (g_iPendingReloadWeaponRef[client] == weaponRef)
		return;

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		return;

	if (g_cvExcludeShotguns.BoolValue && IsRealisticReloadShellByShellShotgun(classname))
		return;

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip <= 0)
		return;

	int reserve = GetRealisticReloadReserveAmmo(client, weapon);
	if (reserve <= 0)
		return;

	g_iPendingReloadWeaponRef[client] = weaponRef;
	g_iPendingReloadStartClip[client] = clip;
	g_iPendingReloadStartReserve[client] = reserve;
	LogRealisticReloadDebug("track_start client=%N tick=%d time=%.3f weapon=%d ref=%d classname=%s start_clip=%d start_reserve=%d", client, GetGameTickCount(), GetGameTime(), weapon, weaponRef, classname, clip, reserve);
}

void ResolvePendingRealisticReload(int client, int activeWeapon)
{
	if (g_iPendingReloadWeaponRef[client] == INVALID_ENT_REFERENCE)
		return;

	int weapon = EntRefToEntIndex(g_iPendingReloadWeaponRef[client]);
	if (weapon == INVALID_ENT_REFERENCE || !IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Data, "m_iClip1") || !HasEntProp(weapon, Prop_Data, "m_bInReload"))
	{
		LogRealisticReloadDebug("track_clear client=%N tick=%d time=%.3f reason=invalid_pending pending_ref=%d active=%d", client, GetGameTickCount(), GetGameTime(), g_iPendingReloadWeaponRef[client], activeWeapon);
		ClearPendingRealisticReloadState(client);
		return;
	}

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip > g_iPendingReloadStartClip[client])
	{
		int reserve = GetRealisticReloadReserveAmmo(client, weapon);
		int activeWeaponRef = IsValidEntity(activeWeapon) ? EntIndexToEntRef(activeWeapon) : INVALID_ENT_REFERENCE;
		bool inReload = !!GetEntProp(weapon, Prop_Data, "m_bInReload");
		LogRealisticReloadDebug("complete_observed client=%N tick=%d time=%.3f weapon=%d ref=%d active_ref=%d in_reload=%d start_clip=%d engine_clip=%d start_reserve=%d engine_reserve=%d", client, GetGameTickCount(), GetGameTime(), weapon, EntIndexToEntRef(weapon), activeWeaponRef, inReload ? 1 : 0, g_iPendingReloadStartClip[client], clip, g_iPendingReloadStartReserve[client], reserve);
		ApplyCompletedRealisticReload(client, weapon);
		g_iAppliedReloadWeaponRef[client] = EntIndexToEntRef(weapon);
		ClearPendingRealisticReloadState(client);
		return;
	}

	bool inReload = !!GetEntProp(weapon, Prop_Data, "m_bInReload");
	if (!inReload || weapon != activeWeapon)
	{
		int reserve = GetRealisticReloadReserveAmmo(client, weapon);
		int activeWeaponRef = IsValidEntity(activeWeapon) ? EntIndexToEntRef(activeWeapon) : INVALID_ENT_REFERENCE;
		char reason[32];
		if (inReload)
			strcopy(reason, sizeof(reason), "weapon_switch");
		else
			strcopy(reason, sizeof(reason), "reload_stopped");
		LogRealisticReloadDebug("track_cancel client=%N tick=%d time=%.3f reason=%s weapon=%d ref=%d active=%d active_ref=%d in_reload=%d start_clip=%d clip=%d start_reserve=%d reserve=%d", client, GetGameTickCount(), GetGameTime(), reason, weapon, EntIndexToEntRef(weapon), activeWeapon, activeWeaponRef, inReload ? 1 : 0, g_iPendingReloadStartClip[client], clip, g_iPendingReloadStartReserve[client], reserve);
		ClearPendingRealisticReloadState(client);
	}
}

void ApplyCompletedRealisticReload(int client, int weapon)
{
	int startClip = g_iPendingReloadStartClip[client];
	int startReserve = g_iPendingReloadStartReserve[client];
	int engineClip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	int engineReserve = GetRealisticReloadReserveAmmo(client, weapon);
	int finalClip = startReserve;
	if (finalClip > engineClip)
		finalClip = engineClip;

	int finalReserve = startReserve - finalClip;
	if (finalReserve < 0)
		finalReserve = 0;

	SetEntProp(weapon, Prop_Data, "m_iClip1", finalClip);
	SetRealisticReloadReserveAmmo(client, weapon, finalReserve);

	LogRealisticReloadDebug("apply_complete client=%N tick=%d time=%.3f mode=runtime_observed weapon=%d ref=%d start_clip=%d start_reserve=%d engine_clip=%d engine_reserve=%d final_clip=%d final_reserve=%d", client, GetGameTickCount(), GetGameTime(), weapon, EntIndexToEntRef(weapon), startClip, startReserve, engineClip, engineReserve, finalClip, finalReserve);
}

void ClearRealisticReloadState(int client)
{
	g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	ClearPendingRealisticReloadState(client);
	ClearRealisticReloadDebugState(client);
}

void ClearPendingRealisticReloadState(int client)
{
	g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadStartClip[client] = 0;
	g_iPendingReloadStartReserve[client] = 0;
}

void ClearRealisticReloadDebugState(int client)
{
	g_iDebugLastWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iDebugLastClip[client] = 0;
	g_iDebugLastReserve[client] = 0;
	g_bDebugLastInReload[client] = false;
	g_bDebugLastStateKnown[client] = false;
}

void TraceRealisticReloadState(int client, int weapon)
{
	if (!g_cvDebug.BoolValue)
		return;

	if (!IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Data, "m_iClip1"))
	{
		if (g_bDebugLastStateKnown[client])
		{
			LogRealisticReloadDebug("state client=%N tick=%d time=%.3f active=%d valid=0 pending_ref=%d applied_ref=%d", client, GetGameTickCount(), GetGameTime(), weapon, g_iPendingReloadWeaponRef[client], g_iAppliedReloadWeaponRef[client]);
			ClearRealisticReloadDebugState(client);
		}
		return;
	}

	int weaponRef = EntIndexToEntRef(weapon);
	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	int reserve = GetRealisticReloadReserveAmmo(client, weapon);
	bool inReload = HasEntProp(weapon, Prop_Data, "m_bInReload") && !!GetEntProp(weapon, Prop_Data, "m_bInReload");

	if (g_bDebugLastStateKnown[client]
		&& g_iDebugLastWeaponRef[client] == weaponRef
		&& g_iDebugLastClip[client] == clip
		&& g_iDebugLastReserve[client] == reserve
		&& g_bDebugLastInReload[client] == inReload)
	{
		return;
	}

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		strcopy(classname, sizeof(classname), "<unknown>");

	LogRealisticReloadDebug("state client=%N tick=%d time=%.3f weapon=%d ref=%d classname=%s in_reload=%d clip=%d reserve=%d pending_ref=%d applied_ref=%d", client, GetGameTickCount(), GetGameTime(), weapon, weaponRef, classname, inReload ? 1 : 0, clip, reserve, g_iPendingReloadWeaponRef[client], g_iAppliedReloadWeaponRef[client]);

	g_iDebugLastWeaponRef[client] = weaponRef;
	g_iDebugLastClip[client] = clip;
	g_iDebugLastReserve[client] = reserve;
	g_bDebugLastInReload[client] = inReload;
	g_bDebugLastStateKnown[client] = true;
}

void LogRealisticReloadDebug(const char[] format, any ...)
{
	if (!g_cvDebug.BoolValue)
		return;

	char message[512];
	VFormat(message, sizeof(message), format, 2);
	LogMessage("[realistic_reload_debug] %s", message);
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

bool IsRealisticReloadShellByShellShotgun(const char[] classname)
{
	if (strcmp(classname, "weapon_nova", false) == 0)
		return true;
	if (strcmp(classname, "weapon_sawedoff", false) == 0)
		return true;
	if (strcmp(classname, "weapon_xm1014", false) == 0)
		return true;

	return false;
}

bool IsValidAliveClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
