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

****************************************************************************************************
INCLUDES
***************************************************************************************************
*/
#include <sourcemod>
#include <sdktools>
#include <cstrike> 
#include <csgoitems> 
#include <system2> 

/****************************************************************************************************
DEFINES
*****************************************************************************************************/
#define VERSION "0.5"

#define 	DEFINDEX 		0
#define 	CLASSNAME 		1
#define 	DISPLAYNAME 	2
#define 	SLOT 			3
#define 	TEAM 			4
#define 	CLIPAMMO 		5
#define 	TYPE 			6
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
/****************************************************************************************************
STRINGS.
*****************************************************************************************************/
char g_chWeaponInfo[100][8][48];
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

#define CSGOItems_LoopWeapons(%1) for(int %1 = 0; %1 <= g_iWeaponCount; %1++)
#define CSGOItems_LoopSkins(%1) for(int %1 = 0; %1 <= g_iPaintCount; %1++)
#define CSGOItems_LoopMusicKits(%1) for(int %1 = 0; %1 <= g_iMusicKitCount; %1++)
#define CSGOItems_LoopWeaponSlots(%1) for(int %1; %1 <= 6; %1++)

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
	
	DownloadLanguageFile(true);
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
	CreateNative("CSGOItems_SetWeaponAmmo", Native_SetWeaponAmmo);
	CreateNative("CSGOItems_RefillClipAmmo", Native_RefillClipAmmo);
	
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

public Action SteamWorks_RestartRequested() {
	DownloadLanguageFile(false);
}

public int DownloadLanguageFile(bool bStorePhrases) {
	if (g_bItemsSyncing) {
		return false;
	}
	
	if (!FileExists("resource/csgo_english_utf8.txt")) {
		System2_DownloadFile(OnLanguageDownload, LANGURL, "resource/csgo_english_utf8.txt", bStorePhrases);
	} else {
		System2_DownloadFile(OnLanguageDownload, LANGURL, "resource/csgo_english_utf8_new.txt", bStorePhrases);
	}
	
	g_iDownloadAttempts++;
	
	return true;
}

public int OnLanguageDownload(bool bFinished, const char[] chError, float fTotal, float fNow, float fUtotal, float fUnow, bool bStorePhrases)
{
	bool bFileExists = FileExists("resource/csgo_english_utf8.txt");
	bool bFileExists2 = FileExists("resource/csgo_english_utf8_new.txt");
	
	if (bFinished) {
		if (bStorePhrases) {
			StoreLanguagePhrases();
		}
	}
	
	else if (!StrEqual(chError, "")) {
		if (g_iDownloadAttempts < 10) {
			DownloadLanguageFile(bStorePhrases);
		}
		
		else if (bFileExists || bFileExists2) {
			if (bStorePhrases) {
				StoreLanguagePhrases();
			}
			
			LogError("UTF-8 language download failed after %d attempts, attempting to use old file. \nCheck: %s", g_iDownloadAttempts, LANGURL);
		}
		
		else if (!bFileExists && !bFileExists2) {
			Call_StartForward(g_hOnPluginEnd);
			Call_Finish();
			SetFailState("Could not download the UTF-8 language and no old file was found, maybe github is down? \nCheck: %s", LANGURL);
		}
	}
}

public void StoreLanguagePhrases()
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
		DeleteFile("resource/csgo_english_utf8.txt"); DeleteFile("resource/csgo_english_utf8_new.txt");
		
		if (hLanguageFile != null) {
			CloseHandle(hLanguageFile);
		}
		
		if (hLanguageFileNew != null) {
			CloseHandle(hLanguageFileNew);
		}
		
		if (g_iDownloadAttempts < 10) {
			DownloadLanguageFile(true);
			return;
		} else {
			Call_StartForward(g_hOnPluginEnd);
			Call_Finish();
			SetFailState("UTF-8 language file is corrupted, failed after %d attempts. \nCheck: %s", g_iDownloadAttempts, LANGURL);
		}
	}
	
	if (hLanguageFile != null) {
		CloseHandle(hLanguageFile);
	}
	
	if (hLanguageFileNew != null) {
		CloseHandle(hLanguageFileNew);
	}
	
	g_iDownloadAttempts = 0;
	LogMessage("UTF-8 language file successfully processed, starting item data synchronization.");
	
	SyncItemData();
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
			g_iWeaponCount++;
			
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
			
			if (IsSpecialPrefab(chBuffer)) {
				KvGetString(g_hItemsKv, "item_name", chBuffer, 48);
			} else {
				KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
				
				KvJumpToKey(g_hItemsKv, "prefabs");
				KvGetString(g_hItemsKv, "prefab", g_chWeaponInfo[g_iWeaponCount][TYPE], 48);
				KvJumpToKey(g_hItemsKv, chBuffer);
				KvGetString(g_hItemsKv, "item_name", chBuffer, 48);
				KvJumpToKey(g_hItemsKv, "used_by_classes");
				
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
				
				KvJumpToKey(g_hItemsKv, "attributes");
				IntToString(KvGetNum(g_hItemsKv, "primary reserve ammo max"), g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], 48);
				
				KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
				
				KvJumpToKey(g_hItemsKv, "items");
				KvJumpToKey(g_hItemsKv, g_chWeaponInfo[g_iWeaponCount][DEFINDEX]);
			}
			
			GetItemName(chBuffer, g_chWeaponInfo[g_iWeaponCount][DISPLAYNAME], 48);
			KvGetString(g_hItemsKv, "item_sub_position", chBuffer, 48);
			
			if (StrContains(chBuffer, "grenade") == -1 && StrContains(chBuffer, "equipment") == -1 && !StrEqual(chBuffer, "", false) && StrContains(chBuffer, "melee") == -1) {
				g_bIsDefIndexSkinnable[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
			}
			
			if (!StrEqual(chBuffer, "", false)) {
				strcopy(g_chWeaponInfo[g_iWeaponCount][SLOT], 48, chBuffer);
			}
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
		g_iPaintCount++;
		KvGetSectionName(g_hItemsKv, chBuffer, 48);
		int iSkinDefIndex = StringToInt(chBuffer);
		
		if (iSkinDefIndex != 0 && iSkinDefIndex != 9001) {
			strcopy(g_chPaintInfo[g_iPaintCount][DEFINDEX], 48, chBuffer);
			KvGetString(g_hItemsKv, "description_tag", chBuffer, 48);
			GetItemName(chBuffer, g_chPaintInfo[g_iPaintCount][DISPLAYNAME], 48);
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
	
	LogMessage("Items successfully processed.");
	g_bItemsSynced = true;
	g_bItemsSyncing = false;
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

stock bool IsValidWeaponClassName(char[] chClassName)
{
	return StrContains(chClassName, "weapon_") != -1 && StrContains(chClassName, "base") == -1 && StrContains(chClassName, "case") == -1;
}

stock bool IsSpecialPrefab(char[] chPrefabName)
{
	return StrContains(chPrefabName, "_prefab") == -1;
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

public int Native_GetWeaponCount(Handle hPlugin, int iNumParams)
{
	return g_iWeaponCount;
}

public int Native_GetSkinCount(Handle hPlugin, int iNumParams)
{
	return g_iPaintCount;
}

public int Native_GetMusicKitCount(Handle hPlugin, int iNumParams)
{
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
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return -1;
	}
	
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
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return -1;
	}
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]);
		}
	}
	
	return -1;
}

public int Native_GetWeaponClipAmmoByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	return StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]);
}

public int Native_SetWeaponAmmo(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	int iReserveAmmo = GetNativeCell(2);
	int iClipAmmo = GetNativeCell(3);
	
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
			CSGOItems_SetWeaponAmmo(iWeapon, -1, StringToInt(g_chWeaponInfo[iWeaponNum][CLIPAMMO]));
			return true;
		}
	}
	
	return false;
}

public int Native_GetWeaponNumByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return -1;
	}
	
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

public int Native_GetWeaponDefIndexByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	return StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]);
}

public int Native_GetWeaponDefIndexByClassName(Handle hPlugin, int iNumParams)
{
	char chClassName[48]; GetNativeString(1, chClassName, sizeof(chClassName));
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return -1;
	}
	
	CSGOItems_LoopWeapons(iWeaponNum) {
		if (StrEqual(g_chWeaponInfo[iWeaponNum][CLASSNAME], chClassName, false)) {
			return StringToInt(g_chWeaponInfo[iWeaponNum][DEFINDEX]);
		}
	}
	
	return -1;
}

public int Native_GetSkinDefIndexBySkinNum(Handle hPlugin, int iNumParams)
{
	int iSkinNum = GetNativeCell(1);
	
	return StringToInt(g_chPaintInfo[iSkinNum][DEFINDEX]);
}

public int Native_GetMusicKitDefIndexByMusicKitNum(Handle hPlugin, int iNumParams)
{
	int iMusicNum = GetNativeCell(1);
	
	return StringToInt(g_chMusicKitInfo[iMusicNum][DEFINDEX]);
}

public int Native_GetWeaponClassNameByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	SetNativeString(2, g_chWeaponInfo[iWeaponNum][CLASSNAME], GetNativeCell(3));
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
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return false;
	}
	
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
	int iWeaponNum = GetNativeCell(1);
	
	SetNativeString(2, g_chWeaponInfo[iWeaponNum][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_GetSkinDisplayNameBySkinNum(Handle hPlugin, int iNumParams)
{
	int iSkinNum = GetNativeCell(1);
	
	SetNativeString(2, g_chPaintInfo[iSkinNum][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_GetMusicKitDisplayNameByMusicKitNum(Handle hPlugin, int iNumParams)
{
	int iMusicKitNum = GetNativeCell(1);
	
	SetNativeString(2, g_chMusicKitInfo[iMusicKitNum][DISPLAYNAME], GetNativeCell(3));
	return true;
}

public int Native_IsDefIndexKnife(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
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

public int Native_GetActiveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

public int Native_GetWeaponDefIndexByWeapon(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	if (!CSGOItems_IsValidWeapon(iWeapon)) {
		return -1;
	}
	
	return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
}

public int Native_IsSkinnableDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	return g_bIsDefIndexSkinnable[iDefIndex];
}

public int Native_FindWeaponByClassName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	char chClassName[48]; GetNativeString(2, chClassName, sizeof(chClassName));
	char chBuffer[48];
	
	CSGOItems_LoopWeaponSlots(iSlot) {
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		
		if (CSGOItems_IsValidWeapon(iWeapon)) {
			continue;
		}
		
		CSGOItems_GetWeaponClassNameByWeapon(iWeapon, chBuffer, 48);
		
		if (StrEqual(chBuffer, chClassName, false)) {
			return iWeapon;
		}
	}
	
	return -1;
}

public int Native_GetWeaponSlotByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	return SlotNameToNum(g_chWeaponInfo[iWeaponNum][SLOT]);
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
	
	if (!IsValidWeaponClassName(chClassName)) {
		ThrowNativeError(SP_ERROR_ARRAY_BOUNDS, "Weapon ClassName %s is invalid.", chClassName);
		return -1;
	}
	
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
	
	int iClientTeam = GetClientTeam(iClient);
	
	if (iClientTeam < 2 || !IsPlayerAlive(iClient)) {
		return -1;
	}
	
	int iViewSequence = GetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence");
	
	if (!IsValidWeaponClassName(chClassName)) {
		return -1;
	}
	
	int iWeaponTeam = CSGOItems_GetWeaponTeamByClassName(chClassName);
	int iWeaponNum = CSGOItems_GetWeaponNumByClassName(chClassName);
	int iSwitchTo = GetNativeCell(5);
	int iWeaponDefIndex = -1;
	
	int iLookingAtWeapon = GetEntProp(iClient, Prop_Send, "m_bIsLookingAtWeapon");
	int iHoldingLookAtWeapon = GetEntProp(iClient, Prop_Send, "m_bIsHoldingLookAtWeapon");
	
	float fNextPlayerAttackTime = GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack");
	
	int iReloadVisuallyComplete = -1;
	int iReloadState = -1;
	int iWeaponSilencer = -1;
	int iWeaponMode = -1;
	int iRecoilIndex = -1;
	int iIronSightMode = -1;
	int iZoomLevel = -1;
	int iBurstShotsRemaining = -1;
	
	float fDoneSwitchingSilencer = 0.0;
	float fNextPrimaryAttack = 0.0;
	float fNextSecondaryAttack = 0.0;
	float fTimeWeaponIdle = 0.0;
	float fAccuracyPenalty = 0.0;
	float fLastShotTime = 0.0;
	
	int iCurrentWeapon = GetPlayerWeaponSlot(iClient, CSGOItems_GetWeaponSlotByClassName(chClassName));
	char chCurrentClassName[48];
	
	if (CSGOItems_IsValidWeapon(iCurrentWeapon)) {
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
			iZoomLevel = GetEntProp(iCurrentWeapon, Prop_Send, "m_zoomLevel");
			iBurstShotsRemaining = GetEntProp(iCurrentWeapon, Prop_Send, "m_iBurstShotsRemaining");
			
			fDoneSwitchingSilencer = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_flDoneSwitchingSilencer");
			fLastShotTime = GetEntPropFloat(iCurrentWeapon, Prop_Send, "m_fLastShotTime");
			
			if (StrEqual(g_chWeaponInfo[CSGOItems_GetWeaponNumByClassName(chCurrentClassName)][TYPE], "Shotgun")) {
				iReloadState = GetEntProp(iCurrentWeapon, Prop_Send, "m_reloadState");
			}
		}
		
		if (!CSGOItems_RemoveWeapon(iClient, iCurrentWeapon)) {
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
	
	bool bDefIndexKnife = CSGOItems_IsDefIndexKnife(CSGOItems_GetWeaponDefIndexByWeapon(iWeapon));
	bool bShotGun = StrEqual(g_chWeaponInfo[iWeaponNum][TYPE], "Shotgun");
	
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
		
		if (iReloadState > -1) {
			SetEntProp(iClient, Prop_Send, "m_reloadState", iReloadState);
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
		
		if (iZoomLevel > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_zoomLevel", iZoomLevel);
		}
		
		if (bShotGun && iBurstShotsRemaining > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_iBurstShotsRemaining", iBurstShotsRemaining);
		}
		
		if (bShotGun && iReloadState > -1) {
			SetEntProp(iWeapon, Prop_Send, "m_reloadState", iReloadState);
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
	
	return iWeapon;
}

public int Native_RemoveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iWeapon = GetNativeCell(2);
	
	if (!CSGOItems_IsValidWeapon(iWeapon) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	if (!RemovePlayerItem(iClient, iWeapon)) {
		return false;
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

public int Native_AreItemsSynced(Handle hPlugin, int iNumParams)
{
	return g_bItemsSynced;
}

public int Native_AreItemsSyncing(Handle hPlugin, int iNumParams)
{
	return g_bItemsSyncing;
}

public int Native_Resync(Handle hPlugin, int iNumParams)
{
	return DownloadLanguageFile(true);
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