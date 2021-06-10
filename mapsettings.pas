UNIT MapSettings;
{
DESCRIPTION:  Settings management
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  SysUtils,
  Utils, Log, Ini,
  EraLog;

CONST
  GAME_SETTINGS_FILE  = 'heroes3.ini';
  ERA_VERSION         = '2.461';
  
  
TYPE
  TDebugDestination = (DEST_CONSOLE, DEST_FILE);


VAR
  DebugOpt: BOOLEAN;
  
  DebugDestination: TDebugDestination;
  DebugFile:        STRING;


(***) IMPLEMENTATION (***)


FUNCTION GetOptValue (CONST OptionName: STRING): STRING;
CONST
  ERA_SECTION = 'Era';
  GAME_SETTINGS_FILE = 'heroes3.ini';

BEGIN
  IF Ini.ReadStrFromIni(OptionName, ERA_SECTION, GAME_SETTINGS_FILE, RESULT) THEN BEGIN
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

PROCEDURE LoadSettings;
BEGIN
  DebugOpt  :=  GetOptValue('Debug') = '1';
  
  IF DebugOpt THEN BEGIN
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
  
  Log.Write('Core', 'CheckVersion', 'Result: ' + ERA_VERSION);
END; // .PROCEDURE LoadSettings

BEGIN
  LoadSettings;
END.
