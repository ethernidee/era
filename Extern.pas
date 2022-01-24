unit Extern;
(*
  DESCRIPTION: API Wrappers for plugins
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)


uses
  Math,
  SysUtils,
  Windows,

  AdvErm,
  Alg,
  ApiJack,
  Core,
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

function tr (const Key: pchar; const Params: array of pchar): pchar; stdcall;
var
  ParamList:   Utils.TArrayOfStr;
  Translation: string;
  i:           integer;

begin
  SetLength(ParamList, length(Params));

  for i := 0 to High(Params) do begin
    ParamList[i] := Params[i];
  end;

  Translation := Trans.tr(Key, ParamList);
  result      := Externalize(Translation);
end; // .function tr

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

function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer): pointer; stdcall;
begin
  if AppliedPatch <> nil then begin
    New(ApiJack.PAppliedPatch(AppliedPatch^));
    AppliedPatch := AppliedPatch^;
  end;

  result := ApiJack.HookCode(Addr, HandlerFunc, ApiJack.PAppliedPatch(AppliedPatch));
end;

function GetArgXVars: PErmXVars; stdcall;
begin
  result := @Erm.ArgXVars;
end;

function GetRetXVars: PErmXVars; stdcall;
begin
  result := @Erm.RetXVars;
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

procedure ShowErmError (Error: pchar); stdcall;
begin
  if Error = nil then begin
    Error := '';
  end;

  Erm.ZvsErmError(nil, 0, Error);
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
procedure GetProcessGuid (Buf: pchar); stdcall;
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

  Utils.CopyMem(Length(ProcessGuid) + 1, pchar(ProcessGuid), Buf);
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

exports
  AdvErm.ExtendArrayLifetime,
  Ask,
  ClearIniCache,
  Core.ApiHook,
  Core.Hook,
  Core.WriteAtCode,
  DecorateInt,
  Erm.ExtractErm,
  Erm.GetDialog8SelectablePicsMask name '_GetDialog8SelectablePicsMask',
  Erm.GetPreselectedDialog8ItemId name '_GetPreselectedDialog8ItemId',
  Erm.ReloadErm,
  Erm.SetDialog8SelectablePicsMask name '_SetDialog8SelectablePicsMask',
  Erm.SetPreselectedDialog8ItemId name '_SetPreselectedDialog8ItemId',
  Erm_CompareStrings,
  Erm_CustomStableSortInt32Array,
  Erm_FillInt32Array,
  Erm_IntLog2,
  Erm_Pow,
  Erm_RevertInt32Array,
  Erm_SortInt32Array,
  Erm_SortStrArray,
  Erm_Sqrt,
  ExecErmCmd,
  FatalError,
  FindNextObject,
  FireErmEvent,
  FireEvent,
  FireRemoteEvent,
  FormatQuantity,
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
  GetVersion,
  GetVersionNum,
  GlobalRedirectFile,
  Graph.DecRef,
  Heroes.GetGameState,
  Heroes.LoadTxt,
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
  PluginExists,
  ReadSavegameSection,
  ReadStrFromIni,
  RedirectFile,
  RegisterErmReceiver,
  RegisterHandler,
  ReportPluginVersion,
  SaveIni,
  SetAssocVarIntValue,
  SetAssocVarStrValue,
  SetEraRegistryIntValue,
  SetEraRegistryStrValue,
  ShowErmError,
  ShowMessage,
  Splice,
  ToStaticStr,
  tr,
  WriteSavegameSection,
  WriteStrToIni;

begin
  IntRegistry := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  StrRegistry := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
end.
