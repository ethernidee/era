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
  NO_STACK = -1;

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
  WM_SYSKEYDOWN       = $104;
  WM_SYSCOMMAND       = $112;
  SC_KEYMENU          = $F100;
  KEY_F11             = 122;
  KEY_F12             = 123;
  ENABLE_DEF_REACTION = 0;

var
  RootDlgId: integer;
  SavedV:    array [1..10] of integer;
  SavedZ:    Erm.TErmZVar;

begin
  result := false;

  // Disable ALT + KEY menu shortcuts to allow scripts to use ALT for their own needs.
  if (Msg = WM_SYSCOMMAND) and (wParam = SC_KEYMENU) then begin
    exit;
  end;

  if (Msg = WM_KEYDOWN) or (Msg = WM_SYSKEYDOWN) then begin
    RootDlgId := Heroes.AdvManagerPtr^.GetRootDlgId;

    if wParam = KEY_F11 then begin
      GameExt.GenerateDebugInfo;

      if RootDlgId = Heroes.ADVMAP_DLGID then begin
        Heroes.PrintChatMsg('{~white}Debug information was dumped to ' + GameExt.DEBUG_DIR +'{~}');
      end;
    end else if (wParam = KEY_F12) and (RootDlgId = Heroes.ADVMAP_DLGID) then begin
      Erm.ReloadErm;
    end else begin
      Erm.ArgXVars[1] := wParam;
      Erm.ArgXVars[2] := ENABLE_DEF_REACTION;
      Erm.ArgXVars[3] := ((lParam shr 30) and 1) xor 1;

      if (RootDlgId = Heroes.ADVMAP_DLGID) and (Heroes.AdvManagerPtr^.CurrentDlg.FocusedItemId = -1) then begin
        Utils.CopyMem(sizeof(SavedV), @Erm.v[1], @SavedV);
        Utils.CopyMem(sizeof(SavedZ), @Erm.z[1], @SavedZ);

        Erm.FireErmEvent(Erm.TRIGGER_KEYPRESS);

        Utils.CopyMem(sizeof(SavedV), @SavedV, @Erm.v[1]);
        Utils.CopyMem(sizeof(SavedZ), @SavedZ, @Erm.z[1]);
      end else begin
        Erm.RetXVars[2] := ENABLE_DEF_REACTION;
      end;

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

var
  PrevHeroScreenHeroInd: integer = -1;

function Hook_ShowHeroScreen (OrigFunc: pointer; HeroInd: integer; ViewOnly: boolean; Unk1, Unk2: integer): integer; stdcall;
var
  SavedPrevHeroScreenHeroInd: integer;

begin
  SavedPrevHeroScreenHeroInd := PrevHeroScreenHeroInd;
  PrevHeroScreenHeroInd      := -1;

  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEventEx(Erm.TRIGGER_OPEN_HEROSCREEN, [HeroInd]);

  result := PatchApi.Call(FASTCALL_, OrigFunc, [HeroInd, ord(ViewOnly), Unk1, Unk2]);

  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEventEx(Erm.TRIGGER_POST_HEROSCREEN, [PrevHeroScreenHeroInd]);

  PrevHeroScreenHeroInd := SavedPrevHeroScreenHeroInd;
  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEventEx(Erm.TRIGGER_CLOSE_HEROSCREEN, [HeroInd]);
end;

function Hook_UpdateHeroScreen (Context: ApiJack.PHookContext): longbool; stdcall;
var
  HeroInd: integer;

begin
  HeroInd := Heroes.PHero(ppointer($698B70)^).Id;

  if PrevHeroScreenHeroInd <> -1 then begin
    Erm.FireErmEventEx(Erm.TRIGGER_POST_HEROSCREEN, [PrevHeroScreenHeroInd]);
    PrevHeroScreenHeroInd := -1;
  end;

  Erm.SetErmCurrHero(HeroInd);
  Erm.FireErmEventEx(Erm.TRIGGER_LOAD_HERO_SCREEN, [HeroInd]);

  PrevHeroScreenHeroInd := HeroInd;
  Erm.FireErmEventEx(Erm.TRIGGER_PRE_HEROSCREEN, [HeroInd]);

  result := true;
end;

function Hook_BeforeBattleStackTurn (Context: ApiJack.PHookContext): longbool; stdcall;
const
  PARAM_STACK_ID = 1;

var
  Stack:      pointer;
  StackId:    integer;
  NewStackId: integer;

begin
  Stack      := Ptr(Context.EDI);
  StackId    := Heroes.GetVal(Stack, STACK_SIDE).v * Heroes.NUM_BATTLE_STACKS_PER_SIDE + Heroes.GetVal(Stack, STACK_IND).v;
  Erm.FireErmEventEx(Erm.TRIGGER_BEFORE_STACK_TURN, [StackId]);
  NewStackId := Erm.RetXVars[PARAM_STACK_ID];

  if (NewStackId >= 0) and (NewStackId < Heroes.NUM_BATTLE_STACKS) then begin
    // Replace active stack pointer both in register and local variable
    Context.EDI                 := integer(Heroes.StackProp(0, 0)) + Heroes.STACK_STRUCT_SIZE * NewStackId;
    pinteger(Context.EBP - $8)^ := Context.EDI;
  end else begin
    ShowMessage('OnBeforeBattleStackTurn: invalid stack ID. Expected 0..41. Got: ' + SysUtils.IntToStr(NewStackId));
  end;

  result := true;
end; // .function Hook_BeforeBattleStackTurn

function Hook_Battle_StackObtainsTurn (OrigFunc: pointer; CombatManager: pointer; Side, StackInd: integer): integer; stdcall;
const
  PARAM_SIDE      = 1;
  PARAM_STACK_IND = 2;

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
    ShowMessage('OnBattleStackObtainsTurn: invalid side, set in event handler. Expected 0..1. Got: ' + SysUtils.IntToStr(NewSide));
  end;

  if (NewStackInd >= 0) and (NewStackInd < Heroes.NUM_BATTLE_STACKS_PER_SIDE) then begin
    StackInd := NewStackInd;
  end else begin
    ShowMessage('OnBattleStackObtainsTurn: invalid new stack index, set in event handler. Expected: 0..20. Got: = ' + SysUtils.IntToStr(NewStackInd));
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
  StackInd     := Heroes.GetVal(Ptr(Context.ECX), STACK_SIDE).v * Heroes.NUM_BATTLE_STACKS_PER_SIDE + Heroes.GetVal(Ptr(Context.ECX), STACK_IND).v;
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

var
  PrevTownScreenId: integer = -1;

function Hook_EnterTownScreen (OrigFunc: pointer; DlgManager, TownDlg: pointer): integer; stdcall;
const
  TOWN_DLG_CONSTRUCTOR = $643730;

var
  TownId: integer;

begin
  if pinteger(TownDlg)^ <> TOWN_DLG_CONSTRUCTOR then begin
    result := PatchApi.Call(THISCALL_, OrigFunc, [DlgManager, TownDlg]);
  end else begin
    TownId := Heroes.GetTownManager.Town.Id;

    Erm.FireErmEventEx(Erm.TRIGGER_OPEN_TOWN_SCREEN, [TownId]);
    PrevTownScreenId := TownId;
    Erm.FireErmEventEx(Erm.TRIGGER_PRE_TOWN_SCREEN, [TownId]);

    result := PatchApi.Call(THISCALL_, OrigFunc, [DlgManager, TownDlg]);

    Erm.FireErmEventEx(Erm.TRIGGER_POST_TOWN_SCREEN, [PrevTownScreenId]);
    PrevTownScreenId := -1;
    Erm.FireErmEventEx(Erm.TRIGGER_CLOSE_TOWN_SCREEN, [TownId]);
  end;
end; // .function Hook_EnterTownScreen

function Hook_SwitchTownScreen (Context: ApiJack.PHookContext): longbool; stdcall;
var
  TownId: integer;

begin
  TownId := Heroes.GetTownManager.Town.Id;
  Erm.FireErmEventEx(Erm.TRIGGER_SWITCH_TOWN_SCREEN, [TownId]);

  if PrevTownScreenId <> -1 then begin
    Erm.FireErmEventEx(Erm.TRIGGER_POST_TOWN_SCREEN, [PrevTownScreenId]);
  end;

  PrevTownScreenId := TownId;
  Erm.FireErmEventEx(Erm.TRIGGER_PRE_TOWN_SCREEN, [TownId]);

  result := true;
end;

function Hook_InitMonInfoDlg (Context: ApiJack.PHookContext): longbool; stdcall;
const
  ARG_MON_UPGRADE_TYPE = 2;

var
  IsReadOnlyDlg: longbool;
  Town:          Heroes.PTown;
  Hero:          Heroes.PHero;
  TownId:        integer;
  HeroId:        integer;
  MonType:       integer;
  UpgradeType:   integer;

begin
  IsReadOnlyDlg := pbyte(Context.EBP + $24)^ <> 0;

  if not IsReadOnlyDlg then begin
    Town        := ppointer(Context.EBP + $14)^;
    Hero        := ppointer(Context.EBP + $10)^;
    HeroId      := -1;
    TownId      := -1;
    MonType     := Utils.PEndlessIntArr(ppointer(Context.EBP + $8)^)[pinteger(Context.EBP + $0C)^];
    UpgradeType := pinteger(Context.EBP - $14)^;

    if Town <> nil then begin
      TownId := Town.Id;
    end;

    if Hero <> nil then begin
      HeroId := Hero.Id;
    end;

    Erm.FireErmEventEx(Erm.TRIGGER_DETERMINE_MON_INFO_DLG_UPGRADE, [MonType, UpgradeType, TownId, HeroId]);
    pinteger(Context.EBP - $14)^ := Erm.RetXVars[ARG_MON_UPGRADE_TYPE];
  end; // .if

  result := true;
end; // .function Hook_InitMonInfoDlg

function Hook_CalculateTownIncome (OrigFunc: pointer; Town: Heroes.PTown; WithResourceSilo: integer): integer; stdcall;
const
  ARG_TOWN                  = 1;
  ARG_INCOME                = 2;
  ARG_ACCOUNT_RESOURCE_SILO = 3;

begin
  result := PatchApi.Call(THISCALL_, OrigFunc, [Town, WithResourceSilo]);
  Erm.FireErmEventEx(Erm.TRIGGER_CALC_TOWN_INCOME, [Town.Id, result, WithResourceSilo]);
  result := Erm.RetXVars[ARG_INCOME];
end;

function Hook_BeforeHumanLocalEvent (Context: ApiJack.PHookContext): longbool; stdcall;
var
  x, y, z: integer;

begin
  Heroes.UnpackCoords(pinteger(Context.EBP + $10)^, x, y, z);

  Erm.ZvsGmAiFlags^ := -1;
  Erm.SetErmCurrHero(PHero(ppointer(Context.EBP + 8)^));
  Erm.FireErmEventEx(Erm.TRIGGER_BEFORE_LOCAL_EVENT, [x, y, z]);

  result := true;
end;

function Hook_AfterHumanLocalEvent (Context: ApiJack.PHookContext): longbool; stdcall;
var
  x, y, z: integer;

begin
  Heroes.UnpackCoords(pinteger(Context.EBP + $10)^, x, y, z);

  Erm.ZvsGmAiFlags^ := -1;
  Erm.SetErmCurrHero(PHero(ppointer(Context.EBP + 8)^));
  Erm.FireErmEventEx(Erm.TRIGGER_AFTER_LOCAL_EVENT, [x, y, z]);

  result := true;
end;

function Hook_ScenarioEnd (Context: ApiJack.PHookContext): longbool; stdcall;
const
  IS_GAME_WON_GLOBAL_ADDR = $699560; // boolean

begin
  if pbyte(IS_GAME_WON_GLOBAL_ADDR)^ <> 0 then begin
    Erm.FireErmEvent(Erm.TRIGGER_WIN_GAME);
  end else begin
    Erm.FireErmEvent(Erm.TRIGGER_LOSE_GAME);
  end;

  result := true;
end;

function Hook_TransferHeroToNextScenario (Context: ApiJack.PHookContext): longbool; stdcall;
const
  TRANSFERRED_HERO_GLOBAL_ADDR = $280761C; // int

begin
  Erm.FireErmEventEx(Erm.TRIGGER_TRANSFER_HERO, [pinteger(TRANSFERRED_HERO_GLOBAL_ADDR)^]);
  result := true;
end;

procedure OnExternalGameLeave (Event: GameExt.PEvent); stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_ONGAMELEAVE);
  GameExt.SetMapDir('');
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
  ApiJack.HookCode(Ptr($464DF1), @Hook_BeforeBattleStackTurn);
  ApiJack.StdSplice(Ptr($464F10), @Hook_Battle_StackObtainsTurn, ApiJack.CONV_THISCALL, 3);

  (* OnBattleRegeneratePhase event *)
  ApiJack.HookCode(Ptr($446B50), @Hook_BattleRegeneratePhase);
  ApiJack.HookCode(Ptr($446BD6), @Hook_BattleDoRegenerate);

  (* OnBuildTownBuilding event *)
  ApiJack.StdSplice(Ptr($5BF1E0), @Hook_BuildTownBuilding, ApiJack.CONV_THISCALL, 4);

  (* OnEnterTownScreen event *)
  ApiJack.StdSplice(Ptr($4B09D0), @Hook_EnterTownScreen, ApiJack.CONV_THISCALL, 2);

  (* OnEnterTownScreen event *)
  ApiJack.HookCode(Ptr($5D4709), @Hook_SwitchTownScreen);

  (* OnDetermineMonInfoDlgUpgrade *)
  ApiJack.HookCode(Ptr($4C6B1C), @Hook_InitMonInfoDlg);

  (* OnCalculateTownIncome + widen result from int16 to int32 *)
  Core.p.WriteDataPatch(Ptr($4C76AD), ['909090']);
  Core.p.WriteDataPatch(Ptr($45246F), ['8BD090']);
  Core.p.WriteDataPatch(Ptr($51C858), ['909090']);
  Core.p.WriteDataPatch(Ptr($52A20E), ['8BD090']);
  Core.p.WriteDataPatch(Ptr($530AE6), ['909090']);
  Core.p.WriteDataPatch(Ptr($5C6C19), ['909090']);
  ApiJack.StdSplice(Ptr($5BFA00), @Hook_CalculateTownIncome, ApiJack.CONV_THISCALL, 1);

  (* OnBeforeLocalEvent, OnAfterLocalEvent *)
  ApiJack.HookCode(Ptr($74DB1D), @Hook_BeforeHumanLocalEvent);
  ApiJack.HookCode(Ptr($74DC24), @Hook_AfterHumanLocalEvent);

  (* OnWinGame, OnLoseGame *)
  ApiJack.HookCode(Ptr($4EFEEA), @Hook_ScenarioEnd);

  (* OnWinGame, OnLoseGame *)
  ApiJack.HookCode(Ptr($755E00), @Hook_TransferHeroToNextScenario);
end; // .procedure OnAfterWoG

begin
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('$OnGameLeave', OnExternalGameLeave);
end.
