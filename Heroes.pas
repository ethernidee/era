UNIT Heroes;
{
DESCRIPTION:  Internal game functions and structures
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Utils;

CONST
  (* Game settings *)
  GAME_SETTINGS_FILE    = 'heroes3.ini';
  GAME_SETTINGS_SECTION = 'Settings';
  
  (* Stacks on battlefield *)
  NUM_BATTLE_STACKS = 42;
  
  (*  BattleMon  *)
  STACK_STRUCT_SIZE = 1352;
  STACK_TYPE        = $34;
  STACK_POS         = $38;
  STACK_POS_SHIFT   = $44;
  STACK_NUM         = $4C;
  STACK_LOSTHP      = $58;
  STACK_FLAGS       = $84;
  STACK_HP          = $C0;
  STACK_SIDE        = $F4;

  (* Game version *)
  ROE         = 0;
  AB          = 1;
  SOD         = 2;
  SOD_AND_AB  = AB + SOD;
  
  SHOW_INTRO_OPT:             PINTEGER  = Ptr($699410);
  MUSIC_VOLUME_OPT:           PINTEGER  = Ptr($6987B0);
  SOUND_VOLUME_OPT:           PINTEGER  = Ptr($6987B4);
  LAST_MUSIC_VOLUME_OPT:      PINTEGER  = Ptr($6987B8);
  LAST_SOUND_VOLUME_OPT:      PINTEGER  = Ptr($6987BC);
  WALK_SPEED_OPT:             PINTEGER  = Ptr($6987AC);
  COMP_WALK_SPEED_OPT:        PINTEGER  = Ptr($6987A8);
  SHOW_ROUTE_OPT:             PINTEGER  = Ptr($6987C4);
  MOVE_REMINDER_OPT:          PINTEGER  = Ptr($6987C8);
  QUICK_COMBAT_OPT:           PINTEGER  = Ptr($6987CC);
  VIDEO_SUBTITLES_OPT:        PINTEGER  = Ptr($6987D0);
  TOWN_OUTLINES_OPT:          PINTEGER  = Ptr($6987D4);
  ANIMATE_SPELLBOOK_OPT:      PINTEGER  = Ptr($6987D8);
  WINDOW_SCROLL_SPEED_OPT:    PINTEGER  = Ptr($6987DC);
  BLACKOUT_COMPUTER_OPT:      PINTEGER  = Ptr($6987E0);
  FIRST_TIME_OPT:             PINTEGER  = Ptr($699574);
  TEST_DECOMP_OPT:            PINTEGER  = Ptr($699578);
  TEST_READ_OPT:              PINTEGER  = Ptr($69957C);
  TEST_BLIT_OPT:              PINTEGER  = Ptr($699580);
  BINK_VIDEO_OPT:             PINTEGER  = Ptr($6987F8);
  UNIQUE_SYSTEM_ID_OPT:       PCHAR     = Ptr($698838);
  NETWORK_DEF_NAME_OPT:       PCHAR     = Ptr($698867);
  AUTOSAVE_OPT:               PINTEGER  = Ptr($6987C0);
  SHOW_COMBAT_GRID_OPT:       PINTEGER  = Ptr($69880C);
  SHOW_COMBAT_MOUSE_HEX_OPT:  PINTEGER  = Ptr($698810);
  COMBAT_SHADE_LEVEL_OPT:     PINTEGER  = Ptr($698814);
  COMBAT_ARMY_INFO_LEVEL_OPT: PINTEGER  = Ptr($698818);
  COMBAT_AUTO_CREATURES_OPT:  PINTEGER  = Ptr($6987E4);
  COMBAT_AUTO_SPELLS_OPT:     PINTEGER  = Ptr($6987E8);
  COMBAT_CATAPULT_OPT:        PINTEGER  = Ptr($6987EC);
  COMBAT_BALLISTA_OPT:        PINTEGER  = Ptr($6987F0);
  COMBAT_FIRST_AID_TENT_OPT:  PINTEGER  = Ptr($6987F4);
  COMBAT_SPEED_OPT:           PINTEGER  = Ptr($69883C);
  MAIN_GAME_SHOW_MENU_OPT:    PINTEGER  = Ptr($6987FC);
  MAIN_GAME_X_OPT:            PINTEGER  = Ptr($698800);
  MAIN_GAME_Y_OPT:            PINTEGER  = Ptr($698804);
  MAIN_GAME_FULL_SCREEN_OPT:  PINTEGER  = Ptr($698808);
  APP_PATH_OPT:               PCHAR     = Ptr($698614);
  CD_DRIVE_OPT:               PCHAR     = Ptr($698888);
  
  (* Dialog Ids *)
  ADVMAP_DLGID              = $402AE0;
  BATTLE_DLGID              = $4723E0;
  HERO_SCREEN_DLGID         = $4E1790;
  HERO_MEETING_SCREEN_DLGID = $5AE6E0;
  TOWN_SCREEN_DLGID         = $5C5CB0;

  LOAD_TXT_FUNC   = $55C2B0;  // F (Name: PCHAR); FASTCALL;
  UNLOAD_TXT_FUNC = $55D300;  // F (PTxtFile); FASTCALL;
  {
  F
  (
    Name:       PCHAR;
    AddExt:     LONGBOOL;
    ShowDialog: LONGBOOL;
    Compress:   INTBOOL;
    SaveToData: LONGBOOL
  ); THISCALL ([GAME_MANAGER]);
  }
  SAVEGAME_FUNC     = $4BEB60;
  LOAD_LOD          = $559420;  // F (Name: PCHAR); THISCALL (PLod);
  LOAD_LODS         = $559390;
  LOAD_DEF_SETTINGS = $50B420;  // F();
  SMACK_OPEN        = $63A464;  // F(FileName: PCHAR; BufSize, BufMask: INT): HANDLE OR 0; STDCALL;
  BINK_OPEN         = $63A390;  // F(hFile, BufMask OR $8000000: INT): HANDLE OR 0; STDCALL;
  
  hWnd:           PINTEGER  = Ptr($699650);
  hHeroes3Event:  PINTEGER  = Ptr($69965C);
  MarkedSavegame: PCHAR     = Ptr($68338C);
  Mp3Name:        PCHAR     = Ptr($6A33F4);
  
  GameVersion:  PINTEGER  = Ptr($67F554);
  
  (* Managers *)
  GAME_MANAGER     = $699538;
  HERO_WND_MANAGER = $6992D0;
  
  (* Colors *)
  RED_COLOR         = '0F2223E';
  HEROES_GOLD_COLOR = '0FFFE794';


TYPE
  PValue  = ^TValue;
  TValue  = PACKED RECORD
    CASE BYTE OF
      0:  (v:   INTEGER);
      1:  (p:   POINTER);
      2:  (pc:  PCHAR);
  END; // .RECORD TValue

  PTxtFile  = ^TTxtFile;
  TTxtFile  = PACKED RECORD
    Dummy:    ARRAY [0..$17] OF BYTE;
    RefCount: INTEGER;
    (* Dummy *)
  END; // .RECORD TTxtFile
  
  PLod  = ^TLod;
  TLod  = PACKED RECORD
    Dummy:  ARRAY [0..399] OF BYTE;
  END; // .RECORD TLod
  
  PGameState  = ^TGameState;
  TGameState  = PACKED RECORD
    RootDlgId:    INTEGER;
    CurrentDlgId: INTEGER;
  END; // .RECORD TGameState

  PPINTEGER = ^PINTEGER;

  PPAdvManager  = ^PAdvManager;
  PAdvManager   = ^TAdvManager;
  TAdvManager   = PACKED RECORD
    Dummy:            ARRAY [0..79] OF BYTE;
    RootDlgIdPtr:     PPINTEGER;
    CurrentDlgIdPtr:  PPINTEGER;
    (* Dummy *)
  END; // .RECORD TAdvManager
  
  PScreenPcx16  = ^TScreenPcx16;
  TScreenPcx16  = PACKED RECORD
    Dummy:  ARRAY [0..35] OF BYTE;
    Width:  INTEGER;
    Height: INTEGER;
    (* Dummy *)
  END; // .RECORD TScreenPcx16
  
  PWndManager = ^TWndManager;
  TWndManager = PACKED RECORD
    Dummy:        ARRAY [0..63] OF BYTE;
    ScreenPcx16:  PScreenPcx16;
    (* Dummy *)
  END; // .RECORD TWndManager

  TMAlloc = FUNCTION (Size: INTEGER): POINTER; CDECL;
  TMFree  = PROCEDURE (Addr: POINTER); CDECL;
  
  TGzipWrite  = PROCEDURE (Data: POINTER; DataSize: INTEGER); CDECL;
  TGzipRead   = FUNCTION (Dest: POINTER; DataSize: INTEGER): INTEGER; CDECL;
  TWndProc    = FUNCTION (hWnd, Msg, wParam, lParam: INTEGER): LONGBOOL; STDCALL;
  
  TGetBattleCellByPos = FUNCTION (Pos: INTEGER): POINTER; CDECL;


CONST
  MAlloc: TMAlloc = Ptr($617492);
  MFree:  TMFree  = Ptr($60B0F0);

  AdvManagerPtr:  PPAdvManager  = Ptr($6992D0);
  WndManagerPtr:  ^PWndManager  = Ptr($6992D0);

  ZvsGzipWrite: TGzipWrite  = Ptr($704062);
  ZvsGzipRead:  TGzipRead   = Ptr($7040A7);
  WndProc:      TWndProc    = Ptr($4F8290);
  
  GetBattleCellByPos: TGetBattleCellByPos = Ptr($715872);


PROCEDURE GZipWrite (Count: INTEGER; {n} Addr: POINTER);
FUNCTION  GzipRead (Count: INTEGER; {n} Addr: POINTER): INTEGER;
FUNCTION  LoadTxt (Name: PCHAR): {n} PTxtFile; STDCALL;
PROCEDURE ForceTxtUnload (Name: PCHAR); STDCALL;
PROCEDURE LoadLod (CONST LodName: STRING; Res: PLod);
PROCEDURE GetGameState (OUT GameState: TGameState); STDCALL;
FUNCTION  GetMapSize: INTEGER;
FUNCTION  IsTwoLevelMap: BOOLEAN;
FUNCTION  GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): INTEGER;
FUNCTION  GetStackIdByPos (StackPos: INTEGER): INTEGER;
PROCEDURE RedrawHeroMeetingScreen;
FUNCTION  IsCampaign: BOOLEAN;
FUNCTION  GetMapFileName: STRING;
FUNCTION  GetCampaignFileName: STRING;
FUNCTION  GetCampaignMapInd: INTEGER;
{Low level}
FUNCTION  GetVal (BaseAddr: POINTER; Offset: INTEGER): PValue; OVERLOAD;
FUNCTION  GetVal (BaseAddr, Offset: INTEGER): PValue; OVERLOAD;


(***) IMPLEMENTATION (***)


FUNCTION GetVal (BaseAddr: POINTER; Offset: INTEGER): PValue; OVERLOAD;
BEGIN
  RESULT  :=  Utils.PtrOfs(BaseAddr, Offset);
END; // .FUNCTION GetVal

FUNCTION GetVal (BaseAddr, Offset: INTEGER): PValue; OVERLOAD;
BEGIN
  RESULT  :=  Utils.PtrOfs(Ptr(BaseAddr), Offset);
END; // .FUNCTION GetVal

PROCEDURE GZipWrite (Count: INTEGER; {n} Addr: POINTER);
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Addr, Count));
  ZvsGzipWrite(Addr, Count);
END; // .PROCEDURE GZipWrite

FUNCTION GzipRead (Count: INTEGER; {n} Addr: POINTER): INTEGER;
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Addr, Count));
  RESULT := ZvsGzipRead(Addr, Count) + Count;
END; // .FUNCTION 

FUNCTION LoadTxt (Name: PCHAR): {n} PTxtFile;
BEGIN
  ASM
    MOV ECX, Name
    MOV EAX, LOAD_TXT_FUNC
    CALL EAX
    MOV @RESULT, EAX
  END; // .ASM
END; // .FUNCTION LoadTxt

PROCEDURE ForceTxtUnload (Name: PCHAR);
VAR
{U} Txt:  PTxtFile;
  
BEGIN
  Txt :=  LoadTxt(Name);
  // * * * * * //
  IF Txt <> NIL THEN BEGIN
    Txt.RefCount  :=  1;
    
    ASM
      MOV ECX, Txt
      MOV EAX, UNLOAD_TXT_FUNC
      CALL EAX
    END; // .ASM
  END; // .IF
END; // .PROCEDURE ForceTxtUnload

PROCEDURE LoadLod (CONST LodName: STRING; Res: PLod);
BEGIN
  {!} ASSERT(Res <> NIL);
  ASM
    MOV ECX, Res
    PUSH LodName
    MOV EAX, LOAD_LOD
    CALL EAX
  END; // .ASM
END; // .PROCEDURE LoadLod

PROCEDURE GetGameState (OUT GameState: TGameState);
BEGIN
  IF AdvManagerPtr^.RootDlgIdPtr <> NIL THEN BEGIN
    GameState.RootDlgId :=  AdvManagerPtr^.RootDlgIdPtr^^;
  END // .IF
  ELSE BEGIN
    GameState.RootDlgId :=  0;
  END; // .ELSE
  IF AdvManagerPtr^.CurrentDlgIdPtr <> NIL THEN BEGIN
    GameState.CurrentDlgId  :=  AdvManagerPtr^.CurrentDlgIdPtr^^;
  END // .IF
  ELSE BEGIN
    GameState.CurrentDlgId  :=  0;
  END; // .ELSE
END; // .PROCEDURE GetDialogsIds

FUNCTION GetMapSize: INTEGER; ASSEMBLER; {$W+}
ASM
  MOV EAX, [GAME_MANAGER]
  MOV EAX, [EAX + $1FC44]
END; // .FUNCTION GetMapSize

FUNCTION IsTwoLevelMap: BOOLEAN; ASSEMBLER; {$W+}
ASM
  MOV EAX, [GAME_MANAGER]
  MOVZX EAX, BYTE [EAX + $1FC48]
END; // .FUNCTION IsTwoLevelMap

FUNCTION GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): INTEGER;
CONST
  SLOTS_PER_SIDE  = 21;
  SIDE_OFFSET     = $18;
  STACKID_OFFSET  = $19;
  
VAR
  Side: BYTE;

BEGIN
  Side  :=  BattleCell[SIDE_OFFSET];
  
  IF Side = 255 THEN BEGIN
    RESULT  :=  -1;
  END // .IF
  ELSE BEGIN
    RESULT  :=  SLOTS_PER_SIDE * Side + BattleCell[STACKID_OFFSET];
  END; // .ELSE
END; // .FUNCTION GetBattleCellStackId

FUNCTION GetStackIdByPos (StackPos: INTEGER): INTEGER;
TYPE
  PStackField = ^TStackField;
  TStackField = PACKED RECORD
    v:  INTEGER;
  END; // .RECORD TStackField

CONST
  NO_STACK  = -1;

  STACK_POS = $38;

  FUNCTION Stacks (Ind: INTEGER; FieldOfs: INTEGER): PStackField; INLINE;
  BEGIN
    RESULT  :=  Utils.PtrOfs(PPOINTER($699420)^, 21708 + 1352 * Ind + FieldOfs);
  END; // .FUNCTION Stacks

VAR
  i:  INTEGER;
  
BEGIN
  RESULT  :=  -1;
  i       :=  0;
  
  WHILE (i < NUM_BATTLE_STACKS) AND (RESULT = NO_STACK) DO BEGIN
    IF Stacks(i, STACK_POS).v = StackPos THEN BEGIN
      RESULT  :=  i;
    END // .IF
    ELSE BEGIN
      INC(i);
    END; // .ELSE
  END; // .WHILE
END; // .FUNCTION GetStackIdByPos

PROCEDURE RedrawHeroMeetingScreen; ASSEMBLER;
ASM
  MOV ECX, [$6A3D90]
  PUSH ECX
  MOV EAX, $5B1200
  CALL EAX
  
  MOV ECX, [ESP]
  MOV ECX, [ECX + $38]
  PUSH $0FFFF
  PUSH $FFFF0001
  PUSH 0
  MOV EDX, [ECX]
  CALL [EDX + $14]

  MOV ECX, [$6992D0]
  PUSH 600
  PUSH 800
  PUSH 0
  PUSH 0
  MOV EAX, $603190
  CALL EAX

  POP ECX
  MOV EAX, $5AF150
  CALL EAX
END; // .PROCEDURE RedrawHeroMeetingScreen

FUNCTION IsCampaign: BOOLEAN;
BEGIN
  RESULT := PBYTE($69779C)^ <> 0;
END; // .FUNCTION IsCampaign

FUNCTION GetMapFileName: STRING;
BEGIN
  RESULT := PCHAR(PINTEGER(GAME_MANAGER)^ + $1F6D9);
END; // .FUNCTION GetMapFileName

FUNCTION GetCampaignFileName: STRING;
TYPE
  TFuncRes = PACKED RECORD
    _0:               INTEGER;
    CampaignFileName: PCHAR;
    _1:               ARRAY [0..247] OF BYTE;
  END; // .RECORD TFuncRes

VAR
  FuncRes: TFuncRes;
  FuncResPtr: ^TFuncRes;

BEGIN
  {!} ASSERT(IsCampaign);
  ASM
    LEA EAX, FuncRes
    PUSH EAX
    MOV ECX, [GAME_MANAGER]
    ADD ECX, $1F458
    MOV EAX, $45A0C0
    CALL EAX
    MOV [FuncResPtr], EAX
  END; // .ASM
  
  RESULT := FuncResPtr.CampaignFileName;
END; // .FUNCTION GetCampaignFileName

FUNCTION GetCampaignMapInd: INTEGER;
BEGIN
  {!} ASSERT(IsCampaign);
  RESULT := PBYTE(PINTEGER(GAME_MANAGER)^ + $1F45A)^;
END; // .FUNCTION GetCampaignMapInd

END.
