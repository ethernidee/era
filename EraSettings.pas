unit EraSettings;
(*
  Description: Settings management
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  Math,
  SysUtils,

  Debug,
  Ini,
  Log;

const
  (* Globally used common directories and files *)
  DEBUG_DIR     = 'Debug\Era';
  LOG_FILE_NAME = 'log.txt';

  (* Game settings *)
  DEFAULT_GAME_SETTINGS_FILE = 'default heroes3.ini';
  GAME_SETTINGS_FILE         = 'heroes3.ini';
  ERA_SETTINGS_SECTION       = 'Era';
  GAME_SETTINGS_SECTION      = 'Settings';

type
  TOption = record
    Value: string;
    Dummy: integer; // This is field is necessary to prevent Delphi 2009 bug, when it tries to optimize 4 byte structures
                    // Memory corruption occurs quite often, while 8 byte structure will be passed as var-parameter and is thus safe

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
  Debug.AbortOnError := GetDebugBoolOpt('Debug.AbortOnError', false);
end;

end.
