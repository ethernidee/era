LIBRARY Era;
{
DESCRIPTION:  HMM 3.5 WogEra
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

USES
  VFS, GameExt, Erm, Tweaks, Rainbow, Triggers, Stores, Lodman,
  AdvErm, PoTweak, SndVid, EraButtons, EraSettings, Extern;

BEGIN
  // Set callback to GameExt unit
  Erm.v[1]  :=  INTEGER(@GameExt.Init);
END.
