unit EventLib;
(*
  List of all Era generated event structures.
*)


(***)  interface  (***)

uses
  Utils;


type
  POnBeforeFastQuitToGameMenuEvent = ^TOnBeforeFastQuitToGameMenuEvent;
  TOnBeforeFastQuitToGameMenuEvent = packed record
    TargetScreen: integer;
  end;

  POnBeforeLoadGameEvent = ^TOnBeforeLoadGameEvent;
  TOnBeforeLoadGameEvent = packed record
    FileName: pchar;
  end;


(***)  implementation  (***)

end.
