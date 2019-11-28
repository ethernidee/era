unit Angel;
(*
  Author: ethernidee aka Berserker aka Alexander Shostak.
  Port of Virtual Pascal Era 1.9+.
*)


(***)  interface  (***)
uses Windows, SysUtils, Utils;

type
  PServiceParam = ^TServiceParam;
  TServiceParam = packed record
    IsStr:         longbool;
    OperGet:       longbool;
    Value:         integer; // numeric value or address
    StrValue:      string;
    ParamModifier: integer;
  end;

  PServiceParams = ^TServiceParams;
  TServiceParams = array[0..23] of TServiceParam;


procedure InitEra;
function  EraGetServiceParams (Cmd: pchar; var NumParams: integer; var Params: TServiceParams): integer; stdcall;
procedure EraReleaseServiceParams (var Params: TServiceParams); stdcall;


(***)  implementation  (***)
uses Erm, AdvErm;


const
  (* Game addresses *)
  C_PCHAR_SAVEGAME_NAME     = $69FC88;
  C_PCHAR_LASTSAVEGAME_NAME = $68338C;
  
  (* Game functions *)
  C_FUNC_PLAYSOUND              = $59A890;
  C_FUNC_ZVS_TRIGGERS_PLAYSOUND = $774F0A;
  C_FUNC_ZVS_ERMMESSAGE         = $70FB63; // IF:M
  C_FUNC_ZVS_PROCESSCMD         = $741DF0; // ProcessCmd
  C_FUNC_SAVEGAME_HANDLER       = $4180C0; // Menu -> Save handler
  C_FUNC_SAVEGAME               = $4BEB60; // Save game function
  C_FUNC_ZVS_GZIPWRITE          = $704062; // GZipWrite(Address: pointer; Count: integer); cdecl;
  C_FUNC_ZVS_GZIPREAD           = $7040A7; // GZipRead(Address: pointer; Count: integer); cdecl;
  C_FUNC_ZVS_GETHEROPTR         = $71168D; // GetHeroPtr(HeroNum: integer); cdecl;
  C_FUNC_ZVS_CALLFU             = $74CE30; // void FUCall(int n)
  C_FUNC_FOPEN                  = $619691; // FOpen
  
  (* Game: variables *)
  C_VAR_ERM_V            = $887668;
  C_VAR_ERM_Z            = $9273E8;
  C_VAR_ERM_Y            = $A48D80;
  C_VAR_ERM_X            = $91DA38;
  C_VAR_ERM_F            = $27718D0; // Erm temp vars f..t
  C_VAR_ERM_HEAP         = $27F9548; // First trigger address (_Cmd_)
  C_VAR_ERM_PTR_CURRHERO = $27F9970; // Current Hero
  C_W_HERO               = $27F9988; // IF:W hero ID
  C_VAR_HWND             = $699650;  // Game window handle
  
  (* Era function call conventions *)
  C_ERA_CALLCONV_PASCAL           = 0;
  C_ERA_CALLCONV_CDECL_OR_STDCALL = 1;
  C_ERA_CALLCONV_THISCALL         = 2;
  C_ERA_CALLCONV_FASTCALL         = 3;
  CONVENTION_FLOAT                = 4; // DEPRECATED: Should be added to other convention value
  
  (* Erm message *)
  C_ERMMESSAGE_MES            = 1;  // Generic message
  C_ERMMESSAGE_QUESTION       = 2;  // Question (Yes/No)
  C_ERMMESSAGE_RMBINFO        = 4;  // RMB popup
  C_ERMMESSAGE_CHOOSE         = 7;  // Selection from two alternatives
  C_ERMMESSAGE_CHOOSEORCANCEL = 10; // Selection from two alternatives with cancelling possibility
  
  (* Era Events *)
  C_ERA_EVENT_SAVEGAME_BEFORE     = 77000;
  C_ERA_EVENT_SAVEGAME_PACK       = 77001;
  C_ERA_EVENT_LOADGAME_UNPACK     = 77002;
  C_ERA_EVENT_WNDPROC_KEYDOWN     = 77003;
  C_ERA_EVENT_HEROSCREEN_ENTER    = 77004;
  C_ERA_EVENT_HEROSCREEN_EXIT     = 77005;
  C_ERA_EVENT_BATTLE_WHOMOVES     = 77006;
  C_ERA_EVENT_BATTLE_BEFOREACTION = 77007;
  C_ERA_EVENT_SAVEGAME_AFTER      = 77008;
  C_ERA_EVENT_SAVEGAME_DIALOG     = 77009;
  TRIGGER_BEFORE_HEROINTERACTION  = 77010;
  TRIGGER_AFTER_HEROINTERACTION   = 77011;

  (* TParamModifier *)
  NO_MODIFIER     = 0;
  MODIFIER_ADD    = 1;
  MODIFIER_SUB    = 2;
  MODIFIER_MUL    = 3;
  MODIFIER_DIV    = 4;
  MODIFIER_CONCAT = 5;


procedure CallProc (Addr: integer; Convention: integer; PParams: pointer; NumParams: integer); stdcall; assembler;
const
  SERVICE_PARAM_SIZE = sizeof(TServiceParam); // Offset to the next parameter in parameters array

var
  SavedEsp: integer;
  
asm
  CMP Convention, CONVENTION_FLOAT
  JB @@IntConvention
@@FloatConvetion:
  SUB Convention, CONVENTION_FLOAT
@@IntConvention:
  PUSH EBX
  MOV SavedEsp, ESP

  // Execute function without parameters immediately
  MOV ECX, NumParams
  TEST ECX, ECX
  JZ @@CallFunc

  MOV EBX, Convention
  MOV EDX, PParams
  
  // Handle Pascal convention separately
  TEST EBX, EBX
  JNZ @@NotPascalConversion
@@PascalConversion:
  @@PascalLoop:
    PUSH DWORD [EDX]
    ADD EDX, SERVICE_PARAM_SIZE
    DEC ECX
    JNZ @@PascalLoop
  JMP @@CallFunc
@@NotPascalConversion:
  // Recalculate number of arguments for pushing into stack
  DEC EBX
  SUB ECX, EBX
  
  // ...And if all arguments are will be stored in registers, no need to use stack at all
  JZ @@InitThisOrFastCall
  JS @@InitThisOrFastCall
  
  // Otherwise push arguments in stack in reversed order
  ADD ECX, EBX
  PUSH ECX
  
  IMUL ECX, ECX, sizeof(TServiceParam)

  LEA EDX, [EDX + ECX - SERVICE_PARAM_SIZE]
  POP ECX
  SUB ECX, EBX
  @@CdeclLoop:
    PUSH DWORD [EDX]
    SUB EDX, SERVICE_PARAM_SIZE
    DEC ECX
    JNZ @@CdeclLoop
  @@InitThisOrFastCall:
  
  // Initialize ThisCall and FastCall arguments
  MOV ECX, PParams
  MOV EDX, [ECX + SERVICE_PARAM_SIZE]
  MOV ECX, [ECX]
@@CallFunc:
  // Calling function
  MOV EAX, Addr
  CALL EAX

  // Save result in both v1 and e1
  FST DWORD [$A48F18]
  MOV DWORD [C_VAR_ERM_V], EAX

  MOV ESP, SavedEsp
  POP EBX
  // RET
end; // .procedure CallProc

function GetErtStr (StrInd: integer): pchar; stdcall; assembler;
asm
  PUSH StrInd
  MOV EAX, $776620
  CALL EAX
  ADD ESP, 4
end;

function GetVarStrValue (VarType: char; Ind: integer; var Res: string): boolean;
begin
  result  :=  true;
  case VarType of
    'V':
      begin
        result  :=  (Ind >= 1) and (Ind <= 10000);
        if result then begin
          Res :=  SysUtils.IntToStr(pinteger(C_VAR_ERM_V - 4 + Ind * 4)^);
        end; // .if
      end; // .case 'V'
    'W':
      begin
        result  :=  (Ind >= 1) and (Ind <= 200);
        if result then begin
          Res :=  SysUtils.IntToStr(w^[pinteger(C_W_HERO)^, Ind]);
        end; // .if
      end; // .case 'W'
    'X':
      begin
        result  :=  (Ind >= 1) and (Ind <= 16);
        if result then begin
          Res :=  SysUtils.IntToStr(pinteger(C_VAR_ERM_X - 4 + Ind * 4)^);
        end; // .if
      end; // .case 'X'
    'Y':
      begin
        result  :=  (Ind >= -100) and (Ind <= 100) and (Ind <> 0);
        if result then begin
          if Ind > 0 then begin
            Res :=  SysUtils.IntToStr(pinteger(C_VAR_ERM_Y - 4 + Ind * 4)^);
          end // .if
          else begin
            Res :=  SysUtils.IntToStr(ny^[-Ind]);
          end; // .else
        end; // .if
      end; // .case 'Y'
    'E':
      begin
        result  :=  (Ind >= -100) and (Ind <= 100) and (Ind <> 0);
        if result then begin
          DecimalSeparator  :=  '.';

          if Ind > 0 then begin
            Res :=  SysUtils.FloatToStr(e^[Ind]);
          end // .if
          else begin
            Res :=  SysUtils.FloatToStr(ne^[-Ind]);
          end; // .else
        end; // .if
      end; // .case 'E'
    'Z':
      begin
        result  :=  (Ind >= -10) and (Ind <> 0);
        if result then begin
          if Ind > 1000 then begin
            Res :=  GetErtStr(Ind);
          end // .if
          else if Ind > 0 then begin
            Res :=  pchar(C_VAR_ERM_Z - 512 + Ind * 512);
          end // .ELSEIF
          else begin
            Res :=  nz^[-Ind];
          end; // .else
        end; // .if
      end; // .case 'Z'
  else
    result  :=  false;
  end; // .switch VarType
end; // .function GetVarStrValue
xxx
function FindChar (c: char; const Str: string; var Pos: integer): boolean;
var
  Len:  integer;

begin
  Len :=  Length(Str);
  while (Pos <= Len) and (Str[Pos] <> c) do begin
    Inc(Pos);
  end; // .while
  result  :=  Pos <= Len;
end; // .function FindChar

function UnwrapStr (const Str: string; var Res: string): boolean;
type
  PListItem = ^TListItem;
  TListItem = record
    Value:    string;
    NextItem: PListItem;
  end; // .record TListItem

var
{O} Root:     PListItem;
{U} CurrItem: PListItem;
    StrLen:   integer;
    StartPos: integer;
    Pos:      integer;
    Token:    string;
    VarType:  char;
    Found:    boolean;
    NumItems: integer;
    ResLen:   integer;

  procedure AddItem (const Str: string);
  begin
    if Root = nil then begin
      New(Root);
      Root^.Value     :=  Str;
      Root^.NextItem  :=  nil;
      CurrItem        :=  Root;
    end // .if
    else begin
      New(CurrItem^.NextItem);
      CurrItem            :=  CurrItem^.NextItem;
      CurrItem^.Value     :=  Str;
      CurrItem^.NextItem  :=  nil;
    end; // .else
    Inc(NumItems);
  end; // .procedure AddItem

begin
  Root      :=  nil;
  CurrItem  :=  nil;
  NumItems  :=  0;
  // * * * * * //
  result  :=  true;
  StrLen  :=  Length(Str);
  Pos     :=  1;
  while Pos <= StrLen do begin
    StartPos  :=  Pos;
    Found     :=  FindChar('%', Str, Pos);
    SetLength(Token, Pos - StartPos);
    if Length(Token) > 0 then begin
      Windows.CopyMemory(pointer(Token), pointer(@Str[StartPos]), Length(Token));
    end; // .if
    AddItem(Token);
    if Found then begin
      if ((Pos + 1) <= StrLen) and (Str[Pos+1] = '%') then begin
        AddItem('%');
        Pos :=  Pos + 2;
      end // .if
      else begin
        Inc(Pos);
        result  :=  (Pos+1) <= StrLen;
        if result then begin
          VarType :=  Str[Pos];
          Inc(Pos);
          StartPos  :=  Pos;

          if Str[Pos] in ['+', '-'] then begin
            Inc(Pos);
          end; // .if

          while (Pos <= StrLen) and (Str[Pos] in ['0'..'9']) do begin
            Inc(Pos);
          end; // .while
          SetLength(Token, Pos - StartPos);
          result  :=  Length(Token) > 0;
          if result then begin
            Windows.CopyMemory(pointer(Token), pointer(@Str[StartPos]), Length(Token));
            result  :=  GetVarStrValue(VarType, SysUtils.StrToInt(Token), Token);
            if result then begin
              AddItem(Token);
            end; // .if
          end; // .if
        end; // .if
      end; // .else
    end; // .if
  end; // .while
  if NumItems = 0 then begin
    Res :=  '';
  end // .if
  else begin
    ResLen    :=  0;
    CurrItem  :=  Root;
    while CurrItem <> nil do begin
      ResLen    :=  ResLen + Length(CurrItem^.Value);
      CurrItem  :=  CurrItem.NextItem;
    end; // .while
    SetLength(Res, ResLen);
    Pos       :=  1;
    CurrItem  :=  Root;
    while CurrItem <> nil do begin
      Windows.CopyMemory(pointer(@Res[Pos]), pointer(CurrItem^.Value), Length(CurrItem^.Value));
      Pos       :=  Pos + Length(CurrItem^.Value);
      CurrItem  :=  CurrItem.NextItem;
    end; // .while
  end; // .else
  while Root <> nil do begin
    CurrItem  :=  Root^.NextItem;
    Dispose(Root);
    Root  :=  CurrItem;
  end; // .while
end; // .function UnwrapStr

function GetServiceParams (Cmd: pchar; var NumParams: integer; var Params: TServiceParams): integer;
type
  TCharArr = array [0..MAXLONGINT - 1] of char;
  PCharArr = ^TCharArr;

var
  PCmd:          PCharArr;
  ParType:       char;
  ParValue:      integer;
  BeginPos:      integer;
  Pos:           integer;
  CharPos:       integer;
  StrLen:        integer;
  IndStr:        string;
  SingleDSyntax: boolean;

begin
  PCmd      := pointer(Cmd);
  NumParams := 0;
  Pos       := 1;
  
  while not (PCmd^[Pos] in [';', ' ']) do begin
    SingleDSyntax                   := false;
    Params[NumParams].ParamModifier := NO_MODIFIER;

    // Получаем тип команды: GET or set
    if PCmd^[Pos] = '?' then begin
      Params[NumParams].OperGet := true;
      Inc(Pos);
    end else begin
      Params[NumParams].OperGet := false;

      if PCmd^[Pos] = 'd' then begin
        Inc(Pos);

        case PCmd^[Pos] of
          '+': begin Params[NumParams].ParamModifier := MODIFIER_ADD; Inc(Pos); end;
          '-': begin Params[NumParams].ParamModifier := MODIFIER_SUB; Inc(Pos); end;
          '*': begin Params[NumParams].ParamModifier := MODIFIER_MUL; Inc(Pos); end;
          ':': begin Params[NumParams].ParamModifier := MODIFIER_DIV; Inc(Pos); end;
          '&': begin Params[NumParams].ParamModifier := MODIFIER_CONCAT; Inc(Pos); end;
        else
          Params[NumParams].ParamModifier := MODIFIER_ADD;
          SingleDSyntax := true;
        end; // .switch
      end; // .if
    end; // .else

    if PCmd^[Pos] = '^' then begin
      Inc(Pos);
      BeginPos := Pos;
      
      while PCmd^[Pos] <> '^' do begin
        Inc(Pos);
      end; // .while
      
      StrLen                     := Pos - BeginPos;
      Params[NumParams].IsStr := true;
      SetLength(Params[NumParams].StrValue, StrLen);
      Windows.CopyMemory(pointer(Params[NumParams].StrValue), @PCmd^[BeginPos], StrLen);
      Params[NumParams].Value    := integer(Params[NumParams].StrValue);
      Inc(Pos);
      CharPos := 1;
      
      if FindChar('%', Params[NumParams].StrValue, CharPos) then begin
        if not UnwrapStr(Params[NumParams].StrValue, Params[NumParams].StrValue) then begin
          result := -1; exit;
        end;
        
        Params[NumParams].Value := integer(Params[NumParams].StrValue);
      end;
    end else begin
      // Get parameter type: z, v, x, y or constant
      ParType := PCmd^[Pos];

      if (ParType in [';', '/', ' ']) and SingleDSyntax then begin
        Params[NumParams].IsStr := false;
        Params[NumParams].Value    := 0;
      end else begin
        if ParType in ['-', '+', '0'..'9'] then begin
          ParType :=  #0;
        end else begin
          Inc(Pos);
        end;
        
        // Remember parameter start position
        BeginPos := Pos;
        
        while not(PCmd^[Pos] in [';', '/', ' ']) do begin
          Inc(Pos);
        end;

        ParValue := 0;

        if ParType in ['f'..'t'] then begin
          ParValue := ord(ParType) - ord('f');
        end else begin
          SetLength(IndStr, Pos - BeginPos);
          Windows.CopyMemory(pointer(IndStr), @PCmd^[BeginPos], Pos - BeginPos);
          
          try
            ParValue := SysUtils.StrToInt(IndStr);
          except
            result := -1; exit;
          end;
        end;
        
        // Everything is ready for constants, now handle variables
        // Get their real addresses for start. For instance, $887668 instead of v1. If syntax is SET, get values by addresses
        if ParType <> #0 then begin
          case ParType of
            'y': begin
              if ParValue < 0 then begin
                ParValue := integer(@ny^[-ParValue]);
              end else begin
                ParValue := (C_VAR_ERM_Y - sizeof(integer)) + ParValue * sizeof(integer);
              end;

              if not Params[NumParams].OperGet then begin
                ParValue := pinteger(ParValue)^;
              end;
            end;
            
            'v': begin
              ParValue := (C_VAR_ERM_V - sizeof(integer)) + ParValue * sizeof(integer);
              
              if not Params[NumParams].OperGet then begin
                ParValue:=pinteger(ParValue)^;
              end;
            end;
            
            'z': begin
              if ParValue > 1000 then begin
                ParValue := integer(GetErtStr(ParValue));
              end else if ParValue > 0 then begin
                ParValue := (C_VAR_ERM_Z-512) + ParValue * 512;
              end else begin
                ParValue := integer(@nz^[-ParValue]);
              end;
            end;
            
            'x': begin
              ParValue := (C_VAR_ERM_X - sizeof(integer)) + ParValue * sizeof(integer);
              
              if not Params[NumParams].OperGet then begin
                ParValue:=pinteger(ParValue)^;
              end;
            end;
            
            'w': begin
              if Params[NumParams].OperGet then begin
                ParValue := integer(@w^[pinteger(C_W_HERO)^, ParValue]);
              end else begin
                ParValue := w^[pinteger(C_W_HERO)^, ParValue];
              end;
            end;
            
            'f'..'t': begin
              ParValue := C_VAR_ERM_F + ParValue * sizeof(integer);
              
              if not Params[NumParams].OperGet then begin
                ParValue := pinteger(ParValue)^;
              end;
            end;
            
            'e':  begin
              if ParValue > 0 then begin
                ParValue := integer(@e^[ParValue]);
              end else begin
                ParValue := integer(@ne^[-ParValue]);
              end;

              if not Params[NumParams].OperGet then begin
                ParValue := pinteger(ParValue)^;
              end;
            end; // switch e
          else
            result:=-1; exit;
          end; // .case ParType
        end; // .if

        Params[NumParams].IsStr := ParType = 'z';
        Params[NumParams].Value := ParValue;

        if (Params[NumParams].IsStr and not(Params[NumParams].ParamModifier in [NO_MODIFIER, MODIFIER_CONCAT]) ) or
           (not Params[NumParams].IsStr and (Params[NumParams].ParamModifier = MODIFIER_CONCAT))
        then begin
          result  :=  -1; exit;
        end;
      end; // .else
    end; // .else

    if PCmd^[Pos] = '/' then begin
      Inc(Pos);
    end; // .if

    Inc(NumParams);
  end; // .while
  while PCmd^[Pos] = ' ' do begin
    Inc(Pos);
  end; // .while
  result  :=  Pos; // Pos - как раз размер строки параметров
end; // .function GetServiceParams

procedure ReleaseServiceParams (var Params: TServiceParams);
var
  i: integer;

begin
  for i := 0 to High(Params) do begin
    Params[i].StrValue := '';
  end;
end;

function CheckServiceParams
(
        NumParams:    integer;
  var   Params:       TServiceParams;
  const ParamsChecks: array of boolean
): boolean;

var
  NumChecks:  integer;
  i:          integer;

begin
  NumChecks :=  High(ParamsChecks) + 1;
  result    :=  (NumChecks div 2) = NumParams;
  i         :=  0;
  while result and (i <= High(ParamsChecks)) do begin
    result  :=
      (Params[i div 2].IsStr = ParamsChecks[i])  and
      (Params[i div 2].OperGet = ParamsChecks[i + 1]);
    i :=  i + 2;
  end; // .while
end; // .function CheckServiceParams

procedure ModifyWithParam (Dest: pinteger; Param: PServiceParam);
begin
  case Param.ParamModifier of
    NO_MODIFIER:  Dest^ := Param.Value;
    MODIFIER_ADD: Dest^ := Dest^ + Param.Value;
    MODIFIER_SUB: Dest^ := Dest^ - Param.Value;
    MODIFIER_MUL: Dest^ := Dest^ * Param.Value;
    MODIFIER_DIV: Dest^ := Dest^ div Param.Value;
  end; // .switch ParamInfo.ParamModifier
end; // .procedure ModifyWithParam

(* Service *) {Команды ЕРМ, реализуемые фреймворком "Эра"}
function Service(Ebp: integer): longbool;
const
  PtrStackMes   = $14;  // + Указатель на структуру _Mes_, что используется в ProcessErm
  PtrCmdLen     = $268; // + // Указатель на размер/смещение команды в функции ProcessCmd 
  PtrStackCmdN  = $730; // + Указатель на номер команды в данном триггере. ProcessErm
  PtrTrigger    = $8C8; // + Указатель на структуру текущего триггера. ProcessErm
  PtrEventId    = $72C; // + Указатель на ID текущего события
  
  (* контанты для функции CheckServiceParams *)
  STR   = true;   // Параметр является строкой
  NUM   = false;  // Параметр - числовое значение
  GETV  = true;   // Синтаксис GET
  SETV  = false;  //Синтаксис set

type
  TMes = record
    Offset: integer; // смещение до подкоманды в команде
    Ptr: pchar; // указатель на текст команды
  end; // .record Mes
  
  PCmd = ^TCmd;
  TCmd = record
    Next: PCmd;
    Event: integer;
  end; // .record TCmd
  
var
  Mes:        ^TMes; // Указатель на структуру TMes
  BaseCmdStr: pchar;
  CmdStr:     pchar; // Строка команды
  Cmd:        char; // Символ команды
  CmdLen:     integer; // Длина команды
  CmdN:       pinteger; // Указатель на номер текущей команды в триггере
  NumParams:  integer;
  Params:     TServiceParams;
  Err:        pchar;
  i:          integer;


begin
  result:=true; // По умолчанию Эра обрабатывает все команды
  integer(Mes):=pinteger(Ebp+PtrStackMes)^; // Получили указатель на структуру TMes
  integer(CmdStr):=pinteger(integer(Mes)+4)^; // Получили указатель на строку с командой
  CmdN:=pinteger(Ebp+PtrStackCmdN); // Указатель на номер команды в триггере
  Cmd:=CmdStr^; // Получили сам символ команды
  // Если это стандартная, то пусть её обрабатывает оригинальный обработчик
  if (Cmd = 'P') or (Cmd = 'S') then begin
    result:=false; exit;
  end; // .if
  BaseCmdStr  :=  CmdStr;
  while CmdStr^ <> ';' do begin
    Cmd:=CmdStr^;
    CmdLen:=GetServiceParams(CmdStr, NumParams, Params); // Парсим параметры, а заодно получаем истинный размер строки команды
    // Если парсинг был неудачным, значит в параметрах ошибка. Выведем сообщение и корректно выйдем из функции
    if CmdLen = -1 then begin
      Erm.ShowErmError('Era Service Error: Invalid parameters string in a call to !!SN. Context:');
      CmdN ^:= 2000000000;
      exit;
    end; // .if
    // Установим реальный размер строки параметров для ProcessCmd, иначе она будет ещё не раз вызывать нашу функцию, считая каждый символ командой
    // Пошло выполнение отдельных команд
    case Cmd of 
      'G': begin
        // PARAMS: CmdN: integer
        if not CheckServiceParams(NumParams, Params, [NUM, SETV]) then begin
          Erm.ShowErmError('Invalid parameters for !!SN:G command. Context:');
          CmdN^:=2000000000;
          exit;
        end; // .if
        CmdN^:=Params[0].Value - 1;
      end; // .switch G
      // 'C': begin
      //   if (NumParams = 2) then begin
      //     // PARAMS: TriggerAddr: pointer; CmdN: integer;
      //     if not CheckServiceParams(NumParams, Params, [NUM, SETV, NUM, SETV]) then begin
      //       Erm.ShowErmError(Lang.Str[Lang.Str_Error_Service_C]);
      //       CmdN^:=2000000000;
      //       exit;
      //     end; // .if
      //     Inc(ServiceCallStack.Pos);
      //     ServiceCallStack.Stack[ServiceCallStack.Pos].Trigger:=pinteger(Ebp+PtrTrigger)^;
      //     ServiceCallStack.Stack[ServiceCallStack.Pos].CmdN:=CmdN^;
      //     pinteger(Ebp+PtrTrigger)^:=Params[0].Value;
      //     pinteger(Ebp+PtrStackCmdN)^:=Params[1].Value-1;
      //   end // .if
      //   else if (NumParams = 3) then begin
      //     // PARAMS: nil; TriggerID: integer; ?Res: integer; 
      //     if
      //       (not CheckServiceParams(NumParams, Params, [NUM, SETV, NUM, SETV, NUM, GETV])) or
      //       (Params[0].Value <> 0)
      //     then begin
      //       Erm.ShowErmError(Lang.Str[Lang.Str_Error_Service_C]);
      //       CmdN^:=2000000000;
      //       exit;
      //     end; // .if
      //     pinteger(Params[2].Value)^:=GetFuncTriggerAddr(Params[1].Value);
      //   end // .elseif
      //   else begin
      //     Erm.ShowErmError(Lang.Str[Lang.Str_Error_Service_C]);
      //     CmdN^:=2000000000;
      //     exit;
      //   end; // .else
      // end; // .switch C
      // 'R': begin
      //   // PARAMS: (NO)
      //   if NumParams <> 0 then begin
      //     Erm.ShowErmError(Lang.Str[Lang.Str_Error_Service_R]);
      //     CmdN^:=2000000000;
      //     exit;
      //   end; // .if
      //   pinteger(Ebp+PtrTrigger)^:=ServiceCallStack.Stack[ServiceCallStack.Pos].Trigger;
      //   pinteger(Ebp+PtrStackCmdN)^:=ServiceCallStack.Stack[ServiceCallStack.Pos].CmdN;
      //   Dec(ServiceCallStack.Pos);
      // end; // .switch R
      // 'Q': begin
      //   // PARAMS: (NO)
      //   if NumParams <> 0 then begin
      //     Erm.ShowErmError(Lang.Str[Lang.Str_Error_Service_Q]);
      //     CmdN^:=2000000000;
      //     exit;
      //   end; // .if
      //   pinteger(Ebp+PtrEventId)^:=2000000000;
      //   CmdN^:=2000000000;
      // end; // .switch Q
      'E': begin
        // PARAMS: Addr: pointer; Convention: integer; Params: ANY...
        if
          (NumParams < 0) or
          not (CheckServiceParams(2, Params, [NUM, SETV, NUM, SETV])) or
          (Params[0].Value = 0) or
          not (Params[1].Value in [C_ERA_CALLCONV_PASCAL..C_ERA_CALLCONV_FASTCALL + CONVENTION_FLOAT])
        then begin
          Erm.ShowErmError('Invalid parameters for !!SN:E command. Context:');
          CmdN^:=2000000000;
          exit;
        end; // .if
        
        CallProc
        (
          Params[0].Value, // Addr
          Params[1].Value, // Convention
          @Params[2].Value, // PParams
          NumParams - 2 // NumParams
        ); // CallProc
      end; // .switch E
      'A': begin
        // PARAMS: hDll: integer; ProcName: string; ?Res: integer;
        if not CheckServiceParams(NumParams, Params, [NUM, SETV, STR, SETV, NUM, GETV]) then begin
          Erm.ShowErmError('Invalid parameters for !!SN:P command. Context:');
          CmdN^:=2000000000;
          exit;
        end; // .if
        pinteger(Params[2].Value)^:=integer(Windows.GetProcAddress(Params[0].Value, pchar(Params[1].Value)));
      end; // .switch A
      'L': begin
        // PARAMS: DllName: string; ?Res: integer;
        if not CheckServiceParams(NumParams, Params, [STR, SETV, NUM, GETV]) then begin
          Erm.ShowErmError('Invalid parameters for !!SN:L command. Context:');
          CmdN^:=2000000000;
          exit;
        end; // .if
        pinteger(Params[1].Value)^:=integer(Windows.LoadLibrary(pchar(Params[0].Value)));
      end; // .switch L
      'X': begin
        if NumParams > High(Erm.x^) then begin
          Erm.ShowErmError('Too many parameters for !!SN:X command. Context:');
          CmdN^:=2000000000;
          exit;
        end; // .if
        for i := 1 to NumParams do begin
          if Params[i].OperGet then begin
            if Params[i].IsStr then begin
              Erm.SetZVar(pointer(Params[i].Value), pointer(Erm.x[i]));
            end else begin
              pinteger(Params[i].Value)^:=Erm.x[i];
            end;
          end else begin
            ModifyWithParam(@Erm.x[i], @Params[i]);
          end; // .else
        end; // .for
      end; // .switch X
    else
      if not AdvErm.ExtendedEraService(Cmd, NumParams, @Params, Err) then begin
        Erm.ShowErmError(Err);
        {CmdN^ :=  2000000000; EXIT;}
      end; // .if
    end; // .case Cmd
    Inc(integer(CmdStr), CmdLen);
  end; // .while
  
  pinteger(Ebp+PtrCmdLen)^:=integer(CmdStr) - integer(BaseCmdStr);
end; // .function Service

(* Asm_Service *) {Переходник к высокоуровневой процедуре ядра Service}
procedure Asm_Service; stdcall; assembler;
asm
  // Сохраним регистры
  PUSHAD
  // Вызываем высокоуровневую функцию Service
  PUSH EBP
  CALL Service
  // Если результат отрицательный - значит выполняем действие по умолчанию
  TEST EAX, EAX
  JNZ @@QuitCmdSN
@@ExecCmdSN:
  // Восстановим регистры
  POPAD
  // Выполним старый код
  MOV AL, byte [EBP+$8]
  MOV byte [EBP-$0C], AL
  // И возвратим управление оригинальной функции
  PUSH $774FB0
  RET
@@QuitCmdSN:
  // ...Service вернула положительный результат, значит нужно корректно выйти из оригинальной функции
  // Восстановим регистры
  POPAD
  // И выйдем
  PUSH $77519F
  // RET
end; // .procedure Asm_Service

procedure Hook_BeforeHeroesInteraction; stdcall; assembler;
asm
  PUSH EBP
  MOV EBP, ESP
  PUSH EBX
  PUSH ESI
  PUSH EDI
  //
  PUSHAD
  CALL SaveEventParams
  MOV EAX, [EBP + $08]
  MOV EAX, [EAX + $1A]
  MOV DWORD [EventParams], EAX
  MOV EAX, [EBP + $0C]
  MOV EAX, [EAX]
  MOV DWORD [EventParams + 4], EAX
  xor EAX, EAX
  MOV DWORD [EventParams + 8], EAX
  PUSH TRIGGER_BEFORE_HEROINTERACTION
  CALL GenerateCustomErmEvent
  MOV EAX, DWORD [EventParams + 8]
  PUSH EAX
  CALL RestoreEventParams
  POP EAX
  TEST EAX, EAX
  JNZ @@AfterInteraction
  POPAD
  PUSH $4A2476
  RET
@@AfterInteraction:
  CALL SaveEventParams
  MOV EAX, [EBP + $08]
  MOV EAX, [EAX + $1A]
  MOV DWORD [EventParams], EAX
  MOV EAX, [EBP + $0C]
  MOV EAX, [EAX]
  MOV DWORD [EventParams + 4], EAX
  PUSH TRIGGER_BEFORE_HEROINTERACTION
  CALL GenerateCustomErmEvent
  CALL RestoreEventParams
  POPAD
  //
  POP EDI
  POP ESI
  POP EBX
  POP EBP
  RET $10
end; // .procedure Hook_BeforeHeroesInteraction

procedure Hook_AfterHeroesInteraction; stdcall; assembler;
asm
  CALL SaveEventParams
  MOV EAX, [EBP + $08]
  MOV EAX, [EAX + $1A]
  MOV DWORD [EventParams], EAX
  MOV EAX, [EBP + $0C]
  MOV EAX, [EAX]
  MOV DWORD [EventParams + 4], EAX
  PUSH TRIGGER_AFTER_HEROINTERACTION
  CALL GenerateCustomErmEvent
  CALL RestoreEventParams
  //
  POP EBX
  POP EBP
  RET $10
end; // .procedure Hook_AfterHeroesInteraction

procedure InitEra;
begin
  if hEra=0 then begin
    // Убеждаемся, что DllMain не будет вызвана 1000 и 1 раз из-за тредов
    hEra:=Windows.GetModuleHandle(C_ERA_DLLNAME);
    Windows.DisableThreadLibraryCalls(hEra);
    (* Секция патчинга *)
    // Сперва патчим функцию FindErm, чтобы были разрешены функции с любыми номерами
    // Temp:=$EB;
    // WriteAtCode(Ptr($74A724), @Temp, 1);
    // Патчим функцию ERM_Sound для поддержки новых команд
    HookCode(Ptr($774FAA), @Asm_Service, C_HOOKTYPE_JUMP, 6);
    (*
    // Патчим внутриигровой цикл для определения, в игре ли мы и установки хука на сообщения окна
    HookCode(pointer($4B0BA1), @Hook_GameLoop_Begin, C_HOOKTYPE_JUMP, 5);
    HookCode(pointer($4F051B), @Hook_GameLoop_End, C_HOOKTYPE_JUMP, 5);
    *)
    // Патчим вызов триггера !?HE
    (*HookCode(pointer($74D75B), @Hook_HeroesMeet_Call, C_HOOKTYPE_JUMP, 5);*)
    HookCode(pointer($4A2470), @Hook_BeforeHeroesInteraction, C_HOOKTYPE_JUMP, 6);
    HookCode(pointer($4A2521), @Hook_AfterHeroesInteraction, C_HOOKTYPE_JUMP, 5);
    HookCode(pointer($4A2531), @Hook_AfterHeroesInteraction, C_HOOKTYPE_JUMP, 5);
    HookCode(pointer($4A257B), @Hook_AfterHeroesInteraction, C_HOOKTYPE_JUMP, 5);
    HookCode(pointer($4A25AA), @Hook_AfterHeroesInteraction, C_HOOKTYPE_JUMP, 5);
    // Вызываем функции инициализации остальных модулей
    Triggers.Init;
  end; // .if 
end; // .procedure InitEra

begin
  InitEra; // Инициализируем фреймворк Эры
end.
