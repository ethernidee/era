unit Era;
(*
  Description: Era SDK
  Author:      Alexander Shostak aka Berserker
*)

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

(***)  interface  (***)

uses Windows;


type
  PHookContext = ^THookContext;
  THookContext = packed record
    EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer;
    RetAddr:                                pointer;
  end;

  THookHandler = function (Context: PHookContext): LONGBOOL; stdcall;

  PEvent = ^TEvent;
  TEvent = packed record
      Name:     pchar;
  {n} Data:     pointer;
      DataSize: integer;
  end;

  TEventHandler = procedure (Event: PEvent) stdcall;

  PErmVVars = ^TErmVVars;
  TErmVVars = array [1..10000] of integer;
  TErmZVar  = array [0..511] of char;
  PErmZVars = ^TErmZVars;
  TErmZVars = array [1..1000] of TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = array [1..100] of integer;
  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;
  PErmFlags = ^TErmFlags;
  TErmFlags = array [1..1000] of boolean;
  PErmEVars = ^TErmEVars;
  TErmEVars = array [1..100] of single;

  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end;

  TDwordBool = integer; // 0 or 1

  (* Stubs *)
  PPcx16Item = pointer;


{$IFDEF FPC}
var
(* WoG vars *)
  v: TErmVVars absolute $887668;
  z: TErmZVars absolute $9273E8;
  y: TErmYVars absolute $A48D80;
  x: TErmXVars absolute $91DA38;
  f: TErmFlags absolute $91F2E0;
  e: TErmEVars absolute $A48F18;
{$ELSE}
const
  (* WoG vars *)
  v:  PErmVVars = Ptr($887668);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);
{$ENDIF}


function CalcHookPatchSize (Addr: pointer): integer; stdcall; external 'era.dll' name 'CalcHookPatchSize';
function GetArgXVars: PErmXVars; stdcall; external 'era.dll' name 'GetArgXVars';
function GetButtonID (ButtonName: pchar): integer; stdcall; external 'era.dll' name 'GetButtonID';
function GetRealAddr (Addr: pointer): pointer; stdcall; external 'era.dll' name 'GetRealAddr';
function GetRetXVars: PErmXVars; stdcall; external 'era.dll' name 'GetRetXVars';
function GetTriggerReadableName (EventId: integer): {O} pchar; stdcall; external 'era.dll' name 'GetTriggerReadableName';
function GetVersion: pchar; stdcall; external 'era.dll' name 'GetVersion';
function GetVersionNum: integer; stdcall; external 'era.dll' name 'GetVersionNum';
function HookCode (Addr: pointer; HandlerFunc: THookHandler; {n} AppliedPatch: ppointer = nil): pointer; stdcall; external 'era.dll' name 'HookCode';
function LoadImageAsPcx16 (FilePath, PcxName: pchar; Width, Height, MaxWidth, MaxHeight, ResizeAlg: integer): {OU} PPcx16Item; stdcall; external 'era.dll' name 'LoadImageAsPcx16';
function PatchExists (PatchName: pchar): boolean; stdcall; external 'era.dll' name 'PatchExists';
function PersistErmCmd (CmdStr: pchar): {n} pointer; stdcall;
function PluginExists (PluginName: pchar): boolean; stdcall; external 'era.dll' name 'PluginExists';
function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; SectionName: pchar ): integer; stdcall; external 'era.dll' name 'ReadSavegameSection';
function ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): boolean; stdcall; external 'era.dll' name 'ReadStrFromIni';
function SaveIni (FilePath: pchar): boolean; stdcall; external 'era.dll' name 'SaveIni';
function SetLanguage (NewLanguage: pchar): TDwordBool; stdcall; external 'era.dll' name 'SetLanguage';
function Splice (OrigFunc, HandlerFunc: pointer; CallingConv: integer; NumArgs: integer; {n} CustomParam: pinteger; {n} AppliedPatch: ppointer): pointer; stdcall; external 'era.dll' name 'Splice';
function TakeScreenshot (FilePath: pchar; Quality: integer; Flags: integer): TDwordBool; stdcall; external 'era.dll' name 'TakeScreenshot';
function tr (const Key: pchar; const Params: array of pchar): pchar; stdcall; external 'era.dll' name 'tr';
function WriteStrToIni (Key, Value, SectionName, FilePath: pchar): boolean; stdcall; external 'era.dll' name 'WriteStrToIni';
procedure ClearAllIniCache; external 'era.dll' name 'ClearAllIniCache';
procedure ClearIniCache (FileName: pchar); stdcall; external 'era.dll' name 'ClearIniCache';
procedure ExecErmCmd (CmdStr: pchar); stdcall; external 'era.dll' name 'ExecErmCmd';
procedure ExecPersistedErmCmd (PersistedCmd: pointer); stdcall;
procedure ExtractErm; external 'era.dll' name 'ExtractErm';
procedure FatalError (Err: pchar); stdcall; external 'era.dll' name 'FatalError';
procedure FireErmEvent (EventID: integer); stdcall; external 'era.dll' name 'FireErmEvent';
procedure FireEvent (EventName: pchar; {n} EventData: pointer; DataSize: integer); stdcall; external 'era.dll' name 'FireEvent';
procedure GenerateDebugInfo; external 'era.dll' name 'GenerateDebugInfo';
procedure GetGameState (var GameState: TGameState); stdcall; external 'era.dll' name 'GetGameState';
procedure GlobalRedirectFile (OldFileName, NewFileName: pchar); stdcall; external 'era.dll' name 'GlobalRedirectFile';
procedure MemFree ({On} Buf: pointer); stdcall; external 'era.dll' name 'MemFree';
procedure NameColor (Color32: integer; Name: pchar); stdcall; external 'era.dll' name 'NameColor';
procedure NameTrigger (TriggerId: integer; Name: pchar); stdcall; external 'era.dll' name 'NameTrigger';
procedure RedirectFile (OldFileName, NewFileName: pchar); stdcall; external 'era.dll' name 'RedirectFile';
procedure RedirectMemoryBlock (OldAddr: pointer; BlockSize: integer; NewAddr: pointer); stdcall; external 'era.dll' name 'RedirectMemoryBlock';
procedure RegisterHandler (Handler: TEventHandler; EventName: pchar); stdcall; external 'era.dll' name 'RegisterHandler';
procedure ReloadErm; external 'era.dll' name 'ReloadErm';
procedure ReportPluginVersion (const VersionLine: pchar); stdcall; external 'era.dll' name 'ReportPluginVersion';
procedure RollbackAppliedPatch ({O} AppliedPatch: pointer); stdcall; external 'era.dll' name 'RollbackAppliedPatch';
procedure ShowMessage (Mes: pchar); stdcall; external 'era.dll' name 'ShowMessage';
procedure WriteAtCode (Count: integer; Src, Dst: pointer); stdcall; external 'era.dll' name 'WriteAtCode';
procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: pchar); stdcall; external 'era.dll' name 'WriteSavegameSection';


(***)  implementation  (***)


end.
