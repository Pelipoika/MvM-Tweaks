#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public void OnPluginStart()
{
	//Make building max health upgrade apply to disposable sentries
	MemoryPatch("GetMaxHealthForCurrentLevel", "GetMaxHealthForCurrentLevel39", {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90}, 9);

	//Make sentries think every tick
	MemoryPatch("SentryThink", "SentryThink71", {0x90, 0x90, 0x90, 0x90, 0x90, 0x90}, 6);

	//Make every class have the currency collection radius effect	
	//0F 93 Set byte if above or equal (CF=0).
	MemoryPatch("RadiusCurrencyCollectionCheck", "RadiusCurrencyCollectionCheck6E", {0xF, 0x93}, 2);
	
	//Patch mvm automatic team assigning to allow more than 6 players on red team
	NumberPatch("GetTeamAssignmentOverride", "GetTeamAssignmentOverride14D", 6, 32);
	
	//Patch mvm to allow more than 6 players to join the server
	NumberPatch("PreClientUpdate", "PreClientUpdate2C2", 6, 32);
}

void MemoryPatch(const char[] patch, const char[] offset, int[] PatchBytes, int iCount)
{
	Handle hConf = LoadGameConfigFile("tf2.mvmpatches");
	if(hConf == INVALID_HANDLE)
		SetFailState("Can't find tf2.mvmpatches gamedata.");

	Address iAddr = GameConfGetAddress(hConf, patch);
	if(iAddr == Address_Null)
	{
		delete hConf;
		SetFailState("Can't find %s address.", patch);
	}
	
	int iOffset = GameConfGetOffset(hConf, offset);
	if(iOffset == -1)
	{
		delete hConf;
		SetFailState("Can't find %s in gamedata.", offset);
	}

	iAddr += view_as<Address>(iOffset);
	
	for (int i = 0; i < iCount; i++)
	{
		StoreToAddress(iAddr + view_as<Address>(i), PatchBytes[i], NumberType_Int8);
	}
	
	PrintToServer("APPLIED PATCH: %s", patch);
	
	delete hConf;
}

void NumberPatch(const char[] patch, const char[] offset, int iOldValue, int iNewValue)
{
	Handle hConf = LoadGameConfigFile("tf2.mvmpatches");
	if(hConf == INVALID_HANDLE)
		SetFailState("Can't find tf2.mvmpatches gamedata.");

	Address iAddr = GameConfGetAddress(hConf, patch);
	if(iAddr == Address_Null)
	{
		delete hConf;
		SetFailState("Can't find %s address.", patch);
	}
	
	int iOffset = GameConfGetOffset(hConf, offset);
	if(iOffset == -1)
	{
		delete hConf;
		SetFailState("Can't find %s in gamedata.", offset);
	}
	
	iAddr += view_as<Address>(iOffset);
	
	if(LoadFromAddress(iAddr, NumberType_Int8) == iOldValue)
	{
		StoreToAddress(iAddr, iNewValue, NumberType_Int8);
		PrintToServer("APPLIED PATCH: %s", patch);
	}
	else
	{
		PrintToServer("PATCH %s ALREADY APPLIED", patch);
	}
	
	delete hConf;
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