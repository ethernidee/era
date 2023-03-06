unit EraLog;
{
DESCRIPTION:  Logging support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Windows, SysUtils, Utils, Files, ConsoleAPI, Log, StrLib, Concur, DlgMes;

type
  TLogger = class (Log.TLogger)
   protected
    {O} fCritSection: Concur.TCritSection;
        fLocked:      boolean;

   public
    constructor Create;
    destructor Destroy; override;

    function  Read (out LogRec: TLogRec): boolean; override;
    function  IsLocked: boolean; override;
    procedure Lock; override;
    procedure Unlock; override;
    function  GetPos (out Pos: integer): boolean; override;
    function  Seek (NewPos: integer): boolean; override;
    function  GetCount (out Count: integer): boolean; override;
  end; // .class TLogger

  TMemoryLogger  = class (TLogger)
    function Write (const EventSource, Operation, Description: string): boolean; override;
  end;

  TConsoleLogger  = class (TLogger)
    (***) protected (***)
      {O} fCon: ConsoleAPI.TConsole;

    (***) public (***)
      constructor Create (const Title: string);
      destructor  Destroy; override;

      function Write (const EventSource, Operation, Description: string): boolean; override;
  end; // .class TConsoleLogger

  TFileLogger = class (TLogger)
    (***) protected (***)
      {O} fFile: Windows.THandle;

    (***) public (***)
      constructor Create (const FilePath: string);
      destructor  Destroy; override;

      function Write (const EventSource, Operation, Description: string): boolean; override;
  end;


(***) implementation (***)


const
  BR                     = #13#10;
  RECORD_BEGIN_SEPARATOR = '>> ';
  RECORD_END_SEPARATOR   = BR + BR;
  OPERATION_SEPARATOR    = ': ';
  DESCRIPTION_SEPARATOR  = BR;
  DESCR_LINES_PREFIX     = '   ';
  DESCR_LINES_GLUE       = BR + DESCR_LINES_PREFIX;


constructor TLogger.Create;
begin
  Self.fCritSection.Init;
  Self.fLocked := false;
end;

destructor TLogger.Destroy;
begin
  Self.fCritSection.Delete;
end;

function TLogger.Read (out LogRec: TLogRec): boolean;
begin
  result := false;
end;

function TLogger.IsLocked: boolean;
begin
  with Self.fCritSection do begin
    Enter;
    result := Self.fLocked;
    Leave;
  end;
end;

procedure TLogger.Lock;
begin
  with Self.fCritSection do begin
    Enter;
    Self.fLocked := true;
    Leave;
  end;
end;

procedure TLogger.Unlock;
begin
  with Self.fCritSection do begin
    Enter;
    Self.fLocked := false;
    Leave;
  end;
end;

function TLogger.GetPos (out Pos: integer): boolean;
begin
  Pos    := -1;
  result := false;
end;

function TLogger.Seek (NewPos: integer): boolean;
begin
  result := false;
end;

function TLogger.GetCount (out Count: integer): boolean;
begin
  Count  := -1;
  result := false;
end;

function TMemoryLogger.Write (const EventSource, Operation, Description: string): boolean;
begin
  result := true;
end;

constructor TConsoleLogger.Create (const Title: string);
begin
  inherited Create;
  Self.fCon := ConsoleAPI.GetConsole(Title, 80, 50, 80, 1000);
end;

destructor TConsoleLogger.Destroy;
begin
  SysUtils.FreeAndNil(Self.fCon);
  inherited;
end;

function TConsoleLogger.Write (const EventSource, Operation, Description: string): boolean;
begin
  with Self.fCritSection do begin
    Enter;

    result := not Self.fLocked;

    if result then begin
      Self.Lock;

      Writeln
      (
        RECORD_BEGIN_SEPARATOR,
        EventSource,
        OPERATION_SEPARATOR,
        Operation,
        DESCRIPTION_SEPARATOR,
        DESCR_LINES_PREFIX,
        StrLib.Join(StrLib.Explode(Description, BR), DESCR_LINES_GLUE),
        RECORD_END_SEPARATOR
      );

      Self.Unlock;
    end; // .if

    Leave;
  end; // .with
end; // .function TConsoleLogger.Write

constructor TFileLogger.Create (const FilePath: string);
begin
  inherited Create;
  Self.fFile := Windows.CreateFileA(pchar(FilePath), Windows.GENERIC_WRITE, Windows.FILE_SHARE_READ or Windows.FILE_SHARE_DELETE, nil, Windows.CREATE_ALWAYS, Windows.FILE_ATTRIBUTE_NORMAL, 0);
end;

destructor TFileLogger.Destroy;
begin
  SysUtils.FreeAndNil(Self.fFile);
  inherited;
end;

function TFileLogger.Write (const EventSource, Operation, Description: string): boolean;
var
  Buf:          string;
  BytesWritten: cardinal;

begin
  with Self.fCritSection do begin
    Enter;

    result := not Self.fLocked;

    if result then begin
      Self.Lock;

      Buf := StrLib.Concat([
        RECORD_BEGIN_SEPARATOR,
        EventSource,
        OPERATION_SEPARATOR,
        Operation,
        DESCRIPTION_SEPARATOR,
        DESCR_LINES_PREFIX,
        StrLib.Join(StrLib.Explode(Description, BR), DESCR_LINES_GLUE),
        RECORD_END_SEPARATOR
      ]);

      Windows.WriteFile(Self.fFile, pchar(Buf)^, Length(Buf), BytesWritten, nil);

      Self.Unlock;
    end; // .if

    Leave;
  end; // .with
end; // .function TFileLogger.Write

end.
