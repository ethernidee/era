unit Triggers;
{
DESCRIPTION:  Extends ERM with new triggers
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils,
  Core, PatchApi, GameExt, Heroes, Erm;

const
  NO_STACK  = -1;
  
  STACK_POS_OFS = $38;


(***) implementation (***)


const
  (* extended MM Trigger *)
  ATTACKER_STACK_N_PARAM  = 0;
  DEFENDER_STACK_N_PARAM  = 1;
  MIN_DAMAGE_PARAM        = 2;
  MAX_DAMAGE_PARAM        = 3;

  
var
  PrevWndProc:  Heroes.TWndProc;
  
  (* Calculate damage delayed parameters *)
  AttackerId:           integer;
  DefenderId:           integer;
  BasicDamage:          integer;
  DamageBonus:          integer;
  IsDistantAttack:      integer;
  IsTheoreticalAttack:  integer;
  Distance:             integer;
  
  (* AI Calculate stack attack effect delayed parameters *)
  AIAttackerId: integer;
  AIDefenderId: integer;
  
  (* Controlling OnGameEnter and OnGameLeave events *)
  MainGameLoopDepth: integer = 0;
  
  
function Hook_BattleHint_GetAttacker (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  GameExt.EraSaveEventParams;
  GameExt.EraEventParams[ATTACKER_STACK_N_PARAM]  :=  Context.EAX;
  GameExt.EraEventParams[DEFENDER_STACK_N_PARAM]  :=  NO_STACK;
  GameExt.EraEventParams[MIN_DAMAGE_PARAM]        :=  -1;
  GameExt.EraEventParams[MAX_DAMAGE_PARAM]        :=  -1;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_BattleHint_GetAttacker

function Hook_BattleHint_GetDefender (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  GameExt.EraEventParams[DEFENDER_STACK_N_PARAM]  :=  Context.EAX;
  result                                          :=  Core.EXEC_DEF_CODE;
end; // .function Hook_BattleHint_GetDefender

function Hook_BattleHint_CalcMinMaxDamage (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  GameExt.EraEventParams[MIN_DAMAGE_PARAM]  :=  Context.EDI;
  GameExt.EraEventParams[MAX_DAMAGE_PARAM]  :=  Context.EAX;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_BattleHint_CalcMinMaxDamage

function Hook_MMTrigger (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  GameExt.EraRestoreEventParams;
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_MMTrigger

procedure OnBeforeTrigger (Event: GameExt.PEvent); stdcall;
var
{U} EventArgs:      Erm.POnBeforeTriggerArgs;
    EventName:      string;
    BaseEventName:  string;
    EventID:        integer;
    
    x:              integer;
    y:              integer;
    z:              integer;
    
    ObjType:        integer;
    ObjSubtype:     integer;

begin
  {!} Assert(Event <> nil);
  EventArgs :=  Erm.POnBeforeTriggerArgs(Event.Data);
  // * * * * * //
  EventName :=  '';
  EventID   :=  EventArgs.TriggerID;
  
  GameExt.FireEvent('OnTrigger ' + SysUtils.IntToStr(EventID), nil, 0);
  
  case EventID of
    {*} Erm.TRIGGER_TM1..Erm.TRIGGER_TM100:
      EventName :=  'OnErmTimer ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_TM1 + 1); 
    {*} Erm.TRIGGER_HE0..Erm.TRIGGER_HE198:
      EventName :=  'OnHeroInteraction ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HE0);
    {*} Erm.TRIGGER_BA0:      EventName :=  'OnBeforeBattle';
    {*} Erm.TRIGGER_BA1:      EventName :=  'OnAfterBattle';
    {*} Erm.TRIGGER_BR:       EventName :=  'OnBattleRound';
    {*} Erm.TRIGGER_BG0:      EventName :=  'OnBeforeBattleAction';
    {*} Erm.TRIGGER_BG1:      EventName :=  'OnAfterBattleAction';
    {*} Erm.TRIGGER_MW0:      EventName :=  'OnWanderingMonsterReach';
    {*} Erm.TRIGGER_MW1:      EventName :=  'OnWanderingMonsterDeath';
    {*} Erm.TRIGGER_MR0:      EventName :=  'OnMagicBasicResistance';
    {*} Erm.TRIGGER_MR1:      EventName :=  'OnMagicCorrectedResistance';
    {*} Erm.TRIGGER_MR2:      EventName :=  'OnDwarfMagicResistance';
    {*} Erm.TRIGGER_CM0:      EventName :=  'OnAdventureMapRightMouseClick';
    {*} Erm.TRIGGER_CM1:      EventName :=  'OnTownMouseClick';
    {*} Erm.TRIGGER_CM2:      EventName :=  'OnHeroScreenMouseClick';
    {*} Erm.TRIGGER_CM3:      EventName :=  'OnHeroesMeetScreenMouseClick';
    {*} Erm.TRIGGER_CM4:      EventName :=  'OnBattleScreenMouseClick';
    {*} Erm.TRIGGER_CM5:      EventName :=  'OnAdventureMapLeftMouseClick';
    {*} Erm.TRIGGER_AE0:      EventName :=  'OnEquipArt';
    {*} Erm.TRIGGER_AE1:      EventName :=  'OnUnequipArt';
    {*} Erm.TRIGGER_MM0:      EventName :=  'OnBattleMouseHint';
    {*} Erm.TRIGGER_MM1:      EventName :=  'OnTownMouseHint';
    {*} Erm.TRIGGER_MP:       EventName :=  'OnMp3MusicChange';
    {*} Erm.TRIGGER_SN:       EventName :=  'OnSoundPlay';
    {*} Erm.TRIGGER_MG0:      EventName :=  'OnBeforeAdventureMagic';
    {*} Erm.TRIGGER_MG1:      EventName :=  'OnAfterAdventureMagic';
    {*} Erm.TRIGGER_TH0:      EventName :=  'OnEnterTown';
    {*} Erm.TRIGGER_TH1:      EventName :=  'OnLeaveTown';
    {*} Erm.TRIGGER_IP0:      EventName :=  'OnBeforeBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP1:      EventName :=  'OnBeforeBattleAfterDataReceived';
    {*} Erm.TRIGGER_IP2:      EventName :=  'OnAfterBattleBeforeDataSend';
    {*} Erm.TRIGGER_IP3:      EventName :=  'OnAfterBattleAfterDataReceived';
    {*} Erm.TRIGGER_CO0:      EventName :=  'OnOpenCommanderWindow';
    {*} Erm.TRIGGER_CO1:      EventName :=  'OnCloseCommanderWindow';
    {*} Erm.TRIGGER_CO2:      EventName :=  'OnAfterCommanderBuy';
    {*} Erm.TRIGGER_CO3:      EventName :=  'OnAfterCommanderResurrect';
    {*} Erm.TRIGGER_BA50:     EventName :=  'OnBeforeBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA51:     EventName :=  'OnAfterBattleForThisPcDefender';
    {*} Erm.TRIGGER_BA52:     EventName :=  'OnBeforeBattleUniversal';
    {*} Erm.TRIGGER_BA53:     EventName :=  'OnAfterBattleUniversal';
    {*} Erm.TRIGGER_GM0:      EventName :=  'OnAfterLoadGame';
    {*} Erm.TRIGGER_GM1:      EventName :=  'OnBeforeSaveGame';
    {*} Erm.TRIGGER_PI:       EventName :=  'OnAfterErmInstructions';
    {*} Erm.TRIGGER_DL:       EventName :=  'OnCustomDialogEvent';
    {*} Erm.TRIGGER_HM:       EventName :=  'OnHeroMove';
    {*} Erm.TRIGGER_HM0..Erm.TRIGGER_HM198:
      EventName :=  'OnHeroMove ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HM0);
    {*} Erm.TRIGGER_HL:   EventName :=  'OnHeroGainLevel';
    {*} Erm.TRIGGER_HL0..Erm.TRIGGER_HL198:
      EventName :=  'OnHeroGainLevel ' + SysUtils.IntToStr(EventID - Erm.TRIGGER_HL0);
    {*} Erm.TRIGGER_BF:       EventName :=  'OnSetupBattlefield';
    {*} Erm.TRIGGER_MF1:      EventName :=  'OnMonsterPhysicalDamage';
    {*} Erm.TRIGGER_TL0:      EventName :=  'OnEverySecond';
    {*} Erm.TRIGGER_TL1:      EventName :=  'OnEvery2Seconds';
    {*} Erm.TRIGGER_TL2:      EventName :=  'OnEvery5Seconds';
    {*} Erm.TRIGGER_TL3:      EventName :=  'OnEvery10Seconds';
    {*} Erm.TRIGGER_TL4:      EventName :=  'OnEveryMinute';
    (* Era Triggers *)
    {*  Erm.TRIGGER_BEFORE_SAVE_GAME:           EventName :=  'OnBeforeSaveGameEx';}
    {*} Erm.TRIGGER_SAVEGAME_WRITE:             EventName :=  'OnSavegameWrite';
    {*} Erm.TRIGGER_SAVEGAME_READ:              EventName :=  'OnSavegameRead';
    {*} Erm.TRIGGER_KEYPRESS:                   EventName :=  'OnKeyPressed';
    {*} Erm.TRIGGER_OPEN_HEROSCREEN:            EventName :=  'OnOpenHeroScreen';
    {*} Erm.TRIGGER_CLOSE_HEROSCREEN:           EventName :=  'OnCloseHeroScreen';
    {*} Erm.TRIGGER_STACK_OBTAINS_TURN:         EventName :=  'OnBattleStackObtainsTurn';
    {*} Erm.TRIGGER_REGENERATE_PHASE:           EventName :=  'OnBattleRegeneratePhase';
    {*} Erm.TRIGGER_AFTER_SAVE_GAME:            EventName :=  'OnAfterSaveGame';
    {*  Erm.TRIGGER_SKEY_SAVEDIALOG:            EventName :=  'OnSKeySaveDialog';}
    {*} Erm.TRIGGER_BEFOREHEROINTERACT:         EventName :=  'OnBeforeHeroInteraction';
    {*} Erm.TRIGGER_AFTERHEROINTERACT:          EventName :=  'OnAfterHeroInteraction';
    {*} Erm.TRIGGER_ONSTACKTOSTACKDAMAGE:       EventName :=  'OnStackToStackDamage';
    {*} Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT:  EventName :=  'OnAICalcStackAttackEffect';
    {*} Erm.TRIGGER_ONCHAT:                     EventName :=  'OnChat';
    {*} Erm.TRIGGER_ONGAMEENTER:                EventName :=  'OnGameEnter';
    {*} Erm.TRIGGER_ONGAMELEAVE:                EventName :=  'OnGameLeave';
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
        
        EventName :=
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
        
        EventName :=
          BaseEventName + SysUtils.IntToStr(ObjType) + '/' + SysUtils.IntToStr(ObjSubtype);
      end; // .else
    end; // .if
  end; // .SWITCH
  
  if EventName <> '' then begin
    GameExt.FireEvent(EventName, @EventArgs.BlockErmExecution, sizeof(EventArgs.BlockErmExecution));
  end; // .if
end; // .procedure OnBeforeTrigger

function MainWndProc (hWnd, Msg, wParam, lParam: integer): LONGBOOL; stdcall;
const
  WM_KEYDOWN          = $100;
  KEY_F11             = 122;
  KEY_F12             = 123;
  ENABLE_DEF_REACTION = 0;

var
  GameState:  Heroes.TGameState;
  
begin
  result  :=  FALSE;
  
  if Msg = WM_KEYDOWN then begin
    Heroes.GetGameState(GameState);
    
    if
      (GameState.RootDlgId = Heroes.ADVMAP_DLGID) and
      (wParam in [KEY_F11, KEY_F12])
    then begin
      case wParam of
        KEY_F12: Erm.ReloadErm;
        KEY_F11: begin
          GameExt.GenerateDebugInfo;
          Erm.PrintChatMsg('{~white}Debug information was dumped to ' + GameExt.DEBUG_DIR +'{~}');
        end; // .case KEY_F11
      end; // .SWITCH
    end // .if
    else begin
      GameExt.EraSaveEventParams;
      
      GameExt.EraEventParams[0] :=  wParam;
      GameExt.EraEventParams[1] :=  ENABLE_DEF_REACTION;
      
      if GameState.RootDlgId = Heroes.ADVMAP_DLGID then begin
        Erm.FireErmEvent(Erm.TRIGGER_KEYPRESS);
      end // .if
      else begin
        GameExt.FireEvent('OnKeyPressed', GameExt.NO_EVENT_DATA, 0);
      end; // .else
      
      result  :=  GameExt.EraEventParams[1] = ENABLE_DEF_REACTION;
      
      GameExt.EraRestoreEventParams;
      
      if result then begin
        PrevWndProc(hWnd, Msg, wParam, lParam);
      end; // .if
    end; // .else
  end // .if
  else begin
    result  :=  PrevWndProc(hWnd, Msg, wParam, lParam);
  end; // .else
end; // .function MainWndProc

function Hook_CreateWindow (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  PrevWndProc :=  Ptr
  (
    Windows.SetWindowLong(Heroes.hWnd^, Windows.GWL_WNDPROC, integer(@MainWndProc))
  );
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_CreateWindow

function Hook_StartCalcDamage (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  AttackerId  :=  Heroes.GetStackIdByPos(PINTEGER(Context.EBX + STACK_POS_OFS)^);
  DefenderId  :=  Heroes.GetStackIdByPos(PINTEGER(Context.ESI + STACK_POS_OFS)^);
  
  BasicDamage         :=  PINTEGER(Context.EBP + 12)^;
  IsDistantAttack     :=  PINTEGER(Context.EBP + 16)^;
  IsTheoreticalAttack :=  PINTEGER(Context.EBP + 20)^;
  Distance            :=  PINTEGER(Context.EBP + 24)^;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_StartCalcDamage

function Hook_CalcDamage_GetDamageBonus (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  DamageBonus :=  Context.EAX;
  result      :=  Core.EXEC_DEF_CODE;
end; // .function Hook_CalcDamage_GetDamageBonus

function Hook_EndCalcDamage (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const
  ATTACKER            = 0;
  DEFENDER            = 1;
  FINAL_DAMAGE_CONST  = 2;
  FINAL_DAMAGE        = 3;
  BASIC_DAMAGE        = 4;
  DAMAGE_BONUS        = 5;
  IS_DISTANT          = 6;
  DISTANCE_ARG        = 7;
  IS_THEORETICAL      = 8;

begin
  GameExt.EraSaveEventParams;

  GameExt.EraEventParams[ATTACKER]            :=  AttackerId;
  GameExt.EraEventParams[DEFENDER]            :=  DefenderId;
  GameExt.EraEventParams[FINAL_DAMAGE_CONST]  :=  Context.EAX;
  GameExt.EraEventParams[FINAL_DAMAGE]        :=  Context.EAX;
  GameExt.EraEventParams[BASIC_DAMAGE]        :=  BasicDamage;
  GameExt.EraEventParams[DAMAGE_BONUS]        :=  DamageBonus;
  GameExt.EraEventParams[IS_DISTANT]          :=  IsDistantAttack;
  GameExt.EraEventParams[DISTANCE_ARG]        :=  Distance;
  GameExt.EraEventParams[IS_THEORETICAL]      :=  IsTheoreticalAttack;

  Erm.FireErmEvent(Erm.TRIGGER_ONSTACKTOSTACKDAMAGE);
  Context.EAX :=  GameExt.EraEventParams[FINAL_DAMAGE];
  
  GameExt.EraRestoreEventParams;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_EndCalcDamage

function Hook_AI_CalcStackAttackEffect_Start (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
begin
  AIAttackerId  :=  Heroes.GetBattleCellStackId
    (Heroes.GetBattleCellByPos(PINTEGER(PINTEGER(Context.ESP + 8)^ + STACK_POS_OFS)^));
  AIDefenderId  :=  Heroes.GetBattleCellStackId
    (Heroes.GetBattleCellByPos(PINTEGER(PINTEGER(Context.ESP + 16)^ + STACK_POS_OFS)^));
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_AI_CalcStackAttackEffect_Start

function Hook_AI_CalcStackAttackEffect_End (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const
  ATTACKER            = 0;
  DEFENDER            = 1;
  EFFECT_VALUE        = 2;
  EFFECT_VALUE_CONST  = 3;

begin
  GameExt.EraSaveEventParams;

  GameExt.EraEventParams[ATTACKER]            :=  AIAttackerId;
  GameExt.EraEventParams[DEFENDER]            :=  AIDefenderId;
  GameExt.EraEventParams[EFFECT_VALUE]        :=  Context.EAX;
  GameExt.EraEventParams[EFFECT_VALUE_CONST]  :=  Context.EAX;

  Erm.FireErmEvent(Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT);
  Context.EAX :=  GameExt.EraEventParams[EFFECT_VALUE];
  
  GameExt.EraRestoreEventParams;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_AI_CalcStackAttackEffect_End

function Hook_EnterChat (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const
  NUM_ARGS  = 0;
  
  (* Event parameters *)
  EVENT_SUBTYPE = 0;
  BLOCK_CHAT    = 1;
  
  ON_ENTER_CHAT = 0;

begin
  GameExt.EraSaveEventParams;
  
  GameExt.EraEventParams[EVENT_SUBTYPE] :=  ON_ENTER_CHAT;
  GameExt.EraEventParams[BLOCK_CHAT]    :=  0;
  
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  result  :=  not LONGBOOL(GameExt.EraEventParams[BLOCK_CHAT]);
  
  GameExt.EraRestoreEventParams;
  
  if not result then begin
    Context.RetAddr :=  Core.Ret(NUM_ARGS);
  end; // .if
end; // .function Hook_EnterChat

procedure ClearChatBox; ASSEMBLER;
asm
  PUSH ESI
  MOV ESI, ECX
  MOV EAX, [ESI + $38]
  PUSH $5547A0
  // RET
end; // .procedure ClearChatBox

function Hook_ChatInput (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const 
  (* Event parameters *)
  ARG_EVENT_SUBTYPE = 0;
  ARG_CHAT_INPUT    = 1;
  ARG_ACTION        = 2;
  
  (* Event subtype *)
  ON_CHAT_INPUT = 1;
  
  (* Action flags *)
  ACTION_CLEAR_BOX  = 0;
  ACTION_CLOSE_BOX  = 1;
  ACTION_DEFAULT    = 2;

var
  Action: integer;
  Obj:    integer;
  
begin
  GameExt.EraSaveEventParams;
  
  GameExt.EraEventParams[ARG_EVENT_SUBTYPE] :=  ON_CHAT_INPUT;
  GameExt.EraEventParams[ARG_CHAT_INPUT]    :=  PINTEGER(Context.ECX + $34)^;
  GameExt.EraEventParams[ARG_ACTION]        :=  ACTION_DEFAULT;
  
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  Action  :=  GameExt.EraEventParams[ARG_ACTION];
  Obj     :=  Context.ECX;
  
  GameExt.EraRestoreEventParams;
  
  result  :=  not Core.EXEC_DEF_CODE;
  
  case Action of 
    ACTION_CLEAR_BOX: Context.RetAddr :=  @ClearChatBox;
    ACTION_CLOSE_BOX: begin
      Context.RetAddr :=  @ClearChatBox;
    
      asm
        MOV ECX, Obj
        MOV EDX, [ECX]
        MOV EAX, [EDX + $64]
        CALL EAX
      end; // .asm
    end; // .case ACTION_CLOSE_BOX    
  else
    result  :=  Core.EXEC_DEF_CODE;
  end; // .SWITCH Action
end; // .function Hook_ChatInput

function Hook_LeaveChat (Context: Core.PHookHandlerArgs): LONGBOOL; stdcall;
const
  (* Event parameters *)
  EVENT_SUBTYPE = 0;
  
  ON_LEAVE_CHAT = 2;

begin
  GameExt.EraSaveEventParams;
  
  GameExt.EraEventParams[EVENT_SUBTYPE] :=  ON_LEAVE_CHAT;
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  
  GameExt.EraRestoreEventParams;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_LeaveChat

procedure Hook_MainGameLoop (h: PatchApi.THiHook; This: pointer); stdcall;
begin
  if MainGameLoopDepth = 0 then begin
    Erm.FireErmEventEx(Erm.TRIGGER_ONGAMEENTER, []);
  end; // .if
  
  Inc(MainGameLoopDepth);
  PatchApi.Call(PatchApi.THISCALL_, h.GetDefaultFunc(), [This]);
  Dec(MainGameLoopDepth);
  
  if MainGameLoopDepth = 0 then begin
    Erm.FireErmEventEx(Erm.TRIGGER_ONGAMELEAVE, []);
    GameExt.SetMapFolder('');
  end; // .if
end; // .procedure Hook_MainGameLoop

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  (* extended MM Trigger *)
  Core.Hook(@Hook_BattleHint_GetAttacker, Core.HOOKTYPE_BRIDGE, 7, Ptr($492409));
  Core.Hook(@Hook_BattleHint_GetDefender, Core.HOOKTYPE_BRIDGE, 7, Ptr($492442));
  Core.Hook(@Hook_BattleHint_CalcMinMaxDamage, Core.HOOKTYPE_BRIDGE, 5, Ptr($493053));
  Core.Hook(@Hook_MMTrigger, Core.HOOKTYPE_BRIDGE, 5, Ptr($74FD3B));
  
  (* Key handling trigger *)
  Core.Hook(@Hook_CreateWindow, Core.HOOKTYPE_BRIDGE, 6, Ptr($4F8239));
  
  (* Stack to stack damage calculation *)
  Core.Hook(@Hook_StartCalcDamage, Core.HOOKTYPE_BRIDGE, 6, Ptr($443C88));
  Core.Hook(@Hook_CalcDamage_GetDamageBonus, Core.HOOKTYPE_BRIDGE, 5, Ptr($443CA1));
  Core.Hook(@Hook_EndCalcDamage, Core.HOOKTYPE_BRIDGE, 5, Ptr($443DA7));
  
  (* AI Target attack effect *)
  Core.Hook(@Hook_AI_CalcStackAttackEffect_Start, Core.HOOKTYPE_BRIDGE, 6, Ptr($4357E0));
  Core.Hook(@Hook_AI_CalcStackAttackEffect_End, Core.HOOKTYPE_BRIDGE, 5, Ptr($4358AA));
  
  (* OnChat trigger *)
  Core.Hook(@Hook_EnterChat, Core.HOOKTYPE_BRIDGE, 5, Ptr($4022B0));
  Core.Hook(@Hook_ChatInput, Core.HOOKTYPE_BRIDGE, 6, Ptr($554780));
  Core.Hook(@Hook_LeaveChat, Core.HOOKTYPE_BRIDGE, 6, Ptr($402298));
  Core.Hook(@Hook_LeaveChat, Core.HOOKTYPE_BRIDGE, 6, Ptr($402240));
  
  (* MainGameCycle: OnEnterGame, OnLeaveGame and MapFolder settings*)
  Core.p.WriteHiHook($4B0BA0, PatchApi.SPLICE_, PatchApi.EXTENDED_, PatchApi.THISCALL_,
                     @Hook_MainGameLoop);
end; // .procedure OnAfterWoG

begin
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
  GameExt.RegisterHandler(OnBeforeTrigger, 'OnBeforeTrigger');
end.
