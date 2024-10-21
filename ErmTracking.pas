unit ErmTracking;
(*
  Description: Provides ERM receivers and triggers tracking support
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  SysUtils,

  FilesEx,
  StrLib,
  Utils,

  Erm,
  GameExt;

type
  TTrackEventType        = (TRACKEDEVENT_START_TRIGGER, TRACKEDEVENT_END_TRIGGER, TRACKEDEVENT_CMD);
  TTriggerTrackEventType = TRACKEDEVENT_START_TRIGGER..TRACKEDEVENT_END_TRIGGER;

  PTrackedEvent = ^TTrackedEvent;
  TTrackedEvent = record
    EventType:    TTrackEventType;
    TriggerId:    integer;
    TriggerLevel: integer;
    SourceCode:   string;

    case TTrackEventType of
      TRACKEDEVENT_CMD: (
        Name: array [0..1] of char;
        Addr: pchar;
      );

      TRACKEDEVENT_START_TRIGGER, TRACKEDEVENT_END_TRIGGER: (
        v: array [997..1000] of integer;
        f: array [Erm.ERM_FLAG_NETWORK_BATTLE..Erm.ERM_FLAG_HUMAN_VISITOR_OR_REAL_BATTLE] of byte;
        x: Erm.TErmXVars;
      );
  end; // .record TTrackedEvent

  TEventTracker = class
   protected
    fEventsBuf:            array of TTrackedEvent;
    fBufSize:              integer;
    fBufPos:               integer;
    fNumTrackedEvents:     integer;
    fDumpCommands:         boolean;
    fIgnoreEmptyTriggers:  boolean;

    function AddRecord: {U} PTrackedEvent;
    function DumpCmd (Addr: pchar): string;

   public
    constructor Create (TrackingBufSize: integer);

    procedure Reset ();
    function  SetDumpCommands (ShouldDumpCommands: boolean): {SELF} TEventTracker;
    function  SetIgnoreEmptyTriggers (ShouldIgnoreEmptyTriggers: boolean): {SELF} TEventTracker;
    procedure TrackCmd (Addr: pchar);
    procedure TrackTrigger (EventType: TTriggerTrackEventType; TriggerId: integer);
    procedure GenerateReport (const FilePath: string);

    property BufSize: integer read fBufSize;
    property NumRecs: integer read fNumTrackedEvents;
  end; // .class TEventTracker


(***) implementation (***)


constructor TEventTracker.Create (TrackingBufSize: integer);
begin
  {!} Assert(TrackingBufSize > 0);
  SetLength(fEventsBuf, TrackingBufSize);
  fBufSize             := TrackingBufSize;
  fBufPos              := 0;
  fNumTrackedEvents    := 0;
  fDumpCommands        := false;
  fIgnoreEmptyTriggers := false;
end; // .constructor TEventTracker.Create

function TEventTracker.AddRecord: {U} PTrackedEvent;
begin
  result := @fEventsBuf[fBufPos];

  if fNumTrackedEvents < fBufSize then begin
    inc(fNumTrackedEvents);
  end;

  if fBufPos >= fBufSize - 1 then begin
    fBufPos := 0;
  end else begin
    inc(fBufPos);
  end;
end; // .function TEventTracker.AddRecord

procedure TEventTracker.Reset ();
begin
  fBufPos           := 0;
  fNumTrackedEvents := 0;
end;

function TEventTracker.SetDumpCommands (ShouldDumpCommands: boolean): {SELF} TEventTracker;
begin
  fDumpCommands := ShouldDumpCommands;
  result        := Self;
end;

function TEventTracker.SetIgnoreEmptyTriggers (ShouldIgnoreEmptyTriggers: boolean): {SELF} TEventTracker;
begin
  fIgnoreEmptyTriggers := ShouldIgnoreEmptyTriggers;
  result               := Self;
end;

procedure TEventTracker.TrackTrigger (EventType: TTriggerTrackEventType; TriggerId: integer);
var
{U} Rec: PTrackedEvent;

begin
  Rec := Self.AddRecord();
  // * * * * * //
  Rec.EventType    := EventType;
  Rec.TriggerId    := TriggerId;
  Rec.TriggerLevel := Erm.ErmTriggerDepth + ord(EventType = TRACKEDEVENT_END_TRIGGER);
  Rec.SourceCode   := '';

  Utils.CopyMem(sizeof(Rec.v), @v[low(Rec.v)], @Rec.v);
  Utils.CopyMem(sizeof(Rec.f), @f[low(Rec.f)], @Rec.f);
  Utils.CopyMem(sizeof(Rec.x), @Erm.x[1], @Rec.x);
end;

procedure TEventTracker.TrackCmd (Addr: pchar);
var
{U} Rec: PTrackedEvent;

begin
  Rec := Self.AddRecord();
  // * * * * * //
  Rec.EventType    := TRACKEDEVENT_CMD;
  Rec.TriggerId    := Erm.CurrErmEventID^;
  Rec.TriggerLevel := Erm.ErmTriggerDepth;
  Rec.Addr         := Addr;
  word(Rec.Name)   := pword(Addr)^;
  Rec.SourceCode   := '';

  if Self.fDumpCommands then begin
    Rec.SourceCode := Self.DumpCmd(Addr);
  end;
end; // .procedure TEventTracker.TrackCmd

procedure TEventTracker.GenerateReport (const FilePath: string);
const
  FlagNames: array [Erm.ERM_FLAG_NETWORK_BATTLE..Erm.ERM_FLAG_HUMAN_VISITOR_OR_REAL_BATTLE, 0..1] of string = (
    ('LOCAL_BATTLE(0)', 'NETWORK_BATTLE(1)'),
    ('THIS_AI_VS_REMOTE_HUMAN(0)', 'THIS_HUMAN_VS_REMOTE_HUMAN(1)'),
    ('IS_NOT_THIS_PC_HUMAN_TURN(0)', 'IS_THIS_PC_HUMAN_TURN(1)'),
    ('AI_TURN_OR_FAKE_BATTLE(0)', 'HUMAN_TURN_OR_REAL_BATTLE(1)')
  );

var
{U} Event:             PTrackedEvent;
    Writer:            FilesEx.IFormattedOutput;
    BufPos:            integer;
    BaseTriggerLevel:  integer;
    LastNonZeroSnxInd: integer;
    i:                 integer;

  procedure ReportTrigger;
  var
    j: integer;

  begin
    with Writer do begin
      EmptyLine;
      WriteIndentation;

      if Event.EventType = TRACKEDEVENT_START_TRIGGER then begin
        Write('!?FU(');
      end else begin
        Write('; END FU(');
      end;

      Write(Erm.GetTriggerReadableName(Event.TriggerId) + '); ID:' + SysUtils.IntToStr(Event.TriggerId) + ', v' + SysUtils.IntToStr(low(Event.v)) + ' = [');

      for j := low(Event.v) to high(Event.v) do begin
        if j > low(Event.v) then begin
          Write(', ');
        end;

        Write(SysUtils.IntToStr(Event.v[j]));
      end;

      Write('], flags = [');

      for j := low(Event.f) to high(Event.f) do begin
        if j > low(Event.f) then begin
          Write(', ');
        end;

        Write(FlagNames[j, integer(Event.f[j] <> 0)]);
      end;

      Write(']');

      LastNonZeroSnxInd := high(Event.x);

      while (LastNonZeroSnxInd >= Low(Event.x)) and (Event.x[LastNonZeroSnxInd] = 0) do begin
        dec(LastNonZeroSnxInd);
      end;

      if LastNonZeroSnxInd >= Low(Event.x) then begin
        Write(', x = [');

        for j := Low(Event.x) to LastNonZeroSnxInd do begin
          if j > Low(Event.x) then begin
            Write(', ');
          end;

          Write(SysUtils.IntToStr(integer(Event.x[j])));
        end;

        Write(']');
      end; // .if

      EmptyLine;
      EmptyLine;

      if Event.TriggerLevel < BaseTriggerLevel then begin
        BaseTriggerLevel := Event.TriggerLevel;
      end;
    end; // .with
  end; // .procedure ReportTrigger

  procedure ReportCmd;
  var
    ScriptName: string;
    LineN:      integer;
    LinePos:    integer;

  begin
    with Writer do begin
      if Erm.AddrToScriptNameAndLine(Event.Addr, ScriptName, LineN, LinePos) then begin
        Line(Format('!!%s in %s on line %d at pos %d', [Self.DumpCmd(Event.Addr), ScriptName, LineN, LinePos]));
      end else if fDumpCommands and (Event.SourceCode <> '') then begin
        Line('!!' + Event.SourceCode);
      end else begin
        Line('!!' + Event.Name + ':_;');
      end;
    end;
  end; // .procedure ReportCmd

begin
  Event := nil;
  // * * * * * //
  Writer := FilesEx.WriteFormattedOutput(FilePath);

  with Writer do begin
    Line('Dump of the last ' + SysUtils.IntToStr(fNumTrackedEvents) + ' tracked events.');

    if fNumTrackedEvents > 0 then begin
      BufPos           := (fBufPos - fNumTrackedEvents + fBufSize) mod fBufSize;
      Event            := @fEventsBuf[BufPos];
      BaseTriggerLevel := Event.TriggerLevel;

      Line('Start trigger depth level: ' + SysUtils.IntToStr(Event.TriggerLevel) + '.');
      EmptyLine;

      i := 1;

      while i <= fNumTrackedEvents do begin
        Event := @fEventsBuf[BufPos];
        SetIndentLevel(Event.TriggerLevel - BaseTriggerLevel);

        if fIgnoreEmptyTriggers and (i < fNumTrackedEvents) and (Event.EventType = TRACKEDEVENT_START_TRIGGER) and (fEventsBuf[(BufPos + 1) mod fBufSize].EventType = TRACKEDEVENT_END_TRIGGER) then begin
          inc(i, 2);
          BufPos := (BufPos + 2) mod fBufSize;
          continue;
        end;

        case Event.EventType of
          TRACKEDEVENT_START_TRIGGER, TRACKEDEVENT_END_TRIGGER: ReportTrigger;
          TRACKEDEVENT_CMD:                                     ReportCmd;
        end;

        inc(BufPos);

        if BufPos = fBufSize then begin
          BufPos := 0;
        end;

        inc(i);
      end; // .while
    end; // .if
  end; // .with
end; // .procedure TEventTracker.GenerateReport

function TEventTracker.DumpCmd (Addr: pchar): string;
var
{U} StartAddr: pchar;
    CmdLen:    integer;

begin
  {!} Assert(Addr <> nil);
  StartAddr := Addr;
  // * * * * * //
  while (not (Addr^ in [#0, ';'])) do begin
    while (not (Addr^ in [#0, ';', '^'])) do begin
      Inc(Addr);
    end;

    if Addr^ = '^' then begin
      Inc(Addr);

      while (not (Addr^ in [#0, '^'])) do begin
        Inc(Addr);
      end;

      if Addr^ = '^' then begin
        Inc(Addr);
      end;
    end;
  end;

  if Addr^ = ';' then begin
    Inc(Addr);
  end;

  CmdLen := integer(Addr) - integer(StartAddr);
  SetLength(result, CmdLen);

  if CmdLen > 0 then begin
    Utils.CopyMem(CmdLen, StartAddr, @result[1]);
  end;
end; // .function TEventTracker.DumpCmd

end.
