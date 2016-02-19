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

****************************************************************************************************
INCLUDES
***************************************************************************************************
*/
#include <sourcemod>
#include <sdktools>
#include <cstrike> 
#include <csgoitems> 

/****************************************************************************************************
DEFINES
*****************************************************************************************************/
#define VERSION "0.4"

#define 	DEFINDEX 		0
#define 	CLASSNAME 		1
#define 	DISPLAYNAME 	2
#define 	SLOT 			3
#define 	TEAM 			4
#define 	CLIPAMMO 		5

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
Handle g_hLanguageFile = null;
Handle g_hItemsKv = null;
//Handle g_hOnWeaponSynced = null;
//Handle g_hOnSkinSynced = null;
//Handle g_hOnMusicKitSynced = null;

/****************************************************************************************************
BOOLS.
*****************************************************************************************************/
bool g_bIsDefIndexKnife[600];
bool g_bIsDefIndexSkinnable[600];
/****************************************************************************************************
STRINGS.
*****************************************************************************************************/
char g_chWeaponInfo[100][7][128];
char g_chPaintInfo[600][3][128];
char g_chMusicKitInfo[100][3][128];
char g_chLangPhrases[2198296];

/****************************************************************************************************
INTS.
*****************************************************************************************************/
static int g_iPaintCount;
static int g_iWeaponCount;
static int g_iMusicKitCount;

#define CSGOItems_LoopWeapons(%1) for(int %1 = 0; %1 <= g_iWeaponCount; %1++)
#define CSGOItems_LoopSkins(%1) for(int %1 = 0; %1 <= g_iPaintCount; %1++)
#define CSGOItems_LoopMusicKits(%1) for(int %1 = 0; %1 <= g_iMusicKitCount; %1++)

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO) {
		SetFailState("This plugin is for CSGO only.");
	}
	
	/****************************************************************************************************
											--FORWARDS--
	*****************************************************************************************************/
	// Yeah, Ill work on these in a bit..
	//g_hOnWeaponSynced = CreateGlobalForward("CSGOItems_OnWeaponSynced", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String);
	//g_hOnSkinSynced = CreateGlobalForward("CSGOItems_OnSkinSynced", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	//g_hOnMusicKitSynced = CreateGlobalForward("CSGOItems_OnMusicKitSynced", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	
	ReadItemsFile(); ReadLanguageFile(); SyncItemData();
}

public APLRes AskPluginLoad2(Handle hNyself, bool bLate, char[] chError, int iErrMax)
{
	/****************************************************************************************************
											--GENERAL NATIVES--
	*****************************************************************************************************/
	// Item Counts
	CreateNative("CSGOItems_GetWeaponCount", Native_GetWeaponCount);
	CreateNative("CSGOItems_GetSkinCount", Native_GetSkinCount);
	CreateNative("CSGOItems_GetMusicKitCount", Native_GetMusicKitCount);
	
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
	
	// Weapon Display Names
	CreateNative("CSGOItems_GetWeaponDisplayNameByDefIndex", Native_GetWeaponDisplayNameByDefIndex);
	CreateNative("CSGOItems_GetWeaponDisplayNameByClassName", Native_GetWeaponDisplayNameByClassName);
	CreateNative("CSGOItems_GetWeaponDisplayNameByWeaponNum", Native_GetWeaponDisplayNameByWeaponNum);
	
	// Weapon Teams
	CreateNative("CSGOItems_GetWeaponTeamByDefIndex", Native_GetWeaponTeamByDefIndex);
	CreateNative("CSGOItems_GetWeaponTeamByClassName", Native_GetWeaponTeamByClassName);
	CreateNative("CSGOItems_GetWeaponTeamByWeaponNum", Native_GetWeaponTeamByWeaponNum);
	
	// Weapon Ammo
	CreateNative("CSGOItems_GetWeaponClipAmmoByDefIndex", Native_GetWeaponClipAmmoByDefIndex);
	CreateNative("CSGOItems_GetWeaponClipAmmoByClassName", Native_GetWeaponClipAmmoByClassName);
	CreateNative("CSGOItems_GetWeaponClipAmmoByWeaponNum", Native_GetWeaponClipAmmoByWeaponNum);
	CreateNative("CSGOItems_RefillClipAmmo", Native_RefillClipAmmo);
	CreateNative("CSGOItems_SetWeaponAmmo", Native_SetWeaponAmmo);
	
	// Misc
	CreateNative("CSGOItems_IsDefIndexKnife", Native_IsDefIndexKnife);
	CreateNative("CSGOItems_GetWeaponDefIndexByWeaponIndex", Native_GetWeaponDefIndexByWeaponIndex);
	CreateNative("CSGOItems_GetWeaponSlotByWeaponNum", Native_GetWeaponSlotByWeaponNum);
	
	CreateNative("CSGOItems_GetActiveClassName", Native_GetActiveClassName);
	CreateNative("CSGOItems_GetClassNameByWeaponIndex", Native_GetClassNameByWeaponIndex);
	CreateNative("CSGOItems_GetActiveWeaponDefIndex", Native_GetActiveWeaponDefIndex);
	CreateNative("CSGOItems_GetActiveWeaponNum", Native_GetActiveWeaponNum);
	CreateNative("CSGOItems_GetActiveWeaponIndex", Native_GetActiveWeaponIndex);
	CreateNative("CSGOItems_FindWeaponIndexByClassName", Native_FindWeaponIndexByClassName);
	CreateNative("CSGOItems_IsValidWeapon", Native_IsValidWeapon);
	CreateNative("CSGOItems_GiveWeapon", Native_GiveWeapon);
	CreateNative("CSGOItems_RemoveWeapon", Native_RemoveWeapon);
	
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

public void ReadItemsFile()
{
	g_hItemsKv = CreateKeyValues("items_game");
	
	if (!FileToKeyValues(g_hItemsKv, "scripts/items/items_game.txt")) {
		SetFailState("Unable to Read/Open items_game.txt");
	}
}

public void ReadLanguageFile()
{
	g_hLanguageFile = OpenFile("resource/csgo_english1.txt", "r");
	
	if (g_hLanguageFile == null) {
		SetFailState("Unable to Read/Open the Language file.");
	}
	
	ReadFileString(g_hLanguageFile, g_chLangPhrases, 2198296); CloseHandle(g_hLanguageFile);
}

public void SyncItemData()
{
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "items") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		SetFailState("Unable to find Item keyvalues");
	}
	
	char chBuffer[128]; char chBuffer2[128];
	
	do {
		KvGetString(g_hItemsKv, "name", chBuffer, 128);
		
		if (IsValidWeaponClassName(chBuffer)) {
			g_iWeaponCount++;
			
			KvGetSectionName(g_hItemsKv, g_chWeaponInfo[g_iWeaponCount][DEFINDEX], 128);
			
			strcopy(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], 128, chBuffer);
			
			if (StrEqual(g_chWeaponInfo[g_iWeaponCount][CLASSNAME], "weapon_c4", false)) {
				g_chWeaponInfo[g_iWeaponCount][TEAM] = "2";
			}
			
			KvGetString(g_hItemsKv, "prefab", chBuffer, 128);
			
			if (StrContains(chBuffer, "melee") != -1) {
				g_bIsDefIndexKnife[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
				
				if (StrContains(chBuffer, "unusual") != -1) {
					g_bIsDefIndexSkinnable[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
					g_chWeaponInfo[g_iWeaponCount][SLOT] = "melee";
				}
			}
			
			if (IsSpecialPrefab(chBuffer)) {
				KvGetString(g_hItemsKv, "item_name", chBuffer, 128);
			} else {
				KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
				
				KvJumpToKey(g_hItemsKv, "prefabs");
				KvJumpToKey(g_hItemsKv, chBuffer);
				KvGetString(g_hItemsKv, "item_name", chBuffer, 128);
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
				IntToString(KvGetNum(g_hItemsKv, "primary reserve ammo max"), g_chWeaponInfo[g_iWeaponCount][CLIPAMMO], 128);
				
				KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
				
				KvJumpToKey(g_hItemsKv, "items");
				KvJumpToKey(g_hItemsKv, g_chWeaponInfo[g_iWeaponCount][DEFINDEX]);
			}
			GetItemName(chBuffer, g_chWeaponInfo[g_iWeaponCount][DISPLAYNAME], 128);
			KvGetString(g_hItemsKv, "item_sub_position", chBuffer, 128);
			
			if (StrContains(chBuffer, "grenade") == -1 && StrContains(chBuffer, "equipment") == -1 && !StrEqual(chBuffer, "", false) && StrContains(chBuffer, "melee") == -1) {
				g_bIsDefIndexSkinnable[StringToInt(g_chWeaponInfo[g_iWeaponCount][DEFINDEX])] = true;
			}
			
			if (!StrEqual(chBuffer, "", false)) {
				strcopy(g_chWeaponInfo[g_iWeaponCount][SLOT], 128, chBuffer);
			}
		}
	}
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "paint_kits") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		SetFailState("Unable to find Paintkit keyvalues");
	}
	
	do {
		g_iPaintCount++;
		KvGetSectionName(g_hItemsKv, chBuffer, 128);
		int iSkinDefIndex = StringToInt(chBuffer);
		
		if (iSkinDefIndex != 0 && iSkinDefIndex != 9001) {
			strcopy(g_chPaintInfo[g_iPaintCount][DEFINDEX], 128, chBuffer);
			KvGetString(g_hItemsKv, "description_tag", chBuffer, 128);
			GetItemName(chBuffer, g_chPaintInfo[g_iPaintCount][DISPLAYNAME], 128);
		}
	}
	
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	KvRewind(g_hItemsKv);
	
	if (!KvJumpToKey(g_hItemsKv, "music_definitions") || !KvGotoFirstSubKey(g_hItemsKv, false)) {
		SetFailState("Unable to find Music Kit keyvalues");
	}
	
	do {
		KvGetSectionName(g_hItemsKv, chBuffer, 128); int iMusicDefIndex = StringToInt(chBuffer);
		if (iMusicDefIndex > 2) {
			strcopy(g_chMusicKitInfo[g_iMusicKitCount][DEFINDEX], 128, chBuffer);
			KvGetString(g_hItemsKv, "loc_name", chBuffer2, 128);
			GetItemName(chBuffer2, g_chMusicKitInfo[g_iMusicKitCount][DISPLAYNAME], 128);
			
			g_iMusicKitCount++;
		}
	}
	
	while (KvGotoNextKey(g_hItemsKv));
	KvGoBack(g_hItemsKv); KvGoBack(g_hItemsKv);
	
	CloseHandle(g_hItemsKv);
}

stock void GetItemName(char[] chPhrase, char[] chBuffer, int iLength)
{
	int iPos = StrContains(g_chLangPhrases, chPhrase[1], false);
	
	if (iPos == -1) {
		strcopy(chBuffer, iLength, chPhrase[1]);
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
	char chClassName[128]; GetNativeString(1, chClassName, sizeof(chClassName));
	
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
	char chClassName[128]; GetNativeString(1, chClassName, sizeof(chClassName));
	
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
	
	if(!CSGOItems_IsValidWeapon(iWeapon)) {
		return false;
	}
	
	if(iReserveAmmo > -1) {
		SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iReserveAmmo);
	}
	
	if(iClipAmmo > -1) {
		SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClipAmmo);
	}
	
	return true;
}

public int Native_RefillClipAmmo(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	
	int iDefIndex = CSGOItems_GetWeaponDefIndexByWeaponIndex(iWeapon);
	
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
	char chClassName[128]; GetNativeString(1, chClassName, sizeof(chClassName));
	
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
	char chClassName[128]; GetNativeString(1, chClassName, sizeof(chClassName));
	
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
	char chClassName[128]; GetNativeString(1, chClassName, sizeof(chClassName));
	
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
	
	char chWeaponClassName[128];
	CSGOItems_GetWeaponClassNameByDefIndex(iWeaponDefIndex, chWeaponClassName, 128);
	SetNativeString(2, chWeaponClassName, GetNativeCell(3));
	
	return true;
}

public int Native_GetActiveWeaponDefIndex(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	
	if (!IsPlayerAlive(iClient)) {
		return -1;
	}
	
	int iActiveWeapon = CSGOItems_GetActiveWeaponIndex(iClient);
	
	return CSGOItems_GetWeaponDefIndexByWeaponIndex(iActiveWeapon);
}

public int Native_GetActiveWeaponNum(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iActiveWeaponDefIndex = CSGOItems_GetActiveWeaponDefIndex(iClient);
	
	return CSGOItems_GetWeaponNumByDefIndex(iActiveWeaponDefIndex);
}

public int Native_GetActiveWeaponIndex(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

public int Native_GetWeaponDefIndexByWeaponIndex(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
}

public int Native_IsSkinnableDefIndex(Handle hPlugin, int iNumParams)
{
	int iDefIndex = GetNativeCell(1);
	
	return g_bIsDefIndexSkinnable[iDefIndex];
}

public int Native_FindWeaponIndexByClassName(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	char chClassName[128]; GetNativeString(2, chClassName, sizeof(chClassName));
	char chBuffer[128];
	
	for (int iSlot = 0; iSlot <= 5; iSlot++) {
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		
		if (iWeapon == -1) {
			continue;
		}
		
		CSGOItems_GetClassNameByWeaponIndex(iWeapon, chBuffer, 128);
		
		if (StrEqual(chBuffer, chClassName, false)) {
			return iWeapon;
		}
	}
	
	return -1;
}

public int Native_GetWeaponSlotByWeaponNum(Handle hPlugin, int iNumParams)
{
	int iWeaponNum = GetNativeCell(1);
	
	SetNativeString(2, g_chWeaponInfo[iWeaponNum][SLOT], GetNativeCell(3));
	return true;
}

public int Native_GetClassNameByWeaponIndex(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	int iWeaponDefIndex = CSGOItems_GetWeaponDefIndexByWeaponIndex(iWeapon);
	char chWeaponClassName[128]; CSGOItems_GetWeaponClassNameByDefIndex(iWeaponDefIndex, chWeaponClassName, 128);
	SetNativeString(2, chWeaponClassName, GetNativeCell(3));
	return true;
}

public int Native_IsValidWeapon(Handle hPlugin, int iNumParams)
{
	int iWeapon = GetNativeCell(1);
	
	if (!IsValidEdict(iWeapon) || !IsValidEntity(iWeapon) || iWeapon == -1) {
		return false;
	}
	
	char chWeapon[128]; GetEdictClassname(iWeapon, chWeapon, sizeof(chWeapon));
	
	return IsValidWeaponClassName(chWeapon);
}

public int Native_GiveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	char chClassName[128]; GetNativeString(2, chClassName, sizeof(chClassName));
	
	int iReserveAmmo = GetNativeCell(3);
	int iClipAmmo = GetNativeCell(4);
	//int iSwitchTo = GetNativeCell(5); Something for later.
	
	if (!IsValidWeaponClassName(chClassName)) {
		return -1;
	}
	
	int iWeaponTeam = CSGOItems_GetWeaponTeamByClassName(chClassName);
	int iClientTeam = GetClientTeam(iClient);
	
	if (iClientTeam < 2 || !IsPlayerAlive(iClient)) {
		return -1;
	}
	
	if (iClientTeam != iWeaponTeam && iWeaponTeam > 1) {
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", iWeaponTeam);
	}
	
	int iWeapon = GivePlayerItem(iClient, chClassName);
	int iWeaponDefIndex = CSGOItems_GetWeaponDefIndexByWeaponIndex(iWeapon);
	
	if (CSGOItems_IsDefIndexKnife(iWeaponDefIndex)) {
		EquipPlayerWeapon(iClient, iWeapon);
	} else {
		CSGOItems_SetWeaponAmmo(iWeapon, iReserveAmmo, iClipAmmo);
	}
	
	int iViewSequence = 0;
	
	/* Unfinished Stuff.
	if (StrEqual(chClassName, "weapon_m4a1_silencer", false)) {
		iViewSequence = 1;
	}
	
	else if (StrEqual(chClassName, "weapon_knife_butterfly", false)) {
		iViewSequence = 2;
	}
	*/
	
	SetEntProp(GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"), Prop_Send, "m_nSequence", iViewSequence);
	
	if (iWeaponTeam > 1 && GetClientTeam(iClient) != iClientTeam) {
		SetEntProp(iClient, Prop_Send, "m_iTeamNum", iClientTeam);
	}
	
	return iWeapon;
} 

public int Native_RemoveWeapon(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	int iWeapon = GetNativeCell(2);
	
	if(!CSGOItems_IsValidWeapon(iWeapon) || !IsPlayerAlive(iClient)) {
		return false;
	}
	
	if (RemovePlayerItem(iClient, iWeapon)) {
		AcceptEntityInput(iWeapon, "Kill");
		return true;
	}
	
	return false;
}