#pragma semicolon 1

#define PLUGIN_AUTHOR "SM9"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <cstrike>
#include <csgoitems>

Handle g_hPrimaryArray = null;
Handle g_hSecondaryArray = null;

int g_iPrimaryCount = 0;
int g_iSecondaryCount = 0;

char g_chMenuTriggers[][] =  {
	"!guns", "/guns", "!gun", "/gun", "!weapon", "/weapon", "!weapons", "/weapons", "guns", "gun", "weapon"
};

public Plugin myinfo = 
{
	name = "CSGOItems Weapon Menu Example", 
	author = PLUGIN_AUTHOR, 
	description = "An example weapon menu built using CSGOItems Core", 
	version = PLUGIN_VERSION, 
	url = "www.fragdeluxe.com"
};

public void OnPluginStart()
{
	// This plugin only works on CSGO, but you already know that :P
	if (GetEngineVersion() != Engine_CSGO) {
		SetFailState("This plugin is for CSGO only.");
	}
	
	// We want to listen for the menu commands.
	AddCommandListener(CommandListener, "say");
	AddCommandListener(CommandListener, "say_team");
	
	// Lets create the 2 arrays to store our weapons.
	g_hPrimaryArray = CreateArray(128);
	g_hSecondaryArray = CreateArray(128);
}

public void CSGOItems_OnItemsSynced() {
	BuildMenuArray(); // Lets build our menu array!
}

public void BuildMenuArray()
{
	// Clear the arrays just incase the items got resynced.
	ClearArray(g_hPrimaryArray);
	ClearArray(g_hSecondaryArray);
	
	int iWeaponCount = CSGOItems_GetWeaponCount(); // Lets get the weapon count.
	
	for (int i = 0; i <= iWeaponCount; ++i) {  // Now we loop through all the weapons.
		
		int iWeaponSlot = CSGOItems_GetWeaponSlotByWeaponNum(i); // We get the weapon slot.
		
		if (iWeaponSlot != CS_SLOT_PRIMARY && iWeaponSlot != CS_SLOT_SECONDARY) {  // Since its a gun menu, all we want is guns.
			continue;
		}
		
		char chClassName[48]; CSGOItems_GetWeaponClassNameByWeaponNum(i, chClassName, 48); // We get the ClassName
		char chDisplayName[48]; CSGOItems_GetWeaponDisplayNameByWeaponNum(i, chDisplayName, 64); // We get the DisplayName
		
		if (StrEqual(chDisplayName, "SCAR-20", false) || StrEqual(chDisplayName, "G3SG1", false)) {  // Lets say we don't want auto snipers, its easy as this.
			continue;
		}
		
		// This part can probably be done better, although I do it like this so we can make the menu alpabetical ;)
		char chBuffer[96]; Format(chBuffer, 64, "%s;%s", chDisplayName, chClassName); // We format 1 string containing the DisplayName and ClassName which we can split later.
		
		// Lets push the weapons into the right arrays.
		switch (iWeaponSlot) {
			case CS_SLOT_PRIMARY :  {
				PushArrayString(g_hPrimaryArray, chBuffer);
				g_iPrimaryCount++;
			}
			
			case CS_SLOT_SECONDARY :  {
				PushArrayString(g_hSecondaryArray, chBuffer);
				g_iSecondaryCount++;
			}
		}
	}
	
	SortADTArray(g_hPrimaryArray, Sort_Ascending, Sort_String); // Lets make the primary menu alphabetical.
	SortADTArray(g_hSecondaryArray, Sort_Ascending, Sort_String); // Lets make the secondary menu alphabetical.
}

public Action CommandListener(int iClient, char[] ChCommand, int iArg)
{
	char chText[20]; GetCmdArgString(chText, 20);
	StripQuotes(chText); TrimString(chText); // Sanitize his text.
	
	int iMenuTriggers = sizeof(g_chMenuTriggers); // Lets get the menu trigger count.
	
	for (int i; i < iMenuTriggers; i++) {  // Loop the triggers.
		if (StrEqual(chText, g_chMenuTriggers[i], false)) {  // If its equal then we can show the menu.
			DisplayWeaponMenu(iClient, CS_SLOT_PRIMARY); // Now lets show him the primary weapon menu :D
			
			return Plugin_Handled; // Block his trigger appearing in chat.
		}
	}
	
	return Plugin_Continue; // Anything else said will be ignored.
}

public void DisplayWeaponMenu(int iClient, int iWeaponSlot)
{
	char chWeaponString[48]; // The string we received from array.
	char chWeaponData[64][64]; // Used for splitting.
	
	Menu hMenu = CreateMenu(Menu_Handler); // Create a menu.
	
	int iCount = -1;
	Handle hArray = null;
	
	switch (iWeaponSlot) {
		case CS_SLOT_PRIMARY :  {
			iCount = g_iPrimaryCount;
			hArray = g_hPrimaryArray;
			SetMenuTitle(hMenu, "Select a primary weapon");
		}
		
		case CS_SLOT_SECONDARY :  {
			iCount = g_iSecondaryCount;
			hArray = g_hSecondaryArray;
			SetMenuTitle(hMenu, "Select a secondary weapon");
		}
	}
	
	for (int i = 0; i < iCount; ++i) {  // Okay, lets loop the array.
		GetArrayString(hArray, i, chWeaponString, 64); // We get the string.
		ExplodeString(chWeaponString, ";", chWeaponData, 64, 64); // Lets split it.
		
		hMenu.AddItem(chWeaponData[1], chWeaponData[0]); // Add the weapon to menu.
	}
	
	// Menu title.
	DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER); // Display menu to player.
}

public int Menu_Handler(Menu mMenu, MenuAction maAction, int iClient, int iItem)
{
	switch (maAction) {
		case MenuAction_Select: {
			char chClassName[48]; mMenu.GetItem(iItem, chClassName, 48); // We got the classname
			char chDisplayName[48]; CSGOItems_GetWeaponDisplayNameByClassName(chClassName, chDisplayName, 48); // Lets show him what he was got :P
			CSGOItems_GiveWeapon(iClient, chClassName); // Now we give him the gun, You don't even need to check if he already has a gun, its handled by the core :)
			PrintToChat(iClient, "[SM] You selected %s", chDisplayName);
			
			if (CSGOItems_GetWeaponSlotByClassName(chClassName) == CS_SLOT_PRIMARY) {  // If he just picked a primary weapon we show him the secondary menu.
				DisplayWeaponMenu(iClient, CS_SLOT_SECONDARY); // Lets show him the secondary menu now.
			}
		}
		
		case MenuAction_End: {  // :( He does not want a gun.
			delete mMenu;
		}
	}
} 