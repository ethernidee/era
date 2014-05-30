UNIT ErmDebug;
{
DESCRIPTION:  Erm debugging and tracking
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Utils, Erm;

TYPE
  TCmdId = Erm.TErmCmdId;
  TEventContext = TObject;

  PEventRec = ^TEventRec;
  TEventRec = RECORD
        EventId:  INTEGER;
        EventN:   INTEGER;
    {O} Context:  TEventContext
  END; // .RECORD TEventRec

  PCmdRec = ^TCmdRec;
  TCmdRec = RECORD
    CmdId:  TCmdId;
    CmdPtr: PCHAR;  // Set for commands from scripts, CmdStr = ''
    CmdStr: STRING; // Set for deleted or temp commands, CmdPtr = NIL
    EventN: INTEGER;
  END; // .RECORD TCmdRec
  
  TTracker = CLASS
   PRIVATE
    fEventRecs:           ARRAY OF TEventRec;
    fCmdRecs:             ARRAY OF TCmdRec;
    fLastEventN:          INTEGER;
    fEventRecsPos:        INTEGER;
    fCmdRecsPos:          INTEGER;
    fEventRecsIsCircBuf:  BOOLEAN; // Becomes true when new records start overwriting the old ones
    fCmdRecsIsCircBuf:    BOOLEAN; // Becomes true when new records start overwriting the old ones
    
   PUBLIC
    CONSTRUCTOR Create (aNumEventRecs, aNumCmdRecs: INTEGER);
    PROCEDURE Reset;
    PROCEDURE TrackEvent (EventId: INTEGER);
    PROCEDURE TrackCmd (CmdId: TCmdId; CmdPtr: PCHAR; IsTempCmd: BOOLEAN);
    FUNCTION  GenerateReport: STRING;
  END; // .CLASS TTracker
  
  TAddrRange = RECORD
    StartAddr: POINTER;
    EndAddr:   POINTER;
  END; // .RECORD TAddrRange
  
  TScriptsLineKeeper = CLASS
   PRIVATE
    ScriptsBounds: ARRAY OF TAddrRange;
  END; // .CLASS TScriptsLineKeeper
  

VAR
{O} Tracker: TTracker;
    
    (* Options *)
    EnableDebuggerOpt:  BOOLEAN = FALSE;
    EnableTracingOpt:   BOOLEAN = FALSE;
    NumTracedEventsOpt: INTEGER = 0;
    NumTracedCmdsOpt:   INTEGER = 0;
  
  
(***) IMPLEMENTATION (***)

CONSTRUCTOR TTracker.Create (aNumEventRecs, aNumCmdRecs: INTEGER);
BEGIN
  {!} ASSERT(aNumEventRecs >= 0);
  {!} ASSERT(aNumCmdRecs >= 0);
  SetLength(fEventRecs, aNumEventRecs);
  SetLength(fCmdRecs, aNumCmdRecs);
  Reset;
END; // .CONSTRUCTOR TTracker.Create

PROCEDURE TTracker.Reset;
BEGIN
  fLastEventN         := 0;
  fEventRecsPos       := 0;
  fCmdRecsPos         := 0;
  fEventRecsIsCircBuf := FALSE;
  fCmdRecsIsCircBuf   := FALSE;
END; // .PROCEDURE TTracker.Reset

PROCEDURE TrackEvent (EventId: INTEGER);
VAR
   
BEGIN
  
END; // .PROCEDURE TrackEvent

PROCEDURE OnBeforeWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  Tracker := TTracker.Create(NumTracedEventsOpt, NumTracedCmdsOpt);
END; // .PROCEDURE OnBeforeWoG

BEGIN
  GameExt.RegisterHandler('OnBeforeWoG', OnBeforeWoG);
END.
