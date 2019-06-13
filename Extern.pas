unit Extern;
(*
  DESCRIPTION: API Wrappers for plugins
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)

uses
  Utils, Core, ApiJack,
  GameExt, Heroes, Erm, Ini, Rainbow, Stores,
  EraButtons, Lodman, Graph, Trans, EventMan;

type
  (* Import *)
  TEventHandler = EventMan.TEventHandler;


(***) implementation (***)


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

(* Frees buffer, that was transfered to client earlier using other VFS API *)
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

procedure ClearIniCache (FileName: pchar); stdcall;
begin
  Ini.ClearIniCache(FileName);
end;

function ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): boolean; stdcall;
var
  ResStr: string;

begin
  result := Ini.ReadStrFromIni(Key, SectionName, FilePath, ResStr);
  Utils.CopyMem(Length(ResStr) + 1, pchar(ResStr), Res);
end;

function WriteStrToIni (Key, Value, SectionName, FilePath: pchar): boolean; stdcall;
begin
  result := Ini.WriteStrToIni(Key, Value, SectionName, FilePath);
end;

function SaveIni (FilePath: pchar): boolean; stdcall;
begin
  result := Ini.SaveIni(FilePath);
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
  GameExt.FireEvent(EventName, EventData, DataSize);
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

function PatchExists (PatchName: pchar): boolean; stdcall;
begin
  result := GameExt.PatchExists(PatchName);
end;

function PluginExists (PluginName: pchar): boolean; stdcall;
begin
  result := GameExt.PluginExists(PluginName);
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

function LoadImageAsPcx16 (FilePath, PcxName: pchar; Width, Height: integer): {OU} Heroes.PPcx16Item; stdcall;
begin
  if FilePath = nil then begin
    FilePath := pchar('');
  end;

  if PcxName = nil then begin
    PcxName := pchar('');
  end;

  result := Graph.LoadImageAsPcx16(FilePath, PcxName, Width, Height);
end;

procedure ShowMessage (Mes: pchar); stdcall;
begin
  Erm.ShowMessage(Mes);
end;

function Ask (Question: pchar): boolean; stdcall;
begin
  result := Erm.Ask(Question);
end;

procedure ReportPluginVersion (const VersionLine: pchar); stdcall;
begin
  GameExt.ReportPluginVersion(VersionLine);
end;

function GetVersion: pchar; stdcall;
begin
  result := GameExt.ERA_VERSION_STR;
end;

function Splice (OrigFunc, HandlerFunc: pointer): pointer; stdcall;
begin
  result := ApiJack.Splice(OrigFunc, HandlerFunc);
end;

function HookCode (Addr: pointer; HandlerFunc: THookHandler): pointer; stdcall;
begin
  result := ApiJack.HookCode(Addr, HandlerFunc);
end;

exports
  Ask,
  ClearIniCache,
  Core.ApiHook,
  Core.Hook,
  Core.WriteAtCode,
  Erm.ExtractErm,
  Erm.ReloadErm,
  ExecErmCmd,
  FatalError,
  FireErmEvent,
  FireEvent,
  GameExt.GenerateDebugInfo,
  GameExt.GetRealAddr,
  GameExt.RedirectMemoryBlock,
  GetButtonID,
  GetVersion,
  GlobalRedirectFile,
  Heroes.GetGameState,
  Heroes.LoadTxt,
  HookCode,
  Ini.ClearAllIniCache,
  LoadImageAsPcx16,
  MemFree,
  NameColor,
  NotifyError,
  PatchExists,
  PluginExists,
  ReadSavegameSection,
  ReadStrFromIni,
  RedirectFile,
  RegisterHandler,
  ReportPluginVersion,
  SaveIni,
  ShowMessage,
  Splice,
  tr,
  WriteSavegameSection,
  WriteStrToIni;

end.
