#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0.6"
#define REALISTIC_RELOAD_FIRE_GRACE 0.12

ConVar g_cvEnable;
ConVar g_cvHumans;
ConVar g_cvBots;
ConVar g_cvAlignReserve;
ConVar g_cvExcludeShotguns;

int g_iAppliedReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadWeaponRef[MAXPLAYERS + 1];
int g_iPendingReloadStartClip[MAXPLAYERS + 1];
int g_iPendingReloadFinalClip[MAXPLAYERS + 1];
int g_iPendingReloadFinalReserve[MAXPLAYERS + 1];
bool g_bPostThinkHooked[MAXPLAYERS + 1];
float g_fLastWeaponFireAt[MAXPLAYERS + 1];

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
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	for (int client = 1; client <= MaxClients; client++)
	{
		ClearRealisticReloadState(client);
		g_bPostThinkHooked[client] = false;
		g_fLastWeaponFireAt[client] = 0.0;
		if (IsClientInGame(client))
			HookRealisticReloadClient(client);
	}
}

public void OnClientPutInServer(int client)
{
	ClearRealisticReloadState(client);
	g_fLastWeaponFireAt[client] = 0.0;
	HookRealisticReloadClient(client);
}

public void OnClientDisconnect(int client)
{
	if (g_bPostThinkHooked[client])
	{
		SDKUnhook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
		g_bPostThinkHooked[client] = false;
	}

	ClearRealisticReloadState(client);
	g_fLastWeaponFireAt[client] = 0.0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
		ClearRealisticReloadState(client);

	RequestFrame(Frame_RefillAllPlayers);
	CreateTimer(0.2, Timer_RefillAllPlayers, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients)
		return;

	ClearRealisticReloadState(client);
	RequestFrame(Frame_RefillSpawnedPlayer, GetClientUserId(client));
	CreateTimer(0.1, Timer_RefillSpawnedPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public void Frame_RefillAllPlayers(any data)
{
	for (int client = 1; client <= MaxClients; client++)
		RefillClientWeaponsForNewRound(client);
}

public void Frame_RefillSpawnedPlayer(any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients)
		RefillClientWeaponsForNewRound(client);
}

public Action Timer_RefillAllPlayers(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
		RefillClientWeaponsForNewRound(client);

	return Plugin_Stop;
}

public Action Timer_RefillSpawnedPlayer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0 && client <= MaxClients)
		RefillClientWeaponsForNewRound(client);

	return Plugin_Stop;
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients)
		return;

	g_fLastWeaponFireAt[client] = GetGameTime();
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidAliveClient(client))
	{
		TryApplyRealisticReload(client, buttons);
	}
	else if (client > 0 && client <= MaxClients)
	{
		ClearRealisticReloadState(client);
	}

	return Plugin_Continue;
}

public void OnClientPostThinkPost(int client)
{
	if (!IsValidAliveClient(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(weapon) || !HasEntProp(weapon, Prop_Data, "m_bInReload"))
		return;

	if (GetEntProp(weapon, Prop_Data, "m_bInReload") != 0)
		return;

	FinishPendingRealisticReload(client, EntIndexToEntRef(weapon), weapon);
}

void TryApplyRealisticReload(int client, int buttons)
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

	if ((buttons & IN_ATTACK) != 0)
		return;

	if (GetGameTime() - g_fLastWeaponFireAt[client] < REALISTIC_RELOAD_FIRE_GRACE)
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

	int finalClip;
	int finalReserve;
	int reserveBeforeEngineLoad;
	CalculateRealisticReloadAmmo(classname, reserve, maxClip, finalClip, finalReserve, reserveBeforeEngineLoad);

	if (reserveBeforeEngineLoad <= 0 || finalClip <= 0)
	{
		ClearRealisticReloadState(client);
		return;
	}

	SetRealisticReloadReserveAmmo(client, weapon, reserveBeforeEngineLoad);
	SetEntProp(weapon, Prop_Data, "m_iClip1", 0);

	g_iAppliedReloadWeaponRef[client] = weaponRef;
	g_iPendingReloadWeaponRef[client] = weaponRef;
	g_iPendingReloadStartClip[client] = 0;
	g_iPendingReloadFinalClip[client] = finalClip;
	g_iPendingReloadFinalReserve[client] = finalReserve;
}

void FinishPendingRealisticReload(int client, int weaponRef, int weapon)
{
	if (g_iPendingReloadWeaponRef[client] == INVALID_ENT_REFERENCE)
		return;

	if (g_iPendingReloadWeaponRef[client] != weaponRef)
	{
		ClearRealisticReloadState(client);
		return;
	}

	int startClip = g_iPendingReloadStartClip[client];
	int finalClip = g_iPendingReloadFinalClip[client];
	int finalReserve = g_iPendingReloadFinalReserve[client];
	ClearRealisticReloadState(client);

	if (finalClip <= 0 || !HasEntProp(weapon, Prop_Data, "m_iClip1"))
		return;

	int clip = GetEntProp(weapon, Prop_Data, "m_iClip1");
	if (clip > startClip)
	{
		SetEntProp(weapon, Prop_Data, "m_iClip1", finalClip);
		SetRealisticReloadReserveAmmo(client, weapon, finalReserve);
	}
}

void CalculateRealisticReloadAmmo(const char[] classname, int reserve, int maxClip, int &finalClip, int &finalReserve, int &reserveBeforeEngineLoad)
{
	if (reserve < maxClip)
	{
		finalClip = reserve;
		finalReserve = 0;
		reserveBeforeEngineLoad = reserve;
		return;
	}

	finalClip = maxClip;
	finalReserve = reserve - maxClip;
	if (g_cvAlignReserve.BoolValue)
		finalReserve = AlignRealisticReloadReserve(finalReserve, maxClip, GetRealisticReloadMaxReserve(classname));

	reserveBeforeEngineLoad = finalReserve + finalClip;
	if (reserveBeforeEngineLoad > reserve)
		reserveBeforeEngineLoad = reserve;
}

void ClearRealisticReloadState(int client)
{
	g_iAppliedReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadWeaponRef[client] = INVALID_ENT_REFERENCE;
	g_iPendingReloadStartClip[client] = 0;
	g_iPendingReloadFinalClip[client] = 0;
	g_iPendingReloadFinalReserve[client] = 0;
}

void HookRealisticReloadClient(int client)
{
	if (g_bPostThinkHooked[client])
		return;

	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
	g_bPostThinkHooked[client] = true;
}

void RefillClientWeaponsForNewRound(int client)
{
	if (!IsValidAliveClient(client) || !ShouldApplyRealisticReloadToClient(client))
		return;

	RefillWeaponSlotForNewRound(client, 0);
	RefillWeaponSlotForNewRound(client, 1);
}

void RefillWeaponSlotForNewRound(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (!IsValidEntity(weapon))
		return;

	if (!HasEntProp(weapon, Prop_Data, "m_iClip1"))
		return;

	char classname[64];
	if (!GetEntityClassname(weapon, classname, sizeof(classname)))
		return;

	int maxClip = GetRealisticReloadMaxClip(classname);
	int maxReserve = GetRealisticReloadMaxReserve(classname);
	if (maxClip <= 0 || maxReserve <= 0)
		return;

	SetEntProp(weapon, Prop_Data, "m_iClip1", maxClip);
	SetRealisticReloadReserveAmmo(client, weapon, maxReserve);
}

bool ShouldApplyRealisticReloadToClient(int client)
{
	if (!g_cvEnable.BoolValue)
		return false;

	bool isBot = IsFakeClient(client);
	if (isBot && !g_cvBots.BoolValue)
		return false;
	if (!isBot && !g_cvHumans.BoolValue)
		return false;

	return true;
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
