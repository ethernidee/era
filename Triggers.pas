unit Triggers;
(*
  Description: Extends ERM with new triggers
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  Math,
  Messages,
  SysUtils,
  Windows,

  Alg,
  ApiJack,
  Core,
  DataLib,
  DlgMes,
  Log,
  PatchApi,
  Utils,
  WindowMessages,

  EraSettings,
  Erm,
  EventLib,
  EventMan,
  GameExt,
  Heroes,
  Tweaks,
  WogEvo;

type
(* Import *)
  TObjDict = DataLib.TObjDict;

const
  STD_REGENERATION_VALUE = -1;


(* Returns true, if current moment is between GameEnter and GameLeave events *)
function IsGameLoop: boolean;

(* Exits adventure manager dialogs and/or all subdialogs and immediately returns to game menu screen by raising special exception.
  TargetScreen: -1 (no screen), 102 - Load Menu, etc *)
procedure FastQuitToGameMenu (TargetScreen: integer); stdcall;

procedure SetRegenerationAbility (MonId: integer; Chance: integer = 100; HitPoints: integer = STD_REGENERATION_VALUE; HpPercents: integer = 0); stdcall;
procedure SetStdRegenerationEffect (Level7Percents: integer; HpPercents: integer); stdcall;


(***) implementation (***)


const
  NO_STACK = -1;
  STACK_POS_OFS = $38;

  (* extended MM Trigger *)
  ATTACKER_STACK_N_PARAM  = 1;
  DEFENDER_STACK_N_PARAM  = 2;
  MIN_DAMAGE_PARAM        = 3;
  MAX_DAMAGE_PARAM        = 4;

type
  TRegenerationAbility = class
   public
    Chance:     integer;
    HitPoints:  integer;
    HpPercents: integer;

    constructor Create (Chance: integer; HitPoints: integer; HpPercents: integer);
  end;

var
  ZvsCanNpcRegenerate:   function (MonType: integer; Stack: Heroes.PBattleStack): integer cdecl = Ptr($76D844);
  ZvsIsNpcNotCreature:   function (Stack: HEroes.PBattleStack): boolean cdecl = Ptr($76BA4D);
  ZvsCrExpBonRegenerate: function (Stack: Heroes.PBattleStack; HpLost: integer): integer cdecl = Ptr($71EAA6);

var
(* Normalized regeneration abilities *)
{O} MonsWithRegeneration:   {O} TObjDict {of TRegenerationAbility};
    StdRegenLevel7Percents: integer = 40;
    StdRegenHpPercents:     integer = 20;

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

  LogWindowMessagesOpt: boolean;


constructor TRegenerationAbility.Create (Chance: integer; HitPoints: integer; HpPercents: integer);
begin
  Self.Chance     := Chance;
  Self.HitPoints  := HitPoints;
  Self.HpPercents := HpPercents;
end;

function IsGameLoop: boolean;
begin
  result := MainGameLoopDepth > 0;
end;

function Hook_BattleHint_GetAttacker (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[ATTACKER_STACK_N_PARAM] := Context.EAX;
  Erm.ArgXVars[DEFENDER_STACK_N_PARAM] := NO_STACK;
  Erm.ArgXVars[MIN_DAMAGE_PARAM]       := -1;
  Erm.ArgXVars[MAX_DAMAGE_PARAM]       := -1;

  result := Core.EXEC_DEF_CODE;
end;

function Hook_BattleHint_GetDefender (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[DEFENDER_STACK_N_PARAM] := Context.EAX;
  result                               := Core.EXEC_DEF_CODE;
end;

function Hook_BattleHint_CalcMinMaxDamage (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.ArgXVars[MIN_DAMAGE_PARAM] := Context.EDI;
  Erm.ArgXVars[MAX_DAMAGE_PARAM] := Context.EAX;
  result                         := Core.EXEC_DEF_CODE;
end;

function MainWndProc (hWnd, Msg, wParam, lParam: integer): longbool; stdcall;
const
  WM_KEYDOWN          = $100;
  WM_KEYUP            = $101;
  WM_SYSKEYDOWN       = $104;
  WM_SYSKEYUP         = $105;
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

  if
    LogWindowMessagesOpt     and (Msg <> WM_MOUSEMOVE)  and (Msg <> WM_TIMER)        and (Msg <> WM_SETCURSOR)  and (Msg <> WM_NCHITTEST) and (Msg <> WM_NCMOUSEMOVE) and
    (Msg <> WM_NCMOUSEHOVER) and (Msg <> WM_MOUSEHOVER) and (Msg <> WM_NCMOUSELEAVE) and (Msg <> WM_MOUSELEAVE) and (Msg <> WM_PAINT)     and (Msg <> WM_GETICON)
  then begin
    Log.Write('WndProc', 'HandleMessage', SysUtils.Format('%s %d %d', [WindowMessages.MessageIdToStr(Msg), wParam, lParam]));
  end;

  // Disable ALT + KEY menu shortcuts to allow scripts to use ALT for their own needs.
  if (Msg = WM_SYSCOMMAND) and (wParam = SC_KEYMENU) then begin
    exit;
  end;

  if (Msg = WM_KEYDOWN) or (Msg = WM_SYSKEYDOWN) then begin
    RootDlgId := Heroes.WndManagerPtr^.GetRootDlgId;

    if wParam = KEY_F11 then begin
      GameExt.GenerateDebugInfo;

      if RootDlgId = Heroes.ADVMAP_DLGID then begin
        Heroes.PrintChatMsg('{~white}Debug information was dumped to ' + EraSettings.DEBUG_DIR +'{~}');
      end;
    end else if (wParam = KEY_F12) and (RootDlgId = Heroes.ADVMAP_DLGID) then begin
      Erm.ReloadErm;
    end else begin
      Erm.ArgXVars[1] := wParam;
      Erm.ArgXVars[2] := ENABLE_DEF_REACTION;
      Erm.ArgXVars[3] := ((lParam shr 30) and 1) xor 1;

      if (RootDlgId = Heroes.ADVMAP_DLGID) and (Heroes.WndManagerPtr^.CurrentDlg.FocusedItemId = -1) then begin
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
  end else if (Msg = WM_KEYUP) or (Msg = WM_SYSKEYUP) then begin
    RootDlgId := Heroes.WndManagerPtr^.GetRootDlgId;

    Erm.ArgXVars[1] := wParam;
    Erm.ArgXVars[2] := ENABLE_DEF_REACTION;
    Erm.ArgXVars[3] := ((lParam shr 30) and 1) xor 1;

    if (RootDlgId = Heroes.ADVMAP_DLGID) and (Heroes.WndManagerPtr^.CurrentDlg.FocusedItemId = -1) then begin
      Utils.CopyMem(sizeof(SavedV), @Erm.v[1], @SavedV);
      Utils.CopyMem(sizeof(SavedZ), @Erm.z[1], @SavedZ);

      Erm.FireErmEvent(Erm.TRIGGER_KEY_RELEASED);

      Utils.CopyMem(sizeof(SavedV), @SavedV, @Erm.v[1]);
      Utils.CopyMem(sizeof(SavedZ), @SavedZ, @Erm.z[1]);
    end else begin
      Erm.RetXVars[2] := ENABLE_DEF_REACTION;
    end;

    result := Erm.RetXVars[2] = ENABLE_DEF_REACTION;

    if result then begin
      PrevWndProc(hWnd, Msg, wParam, lParam);
    end;
  end else begin
    result := PrevWndProc(hWnd, Msg, wParam, lParam);
  end; // .else
end; // .function MainWndProc

function Hook_AfterCreateWindow (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  PrevWndProc := Ptr(Windows.SetWindowLong(Heroes.hWnd^, Windows.GWL_WNDPROC, integer(@MainWndProc)));

  EventMan.GetInstance.Fire('OnAfterCreateWindow');

  result := true;
end;

function Hook_StartCalcDamage (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  AttackerId := Heroes.GetStackIdByPos(pinteger(Context.EBX + STACK_POS_OFS)^);
  DefenderId := Heroes.GetStackIdByPos(pinteger(Context.ESI + STACK_POS_OFS)^);

  BasicDamage         := pinteger(Context.EBP + 12)^;
  IsDistantAttack     := pinteger(Context.EBP + 16)^;
  IsTheoreticalAttack := pinteger(Context.EBP + 20)^;
  Distance            := pinteger(Context.EBP + 24)^;

  result := Core.EXEC_DEF_CODE;
end; // .function Hook_StartCalcDamage

function Hook_CalcDamage_GetDamageBonus (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  DamageBonus := Context.EAX;
  result      := true;
end;

function Hook_EndCalcDamage (Context: ApiJack.PHookContext): longbool; stdcall;
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

function Hook_AI_CalcStackAttackEffect_Start (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  AIAttackerId := Heroes.GetStackIdByPos(pinteger(pinteger(Context.ESP + 8)^ + STACK_POS_OFS)^);
  AIDefenderId := Heroes.GetStackIdByPos(pinteger(pinteger(Context.ESP + 16)^ + STACK_POS_OFS)^);
  result       := true;
end;

function Hook_AI_CalcStackAttackEffect_End (Context: ApiJack.PHookContext): longbool; stdcall;
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

function Hook_EnterChat (Context: ApiJack.PHookContext): longbool; stdcall;
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

function Hook_ChatInput (Context: ApiJack.PHookContext): longbool; stdcall;
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

function Hook_LeaveChat (Context: ApiJack.PHookContext): longbool; stdcall;
const
  (* Event parameters *)
  EVENT_SUBTYPE = 1;

  ON_LEAVE_CHAT = 2;

begin
  Erm.ArgXVars[EVENT_SUBTYPE] := ON_LEAVE_CHAT;
  Erm.FireErmEvent(Erm.TRIGGER_ONCHAT);

  result := true;
end;

// ======================================== GAME LOOP AND EXCEPTION HANDLING ======================================== //
const
  // Custom Era exception. Parameters (Subtype: integer; ...: integer)
  EXCEPTION_CODE_ERA                   = $0EEFFFEE;
  EXCEPTION_ERA_FAST_QUIT_TO_GAME_MENU = 1377;

type
  PExceptionRegistration = ^TExceptionRegistration;
  TExceptionRegistration = packed record
    PrevRegistration: PExceptionRegistration;
    Handler:          pointer;
  end;

  PDelphiExceptionRegistration = ^TDelphiExceptionRegistration;
  TDelphiExceptionRegistration = packed record
    PrevRegistration: PExceptionRegistration;
    Handler:          pointer;
    Custom:           integer;
  end;

var
{U} ExceptionContext: Windows.PContext;
{U} ExceptionRecord:  Windows.PExceptionRecord;
{U} ExceptionArgs:    Utils.PEndlessIntArr;

{$STACKFRAMES OFF}
procedure SetFrameExceptionHandler (ExceptionRegistration: PExceptionRegistration); assembler;
asm
  mov eax, ExceptionRegistration
  mov ecx, fs:[0]
  mov [eax].TExceptionRegistration.PrevRegistration, ecx
  mov fs:[0], eax
end;

procedure UnsetFrameExceptionHandler (ExceptionRegistration: PExceptionRegistration); assembler;
asm
  mov eax, ExceptionRegistration
  mov eax, [eax].TExceptionRegistration.PrevRegistration
  mov dword ptr fs:[0], eax
end;

function EnhancedExceptionHandler (
  ExceptionRecordPtr: Windows.PExceptionRecord;
  EstablisherFrame:   PDelphiExceptionRegistration;
  Context:            Windows.PContext;
  DispatcherContext:  pointer
): integer; cdecl; assembler;
asm
  // Save exception context and record pointers in global variable, because Delphi uses only ExceptionRecord and only for EExternalException
  mov eax, ExceptionRecordPtr
  mov ExceptionRecord, eax
  lea eax, [eax].TExceptionRecord.ExceptionInformation
  mov ExceptionArgs, eax
  mov eax, Context
  mov ExceptionContext, eax

  // Restore original Handler and Custom fields of exception registration structure
  mov eax, EstablisherFrame

  mov ecx, [eax].TDelphiExceptionRegistration.Custom
  mov edx, [ecx].TDelphiExceptionRegistration.Custom
  mov [eax].TDelphiExceptionRegistration.Custom, edx

  mov edx, [ecx].TDelphiExceptionRegistration.Handler
  mov [eax].TDelphiExceptionRegistration.Handler, edx

  // Pass control to original handler
  jmp edx
end;

procedure EnhanceExceptionHandler (ExceptionRegistrationBackup: PDelphiExceptionRegistration); assembler;
asm
  // Make existing top exception handler backup
  mov eax, ExceptionRegistrationBackup
  mov ecx, fs:[0]

  mov edx, [ecx].TDelphiExceptionRegistration.Handler
  mov [eax].TDelphiExceptionRegistration.Handler, edx

  mov edx, [ecx].TDelphiExceptionRegistration.Custom
  mov [eax].TDelphiExceptionRegistration.Custom, edx

  // Replace top exception registration fields with enhanced handler and pointer to backup
  mov [ecx].TDelphiExceptionRegistration.Custom, eax
  mov [ecx].TDelphiExceptionRegistration.Handler, OFFSET EnhancedExceptionHandler
end;
{$STACKFRAMES ON}

function Hook_MainGameLoop (Context: ApiJack.PHookContext): longbool; stdcall;
var
  ExceptionRegistration: TDelphiExceptionRegistration;

begin
  try
    EnhanceExceptionHandler(@ExceptionRegistration);
    TProcedure(Ptr($4EEA70))();
  except
    Tweaks.ProcessUnhandledException(ExceptionRecord, ExceptionContext);
  end;

  result := false;
end;

procedure Hook_ExecuteManager (OrigFunc: pointer; This: pointer); stdcall;
var
  ExceptionRegistration: TDelphiExceptionRegistration;
  Left:                  boolean;
  ShouldFastQuit:        boolean;

  function Leave: boolean;
  begin
    if not Left then begin
      Left := true;

      if MainGameLoopDepth > 0 then begin
        Dec(MainGameLoopDepth);

        if MainGameLoopDepth = 0 then begin
          if Heroes.IsGameEnd^ then begin
            if Heroes.GameEndKind^ <> 0 then begin
              Erm.FireErmEvent(Erm.TRIGGER_WIN_GAME);
            end else begin
              Erm.FireErmEvent(Erm.TRIGGER_LOSE_GAME);
            end;
          end;

          Erm.FireErmEvent(Erm.TRIGGER_ONGAMELEAVE);
          EventMan.GetInstance.Fire('OnGameLeft');
        end;
      end;
    end;

    result := MainGameLoopDepth = 0;
  end;

begin
  Inc(MainGameLoopDepth);
  Left           := false;
  ShouldFastQuit := false;

  try
    EnhanceExceptionHandler(@ExceptionRegistration);

    if MainGameLoopDepth = 1 then begin
      Erm.FireErmEventEx(Erm.TRIGGER_ONGAMEENTER, []);
    end;

    PatchApi.Call(PatchApi.THISCALL_, OrigFunc, [This]);
    Leave;
  except
    if (ExceptionRecord.ExceptionCode = EXCEPTION_CODE_ERA) and (ExceptionArgs[0] = EXCEPTION_ERA_FAST_QUIT_TO_GAME_MENU) then begin
      Erm.PerformCleanupOnExceptions := false;
      Heroes.MainMenuTarget^         := ExceptionArgs[1];
      ShouldFastQuit                 := not Leave;
    end else begin
      Tweaks.ProcessUnhandledException(ExceptionRecord, ExceptionContext);
    end;
  end;

  if ShouldFastQuit then begin
    FastQuitToGameMenu(Heroes.MainMenuTarget^);
  end;
end; // .procedure Hook_ExecuteManager

function Hook_LoadSavegame (OrigFunc: pointer; GameMan: Heroes.PGameManager; FileName: pchar; PreventLoading: boolean; Dummy: integer): integer; stdcall;
const
  VAR_PLAYER_INDEX = $69D860;
  VAR_PLAYER_BIT   = $69CD10;

var
  ShouldSimulateEnterLeaveEvents: boolean;
  Event:                          EventLib.TOnBeforeLoadGameEvent;

begin
  ShouldSimulateEnterLeaveEvents := MainGameLoopDepth > 0;

  if ShouldSimulateEnterLeaveEvents then begin
    Erm.FireErmEvent(Erm.TRIGGER_ONGAMELEAVE);
    EventMan.GetInstance.Fire('OnGameLeft');
  end;

  Event.FileName := FileName;
  EventMan.GetInstance.Fire('OnBeforeLoadGame', @Event, sizeof(Event));

  result := PatchApi.Call(THISCALL_, OrigFunc, [GameMan, FileName, PreventLoading, Dummy]);

  pinteger(VAR_PLAYER_INDEX)^ := Heroes.CurrentPlayerId^;
  pinteger(VAR_PLAYER_BIT)^   := 1 shl Heroes.CurrentPlayerId^;

  if ShouldSimulateEnterLeaveEvents and (result <> 0) then begin
    Erm.FireErmEvent(Erm.TRIGGER_ONGAMEENTER);
  end;
end;

procedure RaiseEraServiceException (Code: integer; const Args: array of integer);
begin
  Erm.PerformCleanupOnExceptions := true;
  Windows.RaiseException(EXCEPTION_CODE_ERA, 0, Length(Args), @Args[0]);
end;

procedure FastQuitToGameMenu (TargetScreen: integer); stdcall;
var
  GameState: Heroes.TGameState;

begin
  Heroes.GetGameState(GameState);

  if GameState.RootDlgId <> 0 then begin
    RaiseEraServiceException(EXCEPTION_CODE_ERA, [EXCEPTION_ERA_FAST_QUIT_TO_GAME_MENU, TargetScreen])
  end;
end;
// ====================================== END GAME LOOP AND EXCEPTION HANDLING ====================================== //

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

procedure SetRegenerationAbility (MonId: integer; Chance: integer; HitPoints: integer; HpPercents: integer); stdcall;
begin
  if Chance <= 0 then begin
    MonsWithRegeneration.DeleteItem(Ptr(MonId));
  end else begin
    MonsWithRegeneration[Ptr(MonId)] := TRegenerationAbility.Create(Chance, HitPoints, HpPercents);
  end;
end;

function GetRegenerationAbility (MonId: integer): {Un} TRegenerationAbility;
begin
  result := MonsWithRegeneration[Ptr(MonId)];
end;

procedure SetStdRegenerationEffect (Level7Percents: integer; HpPercents: integer); stdcall;
begin
  StdRegenLevel7Percents := Alg.ToRange(Level7Percents, 0, 100);
  StdRegenHpPercents     := Alg.ToRange(Level7Percents, 0, 100);
end;

function ImplIsElixirOfLifeStack (Stack: Heroes.PBattleStack): boolean; stdcall;
begin
  result :=
    ((Stack.Flags and Heroes.MON_FLAG_ALIVE) <> 0) or
    (ZvsIsNpcNotCreature(Stack) and ((Stack.Flags and Heroes.MON_FLAG_UNDEAD) = 0));
end;

(* Returns standard amount of healed HP for Regeneration ability in Era *)
function GetStdRenerationAmount (Stack: Heroes.PBattleStack): integer;
var
  SumHp:          integer;
  MonType:        integer;
  FirstRegenAlt:  integer;
  SecondRegenAlt: integer;
  i:              integer;

begin
  SumHp := 0;

  for i := Heroes.TOWN_FIRST to Heroes.TOWN_LAST_WOG do begin
    MonType := Heroes.MonAssignmentsPerTown[i][1][6];
    Inc(SumHp, Heroes.MonInfos[MonType].HitPoints);
  end;

  FirstRegenAlt  := Trunc(SumHp / (Heroes.TOWN_LAST_WOG + 1) * StdRegenLevel7Percents / 100);
  SecondRegenAlt := Stack.HitPoints * StdRegenHpPercents div 100;

  result := Math.Max(FirstRegenAlt, SecondRegenAlt);
end;

function Hook_BattleDoRegenerate (Context: ApiJack.PHookContext): longbool; stdcall;
const
  EXIT_ADDR              = $446E21;
  PROCESS_ANIMATION_ADDR = $446C3F;

var
{Un} RegenerationAbility: TRegenerationAbility;
  MonType:            integer;
  Stack:              Heroes.PBattleStack;
  MonHero:            Heroes.PHero;
  RegenerationChance: integer;
  HasElixirOfLife:    boolean;
  StdHealValue:       integer;
  FinalHealValue:     integer;
  StackExpHealValue:  integer;

begin
  RegenerationAbility := nil;
  // * * * * * //
  result := false;

  if DisableRegen then begin
    Context.RetAddr := Ptr(EXIT_ADDR);
    exit;
  end;

  MonType            := Context.EAX;
  Stack              := Ptr(Context.ESI);
  MonHero            := Heroes.CombatManagerPtr^.Heroes[Stack.Side];
  RegenerationChance := 0;
  StdHealValue       := GetStdRenerationAmount(Stack);
  FinalHealValue     := 0;

  RegenerationAbility := GetRegenerationAbility(MonType);

  if RegenerationAbility <> nil then begin
    RegenerationChance := RegenerationAbility.Chance;

    if ((RegenerationChance > 0) and ((RegenerationChance >= 100) or (Heroes.RandomRange(1, 100) <= RegenerationChance))) then begin
      FinalHealValue := RegenerationAbility.HitPoints;

      if FinalHealValue < 0 then begin
        FinalHealValue := StdHealValue;
      end;

      if RegenerationAbility.HpPercents > 0 then begin
        FinalHealValue := Math.Max(FinalHealValue, trunc(Stack.HitPoints / 100 * RegenerationAbility.HpPercents));
      end;
    end;
  end;

  HasElixirOfLife := (MonHero <> nil)                                and
                     MonHero.HasArtOnDoll(Heroes.ART_ELIXIR_OF_LIFE) and
                     Boolean(WogEvo.IsElixirOfLifeStack(Stack));

  // Elixir of Life regeneration is used only if it's greater than the native one
  if HasElixirOfLife then begin
    FinalHealValue := Max(FinalHealValue, StdHealValue);
  end;

  // Commanders regeneration ability is standard one
  if ZvsCanNpcRegenerate(MonType, Stack) = -1 then begin
    FinalHealValue := Max(FinalHealValue, StdHealValue);
  end else begin
    // Stack experience regeneration is considered a cummulative bonus to existing regeneration points
    // Negative values mean give standard regeneration ability
    StackExpHealValue := ZvsCrExpBonRegenerate(Stack, Stack.HpLost);

    if StackExpHealValue > 0 then begin
      Inc(FinalHealValue, StackExpHealValue);
    end else if StackExpHealValue < 0 then begin
      FinalHealValue := Max(FinalHealValue, StdHealValue);
    end;
  end;

  Erm.FireErmEventEx(Erm.TRIGGER_BATTLE_STACK_REGENERATION, [Stack.Side * Heroes.NUM_BATTLE_STACKS_PER_SIDE + Stack.Index, FinalHealValue, StdHealValue]);
  FinalHealValue := Math.Min(Stack.HpLost, Math.Max(0, Erm.RetXVars[2]));

  if FinalHealValue > 0 then begin
    Dec(Stack.HpLost, FinalHealValue);
    Context.RetAddr := Ptr(PROCESS_ANIMATION_ADDR);
  end else begin
    Context.RetAddr := Ptr(EXIT_ADDR);
  end;
end; // .function Hook_BattleDoRegenerate

function Hook_BattleActionEnd (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  Erm.FireErmEvent(Erm.TRIGGER_BATTLE_ACTION_END);
  result := true;
end;

function Hook_BuildTownBuilding (OrigFunc: pointer; Town: Heroes.PTown; BuildingId, Unk1, Unk2: integer): integer; stdcall;
const
  PARAM_TOWN_ID     = 1;
  PARAM_BUILDING_ID = 2;

begin
  Erm.FireErmEventEx(Erm.TRIGGER_BUILD_TOWN_BUILDING, [Town.Id, BuildingId]);
  result := PatchApi.Call(THISCALL_, OrigFunc, [Town, BuildingId, Unk1, Unk2]);
  Erm.FireErmEventEx(Erm.TRIGGER_AFTER_BUILD_TOWN_BUILDING, [Town.Id, BuildingId]);
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

function Hook_MarkTransferedCampaignHero (Context: ApiJack.PHookContext): longbool; stdcall;
const
  TRANSFERRED_HERO_GLOBAL_ADDR      = $280761C; // int
  COPY_HERO_START_INFO_TO_HERO_FUNC = $485C30;
  ZVS_CARRY_OVER_HERO_FUNC          = $755DD9;  // no args

var
  MarkedHeroId: integer;
  PrevHeroId:   integer;

begin
  MarkedHeroId                            := pinteger(pinteger(Context.ESI + $4)^ + Context.EDI + $1A)^;
  pinteger(TRANSFERRED_HERO_GLOBAL_ADDR)^ := MarkedHeroId;

  PatchApi.Call(THISCALL_, Ptr(COPY_HERO_START_INFO_TO_HERO_FUNC), [Heroes.GameManagerPtr^, MarkedHeroId]);
  PatchApi.Call(STDCALL_,  Ptr(ZVS_CARRY_OVER_HERO_FUNC),          []);

  PrevHeroId := Erm.GetErmCurrHeroId;
  Erm.SetErmCurrHero(MarkedHeroId);

  Erm.FireErmEventEx(Erm.TRIGGER_TRANSFER_HERO, [MarkedHeroId]);

  Erm.SetErmCurrHero(PrevHeroId);

  result          := false;
  Context.RetAddr := Ptr($48607C);
end;

function Hook_AfterHeroGainLevel (Context: ApiJack.PHookContext): longbool; stdcall;
var
  Hero:     Heroes.PHero;
  PrevHero: Heroes.PHero;

begin
  result        := true;
  Hero          := PHero(Context.EBX);
  ZvsGmAiFlags^ := ord(not Erm.ZvsIsAi(Hero.Owner));
  PrevHero      := Erm.GetErmCurrHero();
  Erm.SetErmCurrHero(Hero);

  Erm.FireErmEventEx(Erm.TRIGGER_AFTER_HERO_GAIN_LEVEL, [Hero.Id]);

  Erm.SetErmCurrHero(PrevHero);
end;

procedure OnLoadEraSettings (Event: GameExt.PEvent); stdcall;
begin
  LogWindowMessagesOpt := EraSettings.GetDebugBoolOpt('Debug.LogWindowMessages', false);
end;

procedure OnGameLeave (Event: GameExt.PEvent); stdcall;
begin
  GameExt.SetMapDir('');
end;

procedure OnAbnormalGameLeave (Event: GameExt.PEvent); stdcall;
begin
  Core.FatalError('Not supported. Use ERA API for fast quit to game menu');
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  (* extended MM Trigger *)
  ApiJack.HookCode(Ptr($492409), @Hook_BattleHint_GetAttacker, nil, 7);
  ApiJack.HookCode(Ptr($492442), @Hook_BattleHint_GetDefender, nil, 7);
  ApiJack.HookCode(Ptr($493053), @Hook_BattleHint_CalcMinMaxDamage);

  (* Key handling trigger *)
  ApiJack.HookCode(Ptr($4F8226), @Hook_AfterCreateWindow, nil, 6);

  (* Stack to stack damage calculation *)
  ApiJack.HookCode(Ptr($443C88), @Hook_StartCalcDamage, nil, 6);
  ApiJack.HookCode(Ptr($443CA1), @Hook_CalcDamage_GetDamageBonus);
  ApiJack.HookCode(Ptr($443DA7), @Hook_EndCalcDamage);

  (* AI Target attack effect *)
  ApiJack.HookCode(Ptr($4357E0), @Hook_AI_CalcStackAttackEffect_Start, nil, 6);
  ApiJack.HookCode(Ptr($4358AA), @Hook_AI_CalcStackAttackEffect_End);

  (* OnChat trigger *)
  ApiJack.HookCode(Ptr($4022B0), @Hook_EnterChat);
  ApiJack.HookCode(Ptr($554780), @Hook_ChatInput, nil, 6);
  ApiJack.HookCode(Ptr($402298), @Hook_LeaveChat, nil, 6);
  ApiJack.HookCode(Ptr($402240), @Hook_LeaveChat, nil, 6);

  (* Main game cycle (AdvMgr, CombatMgr): OnGameEnter, OnGameLeave, OnWinGame, OnLoseGamer and MapFolder settings*)
  ApiJack.StdSplice(Ptr($4B0BA0), @Hook_ExecuteManager, ApiJack.CONV_THISCALL, 1);

  (* Hook LoadSavegame to trigger OnGameEnter and OnGameLeave if game loading is performed inside ExecuteManager function *)
  ApiJack.StdSplice(Ptr($4BEFF0), @Hook_LoadSavegame, ApiJack.CONV_THISCALL, 4);

  (* Set top level main loop exception handle *)
  ApiJack.HookCode(Ptr($4F824A), @Hook_MainGameLoop);

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

  (* OnBattleActionEnd event *)
  ApiJack.HookCode(Ptr($479508), @Hook_BattleActionEnd);

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

  (* OnTransferHero *)
  // Disable WoG call from CarryOverHero to _CarryOverHero. _CarryOverHero will be called in Hook_MarkTransferedCampaignHero
  Core.p.WriteDataPatch(Ptr($755E17), ['9090909090']);

  // Provide handling of all transferred campaign heroes, even inactive ones in transition zones
  ApiJack.HookCode(Ptr($486069), @Hook_MarkTransferedCampaignHero);

  (* OnAfterHeroGainLevel *)
  ApiJack.HookCode(Ptr($4DAF06), @Hook_AfterHeroGainLevel);
end; // .procedure OnAfterWoG

procedure InitializeMonsWithRegeneration;
begin
  MonsWithRegeneration := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  SetRegenerationAbility(Heroes.MON_WIGHT);
  SetRegenerationAbility(Heroes.MON_WRAITH);
  SetRegenerationAbility(Heroes.MON_TROLL);
  SetRegenerationAbility(Heroes.MON_HELL_HYDRA);
end;

begin
  WogEvo.SetIsElixirOfLifeStackFunc(@ImplIsElixirOfLifeStack);
  InitializeMonsWithRegeneration;

  EventMan.GetInstance.On('$OnLoadEraSettings', OnLoadEraSettings);
  EventMan.GetInstance.On('OnAbnormalGameLeave', OnAbnormalGameLeave);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
  EventMan.GetInstance.On('OnGameLeave', OnGameLeave);
end.
