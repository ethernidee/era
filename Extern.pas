unit Extern;
(*
  Description: API Wrappers for plugins
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)


uses
  Math,
  ShlwApi,
  SysUtils,
  Windows,

  AdvErm,
  Alg,
  ApiJack,
  Core,
  Crypto,
  DataLib,
  EraButtons,
  EraUtils,
  Erm,
  EventMan,
  GameExt,
  Graph,
  Heroes,
  Ini,
  Lodman,
  Memory,
  Network,
  Rainbow,
  Stores,
  StrLib,
  Trans,
  Triggers,
  Tweaks,
  TypeWrappers,
  Utils,
  WinUtils;

type
  (* Import *)
  TEventHandler = EventMan.TEventHandler;
  TDict         = DataLib.TDict;
  TString       = TypeWrappers.TString;

  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;

  TDwordBool = integer; // 0 or 1

  PAppliedPatch = ^TAppliedPatch;
  TAppliedPatch = packed record
  {O} Data: Utils.PEndlessByteArr;
      Size: integer;
  end;


(***) implementation (***)


var
{O} IntRegistry: {U} TDict {of Ptr(integer)};
{O} StrRegistry: {O} TDict {of TString};


const
  EXTERNAL_BUF_PREFIX_SIZE = sizeof(integer);


function AllocExternalBuf (Size: integer): {O} pointer;
begin
  {!} Assert(Size >= 0);
  GetMem(result, Size + EXTERNAL_BUF_PREFIX_SIZE);
  pinteger(result)^ := Size;
  Inc(integer(result), EXTERNAL_BUF_PREFIX_SIZE);
end;

function Externalize (const Str: AnsiString): {O} pointer; overload;
begin
  result := AllocExternalBuf(Length(Str) + 1);
  Utils.CopyMem(Length(Str) + 1, pchar(Str), result);
end;

function Externalize (const Str: WideString): {O} pointer; overload;
begin
  result := AllocExternalBuf((Length(Str) + 1) * sizeof(WideChar));
  Utils.CopyMem((Length(Str) + 1) * sizeof(WideChar), PWideChar(Str), result);
end;

(* Frees buffer, that was transfered to client earlier *)
procedure MemFree ({On} Buf: pointer); stdcall;
begin
  if Buf <> nil then begin
    FreeMem(Utils.PtrOfs(Buf, -EXTERNAL_BUF_PREFIX_SIZE));
  end;
end;

procedure NameColor (Color32: integer; Name: pchar); stdcall;
begin
  Rainbow.NameColor(Color32, Name);
end;

procedure NameTrigger (TriggerId: integer; Name: pchar); stdcall;
begin
  Erm.NameTrigger(TriggerId, Name);
end;

procedure ClearIniCache (FileName: pchar); stdcall;
begin
  Ini.ClearIniCache(FileName);
end;

function ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): TDwordBool; stdcall;
var
  ResStr: string;

begin
  result := TDwordBool(ord(Ini.ReadStrFromIni(Key, SectionName, FilePath, ResStr)));
  Utils.CopyMem(Length(ResStr) + 1, pchar(ResStr), Res);
end;

function WriteStrToIni (Key, Value, SectionName, FilePath: pchar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Ini.WriteStrToIni(Key, Value, SectionName, FilePath)));
end;

function SaveIni (FilePath: pchar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Ini.SaveIni(FilePath)));
end;

procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: pchar); stdcall;
begin
  Stores.WriteSavegameSection(DataSize, Data, SectionName);
end;

function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; SectionName: pchar): integer; stdcall;
begin
  result := Stores.ReadSavegameSection(DataSize, Dest, SectionName);
end;

procedure ExecErmCmd (CmdStr: pchar); stdcall;
begin
  Erm.ExecErmCmd(CmdStr);
end;

(* Compiles single ERM command without !! prefix and conditions and saves its compiled code in persisted memory storage.
   Returns non-nil opaque pointer on success and nil on failure. Trailing semicolon is optional *)
function PersistErmCmd (CmdStr: pchar): {n} pointer; stdcall;
begin
  result := Erm.CompileErmCmd(CmdStr);
end;

(* Executes previously compiled and persisted ERM command. Use PersistErmCmd API for compilation *)
procedure ExecPersistedErmCmd (PersistedCmd: pointer); stdcall;
begin
  Erm.ZvsProcessCmd(@Erm.PCompiledErmCmd(PersistedCmd).Cmd);
end;

procedure FireErmEvent (EventID: integer); stdcall;
begin
  Erm.FireErmEvent(EventID);
end;

procedure RegisterHandler (Handler: TEventHandler; EventName: pchar); stdcall;
begin
  EventMan.GetInstance.On(EventName, Handler);
end;

procedure FireEvent (EventName: pchar; {n} EventData: pointer; DataSize: integer); stdcall;
begin
  EventMan.GetInstance.Fire(EventName, EventData, DataSize);
end;

procedure FatalError (Err: pchar); stdcall;
begin
  Core.FatalError(Err);
end;

procedure NotifyError (Err: pchar); stdcall;
begin
  Core.NotifyError(Err);
end;

function GetButtonID (ButtonName: pchar): integer; stdcall;
begin
  result := EraButtons.GetButtonID(ButtonName);
end;

function PatchExists (PatchName: pchar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(GameExt.PatchExists(PatchName)));
end;

function PluginExists (PluginName: pchar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(GameExt.PluginExists(PluginName)));
end;

procedure RedirectFile (OldFileName, NewFileName: pchar); stdcall;
begin
  Lodman.RedirectFile(OldFileName, NewFileName);
end;

procedure GlobalRedirectFile (OldFileName, NewFileName: pchar); stdcall;
begin
  Lodman.GlobalRedirectFile(OldFileName, NewFileName);
end;

function TakeScreenshot (FilePath: pchar; Quality: integer; Flags: integer): TDwordBool; stdcall;
begin
  result := ord(Graph.TakeScreenshot(FilePath, Quality, Flags));
end;

function tr (const Key: pchar; const Params: array of pchar): pchar; stdcall;
var
  ParamList:   Utils.TArrayOfStr;
  Translation: string;
  i:           integer;

begin
  SetLength(ParamList, Length(Params) and not 1);

  for i := 0 to Length(ParamList) - 1 do begin
    ParamList[i] := Params[i];
  end;

  Translation := Trans.tr(Key, ParamList);
  result      := Externalize(Translation);
end;

var
  trTempBuf: string;

function trTemp (const Key: pchar; const Params: array of pchar): pchar; stdcall;
var
  ParamList: Utils.TArrayOfStr;
  i:         integer;

begin
  SetLength(ParamList, Length(Params) and not 1);

  for i := 0 to Length(ParamList) - 1 do begin
    ParamList[i] := Params[i];
  end;

  trTempBuf := Trans.tr(Key, ParamList);
  result    := pchar(trTempBuf);
end;

function trStatic (const Key: pchar): pchar; stdcall;
begin
  result := Memory.UniqueStrings[pchar(Trans.tr(Key, []))];
end;

function SetLanguage (NewLanguage: pchar): TDwordBool; stdcall;
begin
  result := ord(Trans.SetLanguage(NewLanguage));
end;

function LoadImageAsPcx16 (FilePath, PcxName: pchar; Width, Height, MaxWidth, MaxHeight, ResizeAlg: integer): {OU} Heroes.PPcx16Item; stdcall;
begin
  if FilePath = nil then begin
    FilePath := pchar('');
  end;

  if PcxName = nil then begin
    PcxName := pchar('');
  end;

  if (ResizeAlg < ord(Low(Graph.TResizeAlg))) or (ResizeAlg > ord(High(Graph.TResizeAlg))) then begin
    Core.NotifyError('Invalid ResizeAlg argument for LoadImageAsPcx16: ' + SysUtils.IntToStr(ResizeAlg));
    ResizeAlg := ord(Graph.ALG_DOWNSCALE);
  end;

  result := Graph.LoadImageAsPcx16(FilePath, PcxName, Width, Height, MaxWidth, MaxHeight, TResizeAlg(ResizeAlg));
end;

procedure ShowMessage (Mes: pchar); stdcall;
begin
  Heroes.ShowMessage(Mes);
end;

function Ask (Question: pchar): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Heroes.Ask(Question)));
end;

procedure ReportPluginVersion (const VersionLine: pchar); stdcall;
begin
  GameExt.ReportPluginVersion(VersionLine);
end;

function GetVersion: pchar; stdcall;
begin
  result := GameExt.ERA_VERSION_STR;
end;

function GetVersionNum: integer; stdcall;
begin
  result := GameExt.ERA_VERSION_INT;
end;

function Splice (OrigFunc, HandlerFunc: pointer; CallingConv: integer; NumArgs: integer; {n} CustomParam: pinteger; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  {!} Assert((CallingConv >= ord(ApiJack.CONV_FIRST)) and (CallingConv <= ord(ApiJack.CONV_LAST)), Format('Splice: Invalid calling convention: %d', [CallingConv]));
  {!} Assert(NumArgs >= 0, Format('Splice>> Invalid arguments number: %d', [NumArgs]));
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  result := ApiJack.StdSplice(OrigFunc, HandlerFunc, ApiJack.TCallingConv(CallingConv), NumArgs, CustomParam, ApiJack.PAppliedPatch(AppliedPatch));
end;

(* Installs new hook at specified address. Returns pointer to bridge with original code. Optionally specify address of a pointer to write applied patch structure pointer to.
   It will allow to rollback the patch later. *)
function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  result := ApiJack.HookCode(Addr, HandlerFunc, ApiJack.PAppliedPatch(AppliedPatch));
end;

function CalcHookPatchSize (Addr: pointer): integer; stdcall;
begin
  result := ApiJack.CalcHookPatchSize(Addr);
end;

(* The patch will be rollback and internal memory and freed. Do not use it anymore *)
procedure RollbackAppliedPatch ({O} AppliedPatch: pointer); stdcall;
begin
  {!} Assert(AppliedPatch <> nil);
  ApiJack.PAppliedPatch(AppliedPatch).Rollback;
  Dispose(AppliedPatch);
end;

(* Frees applied patch structure. Use it if you don't plan to rollback it anymore *)
procedure FreeAppliedPatch ({O} AppliedPatch: pointer); stdcall;
begin
  if AppliedPatch <> nil then begin
    Dispose(AppliedPatch);
  end;
end;

(* Deprecated legacy. Use HookCode instead *)
function ApiHook (HandlerAddr: pointer; HookType: integer; CodeAddr: pointer): {n} pointer; stdcall;
begin
  result := Core.Hook(CodeAddr, HookType, HandlerAddr);
end;

procedure Hook (HandlerAddr: pointer; HookType: integer; PatchSize: integer; CodeAddr: pointer); stdcall;
begin
  Heroes.ShowMessage('"Hook" function is not supported anymore. Use "HookCode" instead');
end;

function GetArgXVars: PErmXVars; stdcall;
begin
  result := @Erm.ArgXVars;
end;

function GetRetXVars: PErmXVars; stdcall;
begin
  result := @Erm.RetXVars;
end;

function GetTriggerReadableName (EventId: integer): {O} pchar; stdcall;
begin
  result := Externalize(Erm.GetTriggerReadableName(EventId));
end;

procedure RegisterErmReceiver (const Cmd: pchar; {n} Handler: TErmCmdHandler; ParamsConfig: integer); stdcall;
begin
  AdvErm.RegisterErmReceiver(Cmd[0] + Cmd[1], Handler, ParamsConfig);
end;

procedure Erm_SortInt32Array (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
begin
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, Alg.IntCompare);
end;

function CustomStrComparator (Str1, Str2: integer; {n} State: pointer): integer;
begin
  result := StrLib.ComparePchars(pchar(Str1), pchar(Str2));
end;

procedure Erm_SortStrArray (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
begin
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, CustomStrComparator);
end;

type
  PErmCustomCompareFuncInfo = ^TErmCustomCompareFuncInfo;
  TErmCustomCompareFuncInfo = record
    FuncId: integer;
    State:  pointer;
  end;

function _ErmCustomCompareFuncBridge (Value1, Value2: integer; {n} State: pointer): integer;
const
  ARG_VALUE1 = 1;
  ARG_VALUE2 = 2;
  ARG_STATE  = 3;
  ARG_RESULT = 4;

begin
  Erm.ArgXVars[ARG_VALUE1] := Value1;
  Erm.ArgXVars[ARG_VALUE2] := Value2;
  Erm.ArgXVars[ARG_STATE]  := integer(PErmCustomCompareFuncInfo(State).State);
  Erm.ArgXVars[ARG_RESULT] := 0;
  Erm.FireErmEvent(PErmCustomCompareFuncInfo(State).FuncId);
  result := Erm.RetXVars[ARG_RESULT];
end;

procedure Erm_CustomStableSortInt32Array (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: integer; ComparatorFuncId: integer; {n} State: pointer); stdcall;
var
  CompareFuncInfo: TErmCustomCompareFuncInfo;

begin
  CompareFuncInfo.FuncId := ComparatorFuncId;
  CompareFuncInfo.State  := State;
  Alg.CustomMergeSortInt32(Arr, MinInd, MaxInd, _ErmCustomCompareFuncBridge, @CompareFuncInfo);
end;

procedure Erm_RevertInt32Array (Arr: Utils.PEndlessIntArr; MinInd, MaxInd: integer); stdcall;
var
  LeftInd:  integer;
  RightInd: integer;
  Temp:     integer;

begin
  LeftInd  := MinInd;
  RightInd := MaxInd;

  while LeftInd < RightInd do begin
    Temp          := Arr[LeftInd];
    Arr[LeftInd]  := Arr[RightInd];
    Arr[RightInd] := Temp;

    Inc(LeftInd);
    Dec(RightInd);
  end;
end; // .procedure Erm_RevertInt32Array

procedure Erm_FillInt32Array (Arr: Utils.PEndlessIntArr; MinInd, MaxInd, StartValue, Step: integer); stdcall;
var
  i: integer;

begin
  for i := MinInd to MaxInd do begin
    Arr[i] := StartValue;
    Inc(StartValue, Step);
  end;
end;

function Erm_Sqrt (Value: single): single; stdcall;
begin
  result := Sqrt(Value);
end;

function Erm_Pow (Base, Power: single): single; stdcall;
begin
  result := Math.Power(Base, Power);
end;

function Erm_IntLog2 (Value: integer): integer; stdcall;
begin
  result := Alg.IntLog2(Value);
end;

function Erm_CompareStrings (Addr1, Addr2: pchar): integer; stdcall;
begin
  result := StrLib.ComparePchars(Addr1, Addr2);
end;

(* Returns substring of original string in the form of new trigger-local ert z-var index *)
function Erm_Substr (Str: pchar; Offset, Count: integer): integer; stdcall;
var
  Res:    string;
  StrLen: integer;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    StrLen := Windows.LStrLen(Str);
    Res    := '';

    if Offset < 0 then begin
      Offset := Math.Max(0, StrLen + Offset);
    end;

    if Count < 0 then begin
      Inc(Count, StrLen);
    end;

    if (StrLen > 0) and (Offset < StrLen) and (Count > 0) then begin
      Count := Math.Min(StrLen - Offset, Count);
      SetLength(Res, Count);
      Utils.CopyMem(Count, @Str[Offset], pointer(Res));
    end;

    result := Erm.CreateTriggerLocalErt(pchar(Res), Length(Res));
  end;
end;

function Erm_StrPos (Where, What: pchar; Offset: integer): integer; stdcall;
var
  WhereLen: integer;
  FoundPos: pchar;

begin
  result := -1;

  if Offset <> 0 then begin
    if Offset < 0 then begin
      exit;
    end;

    WhereLen := StrLib.StrLen(Where);

    if Offset >= WhereLen then begin
      exit;
    end;

    FoundPos := ShlwApi.StrStrA(Utils.PtrOfs(Where, Offset), What);
  end else begin
    FoundPos := ShlwApi.StrStrA(Where, What);
  end;

  if FoundPos <> nil then begin
    result := integer(FoundPos) - integer(Where);
  end;
end;

(* Replaces What strings inside Where string with Replacement strings and returns new trigger-local ert z-var index *)
function Erm_StrReplace (Where, What, Replacement: pchar): integer; stdcall;
var
  Res: string;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    Res    := SysUtils.StringReplace(Where, What, Replacement, [SysUtils.rfReplaceAll]);
    result := Erm.CreateTriggerLocalErt(pchar(Res), Length(Res));
  end;
end;

(* Trims string and returns new trigger-local ert z-var index *)
function Erm_StrTrim (Str: pchar): integer; stdcall;
var
  Res: string;

begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    Res    := SysUtils.Trim(Str);
    result := Erm.CreateTriggerLocalErt(pchar(Res), Length(Res));
  end;
end;

(* Interpolates ERM variables inside string (%v1, etc) and returns newtrigger-local ert z-var index *)
function Erm_Interpolate (Str: pchar): integer; stdcall;
begin
  result := 0;

  if Erm.ErmTriggerDepth > 0 then begin
    result := Erm.CreateTriggerLocalErt(Erm.InterpolateErmStr(Str));
  end;
end;

procedure ShowErmError (Error: pchar); stdcall;
begin
  if Error = nil then begin
    Error := '';
  end;

  Erm.ZvsErmError(nil, 0, Error);
end;

function AllocErmFunc (FuncName: pchar; {i} out FuncId: integer): TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Erm.AllocErmFunc(FuncName, FuncId)));
end;

function FindNextObject (ObjType, ObjSubtype: integer; var x, y, z: integer; Direction: integer): integer; stdcall;
begin
  result := ord(not Heroes.ZvsFindNextObjects(ObjType, ObjSubtype, x, y, z, Direction));
end;

function ToStaticStr ({n} Str: pchar): {n} pchar; stdcall;
begin
  result := Memory.UniqueStrings[Str];
end;

function DecorateInt (Value: integer; Buf: pchar; IgnoreSmallNumbers: integer): integer; stdcall;
var
  Str: string;

begin
  Str := EraUtils.DecorateInt(Value, IgnoreSmallNumbers <> 0);
  Utils.SetPcharValue(Buf, Str, High(integer));
  result := Length(Str);
end;

function FormatQuantity (Value: integer; Buf: pchar; BufSize: integer; MaxLen, MaxDigits: integer): integer; stdcall;
var
  Str: string;

begin
  Str := EraUtils.FormatQuantity(Value, MaxLen, MaxDigits);
  Utils.SetPcharValue(Buf, Str, BufSize);
  result := Length(Str);
end;

var
  (* Global unique process GUID, generated on demand *)
  ProcessGuid: string;

(* Returns 32-character unique key for current game process. The ID will be unique between multiple game runs. *)
function GetProcessGuid: pchar; stdcall;
var
  ProcessGuidBuf: array [0..sizeof(GameExt.ProcessStartTime) - 1] of byte;

begin
  if ProcessGuid = '' then begin
    FillChar(ProcessGuidBuf, sizeof(ProcessGuidBuf), #0);

    if not WinUtils.RtlGenRandom(@ProcessGuidBuf, sizeof(ProcessGuidBuf)) then begin
      Utils.CopyMem(sizeof(GameExt.ProcessStartTime), @GameExt.ProcessStartTime, @ProcessGuidBuf);
    end;

    ProcessGuid := StrLib.BinToHex(sizeof(ProcessGuidBuf), @ProcessGuidBuf);
  end;

  result := pchar(ProcessGuid);
end;

function IsCampaign: TDwordBool; stdcall;
begin
  result := TDwordBool(ord(Heroes.IsCampaign));
end;

procedure GetCampaignFileName (Buf: pchar); stdcall;
begin
  Utils.SetPcharValue(Buf, Heroes.GetCampaignFileName, sizeof(Erm.z[1]));
end;

procedure GetMapFileName (Buf: pchar); stdcall;
begin
  Utils.SetPcharValue(Buf, Heroes.GetMapFileName, sizeof(Erm.z[1]));
end;

function GetCampaignMapInd: integer; stdcall;
begin
  result := Heroes.GetCampaignMapInd;
end;

function GetAssocVarIntValue (const VarName: pchar): integer; stdcall;
var
  AssocVar: AdvErm.TAssocVar;

begin
  AssocVar := AdvErm.AssocMem[VarName];
  result   := 0;

  if AssocVar <> nil then begin
    result := AssocVar.IntValue;
  end;
end;

function GetAssocVarStrValue (const VarName: pchar): {O} pchar; stdcall;
var
  AssocVar: AdvErm.TAssocVar;

begin
  AssocVar := AdvErm.AssocMem[VarName];

  if AssocVar <> nil then begin
    result := Externalize(AssocVar.StrValue);
  end else begin
    result := Externalize('');
  end;
end;

procedure SetAssocVarIntValue (const VarName: pchar; NewValue: integer); stdcall;
begin
  AdvErm.GetOrCreateAssocVar(VarName).IntValue := NewValue;
end;

procedure SetAssocVarStrValue (const VarName, NewValue: pchar); stdcall;
begin
  AdvErm.GetOrCreateAssocVar(VarName).StrValue := NewValue;
end;

function GetEraRegistryIntValue (const Key: pchar): integer; stdcall;
begin
  result := integer(IntRegistry[Key]);
end;

procedure SetEraRegistryIntValue (const Key: pchar; NewValue: integer); stdcall;
begin
  IntRegistry[Key] := Ptr(NewValue);
end;

function GetEraRegistryStrValue (const Key: pchar): {O} pchar; stdcall;
begin
  result := StrRegistry[Key];

  if result <> nil then begin
    result := Externalize(TString(result).Value);
  end else begin
    result := Externalize('');
  end;
end;

procedure SetEraRegistryStrValue (const Key: pchar; NewValue: pchar); stdcall;
begin
  StrRegistry[Key] := TString.Create(NewValue);
end;

function PcxPngExists (const PcxName: pchar): TDwordBool; stdcall;
begin
  result := ord(Graph.PcxPngExists(PcxName));
end;

function FireRemoteEvent (DestPlayerId: integer; EventName: pchar; {n} Data: pointer; DataSize: integer; {n} ProgressHandler: Network.TNetworkStreamProgressHandler;
                                 {n} ProgressHandlerCustomParam: pointer): TDwordBool; stdcall;
begin
  result := ord(Network.FireRemoteEvent(DestPlayerId, EventName, Data, DataSize, ProgressHandler, ProgressHandlerCustomParam));
end;

function Hash32 (Data: pchar; DataSize: integer): integer; stdcall;
begin
  result := Crypto.FastHash(Data, DataSize);
end;

function _SplitMix32 (var Seed: integer): integer;
begin
  Inc(Seed, integer($9E3779B9));
  result := Seed xor (Seed shr 15);
  result := result * integer($85EBCA6B);
  result := result xor (result shr 13);
  result := result * integer($C2B2AE35);
  result := result xor (result shr 16);
end;

function SplitMix32 (var Seed: integer; MinValue, MaxValue: integer): integer; stdcall;
var
  RangeLen:         cardinal;
  MaxUnbiasedValue: cardinal;
  i:                integer;

begin
  if MinValue >= MaxValue then begin
    result := MinValue;
    exit;
  end;

  if (MinValue = Low(integer)) and (MaxValue = High(integer)) then begin
    result := _SplitMix32(Seed);
    exit;
  end;

  RangeLen         := cardinal(MaxValue - MinValue + 1);
  MaxUnbiasedValue := High(cardinal) div RangeLen * RangeLen - 1;

  for i := 0 to 100 do begin
    result := _SplitMix32(Seed);

    if cardinal(result) <= MaxUnbiasedValue then begin
      break;
    end;
  end;

  result := MinValue + integer(cardinal(result) mod RangeLen);
end;

exports
  AdvErm.ExtendArrayLifetime,
  AllocErmFunc,
  ApiHook,
  Ask,
  CalcHookPatchSize,
  ClearIniCache,
  Core.WriteAtCode,
  DecorateInt,
  Erm.DisableErmTracking,
  Erm.EnableErmTracking,
  Erm.ExtractErm,
  Erm.GetDialog8SelectablePicsMask name '_GetDialog8SelectablePicsMask',
  Erm.GetPreselectedDialog8ItemId name '_GetPreselectedDialog8ItemId',
  Erm.ReloadErm,
  Erm.ResetErmTracking,
  Erm.RestoreErmTracking,
  Erm.SetDialog8SelectablePicsMask name '_SetDialog8SelectablePicsMask',
  Erm.SetPreselectedDialog8ItemId name '_SetPreselectedDialog8ItemId',
  Erm_CompareStrings,
  Erm_CustomStableSortInt32Array,
  Erm_FillInt32Array,
  Erm_Interpolate,
  Erm_IntLog2,
  Erm_Pow,
  Erm_RevertInt32Array,
  Erm_SortInt32Array,
  Erm_SortStrArray,
  Erm_Sqrt,
  Erm_StrPos,
  Erm_StrReplace,
  Erm_StrTrim,
  Erm_Substr,
  ExecErmCmd,
  ExecPersistedErmCmd,
  FatalError,
  FindNextObject,
  FireErmEvent,
  FireEvent,
  FireRemoteEvent,
  FormatQuantity,
  FreeAppliedPatch,
  GameExt.GenerateDebugInfo,
  GameExt.GetRealAddr,
  GameExt.RedirectMemoryBlock,
  GetArgXVars,
  GetAssocVarIntValue,
  GetAssocVarStrValue,
  GetButtonID,
  GetCampaignFileName,
  GetCampaignMapInd,
  GetEraRegistryIntValue,
  GetEraRegistryStrValue,
  GetMapFileName,
  GetProcessGuid,
  GetRetXVars,
  GetTriggerReadableName,
  GetVersion,
  GetVersionNum,
  GlobalRedirectFile,
  Graph.DecRef,
  Hash32,
  Heroes.GetGameState,
  Heroes.LoadTxt,
  Hook,
  HookCode,
  Ini.ClearAllIniCache,
  IsCampaign,
  LoadImageAsPcx16,
  MemFree,
  NameColor,
  NameTrigger,
  NotifyError,
  PatchExists,
  PcxPngExists,
  PersistErmCmd,
  PluginExists,
  ReadSavegameSection,
  ReadStrFromIni,
  RedirectFile,
  RegisterErmReceiver,
  RegisterHandler,
  ReportPluginVersion,
  RollbackAppliedPatch,
  SaveIni,
  SetAssocVarIntValue,
  SetAssocVarStrValue,
  SetEraRegistryIntValue,
  SetEraRegistryStrValue,
  SetLanguage,
  ShowErmError,
  ShowMessage,
  Splice,
  SplitMix32,
  TakeScreenshot,
  ToStaticStr,
  tr,
  Trans.ReloadLanguageData,
  Triggers.FastQuitToGameMenu,
  Triggers.SetRegenerationAbility,
  Triggers.SetStdRegenerationEffect,
  trStatic,
  trTemp,
  Tweaks.RandomRangeWithFreeParam,
  WriteSavegameSection,
  WriteStrToIni;

begin
  IntRegistry := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  StrRegistry := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
end.
