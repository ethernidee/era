unit EventLib;
(*
  List of all Era generated event structures.
*)


(***)  interface  (***)

uses
  Utils;


type
  POnBeforeLoadGameEvent = ^TOnBeforeLoadGameEvent;
  TOnBeforeLoadGameEvent = packed record
    FileName: pchar;
  end;


(***)  implementation  (***)

end.