unit Heroes;
{
DESCRIPTION:  Internal game functions and structures
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Utils;

const
  (* Game settings *)
  GAME_SETTINGS_FILE    = 'heroes3.ini';
  GAME_SETTINGS_SECTION = 'Settings';
  
  (* Stacks on battlefield *)
  NUM_BATTLE_STACKS = 42;
  
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
  UNIQUE_SYSTEM_ID_OPT:       pchar     = Ptr($698838);
  NETWORK_DEF_NAME_OPT:       pchar     = Ptr($698867);
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
  APP_PATH_OPT:               pchar     = Ptr($698614);
  CD_DRIVE_OPT:               pchar     = Ptr($698888);
  
  (* Dialog Ids *)
  ADVMAP_DLGID              = $402AE0;
  BATTLE_DLGID              = $4723E0;
  HERO_SCREEN_DLGID         = $4E1790;
  HERO_MEETING_SCREEN_DLGID = $5AE6E0;
  TOWN_SCREEN_DLGID         = $5C5CB0;

  LOAD_TXT_FUNC   = $55C2B0;  // F (Name: pchar); FASTCALL;
  UNLOAD_TXT_FUNC = $55D300;  // F (PTxtFile); FASTCALL;
  {
  F
  (
    Name:       PCHAR;
    AddExt:     LONGBOOL;
    ShowDialog: LONGBOOL;
    Compress:   INTBOOL;
    SaveToData: LONGBOOL
  ); THISCALL ([$699538]);
  }
  SAVEGAME_FUNC     = $4BEB60;
  LOAD_LOD          = $559420;  // F (Name: pchar); THISCALL (PLod);
  LOAD_LODS         = $559390;
  LOAD_DEF_SETTINGS = $50B420;  // F();
  SMACK_OPEN        = $63A464;  // F(FileName: pchar; BufSize, BufMask: int): HANDLE or 0; stdcall;
  BINK_OPEN         = $63A390;  // F(hFile, BufMask or $8000000: int): HANDLE or 0; stdcall;
  
  hWnd:           PINTEGER  = Ptr($699650);
  hHeroes3Event:  PINTEGER  = Ptr($69965C);
  MarkedSavegame: pchar     = Ptr($68338C);
  
  GameVersion:  PINTEGER  = Ptr($67F554);


type
  PTxtFile  = ^TTxtFile;
  TTxtFile  = packed record
    Dummy:    array [0..$17] of byte;
    RefCount: integer;
    (* Dummy *)
  end; // .record TTxtFile
  
  PLod  = ^TLod;
  TLod  = packed record
    Dummy:  array [0..399] of byte;
  end; // .record TLod
  
  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end; // .record TGameState

  PPINTEGER = ^PINTEGER;

  PPAdvManager  = ^PAdvManager;
  PAdvManager   = ^TAdvManager;
  TAdvManager   = packed record
    Dummy:            array [0..79] of byte;
    RootDlgIdPtr:     PPINTEGER;
    CurrentDlgIdPtr:  PPINTEGER;
    (* Dummy *)
  end; // .record TAdvManager
  
  PScreenPcx16  = ^TScreenPcx16;
  TScreenPcx16  = packed record
    Dummy:  array [0..35] of byte;
    Width:  integer;
    Height: integer;
    (* Dummy *)
  end; // .record TScreenPcx16
  
  PWndManager = ^TWndManager;
  TWndManager = packed record
    Dummy:        array [0..63] of byte;
    ScreenPcx16:  PScreenPcx16;
    (* Dummy *)
  end; // .record TWndManager

  TMAlloc = function (Size: integer): pointer; cdecl;
  TMFree  = procedure (Addr: pointer); cdecl;
  
  TGzipWrite  = procedure (Data: pointer; DataSize: integer); cdecl;
  TGzipRead   = procedure (Dest: pointer; DataSize: integer); cdecl;
  TWndProc    = function (hWnd, Msg, wParam, lParam: integer): LONGBOOL; stdcall;
  
  TGetBattleCellByPos = function (Pos: integer): pointer; cdecl;


const
  MAlloc: TMAlloc = Ptr($617492);
  MFree:  TMFree  = Ptr($60B0F0);

  AdvManagerPtr:  PPAdvManager  = Ptr($6992D0);
  WndManagerPtr:  ^PWndManager  = Ptr($6992D0);

  GzipWrite:  TGzipWrite  = Ptr($704062);
  GzipRead:   TGzipRead   = Ptr($7040A7);
  WndProc:    TWndProc    = Ptr($4F8290);
  
  GetBattleCellByPos: TGetBattleCellByPos = Ptr($715872);


function  LoadTxt (Name: pchar): {n} PTxtFile; stdcall;
procedure ForceTxtUnload (Name: pchar); stdcall;
procedure LoadLod (const LodName: string; Res: PLod);
procedure GetGameState (out GameState: TGameState); stdcall;
function  GetMapSize: integer;
function  IsTwoLevelMap: boolean;
function  GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): integer;
function  GetStackIdByPos (StackPos: integer): integer;
procedure RedrawHeroMeetingScreen;

  
(***) implementation (***)


function LoadTxt (Name: pchar): {n} PTxtFile;
begin
  asm
    MOV ECX, Name
    MOV EAX, LOAD_TXT_FUNC
    CALL EAX
    MOV @result, EAX
  end; // .asm
end; // .function LoadTxt

procedure ForceTxtUnload (Name: pchar);
var
{U} Txt:  PTxtFile;
  
begin
  Txt :=  LoadTxt(Name);
  // * * * * * //
  if Txt <> nil then begin
    Txt.RefCount  :=  1;
    
    asm
      MOV ECX, Txt
      MOV EAX, UNLOAD_TXT_FUNC
      CALL EAX
    end; // .asm
  end; // .if
end; // .procedure ForceTxtUnload

procedure LoadLod (const LodName: string; Res: PLod);
begin
  {!} Assert(Res <> nil);
  asm
    MOV ECX, Res
    PUSH LodName
    MOV EAX, LOAD_LOD
    CALL EAX
  end; // .asm
end; // .procedure LoadLod

procedure GetGameState (out GameState: TGameState);
begin
  if AdvManagerPtr^.RootDlgIdPtr <> nil then begin
    GameState.RootDlgId :=  AdvManagerPtr^.RootDlgIdPtr^^;
  end // .if
  else begin
    GameState.RootDlgId :=  0;
  end; // .else
  if AdvManagerPtr^.CurrentDlgIdPtr <> nil then begin
    GameState.CurrentDlgId  :=  AdvManagerPtr^.CurrentDlgIdPtr^^;
  end // .if
  else begin
    GameState.CurrentDlgId  :=  0;
  end; // .else
end; // .procedure GetDialogsIds

function GetMapSize: integer; ASSEMBLER; {$W+}
asm
  MOV EAX, [$699538]
  MOV EAX, [EAX + $1FC44]
end; // .function GetMapSize

function IsTwoLevelMap: boolean; ASSEMBLER; {$W+}
asm
  MOV EAX, [$699538]
  MOVZX EAX, byte [EAX + $1FC48]
end; // .function IsTwoLevelMap

function GetBattleCellStackId (BattleCell: Utils.PEndlessByteArr): integer;
const
  SLOTS_PER_SIDE  = 21;
  SIDE_OFFSET     = $18;
  STACKID_OFFSET  = $19;
  
var
  Side: byte;

begin
  Side  :=  BattleCell[SIDE_OFFSET];
  
  if Side = 255 then begin
    result  :=  -1;
  end // .if
  else begin
    result  :=  SLOTS_PER_SIDE * Side + BattleCell[STACKID_OFFSET];
  end; // .else
end; // .function GetBattleCellStackId

function GetStackIdByPos (StackPos: integer): integer;
type
  PStackField = ^TStackField;
  TStackField = packed record
    v:  integer;
  end; // .record TStackField

const
  NO_STACK  = -1;

  STACK_POS = $38;

  function Stacks (Ind: integer; FieldOfs: integer): PStackField; inline;
  begin
    result  :=  Utils.PtrOfs(PPOINTER($699420)^, 21708 + 1352 * Ind + FieldOfs);
  end; // .function Stacks

var
  i:  integer;
  
begin
  result  :=  -1;
  i       :=  0;
  
  while (i < NUM_BATTLE_STACKS) and (result = NO_STACK) do begin
    if Stacks(i, STACK_POS).v = StackPos then begin
      result  :=  i;
    end // .if
    else begin
      Inc(i);
    end; // .else
  end; // .while
end; // .function GetStackIdByPos

procedure RedrawHeroMeetingScreen; ASSEMBLER;
asm
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
end; // .procedure RedrawHeroMeetingScreen

end.
