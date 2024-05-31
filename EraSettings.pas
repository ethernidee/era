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
  EraLog,
  Erm,
  EventMan,
  GameExt,
  Heroes,
  Ini,
  Log,
  ResLib,
  SndVid,
  Stores,
  Trans,
  Tweaks,
  Utils,
  VfsImport;

const
  LOG_FILE_NAME = 'log.txt';


(***)  implementation  (***)


var
  DebugOpt:           boolean;
  DebugEverythingOpt: boolean;

function GetOptValue (const OptionName: string; const DefVal: string = ''): string;
const
  ERA_SECTION = 'Era';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, GameExt.GameDir + '\' + Heroes.GAME_SETTINGS_FILE, result) then begin
    result := SysUtils.Trim(result);
  end else begin
    result := DefVal;
  end;
end;

function GetOptBoolValue (const OptionName: string; DefValue: boolean = false): boolean;
var
  OptVal: string;

begin
  OptVal := GetOptValue(OptionName, IfThen(DefValue, '1', '0'));
  result := OptVal = '1';
end;

function GetDebugOpt (const OptionName: string; DefValue: boolean = false): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOptBoolValue(OptionName, DefValue));
end;

function GetOptIntValue (const OptionName: string; DefValue: integer = 0): integer;
var
  OptVal: string;

begin
  OptVal := GetOptValue(OptionName, IntToStr(DefValue));

  if not TryStrToInt(OptVal, result) then begin
    Log.Write('Settings', 'GetOptIntValue', 'Error. Invalid option "' + OptionName
                                            + '" value: "' + OptVal + '". Assumed ' + IntToStr(DefValue));
    result := DefValue;
  end;
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

procedure VfsLogger (Operation, Message: pchar); stdcall;
begin
  Log.Write('VFS', Operation, Message);
end;

procedure OnEraStart (Event: GameExt.PEvent); stdcall;
begin
  Ini.LoadIni(Heroes.GAME_SETTINGS_FILE);
  Ini.LoadIni(Heroes.DEFAULT_GAME_SETTINGS_FILE);
  Ini.MergeIniWithDefault(Heroes.GAME_SETTINGS_FILE, Heroes.DEFAULT_GAME_SETTINGS_FILE);

  DebugOpt           := GetOptBoolValue('Debug', true);
  DebugEverythingOpt := GetOptBoolValue('Debug.Everything', false);

  if DebugOpt then begin
    if SysUtils.AnsiLowerCase(GetOptValue('Debug.LogDestination', 'File')) = 'file' then begin
      InstallLogger(EraLog.TFileLogger.Create(GameExt.DEBUG_DIR + '\' + LOG_FILE_NAME));
    end else begin
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end;
  end else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end;

  Log.Write('Core', 'CheckVersion', 'Result: ' + GameExt.ERA_VERSION_STR);

  Core.AbortOnError              := GetDebugOpt(    'Debug.AbortOnError',          true);
  SndVid.LoadCDOpt               := GetOptBoolValue('LoadCD',                      false);
  Tweaks.CpuTargetLevel          := GetOptIntValue( 'CpuTargetLevel',              33);
  Tweaks.AutoSelectPcIpMaskOpt   := GetOptValue(    'AutoSelectPcIpMask',          '');
  Tweaks.UseOnlyOneCpuCoreOpt    := GetOptBoolValue('UseOnlyOneCpuCore',           true);
  Stores.DumpSavegameSectionsOpt := GetDebugOpt(    'Debug.DumpSavegameSections',  false);
  GameExt.DumpVfsOpt             := GetDebugOpt(    'Debug.DumpVirtualFileSystem', false);
  ResLib.ResManCacheSize         := GetOptIntValue( 'ResourceCacheSize',           200000000);
  Tweaks.DebugRng                := GetOptIntValue( 'Debug.Rng',                   0);
  Trans.SetLanguage(GetOptValue('Language', 'en'));

  if GetDebugOpt('Debug.LogVirtualFileSystem', false) then begin
    VfsImport.SetLoggingProc(@VfsLogger);
  end;

  Erm.ErmLegacySupport := GetOptBoolValue('ErmLegacySupport', false);

  with Erm.TrackingOpts do begin
    Enabled := GetDebugOpt('Debug.TrackErm');

    if Enabled then begin
      MaxRecords          := Max(1, GetOptIntValue('Debug.TrackErm.MaxRecords',     10000));
      DumpCommands        := GetOptBoolValue('Debug.TrackErm.DumpCommands',         true);
      IgnoreEmptyTriggers := GetOptBoolValue('Debug.TrackErm.IgnoreEmptyTriggers',  true);
    end;
  end;
end; // .procedure OnEraStart

begin
  EventMan.GetInstance.On('OnEraStart', OnEraStart);
end.
