UNIT ErmTracking;
{
DESCRIPTION:  Provides ERM receivers and teiggers tracking support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Utils;

TYPE
  TCmdId = RECORD
    Is:   WORD;
    Name: ARRAY [0..1] OF CHAR;
  END; // .RECORD TCmdId
  
  PTrigTrackerRec = ^TTrigTrackerRec;
  TTrigTrackerRec = RECORD
    TrigId: INTEGER;
    v:      ARRAY [997..1000] OF INTEGER;
    f:      ARRAY [999..1000] OF BOOLEAN;
    SnX:    GameExt.TEraEventParams;
  END; // .RECORD TTrigTrackerRec
  
  TTrigTracker = CLASS
   PRIVATE
    fRecs:        ARRAY OF TTrigTrackerRec;
    fMaxNumRecs:  INTEGER;
    fPos:         INTEGER;
   
   PUBLIC
    CONSTRUCTOR Create (aMaxNumRecs: INTEGER);
    PROCEDURE Reset ();
    PROCEDURE Track (TrigId: INTEGER);
    FUNCTION  GenerateReport (): STRING;

    PROPERTY MaxNumRecs: INTEGER READ fMaxNumRecs;
  END; // .CLASS TTrigTracker


  {O} TrigTracker:            TTrigTracker;
  
  CONSTRUCTOR TTrigTracker.Create (aMaxNumRecs: INTEGER);
BEGIN
  {!} ASSERT(aMaxNumRecs >= 0);
  SetLength(fRecs, aMaxNumRecs);
  fMaxNumRecs := aMaxNumRecs;
  fPos        := 9;
END; // .CONSTRUCTOR TTrigTracker.Create

PROCEDURE TTrigTracker.Reset ();
VAR
  i: INTEGER;
   
BEGIN
  FOR i := Low(fRecs) TO High(fRecs) DO BEGIN
    fRecs[i].TrigId := TRIGGER_INVALID;
  END; // .FOR
  
  fPos := 0;
END; // .PROCEDURE TTrigTracker.Reset

PROCEDURE TTrigTracker.Track (TrigId: INTEGER);
VAR
{U} Rec: PTrigTrackerRec;
   
BEGIN
  Rec := NIL;
  // * * * * * //
  IF fMaxNumRecs > 0 THEN BEGIN
    Rec        := @fRecs[fPos];
    Rec.TrigId := TrigId;
    Utils.CopyMem(SIZEOF(Rec.v), @v[997], @Rec.v);
    Utils.CopyMem(SIZEOF(Rec.f), @f[999], @Rec.f);
    Utils.CopyMem(SIZEOF(Rec.SnX), GameExt.EraEventParams, @Rec.SnX);
    
    INC(fPos);
    
    IF fPos = fMaxNumRecs THEN BEGIN
      fPos := 0;
    END; // .IF
  END; // .IF
END; // .PROCEDURE TTrigTracker.Track

FUNCTION TTrigTracker.GenerateReport (): STRING;
BEGIN
  RESULT := '';
END; // .FUNCTION TTrigTracker.GenerateReport

FUNCTION GetTriggerReadableName (EventID: INTEGER): STRING;
VAR
  BaseEventName:  STRING;
  EventID:        INTEGER;
  
  x:              INTEGER;
  y:              INTEGER;
  z:              INTEGER;
  
  ObjType:        INTEGER;
  ObjSubtype:     INTEGER;

BEGIN
  CASE EventID OF
    {*} Erm.TRIGGER_TM1..Erm.TRIGGER_TM100:
      RESULT :=  'OnErmTimer ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_TM1 + 1); 
    {*} Erm.TRIGGER_HE0..Erm.TRIGGER_HE198:
      RESULT :=  'OnHeroInteraction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HE0);
    {*} Erm.TRIGGER_BA0:      RESULT :=  'OnBeforeBattle';
    {*} Erm.TRIGGER_BA1:      RESULT :=  'OnAfterBattle';
    {*} Erm.TRIGGER_BR:       RESULT :=  'OnBattleRound';
    {*} Erm.TRIGGER_BG0:      RESULT :=  'OnBeforeBattleAction';
    {*} Erm.TRIGGER_BG1:      RESULT :=  'OnAfterBattleAction';
    {*} Erm.TRIGGER_MW0:      RESULT :=  'OnWanderingMonsterReach';
    {*} Erm.TRIGGER_MW1:      RESULT :=  'OnWanderingMonsterDeath';
    {*} Erm.TRIGGER_MR0:      RESULT :=  'OnMagicBasicResistance';
    {*} Erm.TRIGGER_MR1:      RESULT :=  'OnMagicCorrectedResistance';
    {*} Erm.TRIGGER_MR2:      RESULT :=  'OnDwarfMagicResistance';
    {*} Erm.TRIGGER_CM0:      RESULT :=  'OnAdventureMapRightMouseClick';
    {*} Erm.TRIGGER_CM1:      RESULT :=  'OnTownMouseClick';
    {*} Erm.TRIGGER_CM2:      RESULT :=  'OnHeroScreenMouseClick';
    {*} Erm.TRIGGER_CM3:      RESULT :=  'OnHeroesMeetScreenMouseClick';
    {*} Erm.TRIGGER_CM4:      RESULT :=  'OnBattleScreenMouseClick';
    {*} Erm.TRIGGER_CM5:      RESULT :=  'OnAdventureMapLeftMouseClick';
    {*} Erm.TRIGGER_AE0:      RESULT :=  'OnEquipArt';
    {*} Erm.TRIGGER_AE1:      RESULT :=  'OnUnequipArt';
    {*} Erm.TRIGGER_MM0:      RESULT :=  'OnBattleMouseHint';
    {*} Erm.TRIGGER_MM1:      RESULT :=  'OnTownMouseHint';
    {*} Erm.TRIGGER_MP:       RESULT :=  'OnMp3MusicChange';
    {*} Erm.TRIGGER_SN:       RESULT :=  'OnSoundPlay';
    {*} Erm.TRIGGER_MG0:      RESULT :=  'OnBeforeAdventureMagic';
    {*} Erm.TRIGGER_MG1:      RESULT :=  'OnAfterAdventureMagic';
    {*} Erm.TRIGGER_TH0:      RESULT :=  'OnEnterTown';
    {*} Erm.TRIGGER_TH1:      RESULT :=  'OnLeaveTown';
    {*} Erm.TRIGGER_IP0:      RESULT :=  'OnBeforeBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP1:      RESULT :=  'OnBeforeBattleAfterDataReceived';
    {*} Erm.TRIGGER_IP2:      RESULT :=  'OnAfterBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP3:      RESULT :=  'OnAfterBattleAfterDataReceived';
    {*} Erm.TRIGGER_CO0:      RESULT :=  'OnOpenCommanderWindow';
    {*} Erm.TRIGGER_CO1:      RESULT :=  'OnCloseCommanderWindow';
    {*} Erm.TRIGGER_CO2:      RESULT :=  'OnAfterCommanderBuy';
    {*} Erm.TRIGGER_CO3:      RESULT :=  'OnAfterCommanderResurrect';
    {*} Erm.TRIGGER_BA50:     RESULT :=  'OnBeforeBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA51:     RESULT :=  'OnAfterBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA52:     RESULT :=  'OnBeforeBattleUniversal';
    {*} Erm.TRIGGER_BA53:     RESULT :=  'OnAfterBattleUniversal';
    {*} Erm.TRIGGER_GM0:      RESULT :=  'OnAfterLoadGame';
    {*} Erm.TRIGGER_GM1:      RESULT :=  'OnBeforeSaveGame';
    {*} Erm.TRIGGER_PI:       RESULT :=  'OnAfterErmInstructions';
    {*} Erm.TRIGGER_DL:       RESULT :=  'OnCustomDialogEvent';
    {*} Erm.TRIGGER_HM:       RESULT :=  'OnHeroMove';
    {*} Erm.TRIGGER_HM0..Erm.TRIGGER_HM198:
      RESULT :=  'OnHeroMove ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HM0);
    {*} Erm.TRIGGER_HL:   RESULT :=  'OnHeroGainLevel';
    {*} Erm.TRIGGER_HL0..Erm.TRIGGER_HL198:
      RESULT :=  'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HL0);
    {*} Erm.TRIGGER_BF:       RESULT :=  'OnSetupBattlefield';
    {*} Erm.TRIGGER_MF1:      RESULT :=  'OnMonsterPhysicalDamage';
    {*} Erm.TRIGGER_TL0:      RESULT :=  'OnEverySecond';
    {*} Erm.TRIGGER_TL1:      RESULT :=  'OnEvery2Seconds';
    {*} Erm.TRIGGER_TL2:      RESULT :=  'OnEvery5Seconds';
    {*} Erm.TRIGGER_TL3:      RESULT :=  'OnEvery10Seconds';
    {*} Erm.TRIGGER_TL4:      RESULT :=  'OnEveryMinute';
    (* Era Triggers *)
    {*  Erm.TRIGGER_BEFORE_SAVE_GAME:           RESULT :=  'OnBeforeSaveGameEx';}
    {*} Erm.TRIGGER_SAVEGAME_WRITE:             RESULT :=  'OnSavegameWrite';
    {*} Erm.TRIGGER_SAVEGAME_READ:              RESULT :=  'OnSavegameRead';
    {*} Erm.TRIGGER_KEYPRESS:                   RESULT :=  'OnKeyPressed';
    {*} Erm.TRIGGER_OPEN_HEROSCREEN:            RESULT :=  'OnOpenHeroScreen';
    {*} Erm.TRIGGER_CLOSE_HEROSCREEN:           RESULT :=  'OnCloseHeroScreen';
    {*} Erm.TRIGGER_STACK_OBTAINS_TURN:         RESULT :=  'OnBattleStackObtainsTurn';
    {*} Erm.TRIGGER_REGENERATE_PHASE:           RESULT :=  'OnBattleRegeneratePhase';
    {*} Erm.TRIGGER_AFTER_SAVE_GAME:            RESULT :=  'OnAfterSaveGame';
    {*  Erm.TRIGGER_SKEY_SAVEDIALOG:            RESULT :=  'OnSKeySaveDialog';}
    {*} Erm.TRIGGER_BEFOREHEROINTERACT:         RESULT :=  'OnBeforeHeroInteraction';
    {*} Erm.TRIGGER_AFTERHEROINTERACT:          RESULT :=  'OnAfterHeroInteraction';
    {*} Erm.TRIGGER_ONSTACKTOSTACKDAMAGE:       RESULT :=  'OnStackToStackDamage';
    {*} Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT:  RESULT :=  'OnAICalcStackAttackEffect';
    {*} Erm.TRIGGER_ONCHAT:                     RESULT :=  'OnChat';
    {*} Erm.TRIGGER_ONGAMEENTER:                RESULT :=  'OnGameEnter';
    {*} Erm.TRIGGER_ONGAMELEAVE:                RESULT :=  'OnGameLeave';
    (* End Era Triggers *)
  ELSE
    IF EventID >= Erm.TRIGGER_OB_POS THEN BEGIN
      IF ((EventID AND Erm.TRIGGER_OB_POS) OR (EventID AND Erm.TRIGGER_LE_POS)) <> 0 THEN BEGIN
        x :=  EventID AND 1023;
        y :=  (EventID SHR 16) AND 1023;
        z :=  (EventID SHR 26) AND 1;
        
        IF (EventID AND Erm.TRIGGER_LE_POS) <> 0 THEN BEGIN
          BaseEventName :=  'OnLocalEvent ';
        END // .IF
        ELSE BEGIN
          IF (EventID AND Erm.TRIGGER_OB_LEAVE) <> 0 THEN BEGIN
            BaseEventName :=  'OnAfterVisitObject ';
          END // .IF
          ELSE BEGIN
            BaseEventName :=  'OnBeforeVisitObject ';
          END; // .ELSE
        END; // .ELSE
        
        RESULT :=
          BaseEventName + SysUtils.IntToStr(x) + '/' +
          SysUtils.IntToStr(y) + '/' + SysUtils.IntToStr(z);
      END // .IF
      ELSE BEGIN
        ObjType     :=  (EventID SHR 12) AND 255;
        ObjSubtype  :=  (EventID AND 255) - 1;
        
        IF (EventID AND Erm.TRIGGER_OB_LEAVE) <> 0 THEN BEGIN
          BaseEventName :=  'OnAfterVisitObject ';
        END // .IF
        ELSE BEGIN
          BaseEventName :=  'OnBeforeVisitObject ';
        END; // .ELSE
        
        RESULT :=
          BaseEventName + SysUtils.IntToStr(ObjType) + '/' + SysUtils.IntToStr(ObjSubtype);
      END; // .ELSE
    END; // .IF
  END; // .SWITCH
END; // .FUNCTION GetTriggerReadableName

(***) IMPLEMENTATION (***)

TrigTracker := TTrigTracker.Create(TrigTrackerMaxRecsOpt);

END.
