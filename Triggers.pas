unit Triggers;
{
DESCRIPTION:  Extends ERM with new triggers
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Utils,
  Core, PatchApi, GameExt, Heroes, ApiJack, Erm, EventMan;

const
  NO_STACK  = -1;
  
  STACK_POS_OFS = $38;


(* Returns true, if current moment is between GameEnter and GameLeave events *)
function IsGameLoop: boolean;


(***) implementation (***)


const
  (* extended MM Trigger *)
  ATTACKER_STACK_N_PARAM  = 1;
  DEFENDER_STACK_N_PARAM  = 2;
  MIN_DAMAGE_PARAM        = 3;
  MAX_DAMAGE_PARAM        = 4;

  
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
  

function IsGameLoop: boolean;
begin
  result := MainGameLoopDepth > 0;
end;

function Hook_BattleHint_GetAttacker (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[ATTACKER_STACK_N_PARAM] := Context.EAX;
  Erm.ArgXVars[DEFENDER_STACK_N_PARAM] := NO_STACK;
  Erm.ArgXVars[MIN_DAMAGE_PARAM]       := -1;
  Erm.ArgXVars[MAX_DAMAGE_PARAM]       := -1;
  
  result := Core.EXEC_DEF_CODE;
end;

function Hook_BattleHint_GetDefender (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[DEFENDER_STACK_N_PARAM] := Context.EAX;
  result                               := Core.EXEC_DEF_CODE;
end;

function Hook_BattleHint_CalcMinMaxDamage (Context: Core.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[MIN_DAMAGE_PARAM] := Context.EDI;
  Erm.ArgXVars[MAX_DAMAGE_PARAM] := Context.EAX;
  result                         := Core.EXEC_DEF_CODE;
end;

function MainWndProc (hWnd, Msg, wParam, lParam: integer): longbool; stdcall;
const
  WM_KEYDOWN          = $100;
  KEY_F11             = 122;
  KEY_F12             = 123;
  ENABLE_DEF_REACTION = 0;

var
  GameState: Heroes.TGameState;
  SavedV:    array [1..10] of integer;
  SavedZ:    Erm.TErmZVar;
  
begin
  result := false;
  
  if Msg = WM_KEYDOWN then begin
    Heroes.GetGameState(GameState);
    
    if wParam = KEY_F11 then begin
      GameExt.GenerateDebugInfo;

      if GameState.RootDlgId = Heroes.ADVMAP_DLGID then begin
        Heroes.PrintChatMsg('{~white}Debug information was dumped to ' + GameExt.DEBUG_DIR +'{~}');
      end;
    end else if (wParam = KEY_F12) and (GameState.RootDlgId = Heroes.ADVMAP_DLGID) then begin
      Erm.ReloadErm;
    end else begin
      Erm.ArgXVars[1] := wParam;
      Erm.ArgXVars[2] := ENABLE_DEF_REACTION;
      
      if GameState.RootDlgId = Heroes.ADVMAP_DLGID then begin
        Utils.CopyMem(sizeof(SavedV), @Erm.v[1], @SavedV);
        Utils.CopyMem(sizeof(SavedZ), @Erm.z[1], @SavedZ);
        
        Erm.FireErmEvent(Erm.TRIGGER_KEYPRESS);

        Utils.CopyMem(sizeof(SavedV), @SavedV, @Erm.v[1]);
        Utils.CopyMem(sizeof(SavedZ), @SavedZ, @Erm.z[1]);
      end else begin
        GameExt.FireEvent('OnKeyPressed', GameExt.NO_EVENT_DATA, 0);
      end; // .else
      
      result := Erm.RetXVars[2] = ENABLE_DEF_REACTION;
      
      if result then begin
        PrevWndProc(hWnd, Msg, wParam, lParam);
      end;
    end; // .else
  end else begin
    result := PrevWndProc(hWnd, Msg, wParam, lParam);
  end; // .else
end; // .function MainWndProc

function Hook_AfterCreateWindow (Context: Core.PHookContext): longbool; stdcall;
begin
  PrevWndProc := Ptr(Windows.SetWindowLong(Heroes.hWnd^, Windows.GWL_WNDPROC, integer(@MainWndProc)));

  EventMan.GetInstance.Fire('OnAfterCreateWindow');
  
  result := true;
end;

function Hook_StartCalcDamage (Context: Core.PHookContext): longbool; stdcall;
begin
  AttackerId := Heroes.GetStackIdByPos(pinteger(Context.EBX + STACK_POS_OFS)^);
  DefenderId := Heroes.GetStackIdByPos(pinteger(Context.ESI + STACK_POS_OFS)^);
  
  BasicDamage         := pinteger(Context.EBP + 12)^;
  IsDistantAttack     := pinteger(Context.EBP + 16)^;
  IsTheoreticalAttack := pinteger(Context.EBP + 20)^;
  Distance            := pinteger(Context.EBP + 24)^;
  
  result := Core.EXEC_DEF_CODE;
end; // .function Hook_StartCalcDamage

function Hook_CalcDamage_GetDamageBonus (Context: Core.PHookContext): longbool; stdcall;
begin
  DamageBonus := Context.EAX;
  result      := true;
end;

function Hook_EndCalcDamage (Context: Core.PHookContext): longbool; stdcall;
const
  ATTACKER           = 1;
  DEFENDER           = 2;
  FINAL_DAMAGE_CONST = 3;
  FINAL_DAMAGE       = 4;
  BASIC_DAMAGE       = 5;
  DAMAGE_BONUS       = 6;
  IS_DISTANT         = 7;
  DISTANCE_ARG       = 8;
  IS_THEORETICAL     = 9;

begin
  Erm.ArgXVars[ATTACKER]           := AttackerId;
  Erm.ArgXVars[DEFENDER]           := DefenderId;
  Erm.ArgXVars[FINAL_DAMAGE_CONST] := Context.EAX;
  Erm.ArgXVars[FINAL_DAMAGE]       := Context.EAX;
  Erm.ArgXVars[BASIC_DAMAGE]       := BasicDamage;
  Erm.ArgXVars[DAMAGE_BONUS]       := DamageBonus;
  Erm.ArgXVars[IS_DISTANT]         := IsDistantAttack;
  Erm.ArgXVars[DISTANCE_ARG]       := Distance;
  Erm.ArgXVars[IS_THEORETICAL]     := IsTheoreticalAttack;

  Erm.FireErmEvent(Erm.TRIGGER_ONSTACKTOSTACKDAMAGE);
  
  Context.EAX := Erm.RetXVars[FINAL_DAMAGE];
  result      := Core.EXEC_DEF_CODE;
end; // .function Hook_EndCalcDamage

function Hook_AI_CalcStackAttackEffect_Start (Context: Core.PHookContext): longbool; stdcall;
begin
  AIAttackerId := Heroes.GetBattleCellStackId(Heroes.GetBattleCellByPos(pinteger(pinteger(Context.ESP + 8)^ + STACK_POS_OFS)^));
  AIDefenderId := Heroes.GetBattleCellStackId(Heroes.GetBattleCellByPos(pinteger(pinteger(Context.ESP + 16)^ + STACK_POS_OFS)^));
  result       := true;
end;

function Hook_AI_CalcStackAttackEffect_End (Context: Core.PHookContext): longbool; stdcall;
const
  ATTACKER           = 1;
  DEFENDER           = 2;
  EFFECT_VALUE       = 3;
  EFFECT_VALUE_CONST = 4;

begin
  Erm.ArgXVars[ATTACKER]           := AIAttackerId;
  Erm.ArgXVars[DEFENDER]           := AIDefenderId;
  Erm.ArgXVars[EFFECT_VALUE]       := Context.EAX;
  Erm.ArgXVars[EFFECT_VALUE_CONST] := Context.EAX;

  Erm.FireErmEvent(Erm.TRIGGER_ONAICALCSTACKATTACKEFFECT);
  
  Context.EAX := Erm.RetXVars[EFFECT_VALUE];
  result      := true;
end; // .function Hook_AI_CalcStackAttackEffect_End

function Hook_EnterChat (Context: Core.PHookContext): longbool; stdcall;
const
  NUM_ARGS = 0;
  
  (* Event parameters *)
  EVENT_SUBTYPE = 1;
  BLOCK_CHAT    = 2;
  
  ON_ENTER_CHAT = 0;

begin  
  Erm.ArgXVars[EVENT_SUBTYPE] := ON_ENTER_CHAT;
  Erm.ArgXVars[BLOCK_CHAT]    := 0;
  
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  result := not longbool(Erm.RetXVars[BLOCK_CHAT]);
  
  if not result then begin
    Context.RetAddr := Core.Ret(NUM_ARGS);
  end;
end; // .function Hook_EnterChat

procedure ClearChatBox; assembler;
asm
  PUSH ESI
  MOV ESI, ECX
  MOV EAX, [ESI + $38]
  PUSH $5547A0
  // RET
end;

function Hook_ChatInput (Context: Core.PHookContext): longbool; stdcall;
const 
  (* Event parameters *)
  ARG_EVENT_SUBTYPE = 1;
  ARG_CHAT_INPUT    = 2;
  ARG_ACTION        = 3;
  
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
  Erm.ArgXVars[ARG_EVENT_SUBTYPE] := ON_CHAT_INPUT;
  Erm.ArgXVars[ARG_CHAT_INPUT]    := pinteger(Context.ECX + $34)^;
  Erm.ArgXVars[ARG_ACTION]        := ACTION_DEFAULT;
  
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  Action := Erm.RetXVars[ARG_ACTION];
  Obj    := Context.ECX;
  result := false;
  
  case Action of 
    ACTION_CLEAR_BOX: Context.RetAddr := @ClearChatBox;
    ACTION_CLOSE_BOX: begin
      Context.RetAddr := @ClearChatBox;
    
      asm
        MOV ECX, Obj
        MOV EDX, [ECX]
        MOV EAX, [EDX + $64]
        CALL EAX
      end; // .asm
    end; // .case ACTION_CLOSE_BOX    
  else
    result := true;
  end; // .switch Action
end; // .function Hook_ChatInput

function Hook_LeaveChat (Context: Core.PHookContext): longbool; stdcall;
const
  (* Event parameters *)
  EVENT_SUBTYPE = 1;
  
  ON_LEAVE_CHAT = 2;

begin 
  Erm.ArgXVars[EVENT_SUBTYPE] := ON_LEAVE_CHAT;
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);
  
  result := true;
end;

procedure Hook_MainGameLoop (h: PatchApi.THiHook; This: pointer); stdcall;
begin
  Inc(MainGameLoopDepth);

  if MainGameLoopDepth = 1 then begin
    Erm.FireErmEventEx(Erm.TRIGGER_ONGAMEENTER, []);
  end;
  
  PatchApi.Call(PatchApi.THISCALL_, h.GetDefaultFunc(), [This]);
  
  if MainGameLoopDepth = 1 then begin
    Erm.FireErmEvent(Erm.TRIGGER_ONGAMELEAVE);
    GameExt.SetMapDir('');
  end;

  Dec(MainGameLoopDepth);
end; // .procedure Hook_MainGameLoop

function Hook_KingdomOverviewMouseClick (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  result := Erm.FireMouseEvent(Erm.TRIGGER_KINGDOM_OVERVIEW_MOUSE_CLICK, Ptr(Context.EDI));

  if not result then begin
    Context.RetAddr := Ptr($521E84);
  end;
end;

function Hook_OnHeroesInteraction (OrigFunc: pointer; Unk1: integer; Hero1: Heroes.PHero; Hero2IndPtr: pinteger; Unk2, Unk3: integer): integer; stdcall;
const
  PARAM_FIRST_HERO_ID      = 1;
  PARAM_SECOND_HERO_ID     = 2;
  PARAM_ENABLE_INTERACTION = 3;

var
  SecondHeroId: integer;

begin
  SecondHeroId                           := Hero2IndPtr^;
  Erm.ArgXVars[PARAM_FIRST_HERO_ID]      := Hero1.Id;
  Erm.ArgXVars[PARAM_SECOND_HERO_ID]     := SecondHeroId;
  Erm.ArgXVars[PARAM_ENABLE_INTERACTION] := 1;
  Erm.FireErmEvent(Erm.TRIGGER_BEFOREHEROINTERACT);

  if Erm.RetXVars[PARAM_ENABLE_INTERACTION] <> 0 then begin
    result := PatchApi.Call(THISCALL_, OrigFunc, [Unk1, Hero1, Hero2IndPtr, Unk2, Unk3]);
    Erm.FireErmEventEx(Erm.TRIGGER_AFTERHEROINTERACT, [Hero1.Id, SecondHeroId]);
  end else begin
    result := 0;
    Erm.FireErmEventEx(Erm.TRIGGER_AFTERHEROINTERACT, [Hero1.Id, SecondHeroId]);
  end;
end;

function Hook_SaveGame_After (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_AFTER_SAVE_GAME);
  result := true;
end;

function Hook_ShowHeroScreen (OrigFunc: pointer; HeroInd: integer; ViewOnly: boolean; Unk1, Unk2: integer): integer; stdcall;
begin
  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEvent(Erm.TRIGGER_OPEN_HEROSCREEN);
  result := PatchApi.Call(FASTCALL_, OrigFunc, [HeroInd, ord(ViewOnly), Unk1, Unk2]);
  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEvent(Erm.TRIGGER_CLOSE_HEROSCREEN);
end;

function Hook_UpdateHeroScreen (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.SetErmCurrHero(Heroes.PHero(ppointer($698B70)^));
  Erm.FireErmEvent(Erm.TRIGGER_LOAD_HERO_SCREEN);
  result := true;
end;

function Hook_Battle_StackObtainsTurn (OrigFunc: pointer; CombatManager: pointer; Side, StackInd: integer): integer; stdcall;
const
  PARAM_SIDE      = 1;
  PARAM_STACK_IND = 2;

  MAX_STACKS_PER_SIDE = Heroes.NUM_BATTLE_STACKS div 2;

var
  NewSide:     integer;
  NewStackInd: integer;

begin
  Erm.FireErmEventEx(Erm.TRIGGER_STACK_OBTAINS_TURN, [Side, StackInd]);
  NewSide     := Erm.RetXVars[PARAM_SIDE];
  NewStackInd := Erm.RetXVars[PARAM_STACK_IND];
  
  if (NewSide >= 0) and (NewSide <= 1) then begin
    Side := NewSide;
  end else begin
    ShowMessage('OnBattleStackObtainsTurn: invalid side, set in event handler. Expected 0..1. Got: ' + IntToStr(NewSide));
  end;

  if (NewStackInd >= 0) and (NewStackInd < MAX_STACKS_PER_SIDE) then begin
    StackInd := NewStackInd;
  end else begin
    ShowMessage('OnBattleStackObtainsTurn: invalid new stack index, set in event handler. Expected: 0..20. Got: = ' + IntToStr(NewStackInd));
  end;
 
  result := PatchApi.Call(THISCALL_, OrigFunc, [CombatManager, Side, StackInd]);
end; // .function Hook_Battle_StackObtainsTurn

var
  DisableRegen: boolean;

function Hook_BattleRegeneratePhase (Context: ApiJack.PHookContext): longbool; stdcall;
const
  COMBAT_MON_RECORD_SIZE = 1352;

  PARAM_STACK_IND      = 1;
  PARAM_MON_STRUCT_PTR = 2;
  PARAM_DISABLE_REGEN  = 3;

var
  StackInd: integer;

begin
  StackInd     := (Context.ECX - integer(Heroes.StackProp(0, 0))) div COMBAT_MON_RECORD_SIZE;
  Erm.FireErmEventEx(Erm.TRIGGER_REGENERATE_PHASE, [StackInd, Context.ECX, 0]);
  DisableRegen := Erm.RetXVars[PARAM_DISABLE_REGEN] <> 0;
  result       := true;
end;

function Hook_BattleDoRegenerate (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  result := not DisableRegen;
end;

function Hook_BuildTownBuilding (OrigFunc: pointer; Town: Heroes.PTown; BuildingId, Unk1, Unk2: integer): integer; stdcall;
const
  PARAM_TOWN_ID     = 1;
  PARAM_BUILDING_ID = 2;

begin
  Erm.FireErmEventEx(Erm.TRIGGER_BUILD_TOWN_BUILDING, [Town.Id, BuildingId]);
  result := PatchApi.Call(THISCALL_, OrigFunc, [Town, BuildingId, Unk1, Unk2]);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  (* extended MM Trigger *)
  Core.Hook(@Hook_BattleHint_GetAttacker, Core.HOOKTYPE_BRIDGE, 7, Ptr($492409));
  Core.Hook(@Hook_BattleHint_GetDefender, Core.HOOKTYPE_BRIDGE, 7, Ptr($492442));
  Core.Hook(@Hook_BattleHint_CalcMinMaxDamage, Core.HOOKTYPE_BRIDGE, 5, Ptr($493053));
  
  (* Key handling trigger *)
  Core.Hook(@Hook_AfterCreateWindow, Core.HOOKTYPE_BRIDGE, 6, Ptr($4F8226));
  
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
  Core.p.WriteHiHook(Ptr($4B0BA0), PatchApi.SPLICE_, PatchApi.EXTENDED_, PatchApi.THISCALL_,  @Hook_MainGameLoop);

  (* Kingdom Overview mouse click *)
  ApiJack.HookCode(Ptr($521E50), @Hook_KingdomOverviewMouseClick);

  (* OnBeforeHeroInteraction trigger *)
  ApiJack.StdSplice(Ptr($4A2470), @Hook_OnHeroesInteraction, ApiJack.CONV_THISCALL, 5);

  (* OnAfterSaveGame trigger *)
  ApiJack.HookCode(Ptr($4BEDBE), @Hook_SaveGame_After);

  (* Hero screen Enter/Exit triggers *)
  ApiJack.StdSplice(Ptr($4E1A70), @Hook_ShowHeroScreen, ApiJack.CONV_FASTCALL, 4);

  (* Add OnLoadHeroScreen event *)
  ApiJack.HookCode(Ptr($4E1CC0), @Hook_UpdateHeroScreen);

  (* OnBattleStackObtainsTurn event *)
  ApiJack.StdSplice(Ptr($464F10), @Hook_Battle_StackObtainsTurn, ApiJack.CONV_THISCALL, 3);

  (* OnBattleRegeneratePhase event *)
  ApiJack.HookCode(Ptr($446B50), @Hook_BattleRegeneratePhase);
  ApiJack.HookCode(Ptr($446BD6), @Hook_BattleDoRegenerate);

  (* OnBuild event *)
  ApiJack.StdSplice(Ptr($5BF1E0), @Hook_BuildTownBuilding, ApiJack.CONV_THISCALL, 4);
end; // .procedure OnAfterWoG

begin
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
