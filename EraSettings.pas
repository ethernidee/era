unit EraSettings;
(*
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)
uses
  Math,
  SysUtils,

  Core,
  Ini,
  Log;

const
  (* Globally used common directories *)
  DEBUG_DIR = 'Debug\Era';

  (* Game settings *)
  DEFAULT_GAME_SETTINGS_FILE = 'default heroes3.ini';
  GAME_SETTINGS_FILE         = 'heroes3.ini';
  ERA_SETTINGS_SECTION       = 'Era';
  GAME_SETTINGS_SECTION      = 'Settings';

type
  TOption = record
    Value: string;

    function Str (const Default: string = ''): string;
    function Int (Default: integer = 0): integer;
    function Bool (Default: boolean = false): boolean;
  end;

(* Load Era settings *)
procedure LoadSettings (const GameDir: string);

(* Returns Era settings option by name *)
function GetOpt (const OptionName: string): TOption;

function IsDebug: boolean;

(* Returns Era debug option by name. The result is influenced by 'Debug' and 'Debug.Evenything' options *)
function GetDebugBoolOpt (const OptionName: string; Default: boolean = false): boolean;


(***)  implementation  (***)


var
  DebugOpt:             boolean;
  DebugEverythingOpt:   boolean;
  GameSettingsFilePath: string;


function TOption.Str (const Default: string = ''): string;
begin
  result := Self.Value;

  if Self.Value = '' then begin
    result := Default;
  end;
end;

function TOption.Int (Default: integer = 0): integer;
begin
  if (Self.Value = '') or not SysUtils.TryStrToInt(Self.Value, result) then begin
    result := Default;
  end;
end;

function TOption.Bool (Default: boolean = false): boolean;
begin
  result := Default;

  if Self.Value <> '' then begin
    result := Self.Value <> '0';
  end;
end;

function GetOpt (const OptionName: string): TOption;
begin
  result.Value := '';

  if Ini.ReadStrFromIni(OptionName, ERA_SETTINGS_SECTION, GameSettingsFilePath, result.Value) then begin
    result.Value := SysUtils.Trim(result.Value);
  end;
end;

function IsDebug: boolean;
begin
  result := DebugOpt;
end;

function GetDebugBoolOpt (const OptionName: string; Default: boolean = false): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOpt(OptionName).Bool(Default));
end;

procedure InstallLogger (Logger: Log.TLogger);
var
  LogRec: TLogRec;

begin
  {!} Assert(Logger <> nil);
  Log.Seek(0);

  while Log.Read(LogRec) do begin
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  end;

  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
end; // .procedure InstallLogger

procedure LoadSettings (const GameDir: string);
var
  DefaultGameSettingsPath: string;

begin
  GameSettingsFilePath    := GameDir + '\' + GAME_SETTINGS_FILE;
  DefaultGameSettingsPath := GameDir + '\' + DEFAULT_GAME_SETTINGS_FILE;

  Ini.LoadIni(GameSettingsFilePath);
  Ini.LoadIni(DefaultGameSettingsPath);
  Ini.MergeIniWithDefault(GameSettingsFilePath, DefaultGameSettingsPath);

  DebugOpt           := GetOpt('Debug').Bool(true);
  DebugEverythingOpt := GetOpt('Debug.Everything').Bool(false);
  Core.AbortOnError  := GetDebugBoolOpt('Debug.AbortOnError', false);
end;

end.
