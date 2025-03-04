library Era;
(*
  Description: Heroes of Might and Magic 3.5: In The Wake of Gods (ERA)
  Author:      Alexander Shostak aka Berserker
*)

{$R *.RES}

uses
  {$define AssumeMultiThreaded}
  FastMM4, // Must be the first unit

  Math,
  SysUtils,

  (* Forced order, do not regroup or mix with other units: order dependent hooks/patches *)
  GameExt,
  Erm,

  AdvErm,
  Debug,
  DebugMaps,
  Dwellings,
  EraButtons,
  EraSettings,
  ErmTracking,
  Extern,
  Graph,
  Lodman,
  Lua in 'Lua\Lua.pas',
  Memory,
  PoTweak,
  Rainbow,
  Scripts,
  SndVid,
  Stores,
  Trans,
  Triggers,
  Tweaks,
  VfsImport in '..\Vfs\VfsImport.pas',
  WogEvo;

begin
  SysUtils.DecimalSeparator := '.';

  // set callback to GameExt unit
  Erm.v[1] := integer(@GameExt.Init);
end.

