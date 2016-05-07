/****************************************************************************************************
[CSGO] CSGO Items
*****************************************************************************************************
Credits: 
		NeuroToxin:
					I have learnt a lot from a lot from your previous work and that has helped create this.
****************************************************************************************************
CHANGELOG
****************************************************************************************************
	0.1 ~ 
		- Many changes which I did not even log..
	0.2 ~ 
	
		- Added the ability to get weapon team(s).
		- Added ability to get weapon clip size.
		- Added ability to refill weapon clip size.
		- Added ability to check if a weapon edict is valid.
	0.3 ~ 
	
		- Added CSGOItems_GiveWeapon
							This function is a replacement for GivePlayerItem, it fixes players not getting loadout skins when the weapon team is the opposite of the player.
							This function also automatically equips knives, so you don't need to use EquipPlayerWeapon.
							Example: CSGOItems_GiveWeapon(iClient, "weapon_ak47"); Player team = CT.
							Outcome: Player will recieve an AK47 with his loadout skin.
							Return: Weapon edict index or -1 if failed.
	0.4 ~
		
		- Added CSGOItems_RemoveWeapon
							This function will properly remove a weapon from a client and automatically kill the entity.
							Example: CSGOItems_RemoveWeapon(iClient, iWeapon);
							TBD: CSGOItems_RemoveWeaponSlot(iClient, CS_SLOT_PRIMARY);
							Outcome: The players weapon will be completely removed.
							Return: True on success or false if the weapon is invalid.
		
		- Improved CSGOItems_GiveWeapon
							- Added the ability to set custom reserve / clip ammo (Only for guns for obvious reasons :P).
								- Example: CSGOItems_GiveWeapon("weapon_ak47", 10, 30); 10 reserve + 30 clip, if nothing defined it will use games default values.
							- Improved team switching functionality.
							- Improved equip functionality to remove animations, This is still WIP and does not yet work for all weapons.
		
		- Added CSGOItems_SetWeaponAmmo (Thanks Zipcore for the suggestion)
							This function allows you to set the ammo if any valid weapon entity index.
							Example: CSGOItems_SetWeaponAmmo(iWeapon, 30, 30); 30 Reserve / 30 Clip.
							Usage: You can use -1 to skip setting a certain type of ammo, CSGOItems_SetWeaponAmmo(iWeapon, -1, 30); would skip changing the reserve ammo.
							Outcome: The weapon Reserve and / or clip ammo will be changed if the weapon index is valid.
							Return: True on success or false if the weapon is invalid.
							
		0.5 ~
			- Will add a changelog later, too tired for it now :P
		
		0.6 ~ 
			- Fixed Reserve and Clip ammo functionality.
			- Fixed a bug which caused KV Iteration to fail in some cases.
			- Fixed error spam related to m_iZoomLevel.
			- Added CSGOItems_RemoveKnife. (This function will remove the players knife without removing the Zeus if he has one.)
			- Added CSGOItems_RefillReserveAmmo.
			- Added Reserve ammo natives (For retrieving the values).
			- General Cleanup.
		0.7 ~
			- Removed System2.
			- Using SteamWorks now to retrieve language file.
			- Fixed potential infinite loop / crash.
		0.8 ~
			- General optimization / cleanup.
			- Added CSGOItems_GetRandomSkin
							This function will return a random skin defindex.		
			
			- Added CSGOItems_SetAllWeaponsAmmo
							This function will loop through all spawned weapons of a specific classname and set clip/reserve ammo.
		0.9 ~
			- Added CSGOItems_GetActiveWeaponCount
							This function will return the number of actively equipped weapons by classname.
							
							Example 1, Get number of players with AWP equipped on CT: 
									CSGOItems_GetActiveWeaponCount("weapon_awp", CS_TEAM_CT);
							
							Example 2, Get number of players with AWP equipped on T: 
									CSGOItems_GetActiveWeaponCount("weapon_awp", CS_TEAM_T);
									
							Example 3, Get number of players with AWP equipped on any team: 
									CSGOItems_GetActiveWeaponCount("weapon_awp");
									
			- Added CSGOItems_GetWeaponKillAward(ByDefIndex, ByClassName, ByWeaponNum)
							These functions will return the kill award for the specified weapon.
			
			- Fixed some logic errors with variables / loops.
			- Fixed a rare issue where CSGOItems_GiveWeapon would fail when it shouldn't of.
		1.0 ~
			- New method for Removing player weapons, this should fix some crashes!
									
									
****************************************************************************************************
INCLUDES
***************************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <cstrike> 
#include <sdkhooks> 
#include <SteamWorks> 
#include <csgoitems> 

/****************************************************************************************************
DEFINES
*****************************************************************************************************/
#define VERSION "1.0"

#define 	DEFINDEX 		0
#define 	CLASSNAME 		1
#define 	DISPLAYNAME 	2
#define 	SLOT 			3
#define 	TEAM 			4
#define 	CLIPAMMO 		5
#define 	RESERVEAMMO 	6
#define 	TYPE 			7
#define 	KILLAWARD 		8
#define 	LANGURL         "https://raw.githubusercontent.com/SteamDatabase/GameTracking/master/csgo/csgo/resource/csgo_english_utf8.txt"

/****************************************************************************************************
ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required // To be moved before includes one day.
#pragma semicolon 1

/****************************************************************************************************
PLUGIN INFO.
*****************************************************************************************************/
public Plugin myinfo = 
{
	name = "CSGO Items", 
	author = "SM9", 
	version = VERSION, 
	url = "http://www.fragdeluxe.com"
};

/****************************************************************************************************
HANDLES.
*****************************************************************************************************/
Handle g_hItemsKv = null;
Handle g_hOnItemsSynced = null;
Handle g_hOnPluginEnd = null;
Handle g_hSwitchWeaponCall = null;

/****************************************************************************************************
BOOLS.
*****************************************************************************************************/
bool g_bIsDefIndexKnife[600];
bool g_bIsDefIndexSkinnable[600];
bool g_bItemsSynced;
bool g_bItemsSyncing;
bool g_bLanguageDownloading;
bool g_bClientEquipping[MAXPLAYERS + 1];
bool g_bGivingWeapon[MAXPLAYERS + 1];
bool g_bWeaponEquipping[2049];
/****************************************************************************************************
STRINGS.
*****************************************************************************************************/
char g_chWeaponInfo[100][9][48];
char g_chPaintInfo[600][3][48];
char g_chMusicKitInfo[100][3][48];
char g_chLangPhrases[2198296];

static char g_chViewSequence1[][] =  {
	"weapon_knife_falchion", "weapon_knife_push", 
	"weapon_knife_survival_bowie", "weapon_m4a1_silencer"
};

/****************************************************************************************************
INTS.
*****************************************************************************************************/
int g_iPaintCount = 0;
int g_iWeaponCount = 0;
int g_iMusicKitCount = 0;
int g_iDownloadAttempts = 0;

#define CSGOItems_LoopWeapons(%1) for(int %1 = 0; %1 < g_iWeaponCount; %1++)
#define CSGOItems_LoopSkins(%1) for(int %1 = 0; %1 < g_iPaintCount; %1++)
#define CSGOItems_LoopMusicKits(%1) for(int %1 = 0; %1 < g_iMusicKitCount; %1++)
#define CSGOItems_LoopWeaponSlots(%1) for(int %1 = 0; %1 < 6; %1++)
#define CSGOItems_LoopValidWeapons(%1) for(int %1 = MaxClients; %1 < 2048; %1++) if(CSGOItems_IsValidWeapon(%1))
#define CSGOItems_LoopValidClients(%1) for(int %1 = 1; %1 < MaxClients; %1++) if(IsValidClient(%1))

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO) {
		Call_StartForward(g_hOnPluginEnd);
		Call_Finish();
		SetFailState("This plugin is for CSGO only.");
	}
	
	/****************************************************************************************************
											--FORWARDS--
	*****************************************************************************************************/
	g_hOnItemsSynced = CreateGlobalForward("CSGOItems_OnItemsSynced", ET_Ignore);
	g_hOnPluginEnd = CreateGlobalForward("CSGOItems_OnPluginEnd", ET_Ignore);
	
	Handle hConfig = LoadGameConfigFile("sdkhooks.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "Weapon_Switch");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	
	g_hSwitchWeaponCall = EndPrepSDKCall();
	
	CloseHandle(hConfig);
	
	CSGOItems_LoopValidClients(iClient) {
		OnClientPutInServer(iClient);
	}
	
	HookEvent("player_death", Event_PlayerDeath);
}

public int SteamWorks_SteamServersConnected() {
	RetrieveLanguage();
}

public void OnPluginEnd()
{
	Call_StartForward(g_hOnPluginEnd);
	Call_Finish();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] chError, int iErrMax)
{
	/****************************************************************************************************
											--GENERAL NATIVES--
	*****************************************************************************************************/
	// Item Counts
	CreateNative("CSGOItems_GetWeaponCount", Native_GetWeaponCount);
	CreateNative("CSGOItems_GetSkinCount", Native_GetSkinCount);
	CreateNative("CSGOItems_GetMusicKitCount", Native_GetMusicKitCount);
	CreateNative("CSGOItems_AreItemsSynced", Native_AreItemsSynced);
	CreateNative("CSGOItems_AreItemsSyncing", Native_AreItemsSyncing);
	CreateNative("CSGOItems_ReSync", Native_Resync);
	CreateNative("CSGOItems_GetActiveWeaponCount", Native_GetActiveWeaponCount);
	
	/****************************************************************************************************
											--WEAPON NATIVES--
	*****************************************************************************************************/
	// Weapon Numbers
	CreateNative("CSGOItems_GetWeaponNumByDefIndex", Native_GetWeaponNumByDefIndex);
	CreateNative("CSGOItems_GetWeaponNumByClassName", Native_GetWeaponNumByClassName);
	
	// Weapon Definition Indexes
	CreateNative("CSGOItems_GetWeaponDefIndexByWeaponNum", Native_GetWeaponDefIndexByWeaponNum);
	CreateNative("CSGOItems_GetWeaponDefIndexByClassName", Native_GetWeaponDefIndexByClassName);
	
	// Weapon Class Names
	CreateNative("CSGOItems_GetWeaponClassNameByWeaponNum", Native_GetWeaponClassNameByWeaponNum);
	CreateNative("CSGOItems_GetWeaponClassNameByDefIndex", Native_GetWeaponClassNameByDefIndex);
	CreateNative("CSGOItems_GetWeaponClassNameByWeapon", Native_GetWeaponClassNameByWeapon);
	
	// Weapon Display Names
	CreateNative("CSGOItems_GetWeaponDisplayNameByDefIndex", Native_GetWeaponDisplayNameByDefIndex);
	CreateNative("CSGOItems_GetWeaponDisplayNameByClassName", Native_GetWeaponDisplayNameByClassName);
	CreateNative("CSGOItems_GetWeaponDisplayNameByWeaponNum", Native_GetWeaponDisplayNameByWeaponNum);
	
	// Weapon Teams
	CreateNative("CSGOItems_GetWeaponTeamByDefIndex", Native_GetWeaponTeamByDefIndex);
	CreateNative("CSGOItems_GetWeaponTeamByClassName", Native_GetWeaponTeamByClassName);
	CreateNative("CSGOItems_GetWeaponTeamByWeaponNum", Native_GetWeaponTeamByWeaponNum);
	
	// Weapon Slots
	CreateNative("CSGOItems_GetWeaponSlotByWeaponNum", Native_GetWeaponSlotByWeaponNum);
	CreateNative("CSGOItems_GetWeaponSlotByClassName", Native_GetWeaponSlotByClassName);
	CreateNative("CSGOItems_GetWeaponSlotByDefIndex", Native_GetWeaponSlotByDefIndex);
	
	// Weapon Ammo
	CreateNative("CSGOItems_GetWeaponClipAmmoByDefIndex", Native_GetWeaponClipAmmoByDefIndex);
	CreateNative("CSGOItems_GetWeaponClipAmmoByClassName", Native_GetWeaponClipAmmoByClassName);
	CreateNative("CSGOItems_GetWeaponClipAmmoByWeaponNum", Native_GetWeaponClipAmmoByWeaponNum);
	CreateNative("CSGOItems_GetWeaponReserveAmmoByDefIndex", Native_GetWeaponReserveAmmoByDefIndex);
	CreateNative("CSGOItems_GetWeaponReserveAmmoByClassName", Native_GetWeaponReserveAmmoByClassName);
	CreateNative("CSGOItems_GetWeaponReserveAmmoByWeaponNum", Native_GetWeaponReserveAmmoByWeaponNum);
	CreateNative("CSGOItems_SetWeaponAmmo", Native_SetWeaponAmmo);
	CreateNative("CSGOItems_SetAllWeaponsAmmo", Native_SetAllWeaponsAmmo);
	CreateNative("CSGOItems_RefillClipAmmo", Native_RefillClipAmmo);
	CreateNative("CSGOItems_RefillReserveAmmo", Native_RefillReserveAmmo);
	
	// Weapon Cash
	CreateNative("CSGOItems_GetWeaponKillAwardByDefIndex", Native_GetWeaponKillAwardByDefIndex);
	CreateNative("CSGOItems_GetWeaponKillAwardByClassName", Native_GetWeaponKillAwardByClassName);
	CreateNative("CSGOItems_GetWeaponKillAwardByWeaponNum", Native_GetWeaponKillAwardByWeaponNum);
	
	// Misc
	CreateNative("CSGOItems_IsDefIndexKnife", Native_IsDefIndexKnife);
	CreateNative("CSGOItems_GetWeaponDefIndexByWeapon", Native_GetWeaponDefIndexByWeapon);
	CreateNative("CSGOItems_GetActiveClassName", Native_GetActiveClassName);
	CreateNative("CSGOItems_GetActiveWeaponDefIndex", Native_GetActiveWeaponDefIndex);
	CreateNative("CSGOItems_GetActiveWeaponNum", Native_GetActiveWeaponNum);
	CreateNative("CSGOItems_GetActiveWeapon", Native_GetActiveWeapon);
	CreateNative("CSGOItems_FindWeaponByClassName", Native_FindWeaponByClassName);
	CreateNative("CSGOItems_IsValidWeapon", Native_IsValidWeapon);
	CreateNative("CSGOItems_GiveWeapon", Native_GiveWeapon);
	CreateNative("CSGOItems_RemoveWeapon", Native_RemoveWeapon);
	CreateNative("CSGOItems_RemoveKnife", Native_RemoveKnife);
	CreateNative("CSGOItems_SetActiveWeapon", Native_SetActiveWeapon);
	CreateNative("CSGOItems_GetActiveWeaponSlot", Native_GetActiveWeaponSlot);
	
	/****************************************************************************************************
											--SKIN NATIVES--
	*****************************************************************************************************/
	
	// Skin Numbers
	CreateNative("CSGOItems_GetSkinNumByDefIndex", Native_GetSkinNumByDefIndex);
	
	// Skin Definition Indexes
	CreateNative("CSGOItems_GetSkinDefIndexBySkinNum", Native_GetSkinDefIndexBySkinNum);
	
	// Skin Display Names
	CreateNative("CSGOItems_GetSkinDisplayNameByDefIndex", Native_GetSkinDisplayNameByDefIndex);
	CreateNative("CSGOItems_GetSkinDisplayNameBySkinNum", Native_GetSkinDisplayNameBySkinNum);
	
	// Misc
	CreateNative("CSGOItems_IsSkinnableDefIndex", Native_IsSkinnableDefIndex);
	CreateNative("CSGOItems_GetRandomSkin", Native_GetRandomSkin);
	
	/****************************************************************************************************
											--MUSIC KIT NATIVES--
	*****************************************************************************************************/
	
	// Music Kit Numbers
	CreateNative("CSGOItems_GetMusicKitNumByDefIndex", Native_GetMusicKitNumByDefIndex);
	
	// Music Kit Definition Indexes
	CreateNative("CSGOItems_GetMusicKitDefIndexByMusicKitNum", Native_GetMusicKitDefIndexByMusicKitNum);
	
	// Music Kit Display Names
	CreateNative("CSGOItems_GetMusicKitDisplayNameByDefIndex", Native_GetMusicKitDisplayNameByDefIndex);
	CreateNative("CSGOItems_GetMusicKitDisplayNameByWeaponNum", Native_GetMusicKitDisplayNameByMusicKitNum);
}

public bool RetrieveLanguage()
{
	if (g_bItemsSyncing || g_bLanguageDownloading) {
		return false;
	}
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, LANGURL);
	
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
	SteamWorks_SetHTTPCallbacks(hRequest, Language_Retrieved);
	
	if (SteamWorks_SendHTTPRequest(hRequest)) {
		g_bLanguageDownloading = true;
		g_iDownloadAttempts++;
		return true;
	} else {
		CreateTimer(2.0, Timer_SyncLanguage, hRequest);
		LogMessage("[WARNING] SteamWorks language retrieval failed, attempting to use old file (If one is available)");
	}
	
	return false;
}

public int Language_Retrieved(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any anything)
{
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK) {
		if (FileExists("resource/csgo_english_utf8.txt")) {
			SteamWorks_WriteHTTPResponseBodyToFile(hRequest, "resource/csgo_english_utf8_new.txt");
		} else {
			SteamWorks_WriteHTTPResponseBodyToFile(hRequest, "resource/csgo_english_utf8.txt");
		}
	}
	
	LogMessage("UTF-8 language file successfully retrieved.");
	
	CreateTimer(2.0, Timer_SyncLanguage, hRequest);
}

public Action Timer_SyncLanguage(Handle hTimer, Handle hRequest)
{
	Handle hLanguageFile = OpenFile("resource/csgo_english_utf8.txt", "r");
	Handle hLanguageFileNew = OpenFile("resource/csgo_english_utf8_new.txt", "r");
	
	if (hLanguageFileNew != null && ReadFileString(hLanguageFileNew, g_chLangPhrases, 2198296) && StrContains(g_chLangPhrases, "// GAMEUI_ENGLISH.txt") != -1) {
		DeleteFile("resource/csgo_english_utf8.txt");
		RenameFile("resource/csgo_english_utf8.txt", "resource/csgo_english_utf8_new.txt");
	}
	
	else if (hLanguageFile != null && ReadFileString(hLanguageFile, g_chLangPhrases, 2198296) && StrContains(g_chLangPhrases, "// GAMEUI_ENGLISH.txt") != -1) {
		DeleteFile("resource/csgo_english_utf8_new.txt");
	}
	else {
		g_bLanguageDownloading = false;
		
		if (hRequest != null) {
			CloseHandle(hRequest);
		}
		
		if (hLanguageFile != null) {
			CloseHandle(hLanguageFile);
		}
		
		if (hLanguageFileNew != null) {
			CloseHandle(hLanguageFileNew);
		}
		
		DeleteFile("resource/csgo_english_utf8.txt"); DeleteFile("resource/csgo_english_utf8_new.txt");
		
		if (g_iDownloadAttempts < 10) {
			RetrieveLanguage();
			return Plugin_Stop;
		} else {
			Call_StartForward(g_hOnPluginEnd);
			Call_Finish();
			SetFailState("UTF-8 language file is corrupted, failed after %d attempts. \nCheck: %s", g_iDownloadAttempts, LANGURL);
		}
	}
	
	if (hRequest != null) {
		CloseHandle(hRequest);
	}
	
	if (hLanguageFile != null) {
		CloseHandle(hLanguageFile);
	}
	
	if (hLanguageFileNew != null) {
		CloseHandle(hLanguageFileNew);
	}
	
	g_bLanguageDownloading = false;
	g_iDownloadAttempts = 0;
	LogMessage("UTF-8 language file successfully processed, starting item data synchronization.");
	
	if (!g_bItemsSyncing) {
		SyncItemData();
	}
	
	return Plugin_Stop;
}

public void SyncItemData()
{
	g_bItemsSyncing = true;
	
	g_iPaintCount = 0;
	g_iWeaponCount = 0;
	g_iMusicKitCount = 0;
	
	g_hItemsKv = CreateKeyValues("items_game");
	
	if (!FileToKeyValues(g_hItemsKv, "scripts/items/items_game.txt")) {
		Call_StartForward(g_hOnPluginEnd);
		Call_Finish();
		SetFailState("Unable to Read/Open items_game.txt");
	}
	
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "items") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		Call_StartForward(g_hOnPluginEnd);
		Call_Finish();
		SetFailState("Unable to find Item keyvalues");
	}
	
	char chBuffer[48]; char chBuffer2[48];
	
	do {
		KvGetString(g_hItemsKv, "name", chBuffer, 48);
		
		if (IsValidWeaponClassName(chBuffer)) {
			KvGetSectionName(g_hItemsKv, g_chWeaponInfo[g_iWeaponCount][DEFINDEX], 48);
			strcopy(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], 48, chBuffer);
			
			if (StrEqual(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], "weapon_c4", false)) {
				g_chWeaponInfo[g_iWeaponCount][TEAM] = "2";
			}
			
			KvGetString(g_hItemsKv, "prefab", chBuffer, 48);
			
			if (StrContains(chBuffer, "melee") != -1) {
				g_bIsDefIndexKnife[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
				
				if (StrContains(chBuffer, "unusual") != -1) {
					g_bIsDefIndexSkinnable[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
					g_chWeaponInfo[g_iWeaponCount][SLOT] = "melee";
				}
			}
			
			int iKillAward = -1;
			
			bool bKillAwardFound = GetWeaponKillAward(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], g_chWeaponInfo[g_iWeaponCount][KILLAWARD], 48);
			
			if (bKillAwardFound) {
				iKillAward = StringToInt(g_chWeaponInfo[g_iWeaponCount][KILLAWARD]);
			}
			
			if (IsSpecialPrefab(chBuffer)) {
				KvGetString(g_hItemsKv, "item_name", chBuffer, 48);
			} else {
				KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
				
				if (KvJumpToKey(g_hItemsKv, "prefabs")) {
					
					if (KvJumpToKey(g_hItemsKv, chBuffer)) {
						KvGetString(g_hItemsKv, "prefab", g_chWeaponInfo[g_iWeaponCount][TYPE], 48);
						KvGetString(g_hItemsKv, "item_name", chBuffer, 48);
					}
					
					if (KvJumpToKey(g_hItemsKv, "used_by_classes")) {
						bool bTerrorist = KvGetNum(g_hItemsKv, "terrorists") == 1;
						bool bCounterTerrorist = KvGetNum(g_hItemsKv, "counter-terrorists") == 1;
						bool bBothTeams = bTerrorist && bCounterTerrorist;
						
						if (bBothTeams) {
							g_chWeaponInfo[g_iWeaponCount][TEAM] = "0";
						}
						
						else if (bTerrorist) {
							g_chWeaponInfo[g_iWeaponCount][TEAM] = "2";
						}
						
						else if (bCounterTerrorist) {
							g_chWeaponInfo[g_iWeaponCount][TEAM] = "3";
						}
						
						KvGoBack(g_hItemsKv);
					} else {
						g_chWeaponInfo[g_iWeaponCount][TEAM] = "0";
					}
					
					if (KvJumpToKey(g_hItemsKv, "attributes")) {
						int iClipAmmo = KvGetNum(g_hItemsKv, "primary clip size", -1);
						int iReserveAmmo = KvGetNum(g_hItemsKv, "primary reserve ammo max", -1);
						
						if (iKillAward <= -1 || !bKillAwardFound) {
							iKillAward = KvGetNum(g_hItemsKv, "kill award", -1);
						}
						
						if (iClipAmmo > 0) {
							IntToString(iClipAmmo, g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], 48);
						} else {
							GetWeaponClip(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], 48);
						}
						
						IntToString(iReserveAmmo, g_chWeaponInfo[g_iWeaponCount][RESERVEAMMO], 48);
						
						KvGoBack(g_hItemsKv);
					}
					
					KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
					
					if (KvJumpToKey(g_hItemsKv, "items")) {
						KvJumpToKey(g_hItemsKv, g_chWeaponInfo[g_iWeaponCount][DEFINDEX]);
					}
				}
			}
			
			if (iKillAward <= 0) {
				IntToString(300, g_chWeaponInfo[g_iWeaponCount][KILLAWARD], 48);
			} else {
				IntToString(iKillAward, g_chWeaponInfo[g_iWeaponCount][KILLAWARD], 48);
			}
			
			if (StrEqual(g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], "", false)) {
				strcopy(g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], 4, "-1");
			}
			
			if (StrEqual(g_chWeaponInfo[g_iWeaponCount][RESERVEAMMO], "", false)) {
				strcopy(g_chWeaponInfo[g_iWeaponCount][RESERVEAMMO], 4, "-1");
			}
			
			GetItemName(chBuffer, g_chWeaponInfo[g_iWeaponCount][DISPLAYNAME], 48);
			
			KvGetString(g_hItemsKv, "item_sub_position", chBuffer, 48);
			
			if (StrContains(chBuffer, "grenade") == -1 && StrContains(chBuffer, "equipment") == -1 && !StrEqual(chBuffer, "", false) && StrContains(chBuffer, "melee") == -1) {
				g_bIsDefIndexSkinnable[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
			}
			
			if (!StrEqual(chBuffer, "", false)) {
				strcopy(g_chWeaponInfo[g_iWeaponCount][SLOT], 48, chBuffer);
			}
			
			g_iWeaponCount++;
		}
	}
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "paint_kits") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		Call_StartForward(g_hOnPluginEnd);
		Call_Finish();
		SetFailState("Unable to find Paintkit keyvalues");
	}
	
	do {
		KvGetSectionName(g_hItemsKv, chBuffer, 48);
		int iSkinDefIndex = StringToInt(chBuffer);
		
		if (iSkinDefIndex != 0 && iSkinDefIndex != 9001) {
			strcopy(g_chPaintInfo[g_iPaintCount][DEFINDEX], 48, chBuffer);
			KvGetString(g_hItemsKv, "description_tag", chBuffer, 48);
			GetItemName(chBuffer, g_chPaintInfo[g_iPaintCount][DISPLAYNAME], 48);
			
			g_iPaintCount++;
		}
		
	}
	
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "music_definitions") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		Call_StartForward(g_hOnPluginEnd);
		Call_Finish();
		SetFailState("Unable to find Music Kit keyvalues");
	}
	
	do {
		KvGetSectionName(g_hItemsKv, chBuffer, 48); int iMusicDefIndex = StringToInt(chBuffer);
		if (iMusicDefIndex > 2) {
			strcopy(g_chMusicKitInfo[g_iMusicKitCount][DEFINDEX], 48, chBuffer);
			KvGetString(g_hItemsKv, "loc_name", chBuffer2, 48);
			GetItemName(chBuffer2, g_chMusicKitInfo[g_iMusicKitCount][DISPLAYNAME], 48);
			
			g_iMusicKitCount++;
		}
	}
	
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	CloseHandle(g_hItemsKv);
	Call_StartForward(g_hOnItemsSynced);
	Call_Finish();
	
	g_bItemsSynced = true;
	g_bItemsSyncing = false;
}

public Action Event_PlayerDeath(Handle hEvent, const char[] chName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	g_bClientEquipping[iClient] = false;
	g_bGivingWeapon[iClient] = false;
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int iClient) {
	SDKHook(iClient, SDKHook_WeaponEquip, OnWeaponEquip_Pre);
	SDKHook(iClient, SDKHook_WeaponEquipPost, OnWeaponEquip_Post);
}

public void OnClientDisconnect(int iClient) {
	g_bClientEquipping[iClient] = false;
	g_bGivingWeapon[iClient] = false;
}

public Action OnWeaponEquip_Pre(int iClient, int iWeapon)
{
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return Plugin_Handled;
	}
	
	g_bClientEquipping[iClient] = true;
	g_bWeaponEquipping[iWeapon] = true;
	
	return Plugin_Continue;
}

public Action OnWeaponEquip_Post(int iClient, int iWeapon)
{
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return Plugin_Handled;
	}
	
	g_bClientEquipping[iClient] = false;
	g_bWeaponEquipping[iWeapon] = false;
	
	return Plugin_Continue;
}

stock void GetItemName(char[] chPhrase, char[] chBuffer, int iLength)
{
	int iPos = StrContains(g_chLangPhrases, chPhrase[1], false);
	
	if (iPos == -1) {
		strcopy(chBuffer, iLength, "");
		return;
	}
	
	int iLen = strlen(chPhrase);
	
	iPos += iLen + 1;
	iPos += StrContains(g_chLangPhrases[iPos], "\"") + 1;
	iLen = StrContains(g_chLangPhrases[iPos], "\"") + 1;
	
	strcopy(chBuffer, iLen, g_chLangPhrases[iPos]);
}

stock void GetWeaponClip(char[] chClassName, char[] chReturn, int iLength)
{
	char chBuffer[128]; Format(chBuffer, 64, "scripts/%s.txt", chClassName);
	
	Handle hFile = OpenFile(chBuffer, "r");
	
	if (hFile == null) {
		strcopy(chReturn, iLength, "-1");
		return;
	}
	
	while (ReadFileLine(hFile, chBuffer, 128) && !IsEndOfFile(hFile)) {
		if (StrContains(chBuffer, "clip_size", false) != -1 && StrContains(chBuffer, "default", false) == -1) {
			ReplaceString(chBuffer, 128, "clip_size", "", false); ReplaceString(chBuffer, 128, "\"", "", false);
			TrimString(chBuffer); StripQuotes(chBuffer);
			strcopy(chReturn, iLength, chBuffer);
			break;
		}
	}
	
	if (StrEqual(chReturn, "", false) || StrEqual(chReturn, "0", false)) {
		strcopy(chReturn, iLength, "-1");
	}
	
	CloseHandle(hFile);
}

stock bool GetWeaponKillAward(char[] chClassName, char[] chReturn, int iLength)
{
	char chBuffer[128]; 
	
	if (CSGOItems_IsDefIndexKnife(CSGOItems_GetWeaponDefIndexByClassName(chClassName))) {
		Format(chBuffer, 64, "scripts/weapon_knife.txt", chClassName);
	} else {
		Format(chBuffer, 64, "scripts/%s.txt", chClassName);
	}
	
	Handle hFile = OpenFile(chBuffer, "r");
	
	if (hFile == null) {
		strcopy(chReturn, iLength, "-1");
		return false;
	}
	
	while (ReadFileLine(hFile, chBuffer, 128) && !IsEndOfFile(hFile)) {
		if (StrContains(chBuffer, "KillAward", false) != -1 && StrContains(chBuffer, "Weapon", false) == -1) {
			ReplaceString(chBuffer, 128, "KillAward", "", false); ReplaceString(chBuffer, 128, "\"", "", false);
			TrimString(chBuffer); StripQuotes(chBuffer);
			strcopy(chReturn, iLength, chBuffer);
			break;
		}
	}
	
	if (StrEqual(chReturn, "", false) || StrEqual(chReturn, "0", false)) {
		strcopy(chReturn, iLength, "-1");
		return false;
	}
	
	CloseHandle(hFile);
	return true;
}

stock bool IsValidWeaponClassName(char[] chClassName)
{
	return StrContains(chClassName, "weapon_") != -1 && StrContains(chClassName, "base") == -1 && StrContains(chClassName, "case") == -1;
}

stock bool IsSpecialPrefab(char[] chPrefabName)
{
	return StrContains(chPrefabName, "_prefab") == -1;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	return IsClientInGame(iClient);
}

stock int SlotNameToNum(const char[] chSlotName)
{
	if (StrContains(chSlotName, "rifle") != -1 || StrContains(chSlotName, "heavy") != -1 || StrContains(chSlotName, "smg") != -1) {
		return CS_SLOT_PRIMARY;
	}
	
	else if (StrContains(chSlotName, "secondary") != -1) {
		return CS_SLOT_SECONDARY;
	}
	
	else if (StrContains(chSlotName, "c4") != -1) {
		return CS_SLOT_C4;
	}
	
	else if (StrContains(chSlotName, "melee") != -1) {
		return CS_SLOT_KNIFE;
	}
	
	else if (StrContains(chSlotName, "grenade") != -1) {
		return CS_SLOT_GRENADE;
	}
	
	return -1;
}

public int Native_GetWeaponCount(Handle hPlugin, int iNumParams) {
	return g_iWeaponCount;
}

public int Native_GetSkinCount(Handle hPlugin, int iNumParams) {
	return g_iPaintCount;
}

public int Native_GetMusicKitCount(Handle hPlugin, int iNumParams) {
	return g_iMusicKitCount;
}

public int Native_GetWeaponNumByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return iWeaponNum;
		}
	}
	
	return -1;
}

public int Native_GetWeaponTeamByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][TEAM]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponTeamByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][TEAM]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponTeamByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	return StringToInt(g_chWeaponInfo[iWeaponNum][TEAM]);
}

public int Native_GetWeaponClipAmmoByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponClipAmmoByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponClipAmmoByWeaponNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chWeaponInfo[GetNativeCell(1)][CLIPAMMO]);
}

public int Native_GetWeaponKillAwardByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][KILLAWARD]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponKillAwardByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][KILLAWARD]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponKillAwardByWeaponNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chWeaponInfo[GetNativeCell(1)][KILLAWARD]);
}

public int Native_GetWeaponReserveAmmoByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][RESERVEAMMO]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponReserveAmmoByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][RESERVEAMMO]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponReserveAmmoByWeaponNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chWeaponInfo[GetNativeCell(1)][RESERVEAMMO]);
}

public int Native_SetWeaponAmmo(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	int iReserveAmmo = GetNativeCell(2);
	int iClipAmmo = GetNativeCell(3);
	
	if (iReserveAmmo == -1 && iClipAmmo == -1) {
		return false;
	}
	
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return false;
	}
	
	if (iReserveAmmo > -1) {
		SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iReserveAmmo);
	}
	
	if (iClipAmmo > -1) {
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClipAmmo);
	}
	
	return true;
}

public int Native_RefillClipAmmo(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	int iDefIndex = CSGOItems_GetWeaponDefIndexByWeapon(iWeapon);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			int iClipAmmo = StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]);
			CSGOItems_SetWeaponAmmo(iWeapon, -1, iClipAmmo > 0 ? iClipAmmo : -1);
			return true;
		}
	}
	
	return false;
}

public int Native_RefillReserveAmmo(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	int iDefIndex = CSGOItems_GetWeaponDefIndexByWeapon(iWeapon);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			int iReserveAmmo = StringToInt(g_chWeaponInfo[iWeaponNum][RESERVEAMMO]);
			CSGOItems_SetWeaponAmmo(iWeapon, iReserveAmmo > 0 ? iReserveAmmo : -1, -1);
			return true;
		}
	}
	
	return false;
}

public int Native_GetWeaponNumByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return iWeaponNum;
		}
	}
	
	return -1;
}

public int Native_GetSkinNumByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopSkins(iSkinNum) {
		if (StringToInt(g_chPaintInfo[iSkinNum][DEFINDEX]) == iDefIndex) {
			return iSkinNum;
		}
	}
	
	return -1;
}

public int Native_GetMusicKitNumByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopMusicKits(iMusicKitNum) {
		if (StringToInt(g_chMusicKitInfo[iMusicKitNum][DEFINDEX]) == iDefIndex) {
			return iMusicKitNum;
		}
	}
	
	return -1;
}

public int Native_GetWeaponDefIndexByWeaponNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chWeaponInfo[GetNativeCell(1)][DEFINDEX]);
}

public int Native_GetWeaponDefIndexByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]);
		}
	}
	
	return -1;
}

public int Native_GetSkinDefIndexBySkinNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chPaintInfo[GetNativeCell(1)][DEFINDEX]);
}

public int Native_GetMusicKitDefIndexByMusicKitNum(Handle hPlugin, int iNumParams) {
	return StringToInt(g_chMusicKitInfo[GetNativeCell(1)][DEFINDEX]);
}

public int Native_GetWeaponClassNameByWeaponNum(Handle hPlugin, int iNumParams)
{
	SetNativeString(2, g_chWeaponInfo[GetNativeCell(1)][CLASSNAME], GetNativeCell(3));
	return true;
}

public int Native_GetWeaponClassNameByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			SetNativeString(2, g_chWeaponInfo[iWeaponNum][CLASSNAME], GetNativeCell(3));
			return true;
		}
	}
	
	return false;
}

public int Native_GetWeaponDisplayNameByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			SetNativeString(2, g_chWeaponInfo[iWeaponNum][DISPLAYNAME], GetNativeCell(3));
			return true;
		}
	}
	
	return false;
}

public int Native_GetSkinDisplayNameByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopSkins(iSkinNum) {
		if (StringToInt(g_chPaintInfo[iSkinNum][DEFINDEX]) == iDefIndex) {
			SetNativeString(2, g_chPaintInfo[iSkinNum][DISPLAYNAME], GetNativeCell(3));
			return true;
		}
	}
	
	return false;
}

public int Native_GetMusicKitDisplayNameByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopMusicKits(iMusicKitNum) {
		if (StringToInt(g_chMusicKitInfo[iMusicKitNum][DEFINDEX]) == iDefIndex) {
			SetNativeString(2, g_chMusicKitInfo[iMusicKitNum][DISPLAYNAME], GetNativeCell(3));
			return true;
		}
	}
	
	return false;
}

public int Native_GetWeaponDisplayNameByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			SetNativeString(2, g_chWeaponInfo[iWeaponNum][DISPLAYNAME], GetNativeCell(3));
			return false;
		}
	}
	
	return false;
}

public int Native_GetWeaponDisplayNameByWeaponNum(Handle hPlugin, int iNumParams)
{
	SetNativeString(2, g_chWeaponInfo[GetNativeCell(1)][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_GetSkinDisplayNameBySkinNum(Handle hPlugin, int iNumParams)
{
	SetNativeString(2, g_chPaintInfo[GetNativeCell(1)][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_GetMusicKitDisplayNameByMusicKitNum(Handle hPlugin, int iNumParams)
{
	SetNativeString(2, g_chMusicKitInfo[GetNativeCell(1)][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_IsDefIndexKnife(Handle hPlugin, int iNumParams) {
	int iDefIndex = GetNativeCell(1);
	
	if(iDefIndex <= -1 || iDefIndex > 600) {
		return false;
	}
	
	return g_bIsDefIndexKnife[iDefIndex];
}

public int Native_GetActiveClassName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iWeaponDefIndex = CSGOItems_GetActiveWeaponDefIndex(iClient);
	
	char chWeaponClassName[48];
	CSGOItems_GetWeaponClassNameByDefIndex(iWeaponDefIndex, chWeaponClassName, 48);
	SetNativeString(2, chWeaponClassName, GetNativeCell(3));
	
	return true;
}

public int Native_GetActiveWeaponDefIndex(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	if (!IsPlayerAlive(iClient)) {
		return -1;
	}
	
	int iActiveWeapon = CSGOItems_GetActiveWeapon(iClient);
	
	return CSGOItems_GetWeaponDefIndexByWeapon(iActiveWeapon);
}

public int Native_GetActiveWeaponNum(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iActiveWeaponDefIndex = CSGOItems_GetActiveWeaponDefIndex(iClient);
	
	return CSGOItems_GetWeaponNumByDefIndex(iActiveWeaponDefIndex);
}

public int Native_GetActiveWeapon(Handle hPlugin, int iNumParams) {
	return GetEntPropEnt(GetNativeCell(1), Prop_Send, "m_hActiveWeapon");
}

public int Native_GetWeaponDefIndexByWeapon(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return -1;
	}
	
	return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
}

public int Native_IsSkinnableDefIndex(Handle hPlugin, int iNumParams) {
	return g_bIsDefIndexSkinnable[GetNativeCell(1)];
}

public int Native_FindWeaponByClassName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	char chClassName[48]; GetNativeString(2, chClassName, sizeof(chClassName));
	char chBuffer[48];
	
	CSGOItems_LoopWeaponSlots(iSlot) {
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		
		if (!CSGOItems_IsValidWeapon(iWeapon)) {
			continue;
		}
		
		CSGOItems_GetWeaponClassNameByWeapon(iWeapon, chBuffer, 48);
		
		if (StrEqual(chBuffer, chClassName, false)) {
			return iWeapon;
		}
	}
	
	return -1;
}

public int Native_GetWeaponSlotByWeaponNum(Handle hPlugin, int iNumParams) {
	return SlotNameToNum(g_chWeaponInfo[GetNativeCell(1)][SLOT]);
}

public int Native_GetWeaponSlotByDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]) == iDefIndex) {
			return SlotNameToNum(g_chWeaponInfo[iWeaponNum][SLOT]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponSlotByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return SlotNameToNum(g_chWeaponInfo[iWeaponNum][SLOT]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponClassNameByWeapon(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return false;
	}
	
	int iWeaponDefIndex = CSGOItems_GetWeaponDefIndexByWeapon(iWeapon);
	char chWeaponClassName[48]; CSGOItems_GetWeaponClassNameByDefIndex(iWeaponDefIndex, chWeaponClassName, 48);
	
	SetNativeString(2, chWeaponClassName, GetNativeCell(3));
	return true;
}

public int Native_IsValidWeapon(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	if (!IsValidEdict(iWeapon) || !IsValidEntity(iWeapon) || iWeapon == -1) {
		return false;
	}
	
	char chWeapon[48]; GetEdictClassname(iWeapon, chWeapon, sizeof(chWeapon));
	
	return IsValidWeaponClassName(chWeapon);
}

public int Native_GiveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	char chClassName[48]; GetNativeString(2, chClassName, sizeof(chClassName));
	
	int iReserveAmmo = GetNativeCell(3);
	int iClipAmmo = GetNativeCell(4);
	int iSwitchTo = GetNativeCell(5);
	
	if(g_bGivingWeapon[iClient]) {
		return -1;
	}
	
	if (g_bClientEquipping[iClient]) {
		g_bGivingWeapon[iClient] = false;
		return -1;
	}
	
	g_bGivingWeapon[iClient] = true;
	
	int iClientTeam = GetClientTeam(iClient);
	
	if (iClientTeam < 2 || !IsPlayerAlive(iClient)) {
		g_bGivingWeapon[iClient] = false;
		return -1;
	}
	
	int iViewSequence = GetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence");
	
	if (!IsValidWeaponClassName(chClassName)) {
		g_bGivingWeapon[iClient] = false;
		return -1;
	}
	
	int iWeaponTeam = CSGOItems_GetWeaponTeamByClassName(chClassName);
	int iWeaponNum = CSGOItems_GetWeaponNumByClassName(chClassName);
	int iWeaponDefIndex = -1;
	int iLookingAtWeapon = GetEntProp(iClient, Prop_Send, "m_bIsLookingAtWeapon");
	int iHoldingLookAtWeapon = GetEntProp(iClient, Prop_Send, "m_bIsHoldingLookAtWeapon");
	int iReloadVisuallyComplete = -1;
	int iWeaponSilencer = -1;
	int iWeaponMode = -1;
	int iRecoilIndex = -1;
	int iIronSightMode = -1;
	int iZoomLevel = -1;
	int iCurrentWeapon = GetPlayerWeaponSlot(iClient, CSGOItems_GetWeaponSlotByClassName(chClassName));
	
	float fNextPlayerAttackTime = GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack");
	float fDoneSwitchingSilencer = 0.0;
	float fNextPrimaryAttack = 0.0;
	float fNextSecondaryAttack = 0.0;
	float fTimeWeaponIdle = 0.0;
	float fAccuracyPenalty = 0.0;
	float fLastShotTime = 0.0;
	
	char chCurrentClassName[48];
	
	if (CSGOItems_IsValidWeapon(iCurrentWeapon)) {
		if (g_bWeaponEquipping[iCurrentWeapon]) {
			g_bGivingWeapon[iClient] = false;
			return -1;
		}
		
		CSGOItems_GetWeaponClassNameByWeapon(iCurrentWeapon, chCurrentClassName, 48);
		iWeaponDefIndex = CSGOItems_GetWeaponDefIndexByWeapon(iCurrentWeapon);
		
		fNextPrimaryAttack = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextPrimaryAttack");
		fNextSecondaryAttack = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flNextSecondaryAttack");
		fTimeWeaponIdle = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flTimeWeaponIdle");
		fAccuracyPenalty = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_fAccuracyPenalty");
		
		if (!CSGOItems_IsDefIndexKnife(iWeaponDefIndex)) {
			iReloadVisuallyComplete = GetEntProp(iCurrentWeapon, Prop_Send, "m_bReloadVisuallyComplete");
			iWeaponSilencer = GetEntProp(iCurrentWeapon, Prop_Send, "m_bSilencerOn");
			iWeaponMode = GetEntProp(iCurrentWeapon, Prop_Send, "m_weaponMode");
			iRecoilIndex = GetEntProp(iCurrentWeapon, Prop_Send, "m_iRecoilIndex");
			iIronSightMode = GetEntProp(iCurrentWeapon, Prop_Send, "m_iIronSightMode");
			fDoneSwitchingSilencer = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flDoneSwitchingSilencer");
			fLastShotTime = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_fLastShotTime");
			
			if (StrEqual(g_chWeaponInfo[CSGOItems_GetWeaponNumByClassName(chCurrentClassName)][TYPE], "sniper_rifle", false)) {
				iZoomLevel = GetEntProp(iCurrentWeapon, Prop_Send, "m_zoomLevel");
			}
			
			if (!CSGOItems_RemoveWeapon(iClient, iCurrentWeapon)) {
				g_bGivingWeapon[iClient] = false;
				return -1;
			}
		} else if (!CSGOItems_RemoveKnife(iClient)) {
			g_bGivingWeapon[iClient] = false;
			return -1;
		}
	}
	
	if (iClientTeam != iWeaponTeam && iWeaponTeam > 1) {
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", iWeaponTeam);
	}
	
	if (iSwitchTo == -1 && GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY) == -1 && CSGOItems_GetWeaponSlotByClassName(chClassName) == CS_SLOT_PRIMARY) {
		iSwitchTo = CS_SLOT_PRIMARY;
	}
	
	int iWeapon = GivePlayerItem(iClient, chClassName);
	
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		g_bGivingWeapon[iClient] = false;
		
		if(iWeapon != -1 && IsValidEdict(iWeapon) && IsValidEntity(iWeapon)) {
			CSGOItems_RemoveWeapon(iClient, iWeapon);
		}
		
		return -1;
	}
	
	bool bDefIndexKnife = CSGOItems_IsDefIndexKnife(CSGOItems_GetWeaponDefIndexByWeapon(iWeapon));
	bool bSniper = StrEqual(g_chWeaponInfo[iWeaponNum][TYPE], "sniper_rifle", false);
	
	if (bDefIndexKnife) {
		EquipPlayerWeapon(iClient, iWeapon);
	} else {
		CSGOItems_SetWeaponAmmo(iWeapon, iReserveAmmo, iClipAmmo);
	}
	
	int iSwitchWeapon = GetPlayerWeaponSlot(iClient, iSwitchTo); CSGOItems_SetActiveWeapon(iClient, iSwitchWeapon);
	
	if (iWeaponTeam > 1 && GetClientTeam(iClient) != iClientTeam) {
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", iClientTeam);
	}
	
	int iActiveWeapon = CSGOItems_GetActiveWeapon(iClient);
	
	if (StrEqual(chClassName, chCurrentClassName, false) && iActiveWeapon == iWeapon && iSwitchWeapon == iWeapon) {
		if (iLookingAtWeapon > -1) {
			SetEntProp(iClient, Prop_Send, "m_bIsLookingAtWeapon", iLookingAtWeapon);
		}
		
		if (iHoldingLookAtWeapon > -1) {
			SetEntProp(iClient, Prop_Send, "m_bIsHoldingLookAtWeapon", iHoldingLookAtWeapon);
		}
		
		if (fNextPlayerAttackTime > 0.0) {
			SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", fNextPlayerAttackTime);
		}
		
		if (fNextPrimaryAttack > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fNextPrimaryAttack);
		}
		
		if (fNextSecondaryAttack > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", fNextSecondaryAttack);
		}
		
		if (fTimeWeaponIdle > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_flTimeWeaponIdle", fTimeWeaponIdle);
		}
		
		if (fAccuracyPenalty > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_fAccuracyPenalty", fAccuracyPenalty);
		}
		
		if (fDoneSwitchingSilencer > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_flDoneSwitchingSilencer", fDoneSwitchingSilencer);
		}
		
		if (fLastShotTime > 0.0) {
			SetEntPropFloat(iWeapon, Prop_Send, "m_fLastShotTime", fLastShotTime);
		}
		
		if (iReloadVisuallyComplete > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_bReloadVisuallyComplete", iReloadVisuallyComplete);
		}
		
		if (iWeaponSilencer > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_bSilencerOn", iWeaponSilencer);
		}
		
		if (iWeaponMode > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_weaponMode", iWeaponMode);
		}
		
		if (iRecoilIndex > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_iRecoilIndex", iRecoilIndex);
		}
		
		if (iIronSightMode > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_iIronSightMode", iIronSightMode);
		}
		
		if (iZoomLevel > -1 && bSniper) {
			SetEntProp(iWeapon, Prop_Send, "m_zoomLevel", iZoomLevel);
		}
	}
	
	else if (iActiveWeapon == iWeapon && iSwitchWeapon == iWeapon) {
		if (bDefIndexKnife) {
			iViewSequence = 2;
		} else {
			iViewSequence = 0;
		}
		
		int iViewSequences = sizeof(g_chViewSequence1);
		
		for (int i = 0; i < iViewSequences; i++) {
			if (!StrEqual(chClassName, g_chViewSequence1[i], false)) {
				continue;
			}
			
			iViewSequence = 1;
			break;
		}
	}
	
	if (iActiveWeapon == iWeapon) {
		SetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence", iViewSequence);
	}
	
	g_bGivingWeapon[iClient] = false;
	
	return iWeapon;
}

public int Native_RemoveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iWeapon = GetNativeCell(2);
	
	if (!CSGOItems_IsValidWeapon(iWeapon) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	if (g_bClientEquipping[iClient] || g_bWeaponEquipping[iWeapon]) {
		return false;
	}
	
	int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	
	if (iOwnerEntity != iClient) {
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);
	}
	
	SDKHooks_DropWeapon(iClient, iWeapon, NULL_VECTOR, NULL_VECTOR);
	
	if (iOwnerEntity != -1) {
		SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iOwnerEntity);
	}
	
	return AcceptEntityInput(iWeapon, "Kill");
}

public int Native_SetActiveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iWeapon = GetNativeCell(2);
	
	if (!CSGOItems_IsValidWeapon(iWeapon) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	SDKCall(g_hSwitchWeaponCall, iClient, iWeapon, 0);
	SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	
	return true;
}

public int Native_AreItemsSynced(Handle hPlugin, int iNumParams) {
	return g_bItemsSynced;
}

public int Native_AreItemsSyncing(Handle hPlugin, int iNumParams) {
	return g_bItemsSyncing;
}

public int Native_Resync(Handle hPlugin, int iNumParams) {
	return RetrieveLanguage();
}

public int Native_GetActiveWeaponSlot(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	if (!IsPlayerAlive(iClient)) {
		return -1;
	}
	
	CSGOItems_LoopWeaponSlots(iSlot) {
		if (GetPlayerWeaponSlot(iClient, iSlot) == CSGOItems_GetActiveWeapon(iClient)) {
			return iSlot;
		}
	}
	
	return -1;
}

public int Native_RemoveKnife(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	CSGOItems_LoopValidWeapons(iWeapon) {
		if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != iClient) {
			continue;
		}
		
		int iDefIndex = CSGOItems_GetWeaponDefIndexByWeapon(iWeapon);
		
		if (!CSGOItems_IsDefIndexKnife(iDefIndex)) {
			continue;
		}
		
		return CSGOItems_RemoveWeapon(iClient, iWeapon);
	}
	
	return false;
}

public int Native_GetActiveWeaponCount(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	int iTeam = GetNativeCell(2);
	int iCount = 0;
	int iWeaponSlot = CSGOItems_GetWeaponSlotByClassName(chClassName);
	
	if (iWeaponSlot <= -1) {
		return 0;
	}
	
	CSGOItems_LoopValidClients(iClient) {
		if (iTeam > 1 && iTeam < 4 && GetClientTeam(iClient) != iTeam) {
			continue;
		}
		
		if (CSGOItems_FindWeaponByClassName(iClient, chClassName) == -1) {
			continue;
		}
		
		iCount++;
	}
	
	return iCount;
}

public int Native_SetAllWeaponsAmmo(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; char chBuffer[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	int iReserveAmmo = GetNativeCell(2);
	int iClipAmmo = GetNativeCell(3);
	
	CSGOItems_LoopValidWeapons(iWeapon) {
		CSGOItems_GetWeaponClassNameByWeapon(iWeapon, chBuffer, 48);
		
		if (!StrEqual(chClassName, chBuffer, false)) {
			continue;
		}
		
		CSGOItems_SetWeaponAmmo(iWeapon, iReserveAmmo, iClipAmmo);
	}
}

public int Native_GetRandomSkin(Handle hPlugin, int iNumParams)
{
	int iSkinNum = GetRandomInt(1, g_iPaintCount);
	return StringToInt(g_chPaintInfo[iSkinNum][DEFINDEX]);
} 