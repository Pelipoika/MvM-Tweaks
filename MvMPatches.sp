#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <dhooks>
#include <tf2_stocks>

#pragma newdecls required

Handle hConf;


//Detours
Handle hCreateEntityByName;
Handle hAddItem;

public void OnPluginStart()
{
	hConf = LoadGameConfigFile("tf2.mvmpatches");
	if(hConf == null)
		SetFailState("Can't find tf2.mvmpatches gamedata.");

	//Don't prevent BunnyJumping, a scuffed way of doing it but it works and is simple
	MemoryPatch("PreventBunnyJumping", "PreventBunnyJumping18", {0x74}, 1);

	//Make sentries think every tick
//	MemoryPatch("SentryThink", "SentryThink71", {0x90, 0x90, 0x90, 0x90, 0x90, 0x90}, 6);

	//Make every class have the currency collection radius effect	
	//Replace the offset it checks ("m_iClass") for with "m_bClientSideAnimation" which should always be 1
	int iOldOffset = FindSendPropInfo("CTFPlayer", "m_iClass");
	int iNewOffset = FindSendPropInfo("CTFPlayer", "m_bClientSideAnimation");
	NumberPatch("RadiusCurrencyCollectionCheck", "RadiusCurrencyCollectionCheck6E", iOldOffset, iNewOffset, NumberType_Int16);
	
	//Patch mvm automatic team assigning to allow more than 6 players on red team
	NumberPatch("GetTeamAssignmentOverride", "GetTeamAssignmentOverride14D", 6, 10, NumberType_Int8);
	
	//Patch mvm to allow more than 6 players to join the server
	NumberPatch("PreClientUpdate", "PreClientUpdate2C2", 6, 10, NumberType_Int8);
	
	//Patch mvm adding spectator count to sv_visiblemaxplayers
	MemoryPatch("PreClientUpdate", "PreClientUpdateSpecINC", {0x90}, 1);
	
	//Remap item entity names so bots can be given multi-class weapons
	//CreateEntityByName
	hCreateEntityByName = DHookCreateDetour(Address_Null, CallConv_CDECL, ReturnType_CBaseEntity, ThisPointer_Address);
	if (!hCreateEntityByName)
		SetFailState("Failed to setup detour for CreateEntityByName");
	
	if (!DHookSetFromConf(hCreateEntityByName, hConf, SDKConf_Signature, "CreateEntityByName"))
		SetFailState("Failed to load CreateEntityByName signature from gamedata");
	
	DHookAddParam(hCreateEntityByName, HookParamType_CharPtr); // *classname
	DHookAddParam(hCreateEntityByName, HookParamType_Int); //iForceEdictIndex
	
	if (!DHookEnableDetour(hCreateEntityByName, false, CreateEntityByName_Dtor))
		SetFailState("Failed to detour CreateEntityByName.");
	
	PrintToServer("Detoured CreateEntityByName!");
	
	//CTFBot::AddItem
	hAddItem = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Void, ThisPointer_CBaseEntity);
	if (!hAddItem)
		SetFailState("Failed to setup detour for CTFBot::AddItem");
	
	if (!DHookSetFromConf(hAddItem, hConf, SDKConf_Signature, "CTFBot::AddItem"))
		SetFailState("Failed to load CTFBot::AddItem signature from gamedata");
	
	DHookAddParam(hAddItem, HookParamType_CharPtr, .custom_register = DHookRegister_EBX); // *classname
	DHookAddParam(hAddItem, HookParamType_Int); //something (Windows exclusive!)
	
	if (!DHookEnableDetour(hAddItem, false, CTFBot_AddItem_Dtor))
		SetFailState("Failed to detour CTFBot::AddItem.");
	
	PrintToServer("Detoured CTFBot::AddItem!");
	
	delete hConf;
}

bool bTranslate = false;
TFClassType bot_classnum = TFClass_Unknown;

public MRESReturn CTFBot_AddItem_Dtor(int pThis, Handle hParams)
{
	//char strItemName[PLATFORM_MAX_PATH];	//Gives garbled string, propably beacuse of the custom register stuff
	//DHookGetParamString(hParams, 1, strItemName, sizeof(strItemName));

	bot_classnum = TF2_GetPlayerClass(pThis);
	bTranslate = true;
	
	//PrintToServer("CTFBot::AddItem(%i (\"%N\")) class %i", pThis, pThis, bot_classnum);
	
	return MRES_Ignored;
}

public MRESReturn CreateEntityByName_Dtor(Address pThis, Handle hParams)
{
	char strClass[PLATFORM_MAX_PATH];
	DHookGetParamString(hParams, 1, strClass, sizeof(strClass));
	
	if(bTranslate)
	{
		//PrintToServer("PRE CreateEntityByName(%s)", strClass);
		
		bool bWasTranslated = TranslateWeaponEntForClass(strClass, bot_classnum, strClass, sizeof(strClass));
		
		if(bWasTranslated) {
			//PrintToServer("TRANSLATED CreateEntityByName(%s)", strClass);
			
			DHookSetParamString(hParams, 1, strClass);
			
			bTranslate = false;
			
			return MRES_ChangedHandled;
		}	
	}
	
	bTranslate = false;
	
	return MRES_Ignored;
}

stock bool TranslateWeaponEntForClass(const char[] name, TFClassType class, char[] buffer, int maxlength)
{
	if (StrEqual(name, "tf_weapon_shotgun")) 
	{
		switch (class) 
		{
			case TFClass_Soldier:  {strcopy(buffer, maxlength, "tf_weapon_shotgun_soldier"); return true;}
			case TFClass_Pyro:     {strcopy(buffer, maxlength, "tf_weapon_shotgun_pyro");    return true;}
			case TFClass_Heavy:    {strcopy(buffer, maxlength, "tf_weapon_shotgun_hwg");     return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_shotgun_primary"); return true;}
			default:               {strcopy(buffer, maxlength, "tf_weapon_shotgun_primary"); return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_pistol")) 
	{
		switch (class) 
		{
			case TFClass_Scout:    {strcopy(buffer, maxlength, "tf_weapon_pistol_scout"); return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_pistol");       return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_shovel") || StrEqual(name, "tf_weapon_bottle")) 
	{
		switch (class) 
		{
			case TFClass_Soldier: {strcopy(buffer, maxlength, "tf_weapon_shovel"); return true;}
			case TFClass_DemoMan: {strcopy(buffer, maxlength, "tf_weapon_bottle"); return true;}
		}
	}
	
	if (StrEqual(name, "saxxy")) 
	{
		switch (class)
		{
			case TFClass_Scout:    {strcopy(buffer, maxlength, "tf_weapon_bat");     return true;}
			case TFClass_Soldier:  {strcopy(buffer, maxlength, "tf_weapon_shovel");  return true;}
			case TFClass_Pyro:     {strcopy(buffer, maxlength, "tf_weapon_fireaxe"); return true;}
			case TFClass_DemoMan:  {strcopy(buffer, maxlength, "tf_weapon_bottle");  return true;}
			case TFClass_Heavy:    {strcopy(buffer, maxlength, "tf_weapon_fireaxe"); return true;}
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_wrench");  return true;}
			case TFClass_Medic:    {strcopy(buffer, maxlength, "tf_weapon_bonesaw"); return true;}
			case TFClass_Sniper:   {strcopy(buffer, maxlength, "tf_weapon_club");    return true;}
			case TFClass_Spy:      {strcopy(buffer, maxlength, "tf_weapon_knife");   return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_throwable")) 
	{
		switch (class) 
		{
			case TFClass_Medic: {strcopy(buffer, maxlength, "tf_weapon_throwable_primary");   return true;}
			default:            {strcopy(buffer, maxlength, "tf_weapon_throwable_secondary"); return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_parachute")) 
	{
		switch (class) 
		{
			case TFClass_Soldier: {strcopy(buffer, maxlength, "tf_weapon_parachute_secondary"); return true;}
			case TFClass_DemoMan: {strcopy(buffer, maxlength, "tf_weapon_parachute_primary");   return true;}
		}
	}
	
	if (StrEqual(name, "tf_weapon_revolver")) 
	{
		switch (class) 
		{
			case TFClass_Engineer: {strcopy(buffer, maxlength, "tf_weapon_revolver_secondary"); return true;}
		}
	}
	
	/* if not handled: return original entity name, not an empty string */
	strcopy(buffer, maxlength, name);
	
	return false;
}

void MemoryPatch(const char[] patch, const char[] offset, int[] PatchBytes, int iCount)
{
	Address iAddr = GameConfGetAddress(hConf, patch);
	if(iAddr == Address_Null)
	{
		LogError("Can't find %s address.", patch);
		return;
	}
	
	int iOffset = GameConfGetOffset(hConf, offset);
	if(iOffset == -1)
	{
		LogError("Can't find %s in gamedata.", offset);
		return;
	}
	
	iAddr += view_as<Address>(iOffset);
	
	for (int i = 0; i < iCount; i++)
	{
		//int instruction = LoadFromAddress(iAddr + view_as<Address>(i), NumberType_Int8);
		//PrintToServer("%s 0x%x %i", patch, instruction, instruction);
		
		StoreToAddress(iAddr + view_as<Address>(i), PatchBytes[i], NumberType_Int8);
	}
	
	PrintToServer("APPLIED PATCH: %s", patch);
}

void NumberPatch(const char[] patch, const char[] offset, int iOldValue, int iNewValue, NumberType numtype = NumberType_Int8)
{
	Address iAddr = GameConfGetAddress(hConf, patch);
	if(iAddr == Address_Null)
	{
		LogError("Can't find %s address.", patch);
		return;
	}
	
	int iOffset = GameConfGetOffset(hConf, offset);
	if(iOffset == -1)
	{
		LogError("Can't find %s in gamedata.", offset);
		return;
	}
	
	iAddr += view_as<Address>(iOffset);
	
/*	for (int i = 0; i < 4; i++)
	{
		int instruction = LoadFromAddress(iAddr + view_as<Address>(i), numtype);
		PrintToServer("%i = 0x%x %i", i, instruction, instruction);
	}
	
	PrintToServer("old %i new %i", iOldValue, iNewValue);*/
		
	if(LoadFromAddress(iAddr, numtype) == iOldValue)
	{
		StoreToAddress(iAddr, iNewValue, numtype);
		PrintToServer("APPLIED PATCH: %s", patch);
	}
	else
	{
		PrintToServer("PATCH %s ALREADY APPLIED", patch);
	}
}

/*
EAX = AH AX AL
EDX = DH DX AL
ECX = CH CX CL
EBX = BH BX BL

56                                      push    esi
8B B7 8C 01 00 00                       mov     esi, [edi+18Ch]						Move 396    into esi
B8 40 14 00 00                          mov     eax, 1440h							Move 5 184  into eax
BA 00 44 01 00                          mov     edx, 14400h							Move 82 944 into edx
83 BE 58 20 00 00 01                    cmp     dword ptr [esi+2058h], 1			Compare 1 with m_PlayerClass + m_iClass. if(iClass - 1) == 0 ? ZF = 1 : ZF = 0
0F 94 C1                                setz    cl									Set cl to 1 if zero (ZF = 1)
84 C9                                   test    cl, cl								Set ZF to 1 if cl == 0
88 4D FF                                mov     [ebp+var_1], cl						Move cl into ebx + var_1 stack
0F 45 C2                                cmovnz  eax, edx							Move edx [Contains 82 944] into eax if not zero (ZF = 0)
89 45 E8                                mov     [ebp+var_18], eax					Move eax [Contains 5 184]  into ebp + var_18 stack
8B 86 14 01 00 00                       mov     eax, [esi+114h]						Move esi + 276 into eax
C1 E8 0B                                shr     eax, 0Bh							Unsigned divide eax by 2, 11 times
A8 01                                   test    al, 1								al & 1
74 07                                   jz      short loc_104CA3D7					Jump short if zero/equal (ZF = 0)
8B CE                                   mov     ecx, esi							Move esi into ecx
E8 E9 03 CC FF                          call    CBaseEntity__CalcAbsolutePosition	Call blah
*/