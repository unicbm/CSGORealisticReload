#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"

ConVar g_cvEnable;
ConVar g_cvHumans;
ConVar g_cvBots;
ConVar g_cvAlignReserve;
ConVar g_cvExcludeShotguns;

int g_iAppliedReloadWeaponRef[MAXPLAYERS + 1];

enum
{
	DefIndexSpec_DefIndex,
	DefIndexSpec_MaxClip,
	DefIndexSpec_MaxReserve
};

enum
{
	ClassnameSpec_MaxClip,
	ClassnameSpec_MaxReserve
};

static const int g_iDefIndexAmmoSpecs[][] =
{
	{ 60, 20, 80 }, // M4A1-S may use weapon_m4a1 as classname on some servers.
	{ 61, 12, 24 }, // USP-S can appear as weapon_hkp2000.
	{ 63, 12, 12 }, // CZ75-Auto.
	{ 64, 8, 8 }    // R8 Revolver.
};

static const char g_sClassnameAmmoSpecs[][] =
{
	"weapon_deagle",
	"weapon_elite",
	"weapon_fiveseven",
	"weapon_glock",
	"weapon_ak47",
	"weapon_aug",
	"weapon_awp",
	"weapon_famas",
	"weapon_g3sg1",
	"weapon_galilar",
	"weapon_m249",
	"weapon_m4a1",
	"weapon_mac10",
	"weapon_p90",
	"weapon_mp5sd",
	"weapon_ump45",
	"weapon_bizon",
	"weapon_negev",
	"weapon_tec9",
	"weapon_hkp2000",
	"weapon_mp7",
	"weapon_mp9",
	"weapon_p250",
	"weapon_scar20",
	"weapon_sg556",
	"weapon_ssg08",
	"weapon_m4a1_silencer",
	"weapon_usp_silencer",
	"weapon_cz75a",
	"weapon_revolver"
};

static const int g_iClassnameAmmoSpecs[][] =
{
	{ 7, 35 },    // weapon_deagle
	{ 30, 120 },  // weapon_elite
	{ 20, 100 },  // weapon_fiveseven
	{ 20, 120 },  // weapon_glock
	{ 30, 90 },   // weapon_ak47
	{ 30, 90 },   // weapon_aug
	{ 5, 40 },    // weapon_awp
	{ 25, 90 },   // weapon_famas
	{ 20, 90 },   // weapon_g3sg1
	{ 35, 90 },   // weapon_galilar
	{ 100, 200 }, // weapon_m249
	{ 30, 90 },   // weapon_m4a1
	{ 30, 100 },  // weapon_mac10
	{ 50, 100 },  // weapon_p90
	{ 30, 120 },  // weapon_mp5sd
	{ 25, 100 },  // weapon_ump45
	{ 64, 120 },  // weapon_bizon
	{ 150, 200 }, // weapon_negev
	{ 18, 90 },   // weapon_tec9
	{ 13, 52 },   // weapon_hkp2000
	{ 30, 120 },  // weapon_mp7
	{ 30, 120 },  // weapon_mp9
	{ 13, 26 },   // weapon_p250
	{ 20, 90 },   // weapon_scar20
	{ 30, 90 },   // weapon_sg556
	{ 10, 90 },   // weapon_ssg08
	{ 20, 80 },   // weapon_m4a1_silencer
	{ 12, 24 },   // weapon_usp_silencer
	{ 12, 12 },   // weapon_cz75a
	{ 8, 8 }      // weapon_revolver
};

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

	int defIndex = HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
	int maxClip = GetRealisticReloadMaxClip(classname, defIndex);
	if (maxClip <= 0)
		return;

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip <= 0 || clip >= maxClip)
		return;

	int reserve = GetRealisticReloadReserveAmmo(client, weapon);
	if (reserve <= 0)
		return;

	int missing = maxClip - clip;
	int reserveBeforeEngineLoad;

	if (g_cvAlignReserve.BoolValue)
	{
		int targetReserveAfterReload = reserve - maxClip;
		if (targetReserveAfterReload < 0)
			targetReserveAfterReload = 0;
		targetReserveAfterReload = AlignRealisticReloadReserve(targetReserveAfterReload, maxClip, GetRealisticReloadMaxReserve(classname, defIndex));
		if (targetReserveAfterReload == 0 && reserve <= maxClip)
		{
			SetEntProp(weapon, Prop_Data, "m_iClip1", reserve);
			SetRealisticReloadReserveAmmo(client, weapon, 0);
			g_iAppliedReloadWeaponRef[client] = weaponRef;
			return;
		}

		reserveBeforeEngineLoad = targetReserveAfterReload + missing;
		if (reserveBeforeEngineLoad > reserve)
			reserveBeforeEngineLoad = reserve;
	}
	else
	{
		int extraReserve = reserve - missing;
		if (extraReserve <= 0)
			return;

		int penalty = clip;
		if (penalty > extraReserve)
			penalty = extraReserve;

		reserveBeforeEngineLoad = reserve - penalty;
	}

	if (reserveBeforeEngineLoad >= reserve)
		return;

	SetRealisticReloadReserveAmmo(client, weapon, reserveBeforeEngineLoad);
	g_iAppliedReloadWeaponRef[client] = weaponRef;
}

void ClearRealisticReloadState(int client)
{
	g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
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

int GetRealisticReloadMaxClip(const char[] classname, int defIndex = -1)
{
	int maxClip;
	int maxReserve;
	if (GetRealisticReloadAmmoSpec(classname, defIndex, maxClip, maxReserve))
		return maxClip;

	return 0;
}

int GetRealisticReloadMaxReserve(const char[] classname, int defIndex = -1)
{
	int maxClip;
	int maxReserve;
	if (GetRealisticReloadAmmoSpec(classname, defIndex, maxClip, maxReserve))
		return maxReserve;

	return 0;
}

bool GetRealisticReloadAmmoSpec(const char[] classname, int defIndex, int &maxClip, int &maxReserve)
{
	for (int i = 0; i < sizeof(g_iDefIndexAmmoSpecs); i++)
	{
		if (g_iDefIndexAmmoSpecs[i][DefIndexSpec_DefIndex] != defIndex)
			continue;

		maxClip = g_iDefIndexAmmoSpecs[i][DefIndexSpec_MaxClip];
		maxReserve = g_iDefIndexAmmoSpecs[i][DefIndexSpec_MaxReserve];
		return true;
	}

	for (int i = 0; i < sizeof(g_sClassnameAmmoSpecs); i++)
	{
		if (strcmp(classname, g_sClassnameAmmoSpecs[i], false) != 0)
			continue;

		maxClip = g_iClassnameAmmoSpecs[i][ClassnameSpec_MaxClip];
		maxReserve = g_iClassnameAmmoSpecs[i][ClassnameSpec_MaxReserve];
		return true;
	}

	maxClip = 0;
	maxReserve = 0;
	return false;
}

bool IsValidAliveClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client);
}
