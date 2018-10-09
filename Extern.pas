unit Extern;
(*
  DESCRIPTION: API Wrappers for plugins
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)

uses Utils, Core, GameExt, Heroes, Erm, Ini, Rainbow, Stores, EraButtons, Lodman, Graph;


procedure FatalError (Err: pchar); stdcall;
procedure RegisterHandler (Handler: TEventHandler; EventName: pchar); stdcall;
procedure FireEvent (EventName: pchar; {n} EventData: pointer; DataSize: integer); stdcall;
procedure ExecErmCmd (CmdStr: pchar); stdcall;
procedure FireErmEvent (EventID: integer); stdcall;
procedure ClearIniCache (FileName: pchar);
function  ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): boolean; stdcall;
function  WriteStrToIni (Key, Value, SectionName, FilePath: pchar): boolean; stdcall;
function  SaveIni (FilePath: pchar): boolean; stdcall;
procedure NameColor (Color32: integer; Name: pchar); stdcall;
procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: pchar); stdcall;

function  ReadSavegameSection
(
      DataSize:     integer;
  {n} Dest:         pointer;
      SectionName:  pchar
): integer; stdcall;

function  GetButtonID (ButtonName: pchar): integer; stdcall;
function  PatchExists (PatchName: pchar): boolean; stdcall;
function  PluginExists (PluginName: pchar): boolean; stdcall;
procedure RedirectFile (OldFileName, NewFileName: pchar); stdcall;
procedure GlobalRedirectFile (OldFileName, NewFileName: pchar); stdcall;
function  LoadImageAsPcx16 (FilePath, PcxName: pchar; Width, Height: integer): {OU} Heroes.PPcx16Item; stdcall;
procedure ShowMessage (Mes: pchar);
function  Ask (Question: pchar): boolean;


exports
  Core.WriteAtCode,
  Core.Hook,
  Core.ApiHook,
  Core.KillThisProcess,
  FatalError,
  RegisterHandler,
  FireEvent,
  Heroes.LoadTxt,
  Heroes.ForceTxtUnload,
  ExecErmCmd,
  Erm.ReloadErm,
  Erm.ExtractErm,
  FireErmEvent,
  Ini.ClearAllIniCache,
  ClearIniCache,
  ReadStrFromIni,
  WriteStrToIni,
  SaveIni,
  NameColor,
  WriteSavegameSection,
  ReadSavegameSection,
  Heroes.GetGameState,
  GetButtonID,
  PatchExists,
  PluginExists,
  RedirectFile,
  GlobalRedirectFile,
  LoadImageAsPcx16,
  GameExt.RedirectMemoryBlock,
  GameExt.GetRealAddr,
  GameExt.GenerateDebugInfo,
  ShowMessage,
  Ask;


(***) implementation (***)


procedure NameColor (Color32: integer; Name: pchar);
begin
  Rainbow.NameColor(Color32, Name);
end;

procedure ClearIniCache (FileName: pchar);
begin
  Ini.ClearIniCache(FileName);
end;

function ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): boolean;
var
  ResStr: string;

begin
  result := Ini.ReadStrFromIni(Key, SectionName, FilePath, ResStr);
  Utils.CopyMem(Length(ResStr) + 1, pchar(ResStr), Res);
end;

function WriteStrToIni (Key, Value, SectionName, FilePath: pchar): boolean;
begin
  result := Ini.WriteStrToIni(Key, Value, SectionName, FilePath);
end;

function SaveIni (FilePath: pchar): boolean;
begin
  result := Ini.SaveIni(FilePath);
end;

procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: pchar);
begin
  Stores.WriteSavegameSection(DataSize, Data, SectionName);
end;

function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; SectionName: pchar): integer;
begin
  result := Stores.ReadSavegameSection(DataSize, Dest, SectionName);
end;

procedure ExecErmCmd (CmdStr: pchar);
begin
  Erm.ExecErmCmd(CmdStr);
end;

procedure FireErmEvent (EventID: integer);
begin
  Erm.FireErmEvent(EventID);
end;

procedure RegisterHandler (Handler: TEventHandler; EventName: pchar);
begin
  GameExt.RegisterHandler(Handler, EventName);
end;

procedure FireEvent (EventName: pchar; {n} EventData: pointer; DataSize: integer);
begin
  GameExt.FireEvent(EventName, EventData, DataSize);
end;

procedure FatalError (Err: pchar);
begin
  Core.FatalError(Err);
end;

function GetButtonID (ButtonName: pchar): integer; stdcall;
begin
  result := EraButtons.GetButtonID(ButtonName);
end;

function PatchExists (PatchName: pchar): boolean;
begin
  result := GameExt.PatchExists(PatchName);
end;

function PluginExists (PluginName: pchar): boolean;
begin
  result := GameExt.PluginExists(PluginName);
end;

procedure RedirectFile (OldFileName, NewFileName: pchar);
begin
  Lodman.RedirectFile(OldFileName, NewFileName);
end;

procedure GlobalRedirectFile (OldFileName, NewFileName: pchar);
begin
  Lodman.GlobalRedirectFile(OldFileName, NewFileName);
end;

{function tr (const Key: pchar; const Params: array of pchar): pchar; stdcall;
var
  ParamsList: StrLib.TArrayOfStr;

begin
  Translation := LangMap[Key];
  // * * * * * //
  SetLength(ParamsList, length(Params));
  
  if Translation <> nil then begin
    result := StrLib.BuildStr(Translation.Value, Params, TEMPL_CHAR);
  end else begin
    result := Key;
  end;
end; // .function tr}

function LoadImageAsPcx16 (FilePath, PcxName: pchar; Width, Height: integer): {OU} Heroes.PPcx16Item;
begin
  if FilePath = nil then begin
    FilePath := pchar('');
  end;

  if PcxName = nil then begin
    PcxName := pchar('');
  end;

  result := Graph.LoadImageAsPcx16(FilePath, PcxName, Width, Height);
end;

procedure ShowMessage (Mes: pchar);
begin
  Erm.ShowMessage(Mes);
end;

function Ask (Question: pchar): boolean;
begin
  result := Erm.Ask(Question);
end;

end.
