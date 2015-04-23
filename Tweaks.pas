unit Tweaks;
{
DESCRIPTION:  Game improvements
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Utils, StrLib, WinSock, Windows, Math,
  CFiles, Files, FilesEx, Ini, DataLib,
  PatchApi, Core, GameExt, Heroes, Lodman;

type
  (* Import *)
  TStrList = DataLib.TStrList;

const
  // f (Value: pchar; MaxResLen: integer; DefValue, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsReadStrIni   = Ptr($773A46);
  // f (Res: PINTEGER; DefValue: integer; Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsReadIntIni   = Ptr($7739D1);
  // f (Value: pchar; Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteStrIni  = Ptr($773B34);
  // f (Value, Key, SectionName, FileName: pchar): integer; cdecl;
  ZvsWriteIntIni  = Ptr($773ACB);
  
  ZvsAppliedDamage: PINTEGER  = Ptr($2811888);


var
  CPUPatchOpt:          boolean;
  FixGetHostByNameOpt:  boolean;
  UseOnlyOneCpuCoreOpt: boolean;
  
  
(***) implementation (***)


var
  hTimerEvent:          THandle;
  InetCriticalSection:  Windows.TRTLCriticalSection;
  ZvsLibImageTemplate:  string;
  ZvsLibGamePath:       string;


function Hook_ReadIntIni
(
  Res:          PINTEGER;
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
  end; // .if
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
  end; // .if
  
  if Value <> '' then begin
    Utils.CopyMem(Length(Value) + 1, pointer(Value), Res);
  end // .if
  else begin
    Res^  :=  #0;
  end; // .else
end; // .function Hook_ReadStrIni

function Hook_WriteStrIni (Value, Key, SectionName, FileName: pchar): integer; cdecl;
begin
  result  :=  0;
  
  if Ini.WriteStrToIni(Key, Value, SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end; // .if
end; // .function Hook_WriteStrIni

function Hook_WriteIntIni (Value: integer; Key, SectionName, FileName: pchar): integer; cdecl;
begin
  result  :=  0;
  
  if Ini.WriteStrToIni(Key, SysUtils.IntToStr(Value), SectionName, FileName) then begin
    Ini.SaveIni(FileName);
  end; // .if
end; // .function Hook_ReadIntIni

function Hook_ZvsGetWindowWidth (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.ECX :=  WndManagerPtr^.ScreenPcx16.Width;
  result      :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsGetWindowWidth

function Hook_ZvsGetWindowHeight (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.EDX :=  WndManagerPtr^.ScreenPcx16.Height;
  result      :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsGetWindowHeight

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
    end; // .if
    SysUtils.FreeAndNil(FileInfo);
  end; // .while
  
  Locator.FinitSearch;
  
  Utils.CopyMem(Length(FreshestFileName) + 1, pointer(FreshestFileName), Heroes.MarkedSavegame);
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .procedure MarkFreshestSavegame

function Hook_SetHotseatHeroName (Context: Core.PHookContext): LONGBOOL; stdcall;
var
  PlayerName:     string;
  NewPlayerName:  string;
  EcxReg:         integer;

begin
  PlayerName    :=  pchar(Context.EAX);
  NewPlayerName :=  PlayerName + ' 1';
  EcxReg        :=  Context.ECX;
  
  asm
    MOV ECX, EcxReg
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end; // .asm
  
  NewPlayerName :=  PlayerName + ' 2';
  EcxReg        :=  Context.EBX;
  
  asm
    MOV ECX, EcxReg
    MOV ECX, [ECX + $54]
    PUSH NewPlayerName
    MOV EDX, [ECX]
    CALL [EDX + $34]
  end; // .asm
  
  result  :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_SetHotseatHeroName

function Hook_PeekMessageA (Hook: PatchApi.THiHook; var lpMsg: TMsg; hWnd: Windows.HWND;
                            wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL; stdcall;
begin
  Windows.WaitForSingleObject(hTimerEvent, 1);
  result := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                               [@lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg]));
end; // .function Hook_PeekMessageA

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
  end; // .if
  
  if BufSize <= Length(Res) then begin
    SetLength(Res, BufSize - 1);
  end; // .if
  
  Utils.CopyMem(Length(Res) + 1, pchar(Res), Buf);
  
  result :=  Length(Res) + 1;
end; // .function New_Zvslib_GetPrivateProfileStringA

procedure ReadGameSettings;
  procedure ReadInt (const Key: string; Res: PINTEGER);
  var
    StrValue: string;
    Value:    integer;
     
  begin
    if
      Ini.ReadStrFromIni
      (
        Key,
        Heroes.GAME_SETTINGS_SECTION,
        Heroes.GAME_SETTINGS_FILE,
        StrValue
      ) and
      SysUtils.TryStrToInt(StrValue, Value)
    then begin
      Res^  :=  Value;
    end; // .if
  end; // .procedure ReadInt
  
  procedure ReadStr (const Key: string; Res: pchar);
  var
    StrValue: string;
     
  begin
    if
      Ini.ReadStrFromIni(Key, Heroes.GAME_SETTINGS_SECTION, Heroes.GAME_SETTINGS_FILE, StrValue)
    then begin
      Utils.CopyMem(Length(StrValue) + 1, pchar(StrValue), Res);
    end; // .if
  end; // .procedure ReadStr
  
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
  end; // .asm

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
    RandomValue :=  (integer(Windows.GetTickCount) + Random(MAXLONGINT)) and UNIQUE_ID_MASK;
    SetLength(RandomStr, UNIQUE_ID_LEN);
    
    for i:=1 to UNIQUE_ID_LEN do begin
      RandomStr[i]  :=  UPCASE(StrLib.ByteToHexChar(RandomValue and $F));
      RandomValue   :=  RandomValue shr 4;
    end; // .for
    
    Utils.CopyMem(Length(RandomStr) + 1, pointer(RandomStr), Heroes.UNIQUE_SYSTEM_ID_OPT);
    
    Ini.WriteStrToIni
    (
      'Unique System ID',
      RandomStr,
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
    
    Ini.SaveIni(Heroes.GAME_SETTINGS_FILE);
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
  procedure WriteInt (const Key: string; Value: PINTEGER); 
  begin
    Ini.WriteStrToIni
    (
      Key,
      SysUtils.IntToStr(Value^),
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
  end; // .procedure WriteInt
  
  procedure WriteStr (const Key: string; Value: pchar);
  begin
    Ini.WriteStrToIni
    (
      Key,
      Value,
      Heroes.GAME_SETTINGS_SECTION,
      Heroes.GAME_SETTINGS_FILE
    );
  end; // .procedure WriteStr
   
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
  
  Ini.SaveIni(Heroes.GAME_SETTINGS_FILE);
end; // .procedure WriteGameSettings

function Hook_GetHostByName (Hook: PatchApi.THiHook; Name: pchar): WinSock.PHostEnt; stdcall;
type
  PEndlessPIntArr = ^TEndlessPIntArr;
  TEndlessPIntArr = array [0..MAXLONGINT div 4 - 1] of PINTEGER;
  
var
{U} HostEnt:  WinSock.PHostEnt;
{U} Addrs:    PEndlessPIntArr;
    i:        integer;

  function IsLocalAddr (Addr: integer): boolean;
  type
    TInt32 = packed array [0..3] of byte;
  
  begin
    result := (TInt32(Addr)[0] = 10) or ((TInt32(Addr)[0] = 172) and Math.InRange(TInt32(Addr)[1],
                                                                                  16, 31)) or
                                        ((TInt32(Addr)[0] = 192) and (TInt32(Addr)[1] = 168));
  end; // .function IsLocalAddr
    
begin
  {!} Windows.EnterCriticalSection(InetCriticalSection);
  
  result := Ptr(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc(), [Name]));
  HostEnt := result;
  
  if HostEnt.h_length = sizeof(integer) then begin
    Addrs := pointer(HostEnt.h_addr_list);
    
    if (Addrs[0] <> nil) and IsLocalAddr(Addrs[0]^) then begin
      i := 1;

      while (Addrs[i] <> nil) and IsLocalAddr(Addrs[i]^) do begin
        Inc(i);
      end; // .while

      if Addrs[i] <> nil then begin
        Utils.Exchange(Addrs[0]^, Addrs[i]^);
      end; // .if
    end; // .if
  end; // .if
  
  {!} Windows.LeaveCriticalSection(InetCriticalSection);
end; // .function Hook_GetHostByName

function Hook_UN_C (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PPOINTER(Context.EBP - $0C)^  :=  GameExt.GetRealAddr(PPOINTER(Context.EBP - $0C)^);
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_UN_C

function Hook_ApplyDamage_Ebx (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.EBX :=  ZvsAppliedDamage^;
  result      :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Ebx

function Hook_ApplyDamage_Esi (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.ESI :=  ZvsAppliedDamage^;
  result      :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Esi

function Hook_ApplyDamage_Esi_Arg1 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.ESI                 :=  ZvsAppliedDamage^;
  PINTEGER(Context.EBP + $8)^ :=  ZvsAppliedDamage^;
  result                      :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Esi

function Hook_ApplyDamage_Arg1 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PINTEGER(Context.EBP + $8)^ :=  ZvsAppliedDamage^;
  result                      :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Arg1

function Hook_ApplyDamage_Ebx_Local7 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  Context.EBX                    := ZvsAppliedDamage^;
  PINTEGER(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Ebx_Local7

function Hook_ApplyDamage_Local7 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PINTEGER(Context.EBP - 7 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_ocal7

function Hook_ApplyDamage_Local4 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PINTEGER(Context.EBP - 4 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Local4

function Hook_ApplyDamage_Local8 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PINTEGER(Context.EBP - 8 * 4)^ := ZvsAppliedDamage^;
  result                         := Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Local8

function Hook_ApplyDamage_Local13 (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  PINTEGER(Context.EBP - 13 * 4)^ := ZvsAppliedDamage^;
  result                          := Core.EXEC_DEF_CODE;
end; // .function Hook_ApplyDamage_Local13

function Hook_GetWoGAndErmVersions (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  NEW_WOG_VERSION = 400;
  
begin
  PINTEGER(Context.EBP - $0C)^  :=  NEW_WOG_VERSION;
  PINTEGER(Context.EBP - $24)^  :=  GameExt.ERA_VERSION_INT;
  result                        :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_GetWoGAndErmVersions

function Hook_ZvsLib_ExtractDef (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  MIN_NUM_TOKENS  = 2;
  TOKEN_LODNAME   = 0;
  TOKEN_DEFNAME   = 1;
  
  EBP_ARG_IMAGE_TEMPLATE  = 16;

var
  ImageSettings:  string;
  Tokens:         StrLib.TArrayOfStr;
  LodName:        string;
  
begin
  ImageSettings :=  PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^;
  Tokens        :=  StrLib.Explode(ImageSettings, ';');

  if
    (Length(Tokens) >= MIN_NUM_TOKENS)  and
    (FindFileLod(Tokens[TOKEN_DEFNAME], LodName))
  then begin
    Tokens[TOKEN_LODNAME] :=  SysUtils.ExtractFileName(LodName);
    ZvsLibImageTemplate   :=  StrLib.Join(Tokens, ';');
    PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^ :=  pchar(ZvsLibImageTemplate);
  end; // .if
  
  //fatalerror(PPCHAR(Context.EBP + EBP_ARG_IMAGE_TEMPLATE)^);
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsLib_ExtractDef

function Hook_ZvsLib_ExtractDef_GetGamePath (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  EBP_LOCAL_GAME_PATH = 16;

begin
  ZvsLibGamePath  :=  SysUtils.ExtractFileDir(ParamStr(0));
  {!} Assert(Length(ZvsLibGamePath) > 0);
  // Increase string ref count for C++ Builder AnsiString
  Inc(PINTEGER(Utils.PtrOfs(pointer(ZvsLibGamePath), -8))^);
  
  PPCHAR(Context.EBP - EBP_LOCAL_GAME_PATH)^ :=  pchar(ZvsLibGamePath);
  Context.RetAddr :=  Utils.PtrOfs(Context.RetAddr, 486);
  result          :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_ZvsLib_ExtractDef_GetGamePath

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
const
  ZVSLIB_EXTRACTDEF_OFS             = 100668;
  ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS = 260;
  
  NOP7: string  = #$90#$90#$90#$90#$90#$90#$90;
  
var
  Zvslib1Handle:  integer;
  Addr:           integer;
  NewAddr:        pointer;

begin
  (* Ini handling *)
  Core.Hook(@Hook_ReadStrIni, Core.HOOKTYPE_JUMP, 5, ZvsReadStrIni);
  Core.Hook(@Hook_WriteStrIni, Core.HOOKTYPE_JUMP, 5, ZvsWriteStrIni);
  Core.Hook(@Hook_WriteIntIni, Core.HOOKTYPE_JUMP, 5, ZvsWriteIntIni);
  
  (* DL dialogs centering *)
  Core.Hook(@Hook_ZvsGetWindowWidth, Core.HOOKTYPE_BRIDGE, 5, Ptr($729C5A));
  Core.Hook(@Hook_ZvsGetWindowHeight, Core.HOOKTYPE_BRIDGE, 5, Ptr($729C6D));
  
  (* Mark the freshest savegame *)
  MarkFreshestSavegame;
  
  (* Fix multi-thread CPU problem *)
  if UseOnlyOneCpuCoreOpt then begin
    Windows.SetProcessAffinityMask(Windows.GetCurrentProcess, 1);
  end; // .if
  
  (* Fix HotSeat second hero name *)
  Core.Hook(@Hook_SetHotseatHeroName, Core.HOOKTYPE_BRIDGE, 6, Ptr($5125B0));
  Core.WriteAtCode(Length(NOP7), pointer(NOP7), Ptr($5125F9));
  
  (* Universal CPU patch *)
  if CPUPatchOpt then begin
    hTimerEvent := Windows.CreateEvent(nil, true, false, 'CPUPatch');
    
    Core.p.WriteHiHook
    (
      integer(Windows.GetProcAddress(GetModuleHandle('user32.dll'), 'PeekMessageA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_PeekMessageA
    );
  end; // .if
  
  (* Remove duplicate ResetAll call *)
  PINTEGER($7055BF)^ :=  integer($90909090);
  PBYTE($7055C3)^    :=  $90;
  
  (* Optimize zvslib1.dll ini handling *)
  Zvslib1Handle   :=  Windows.GetModuleHandle('zvslib1.dll');
  Addr            :=  Zvslib1Handle + 1666469;
  Addr            :=  PINTEGER(Addr + PINTEGER(Addr)^ + 6)^;
  NewAddr         :=  @New_Zvslib_GetPrivateProfileStringA;
  Core.WriteAtCode(sizeof(NewAddr), @NewAddr, pointer(Addr));
  
  (* Redirect reading/writing game settings to ini *)
  // No saving settings after reading them
  PBYTE($50B964)^     :=  $C3;
  PINTEGER($50B965)^  :=  integer($90909090);
  
  PPOINTER($50B920)^  :=  Ptr(integer(@ReadGameSettings) - $50B924);
  PPOINTER($50BA2F)^  :=  Ptr(integer(@WriteGameSettings) - $50BA33);
  PPOINTER($50C371)^  :=  Ptr(integer(@WriteGameSettings) - $50C375);
  
  (* Fix game version to enable map generator *)
  Heroes.GameVersion^ :=  Heroes.SOD_AND_AB;
  
  (* Fix gethostbyname function to return external IP address at first place *)
  if FixGetHostByNameOpt then begin
    Core.p.WriteHiHook
    (
      integer(Windows.GetProcAddress(Windows.GetModuleHandle('ws2_32.dll'), 'gethostbyname')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetHostByName
    );
  end; // .if
  
  (* Fix UN:C to work with redirected addresses also *)
  Core.ApiHook(@Hook_UN_C, Core.HOOKTYPE_BRIDGE, Ptr($732086));
  
  (* Fix ApplyDamage calls, so that !?MF1 damage is displayed correctly in log *)
  Core.ApiHook(@Hook_ApplyDamage_Ebx_Local7,  Core.HOOKTYPE_BRIDGE, Ptr($43F95B + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($43FA5E + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local7,      Core.HOOKTYPE_BRIDGE, Ptr($43FD3D + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($4400DF + 5));
  Core.ApiHook(@Hook_ApplyDamage_Esi_Arg1,    Core.HOOKTYPE_BRIDGE, Ptr($440858 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($440E70 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Arg1,        Core.HOOKTYPE_BRIDGE, Ptr($441048 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Esi,         Core.HOOKTYPE_BRIDGE, Ptr($44124C + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local4,      Core.HOOKTYPE_BRIDGE, Ptr($441739 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local8,      Core.HOOKTYPE_BRIDGE, Ptr($44178A + 5));
  Core.ApiHook(@Hook_ApplyDamage_Arg1,        Core.HOOKTYPE_BRIDGE, Ptr($46595F + 5));
  Core.ApiHook(@Hook_ApplyDamage_Ebx,         Core.HOOKTYPE_BRIDGE, Ptr($469A93 + 5));
  Core.ApiHook(@Hook_ApplyDamage_Local13,     Core.HOOKTYPE_BRIDGE, Ptr($5A1065 + 5));

  (* Fix negative offsets handling in fonts *)
  PBYTE($4B534A)^ :=  $B6;
  PBYTE($4B53E6)^ :=  $B6;
  
  (* Fix WoG/ERM versions *)
  Core.Hook(@Hook_GetWoGAndErmVersions, Core.HOOKTYPE_BRIDGE, 14, Ptr($73226C));
  
  (*  Fix zvslib1.dll ExtractDef function to support mods  *)
  Core.ApiHook
  (
    @Hook_ZvsLib_ExtractDef, Core.HOOKTYPE_BRIDGE, Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + 3)
  );
  
  Core.ApiHook
  (
    @Hook_ZvsLib_ExtractDef_GetGamePath,
    Core.HOOKTYPE_BRIDGE,
    Ptr(Zvslib1Handle + ZVSLIB_EXTRACTDEF_OFS + ZVSLIB_EXTRACTDEF_GETGAMEPATH_OFS)
  );
  
  (* Disable MP3 trigger *)
  // Overriden by Lodman redirection
  // Core.p.WriteHexPatch($59AC51, 'BF F4 33 6A 00');
end; // .procedure OnAfterWoG

begin
  Windows.InitializeCriticalSection(InetCriticalSection);
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
end.
