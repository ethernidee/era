unit EraSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Utils, Log, Ini,
  VFS, Heroes, GameExt, EraLog, SndVid, Tweaks, Stores, Erm;

const
  LOG_FILE_NAME = 'log.txt';
  
implementation

var
  DebugOpt:           boolean;
  DebugEverythingOpt: boolean;

function GetOptValue (const OptionName: string): string;
const
  ERA_SECTION               = 'Era';
  DEFAULT_ERA_SETTINGS_FILE = 'default era settings.ini';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, Heroes.GAME_SETTINGS_FILE, result) or
     Ini.ReadStrFromIni(OptionName, ERA_SECTION, DEFAULT_ERA_SETTINGS_FILE, result)
  then begin
    result := SysUtils.Trim(result);
  end else begin
    result := '';
  end; // .else
end; // .function GetOptValue

function GetOptBoolValue (const OptionName: string): boolean;
begin
  result := GetOptValue(OptionName) = '1';
end; // .function GetOptBoolValue

function GetDebugOpt (const OptionName: string): boolean;
begin
  result := DebugOpt and (DebugEverythingOpt or GetOptBoolValue(OptionName)); 
end; // .function GetDebugOpt

function GetOptIntValue (const OptionName: string): integer;
var
  OptVal: string;

begin
  OptVal := GetOptValue(OptionName);

  if not TryStrToInt(OptVal, result) then begin
    Log.Write('Settings', 'GetOptIntValue', 'Error. Invalid option "' + OptionName
                                            + '" value: "' + OptVal + '". Assumed 0');
    result := 0;
  end; // .if
end; // .function GetOptIntValue

procedure InstallLogger (Logger: Log.TLogger);
var
  LogRec: TLogRec;

begin
  {!} Assert(Logger <> nil);
  Log.Seek(0);

  while Log.Read(LogRec) do begin
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  end; // .while
  
  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
end; // .procedure InstallLogger

procedure OnEraStart (Event: GameExt.PEvent); stdcall;
begin
  DebugOpt           := GetOptBoolValue('Debug');
  DebugEverythingOpt := GetOptBoolValue('Debug.Everything');

  if DebugOpt then begin
    if GetOptValue('Debug.LogDestination') = 'File' then begin
      InstallLogger(EraLog.TFileLogger.Create(GameExt.DEBUG_DIR + '\' + LOG_FILE_NAME));
    end else begin     
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end; // .else
  end // .if
  else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end; // .else
  
  Log.Write('Core', 'CheckVersion', 'result: ' + GameExt.ERA_VERSION_STR);

  SndVid.LoadCDOpt               := GetOptBoolValue('LoadCD');
  Tweaks.CPUPatchOpt             := GetOptBoolValue('CPUPatch');
  Tweaks.FixGetHostByNameOpt     := GetOptBoolValue('FixGetHostByName');
  Tweaks.UseOnlyOneCpuCoreOpt    := GetOptBoolValue('UseOnlyOneCpuCore');
  Stores.DumpSavegameSectionsOpt := GetDebugOpt('Debug.DumpSavegameSections');
  Stores.EraSectionsSize         := GetOptIntValue('SavedGameExtraBlockSize');
  Erm.IgnoreInvalidCmdsOpt       := GetOptBoolValue('IgnoreInvalidReceivers');
  VFS.DebugOpt                   := GetDebugOpt('Debug.LogVirtualFileSystem');
end; // .procedure OnEraStart

begin
  GameExt.RegisterHandler(OnEraStart, 'OnEraStart');
end.
