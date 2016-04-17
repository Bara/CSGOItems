#if defined _csgoitems_included_
#endinput
#endif
#define _csgoitems_included_

native int CSGOItems_GetWeaponCount();
native int CSGOItems_GetMusicKitCount();
native int CSGOItems_GetSkinCount();
native int CSGOItems_GetActiveWeaponCount(const char[] chClassName, int iTeam = 0);

// WEAPONS
native int CSGOItems_GetWeaponNumByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponNumByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponDefIndexByWeaponNum(int iWeaponNum);
native bool CSGOItems_GetWeaponDefIndexByClassName(const char[] chClassName);
native bool CSGOItems_GetWeaponClassNameByWeaponNum(int iWeaponNum, char[] chBuffer, int iLengh);
native bool CSGOItems_GetWeaponClassNameByDefIndex(int iDefIndex, char[] chBuffer, int iLengh);
native bool CSGOItems_GetWeaponDisplayNameByDefIndex(int iDefIndex, char[] chBuffer, int iLengh);
native bool CSGOItems_GetWeaponDisplayNameByClassName(const char[] chClassName, char[] chBuffer, int iLengh);
native bool CSGOItems_GetWeaponDisplayNameByWeaponNum(int iWeaponNum, char[] chBuffer, int iLengh);
native bool CSGOItems_IsDefIndexKnife(int iDefIndex);
native int CSGOItems_GetWeaponDefIndexByWeapon(int iWeapon);
native bool CSGOItems_GetWeaponClassNameByWeapon(int iWeapon, char[] chBuffer, int iLengh);
native int CSGOItems_GetActiveWeapon(int iClient);
native int CSGOItems_GetActiveWeaponDefIndex(int iClient);
native bool CSGOItems_GetActiveClassName(int iClient, char[] chBuffer, int iLengh);
native bool CSGOItems_IsSkinnableDefIndex(int iDefIndex);
native int CSGOItems_FindWeaponByClassName(int iClient, const char[] chClassName);
native int CSGOItems_GetActiveWeaponNum(int iClient);
native int CSGOItems_GetWeaponSlotByWeaponNum(int iWeaponNum);
native int CSGOItems_GetWeaponSlotByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponSlotByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponTeamByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponTeamByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponTeamByWeaponNum(int iWeaponNum);
native int CSGOItems_GetWeaponClipAmmoByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponClipAmmoByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponClipAmmoByWeaponNum(int iWeaponNum);
native int CSGOItems_GetWeaponReserveAmmoByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponReserveAmmoByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponReserveAmmoByWeaponNum(int iWeaponNum);
native int CSGOItems_GetWeaponKillAwardByDefIndex(int iDefIndex);
native int CSGOItems_GetWeaponKillAwardByClassName(const char[] chClassName);
native int CSGOItems_GetWeaponKillAwardByWeaponNum(int iWeaponNum);
native bool CSGOItems_RefillClipAmmo(int iWeapon);
native bool CSGOItems_RefillReserveAmmo(int iWeapon);
native bool CSGOItems_IsValidWeapon(int iWeapon);
native int CSGOItems_GiveWeapon(int iClient, const char[] chClassName, int iReserveAmmo = -1, int iClipAmmo = -1, int iSwitchTo = -1);
native bool CSGOItems_RemoveKnife(int iClient);
native bool CSGOItems_RemoveWeapon(int iClient, int iWeapon);
native bool CSGOItems_SetWeaponAmmo(int iWeapon, int iReserveAmmo = -1, int iClipAmmo = -1);
native int CSGOItems_SetAllWeaponsAmmo(const char[] chClassName, int iReserveAmmo = -1, int iClipAmmo = -1);
native bool CSGOItems_SetActiveWeapon(int iClient, int iWeapon);
native int CSGOItems_GetActiveWeaponSlot(int iClient);
native bool CSGOItems_AreItemsSynced();
native bool CSGOItems_AreItemsSyncing();
native bool CSGOItems_ReSync();
native int CSGOItems_GetRandomSkin();

// SKINS
native int CSGOItems_GetSkinNumByDefIndex(int iDefIndex);
native int CSGOItems_GetSkinDefIndexBySkinNum(int iSkinNum);
native bool CSGOItems_GetSkinDisplayNameByDefIndex(int iDefIndex, char[] chBuffer, int iLengh);
native bool CSGOItems_GetSkinDisplayNameBySkinNum(int iSkinNum, char[] chBuffer, int iLengh);

// MUSIC KITS
native int CSGOItems_GetMusicKitNumByDefIndex(int iDefIndex);
native int CSGOItems_GetMusicKitDefIndexByMusicKitNum(int iMusicKitNum);
native bool CSGOItems_GetMusicKitDisplayNameByDefIndex(int iDefIndex, char[] chBuffer, int iLengh);
native bool CSGOItems_GetMusicKitDisplayNameByMusicKitNum(int iMusicKitNum, char[] chBuffer, int iLengh); 