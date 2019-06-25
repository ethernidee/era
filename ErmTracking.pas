unit ErmTracking;
{
DESCRIPTION:  Provides ERM receivers and teiggers tracking support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses Utils;

type
  TCmdId = record
    Is:   word;
    Name: array [0..1] of char;
  end; // .record TCmdId
  
  PTrigTrackerRec = ^TTrigTrackerRec;
  TTrigTrackerRec = record
    TrigId: integer;
    v:      array [997..1000] of integer;
    f:      array [999..1000] of boolean;
    SnX:    GameExt.TEraEventParams;
  end; // .record TTrigTrackerRec
  
  TTrigTracker = class
   private
    fRecs:        array of TTrigTrackerRec;
    fMaxNumRecs:  integer;
    fPos:         integer;
   
   public
    constructor Create (aMaxNumRecs: integer);
    procedure Reset ();
    procedure Track (TrigId: integer);
    function  GenerateReport (): string;

    property MaxNumRecs: integer read fMaxNumRecs;
  end; // .class TTrigTracker


  {O} TrigTracker:            TTrigTracker;
  
  constructor TTrigTracker.Create (aMaxNumRecs: integer);
begin
  {!} Assert(aMaxNumRecs >= 0);
  SetLength(fRecs, aMaxNumRecs);
  fMaxNumRecs := aMaxNumRecs;
  fPos        := 9;
end; // .constructor TTrigTracker.Create

procedure TTrigTracker.Reset ();
var
  i: integer;
   
begin
  for i := Low(fRecs) to High(fRecs) do begin
    fRecs[i].TrigId := TRIGGER_INVALID;
  end; // .for
  
  fPos := 0;
end; // .procedure TTrigTracker.Reset

procedure TTrigTracker.Track (TrigId: integer);
var
{U} Rec: PTrigTrackerRec;
   
begin
  Rec := nil;
  // * * * * * //
  if fMaxNumRecs > 0 then begin
    Rec        := @fRecs[fPos];
    Rec.TrigId := TrigId;
    Utils.CopyMem(sizeof(Rec.v), @v[997], @Rec.v);
    Utils.CopyMem(sizeof(Rec.f), @f[999], @Rec.f);
    Utils.CopyMem(sizeof(Rec.SnX), GameExt.EraEventParams, @Rec.SnX);
    
    Inc(fPos);
    
    if fPos = fMaxNumRecs then begin
      fPos := 0;
    end; // .if
  end; // .if
end; // .procedure TTrigTracker.Track

function TTrigTracker.GenerateReport (): string;
begin
  result := '';
end; // .function TTrigTracker.GenerateReport

function GetTriggerReadableName (EventID: integer): string;
var
  BaseEventName:  string;
  EventID:        integer;
  
  x:              integer;
  y:              integer;
  z:              integer;
  
  ObjType:        integer;
  ObjSubtype:     integer;

begin
  case EventID of
    {*} Erm.TRIGGER_TM1..Erm.TRIGGER_TM100:
      result :=  'OnErmTimer ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_TM1 + 1); 
    {*} Erm.TRIGGER_HE0..Erm.TRIGGER_HE198:
      result :=  'OnHeroInteraction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HE0);
    {*} Erm.TRIGGER_BA0:      result :=  'OnBeforeBattle';
    {*} Erm.TRIGGER_BA1:      result :=  'OnAfterBattle';
    {*} Erm.TRIGGER_BR:       result :=  'OnBattleRound';
    {*} Erm.TRIGGER_BG0:      result :=  'OnBeforeBattleAction';
    {*} Erm.TRIGGER_BG1:      result :=  'OnAfterBattleAction';
    {*} Erm.TRIGGER_MW0:      result :=  'OnWanderingMonsterReach';
    {*} Erm.TRIGGER_MW1:      result :=  'OnWanderingMonsterDeath';
    {*} Erm.TRIGGER_MR0:      result :=  'OnMagicBasicResistance';
    {*} Erm.TRIGGER_MR1:      result :=  'OnMagicCorrectedResistance';
    {*} Erm.TRIGGER_MR2:      result :=  'OnDwarfMagicResistance';
    {*} Erm.TRIGGER_CM0:      result :=  'OnAdventureMapRightMouseClick';
    {*} Erm.TRIGGER_CM1:      result :=  'OnTownMouseClick';
    {*} Erm.TRIGGER_CM2:      result :=  'OnHeroScreenMouseClick';
    {*} Erm.TRIGGER_CM3:      result :=  'OnHeroesMeetScreenMouseClick';
    {*} Erm.TRIGGER_CM4:      result :=  'OnBattleScreenMouseClick';
    {*} Erm.TRIGGER_CM5:      result :=  'OnAdventureMapLeftMouseClick';
    {*} Erm.TRIGGER_AE0:      result :=  'OnEquipArt';
    {*} Erm.TRIGGER_AE1:      result :=  'OnUnequipArt';
    {*} Erm.TRIGGER_MM0:      result :=  'OnBattleMouseHint';
    {*} Erm.TRIGGER_MM1:      result :=  'OnTownMouseHint';
    {*} Erm.TRIGGER_MP:       result :=  'OnMp3MusicChange';
    {*} Erm.TRIGGER_SN:       result :=  'OnSoundPlay';
    {*} Erm.TRIGGER_MG0:      result :=  'OnBeforeAdventureMagic';
    {*} Erm.TRIGGER_MG1:      result :=  'OnAfterAdventureMagic';
    {*} Erm.TRIGGER_TH0:      result :=  'OnEnterTown';
    {*} Erm.TRIGGER_TH1:      result :=  'OnLeaveTown';
    {*} Erm.TRIGGER_IP0:      result :=  'OnBeforeBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP1:      result :=  'OnBeforeBattleAfterDataReceived';
    {*} Erm.TRIGGER_IP2:      result :=  'OnAfterBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP3:      result :=  'OnAfterBattleAfterDataReceived';
    {*} Erm.TRIGGER_CO0:      result :=  'OnOpenCommanderWindow';
    {*} Erm.TRIGGER_CO1:      result :=  'OnCloseCommanderWindow';
    {*} Erm.TRIGGER_CO2:      result :=  'OnAfterCommanderBuy';
    {*} Erm.TRIGGER_CO3:      result :=  'OnAfterCommanderResurrect';
    {*} Erm.TRIGGER_BA50:     result :=  'OnBeforeBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA51:     result :=  'OnAfterBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA52:     result :=  'OnBeforeBattleUniversal';
    {*} Erm.TRIGGER_BA53:     result :=  'OnAfterBattleUniversal';
    {*} Erm.TRIGGER_GM0:      result :=  'OnAfterLoadGame';
    {*} Erm.TRIGGER_GM1:      result :=  'OnBeforeSaveGame';
    {*} Erm.TRIGGER_PI:       result :=  'OnAfterErmInstructions';
    {*} Erm.TRIGGER_DL:       result :=  'OnCustomDialogEvent';
    {*} Erm.TRIGGER_HM:       result :=  'OnHeroMove';
    {*} Erm.TRIGGER_HM0..Erm.TRIGGER_HM198:
      result :=  'OnHeroMove ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HM0);
    {*} Erm.TRIGGER_HL:   result :=  'OnHeroGainLevel';
    {*} Erm.TRIGGER_HL0..Erm.TRIGGER_HL198:
      result :=  'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HL0);
    {*} Erm.TRIGGER_BF:       result :=  'OnSetupBattlefield';
    {*} Erm.TRIGGER_MF1:      result :=  'OnMonsterPhysicalDamage';
    {*} Erm.TRIGGER_TL0:      result :=  'OnEverySecond';
    {*} Erm.TRIGGER_TL1:      result :=  'OnEvery2Seconds';
    {*} Erm.TRIGGER_TL2:      result :=  'OnEvery5Seconds';
    {*} Erm.TRIGGER_TL3:      result :=  'OnEvery10Seconds';
    {*} Erm.TRIGGER_TL4:      result :=  'OnEveryMinute';
    (* Era Triggers *)
    {*  Erm.TRIGGER_BEFORE_SAVE_GAME:           RESULT :=  'OnBeforeSaveGameEx';}
    {*} Erm.TRIGGER_SAVEGAME_WRITE:             result :=  'OnSavegameWrite';
    {*} Erm.TRIGGER_SAVEGAME_READ:              result :=  'OnSavegameRead';
    {*} Erm.TRIGGER_KEYPRESS:                   result :=  'OnKeyPressed';
    {*} Erm.TRIGGER_OPEN_HEROSCREEN:            result :=  'OnOpenHeroScreen';
    {*} Erm.TRIGGER_CLOSE_HEROSCREEN:           result :=  'OnCloseHeroScreen';
    {*} Erm.TRIGGER_STACK_OBTAINS_TURN:         result :=  'OnBattleStackObtainsTurn';
    {*} Erm.TRIGGER_REGENERATE_PHASE:           result :=  'OnBattleRegeneratePhase';
    {*} Erm.TRIGGER_AFTER_SAVE_GAME:            result :=  'OnAfterSaveGame';
    {*  Erm.TRIGGER_SKEY_SAVEDIALOG:            RESULT :=  'OnSKeySaveDialog';}
    {*} Erm.TRIGGER_BEFOREHEROINTERACT:         result :=  'OnBeforeHeroInteraction';
    {*} Erm.TRIGGER_AFTERHEROINTERACT:          result :=  'OnAfterHeroInteraction';
    {*} Erm.TRIGGER_ONSTACKTOSTACKDAMAGE:       result :=  'OnStackToStackDamage';
    {*} Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT:  result :=  'OnAICalcStackAttackEffect';
    {*} Erm.TRIGGER_ONCHAT:                     result :=  'OnChat';
    {*} Erm.TRIGGER_ONGAMEENTER:                result :=  'OnGameEnter';
    {*} Erm.TRIGGER_ONGAMELEAVE:                result :=  'OnGameLeave';
    (* end Era Triggers *)
  else
    if EventID >= Erm.TRIGGER_OB_POS then begin
      if ((EventID and Erm.TRIGGER_OB_POS) or (EventID and Erm.TRIGGER_LE_POS)) <> 0 then begin
        x :=  EventID and 1023;
        y :=  (EventID shr 16) and 1023;
        z :=  (EventID shr 26) and 1;
        
        if (EventID and Erm.TRIGGER_LE_POS) <> 0 then begin
          BaseEventName :=  'OnLocalEvent ';
        end // .if
        else begin
          if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
            BaseEventName :=  'OnAfterVisitObject ';
          end // .if
          else begin
            BaseEventName :=  'OnBeforeVisitObject ';
          end; // .else
        end; // .else
        
        result :=
          BaseEventName + SysUtils.IntToStr(x) + '/' +
          SysUtils.IntToStr(y) + '/' + SysUtils.IntToStr(z);
      end // .if
      else begin
        ObjType     :=  (EventID shr 12) and 255;
        ObjSubtype  :=  (EventID and 255) - 1;
        
        if (EventID and Erm.TRIGGER_OB_LEAVE) <> 0 then begin
          BaseEventName :=  'OnAfterVisitObject ';
        end // .if
        else begin
          BaseEventName :=  'OnBeforeVisitObject ';
        end; // .else
        
        result :=
          BaseEventName + SysUtils.IntToStr(ObjType) + '/' + SysUtils.IntToStr(ObjSubtype);
      end; // .else
    end; // .if
  end; // .SWITCH
end; // .function GetTriggerReadableName

(***) implementation (***)

TrigTracker := TTrigTracker.Create(TrigTrackerMaxRecsOpt);

end.
