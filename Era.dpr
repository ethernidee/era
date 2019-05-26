library Era;
{
DESCRIPTION: HMM 3.5 WogEra
AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

{$R *.RES}

uses  Math,
  GameExt, Erm, Tweaks,
  DebugMaps,
  VfsImport in '..\Vfs\VfsImport.pas',
  Lua in 'Lua\Lua.pas',
  Rainbow, Triggers, Stores, Lodman, Trans, Graph,
  AdvErm, Scripts, ErmTracking, PoTweak, SndVid, EraButtons,
  EraSettings, Extern;

begin
  // set callback to GameExt unit
  Erm.v[1] := integer(@GameExt.Init);
end.

