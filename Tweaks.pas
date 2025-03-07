unit Tweaks;
(*
  Description: Game fixes, tweaks and improvements
  Author:      Alexander Shostak (aka Berserker aka EtherniDee)
*)

(***)  interface  (***)
uses
  Math,
  PsApi,
  SysUtils,
  Types,
  Windows,
  WinSock,

  FastMM4,

  Alg,
  ApiJack,
  CFiles,
  Concur,
  ConsoleApi,
  Crypto,
  DataLib,
  Debug,
  DlgMes,
  FastRand,
  Files,
  FilesEx,
  Ini,
  Log,
  PatchApi,
  StrLib,
  Utils,
  WinNative,
  WinUtils,

  EraSettings,
  Erm,
  EventLib,
  EventMan,
  GameExt,
  Graph,
  Heroes,
  Lodman,
  Memory,
  Network,
  Stores,
  Trans,
  WogDialogs;

type
  (* Import *)
  TStrList = DataLib.TStrList;
  TRect    = Types.TRect;

  pbyte = ^byte;

const
  // f (Value: pchar; MaxResLen: integer; DefValue, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsReadStrIni  = Ptr($773A46);
  // f (Res: pinteger; DefValue: integer; Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsReadIntIni  = Ptr($7739D1);
  // f (Value: pchar; Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteStrIni = Ptr($773B34);
  // f (Value, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteIntIni = Ptr($773ACB);
  // f ()
  ZvsNoMoreTactic1 = Ptr($75D1FF);

  ZvsAppliedDamage: pinteger = Ptr($2811888);
  CurrentMp3Track:  pchar = pointer($6A33F4);

  FIRST_TACTICS_ROUND = -1000000000;

  DEBUG_RNG_NONE  = 0; // do not debug
  DEBUG_RNG_SRAND = 1; // debug only seeds
  DEBUG_RNG_RANGE = 2; // debug only seeds and range generations
  DEBUG_RNG_ALL   = 3; // debug all rand/srand/rand_range calls


var
  (* Desired level of CPU loading *)
  CpuTargetLevel: integer;

  AutoSelectPcIpMaskOpt: string;
  LastUsedPcIp:          integer = 0;
  IsSelectingPcIp:       boolean = false;

  UseOnlyOneCpuCoreOpt:  boolean;
  DebugRng:              integer;


(* Generates random value in specified range with additional custom parameter used only in deterministic generators to produce different outputs for sequence of generations *)
function RandomRangeWithFreeParam (MinValue, MaxValue, FreeParam: integer): integer; stdcall;

procedure ProcessUnhandledException (ExceptionRecord: Windows.PExceptionRecord; Context: Windows.PContext);

(* Writes memory consumption info to main log file *)
procedure LogMemoryState;


(***) implementation (***)


const
  RNG_SAVE_SECTION      = 'Era.RNG';
  CRASH_SCREENSHOT_PATH = EraSettings.DEBUG_DIR + '\screenshot.jpg';
  CRASH_SAVEGAME_PATH   = EraSettings.DEBUG_DIR + '\savegame.gm1';

  DL_GROUP_INDEX_MARKER = 100000; // DL frame index column is DL_GROUP_INDEX_MARKER * groupIndex + frameIndex

  OUT_OF_MEMORY_RESERVE_BLOCK_SIZE    = 1024000;
  OUT_OF_MEMORY_RESERVE_BYTES         = 1 * OUT_OF_MEMORY_RESERVE_BLOCK_SIZE;  // Delphi GetMem reserve
  OUT_OF_MEMORY_VIRTUAL_RESERVE_BYTES = 15 * OUT_OF_MEMORY_RESERVE_BLOCK_SIZE; // VirtualAlloc reserved, but not commited

type
  TWogMp3Process = procedure; stdcall;

  TBattleDeterministicRngState = packed record
    fCombatRound:    integer;
    fRangeMin:       integer;
    fCombatId:       integer;
    fRangeMax:       integer;
    fCombatActionId: integer;
    fFreeParam:      integer;
    fAttemptParam:   integer;
  end;

  TBattleDeterministicRng = class (FastRand.TRng)
   protected
    fState:             TBattleDeterministicRngState;
    fCombatIdPtr:       pinteger;
    fCombatRoundPtr:    pinteger;
    fCombatActionIdPtr: pinteger;
    fFreeParamPtr:      pinteger;

    procedure UpdateState (RangeMin, RangeMax: integer; AttemptIndex: integer = 1);

   public
    constructor Create (CombatIdPtr, CombatRoundPtr, CombatActionIdPtr, FreeParamPtr: pinteger);

    procedure Seed (NewSeed: integer); override;
    function Random: integer; override;
    function GetStateSize: integer; override;
    procedure ReadState (Buf: pointer); override;
    procedure WriteState (Buf: pointer); override;
    function RandomRange (MinValue, MaxValue: integer): integer; override;
  end;

var
{O} CLangRng:                  FastRand.TClangRng;
{O} QualitativeRng:            FastRand.TXoroshiro128Rng;
{O} BattleDeterministicRng:    TBattleDeterministicRng;
{U} GlobalRng:                 FastRand.TRng;
{O} OutOfMemoryReserve:        pointer;
{O} OutOfMemoryVirtualReserve: pointer;

  hTimerEvent:           THandle;
  InetCriticalSection:   Windows.TRTLCriticalSection;
  ExceptionsCritSection: Concur.TCritSection;
  ZvsLibImageTemplate:   string;
  ZvsLibGamePath:        string;
  IsLocalPlaceObject:    boolean = true;
  DlgLastEvent:          Heroes.TMouseEventInfo;
  ComputerName:          string;
  IsCrashing:            boolean;
  CrashSavegameName:     string;
  ShouldLogMemoryState:  boolean = true;

  Mp3TriggerHandledEvent: THandle;
  IsMp3Trigger:           boolean = false;
  WogCurrentMp3TrackPtr:  ppchar = pointer($28AB204);
  WoGMp3Process:          TWogMp3Process = pointer($77495F);

  CombatId:            integer;
  CombatRound:         integer;
  CombatActionId:      integer;
  CombatRngFreeParam:  integer;
  HadTacticsPhase:     boolean;
  NativeRngSeed:       pinteger = pointer($67FBE4);

  CombatOrigStackActionInfo: record
    Action:       integer;
    Spell:        integer;
    TargetPos:    integer;
    ActionParam2: integer;
  end;

threadvar
  (* Counter (0..100). When reaches 100, PeekMessageA does not call sleep before returning result *)
  CpuPatchCounter: integer;


constructor TBattleDeterministicRng.Create (CombatIdPtr, CombatRoundPtr, CombatActionIdPtr, FreeParamPtr: pinteger);
begin
  Self.fCombatIdPtr       := CombatIdPtr;
  Self.fCombatRoundPtr    := CombatRoundPtr;
  Self.fCombatActionIdPtr := CombatActionIdPtr;
  Self.fFreeParamPtr      := FreeParamPtr;
end;

procedure TBattleDeterministicRng.UpdateState (RangeMin, RangeMax: integer; AttemptIndex: integer = 1);
begin
  Self.fState.fCombatRound    := Crypto.Tm32Encode(Self.fCombatRoundPtr^);
  Self.fState.fRangeMin       := RangeMin;
  Self.fState.fCombatId       := Crypto.Tm32Encode(Self.fCombatIdPtr^);
  Self.fState.fRangeMax       := RangeMax;
  Self.fState.fCombatActionId := Crypto.Tm32Encode(Self.fCombatActionIdPtr^ + 1147022261);
  Self.fState.fFreeParam      := Crypto.Tm32Encode(Self.fFreeParamPtr^ + 641013956);
  Self.fState.fAttemptParam   := 1709573561 + AttemptIndex * 39437491;
end;

procedure TBattleDeterministicRng.Seed (NewSeed: integer);
begin
  // Ignored
end;

function TBattleDeterministicRng.Random: integer;
begin
  Self.UpdateState(Low(result), High(result));
  result := Crypto.FastHash(@Self.fState, sizeof(Self.fState));
end;

function TBattleDeterministicRng.RandomRange (MinValue, MaxValue: integer): integer;
const
  MAX_UNBIAS_ATTEMPTS = 100;

var
  RangeLen:         cardinal;
  BiasedRangeLen:   cardinal;
  MaxUnbiasedValue: cardinal;
  i:                integer;

begin
  if MinValue >= MaxValue then begin
    result := MinValue;
    exit;
  end;

  Self.UpdateState(MinValue, MaxValue);
  result := Crypto.FastHash(@Self.fState, sizeof(Self.fState));

  if (MinValue > Low(integer)) or (MaxValue < High(integer)) then begin
    i                := 2;
    RangeLen         := cardinal(MaxValue - MinValue) + 1;
    BiasedRangeLen   := High(cardinal) mod RangeLen + 1;

    if BiasedRangeLen = RangeLen then begin
      BiasedRangeLen := 0;
    end;

    MaxUnbiasedValue := High(cardinal) - BiasedRangeLen;

    while (cardinal(result) > MaxUnbiasedValue) and (i <= MAX_UNBIAS_ATTEMPTS) do begin
      Inc(Self.fState.fAttemptParam, 39437491);
      result := Crypto.FastHash(@Self.fState, sizeof(Self.fState));
      Inc(i);
    end;

    result := MinValue + integer(cardinal(result) mod RangeLen);
  end;
end;

function TBattleDeterministicRng.GetStateSize: integer;
begin
  result := 0;
end;

procedure TBattleDeterministicRng.ReadState (Buf: pointer);
begin
  // Ignored
end;

procedure TBattleDeterministicRng.WriteState (Buf: pointer);
begin
  // Ignored
end;

function Hook_ReadIntIni
(
  Res:          pinteger;
  DefValue:     integer;
  Key:          pchar;
  SectionName:  pchar;
  FileName:     pchar
): integer; cdecl;

var
  Value:  string;

begin
  result  :=  0;

  if
    (not Ini.ReadStrFromIni(Key, SectionName, FileName, Value)) or
    not SysUtils.TryStrToInt(Value, Res^)
  then begin
    Res^  :=  DefValue;
  end;
end; // .function Hook_ReadIntIni

function Hook_ReadStrIni
(
  Res:          pchar;
  MaxResLen:    integer;
  DefValue:     pchar;
  Key:          pchar;
  SectionName:  pchar;
  FileName:     pchar
): integer; cdecl;

var
  Value:  string;

begin
  result  :=  0;

  if
    (not Ini.ReadStrFromIni(Key, SectionName, FileName, Value)) or
    (Length(Value) > MaxResLen)
  then begin
    Value :=  DefValue;
  end;

  if Value <> '' then begin
    Utils.CopyMem(Length(Value) + 1, pointer(Value), Res);
  end else begin
    Res^  :=  #0;
  end;
end; // .function Hook_ReadStrIni

function Hook_WriteStrIni (Value, Key, SectionName, FileName: pchar): integer; cdecl;
begin
  result  :=  0;

  if Ini.WriteStrToIni(Key, Value, SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end;
end;

function Hook_WriteIntIni (Value: integer; Key, SectionName, FileName: pchar): integer; cdecl;
begin
  result := 0;

  if Ini.WriteStrToIni(Key, SysUtils.IntToStr(Value), SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end;
end;

function Hook_ZvsGetWindowWidth (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.ECX     := WndManagerPtr^.ScreenPcx16.Width;
  Context.RetAddr := Ptr($729C5F);
  result          := false;
end;

function Hook_ZvsGetWindowHeight (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EDX     := WndManagerPtr^.ScreenPcx16.Height;
  Context.RetAddr := Ptr($729C72);
  result          := false;
end;

procedure MarkFreshestSavegame;
var
{O} Locator:          Files.TFileLocator;
{O} FileInfo:         Files.TFileItemInfo;
    FileName:         string;
    FreshestTime:     INT64;
    FreshestFileName: string;

begin
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  FreshestFileName  :=  #0;
  FreshestTime      :=  0;

  Locator.DirPath   :=  'Games';
  Locator.InitSearch('*.*');

  while Locator.NotEnd do begin
    FileName  :=  Locator.GetNextItem(CFiles.TItemInfo(FileInfo));

    if
      ((FileInfo.Data.dwFileAttributes and Windows.FILE_ATTRIBUTE_DIRECTORY) = 0) and
      (INT64(FileInfo.Data.ftLastWriteTime) > FreshestTime)
    then begin
      FreshestFileName  :=  FileName;
      FreshestTime      :=  INT64(FileInfo.Data.ftLastWriteTime);
    end;
    SysUtils.FreeAndNil(FileInfo);
  end; // .while

  Locator.FinitSearch;

  Utils.CopyMem(Length(FreshestFileName) + 1, pointer(FreshestFileName), Heroes.MarkedSavegame);
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .procedure MarkFreshestSavegame

function Hook_SetHotseatHeroName (Context: ApiJack.PHookContext): longbool; stdcall;
var
  PlayerName:    string;
  NewPlayerName: string;
  EcxReg:        integer;

begin
  PlayerName    := pchar(Context.EAX);
  NewPlayerName := PlayerName + ' 1';
  EcxReg        := Context.ECX;

  asm
    MOV ECX, EcxReg
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end;

  NewPlayerName := PlayerName + ' 2';
  EcxReg        := Context.EBX;

  asm
    MOV ECX, EcxReg
    MOV ECX, [ECX + $54]
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end;

  Context.RetAddr := Ptr($5125B6);
  result          := false;
end;

function Hook_PeekMessageA (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Inc(CpuPatchCounter, CpuTargetLevel);

  if CpuPatchCounter >= 100 then begin
    Dec(CpuPatchCounter, 100);
  end else begin
    Windows.WaitForSingleObject(hTimerEvent, 1);
  end;

  result := true;
end;

function New_Zvslib_GetPrivateProfileStringA
(
  Section:  pchar;
  Key:      pchar;
  DefValue: pchar;
  Buf:      pchar;
  BufSize:  integer;
  FileName: pchar
): integer; stdcall;

var
  Res:  string;

begin
  Res :=  '';

  if not Ini.ReadStrFromIni(Key, Section, FileName, Res) then begin
    Res :=  DefValue;
  end;

  if BufSize <= Length(Res) then begin
    SetLength(Res, BufSize - 1);
  end;

  Utils.CopyMem(Length(Res) + 1, pchar(Res), Buf);

  result :=  Length(Res) + 1;
end; // .function New_Zvslib_GetPrivateProfileStringA

procedure ReadGameSettings;
var
  GameSettingsFilePath: string;

  function ReadValue (const Key: string; const DefVal: string = ''): string;
  begin
    if Ini.ReadStrFromIni(Key, EraSettings.GAME_SETTINGS_SECTION, GameSettingsFilePath, result) then begin
      result := SysUtils.Trim(result);
    end else begin
      result := DefVal;
    end;
  end;

  procedure ReadInt (const Key: string; Res: pinteger);
  var
    Value: integer;

  begin
    if SysUtils.TryStrToInt(ReadValue(Key, '0'), Value) then begin
      Res^ := Value;
    end else begin
      Res^ := 0;
    end;
  end;

  procedure ReadStr (const Key: string; Res: pchar);
  var
    StrValue: string;

  begin
    StrValue := ReadValue(Key, '');
    Utils.CopyMem(Length(StrValue) + 1, pchar(StrValue), Res);
  end;

const
  UNIQUE_ID_LEN   = 3;
  UNIQUE_ID_MASK  = $FFF;

var
  RandomValue:  integer;
  RandomStr:    string;
  i:            integer;

begin
  asm
    MOV EAX, Heroes.LOAD_DEF_SETTINGS
    CALL EAX
  end;

  GameSettingsFilePath := GameExt.GameDir + '\' + EraSettings.GAME_SETTINGS_FILE;

  ReadInt('Show Intro',             Heroes.SHOW_INTRO_OPT);
  ReadInt('Music Volume',           Heroes.MUSIC_VOLUME_OPT);
  ReadInt('Sound Volume',           Heroes.SOUND_VOLUME_OPT);
  ReadInt('Last Music Volume',      Heroes.LAST_MUSIC_VOLUME_OPT);
  ReadInt('Last Sound Volume',      Heroes.LAST_SOUND_VOLUME_OPT);
  ReadInt('Walk Speed',             Heroes.WALK_SPEED_OPT);
  ReadInt('Computer Walk Speed',    Heroes.COMP_WALK_SPEED_OPT);
  ReadInt('Show Route',             Heroes.SHOW_ROUTE_OPT);
  ReadInt('Move Reminder',          Heroes.MOVE_REMINDER_OPT);
  ReadInt('Quick Combat',           Heroes.QUICK_COMBAT_OPT);
  ReadInt('Video Subtitles',        Heroes.VIDEO_SUBTITLES_OPT);
  ReadInt('Town Outlines',          Heroes.TOWN_OUTLINES_OPT);
  ReadInt('Animate SpellBook',      Heroes.ANIMATE_SPELLBOOK_OPT);
  ReadInt('Window Scroll Speed',    Heroes.WINDOW_SCROLL_SPEED_OPT);
  ReadInt('Bink Video',             Heroes.BINK_VIDEO_OPT);
  ReadInt('Blackout Computer',      Heroes.BLACKOUT_COMPUTER_OPT);
  ReadInt('First Time',             Heroes.FIRST_TIME_OPT);
  ReadInt('Test Decomp',            Heroes.TEST_DECOMP_OPT);
  ReadInt('Test Read',              Heroes.TEST_READ_OPT);
  ReadInt('Test Blit',              Heroes.TEST_BLIT_OPT);
  ReadStr('Unique System ID',       Heroes.UNIQUE_SYSTEM_ID_OPT);

  if Heroes.UNIQUE_SYSTEM_ID_OPT^ = #0 then begin
    Randomize;
    RandomValue := (integer(Windows.GetTickCount) + Random(MAXLONGINT)) and UNIQUE_ID_MASK;
    SetLength(RandomStr, UNIQUE_ID_LEN);

    for i:=1 to UNIQUE_ID_LEN do begin
      RandomStr[i] := Upcase(StrLib.ByteToHexChar(RandomValue and $F));
      RandomValue  := RandomValue shr 4;
    end;

    Utils.CopyMem(Length(RandomStr) + 1, pointer(RandomStr), Heroes.UNIQUE_SYSTEM_ID_OPT);

    Ini.WriteStrToIni
    (
      'Unique System ID',
      RandomStr,
      EraSettings.GAME_SETTINGS_SECTION,
      EraSettings.GAME_SETTINGS_FILE
    );

    Ini.SaveIni(EraSettings.GAME_SETTINGS_FILE);
  end; // .if

  ReadStr('Network default Name',   Heroes.NETWORK_DEF_NAME_OPT);
  ReadInt('Autosave',               Heroes.AUTOSAVE_OPT);
  ReadInt('Show Combat Grid',       Heroes.SHOW_COMBAT_GRID_OPT);
  ReadInt('Show Combat Mouse Hex',  Heroes.SHOW_COMBAT_MOUSE_HEX_OPT);
  ReadInt('Combat Shade Level',     Heroes.COMBAT_SHADE_LEVEL_OPT);
  ReadInt('Combat Army Info Level', Heroes.COMBAT_ARMY_INFO_LEVEL_OPT);
  ReadInt('Combat Auto Creatures',  Heroes.COMBAT_AUTO_CREATURES_OPT);
  ReadInt('Combat Auto Spells',     Heroes.COMBAT_AUTO_SPELLS_OPT);
  ReadInt('Combat Catapult',        Heroes.COMBAT_CATAPULT_OPT);
  ReadInt('Combat Ballista',        Heroes.COMBAT_BALLISTA_OPT);
  ReadInt('Combat First Aid Tent',  Heroes.COMBAT_FIRST_AID_TENT_OPT);
  ReadInt('Combat Speed',           Heroes.COMBAT_SPEED_OPT);
  ReadInt('Main Game Show Menu',    Heroes.MAIN_GAME_SHOW_MENU_OPT);
  ReadInt('Main Game X',            Heroes.MAIN_GAME_X_OPT);
  ReadInt('Main Game Y',            Heroes.MAIN_GAME_Y_OPT);
  ReadInt('Main Game Full Screen',  Heroes.MAIN_GAME_FULL_SCREEN_OPT);
  ReadStr('AppPath',                Heroes.APP_PATH_OPT);
  ReadStr('CDDrive',                Heroes.CD_DRIVE_OPT);
end; // .procedure ReadGameSettings

procedure WriteGameSettings;
  procedure WriteInt (const Key: string; Value: pinteger);
  begin
    Ini.WriteStrToIni
    (
      Key,
      SysUtils.IntToStr(Value^),
      EraSettings.GAME_SETTINGS_SECTION,
      EraSettings.GAME_SETTINGS_FILE
    );
  end;

  procedure WriteStr (const Key: string; Value: pchar);
  begin
    Ini.WriteStrToIni
    (
      Key,
      Value,
      EraSettings.GAME_SETTINGS_SECTION,
      EraSettings.GAME_SETTINGS_FILE
    );
  end;

begin
  WriteInt('Show Intro',             Heroes.SHOW_INTRO_OPT);
  WriteInt('Music Volume',           Heroes.MUSIC_VOLUME_OPT);
  WriteInt('Sound Volume',           Heroes.SOUND_VOLUME_OPT);
  WriteInt('Last Music Volume',      Heroes.LAST_MUSIC_VOLUME_OPT);
  WriteInt('Last Sound Volume',      Heroes.LAST_SOUND_VOLUME_OPT);
  WriteInt('Walk Speed',             Heroes.WALK_SPEED_OPT);
  WriteInt('Computer Walk Speed',    Heroes.COMP_WALK_SPEED_OPT);
  WriteInt('Show Route',             Heroes.SHOW_ROUTE_OPT);
  WriteInt('Move Reminder',          Heroes.MOVE_REMINDER_OPT);
  WriteInt('Quick Combat',           Heroes.QUICK_COMBAT_OPT);
  WriteInt('Video Subtitles',        Heroes.VIDEO_SUBTITLES_OPT);
  WriteInt('Town Outlines',          Heroes.TOWN_OUTLINES_OPT);
  WriteInt('Animate SpellBook',      Heroes.ANIMATE_SPELLBOOK_OPT);
  WriteInt('Window Scroll Speed',    Heroes.WINDOW_SCROLL_SPEED_OPT);
  WriteInt('Bink Video',             Heroes.BINK_VIDEO_OPT);
  WriteInt('Blackout Computer',      Heroes.BLACKOUT_COMPUTER_OPT);
  WriteInt('First Time',             Heroes.FIRST_TIME_OPT);
  WriteInt('Test Decomp',            Heroes.TEST_DECOMP_OPT);
  WriteInt('Test Write',             Heroes.TEST_READ_OPT);
  WriteInt('Test Blit',              Heroes.TEST_BLIT_OPT);
  WriteStr('Unique System ID',       Heroes.UNIQUE_SYSTEM_ID_OPT);
  WriteStr('Network default Name',   Heroes.NETWORK_DEF_NAME_OPT);
  WriteInt('Autosave',               Heroes.AUTOSAVE_OPT);
  WriteInt('Show Combat Grid',       Heroes.SHOW_COMBAT_GRID_OPT);
  WriteInt('Show Combat Mouse Hex',  Heroes.SHOW_COMBAT_MOUSE_HEX_OPT);
  WriteInt('Combat Shade Level',     Heroes.COMBAT_SHADE_LEVEL_OPT);
  WriteInt('Combat Army Info Level', Heroes.COMBAT_ARMY_INFO_LEVEL_OPT);
  WriteInt('Combat Auto Creatures',  Heroes.COMBAT_AUTO_CREATURES_OPT);
  WriteInt('Combat Auto Spells',     Heroes.COMBAT_AUTO_SPELLS_OPT);
  WriteInt('Combat Catapult',        Heroes.COMBAT_CATAPULT_OPT);
  WriteInt('Combat Ballista',        Heroes.COMBAT_BALLISTA_OPT);
  WriteInt('Combat First Aid Tent',  Heroes.COMBAT_FIRST_AID_TENT_OPT);
  WriteInt('Combat Speed',           Heroes.COMBAT_SPEED_OPT);
  WriteInt('Main Game Show Menu',    Heroes.MAIN_GAME_SHOW_MENU_OPT);
  WriteInt('Main Game X',            Heroes.MAIN_GAME_X_OPT);
  WriteInt('Main Game Y',            Heroes.MAIN_GAME_Y_OPT);
  WriteInt('Main Game Full Screen',  Heroes.MAIN_GAME_FULL_SCREEN_OPT);
  WriteStr('AppPath',                Heroes.APP_PATH_OPT);
  WriteStr('CDDrive',                Heroes.CD_DRIVE_OPT);

  Ini.SaveIni(EraSettings.GAME_SETTINGS_FILE);
end; // .procedure WriteGameSettings

function Ip4ToStr (ip: integer): string;
begin
  result := SysUtils.Format('%d.%d.%d.%d', [ip and $FF, (ip shr 8) and $FF, (ip shr 16) and $FF, (ip shr 24) and $FF]);
end;

function Hook_GetHostByName (OrigFunc: pointer; Name: pchar): WinSock.PHostEnt; stdcall;
type
  PEndlessPIntArr = ^TEndlessPIntArr;
  TEndlessPIntArr = array [0..MAXLONGINT div 4 - 1] of pinteger;
  TInt32          = packed array [0..3] of byte;

var
{On} AddrList:        {U} TStrList {of TObject};
{U}  Addrs:           PEndlessPIntArr;
     SelectedAddrInd: integer;
     AddrStr:         string;
     i:               integer;

begin
  AddrList := nil;
  // * * * * * //
  result := Ptr(PatchApi.Call(PatchApi.STDCALL_, OrigFunc, [Name]));

  if (result = nil) or ((Name <> nil) and (Name <> ComputerName)) or (result.h_length <> sizeof(integer)) then begin
    exit;
  end;

  Addrs := pointer(result.h_addr_list);

  if (Addrs[0] = nil) or (Addrs[1] = nil) then begin
    exit;
  end;

  {!} Windows.EnterCriticalSection(InetCriticalSection);

  if (not IsSelectingPcIp) and (Addrs[0] <> nil) then begin
    IsSelectingPcIp := true;
    AddrList        := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
    i               := 0;
    SelectedAddrInd := -1;

    while (SelectedAddrInd = -1) and (Addrs[i] <> nil) do begin
      if (Addrs[i]^ = LastUsedPcIp) then begin
        SelectedAddrInd := i;
      end else begin
        AddrStr := Ip4ToStr(Addrs[i]^);

        if (AutoSelectPcIpMaskOpt <> '') and StrLib.Match(AddrStr, AutoSelectPcIpMaskOpt) then begin
          SelectedAddrInd := i;
        end else if i < WogDialogs.MAX_OPTIONS_DLG_ITEMS then begin
          AddrList.Add(AddrStr);
        end;
      end;

      Inc(i);
    end;

    if SelectedAddrInd = -1 then begin
      SelectedAddrInd := WogDialogs.ShowRadioDlg(Trans.tr('era.select_ip_address', []) + ':', AddrList.GetKeys);
    end;

    LastUsedPcIp := Addrs[SelectedAddrInd]^;
    Utils.Exchange(Addrs[0]^, Addrs[SelectedAddrInd]^);

    IsSelectingPcIp := false;
  end; // .if

  {!} Windows.LeaveCriticalSection(InetCriticalSection);
  // * * * * * //
  SysUtils.FreeAndNil(AddrList);
end; // .function Hook_GetHostByName

function Hook_ApplyDamage_Ebx (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EBX := ZvsAppliedDamage^;
  result      := true;
end;

function Hook_ApplyDamage_Esi (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.ESI := ZvsAppliedDamage^;
  result      := true;
end;

function Hook_ApplyDamage_Esi_Arg1 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.ESI                 := ZvsAppliedDamage^;
  pinteger(Context.EBP + $8)^ := ZvsAppliedDamage^;
  result                      := true;
end;

function Hook_ApplyDamage_Arg1 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP + $8)^ :=  ZvsAppliedDamage^;
  result                      :=  true;
end;

function Hook_ApplyDamage_Ebx_Local7 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EBX                    := ZvsAppliedDamage^;
  pinteger(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := true;
end;

function Hook_ApplyDamage_Local7 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := true;
end;

function Hook_ApplyDamage_Local4 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 4 * 4)^ := ZvsAppliedDamage^;
  result                         := true;
end;

function Hook_ApplyDamage_Local8 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 8 * 4)^ := ZvsAppliedDamage^;
  result                         := true;
end;

function Hook_ApplyDamage_Local13 (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 13 * 4)^ := ZvsAppliedDamage^;
  result                          := true;
end;

function Hook_GetWoGAndErmVersions (Context: ApiJack.PHookContext): longbool; stdcall;
const
  NEW_WOG_VERSION = 400;

begin
  pinteger(Context.EBP - $0C)^ := NEW_WOG_VERSION;
  pinteger(Context.EBP - $24)^ := GameExt.ERA_VERSION_INT;
  Context.RetAddr              := Ptr($73227A);
  result                       := false;
end;

function Hook_ZvsLib_ExtractDef (Context: ApiJack.PHookContext): longbool; stdcall;
const
  MIN_NUM_TOKENS = 2;
  TOKEN_LODNAME  = 0;
  TOKEN_DEFNAME  = 1;

  EBP_ARG_IMAGE_TEMPLATE = 16;

var
  ImageSettings: string;
  Tokens:        StrLib.TArrayOfStr;
  LodName:       string;

begin
  ImageSettings := PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^;
  Tokens        := StrLib.Explode(ImageSettings, ';');

  if
    (Length(Tokens) >= MIN_NUM_TOKENS)  and
    (FindFileLod(Tokens[TOKEN_DEFNAME], LodName))
  then begin
    Tokens[TOKEN_LODNAME] := SysUtils.ExtractFileName(LodName);
    ZvsLibImageTemplate   := StrLib.Join(Tokens, ';');
    PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^ :=  pchar(ZvsLibImageTemplate);
  end;

  //fatalerror(PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^);

  result  :=  true;
end; // .function Hook_ZvsLib_ExtractDef

function Hook_ZvsLib_ExtractDef_GetGamePath (Context: ApiJack.PHookContext): longbool; stdcall;
const
  EBP_LOCAL_GAME_PATH = 16;

begin
  ZvsLibGamePath  := SysUtils.ExtractFileDir(ParamStr(0));
  {!} Assert(Length(ZvsLibGamePath) > 0);
  // Increase string ref count for C++ Builder AnsiString
  Inc(pinteger(Utils.PtrOfs(pointer(ZvsLibGamePath), -8))^);

  PPCHAR(Context.EBP - EBP_LOCAL_GAME_PATH)^ :=  pchar(ZvsLibGamePath);
  Context.RetAddr := Utils.PtrOfs(Context.RetAddr, 486);
  result          := false;
end;

function Hook_ZvsPlaceMapObject (Hook: PatchApi.THiHook; x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain: integer): integer; stdcall;
var
  Params: packed array [0..7] of integer;

begin
  if IsLocalPlaceObject then begin
    Params[0] := x;
    Params[1] := y;
    Params[2] := Level;
    Params[3] := ObjType;
    Params[4] := ObjSubtype;
    Params[5] := ObjType2;
    Params[6] := ObjSubtype2;
    Params[7] := Terrain;

    FireRemoteEvent(Network.DEST_ALL_PLAYERS, 'OnRemoteCreateAdvMapObject', @Params, sizeof(Params));
  end;

  result := PatchApi.Call(PatchApi.CDECL_, Hook.GetOriginalFunc(), [x, y, Level, ObjType, ObjSubtype, ObjType2, ObjSubtype2, Terrain]);
end;

procedure OnRemoteCreateAdvMapObject (Event: GameExt.PEvent); stdcall;
type
  TParams = packed array [0..7] of integer;
  PParams = ^TParams;

var
  Params: PParams;

begin
  Params             := Event.Data;
  IsLocalPlaceObject := false;
  Erm.ZvsPlaceMapObject(Params[0], Params[1], Params[2], Params[3], Params[4], Params[5], Params[6], Params[7]);
  IsLocalPlaceObject := true;
end;

function Hook_ZvsEnter2Monster (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ARG_MAP_ITEM  = 8;
  ARG_MIXED_POS = 16;

var
  x, y, z:  integer;
  MixedPos: integer;
  MapItem:  pointer;

begin
  MapItem  := ppointer(Context.EBP + ARG_MAP_ITEM)^;
  MapItemToCoords(MapItem, x, y, z);
  MixedPos := CoordsToMixedPos(x, y, z);
  pinteger(Context.EBP + ARG_MIXED_POS)^ := MixedPos;

  Context.RetAddr := Ptr($7577B2);
  result          := false;
end;

function Hook_ZvsEnter2Monster2 (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ARG_MAP_ITEM  = 8;
  ARG_MIXED_POS = 16;

var
  x, y, z:  integer;
  MixedPos: integer;
  MapItem:  pointer;

begin
  MapItem  := ppointer(Context.EBP + ARG_MAP_ITEM)^;
  MapItemToCoords(MapItem, x, y, z);
  MixedPos := CoordsToMixedPos(x, y, z);
  pinteger(Context.EBP + ARG_MIXED_POS)^ := MixedPos;

  Context.RetAddr := Ptr($757A87);
  result          := false;
end;

function Hook_WoGMouseClick3 (OrigFunc: pointer; AdvMan: pointer; MouseEvent: Heroes.PMouseEventInfo; Arg3: integer; Arg4: integer): integer; stdcall;
const
  ITEM_CHAT       = 38;
  VANILLA_HANDLER = $409740;

begin
  // Bug fix: chat typing produces phantom mouse click event
  if (MouseEvent.Item = ITEM_CHAT) and (MouseEvent.X = 0) and (MouseEvent.Y = 0) then begin
    result := PatchApi.Call(THISCALL_, Ptr(VANILLA_HANDLER), [AdvMan, MouseEvent, Arg3, Arg4]);
  end else begin
    ZvsMouseClickEventInfo^ := MouseEvent;
    ZvsHandleAdvMapMouseClick(ord(true));

    if ZvsAllowDefMouseReaction^ then begin
      result := PatchApi.Call(THISCALL_, Ptr(VANILLA_HANDLER), [AdvMan, MouseEvent, Arg3, Arg4]);
    end else begin
      result := 1;
    end;
  end;
end;

function Hook_StartBattle (OrigFunc: pointer; WndMan: Heroes.PWndManager; PackedCoords: integer; AttackerHero: Heroes.PHero; AttackerArmy: Heroes.PArmy; DefenderPlayerId: integer;
                           DefenderTown: Heroes.PTown; DefenderHero: Heroes.PHero; DefenderArmy: Heroes.PArmy; Seed, Unk10: integer; IsBank: boolean): integer; stdcall;

const
  DEFAULT_COMBAT_ID = -1359960668;

var
  AttackerPlayerId: integer;

begin
  HadTacticsPhase := false;
  CombatRound     := FIRST_TACTICS_ROUND;
  CombatActionId  := 0;
  GlobalRng       := QualitativeRng;

  AttackerPlayerId := Heroes.PLAYER_NONE;

  if AttackerHero <> nil then begin
    AttackerPlayerId := AttackerHero.Owner;
  end;

  if Heroes.IsNetworkGame                       and
     Heroes.IsValidPlayerId(AttackerPlayerId)   and
     Heroes.IsValidPlayerId(DefenderPlayerId)   and
     Heroes.GetPlayer(AttackerPlayerId).IsHuman and
     Heroes.GetPlayer(DefenderPlayerId).IsHuman
  then begin
    GlobalRng := BattleDeterministicRng;

    // If we are network defender, the attacker already sent CombatId to us. Otherwise we should generate it and send later
    if not Heroes.GetPlayer(DefenderPlayerId).IsThisPcHumanPlayer then begin
      CombatId := Erm.UniqueRng.Random;
    end;
  end else begin
    CombatId := DEFAULT_COMBAT_ID;
  end;

  result    := PatchApi.Call(THISCALL_, OrigFunc, [WndMan, PackedCoords, AttackerHero, AttackerArmy, DefenderPlayerId, DefenderTown, DefenderHero, DefenderArmy, Seed, Unk10, IsBank]);
  GlobalRng := QualitativeRng;
end; // .function Hook_StartBattle

function Hook_WoGBeforeBattleAction (Context: ApiJack.PHookContext): longbool; stdcall;
var
  BattleMgr: Heroes.PCombatManager;

begin
  Inc(CombatActionId);

  BattleMgr := Heroes.CombatManagerPtr^;

  CombatOrigStackActionInfo.Action       := BattleMgr.Action;
  CombatOrigStackActionInfo.Spell        := BattleMgr.Spell;
  CombatOrigStackActionInfo.TargetPos    := BattleMgr.TargetPos;
  CombatOrigStackActionInfo.ActionParam2 := BattleMgr.ActionParam2;

  result := true;
end;

function Hook_WoGBeforeBattleAction_HandleEnchantress (Context: ApiJack.PHookContext): longbool; stdcall;
const
  LOCAL_ACTING_MON_TYPE = -$2C;

var
  BattleMgr: Heroes.PCombatManager;

begin
  BattleMgr  := Heroes.CombatManagerPtr^;
  Erm.v[997] := CombatRound;
  Erm.FireErmEvent(TRIGGER_BG0);

  // Monster type could be changed by script, use the one from combat manager
  pinteger(Context.EBP + LOCAL_ACTING_MON_TYPE)^ := BattleMgr.GetActiveStack().MonType;

  result := true;
end;

function Hook_WoGCallAfterBattleAction (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.v[997] := CombatRound;
  Erm.FireErmEvent(TRIGGER_BG1);

  Context.RetAddr := Ptr($75D317);
  result          := false;
end;

function Hook_SendBattleAction_CopyActionParams (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EAX := CombatOrigStackActionInfo.ActionParam2;
  Context.ECX := CombatOrigStackActionInfo.TargetPos;
  Context.EDX := CombatOrigStackActionInfo.Spell;
  Context.EBX := CombatOrigStackActionInfo.Action;

  result := true;
end;

function Hook_OnBeforeBattlefieldVisible (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_ONBEFORE_BATTLEFIELD_VISIBLE);
  result := true;
end;

function Hook_OnBattlefieldVisible (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  HadTacticsPhase := Heroes.CombatManagerPtr^.IsTactics;

  if not HadTacticsPhase then begin
    CombatRound        := 0;
    pinteger($79F0B8)^ := 0;
    pinteger($79F0BC)^ := 0;
  end;

  Erm.FireErmEvent(Erm.TRIGGER_BATTLEFIELD_VISIBLE);
  Erm.v[997] := CombatRound;
  Erm.FireErmEventEx(Erm.TRIGGER_BR, [CombatRound]);

  result := true;
end;

function Hook_OnAfterTacticsPhase (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_AFTER_TACTICS_PHASE);

  if HadTacticsPhase then begin
    CombatRound := 0;
    Erm.v[997]  := CombatRound;
    Erm.FireErmEvent(Erm.TRIGGER_BR);
  end;

  result := true;
end;

function Hook_OnCombatRound_Start (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  if pinteger($79F0B8)^ <> Heroes.CombatManagerPtr^.Round then begin
    Inc(CombatRound);
  end;

  result := true;
end;

function Hook_OnCombatRound_End (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.v[997] := CombatRound;
  Erm.FireErmEvent(Erm.TRIGGER_BR);
  result := true;
end;

var
  RngId: integer = 0; // Holds random generation attempt ID, auto resets at each reseeding. Used for debugging purposes

procedure Hook_SRand (OrigFunc: pointer; Seed: integer); stdcall;
type
  TSRandFunc = procedure (Seed: integer); cdecl;

var
  CallerAddr: pointer;
  Message:    string;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  GlobalRng.Seed(Seed);

  if DebugRng <> DEBUG_RNG_NONE then begin
    Message := SysUtils.Format('SRand %d from %.8x', [Seed, integer(CallerAddr)]);
    Log.Write('RNG', '', Message);
  end;

  if (DebugRng <> DEBUG_RNG_NONE) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Writeln(Message);
    Heroes.PrintChatMsg('{~ffffff}' + Message);
  end;

  RngId := 0;
end;

procedure Hook_Tracking_SRand (OrigFunc: pointer; Seed: integer); stdcall;
type
  TSRandFunc = procedure (Seed: integer); cdecl;

var
  CallerAddr: pointer;
  Message:    string;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  GlobalRng.Seed(Seed);
  NativeRngSeed^ := Seed;

  if DebugRng <> DEBUG_RNG_NONE then begin
    Message := SysUtils.Format('SRand %d from %.8x', [Seed, integer(CallerAddr)]);
    Log.Write('RNG', '', Message);
  end;

  if (DebugRng <> DEBUG_RNG_NONE) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Writeln(Message);
    Heroes.PrintChatMsg('{~ffffff}' + Message);
  end;

  RngId := 0;
end;

function Hook_Rand (OrigFunc: pointer): integer; stdcall;
type
  TRandFunc = function (): integer;

var
  CallerAddr: pointer;
  Message:    string;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  result := GlobalRng.Random and $7FFF;

  if DebugRng = DEBUG_RNG_ALL then begin
    if GlobalRng = BattleDeterministicRng then begin
      Message := SysUtils.Format('brng rand #%d from %.8x, B%d R%d A%d = %d', [RngId, integer(CallerAddr), CombatId, CombatRound, CombatActionId, result]);
    end else begin
      Message := 'qrng ';

      if GlobalRng = CLangRng then begin
        Message := 'crng ';
      end;

      Message := Message + SysUtils.Format('rand #%d from %.8x = %d', [RngId, integer(CallerAddr), result]);
    end;

    Log.Write('RNG', '', Message);
  end;

  if (DebugRng = DEBUG_RNG_ALL) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Writeln(Message);
    PrintChatMsg('{~ffffff}' + Message);
  end;

  Inc(RngId);
end;

procedure DebugRandomRange (CallerAddr: pointer; MinValue, MaxValue, ResValue: integer);
var
  Message: string;

begin
  if DebugRng >= DEBUG_RNG_RANGE then begin
    if GlobalRng = BattleDeterministicRng then begin
      Message := SysUtils.Format('brng rand #%d from %.8x, B%d  R%d A%d F%d: %d..%d = %d', [
        RngId, integer(CallerAddr), CombatId, CombatRound, CombatActionId, CombatRngFreeParam, MinValue, MaxValue, ResValue
      ]);
    end else begin
      Message := 'qrng ';

      if GlobalRng = CLangRng then begin
        Message := 'crng ';
      end;

      Message := Message + SysUtils.Format('rand #%d from %.8x: %d..%d = %d', [RngId, integer(CallerAddr), MinValue, MaxValue, ResValue]);
    end;

    Log.Write('RNG', '', Message);
  end;

  if (DebugRng = DEBUG_RNG_ALL) and (Heroes.WndManagerPtr^ <> nil) and (Heroes.WndManagerPtr^.RootDlg <> nil) then begin
    Writeln(Message);
    PrintChatMsg('{~ffffff}' + Message);
  end;

  Inc(RngId);
end;

function _RandomRangeWithFreeParam (CallerAddr: pointer; MinValue, MaxValue, FreeParam: integer): integer;
begin
  CombatRngFreeParam := FreeParam;
  result             := GlobalRng.RandomRange(MinValue, MaxValue);
  DebugRandomRange(CallerAddr, MinValue, MaxValue, result);
  CombatRngFreeParam := 0;
end;

function RandomRangeWithFreeParam (MinValue, MaxValue, FreeParam: integer): integer; stdcall;
var
  CallerAddr: pointer;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
  end;

  result := _RandomRangeWithFreeParam(CallerAddr, MinValue, MaxValue, FreeParam);
end;

function Hook_RandomRange (OrigFunc: pointer; MinValue, MaxValue: integer): integer; stdcall;
type
  PCallerContext = ^TCallerContext;
  TCallerContext = packed record EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer; end;

const
  CALLER_CONTEXT_SIZE = sizeof(TCallerContext);

var
  CallerAddr: pointer;
  Context:    PCallerContext;
  CallerEbp:  integer;
  FreeParam:  integer;

begin
  asm
    mov eax, [ebp + 4]
    mov CallerAddr, eax
    pushad
    mov [Context], esp
  end;

  CallerEbp := pinteger(Context.EBP)^;
  FreeParam := 0;

  case integer(CallerAddr) of
    // Battle stack damage generation
    $442FEE, $443029: FreeParam := pinteger(CallerEbp + $8)^;
    // Bad morale
    $4647AC, $4647D5: FreeParam := StackPtrToId(Ptr(Context.EDI));
    // Magic resistence
    $5A65A3, $5A4D85, $5A061B, $5A1017, $5A1214: FreeParam := StackPtrToId(Ptr(Context.EDI));
    $5A4F5F:                                     FreeParam := StackPtrToId(Ptr(Context.ESI));
    $5A2105:                                     FreeParam := StackPtrToId(ppointer(CallerEbp + $14)^);
  end;

  result := _RandomRangeWithFreeParam(CallerAddr, MinValue, MaxValue, FreeParam);

  asm
    add esp, CALLER_CONTEXT_SIZE
  end;
end; // .function Hook_RandomRange


// ============================ NETWORK BATTLE SEQUENTIAL PRNG GENERATIONS FIX ============================ //
(*
  Ready-to use replacements for native code, using PRNG sequentially in combats (spell resistence, death stare, phoenixes, etc).
  Sequential calls from the same address produce different results even in network PvP battles. Free parameter is used for this purpose.
*)

const
  SEQ_RAND_UNIQUE_MASK = integer(-696336428);

var
  SequentialRandCurrCaller: pointer;
  SequentialRandPrevCaller: pointer;
  SequantialRandFreeParam:  integer;

function SequantialRandomRange (MinValue, MaxValue: integer): integer;
begin
  if SequentialRandCurrCaller = SequentialRandPrevCaller then begin
    Inc(SequantialRandFreeParam);
  end else begin
    // впихнуть сюда xor CallerAddr и для обоих сперва вызвать EncodeInt32
    SequantialRandFreeParam  := 0;
    SequentialRandPrevCaller := SequentialRandCurrCaller;
  end;

  result := _RandomRangeWithFreeParam(SequentialRandCurrCaller, MinValue, MaxValue, Crypto.Tm32Encode(SequantialRandFreeParam) xor SEQ_RAND_UNIQUE_MASK);
end;

function SequentialRand: integer;
begin
  asm
    mov eax, [ebp + 4]
    mov SequentialRandCurrCaller, eax
  end;

  result := SequantialRandomRange(0, High(integer));
end;

function SequentialRandomRangeFastcall (_1, MaxValue, MinValue: integer): integer; register;
begin
  asm
    push eax
    mov eax, [ebp + 4]
    mov SequentialRandCurrCaller, eax
    pop eax
  end;

  result := SequantialRandomRange(MinValue, MaxValue);
end;

function SequentialRandomRangeCdecl (MinValue, MaxValue: integer): integer; cdecl;
begin
  asm
    mov eax, [ebp + 4]
    mov SequentialRandCurrCaller, eax
  end;

  result := SequantialRandomRange(MinValue, MaxValue);
end;

// ========================== END NETWORK BATTLE SEQUENTIAL PRNG GENERATIONS FIX ========================== //


function Hook_PlaceBattleObstacles (OrigFunc, BattleMgr: pointer): integer; stdcall;
var
  PrevRng: FastRand.TRng;

begin
  PrevRng   := GlobalRng;
  GlobalRng := CLangRng;

  Heroes.SRand(NativeRngSeed^);

  // Skip one random generation, because random battle music selection is already performed by this moment
  Heroes.RandomRange(0, 7);

  //Erm.FireErmEvent(Erm.TRIGGER_BEFORE_BATTLE_PLACE_BATTLE_OBSTACLES);
  result := PatchApi.Call(THISCALL_, OrigFunc, [BattleMgr]);

  GlobalRng := PrevRng;
  Erm.FireErmEvent(Erm.TRIGGER_AFTER_BATTLE_PLACE_BATTLE_OBSTACLES);
end;

procedure Splice_CombatManager_CastSpell (
  OrigFunc:        pointer;
  CombatMan:       Heroes.PCombatManager;
  SpellId:         integer;
  TargetPos:       integer;
  SpellCasterType: integer;
  SecondaryPos:    integer;
  SkillLevel:      integer;
  SpellPower:      integer
); stdcall;

const
  CASTER_TYPE_HERO     = 0;
  CASTER_TYPE_MONSTER  = 1;
  CASTER_TYPE_ARTIFACT = 2;

var
  ActiveStack:       Heroes.PBattleStack;
  OrigCurrStackSide: integer;
  OrigCurrStackInd:  integer;
  OrigControlSide:   integer;

begin
  OrigCurrStackSide := CombatMan.CurrStackSide;
  OrigCurrStackInd  := CombatMan.CurrStackInd;
  OrigControlSide   := CombatMan.ControlSide;

  if SpellCasterType = CASTER_TYPE_MONSTER then begin
    ActiveStack           := CombatMan.GetActiveStack;
    Writeln(ActiveStack.SpellDurations[SPELL_HYPNOTIZE], ' ', ActiveStack.Side, ' ', ActiveStack.Index, ' ', ActiveStack.MonType);
    CombatMan.ControlSide := ActiveStack.Side xor ord(ActiveStack.SpellDurations[SPELL_HYPNOTIZE] <> 0);
  end;

  PatchApi.Call(THISCALL_, OrigFunc, [CombatMan, SpellId, TargetPos, SpellCasterType, SecondaryPos, SkillLevel, SpellPower]);

  CombatMan.CurrStackSide := OrigCurrStackSide;
  CombatMan.CurrStackInd  := OrigCurrStackInd;
  CombatMan.ControlSide   := OrigControlSide;
end;

function Splice_ZvsQuickSandOrLandMine (OrigFunc: pointer; SpellCasterType, StackId, Pos, Redraw: integer): integer; stdcall;
const
  CASTER_TYPE_HERO     = 0;
  CASTER_TYPE_MONSTER  = 1;
  CASTER_TYPE_ARTIFACT = 2;

type
  TQuickSandOrLandMine = function (SpellCasterType, StackId, Pos, Redraw: integer): integer; cdecl;

var
  CombatMan:   Heroes.PCombatManager;
  OrigStackId: integer;

begin
  CombatMan   := Heroes.CombatManagerPtr^;
  OrigStackId := CombatMan.CurrStackSide * NUM_BATTLE_STACKS_PER_SIDE + CombatMan.CurrStackInd;

  result := TQuickSandOrLandMine(OrigFunc)(SpellCasterType, StackId, Pos, Redraw);

  if (SpellCasterType = CASTER_TYPE_MONSTER) and (OrigStackId <> StackId) then begin
    CombatMan.RedrawGridAndSelection;
  end;
end;

function Hook_ZvsAdd2Send (Context: ApiJack.PHookContext): longbool; stdcall;
const
  BUF_ADDR                = $2846C60;
  DEST_PLAYER_ID_VAR_ADDR = $281187C;
  BUF_POS_VAR             = -$0C;

type
  PWoGBattleSyncBuffer = ^TWoGBattleSyncBuffer;
  TWoGBattleSyncBuffer = array [0..103816 - 1] of byte;

var
  BufPosPtr: pinteger;

begin
  BufPosPtr := Ptr(Context.EBP + BUF_POS_VAR);

  // Write chunk size + chunk bytes, adjust buffer position
  pinteger(BUF_ADDR + BufPosPtr^)^ := sizeof(integer);
  Inc(BufPosPtr^, sizeof(integer));
  pinteger(BUF_ADDR + BufPosPtr^)^ := CombatId;
  Inc(BufPosPtr^, sizeof(integer));

  result := true;
end;

function Hook_ZvsGet4Receive (Context: ApiJack.PHookContext): longbool; stdcall;
const
  BUF_VAR     = +$8;
  BUF_POS_VAR = -$4;

var
  BufAddr:   integer;
  BufPosPtr: pinteger;

begin
  BufPosPtr := Ptr(Context.EBP + BUF_POS_VAR);
  BufAddr   := pinteger(Context.EBP + BUF_VAR)^;

  if pinteger(BufAddr + BufPosPtr^)^ <> sizeof(integer) then begin
    Heroes.ShowMessage('Hook_ZvsGet4Receive: Invalid data received from remote client');
  end else begin
    Inc(BufPosPtr^, sizeof(integer));
    CombatId := pinteger(BufAddr + BufPosPtr^)^;
    Inc(BufPosPtr^, sizeof(integer));
  end;

  result := true;
end;

procedure Hook_ZvsTriggerIp (OrigFunc: pointer; TriggerSubtype: integer); stdcall;
const
  ATTACKER_BEFORE_DATA_SEND = 0;
  DEFENDER_BEFORE_DATA_SEND = 2;

begin
  PatchApi.Call(CDECL_, OrigFunc, [TriggerSubtype]);

  if TriggerSubtype = ATTACKER_BEFORE_DATA_SEND then begin
    EventMan.GetInstance.Fire('$OnBeforeBattleBeforeDataSend');
  end else if TriggerSubtype = DEFENDER_BEFORE_DATA_SEND then begin
    EventMan.GetInstance.Fire('$OnAfterBattleBeforeDataSend');
  end;
end;

procedure OnBeforeBattleUniversal (Event: GameExt.PEvent); stdcall;
begin
  CombatRound    := FIRST_TACTICS_ROUND;
  CombatActionId := 0;
end;

procedure OnBattleReplay (Event: GameExt.PEvent); stdcall;
begin
  OnBeforeBattleUniversal(Event);
  Erm.FireErmEvent(TRIGGER_BATTLE_REPLAY);
end;

procedure OnBeforeBattleReplay (Event: GameExt.PEvent); stdcall;
begin
  Erm.FireErmEvent(TRIGGER_BEFORE_BATTLE_REPLAY);
end;

function Hook_PostBattle_OnAddCreaturesExp (Context: ApiJack.PHookContext): longbool; stdcall;
var
  ExpToAdd: integer;
  FinalExp: integer;

begin
  // EAX: Old experience value
  // EBP - $C: addition
  ExpToAdd := pinteger(Context.EBP - $C)^;

  if ExpToAdd < 0 then begin
    ExpToAdd := High(integer);
  end;

  FinalExp := Math.Max(0, Context.EAX) + ExpToAdd;

  if FinalExp < 0 then begin
    FinalExp := High(integer);
  end;

  ppinteger(Context.EBP - 8)^^ := FinalExp;

  Context.RetAddr := Ptr($71922D);
  result          := false;
end;

function Hook_DisplayComplexDialog_GetTimeout (Context: ApiJack.PHookContext): longbool; stdcall;
var
  Opts:          integer;
  Timeout:       integer;
  MsgType:       integer;
  TextAlignment: integer;
  StrConfig:     integer;

begin
  Opts          := pinteger(Context.EBP + $10)^;
  Timeout       := Opts and $FFFF;
  StrConfig     := (Opts shr 24) and $FF;
  MsgType       := (Opts shr 16) and $0F;
  TextAlignment := ((Opts shr 20) and $0F) - 1;

  if MsgType = 0 then begin
    MsgType := ord(Heroes.MES_MES);
  end;

  if TextAlignment < 0 then begin
    TextAlignment := Heroes.TEXT_ALIGN_CENTER;
  end;

  Erm.SetDialog8TextAlignment(TextAlignment);

  pinteger(Context.EBP - $24)^ := Timeout;
  pinteger(Context.EBP - $2C)^ := MsgType;
  pbyte(Context.EBP - $2C0)^   := StrConfig;
  result                       := true;
end; // .function Hook_DisplayComplexDialog_GetTimeout

function Hook_ShowParsedDlg8Items_CreateTextField (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - 132)^ := GetDialog8TextAlignment();
  result := true;
end;

function Hook_ShowParsedDlg8Items_Init (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  // WoG Native Dialogs uses imported function currently and manually determines selected item
  // Heroes.ComplexDlgResItemId^ := Erm.GetPreselectedDialog8ItemId();
  result := true;
end;

function Hook_ZvsDisplay8Dialog_BeforeShow (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Context.EAX     := DisplayComplexDialog(ppointer(Context.EBP + $8)^, Ptr($8403BC), Heroes.TMesType(pinteger(Context.EBP + $10)^),
                                          pinteger(Context.EBP + $14)^);
  result          := false;
  Context.RetAddr := Ptr($716A04);
end;

const
  PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES = -$C0;

function Hook_ParsePicture_Start (Context: ApiJack.PHookContext): longbool; stdcall;
const
  PIC_TYPE_ARG = +$8;

var
  PicType: integer;

begin
  PicType := pinteger(Context.EBP + PIC_TYPE_ARG)^;

  if PicType <> -1 then begin
    pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ := PicType shr 31;
    pinteger(Context.EBP + PIC_TYPE_ARG)^                           := PicType and not (1 shl 31);
  end else begin
    pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ := 0;
  end;

  (* Not ideal but still solution. Apply runtime patches to allow/disallow displaying of zero quantities *)
  if pinteger(Context.EBP + PARSE_PICTURE_VAR_SHOW_ZERO_QUANTITIES)^ <> 0 then begin
    pbyte($4F55EC)^ := $7C;   // resources
    pbyte($4F5EB3)^ := $EB;   // experience
    pword($4F5BCA)^ := $9090; // monsters
    pbyte($4F5ACC)^ := $EB;   // primary skills
    pbyte($4F5725)^ := $7C;   // money
    pbyte($4F5765)^ := $EB;   // money
  end else begin
    pbyte($4F55EC)^ := $7E;   // resources
    pbyte($4F5EB3)^ := $75;   // experience
    pword($4F5BCA)^ := $7A74; // monsters
    pbyte($4F5ACC)^ := $75;   // primary skills
    pbyte($4F5725)^ := $7E;   // money
    pbyte($4F5765)^ := $75;   // money
  end;

  result := true;
end; // .function Hook_ParsePicture_Start

function Hook_HDlg_BuildPcx (OrigFunc: pointer; x, y, dx, dy, ItemId: integer; PcxFile: pchar; Flags: integer): pointer; stdcall;
const
  DLG_ITEM_STRUCT_SIZE = 52;

var
  FileName:       string;
  FileExt:        string;
  PcxConstructor: pointer;

begin
  FileName       := PcxFile;
  FileExt        := SysUtils.AnsiLowerCase(StrLib.ExtractExt(FileName));
  PcxConstructor := Ptr($44FFA0);

  if FileExt = 'pcx16' then begin
    FileName       := SysUtils.ChangeFileExt(FileName, '') + '.pcx';
    PcxConstructor := Ptr($450340);
  end;

  result := Ptr(PatchApi.Call(THISCALL_, PcxConstructor, [Heroes.MAlloc(DLG_ITEM_STRUCT_SIZE), x, y, dx, dy, ItemId, pchar(FileName), Flags]));
end;

function Hook_HandleMonsterCast_End (Context: ApiJack.PHookContext): longbool; stdcall;
const
  CASTER_MON         = 1;
  NO_EXT_TARGET_POS  = -1;

  FIELD_ACTIVE_SPELL = $4E0;
  FIELD_NUM_MONS     = $4C;
  FIELD_MON_ID       = $34;

  MON_FAERIE_DRAGON   = 134;
  MON_SANTA_GREMLIN   = 173;
  MON_COMMANDER_FIRST = 174;
  MON_COMMANDER_LAST  = 191;

  WOG_GET_NPC_MAGIC_POWER = $76BEEA;

var
  Spell:      integer;
  TargetPos:  integer;
  Stack:      pointer;
  MonId:      integer;
  NumMons:    integer;
  SkillLevel: integer;
  SpellPower: integer;

begin
  TargetPos  := pinteger(Context.EBP + $8)^;
  Stack      := Ptr(Context.ESI);
  MonId      := pinteger(integer(Stack) + FIELD_MON_ID)^;
  Spell      := pinteger(integer(Stack) + FIELD_ACTIVE_SPELL)^;
  NumMons    := pinteger(integer(Stack) + FIELD_NUM_MONS)^;
  SpellPower := NumMons;
  SkillLevel := 2;

  if (TargetPos >= 0) and (TargetPos < 187) then begin
    if MonId = MON_FAERIE_DRAGON then begin
      SpellPower := NumMons * 5;
    end else if MonId = MON_SANTA_GREMLIN then begin
      SkillLevel := 0;
      SpellPower := (NumMons - 1) div 2;

      if (((NumMons - 1) and 1) <> 0) and (ZvsRandom(0, 1) = 1) then begin
        Inc(SpellPower);
      end;
    end else if Math.InRange(MonId, MON_COMMANDER_FIRST, MON_COMMANDER_LAST) then begin
      SpellPower := PatchApi.Call(CDECL_, Ptr(WOG_GET_NPC_MAGIC_POWER), [Stack]);
    end;

    Context.EAX := PatchApi.Call(THISCALL_, Ptr($5A0140), [Heroes.CombatManagerPtr^, Spell, TargetPos, CASTER_MON, NO_EXT_TARGET_POS, SkillLevel, SpellPower]);
  end;

  result          := false;
  Context.RetAddr := Ptr($4483DD);
end; // .function Hook_HandleMonsterCast_End

function Hook_ErmDlgFunctionActionSwitch (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ARG_DLG_ID = 1;

  DLG_MOUSE_EVENT_INFO_VAR = $887654;
  DLG_USER_COMMAND_VAR     = $887658;
  DLG_BODY_VAR             = -$5C;
  DLG_BODY_ID_FIELD        = 200;
  DLG_COMMAND_CLOSE        = 1;
  MOUSE_OK_CLICK           = 10;
  MOUSE_LMB_PRESSED        = 12;
  MOUSE_LMB_RELEASED       = 13;
  MOUSE_RMB_PRESSED        = 14;
  ACTION_KEY_PRESSED       = 20;
  ITEM_INSIDE_DLG          = -1;
  ITEM_OUTSIDE_DLG         = -2;

var
  MouseEventInfo: Heroes.PMouseEventInfo;
  SavedEventX:    integer;
  SavedEventY:    integer;
  SavedEventZ:    integer;
  PrevUserCmd:    integer;

begin
  MouseEventInfo := ppointer(Context.EBP + $8)^;
  result         := false;

  case MouseEventInfo.ActionType of
    Heroes.DLG_ACTION_INDLG_CLICK:  begin end;
    Heroes.DLG_ACTION_SCROLL_WHEEL: begin MouseEventInfo.Item := ITEM_INSIDE_DLG; end;

    Heroes.DLG_ACTION_KEY_PRESSED: begin
      MouseEventInfo.Item := ITEM_INSIDE_DLG;
    end;

    Heroes.DLG_ACTION_OUTDLG_RMB_PRESSED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_RMB_PRESSED;
    end;

    Heroes.DLG_ACTION_OUTDLG_LMB_PRESSED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_LMB_PRESSED;
    end;

    Heroes.DLG_ACTION_OUTDLG_LMB_RELEASED: begin
      MouseEventInfo.Item          := ITEM_OUTSIDE_DLG;
      MouseEventInfo.ActionSubtype := MOUSE_LMB_RELEASED;
    end;
  else
    result := true;
  end; // .switch MouseEventInfo.ActionType

  if result then begin
    exit;
  end;

  ppointer(DLG_MOUSE_EVENT_INFO_VAR)^ := MouseEventInfo;

  SavedEventX := Erm.ZvsEventX^;
  SavedEventY := Erm.ZvsEventY^;
  SavedEventZ := Erm.ZvsEventZ^;
  PrevUserCmd := pinteger(DLG_USER_COMMAND_VAR)^;

  Erm.ArgXVars[ARG_DLG_ID] := pinteger(pinteger(Context.EBP + DLG_BODY_VAR)^ + DLG_BODY_ID_FIELD)^;

  Erm.ZvsEventX^ := Erm.ArgXVars[ARG_DLG_ID];
  Erm.ZvsEventY^ := MouseEventInfo.Item;
  Erm.ZvsEventZ^ := MouseEventInfo.ActionSubtype;

  pinteger(DLG_USER_COMMAND_VAR)^ := 0;
  Erm.FireMouseEvent(Erm.TRIGGER_DL, MouseEventInfo);

  Erm.ZvsEventX^ := SavedEventX;
  Erm.ZvsEventY^ := SavedEventY;
  Erm.ZvsEventZ^ := SavedEventZ;

  Context.EAX := 1;
  ppointer(DLG_MOUSE_EVENT_INFO_VAR)^ := nil;

  if pinteger(DLG_USER_COMMAND_VAR)^ = DLG_COMMAND_CLOSE then begin
    Context.EAX                     := 2;
    MouseEventInfo.ActionType       := Heroes.DLG_ACTION_INDLG_CLICK;
    MouseEventInfo.ActionSubtype    := MOUSE_OK_CLICK;

    // Assign result item
    pinteger(pinteger(Context.EBP - $10)^ + 56)^ := MouseEventInfo.Item;
  end;

  pinteger(DLG_USER_COMMAND_VAR)^ := PrevUserCmd;

  result          := false;
  Context.RetAddr := Ptr($7297C6);
end; // .function Hook_ErmDlgFunctionActionSwitch

const
  SET_DEF_ITEM_FRAME_INDEX_FUNC = $4EB0D0;
  HDLG_BUILD_DEF_FUNC           = $728DA1;
  HDLG_ADD_ITEM_FUNC            = $7287A1;
  HDLG_SET_ANIM_DEF_FUNC        = $7286A0;

type
  PAnimDefDlgItem = ^TAnimDefDlgItem;
  TAnimDefDlgItem = packed record
    _Unk1:    array [1..52] of byte;
    FrameInd: integer; // +0x34
    GroupInd: integer; // +0x38
    // ...
  end;

  PAnimatedDefWrapper = ^TAnimatedDefWrapper;
  TAnimatedDefWrapper = packed record
    ZvsDefFrameInd: integer;
    DefItem:        PAnimDefDlgItem;
  end;

function Hook_DL_D_ItemCreation (Context: ApiJack.PHookContext): longbool; stdcall;
var
  DefItem:  PAnimDefDlgItem;
  GroupInd: integer;
  FrameInd: integer;

begin
  DefItem  := ppointer(Context.EBP - $4)^;
  FrameInd := pinteger(Context.EBP - $44)^;
  GroupInd := 0;

  // DL frame index column is DL_GROUP_INDEX_MARKER * groupIndex + frameIndex
  if FrameInd >= DL_GROUP_INDEX_MARKER then begin
    GroupInd := FrameInd div DL_GROUP_INDEX_MARKER;
    FrameInd := FrameInd mod DL_GROUP_INDEX_MARKER;
  end;

  DefItem.GroupInd := GroupInd;

  PatchApi.Call(THISCALL_, Ptr(SET_DEF_ITEM_FRAME_INDEX_FUNC), [DefItem, FrameInd]);

  // Animated defs must contain 'animated' substring in name
  if System.Pos('animated', ppchar(Context.EBP - $74)^) <> 0 then begin
    PatchApi.Call(THISCALL_, Ptr(HDLG_SET_ANIM_DEF_FUNC), [pinteger(Context.EBP - $78)^, DefItem]);
  end;

  result := true;
end; // .function Hook_DL_D_ItemCreation

function Hook_ErmDlgFunction_HandleAnimatedDef (Context: ApiJack.PHookContext): longbool; stdcall;
var
  AnimatedDefWrapper: PAnimatedDefWrapper;
  AnimatedDefItem:    PAnimDefDlgItem;

begin
  AnimatedDefWrapper := ppointer(Context.EBP - $28)^;
  AnimatedDefItem    := AnimatedDefWrapper.DefItem;

  PatchApi.Call(THISCALL_, Ptr(SET_DEF_ITEM_FRAME_INDEX_FUNC), [AnimatedDefItem, AnimatedDefItem.FrameInd + 1]);

  result          := false;
  Context.RetAddr := Ptr($7294E8);
end; // .function Hook_ErmDlgFunction_HandleAnimatedDef

function Hook_OpenMainMenuVideo (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  if not Math.InRange(Heroes.a2i(pchar(Trans.Tr('era.acredit_pos.x', []))), 0, 800 - 1) or
     not Math.InRange(Heroes.a2i(pchar(Trans.Tr('era.acredit_pos.y', []))), 0, 600 - 1)
  then begin
    pinteger($699568)^ := Context.EAX;
    Context.RetAddr    := Ptr($4EEF07);
    result := false;
  end else begin
    result := true;
  end;
end;

function Hook_ShowMainMenuVideo (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  pinteger(Context.EBP - $0C)^ := Heroes.a2i(pchar(Trans.Tr('era.acredit_pos.x', [])));
  pinteger(Context.EBP + $8)^  := Heroes.a2i(pchar(Trans.Tr('era.acredit_pos.y', [])));

  result          := false;
  Context.RetAddr := Ptr($706630);
end;

function Hook_ZvsPlaceCreature_End (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  // Here we rely on the fact, that ZvsLeaveCreature is simple wrapper with pushad + extra data upon b_MsgBox (4F6C00)
  PatchApi.Call(FASTCALL_, Ptr($4F6C00), [pinteger(Context.EBP - $38)^, 4, pinteger(Context.EBP + 60)^, pinteger(Context.EBP + 64)^, -1, 0, -1, 0, -1, 0, -1, 0]);

  result          := false;
  Context.RetAddr := Ptr($7575B3);
end;

function Hook_Dlg_SendMsg (OrigFunc: pointer; Dlg: Heroes.PDlg; Msg: Heroes.PMouseEventInfo): integer; stdcall;
begin
  if
    (Msg.ActionType = DLG_ACTION_OUTDLG_LMB_PRESSED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_LMB_RELEASED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_RMB_PRESSED) or
    (Msg.ActionType = DLG_ACTION_OUTDLG_RMB_RELEASED) or
    (Msg.ActionType = DLG_ACTION_INDLG_CLICK)
  then begin
    DlgLastEvent := Msg^;
  end;

  result := PatchApi.Call(THISCALL_, OrigFunc, [Dlg, Msg]);
end;

function Hook_Show3PicDlg_PrepareDialogStruct (Context: ApiJack.PHookContext): longbool; stdcall;
type
  PDlgStruct = ^TDlgStruct;
  TDlgStruct = packed record
    _1: array [1..16] of byte;
    x:      integer;
    y:      integer;
    Width:  integer;
    Height: integer;
  end;

const
  FUNC_PREPARE_DLG_STRUCT = $4F6410;
  MIN_OFFSET_FROM_BORDERS = 8;
  STD_GAME_WIDTH          = 800;
  STD_GAME_HEIGHT         = 600;
  SMALLEST_DLG_HEIGHT     = 256;

var
  DlgStruct:   PDlgStruct;
  MessageType: integer;
  OrigX:       integer;
  OrigY:       integer;
  CurrDlgId:   integer;
  CurrDlg:     Heroes.PDlg;
  BoxRect:     TRect;
  ClickX:      integer;
  ClickY:      integer;

begin
  DlgStruct := Ptr(Context.ECX);
  OrigX     := DlgStruct.x;
  OrigY     := DlgStruct.y;

  PatchApi.Call(THISCALL_, Ptr(FUNC_PREPARE_DLG_STRUCT), [DlgStruct]);

  MessageType := pinteger(Context.EBP - $10)^;
  CurrDlgId   := Heroes.WndManagerPtr^.GetCurrentDlgId;

  if
    //(OrigX = -1) and (OrigY = -1) and
    (MessageType = ord(Heroes.MES_RMB_HINT))
  then begin
    CurrDlg := Heroes.WndManagerPtr^.CurrentDlg;
    ClickX  := DlgLastEvent.x;
    ClickY  := DlgLastEvent.y;
    BoxRect := Types.Bounds(0, 0, Heroes.ScreenWidth^, Heroes.ScreenHeight^);

    if CurrDlgId <> Heroes.ADVMAP_DLGID then begin
      BoxRect := Types.Bounds((Heroes.ScreenWidth^ - CurrDlg.Width) div 2, (Heroes.ScreenHeight^ - CurrDlg.Height) div 2, CurrDlg.Width, CurrDlg.Height);
    end;

    DlgStruct.x := ClickX - DlgStruct.Width div 2;

    if DlgStruct.x < (BoxRect.Left + MIN_OFFSET_FROM_BORDERS) then begin
      DlgStruct.x := (BoxRect.Left + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.x + DlgStruct.Width > BoxRect.Right then begin
      DlgStruct.x := BoxRect.Right - (DlgStruct.Width + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.x < BoxRect.Left then begin
      DlgStruct.x := (Heroes.ScreenWidth^ - DlgStruct.Width) div 2;
    end;

    // Center small dialogs vertically, show taller dialog 65 pixels above the cursor
    if DlgStruct.Height <= SMALLEST_DLG_HEIGHT then begin
      DlgStruct.y := ClickY - DlgStruct.Height div 2;
    end else begin
      DlgStruct.y := ClickY - 65;
    end;

    if DlgStruct.y < (BoxRect.Top + MIN_OFFSET_FROM_BORDERS) then begin
      DlgStruct.y := (BoxRect.Top + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.y + DlgStruct.Height > BoxRect.Bottom then begin
      DlgStruct.y := BoxRect.Bottom - (DlgStruct.Height + MIN_OFFSET_FROM_BORDERS);
    end;

    if DlgStruct.y < BoxRect.Top then begin
      DlgStruct.y := (Heroes.ScreenHeight^ - DlgStruct.Height) div 2;
    end;
  end;

  result          := false;
  Context.RetAddr := Ptr($4F6D59);
end; // .function Hook_Show3PicDlg_PrepareDialogStruct

procedure DumpWinPeModuleList;
const
  DEBUG_WINPE_MODULE_LIST_PATH = EraSettings.DEBUG_DIR + '\pe modules.txt';

var
  i: integer;

begin
  {!} Debug.ModuleContext.Lock;
  Debug.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(GameExt.GameDir + '\' + DEBUG_WINPE_MODULE_LIST_PATH) do begin
    Line('> Win32 executable modules');
    EmptyLine;

    for i := 0 to Debug.ModuleContext.ModuleList.Count - 1 do begin
      Line(Debug.ModuleContext.ModuleInfo[i].ToStr);
    end;
  end;

  {!} Debug.ModuleContext.Unlock;
end; // .procedure DumpWinPeModuleList

procedure DumpExceptionContext (ExcRec: Windows.PExceptionRecord; Context: Windows.PContext);
const
  DEBUG_EXCEPTION_CONTEXT_PATH = EraSettings.DEBUG_DIR + '\exception context.txt';

var
  ExceptionText: string;
  LineText:      string;
  Ebp:           integer;
  Esp:           integer;
  RetAddr:       integer;
  i:             integer;

begin
  {!} Debug.ModuleContext.Lock;
  Debug.ModuleContext.UpdateModuleList;

  with FilesEx.WriteFormattedOutput(GameExt.GameDir + '\' + DEBUG_EXCEPTION_CONTEXT_PATH) do begin
    case ExcRec.ExceptionCode of
      $C0000005: begin
        if ExcRec.ExceptionInformation[0] <> 0 then begin
          ExceptionText := 'Failed to write data at ' + Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end else begin
          ExceptionText := 'Failed to read data at ' + Format('%x', [integer(ExcRec.ExceptionInformation[1])]);
        end;
      end; // .case $C0000005

      $C000008C: ExceptionText := 'Array index is out of bounds';
      $80000003: ExceptionText := 'Breakpoint encountered';
      $80000002: ExceptionText := 'Data access misalignment';
      $C000008D: ExceptionText := 'One of the operands in a floating-point operation is denormal';
      $C000008E: ExceptionText := 'Attempt to divide a floating-point value by a floating-point divisor of zero';
      $C000008F: ExceptionText := 'The result of a floating-point operation cannot be represented exactly as a decimal fraction';
      $C0000090: ExceptionText := 'Invalid floating-point exception';
      $C0000091: ExceptionText := 'The exponent of a floating-point operation is greater than the magnitude allowed by the corresponding type';
      $C0000092: ExceptionText := 'The stack overflowed or underflowed as the result of a floating-point operation';
      $C0000093: ExceptionText := 'The exponent of a floating-point operation is less than the magnitude allowed by the corresponding type';
      $C000001D: ExceptionText := 'Attempt to execute an illegal instruction';
      $C0000006: ExceptionText := 'Attempt to access a page that was not present, and the system was unable to load the page';
      $C0000094: ExceptionText := 'Attempt to divide an integer value by an integer divisor of zero';
      $C0000095: ExceptionText := 'Integer arithmetic overflow';
      $C0000026: ExceptionText := 'An invalid exception disposition was returned by an exception handler';
      $C0000025: ExceptionText := 'Attempt to continue from an exception that isn''t continuable';
      $C0000096: ExceptionText := 'Attempt to execute a privilaged instruction.';
      $80000004: ExceptionText := 'Single step exception';
      $C00000FD: ExceptionText := 'Stack overflow';
      else       ExceptionText := 'Unknown exception';
    end; // .switch ExcRec.ExceptionCode

    Line(ExceptionText + '.');
    Line(Format('EIP: %s. Code: %x', [Debug.ModuleContext.AddrToStr(Ptr(Context.Eip)), ExcRec.ExceptionCode]));
    EmptyLine;
    Line('> Registers');

    Line('EAX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Eax), Debug.ANALYZE_DATA));
    Line('ECX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ecx), Debug.ANALYZE_DATA));
    Line('EDX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Edx), Debug.ANALYZE_DATA));
    Line('EBX: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ebx), Debug.ANALYZE_DATA));
    Line('ESP: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Esp), Debug.ANALYZE_DATA));
    Line('EBP: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Ebp), Debug.ANALYZE_DATA));
    Line('ESI: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Esi), Debug.ANALYZE_DATA));
    Line('EDI: ' + Debug.ModuleContext.AddrToStr(Ptr(Context.Edi), Debug.ANALYZE_DATA));

    EmptyLine;
    Line('> Callstack');
    Ebp     := Context.Ebp;
    RetAddr := 1;

    try
      while (Ebp <> 0) and (RetAddr <> 0) do begin
        RetAddr := pinteger(Ebp + 4)^;

        if RetAddr <> 0 then begin
          Line(Debug.ModuleContext.AddrToStr(Ptr(RetAddr)));
          Ebp := pinteger(Ebp)^;
        end;
      end;
    except
      // Stop processing callstack
    end; // .try

    EmptyLine;
    Line('> Stack');
    Esp := Context.Esp - sizeof(integer) * 5;

    try
      for i := 1 to 40 do begin
        LineText := IntToHex(Esp, 8);

        if Esp = integer(Context.Esp) then begin
          LineText := LineText + '*';
        end;

        LineText := LineText + ': ' + Debug.ModuleContext.AddrToStr(ppointer(Esp)^, Debug.ANALYZE_DATA);
        Inc(Esp, sizeof(integer));
        Line(LineText);
      end; // .for
    except
      // Stop stack traversing
    end; // .try
  end; // .with

  {!} Debug.ModuleContext.Unlock;
end; // .procedure DumpExceptionContext

procedure LogMemoryState;
var
{U} MemoryConsumers:          DataLib.TStrList {of Ptr(AllocatedSize: integer)};
    MemoryInfo:               PsApi.PROCESS_MEMORY_COUNTERS;
    MemoryManagerState:       FastMM4.TMemoryManagerState;
    ReservedSmallBlocksSize:  cardinal;
    TotalSmallBlocksSize:     cardinal;
    TotalSmallBlocksCount:    cardinal;
    TotalAllocatedSize:       cardinal;
    TotalReservedSize:        cardinal;
    TotalTrackedConsumption:  cardinal;
    EraMemoryConsumption:     cardinal;
    GameMemoryConsumption:    cardinal;
    PluginsMemoryConsumption: cardinal;
    MemoryConsumptionReport:  string;
    i:                        integer;

begin
  MemoryConsumers := nil;
  // * * * * * //
  System.FillChar(MemoryInfo, sizeof(MemoryInfo), #0);
  MemoryInfo.cb := sizeof(MemoryInfo);

  if (PsApi.GetProcessMemoryInfo(Windows.GetCurrentProcess(), @MemoryInfo, sizeof(MemoryInfo))) then begin
    Log.Write('LogMemoryState', 'Log process memory state', SysUtils.Format(
      'Allocated bytes: %d'#13#10            +
      'Reserved bytes: %d'#13#10             +
      'Peak allocated bytes: %d'#13#10       +
      'Peak reserved bytes: %d'#13#10        +
      'PageFaultCount: %d'#13#10,
      //'QuotaPeakPagedPoolUsage: %d'#13#10    +
      //'QuotaPagedPoolUsage: %d'#13#10        +
      //'QuotaPeakNonPagedPoolUsage: %d'#13#10 +
      //'QuotaNonPagedPoolUsage: %d',
    [
      MemoryInfo.WorkingSetSize,
      MemoryInfo.PagefileUsage,
      MemoryInfo.PeakWorkingSetSize,
      MemoryInfo.PeakPagefileUsage,
      MemoryInfo.PageFaultCount
      // MemoryInfo.QuotaPeakPagedPoolUsage,
      // MemoryInfo.QuotaPagedPoolUsage,
      // MemoryInfo.QuotaPeakNonPagedPoolUsage,
      // MemoryInfo.QuotaNonPagedPoolUsage
    ]));
  end;

  FastMM4.GetMemoryManagerState(MemoryManagerState);

  ReservedSmallBlocksSize := 0;
  TotalSmallBlocksSize    := 0;
  TotalSmallBlocksCount   := 0;

  for i := Low(MemoryManagerState.SmallBlockTypeStates) to High(MemoryManagerState.SmallBlockTypeStates) do begin
    Inc(ReservedSmallBlocksSize, MemoryManagerState.SmallBlockTypeStates[i].ReservedAddressSpace);
    Inc(TotalSmallBlocksSize,    MemoryManagerState.SmallBlockTypeStates[i].AllocatedBlockCount * MemoryManagerState.SmallBlockTypeStates[i].UseableBlockSize);
    Inc(TotalSmallBlocksCount,   MemoryManagerState.SmallBlockTypeStates[i].AllocatedBlockCount);
  end;

  TotalAllocatedSize := TotalSmallBlocksSize + MemoryManagerState.TotalAllocatedMediumBlockSize + MemoryManagerState.TotalAllocatedLargeBlockSize;
  TotalReservedSize  := ReservedSmallBlocksSize + MemoryManagerState.ReservedMediumBlockAddressSpace + MemoryManagerState.ReservedLargeBlockAddressSpace;

  Log.Write('LogMemoryState', 'Log Era memory state', SysUtils.Format(
    'TotalAllocatedSize: %d'#13#10              +
    'TotalReservedSize: %d'#13#10               +
    'TotalSmallBlocksCount: %d'#13#10           +
    'TotalSmallBlocksSize: %d'#13#10            +
    'ReservedSmallBlocksSize: %d'#13#10         +
    'AllocatedMediumBlockCount: %d'#13#10       +
    'TotalAllocatedMediumBlockSize: %d'#13#10   +
    'ReservedMediumBlockAddressSpace: %d'#13#10 +
    'AllocatedLargeBlockCount: %d'#13#10        +
    'TotalAllocatedLargeBlockSize: %d'#13#10    +
    'ReservedLargeBlockAddressSpace: %d',
  [
    TotalAllocatedSize,
    TotalReservedSize,
    TotalSmallBlocksCount,
    TotalSmallBlocksSize,
    ReservedSmallBlocksSize,
    MemoryManagerState.AllocatedMediumBlockCount,
    MemoryManagerState.TotalAllocatedMediumBlockSize,
    MemoryManagerState.ReservedMediumBlockAddressSpace,
    MemoryManagerState.AllocatedLargeBlockCount,
    MemoryManagerState.TotalAllocatedLargeBlockSize,
    MemoryManagerState.ReservedLargeBlockAddressSpace
  ]));

  MemoryConsumers         := Memory.GetMemoryConsumers;
  MemoryConsumptionReport := '';
  TotalTrackedConsumption := 0;
  GameMemoryConsumption   := integer(MemoryConsumers.Values[Memory.GAME_MEM_CONSUMER_INDEX]);

  for i := 0 to MemoryConsumers.Count - 1 do begin
    Inc(TotalTrackedConsumption, cardinal(MemoryConsumers.Values[i]));
    MemoryConsumptionReport := MemoryConsumptionReport + MemoryConsumers[i] + ': ' + SysUtils.IntToStr(integer(MemoryConsumers.Values[i]));

    if i < MemoryConsumers.Count - 1 then begin
      MemoryConsumptionReport := MemoryConsumptionReport + #13#10;
    end;
  end;

  PluginsMemoryConsumption := TotalTrackedConsumption - GameMemoryConsumption;
  EraMemoryConsumption     := TotalAllocatedSize - TotalTrackedConsumption;

  Log.Write('LogMemoryState', 'Log tracked memory consumption', SysUtils.Format(
    'Game memory consumption: %d'#13#10 +
    'Era memory consumption: %d'#13#10 +
    'Plugins memory consumption: %d'#13#10#13#10'Memory consumers:'#13#10'-----------------'#13#10'%s',
    [
      GameMemoryConsumption,
      EraMemoryConsumption,
      PluginsMemoryConsumption,
      MemoryConsumptionReport
    ]
  ));
end; // .procedure LogMemoryState

procedure ProcessUnhandledException (ExceptionRecord: Windows.PExceptionRecord; Context: Windows.PContext);
begin
  {!} ExceptionsCritSection.Enter;

  if not IsCrashing then begin
    IsCrashing      := true;
    Erm.ErmEnabled^ := false;

    Windows.VirtualFree(OutOfMemoryVirtualReserve, 0, Windows.MEM_RELEASE);
    System.FreeMem(OutOfMemoryReserve);

    GameExt.ClearDebugDir;
    DumpExceptionContext(ExceptionRecord, Context);
    LogMemoryState;
    ShouldLogMemoryState := false;
    GameExt.GenerateDebugInfoWithoutCleanup;
    Windows.MessageBoxA(Heroes.hWnd^, pchar(Trans.Tr('era.game_crash_message', ['debug_dir', DEBUG_DIR])), '', Windows.MB_OK);
  end;

  Debug.KillThisProcess;

  {!} ExceptionsCritSection.Leave;
end;

function UnhandledExceptionFilter (const ExceptionPtrs: TExceptionPointers): integer; stdcall;
const
  EXCEPTION_CONTINUE_SEARCH = 0;

begin
  ProcessUnhandledException(ExceptionPtrs.ExceptionRecord, ExceptionPtrs.ContextRecord);

  result := EXCEPTION_CONTINUE_SEARCH;
end;

procedure CaptureCrashScreenshot;
begin
  Graph.TakeScreenshot(GameExt.GameDir + '\' + CRASH_SCREENSHOT_PATH, 70);
end;

procedure CopyCrashSavegameToDebugDir;
var
  CrashSavegamePath: string;

begin
  if CrashSavegameName <> '' then begin
    CrashSavegamePath := GameExt.GameDir + '\games\' + CrashSavegameName;

    if Files.FileExists(CrashSavegamePath) then begin
      Windows.CopyFile(pchar(CrashSavegamePath), pchar(GameExt.GameDir + '\' + CRASH_SAVEGAME_PATH), false);
    end;
  end;
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  if ShouldLogMemoryState then begin
    LogMemoryState;
  end;

  if EraSettings.GetOpt('Debug.CaptureScreenshotOnCrash').Bool(true) then begin
    CaptureCrashScreenshot;
  end;

  if EraSettings.GetOpt('Debug.CopySavegameOnCrash').Bool(true) then begin
    CopyCrashSavegameToDebugDir;
  end;

  DumpWinPeModuleList;
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
const
  ZVSLIB_EXTRACTDEF_OFS             = 100668;
  ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS = 260;

  NOP7: string  = #$90#$90#$90#$90#$90#$90#$90;

var
  Zvslib1Handle:  integer;
  Addr:           integer;
  NewAddr:        pointer;
  MinTimerResol:  cardinal;
  MaxTimerResol:  cardinal;
  CurrTimerResol: cardinal;

begin
  if DebugRng <> DEBUG_RNG_NONE then begin
    ConsoleApi.GetConsole();
  end;

  (* Ini handling *)
  ApiJack.Hook(ZvsReadStrIni,  @Hook_ReadStrIni,  nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(ZvsWriteStrIni, @Hook_WriteStrIni, nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(ZvsWriteIntIni, @Hook_WriteIntIni, nil, 0, ApiJack.HOOKTYPE_JUMP);

  (* DL dialogs centering *)
  ApiJack.Hook(Ptr($729C5A), @Hook_ZvsGetWindowWidth);
  ApiJack.Hook(Ptr($729C6D), @Hook_ZvsGetWindowHeight);

  (* Mark the freshest savegame *)
  MarkFreshestSavegame;

  (* Fix multi-thread CPU problem *)
  if UseOnlyOneCpuCoreOpt then begin
    Windows.SetProcessAffinityMask(Windows.GetCurrentProcess, 1);
  end;

  (* Fix HotSeat second hero name *)
  ApiJack.Hook(Ptr($5125B0), @Hook_SetHotseatHeroName, nil, 6);
  PatchApi.p.WriteDataPatch(Ptr($5125F9), ['90909090909090']);

  (* Universal CPU patch *)
  if CpuTargetLevel < 100 then begin
    // Try to set timer resolution to at least 1ms = 10000 ns
    if (WinNative.NtQueryTimerResolution(MinTimerResol, MaxTimerResol, CurrTimerResol) = STATUS_SUCCESS) and (CurrTimerResol > 10000) and (MaxTimerResol < CurrTimerResol) then begin
      WinNative.NtSetTimerResolution(Math.Max(10000, MaxTimerResol), true, CurrTimerResol);
    end;

    hTimerEvent := Windows.CreateEvent(nil, true, false, nil);
    ApiJack.Hook(Windows.GetProcAddress(GetModuleHandle('user32.dll'), 'PeekMessageA'), @Hook_PeekMessageA, nil, 0, ApiJack.HOOKTYPE_BRIDGE);
  end;

  (* Remove duplicate ResetAll call *)
  pinteger($7055BF)^ :=  integer($90909090);
  PBYTE($7055C3)^    :=  $90;

  (* Optimize zvslib1.dll ini handling *)
  Zvslib1Handle   :=  Windows.GetModuleHandle('zvslib1.dll');
  Addr            :=  Zvslib1Handle + 1666469;
  Addr            :=  pinteger(Addr + pinteger(Addr)^ + 6)^;
  NewAddr         :=  @New_Zvslib_GetPrivateProfileStringA;
  PatchApi.p.WriteDword(@NewAddr, integer(Addr));

  (* Redirect reading/writing game settings to ini *)
  // No saving settings after reading them
  PBYTE($50B964)^    := $C3;
  pinteger($50B965)^ := integer($90909090);

  ppointer($50B920)^ := Ptr(integer(@ReadGameSettings) - $50B924);
  ppointer($50BA2F)^ := Ptr(integer(@WriteGameSettings) - $50BA33);
  ppointer($50C371)^ := Ptr(integer(@WriteGameSettings) - $50C375);

  (* Fix game version to enable map generator *)
  Heroes.GameVersion^ := Heroes.SOD_AND_AB;

  (* Hook gethostbyname function to implement desired IP address selection *)
  ApiJack.StdSplice(Windows.GetProcAddress(Windows.GetModuleHandle('ws2_32.dll'), 'gethostbyname'), @Hook_GetHostByName, ApiJack.CONV_STDCALL, 1);

  (* Fix ApplyDamage calls, so that !?MF1 damage is displayed correctly in log *)
  ApiJack.Hook(Ptr($43F95B + 5), @Hook_ApplyDamage_Ebx_Local7);
  ApiJack.Hook(Ptr($43FA5E + 5), @Hook_ApplyDamage_Ebx);
  ApiJack.Hook(Ptr($43FD3D + 5), @Hook_ApplyDamage_Local7);
  ApiJack.Hook(Ptr($4400DF + 5), @Hook_ApplyDamage_Ebx);
  ApiJack.Hook(Ptr($440858 + 5), @Hook_ApplyDamage_Esi_Arg1);
  ApiJack.Hook(Ptr($440E70 + 5), @Hook_ApplyDamage_Ebx);
  ApiJack.Hook(Ptr($441048 + 5), @Hook_ApplyDamage_Arg1);
  ApiJack.Hook(Ptr($44124C + 5), @Hook_ApplyDamage_Esi);
  ApiJack.Hook(Ptr($441739 + 5), @Hook_ApplyDamage_Local4);
  ApiJack.Hook(Ptr($44178A + 5), @Hook_ApplyDamage_Local8);
  ApiJack.Hook(Ptr($46595F + 5), @Hook_ApplyDamage_Arg1);
  ApiJack.Hook(Ptr($469A93 + 5), @Hook_ApplyDamage_Ebx);
  ApiJack.Hook(Ptr($5A1065 + 5), @Hook_ApplyDamage_Local13);

  (* Fix negative offsets handling in fonts *)
  PatchApi.p.WriteDataPatch(Ptr($4B534A), ['B6']);
  PatchApi.p.WriteDataPatch(Ptr($4B53E6), ['B6']);

  (* Fix WoG/ERM versions *)
  ApiJack.Hook(Ptr($73226C), @Hook_GetWoGAndErmVersions, nil, 14);

  (*  Fix zvslib1.dll ExtractDef function to support mods  *)
  ApiJack.Hook(Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + 3), @Hook_ZvsLib_ExtractDef);

  ApiJack.Hook(Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS), @Hook_ZvsLib_ExtractDef_GetGamePath);

  (* Syncronise object creation at local and remote PC *)
  PatchApi.p.WriteHiHook(Ptr($71299E), PatchApi.SPLICE_, PatchApi.EXTENDED_, PatchApi.CDECL_, @Hook_ZvsPlaceMapObject);
  EventMan.GetInstance.On('OnRemoteCreateAdvMapObject', OnRemoteCreateAdvMapObject);

  (* Fixed bug with combined artifact (# > 143) dismounting in heroes meeting screen *)
  PatchApi.p.WriteDataPatch(Ptr($4DC358), ['A0']);

  (* Fix MixedPos to not drop higher order bits and not treat them as underground flag *)
  PatchApi.p.WriteDataPatch(Ptr($711F4F), ['8B451425FFFFFF048945149090909090909090']);

  (* Fix WoG bug: double !?OB54 event generation when attacking without moving due to Enter2Object + Enter2Monster2 calling *)
  PatchApi.p.WriteDataPatch(Ptr($757AA0), ['EB2C90909090']);

  (* Fixe WoG adventure map mouse click handler: chat input produces left click event *)
  ApiJack.StdSplice(Ptr($74EF37), @Hook_WoGMouseClick3, CONV_THISCALL, 4);

  (* Fix battle round counting: no !?BR before battlefield is shown, negative FIRST_TACTICS_ROUND incrementing for the whole tactics phase, the
     first real round always starts from 0 *)
  ApiJack.Hook(Ptr($75EAEA), @Hook_OnBeforeBattlefieldVisible);
  ApiJack.Hook(Ptr($462E2B), @Hook_OnBattlefieldVisible);
  ApiJack.Hook(Ptr($75D137), @Hook_OnAfterTacticsPhase);
  // Call ZvsNoMoreTactic1 in network game for the opposite side
  ApiJack.Hook(Ptr($473E89), ZvsNoMoreTactic1, nil, 0, ApiJack.HOOKTYPE_CALL);
  ApiJack.Hook(Ptr($76065B), @Hook_OnCombatRound_Start);
  ApiJack.Hook(Ptr($7609A3), @Hook_OnCombatRound_End);

  // Disable BACall2 function, generating !?BR event, because !?BR will be the same as OnCombatRound now
  PatchApi.p.WriteDataPatch(Ptr($74D1AB), ['C3']);

  // Disable WoG AppearAfterTactics hook. We will call BR0 manually a bit after to reduce crashing probability
  PatchApi.p.WriteDataPatch(Ptr($462C19), ['E8F2051A00']);

  // Use CombatRound instead of combat manager field to summon creatures every nth turn via creature experience system
  PatchApi.p.WriteDataPatch(Ptr($71DFBE), ['8B15 %d', @CombatRound]);

  // Fix combatManager::CastSpell function by temporarily setting CombatManager->ControlSide to the side, controlling casting stack.
  // "Fire wall", "land mines", "quick sands" and many other spells rely on which side is considered friendly for spell.
  ApiJack.StdSplice(Ptr($5A0140), @Splice_CombatManager_CastSpell, ApiJack.CONV_THISCALL, 7);

  // Fix WoG QuickSand and LandMine functions: redraw battlefield if spell is casted by inactive stack
  ApiJack.StdSplice(Ptr($75EBBA), @Splice_ZvsQuickSandOrLandMine, ApiJack.CONV_CDECL, 4);
  ApiJack.StdSplice(Ptr($75ED82), @Splice_ZvsQuickSandOrLandMine, ApiJack.CONV_CDECL, 4);

  // Fix crash in network game in savegame dialog: RMB on some dialog items above savegame list, attempt to update ScreenLog without having valid textWidget field
  PatchApi.p.WriteDataPatch(Ptr($58B15A), ['E98200000090']);

  // Restore Nagash and Jeddite specialties
  PatchApi.p.WriteDataPatch(Ptr($753E0B), ['E9990000009090']); // PrepareSpecWoG => ignore new WoG settings
  PatchApi.p.WriteDataPatch(Ptr($79C3D8), ['FFFFFFFF']);       // HeroSpecWoG[0].Ind = -1

  // Fix check for multiplayer in attack type selection dialog, causing wrong "This feature does not work in Human vs Human network baced battle" message
  PatchApi.p.WriteDataPatch(Ptr($762604), ['C5']);

  // Fix creature experience overflow after battle
  ApiJack.Hook(Ptr($719225), @Hook_PostBattle_OnAddCreaturesExp);

  // Fix DisplayComplexDialog to overload the last argument
  // closeTimeoutMsec is now TComplexDialogOpts
  //  16 bits for closeTimeoutMsec.
  //  4 bits for msgType (1 - ok, 2 - question, 4 - popup, etc), 0 is treated as 1.
  //  4 bits for text alignment + 1.
  //  8 bits for H3 string internal purposes (0 mostly).
  ApiJack.Hook(Ptr($4F7D83), @Hook_DisplayComplexDialog_GetTimeout);
  // Nop dlg.closeTimeoutMsec := closeTimeoutMsec
  PatchApi.p.WriteDataPatch(Ptr($4F7E19), ['909090']);
  // Nop dlg.msgType := MSG_TYPE_MES
  PatchApi.p.WriteDataPatch(Ptr($4F7E4A), ['90909090909090']);

  (* Fix ShowParsedDlg8Items function to allow custom text alignment and preselected item *)
  ApiJack.Hook(Ptr($4F72B5), @Hook_ShowParsedDlg8Items_CreateTextField);
  ApiJack.Hook(Ptr($4F7136), @Hook_ShowParsedDlg8Items_Init);

  (* Fix ZvsDisplay8Dialog to 2 extra arguments (msgType, alignment) and return -1 or 0..7 for chosen picture or 0/1 for question *)
  ApiJack.Hook(Ptr($7169EB), @Hook_ZvsDisplay8Dialog_BeforeShow);

  (* Patch ParsePicture function to allow "0 something" values in generic h3 dialogs *)
  // Allocate new local variables EBP - $0B4
  PatchApi.p.WriteDataPatch(Ptr($4F555A), ['B4000000']);
  // Unpack highest bit of Type parameter as "display 0 quantities" flag into new local variable
  ApiJack.Hook(Ptr($4F5564), @Hook_ParsePicture_Start);

  (* Fix WoG HDlg::BuildPcx to allow .pcx16 virtual file extension to load image as pcx16 *)
  ApiJack.StdSplice(Ptr($7287FB), @Hook_HDlg_BuildPcx, ApiJack.CONV_STDCALL, 7);

  (* Fix Santa-Gremlins *)
  // Remove WoG FairePower hook
  PatchApi.p.WriteDataPatch(Ptr($44836D), ['8B464C8D0480']);
  // Add new FairePower hook
  ApiJack.Hook(Ptr($44836D), @Hook_HandleMonsterCast_End);
  // Disable Santa's every day growth
  PatchApi.p.WriteDataPatch(Ptr($760D6D), ['EB']);
  // Restore Santa's normal growth
  PatchApi.p.WriteDataPatch(Ptr($760C56), ['909090909090']);
  // Disable Santa's gifts
  PatchApi.p.WriteDataPatch(Ptr($75A964), ['9090']);

  (* Fix multiplayer crashes: disable orig/diff.dat generation, always send packed whole savegames *)
  PatchApi.p.WriteDataPatch(Ptr($4CAE51), ['E86A5EFCFF']);       // Disable WoG BuildAllDiff hook
  PatchApi.p.WriteDataPatch(Ptr($6067E2), ['E809000000']);       // Disable WoG GZ functions hooks
  PatchApi.p.WriteDataPatch(Ptr($4D6FCC), ['E8AF001300']);       // ...
  PatchApi.p.WriteDataPatch(Ptr($4D700D), ['E8DEFE1200']);       // ...
  PatchApi.p.WriteDataPatch(Ptr($4CAF32), ['EB']);               // do not create orig.dat on send
  if false then PatchApi.p.WriteDataPatch(Ptr($4CAF37), ['01']); // save orig.dat on send compressed
  PatchApi.p.WriteDataPatch(Ptr($4CAD91), ['E99701000090']);     // do not perform savegame diffs
  PatchApi.p.WriteDataPatch(Ptr($41A0D1), ['EB']);               // do not create orig.dat on receive
  if false then PatchApi.p.WriteDataPatch(Ptr($41A0DC), ['01']); // save orig.dat on receive compressed
  PatchApi.p.WriteDataPatch(Ptr($4CAD5A), ['31C040']);           // Always gzip the data to be sent
  PatchApi.p.WriteDataPatch(Ptr($589EA4), ['EB10']);             // Do not create orig on first savegame receive from server

  (* Splice WoG Get2Battle function, handling any battle *)
  ApiJack.StdSplice(Ptr($75ADD9), @Hook_StartBattle, ApiJack.CONV_THISCALL, 11);

  (* Always send original (unmodified) battle stack action info to remote side in PvP battles  *)
  ApiJack.Hook(Ptr($75C69E), @Hook_WoGBeforeBattleAction);
  ApiJack.Hook(Ptr($47883B), @Hook_SendBattleAction_CopyActionParams);

  (* Trigger OnBeforeBattleAction before Enchantress, Hell Steed and creature experience mass spell processing *)
  ApiJack.Hook(Ptr($75C96C), @Hook_WoGBeforeBattleAction_HandleEnchantress);
  PatchApi.p.WriteDataPatch(Ptr($75CB26), ['9090909090909090909090']);

  (* Use CombatRound in OnAfterBattleAction trigger for v997 *)
  ApiJack.Hook(Ptr($75D306), @Hook_WoGCallAfterBattleAction);

  (* Send and receive unique identifier for each battle to use in deterministic PRNG in multiplayer *)
  ApiJack.Hook(Ptr($763796), @Hook_ZvsAdd2Send);
  ApiJack.Hook(Ptr($763BA4), @Hook_ZvsGet4Receive);

  (* Introduce new internal triggers $OnBeforeBattleBeforeDataSend and $OnAfterBattleBeforeDataSend *)
  ApiJack.StdSplice(Ptr($74D160), @Hook_ZvsTriggerIp, ApiJack.CONV_CDECL, 1);

  (* Replace Heroes PRNG with custom switchable PRNGs *)
  ApiJack.StdSplice(Ptr($61841F), @Hook_SRand, ApiJack.CONV_CDECL, 1);
  ApiJack.StdSplice(Ptr($61842C), @Hook_Rand, ApiJack.CONV_STDCALL, 0);
  ApiJack.StdSplice(Ptr($50C7B0), @Hook_Tracking_SRand, ApiJack.CONV_THISCALL, 1);
  ApiJack.StdSplice(Ptr($50C7C0), @Hook_RandomRange, ApiJack.CONV_FASTCALL, 2);

  // Apply battle RNG seed right before placing obstacles, so that rand() calls in !?BF trigger would not influence battle obstacles
  ApiJack.StdSplice(Ptr($465E70), @Hook_PlaceBattleObstacles, ApiJack.CONV_THISCALL, 1);

  // Fix sequential PRNG calls in network PvP battles
  ApiJack.Hook(Ptr($75D760), @SequentialRandomRangeFastcall, nil, 7, ApiJack.HOOKTYPE_CALL); // Death Stare WoG-native
  ApiJack.Hook(Ptr($75D72E), @SequentialRandomRangeCdecl,    nil, 5, ApiJack.HOOKTYPE_CALL); // Death Stare WoG
  ApiJack.Hook(Ptr($4690CA), @SequentialRand,                nil, 5, ApiJack.HOOKTYPE_CALL); // Phoenix Ressurection native

  (* Allow to handle dialog outer clicks and provide full mouse info for event *)
  ApiJack.Hook(Ptr($7295F1), @Hook_ErmDlgFunctionActionSwitch);

  (* Add up to 10 animated DEFs support in DL-dialogs by restoring commented ZVS code *)
  ApiJack.Hook(Ptr($72A1F6), @Hook_DL_D_ItemCreation);
  ApiJack.Hook(Ptr($729513), @Hook_ErmDlgFunction_HandleAnimatedDef);

  (* Move acredits.smk video positon to json config and treat out-of-bounds coordinates as video switch-off *)
  ApiJack.Hook(Ptr($706609), @Hook_ShowMainMenuVideo);
  ApiJack.Hook(Ptr($4EEEE8), @Hook_OpenMainMenuVideo);

  (* Fix Blood Dragons aging change from 20% to 40% *)
  PatchApi.p.WriteDataPatch(Ptr($75DE31), ['7509C6055402440028EB07C6055402440064']);

  (* Fix CheckForCompleteAI function, checking gosolo mode only if timer <> 0, while it's 0 in modern game with HD mod *)
  PatchApi.p.WriteDataPatch(Ptr($75ADC1), ['9090']);

  (* Use click coords to show popup dialogs almost everywhere *)
  ApiJack.Hook(Ptr($4F6D54), @Hook_Show3PicDlg_PrepareDialogStruct);
  ApiJack.StdSplice(Ptr($5FF3A0), @Hook_Dlg_SendMsg, ApiJack.CONV_THISCALL, 2);

  if FALSE then begin
    // Disabled, the patch simply restores SOD behavior on adventure map
    ApiJack.Hook(Ptr($7575A3), @Hook_ZvsPlaceCreature_End);
  end;

  (* Fix PrepareDialog3Struct inner width calculation: dlgWidth - 50 => dlgWidth - 40, centering the text *)
  PatchApi.p.WriteDataPatch(Ptr($4F6696), ['D7']);

  (* Increase number of quick battle rounds before fast finish from 30 to 100 *)
  PatchApi.p.WriteDataPatch(Ptr($475C35), ['64']);

  (* Remove WoG Service_SetExcFilter call, preventing SetUnhandledExceptionFilter *)
  PatchApi.p.WriteDataPatch(Ptr($77180E), ['90909090909090909090909090']);

  (* Fix advmap objects control word unpacking: right arithmetic shift was used instead of right logical shift *)
  PatchApi.p.WriteDataPatch(Ptr($4A4CF8), ['E8']);
  PatchApi.p.WriteDataPatch(Ptr($4A512E), ['E8']);
  PatchApi.p.WriteDataPatch(Ptr($4A61CC), ['E8']);
  PatchApi.p.WriteDataPatch(Ptr($4A66AC), ['E8']);
  PatchApi.p.WriteDataPatch(Ptr($4A795B), ['E8']);
end; // .procedure OnAfterWoG

procedure OnLoadEraSettings (Event: GameExt.PEvent); stdcall;
begin
  CpuTargetLevel          := EraSettings.GetOpt('CpuTargetLevel')    .Int(50);
  AutoSelectPcIpMaskOpt   := EraSettings.GetOpt('AutoSelectPcIpMask').Str('');
  UseOnlyOneCpuCoreOpt    := EraSettings.GetOpt('UseOnlyOneCpuCore') .Bool(false);
  DebugRng                := EraSettings.GetOpt('Debug.Rng')         .Int(0);
end;

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
begin
  (* Repeat top-level handler installation, because other plugins and dlls could interfere *)
  Windows.SetErrorMode(SEM_NOGPFAULTERRORBOX);
  Windows.SetUnhandledExceptionFilter(@UnhandledExceptionFilter);
end;

procedure OnBeforeErmInstructions (Event: GameExt.PEvent); stdcall;
begin
  CrashSavegameName := '';
end;

procedure OnBeforeLoadGame (Event: GameExt.PEvent); stdcall;
begin
  CrashSavegameName := EventLib.POnBeforeLoadGameEvent(Event.Data).FileName;
end;

procedure OnBeforeSaveGame (Event: GameExt.PEvent); stdcall;
begin
  CrashSavegameName := pchar(Erm.x[1]);
end;

procedure OnAfterVfsInit (Event: GameExt.PEvent); stdcall;
begin
  Windows.SetErrorMode(SEM_NOGPFAULTERRORBOX);
  Windows.SetUnhandledExceptionFilter(@UnhandledExceptionFilter);
end;

begin
  Windows.InitializeCriticalSection(InetCriticalSection);
  ExceptionsCritSection.Init;
  System.GetMem(OutOfMemoryReserve, OUT_OF_MEMORY_RESERVE_BYTES);
  OutOfMemoryVirtualReserve := Windows.VirtualAlloc(nil, OUT_OF_MEMORY_VIRTUAL_RESERVE_BYTES, Windows.MEM_RESERVE, Windows.PAGE_READWRITE);
  CLangRng               := FastRand.TClangRng.Create(FastRand.GenerateSecureSeed);
  QualitativeRng         := FastRand.TXoroshiro128Rng.Create(FastRand.GenerateSecureSeed);
  BattleDeterministicRng := TBattleDeterministicRng.Create(@CombatId, @CombatRound, @CombatActionId, @CombatRngFreeParam);
  GlobalRng              := QualitativeRng;
  Mp3TriggerHandledEvent := Windows.CreateEvent(nil, false, false, nil);
  ComputerName           := WinUtils.GetComputerNameW;

  EventMan.GetInstance.On('$OnLoadEraSettings',      OnLoadEraSettings);
  EventMan.GetInstance.On('OnAfterCreateWindow',     OnAfterCreateWindow);
  EventMan.GetInstance.On('OnAfterVfsInit',          OnAfterVfsInit);
  EventMan.GetInstance.On('OnAfterWoG',              OnAfterWoG);
  EventMan.GetInstance.On('OnBattleReplay',          OnBattleReplay);
  EventMan.GetInstance.On('OnBeforeBattleReplay',    OnBeforeBattleReplay);
  EventMan.GetInstance.On('OnBeforeBattleUniversal', OnBeforeBattleUniversal);
  EventMan.GetInstance.On('OnBeforeErmInstructions', OnBeforeErmInstructions);
  EventMan.GetInstance.On('OnBeforeLoadGame',        OnBeforeLoadGame);
  EventMan.GetInstance.On('OnBeforeSaveGame',        OnBeforeSaveGame);
  EventMan.GetInstance.On('OnGenerateDebugInfo',     OnGenerateDebugInfo);
end.
