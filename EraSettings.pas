unit EraSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Utils, Log, Ini,
  Heroes, GameExt, EraLog, SndVid, Tweaks, Stores;
  
  
(***) implementation (***)


function GetOptValue (const OptionName: string): string;
const
  ERA_SECTION = 'Era';

begin
  if Ini.ReadStrFromIni(OptionName, ERA_SECTION, Heroes.GAME_SETTINGS_FILE, result) then begin
    result := SysUtils.Trim(result);
  end // .if
  else begin
    result := '';
  end; // .else
end; // .function GetOptValue

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
  if GetOptValue('Debug') = '1' then begin
    VFS.DebugOpt := GetOptValue('Debug.VFS') = '1';

    if GetOptValue('Debug.Destination') = 'File' then begin
      InstallLogger(EraLog.TFileLogger.Create(GetOptValue('Debug.File')));
    end // .if
    else begin     
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    end; // .else
  end // .if
  else begin
    InstallLogger(EraLog.TMemoryLogger.Create);
  end; // .else
  
  Log.Write('Core', 'CheckVersion', 'Result: ' + GameExt.ERA_VERSION_STR);
  
  SndVid.LoadCDOpt            := GetOptValue('LoadCD') = '1';
  Tweaks.CPUPatchOpt          := GetOptValue('CPUPatch') = '1';
  Tweaks.FixGetHostByNameOpt  := GetOptValue('FixGetHostByName') = '1';
  Tweaks.UseOnlyOneCpuCoreOpt := GetOptValue('UseOnlyOneCpuCore') = '1';
  Stores.EraSectionsSize      := SysUtils.StrToInt(GetOptValue('SavedGameExtraBlockSize'));
end; // .procedure OnEraStart

begin
  GameExt.RegisterHandler(OnEraStart, 'OnEraStart');
end.
