UNIT EraSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  SysUtils, Utils, Log, Ini,
  Heroes, GameExt, EraLog, SndVid, Tweaks, Stores;
  
  
(***) IMPLEMENTATION (***)


FUNCTION GetOptValue (CONST OptionName: STRING): STRING;
CONST
  ERA_SECTION = 'Era';

BEGIN
  IF Ini.ReadStrFromIni(OptionName, ERA_SECTION, Heroes.GAME_SETTINGS_FILE, RESULT) THEN BEGIN
    RESULT := SysUtils.Trim(RESULT);
  END // .IF
  ELSE BEGIN
    RESULT := '';
  END; // .ELSE
END; // .FUNCTION GetOptValue

PROCEDURE InstallLogger (Logger: Log.TLogger);
VAR
  LogRec: TLogRec;

BEGIN
  {!} ASSERT(Logger <> NIL);
  Log.Seek(0);

  WHILE Log.Read(LogRec) DO BEGIN
    Logger.Write(LogRec.EventSource, LogRec.Operation, LogRec.Description);
  END; // .WHILE
  
  Log.InstallLogger(Logger, Log.FREE_OLD_LOGGER);
END; // .PROCEDURE InstallLogger

PROCEDURE OnEraStart (Event: GameExt.PEvent); STDCALL;
BEGIN
  IF GetOptValue('Debug') = '1' THEN BEGIN
    IF GetOptValue('Debug.Destination') = 'File' THEN BEGIN
      InstallLogger(EraLog.TFileLogger.Create(GetOptValue('Debug.File')));
    END // .IF
    ELSE BEGIN     
      InstallLogger(EraLog.TConsoleLogger.Create('Era Log'));
    END; // .ELSE
  END // .IF
  ELSE BEGIN
    InstallLogger(EraLog.TMemoryLogger.Create);
  END; // .ELSE
  
  Log.Write('Core', 'CheckVersion', 'Result: ' + GameExt.ERA_VERSION_STR);
  
  SndVid.LoadCDOpt            := GetOptValue('LoadCD') = '1';
  Tweaks.CPUPatchOpt          := GetOptValue('CPUPatch') = '1';
  Tweaks.FixGetHostByNameOpt  := GetOptValue('FixGetHostByName') = '1';
  Tweaks.UseOnlyOneCpuCoreOpt := GetOptValue('UseOnlyOneCpuCore') = '1';
  Stores.EraSectionsSize      := SysUtils.StrToInt(GetOptValue('SavedGameExtraBlockSize'));
END; // .PROCEDURE OnEraStart

BEGIN
  GameExt.RegisterHandler(OnEraStart, 'OnEraStart');
END.
