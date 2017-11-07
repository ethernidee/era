unit DebugMaps;

interface

uses
  SysUtils, Classes;

TDebugMap = class
 public
  abstract function LoadFromString (const MapContents: string): string;
  abstract function GetAddrInfo ({n} Addr: pointer; var FileName, Line, Pos: string): boolean;
end; // .class TDebugMap

TDebugMapBorland = class
 protected
  

 public
  function LoadFromString (const MapContents: string): string;
  function GetAddrInfo ({n} Addr: pointer; var FileName, Line, Pos: string): boolean; override;
end; // .class TDebugMapBorland

implementation



end.