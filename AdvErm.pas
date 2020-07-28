unit AdvErm;
{
DESCRIPTION: Era custom Memory implementation
AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Math, Crypto, Utils, AssocArrays, DataLib, StrLib, TypeWrappers, Files, ApiJack, Alg,
  PatchApi, Core, GameExt, Erm, Stores, Triggers, Heroes, Lodman, Trans, EventMan;

const
  AUTO_ALLOC_SLOT = -1;
  NO_SLOT         = -1;
  
  IS_TEMP          = 0;
  NOT_TEMP         = 1;
  IS_TRIGGER_LOCAL = -1;

  (* For CheckCmdParamsEx *)
  TYPE_INT       = 1;
  TYPE_STR       = 2;
  TYPE_ANY       = 4;
  ACTION_SET     = 8;
  ACTION_GET     = 16;
  ACTION_ANY     = 32;
  PARAM_OPTIONAL = 64;
  
  SLOTS_SAVE_SECTION  = 'Era.DynArrays_SN_M';
  ASSOC_SAVE_SECTION  = 'Era.AssocArray_SN_W';
  HINTS_SAVE_SECTION  = 'Era.Hints_SN_H';
  
  (* TParamModifier *)
  NO_MODIFIER      = 0;
  MODIFIER_ADD     = 1;
  MODIFIER_SUB     = 2;
  MODIFIER_MUL     = 3;
  MODIFIER_DIV     = 4;
  MODIFIER_MOD     = 5;
  MODIFIER_CONCAT  = 6;
  MODIFIER_OR      = 7;
  MODIFIER_AND_NOT = 8;
  MODIFIER_SHL     = 9;
  MODIFIER_SHR     = 10;

  (* Era function call conventions *)
  ERA_CALLCONV_PASCAL           = 0;
  ERA_CALLCONV_CDECL_OR_STDCALL = 1;
  ERA_CALLCONV_THISCALL         = 2;
  ERA_CALLCONV_FASTCALL         = 3;
  ERA_CALLCONV_FLOAT_RES        = 4;

  (* ERM additional commands parameter config *)
  CMD_PARAMS_CONFIG_NONE                     = 0;
  CMD_PARAMS_CONFIG_SINGLE_INT               = 1;
  CMD_PARAMS_CONFIG_ONE_TO_FIVE_INTS         = 2;
  CMD_PARAMS_CONFIG_SINGLE_INT_AS_STRUCT_PTR = 3;
  CMD_PARAMS_CONFIG_FOUR_INTS                = 4;
  CMD_PARAMS_CONFIG_TWO_VARS                 = 5;

  (* Hint code flags *)
  CODE_TYPE_SUBTYPE = $01000000;

  ERM_MEMORY_DUMP_FILE = GameExt.DEBUG_DIR + '\erm memory dump.txt';

type
  (* Import *)
  TDict    = DataLib.TDict;
  TObjDict = DataLib.TObjDict;
  TString  = TypeWrappers.TString;

  TServiceParamValue = packed record
    case byte of
      0: (v:  integer);
      1: (p:  pointer);
      2: (pi: pinteger);
      3: (pc: pchar);
  end;

  PServiceParam            = ^TServiceParam;
  TServiceParamStrReturner = procedure (Param: PServiceParam; Str: pchar; StrLen: integer);
  TServiceParamIntReturner = procedure (Param: PServiceParam; Value: integer);

  TServiceParam = record
    IsStr:         longbool;
    OperGet:       longbool;
    Value:         TServiceParamValue;
    ValReturner:   pointer;
    ParamModifier: integer;

    procedure RetPchar ({n} Str: pchar; StrLen: integer = -1);
    procedure RetStr (const Str: string);
    procedure RetInt (Value: integer); inline;
  end;

  PServiceParams = ^TServiceParams;
  TServiceParams = array[0..23] of TServiceParam;

  (* Params index starts from 1 *)
  TCommandHandler = function (const CommandName: string; NumParams: integer; Params: PServiceParams; var Error: string): boolean;

  TErmCmdHandler = function (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: Erm.PErmSubCmd): integer cdecl;

  TVarType = (INT_VAR, STR_VAR);
  
  TSlot = class
    ItemsType: TVarType;
    IsTemp:    boolean;
    IntItems:  array of integer;
    StrItems:  array of string;
    NumItems:  integer;
  end;

  TSlotReleaser = class
   protected
    fSlotN: integer;

   public
    constructor Create (SlotN: integer);
    destructor Destroy; override;
  end;
  
  TAssocVar = class
    IntValue: integer;
    StrValue: string;
  end;

  (* Fast temp memory allocator for ERM inline strings storage during commands execution *)
  TServiceMemAllocator = record
    BufPos:    integer;
    Buf:       array [0..3000000 - 1] of char;
    BufBorder: integer;

    procedure Init;
    procedure AllocPage;
    function  Alloc (Size: integer): pointer;
    function  AllocStr (StrLen: integer): pchar;
    procedure FreePage;
    function  OwnsPtr (Addr: pointer): boolean;
  end;

  PErmCmdWrapper = ^TErmCmdWrapper;
  TErmCmdWrapper = record
    Success:    boolean;
    SubCmd:     Erm.PErmSubCmd;
    CmdPtr:     pchar;
    CmdName:    pchar;
    Cmd:        char;
    Error:      string;
    NumParams:  integer;
    _ParamsLen: integer;
    Params:     TServiceParams;

    function  FindNextSubcmd (AllowedSubcmds: Utils.TCharSet): boolean;
    procedure Cleanup;
    function  GetCmdResult: integer;
  end; // .record TErmCmdWrapper

  PSoundNameBuffer = ^TSoundNameBuffer;
  TSoundNameBuffer = array [0..255] of char;


procedure ResetMemory;
function  GetOrCreateAssocVar (const VarName: string): {U} TAssocVar;
procedure RegisterErmReceiver (const Cmd: string; {n} Handler: TErmCmdHandler; ParamsConfig: integer);
function  WrapErmCmd (CmdName: pchar; SubCmd: Erm.PErmSubCmd; var Wrapper: TErmCmdWrapper): PErmCmdWrapper;
procedure ApplyIntParam (var Param: TServiceParam; var Dest: integer);
procedure AssignPcharFromParam (var Param: TServiceParam; {n} Buf: pchar; BufSize: integer);
procedure AssignStrFromParam (var Param: TServiceParam; var Str: string);
function  CheckCmdParamsEx (Params: PServiceParams; NumParams: integer; const ParamConstraints: array of integer): boolean;


var
{O} AssocMem: {O} AssocArrays.TAssocArray {OF TAssocVar};

  ServiceMemAllocator: TServiceMemAllocator;

  
(***) implementation (***)


type
  PMp3TriggerContext = ^TMp3TriggerContext;
  TMp3TriggerContext = record
    TrackName:         string;
    DontTrackPosition: integer;
    Loop:              integer;
    DefaultReaction:   integer;
  end;

  TErmAdditionalCmd = packed record
    Id:           Erm.TErmCmdId;
    Handler:      TErmCmdHandler;
    ParamsConfig: integer;
  end;

var
(* Cached exported stdcall API of Era.dll and kernel32.dll *)
{O} ApiCache:       {U} TDict {of command name => API function address};
    Kernel32Handle: Windows.THandle;
    
    AdditionalCmds:    array [0..199] of TErmAdditionalCmd;
    NumAdditionalCmds: integer = 67;

{O} Hints:      {O} TDict {of [O] TObjDict of TString};
{O} Slots:      {O} AssocArrays.TObjArray {OF TSlot};
    FreeSlotN:  integer = AUTO_ALLOC_SLOT - 1;

    Mp3TriggerContext:   PMp3TriggerContext = nil;
    CurrentMp3Track:     string;
    CurrentSoundNameBuf: PSoundNameBuffer = nil;


constructor TSlotReleaser.Create (SlotN: integer);
begin
  Self.fSlotN := SlotN;
end;

destructor TSlotReleaser.Destroy;
begin
  Slots.DeleteItem(Ptr(Self.fSlotN));
end;

procedure TServiceMemAllocator.Init;
begin
  Self.BufPos                       := 0;
  pinteger(@Self.Buf[Self.BufPos])^ := 0;
  Self.BufBorder                    := 0;
end;

procedure TServiceMemAllocator.AllocPage;
begin
  Inc(Self.BufPos, sizeof(integer));
  {!} Assert(Self.BufPos + sizeof(integer) < sizeof(Self.Buf), 'TServiceMemAllocator.AllocPage failed. No space in buffer');
  pinteger(@Self.Buf[Self.BufPos])^ := 0;
end;

function TServiceMemAllocator.Alloc (Size: integer): pointer;
var
  PageSize:    integer;
  AlignedSize: integer;

begin
  AlignedSize := (Size + (sizeof(integer) - 1)) and not 3;
  result      := @Self.Buf[Self.BufPos];
  PageSize    := pinteger(@Self.Buf[Self.BufPos])^ + AlignedSize;
  Inc(Self.BufPos, AlignedSize);
  {!} Assert(Self.BufPos + sizeof(integer) < sizeof(Self.Buf), 'TServiceMemAllocator.Alloc failed. No space in buffer');
  pinteger(@Self.Buf[Self.BufPos])^ := PageSize;
end;

function TServiceMemAllocator.AllocStr (StrLen: integer): pchar;
begin
  result         := Self.Alloc(StrLen + 1);
  result[StrLen] := #0;
end;

procedure TServiceMemAllocator.FreePage;
begin
  {!} Assert(Self.BufPos > 0, 'TServiceMemAllocator.FreePage failed. No page allocated');
  Dec(Self.BufPos, pinteger(@Self.Buf[Self.BufPos])^ + sizeof(integer));
end;

function TServiceMemAllocator.OwnsPtr (Addr: pointer): boolean;
begin
  result := (cardinal(Addr) >= cardinal(@Self.Buf)) and (cardinal(Addr) <= cardinal(@Self.Buf[High(Self.Buf)]));
end;

procedure TServiceParam.RetPchar ({n} Str: pchar; StrLen: integer = -1);
begin
  if (Str = nil) or (StrLen = 0) then begin
    TServiceParamStrReturner(Self.ValReturner)(@Self, pchar(''), 0);
  end else if StrLen < 0 then begin
    TServiceParamStrReturner(Self.ValReturner)(@Self, Str, Windows.LStrLen(Str));
  end else begin
    TServiceParamStrReturner(Self.ValReturner)(@Self, Str, StrLen);
  end;
end;

procedure TServiceParam.RetStr (const Str: string);
begin
  if (Str = '') or (Str[1] = #0) then begin
    TServiceParamStrReturner(Self.ValReturner)(@Self, pchar(''), 0);
  end else begin
    TServiceParamStrReturner(Self.ValReturner)(@Self, pchar(Str), Length(Str));
  end;
end;

procedure TServiceParam.RetInt (Value: integer);
begin
  TServiceParamIntReturner(Self.ValReturner)(@Self, Value);
end;

procedure ErmIntReturner (Param: PServiceParam; Value: integer);
begin
  Param.Value.pi^ := Value;
end;

procedure AssocIntReturner (Param: PServiceParam; Value: integer);
var
{Un} AssocVarValue: TAssocVar;

begin
  AssocVarValue := TAssocVar(AssocMem[Param.Value.pc]);
  // * * * * * //
  if AssocVarValue = nil then begin
    AssocVarValue            := TAssocVar.Create;
    AssocMem[Param.Value.pc] := AssocVarValue;
  end;

  AssocVarValue.IntValue := Value;
end;

procedure ZVarStrReturner (Param: PServiceParam; Str: pchar; StrLen: integer);
begin
  Utils.CopyMem(Math.Min(sizeof(TErmZVar) - 1, StrLen) + 1, Str, Param.Value.pc);
end;

procedure AssocStrReturner (Param: PServiceParam; Str: pchar; StrLen: integer);
var
{Un} AssocVarValue: TAssocVar;

begin
  {!} Assert(Utils.IsValidBuf(Str, StrLen));
  AssocVarValue := TAssocVar(AssocMem[Param.Value.pc]);
  // * * * * * //
  if AssocVarValue = nil then begin
    AssocVarValue            := TAssocVar.Create;
    AssocMem[Param.Value.pc] := AssocVarValue;
  end;

  System.SetString(AssocVarValue.StrValue, pchar(Str), StrLen);
end;

function ErmVarToStr (VarType: char; Ind: integer; var Res: string): boolean;
begin
  result := true;
  
  case VarType of
    'V': begin
      result := (Ind >= Low(Erm.v^)) and (Ind <= High(Erm.v^));
      
      if result then begin
        Res := SysUtils.IntToStr(Erm.v[Ind]);
      end;
    end;

    'W': begin
      result := (Ind >= 1) and (Ind <= 200) and (Erm.GetErmCurrHero <> nil);
      
      if result then begin
        Res := SysUtils.IntToStr(Erm.w[Erm.ZvsWHero^, Ind]);
      end;
    end;

    'X': begin
      result := (Ind >= Low(Erm.x^)) and (Ind <= High(Erm.x^));
      
      if result then begin
        Res := SysUtils.IntToStr(Erm.x[Ind]);
      end;
    end;

    'Y': begin
      result := ((Ind >= Low(Erm.y^)) and (Ind <= High(Erm.y^))) or ((-Ind >= Low(Erm.ny^)) and (-Ind <= High(Erm.ny^)));
      
      if result then begin
        if Ind > 0 then begin
          Res := SysUtils.IntToStr(Erm.y[Ind]);
        end else begin
          Res := SysUtils.IntToStr(Erm.ny^[-Ind]);
        end;
      end;
    end;

    'E': begin
      result := ((Ind >= Low(Erm.e^)) and (Ind <= High(Erm.e^))) or ((-Ind >= Low(Erm.ne^)) and (-Ind <= High(Erm.ne^)));
      
      if result then begin
        if Ind > 0 then begin
          Res := SysUtils.FloatToStr(Erm.e^[Ind]);
        end else begin
          Res := SysUtils.FloatToStr(Erm.ne^[-Ind]);
        end;
      end;
    end;

    'Z': begin
      result := (Ind >= -High(Erm.nz^)) and (Ind <> 0);
      
      if result then begin
        if Ind > 1000 then begin
          Res := ZvsGetErtStr(Ind);
        end else if Ind > 0 then begin
          Res := pchar(@Erm.z[Ind]);
        end else begin
          Res := pchar(@Erm.nz^[-Ind]);
        end;
      end;
    end;
  else
    result := false;
  end; // .switch VarType
end; // .function ErmVarToStr

function ErmVarToServiceParam (VarType: char; Ind: integer; IsGet: boolean; var ServiceParam: TServiceParam): boolean;
begin
  result             := true;
  ServiceParam.IsStr := false;

  case VarType of
    'v': begin
      result := (Ind >= Low(Erm.v^)) and (Ind <= High(Erm.v^));
      
      if result then begin
        if IsGet then begin
          ServiceParam.Value.p := @Erm.v[Ind];
        end else begin
          ServiceParam.Value.v := Erm.v[Ind];
        end;
      end else begin
        Erm.ShowErmError('v-index is out of range 1..10000');
      end;
    end;

    'w': begin
      result := (Ind >= 1) and (Ind <= 200) and (Erm.GetErmCurrHero <> nil);
      
      if result then begin
        if IsGet then begin
          ServiceParam.Value.p := @Erm.w[Erm.ZvsWHero^, Ind];
        end else begin
          ServiceParam.Value.v := Erm.w[Erm.ZvsWHero^, Ind];
        end;
      end else begin
        Erm.ShowErmError('w-index is out of range 1..200');
      end;
    end;

    'x': begin
      result := (Ind >= Low(Erm.x^)) and (Ind <= High(Erm.x^));
      
      if result then begin
        if IsGet then begin
          ServiceParam.Value.p := @Erm.x[Ind];
        end else begin
          ServiceParam.Value.v := Erm.x[Ind];
        end;
      end else begin
        Erm.ShowErmError('x-index is out of range 1..16');
      end;
    end;

    'y': begin
      result := ((Ind >= Low(Erm.y^)) and (Ind <= High(Erm.y^))) or ((-Ind >= Low(Erm.ny^)) and (-Ind <= High(Erm.ny^)));
      
      if result then begin
        if Ind > 0 then begin
          ServiceParam.Value.p := @Erm.y[Ind];
        end else begin
          ServiceParam.Value.p := @Erm.ny[-Ind];
        end;

        if not IsGet then begin
          ServiceParam.Value.v := pinteger(ServiceParam.Value.p)^;
        end;
      end else begin
        Erm.ShowErmError('y-index is out of range -100..-1, 1..100');
      end;
    end;

    'e': begin
      result := ((Ind >= Low(Erm.e^)) and (Ind <= High(Erm.e^))) or ((-Ind >= Low(Erm.ne^)) and (-Ind <= High(Erm.ne^)));
      
      if result then begin
        if Ind > 0 then begin
          ServiceParam.Value.p := @Erm.e[Ind];
        end else begin
          ServiceParam.Value.p := @Erm.ne[-Ind];
        end;

        if not IsGet then begin
          ServiceParam.Value.v := pinteger(ServiceParam.Value.p)^;
        end;
      end else begin
        Erm.ShowErmError('e-index is out of range -100..-1, 1..100');
      end;
    end;

    'z': begin
      result := (Ind >= -High(Erm.nz^)) and (Ind <> 0);
      
      if result then begin
        if Ind > 1000 then begin
          ServiceParam.Value.pc := ZvsGetErtStr(Ind);
        end else if Ind > 0 then begin
          ServiceParam.Value.pc := pchar(@Erm.z[Ind]);
        end else begin
          ServiceParam.Value.pc := pchar(@Erm.nz[-Ind]);
        end;

        ServiceParam.IsStr := true;
      end; // .if
    end; // .case

    'f'..'t': begin
      if IsGet then begin
        ServiceParam.Value.p := @Erm.QuickVars[Ind];
      end else begin
        ServiceParam.Value.v := Erm.QuickVars[Ind];
      end;
    end;
  else
    result := false;
  end; // .switch VarType
end; // .function ErmVarToServiceParam

function GetServiceParams (Cmd: pchar; var NumParams: integer; var Params: TServiceParams): integer;
const
  INDEXABLE_PAR_TYPES = ['v', 'y', 'x', 'z', 'w', 'e'];
  PARAM_START_CHARS   = ['x', 'y', 'z', 'w', 'v', 'e', 'f'..'t', 'd', '+', '-', '0'..'9', '?', '^'];

var
  PCmd:          pchar;
  CmdMark:       pchar;
  Param:         PServiceParam;
  ParType:       char;
  ParValue:      integer;
  BaseParType:   char;
  IsIndexed:     boolean;
  StartPos:      integer;
  Pos:           integer;
  StrLen:        integer;
  SingleDSyntax: longbool;
  AssocVarUsed:  longbool;
  AssocVarValue: TAssocVar;

begin
  PCmd      := pointer(Cmd);
  NumParams := 0;
  Pos       := 1;

  while true do begin
    while PCmd[Pos] in [#1..#32] do begin
      Inc(Pos);
    end;

    if not (PCmd[Pos] in PARAM_START_CHARS) then begin
      break;
    end;

    SingleDSyntax       := false;
    Param               := @Params[NumParams];
    Param.ParamModifier := NO_MODIFIER;

    // Detect command type: GET or SET
    if PCmd[Pos] = '?' then begin
      Param.OperGet := true;
      Inc(Pos);
    end else begin
      Param.OperGet := false;

      if PCmd[Pos] = 'd' then begin
        Param.ParamModifier := MODIFIER_ADD;
        Inc(Pos);

        case PCmd[Pos] of
          '+': begin Param.ParamModifier := MODIFIER_ADD;     Inc(Pos); end;
          '-': begin Param.ParamModifier := MODIFIER_SUB;     Inc(Pos); end;
          '*': begin Param.ParamModifier := MODIFIER_MUL;     Inc(Pos); end;
          ':': begin Param.ParamModifier := MODIFIER_DIV;     Inc(Pos); end;
          '%': begin Param.ParamModifier := MODIFIER_MOD;     Inc(Pos); end;
          '&': begin Param.ParamModifier := MODIFIER_CONCAT;  Inc(Pos); end;
          '|': begin Param.ParamModifier := MODIFIER_OR;      Inc(Pos); end;
          '~': begin Param.ParamModifier := MODIFIER_AND_NOT; Inc(Pos); end;
          
          '<': begin
            if PCmd[Pos + 1] = '<' then begin
              Param.ParamModifier := MODIFIER_SHL;
              Inc(Pos, 2);
            end else begin
              SingleDSyntax := true;
            end;
          end;
          
          '>': begin
            if PCmd[Pos + 1] = '>' then begin
              Param.ParamModifier := MODIFIER_SHR;
              Inc(Pos, 2);
            end else begin
              SingleDSyntax := true;
            end;
          end;
        else
          SingleDSyntax := true;
        end; // .switch
      end; // .if
    end; // .else

    AssocVarUsed := false;
    BaseParType  := PCmd[Pos];
    IsIndexed    := BaseParType in INDEXABLE_PAR_TYPES;

    if IsIndexed then begin
      Inc(Pos);
    end;

    if (BaseParType = '^') or ((BaseParType in ['s', 'i']) and (PCmd[Pos + 1] = '^')) then begin
      Param.IsStr  := true;
      AssocVarUsed := BaseParType <> '^';

      if AssocVarUsed then begin
        Param.IsStr := BaseParType = 's';
        Inc(Pos);
      end;
      
      Inc(Pos);
      StartPos := Pos;
      
      while not (PCmd[Pos] in ['^', #0]) do begin
        Inc(Pos);
      end;

      if PCmd[Pos] <> '^' then begin
        result := -1;
        exit;
      end;
      
      StrLen    := Pos - StartPos;
      PCmd[Pos] := #0;

      if SysUtils.StrScan(@PCmd[StartPos], '%') <> nil then begin
        Param.Value.pc := Erm.ZvsInterpolateStr(@PCmd[StartPos]);
        StrLen         := Windows.LStrLen(Param.Value.pc);
        Param.Value.pc := LStrCpy(ServiceMemAllocator.AllocStr(StrLen), Param.Value.pc);
      end else begin
        Param.Value.pc := ServiceMemAllocator.AllocStr(StrLen);
        Utils.CopyMem(StrLen, pchar(@PCmd[StartPos]), Param.Value.pc);
      end;

      
      PCmd[Pos] := '^';
      Inc(Pos);

      // Get and interpret associative var
      if AssocVarUsed then begin
        if Param.OperGet then begin
          if Param.IsStr then begin
            Param.ValReturner := @AssocStrReturner;
          end else begin
            Param.ValReturner := @AssocIntReturner;
          end;
        end else begin
          AssocVarValue := TAssocVar(AssocMem[Param.Value.pc]);

          if Param.IsStr then begin
            if (AssocVarValue = nil) or (AssocVarValue.StrValue = '') then begin
              Param.Value.pc := '';
            end else begin
              StrLen         := Length(AssocVarValue.StrValue);
              Param.Value.pc := ServiceMemAllocator.AllocStr(StrLen);
              Utils.CopyMem(StrLen, pchar(AssocVarValue.StrValue), Param.Value.pc);
            end;
          end else begin
            if AssocVarValue = nil then begin
              Param.Value.v := 0;
            end else begin
              Param.Value.v := AssocVarValue.IntValue;
            end;
          end; // .else
        end; // .else
      end; // .if
    end else begin
      // Get parameter type: z, v, x, y, w, e, f..t or constant
      ParType := PCmd[Pos];

      if (ParType in [';', '/', #1..#32]) and SingleDSyntax then begin
        Param.IsStr   := false;
        Param.Value.v := 0;
      end else begin
        if ParType in ['-', '+', '0'..'9'] then begin
          ParType := #0;
        end else begin
          Inc(Pos);
        end;

        if ParType in ['f'..'t'] then begin
          ParValue := ord(ParType) - ord('f') + Low(Erm.QuickVars^);
        end else begin
          // Remember parameter start position
          StartPos := Pos;
          CmdMark  := @PCmd[StartPos];

          if not StrLib.ParseIntFromPchar(CmdMark, ParValue) then begin
            result := -1; exit;
          end;
          
          Inc(Pos, integer(CmdMark) - integer(@PCmd[StartPos]));
        end; // .else

        // Literal values are handled, now handle variables
        if ParType <> #0 then begin
          if not ErmVarToServiceParam(ParType, ParValue, Param.OperGet and not IsIndexed, Param^) then begin
            result := -1; exit;
          end;
        // Disallow GET for numeric constants
        end else if not IsIndexed and Param.OperGet then begin
          result := -1; exit;
        // Allow SET for numeric constants
        end else begin
          Param.IsStr   := false;
          Param.Value.v := ParValue;
        end;
      end; // .else
    end; // .else

    if IsIndexed then begin
      // Strings are not valid indexes
      if Param.IsStr then begin
        result := -1; exit;
      end;
      
      if not ErmVarToServiceParam(BaseParType, Param.Value.v, Param.OperGet, Param^) then begin
        result := -1; exit;
      end;
    end;

    // Recheck if modifiers are valid
    if (Param.IsStr and not(Param.ParamModifier in [NO_MODIFIER, MODIFIER_CONCAT])) or
       (not Param.IsStr and (Param.ParamModifier = MODIFIER_CONCAT))
    then begin
      result := -1; exit;
    end;

    // Set up getter methods for native ERM variables
    if Param.OperGet and (IsIndexed or not AssocVarUsed) then begin
      if Param.IsStr then begin
        Param.ValReturner := @ZVarStrReturner;
      end else begin
        Param.ValReturner := @ErmIntReturner;
      end;
    end;

    Inc(NumParams);

    while PCmd[Pos] in [#1..#32] do begin
      Inc(Pos);
    end;

    if PCmd[Pos] = '/' then begin
      Inc(Pos);
    end;
  end; // .while
  
  result := Pos;
end; // .function GetServiceParams

procedure CallProc (Addr: integer; Convention: integer; PParams: pointer; NumParams: integer); stdcall; assembler;
const
  SERVICE_PARAM_SIZE = sizeof(TServiceParam); // Offset to the next parameter in parameters array

var
  SavedEsp: integer;
  IsIntRes: integer;
  
asm
  MOV IsIntRes, 1
  CMP Convention, ERA_CALLCONV_FLOAT_RES
  JB @@IntConvention
@@FloatConvetion:
  SUB Convention, ERA_CALLCONV_FLOAT_RES
  MOV IsIntRes, 0
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
  IMUL ECX, ECX, SERVICE_PARAM_SIZE
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

  CMP IsIntRes, 1
  JNE @@FloatRes
  // Set v1
  MOV DWORD [$887668], EAX
  JMP @@Ret
@@FloatRes:
  // Set e1
  FST DWORD [$A48F18]

@@Ret:
  MOV ESP, SavedEsp
  POP EBX
  // RET
end; // .procedure CallProc

(* Returns Era/kernel32 API function address by name. Caches positive results *)
function GetCombinedApiAddr (const ApiName: string): {n} pointer;
begin
  result := ApiCache[ApiName];

  if result = nil then begin
    result := Windows.GetProcAddress(GameExt.hEra, pchar(ApiName));

    if result = nil then begin
      result := Windows.GetProcAddress(Kernel32Handle, pchar(ApiName));
    end;

    if result <> nil then begin
      ApiCache[ApiName] := result;
    end;
  end;
end;

function GetAdditionalCmdHandler (CmdId: word): {n} TErmCmdHandler;
var
  i: integer;

begin
  result := nil;

  for i := 0 to NumAdditionalCmds - 1 do begin
    if AdditionalCmds[i].Id.Id = CmdId then begin
      result := @AdditionalCmds[i].Handler;
      exit;
    end;
  end;
end;

(* Stores direct cmd handler in cmd parameters *)
procedure OptimizeErmCmd (Cmd: Erm.PErmCmd);
begin
  Cmd.Params[High(Cmd.Params)].Value := integer(GetAdditionalCmdHandler(Cmd.CmdId.Id));
end;

procedure RegisterErmReceiver (const Cmd: string; {n} Handler: TErmCmdHandler; ParamsConfig: integer);
var
  CmdId: Erm.TErmCmdId;
  i:     integer;

begin
  {!} Assert(Length(Cmd) = 2, 'Cannot register invalid ERM receiver: ' + Cmd);
  CmdId.Name[0] := Cmd[1];
  CmdId.Name[1] := Cmd[2];

  i := 0;

  while (i < NumAdditionalCmds) and (AdditionalCmds[i].Id.Id <> CmdId.Id) do begin
    Inc(i);
  end;

  {!} Assert(i <= High(AdditionalCmds), 'Cannot register more ERM receivers');
  
  AdditionalCmds[i].Id.Id        := CmdId.Id;
  AdditionalCmds[i].Handler      := Handler;
  AdditionalCmds[i].ParamsConfig := ParamsConfig;

  if i >= NumAdditionalCmds then begin
    Inc(NumAdditionalCmds);
  end;

  AdditionalCmds[NumAdditionalCmds].Id.Id   := 0;
  AdditionalCmds[NumAdditionalCmds].Handler := nil;
end; // .procedure RegisterErmReceiver

function WrapErmCmd (CmdName: pchar; SubCmd: Erm.PErmSubCmd; var Wrapper: TErmCmdWrapper): PErmCmdWrapper;
begin
  {!} Assert(CmdName <> nil);
  {!} Assert(SubCmd <> nil);
  SubCmd.Pos      := 0;
  Wrapper.SubCmd  := SubCmd;
  Wrapper.CmdName := CmdName;
  result          := @Wrapper;

  with Wrapper do begin
    Success    := true;
    CmdPtr     := @SubCmd.Code.Value[0];
    Cmd        := CmdPtr^;
    Error      := 'Invalid command parameters';
    NumParams  := 0;
    _ParamsLen := 0;
  end;
end; // .function WrapErmCm

function TErmCmdWrapper.FindNextSubcmd (AllowedSubcmds: Utils.TCharSet): boolean;
begin
  // Skip parameters and subcommand from previous call
  if Self.Success and (Self._ParamsLen > 0) then begin
    Inc(Self.CmdPtr,     Self._ParamsLen);
    Inc(Self.SubCmd.Pos, Self._ParamsLen);
    Self._ParamsLen := 0;
  end;

  result := Self.Success;

  if result then begin
    while Self.CmdPtr^ in [#1..#32] do begin
      Inc(Self.CmdPtr^);
      Inc(Self.SubCmd.Pos);
    end;

    result := not (Self.CmdPtr^ in [';', #0]);
  end;

  if result then begin
    Self.Cmd     := Self.CmdPtr^;
    Self.Success := Self.Cmd in AllowedSubcmds;
    result       := Self.Success;

    if not Self.Success then begin
      Error := 'Unknown command "!!' + Self.CmdName + ':' + Self.Cmd + '"';
    end else begin
      Self._ParamsLen := GetServiceParams(Self.CmdPtr, Self.NumParams, Self.Params);

      if Self._ParamsLen = -1 then begin
        Self.Success := false;
        result       := false;
      end;
    end; // .else
  end; // .if
end; // .function TErmCmdWrapper.FindNextSubcmd

procedure TErmCmdWrapper.Cleanup;
begin
  // May be necessary again in the future in case of code optimization and manual cleaup
end;

function TErmCmdWrapper.GetCmdResult: integer;
begin
  result := ord(Self.Success);

  if not Self.Success then begin
    Erm.ErmErrCmdPtr^ := @SubCmd.Code.Value[0];
    Erm.ShowErmError(Self.Error);
  end;
end;

procedure ApplyIntParam (var Param: TServiceParam; var Dest: integer);
begin
  if Param.OperGet then begin
    Param.RetInt(Dest);
  end else begin
    case Param.ParamModifier of 
      NO_MODIFIER:  Dest := Param.Value.v;
      MODIFIER_ADD: Dest := Dest + Param.Value.v;
      MODIFIER_SUB: Dest := Dest - Param.Value.v;
      MODIFIER_MUL: Dest := Dest * Param.Value.v;
      
      MODIFIER_DIV: begin
        if Param.Value.v <> 0 then begin
          Dest := Dest div Param.Value.v;
        end else begin
          ShowErmError('Division by zero in d-modifier');
        end;
      end;

      MODIFIER_MOD: begin
        if Param.Value.v <> 0 then begin
          Dest := Dest mod Param.Value.v;
        end else begin
          ShowErmError('Division by zero in d-modifier');
        end;
      end;

      MODIFIER_OR:      Dest := Dest and Param.Value.v;
      MODIFIER_AND_NOT: Dest := Dest and not Param.Value.v;
      MODIFIER_SHL:     Dest := Dest shl Alg.ToRange(Param.Value.v, 0, 100);
      MODIFIER_SHR:     Dest := Dest shr Alg.ToRange(Param.Value.v, 0, 100);
    end; // .switch
  end; // .else
end; // .procedure ApplyIntParam

procedure AssignPcharFromParam (var Param: TServiceParam; {n} Buf: pchar; BufSize: integer);
begin
  {!} Assert(Utils.IsValidBuf(Buf, BufSize));
  {!} Assert(not Param.OperGet);
  if Param.ParamModifier <> MODIFIER_CONCAT then begin
    Utils.SetPcharValue(Buf, Param.Value.pc, BufSize);
  end else begin
    StrLib.Concat(Buf, BufSize, Buf, -1, Param.Value.pc, -1);
  end;
end;

procedure AssignStrFromParam (var Param: TServiceParam; var Str: string);
begin
  {!} Assert(not Param.OperGet);
  if Param.ParamModifier <> MODIFIER_CONCAT then begin
    Str := Param.Value.pc;
  end else begin
    Str := Str + Param.Value.pc;
  end;
end;

function CheckCmdParamsEx (Params: PServiceParams; NumParams: integer; const ParamConstraints: array of integer): boolean;
var
  i: integer;

begin
  {!} Assert(Params <> nil);
  result := true;

  for i := 0 to High(ParamConstraints) do begin
    with Utils.Flags(ParamConstraints[i]) do begin
      if i >= NumParams then begin
        result := Have(PARAM_OPTIONAL);
        exit;
      end;

      if
        (Have(TYPE_INT)   and     Params[i].IsStr)   or
        (Have(TYPE_STR)   and not Params[i].IsStr)   or
        (Have(ACTION_GET) and not Params[i].OperGet) or
        (Have(ACTION_SET) and     Params[i].OperGet)
      then begin
        result := false;
        exit;
      end;
    end;
  end; // .for
end; // .function CheckCmdParamsEx

function GetSlotItemsCount (Slot: TSlot): integer;
begin
  {!} Assert(Slot <> nil);
  result := Slot.NumItems;
end;

procedure SetSlotItemsCount (NewNumItems: integer; Slot: TSlot);
const
  MIN_SLOT_CAPACITY = 8;
  GROWTH_RATE       = 2;

var
  i: integer;

begin
  {!} Assert(NewNumItems >= 0);
  {!} Assert(Slot <> nil);

  if Slot.ItemsType = INT_VAR then begin
    if NewNumItems <> Slot.NumItems then begin
      // Shrinking
      if NewNumItems < Slot.NumItems then begin
        if (NewNumItems > MIN_SLOT_CAPACITY) and (NewNumItems * (GROWTH_RATE * 2) <= Length(Slot.IntItems)) then begin
          SetLength(Slot.IntItems, NewNumItems * GROWTH_RATE);
        end;

        for i := NewNumItems to Slot.NumItems - 1 do begin
          Slot.IntItems[i] := 0;
        end;
      end
      // Growing
      else begin
        // Lack of capacity
        if NewNumItems > Length(Slot.IntItems) then begin
          SetLength(Slot.IntItems, Math.Max(MIN_SLOT_CAPACITY, Math.Max(NewNumItems, Slot.NumItems * GROWTH_RATE)));
        end;
      end; // .else
    end; // .if
  end else begin
    if NewNumItems <> Slot.NumItems then begin
      // Shrinking
      if NewNumItems < Slot.NumItems then begin
        if (NewNumItems > MIN_SLOT_CAPACITY) and (NewNumItems * (GROWTH_RATE * 2) <= Length(Slot.StrItems)) then begin
          SetLength(Slot.StrItems, NewNumItems * GROWTH_RATE);
        end;

        for i := NewNumItems to Slot.NumItems - 1 do begin
          Slot.StrItems[i] := '';
        end;
      end
      // Growing
      else begin
        // Lack of capacity
        if NewNumItems > Length(Slot.StrItems) then begin
          SetLength(Slot.StrItems, Math.Max(MIN_SLOT_CAPACITY, Math.Max(NewNumItems, Slot.NumItems * GROWTH_RATE)));
        end;
      end; // .else
    end; // .if
  end; // .else

  Slot.NumItems := NewNumItems;
end; // .procedure SetSlotItemsCount

function NewSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): TSlot;
begin
  {!} Assert(ItemsCount >= 0);
  result           := TSlot.Create;
  result.ItemsType := ItemsType;
  result.IsTemp    := IsTemp;
  result.NumItems  := 0;
  
  SetSlotItemsCount(ItemsCount, result);
end;
  
function GetSlot (SlotN: integer; out {U} Slot: TSlot; out Error: string): boolean;
begin
  {!} Assert(Slot = nil);
  Slot   := Slots[Ptr(SlotN)];
  result := Slot <> nil;
  
  if not result then begin
    Error := 'Slot #' + SysUtils.IntToStr(SlotN) + ' does not exist.';
  end;
end;

function AllocSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): integer;
begin
  while Slots[Ptr(FreeSlotN)] <> nil do begin
    Dec(FreeSlotN);
    
    if FreeSlotN > 0 then begin
      FreeSlotN := AUTO_ALLOC_SLOT - 1;
    end;
  end;
  
  Slots[Ptr(FreeSlotN)] := NewSlot(ItemsCount, ItemsType, IsTemp);
  result                := FreeSlotN;
  Dec(FreeSlotN);
  
  if FreeSlotN > 0 then begin
    FreeSlotN := AUTO_ALLOC_SLOT - 1;
  end;
end; // .function AllocSlot

function GetOrCreateAssocVar (const VarName: string): {U} TAssocVar;
begin
  result := AssocMem[VarName];

  if result = nil then begin
    result            := TAssocVar.Create;
    AssocMem[VarName] := result;
  end;
end;

function SN_H (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
{U} Section:     TObjDict;
{U} StrValue:    TString;
    SectionName: string;
    HintRaw:     pchar;
    Code:        integer;
    DeleteHint:  boolean;

    ObjType:    integer;
    ObjSubtype: integer;

    x: integer;
    y: integer;
    z: integer;

    Hero:     integer;
    NameType: integer;
    Skill:    integer;
    Monster:  integer absolute Skill;
    Art:      integer absolute Skill;

  (* Returns new hint address or nil if hint was deleted *)
  function UpdateHint (HintParamN: integer): {n} pchar;
  begin
    if DeleteHint then begin
      Section.DeleteItem(Ptr(Code));
      result := nil;
    end else begin
      StrValue := TString(Section[Ptr(Code)]);

      if StrValue = nil then begin
        StrValue           := TString.Create('');
        Section[Ptr(Code)] := StrValue;     
      end;

      AssignStrFromParam(Params[HintParamN], StrValue.Value);

      result := pchar(StrValue.Value);
    end; // .else
  end; // .function UpdateHint

begin
  Section  := nil;
  StrValue := nil;
  result   := true;
  // * * * * * //
  if NumParams >= 3 then begin
    result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET or TYPE_STR]);

    if result then begin
      SectionName := Params[0].Value.pc;
      DeleteHint  := (SectionName <> '') and (SectionName[1] = '-');

      if DeleteHint then begin
        SectionName := Copy(SectionName, 2);
      end;

      Section := TObjDict(Hints[SectionName]);
      result  := Section <> nil;

      if result then begin
        if SectionName = 'object' then begin
          // SN:H^object^/#type/#subtype or -1/$hint
          if NumParams = 4 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);
            
            if result then begin
              ObjType    := Params[1].Value.v;
              ObjSubtype := Params[2].Value.v;
              result     := Math.InRange(ObjType, -1, 254) and Math.InRange(ObjSubtype, -1, 254);

              if result then begin
                if ObjType = -1 then begin
                  ObjType := 255;
                end;

                if ObjSubtype = -1 then begin
                  ObjSubtype := 255;
                end;

                Code := ObjType or (ObjSubtype shl 8) or CODE_TYPE_SUBTYPE;

                if Params[3].OperGet then begin
                  Params[3].RetStr(TString.ToString(Section[Ptr(Code)]));
                end else begin
                  UpdateHint(3);
                end;
              end; // .if
            end; // .if
          // SN:H^object^/x/y/z/hint
          end else if NumParams = 5 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);

            if result then begin
              x      := Params[1].Value.v;
              y      := Params[2].Value.v;
              z      := Params[3].Value.v;
              result := Math.InRange(x, 0, 255) and Math.InRange(y, 0, 255) and Math.InRange(z, 0, 255);

              if result then begin
                Code := x or (y shl 8) or (z shl 16);

                if Params[4].OperGet then begin
                  StrValue := Section[Ptr(Code)];                 
                  
                  if StrValue = nil then begin
                    Params[4].RetStr('');
                  end else begin
                    Params[4].RetStr(StrValue.Value);
                  end;
                end else begin
                  UpdateHint(4);
                end;
              end;
            end; // .if
          end else begin
            result := false;
            Error  := 'Invalid number of command parameters';
          end; // .else
        // SN:H^spec^/hero/short (0), full (1) or descr (2)/hint
        end else if SectionName = 'spec' then begin
          if NumParams = 4 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);

            if result then begin
              Hero     := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Hero, 0, Erm.NUM_WOG_HEROES - 1) and Math.InRange(NameType, 0, 2);
              
              if result then begin
                if Params[3].OperGet then begin
                  Params[3].RetPchar(Erm.HeroSpecsTable[Hero].Descr[NameType]);
                end else begin
                  Code    := Hero or (NameType shl 8);
                  HintRaw := UpdateHint(3);
                  Erm.HeroSpecSettingsTable[Hero].ZVarDescr[NameType] := 0;

                  if DeleteHint then begin
                    Erm.HeroSpecsTable[Hero].Descr[NameType] := Erm.HeroSpecsTableBack[Hero].Descr[NameType];
                  end else begin
                    Erm.HeroSpecsTable[Hero].Descr[NameType] := HintRaw;
                  end;
                end; // .else
              end; // .if
            end; // .if
          end else begin
            result := false;
            Error  := 'Invalid number of command parameters';
          end; // .else
        // SN:H^secskill^/skill/name (0), basic (1), advanced (2) or expert (3)/text
        end else if SectionName = 'secskill' then begin
          if NumParams = 4 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);

            if result then begin
              Skill    := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Skill, 0, Heroes.MAX_SECONDARY_SKILLS - 1) and Math.InRange(NameType, 0, Heroes.SKILL_LEVEL_EXPERT);
              
              if result then begin
                if Params[3].OperGet then begin
                  Params[3].RetPchar(Heroes.SecSkillTexts[Skill].Texts[NameType]);
                end else begin
                  Code    := Skill or (NameType shl 8);
                  HintRaw := UpdateHint(3);
                  Erm.SecSkillSettingsTable[Skill].Texts[NameType] := 0;

                  if DeleteHint then begin
                    Heroes.SecSkillTexts[Skill].Texts[NameType] := Erm.SecSkillTextsBack[Skill].Texts[NameType];

                    if NameType = Heroes.SKILL_LEVEL_NONE then begin
                      Heroes.SecSkillNames[Skill] := Erm.SecSkillNamesBack[Skill];
                    end else begin
                      Heroes.SecSkillDescs[Skill].Descs[NameType - 1] := Erm.SecSkillDescsBack[Skill].Descs[NameType - 1];
                    end;
                  end else begin
                    Heroes.SecSkillTexts[Skill].Texts[NameType] := HintRaw;

                    if NameType = Heroes.SKILL_LEVEL_NONE then begin
                      Heroes.SecSkillNames[Skill] := HintRaw;
                    end else begin
                      Heroes.SecSkillDescs[Skill].Descs[NameType - 1] := HintRaw;
                    end;
                  end; // .else
                end; // .else
              end; // .if
            end; // .if
          end else begin
            result := false;
            Error  := 'Invalid number of command parameters';
          end; // .else
        // SN:H^monname^/monster/single (0), plural (1), description (2)/text
        end else if SectionName = 'monname' then begin
          if NumParams = 4 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);

            if result then begin
              Monster  := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Monster, 0, Heroes.NumMonstersPtr^ - 1) and Math.InRange(NameType, 0, 2);
              
              if result then begin
                if Params[3].OperGet then begin
                  Params[3].RetPchar(Heroes.MonInfos[Monster].Names.Texts[NameType]);
                end else begin
                  Code    := Monster or (NameType shl 16);
                  HintRaw := UpdateHint(3);
                  Erm.MonNamesSettingsTable[Monster].Texts[NameType] := 0;

                  if DeleteHint then begin
                    Heroes.MonInfos[Monster].Names.Texts[NameType] := Erm.MonNamesTablesBack[NameType][Monster];
                    Erm.MonNamesTables[NameType][Monster]          := Erm.MonNamesTablesBack[NameType][Monster];
                  end else begin
                    Heroes.MonInfos[Monster].Names.Texts[NameType] := HintRaw;
                    Erm.MonNamesTables[NameType][Monster]          := HintRaw;
                  end;
                end; // .else
              end; // .if
            end; // .if
          end else begin
            result := false;
            Error  := 'Invalid number of command parameters';
          end; // .else
        // SN:H^art^/art/name (0) or description (1)/text
        end else if SectionName = 'art' then begin
          if NumParams = 4 then begin
            result := CheckCmdParamsEx(Params, NumParams, [TYPE_ANY, ACTION_SET or TYPE_INT, ACTION_SET or TYPE_INT, TYPE_STR]);

            if result then begin
              Art      := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Art, 0, Heroes.NumArtsPtr^ - 1) and Math.InRange(NameType, 0, 1);
              
              if result then begin
                if Params[3].OperGet then begin
                  Params[3].RetPchar(Heroes.ArtInfos[Art].GetTextField(NameType).pc);
                end else begin
                  Code    := Art or (NameType shl 16);
                  HintRaw := UpdateHint(3);
                  Erm.ArtNamesSettingsTable[Art].Texts[NameType] := 0;

                  if DeleteHint then begin
                    Heroes.ArtInfos[Art].GetTextField(NameType).pc := Erm.ArtInfosBack[Art].GetTextField(NameType).pc;
                  end else begin
                    Heroes.ArtInfos[Art].GetTextField(NameType).pc := HintRaw;
                  end;
                end; // .else
              end; // .if
            end; // .if
          end else begin
            result := false;
            Error  := 'Invalid number of command parameters';
          end; // .else
        end; // .elsif
      end; // .if
    end; // .if
  end else begin
    result := false;
    Error  := 'Invalid number of command parameters';
  end; // .else
end; // .function SN_H

function SN_T (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
const
  NUM_OBLIG_PARAMS  = 2;
  NUM_DEF_TR_PARAMS = 1;

var
{U} ResPtr:      pchar;
    TrParams:    StrLib.TArrayOfStr;
    Translation: string;
    NumTrParams: integer;
    i:           integer;

begin
  ResPtr := nil;
  result := false;
  // * * * * * //
  if NumParams < NUM_OBLIG_PARAMS then begin
    Error := 'Invalid number of command parameters';
    exit;
  end;

  if not CheckCmdParamsEx(Params, NumParams, [ACTION_SET or TYPE_STR, ACTION_GET or TYPE_STR]) then begin
    Error := 'Valid syntax is !!SN:T^key^/?(str result)/...parameters...';
    exit;
  end;

  // SN:T^key^/?(translation)/...parameters...
  NumTrParams                  := (NumParams - NUM_OBLIG_PARAMS) div 2;
  SetLength(TrParams, (NumTrParams + NUM_DEF_TR_PARAMS) * 2);
  TrParams[high(TrParams) - 1] := '';
  TrParams[high(TrParams)]     := Trans.TEMPL_CHAR;

  for i := NUM_OBLIG_PARAMS to NUM_OBLIG_PARAMS + NumTrParams * 2 - 1 do begin
    if Params[i].OperGet then begin
      Error := 'Arguments for translation must use set syntax';
      exit;
    end;

    if Params[i].IsStr then begin
      TrParams[i - NUM_OBLIG_PARAMS] := Params[i].Value.pc;
    end else begin
      TrParams[i - NUM_OBLIG_PARAMS] := SysUtils.IntToStr(Params[i].Value.v);
    end;
  end;

  Translation := Trans.tr(Params[0].Value.pc, TrParams);
  Params[1].RetStr(Translation);

  result := true;
end; // .function SN_T

function ExtendedEraService (Cmd: char; NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
{U} Slot:              TSlot;
    SlotId:            integer;
    SlotItemInd:       integer;
{U} AssocVarValue:     TAssocVar;
    AssocVarName:      string;
    NewSlotItemsCount: integer;
    GameState:         TGameState;
{U} Tile:              Heroes.PMapTile;
    Coords:            Heroes.TMapCoords;
    MapSize:           integer;

begin
  Slot          := nil;
  AssocVarValue := nil;
  // * * * * * //
  result := true;
  
  case Cmd of  
    'M':
      begin
        case NumParams of
          // M; delete all slots
          0:
            begin
              Slots.Clear;
            end; // .case 0
          // M(Slot); delete specified slot
          1:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET]) and (Params[0].Value.v <> AUTO_ALLOC_SLOT);
              
              if result then begin
                Slots.DeleteItem(Ptr(Params[0].Value.v));
              end;
            end; // .case 1
          // M(Slot)/[?]ItemsCount; analog of SetLength/Length
          2:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT]) and (Params[1].OperGet or (Params[1].Value.v >= 0));

              if result then begin          
                if Params[1].OperGet then begin
                  Slot := Slots[Ptr(Params[0].Value.v)];
                  
                  if Slot <> nil then begin
                    Params[1].RetInt(GetSlotItemsCount(Slot));
                  end else begin
                    Params[1].RetInt(NO_SLOT);
                  end;
                end else begin
                  result := GetSlot(Params[0].Value.v, Slot, Error);
                  
                  if result then begin
                    NewSlotItemsCount := GetSlotItemsCount(Slot);
                    ApplyIntParam(Params[1], NewSlotItemsCount);
                    SetSlotItemsCount(NewSlotItemsCount, Slot);
                  end;
                end; // .else
              end; // .if
            end; // .case 2
          // SN:M(Slot)/(VarN)/[?](Value) or M(Slot)/?addr/(VarN)
          3:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT]) and GetSlot(Params[0].Value.v, Slot, Error);
              
              if result then begin
                if Params[1].OperGet then begin
                  SlotItemInd := Params[2].Value.v;

                  if SlotItemInd < 0 then begin
                    Inc(SlotItemInd, GetSlotItemsCount(Slot));
                  end;

                  result :=
                    (not Params[2].OperGet) and
                    (not Params[2].IsStr)   and
                    Math.InRange(SlotItemInd, 0, GetSlotItemsCount(Slot) - 1);

                  if result then begin
                    if Slot.ItemsType = INT_VAR then begin
                      Params[1].RetInt(integer(@Slot.IntItems[SlotItemInd]));
                    end else begin
                      Params[1].RetInt(integer(pointer(Slot.StrItems[SlotItemInd])));
                    end;
                  end;
                end else begin
                  SlotItemInd := Params[1].Value.v;

                  if SlotItemInd < 0 then begin
                    Inc(SlotItemInd, GetSlotItemsCount(Slot));
                  end;

                  result :=
                    (not Params[1].OperGet) and
                    (not Params[1].IsStr)   and
                    Math.InRange(SlotItemInd, 0, GetSlotItemsCount(Slot) - 1);

                  if result and (Params[2].IsStr <> (Slot.ItemsType = STR_VAR)) then begin
                    Error  := 'Cannot get INTEGER/STRING item into variable of not appropriate type';
                    result := false;
                  end;
                  
                  if result then begin
                    if Params[2].OperGet then begin
                      if Slot.ItemsType = INT_VAR then begin
                        Params[2].RetInt(Slot.IntItems[SlotItemInd]);
                      end else begin
                        Params[2].RetStr(Slot.StrItems[SlotItemInd]);
                      end;
                    end else begin
                      if Slot.ItemsType = INT_VAR then begin
                        ApplyIntParam(Params[2], Slot.IntItems[SlotItemInd]);
                      end else begin
                        AssignStrFromParam(Params[2], Slot.StrItems[SlotItemInd]);
                      end;
                    end; // .else
                  end; // .if
                end; // .else
              end; // .if
            end; // .case 3
          // SN:M#slot/#count/#type/#persistInSaves or -1 for trigger-local array[/?slotID]
          4..5:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET, TYPE_INT or ACTION_GET or PARAM_OPTIONAL]) and
              (Params[0].Value.v >= AUTO_ALLOC_SLOT)                  and
              (Params[1].Value.v >= 0)                                and
              Math.InRange(Params[2].Value.v, 0, ord(High(TVarType))) and
              ((Params[3].Value.v = IS_TEMP) or (Params[3].Value.v = NOT_TEMP) or ((Params[3].Value.v = IS_TRIGGER_LOCAL) and (Params[0].Value.v = AUTO_ALLOC_SLOT)));
              
              if result then begin
                SlotId := Params[0].Value.v;

                if SlotId = AUTO_ALLOC_SLOT then begin
                  SlotId   := AllocSlot(Params[1].Value.v, TVarType(Params[2].Value.v), Params[3].Value.v <> NOT_TEMP);
                  Erm.v[1] := SlotId;
                end else begin
                  Slots[Ptr(SlotId)] := NewSlot(Params[1].Value.v, TVarType(Params[2].Value.v), Params[3].Value.v <> NOT_TEMP);
                end;

                if NumParams >= 5 then begin
                  Params[4].RetInt(SlotId);
                end;

                if Params[3].Value.v = IS_TRIGGER_LOCAL then begin
                  Erm.RegisterTriggerLocalObject(TSlotReleaser.Create(Erm.v[1]));
                end;
              end; // .if
            end; // .case 4..5
        else
          result := false;
          Error  := 'Invalid number of command parameters';
        end; // .switch NumParams
      end; // .case "M"  
    'K':
      begin
        case NumParams of 
          // K(str)/?(len) Get string length
          2:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET, ACTION_GET or TYPE_INT]);
              
              if result then begin
                Params[1].RetInt(Windows.LStrLen(Params[0].Value.pc));
              end;
            end; // .case 2
          // K(str)/(ind)/[?](strchar) Get/set string character at position
          3:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET, ACTION_SET or TYPE_INT, TYPE_STR]) and (Params[1].Value.v >= 0);
             
              if result then begin
                if Params[2].OperGet then begin
                  Params[2].RetPchar(pchar(Utils.PtrOfs(Params[0].Value.p, Params[1].Value.v)), 1);
                end else begin
                  PEndlessCharArr(Params[0].Value.v)[Params[1].Value.v] := pchar(Params[2].Value.v)^;
                end;
              end;
            end; // .case 3
          // SN:K#count/#from/#to/#dummy Copy memory
          4:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET or TYPE_INT, ACTION_SET, ACTION_SET]) and (Params[0].Value.v >= 0);
              
              if result and (Params[0].Value.v > 0) then begin
                Utils.CopyMem(Params[0].Value.v, Params[1].Value.p, Params[2].Value.p);
              end;
            end; // .case 4
        else
          result := false;
          Error  := 'Invalid number of command parameters';
        end; // .switch NumParams
      end; // .case "K"
    'W':
      begin
        case NumParams of 
          // Clear all
          0: AssocMem.Clear;
          
          // SN:W#var Delete var
          1:
            begin
              result := not Params[0].OperGet;
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName := Params[0].Value.pc;
                end else begin
                  AssocVarName := SysUtils.IntToStr(Params[0].Value.v);
                end;
                
                AssocMem.DeleteItem(AssocVarName);
              end;
            end; // .case 1
          // SN:W#var/$value Get/set var
          2:
            begin
              result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET, ACTION_ANY or TYPE_ANY]);
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName := Params[0].Value.pc;
                end else begin
                  AssocVarName := SysUtils.IntToStr(Params[0].Value.v);
                end;
                
                AssocVarValue := AssocMem[AssocVarName];
                
                if Params[1].OperGet then begin
                  if Params[1].IsStr then begin
                    if (AssocVarValue = nil) or (AssocVarValue.StrValue = '') then begin
                      Params[1].RetStr('');
                    end else begin
                      Params[1].RetStr(AssocVarValue.StrValue);
                    end;
                  end else begin
                    if AssocVarValue = nil then begin
                      Params[1].RetInt(0);
                    end else begin
                      Params[1].RetInt(AssocVarValue.IntValue);
                    end;
                  end; // .else
                end else begin
                  if AssocVarValue = nil then begin
                    AssocVarValue          := TAssocVar.Create;
                    AssocMem[AssocVarName] := AssocVarValue;
                  end;
                  
                  if Params[1].IsStr then begin
                    AssignStrFromParam(Params[1], AssocVarValue.StrValue);
                  end else begin
                    ApplyIntParam(Params[1], AssocVarValue.IntValue);
                  end;
                end; // .else
              end; // .if
            end; // .case 2
        else
          result := false;
          Error  := 'Invalid number of command parameters';
        end; // .switch
      end; // .case "W"
    'D':
      begin
        GetGameState(GameState);
        
        if GameState.CurrentDlgId = Heroes.ADVMAP_DLGID then begin
          Erm.ExecErmCmd('UN:R1;');
        end else if GameState.CurrentDlgId = Heroes.TOWN_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R4;');
        end else if GameState.CurrentDlgId = Heroes.HERO_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R3/-1;');
        end else if GameState.CurrentDlgId = Heroes.HERO_MEETING_SCREEN_DLGID then begin
          Heroes.RedrawHeroMeetingScreen;
        end else if GameState.CurrentDlgId = Heroes.BATTLE_DLGID then begin
          Erm.ExecErmCmd('BU:R;');
        end;
      end; // .case "D"
    'O':
      begin
        // O?$/?$/?$
        if NumParams = 3 then begin
          result := CheckCmdParamsEx(Params, NumParams, [ACTION_GET or TYPE_INT, ACTION_GET or TYPE_INT, ACTION_GET or TYPE_INT]);

          if result then begin
            Coords[0] := Params[0].Value.pi^;
            Coords[1] := Params[1].Value.pi^;
            Coords[2] := Params[2].Value.pi^;
            MapSize   := GameManagerPtr^.MapSize;

            if (Coords[0] < 0) or (Coords[0] >= MapSize) or (Coords[1] < 0) or
               (Coords[1] >= MapSize) or (Coords[2] < 0) or (Coords[2] > 1) or
               ((Coords[2] = 1) and not GameManagerPtr^.IsTwoLevelMap)
            then begin
              result := false;
              Error  := Format('Invalid coordinates: %d %d %d', [Coords[0], Coords[1], Coords[2]]);
            end else begin
              Tile := @GameManagerPtr^.MapTiles[(Coords[2] * MapSize + Coords[1]) * MapSize + Coords[0]];
              Tile := Heroes.GetObjectEntranceTile(Tile);
              Heroes.MapTileToCoords(Tile, Coords);
              Params[0].RetInt(Coords[0]);
              Params[1].RetInt(Coords[1]);
              Params[2].RetInt(Coords[2]);
            end; // .else
          end; // .if
        end else begin
          result := false;
          Error  := 'Invalid number of command parameters';
        end; // .else
      end; // .case "O"
  else
    result := false;
    Error  := 'Unknown command "' + Cmd +'".';
  end; // .switch Cmd
end; // .function ExtendedEraService

function SN_R (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR or ACTION_SET, TYPE_STR or ACTION_SET]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:R^original resource name^/^new resource name^';
  end else begin
    Lodman.RedirectFile(Params[0].Value.pc, Params[1].Value.pc);
  end;
end;

function SN_I (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR or ACTION_SET, TYPE_STR or ACTION_GET]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:Iz#/?z#';
  end else begin
    Erm.SetZVar(Params[1].Value.pc, Erm.ZvsInterpolateStr(Params[0].Value.pc));
  end;
end;

type
  PStdcallFuncArgs = ^TStdcallFuncArgs;
  TStdcallFuncArgs = array [0..High(TServiceParams)] of integer;

function CallStdcallFunc (Addr: pointer; Args: PStdcallFuncArgs; NumArgs: integer): integer; assembler; stdcall;
asm
  mov ecx, NumArgs
  mov edx, Args
  mov eax, NumArgs
  lea edx, [edx + eax * 4]
@push_params:
  test ecx, ecx
  jz @push_params_end
  sub edx, 4
  push [edx]
  dec ecx
  jmp @push_params
@push_params_end:
  mov eax, Addr
  call eax
end;

function SN_F (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
    ApiName: string;
{n} ApiFunc: pointer;
    ApiArgs: TStdcallFuncArgs;
    i:       integer;

begin
  // SN:F#funcName/#params...
  result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET or TYPE_STR]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:F^API function name^/possible parameters...';
  end else begin
    ApiName := Params[0].Value.pc;
    ApiFunc := GetCombinedApiAddr(ApiName);
    result  := ApiFunc <> nil;

    if not result then begin
      Error := 'Unknown Era/Kernel32 API function: "' + ApiName + '"';
    end else begin
      for i := 1 to NumParams do begin
        ApiArgs[i - 1] := Params[i].Value.v;
      end;
      
      Erm.v[1] := CallStdcallFunc(ApiFunc, @ApiArgs, NumParams - 1);
    end;
  end; // .else
end; // .function SN_F

function SN_P (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
  FileName: pchar;

begin
  result := CheckCmdParamsEx(Params, NumParams, [ACTION_SET]);

  if result then begin
    if Params[0].IsStr then begin
      FileName := Params[0].Value.pc;
    end else if Math.InRange(Params[0].Value.v, 1, 1000) then begin
      FileName := @Erm.z[Params[0].Value.v];
    end else begin
      FileName := Erm.ZvsGetErtStr(Params[0].Value.v);
    end;

    Heroes.PlaySound(FileName);
  end;
end;

function SN_S (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR]);

  if result then begin
    result := CurrentSoundNameBuf <> nil;

    if not result then begin
      Error := 'Cannot use SN:S outside of SN trigger';
    end else if Params[0].OperGet then begin
      Params[0].RetPchar(pchar(CurrentSoundNameBuf));
    end else begin
      AssignPcharFromParam(Params[0], pchar(CurrentSoundNameBuf), sizeof(CurrentSoundNameBuf^));
    end;
  end;
end;

function SN_E (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET]) and (Params[0].Value.v <> 0) and
            Alg.InRange(Params[1].Value.v, ERA_CALLCONV_PASCAL, ERA_CALLCONV_FASTCALL + ERA_CALLCONV_FLOAT_RES);

  if result then begin
    CallProc(Params[0].Value.v, Params[1].Value.v, @Params[2].Value.v, NumParams - 2);
  end;
end;

function SN_L (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR or ACTION_SET, TYPE_INT or ACTION_GET]);

  if result then begin
    Params[1].RetInt(Windows.LoadLibraryA(Params[0].Value.pc));
  end;
end;

function SN_A (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_STR or ACTION_SET, TYPE_INT or ACTION_GET]) and (Params[0].Value.v <> 0);

  if result then begin
    Params[2].RetInt(integer(Windows.GetProcAddress(Windows.THandle(Params[0].Value.v), Params[1].Value.pc)));
  end;
end;

function SN_X (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
  i: integer;

begin
  result := NumParams <= High(Erm.x^);

  if result then begin
    for i := 0 to NumParams - 1 do begin
      if Params[i].OperGet then begin
        if Params[i].IsStr then begin
          Params[i].RetPchar(pchar(Erm.x[i + 1]));
        end else begin
          Params[i].RetInt(Erm.x[i + 1]);
        end;
      end else begin
        if Params[i].IsStr then begin
          Erm.x[i + 1] := Params[i].Value.v;
        end else begin
          ApplyIntParam(Params[i], Erm.x[i + 1]);
        end;
      end; // .else
    end; // .for
  end; // .if
end; // .function SN_X

function SN_V (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
const
  FIRST_ITEM_PARAM_IND = 2;

var
{U} Slot:       TSlot;
    SlotLength: integer;
    StartInd:   integer;
    ItemInd:    integer;
    i:          integer;

begin
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET]);

  if not result then begin
    exit;
  end;

  result := GetSlot(Params[0].Value.v, Slot, Error);

  if not result then begin
    Error := 'Failed to find SN:M array with ID ' + SysUtils.IntToStr(Params[0].Value.v);
    exit;
  end;

  StartInd   := Params[1].Value.v;
  SlotLength := GetSlotItemsCount(Slot);

  if not Math.InRange(StartInd, 0, SlotLength - 1) then begin
    Error  := Format('Invalid starting dynamical array index: %d for array with ID %d and length %d', [StartInd, Params[0].Value.v, SlotLength]);
    result := false; exit;
  end;
  
  if result then begin
    for i := FIRST_ITEM_PARAM_IND to NumParams - 1 do begin
      ItemInd := StartInd + i - FIRST_ITEM_PARAM_IND;

      if ItemInd >= SlotLength then begin
        Error  := Format('Index %d is out of bounds for dynamical array with ID %d and length %d', [ItemInd, Params[0].Value.v, SlotLength]);
        result := false; exit;
      end;

      if (Params[i].IsStr <> (Slot.ItemsType = STR_VAR)) then begin
        Error  := 'Cannot get INTEGER/STRING item into variable of not appropriate type';
        result := false; exit;
      end;
      
      if Params[i].OperGet then begin
        if Slot.ItemsType = INT_VAR then begin
          Params[i].RetInt(Slot.IntItems[ItemInd]);
        end else begin
          Params[i].RetStr(Slot.StrItems[ItemInd]);
        end;
      end else begin
        if Slot.ItemsType = INT_VAR then begin
          ApplyIntParam(Params[i], Slot.IntItems[ItemInd]);
        end else begin
          AssignStrFromParam(Params[i], Slot.StrItems[ItemInd]);
        end;
      end; // .else
    end; // .for
  end; // .if
end; // .function SN_V

function SN_Receiver (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: Erm.PErmSubCmd): integer; cdecl;
var
  CmdWrapper: TErmCmdWrapper;

begin
  with WrapErmCmd('SN', SubCmd, CmdWrapper)^ do begin
    while FindNextSubcmd(['P', 'S', 'G', 'Q', 'L', 'A', 'E', 'D', 'H', 'T', 'I', 'F', 'X', 'M', 'K', 'W', 'D', 'O', 'R', 'V']) do begin
      case Cmd of
        'G': begin
          Success := (Erm.CurrentTriggerCmdIndPtr <> nil) and (NumParams = 1) and not Params[0].OperGet and not Params[0].IsStr and (Params[0].Value.v >= 0) and (Params[0].Value.v < High(integer));

          if Success then begin
            Erm.CurrentTriggerCmdIndPtr^ := Params[0].Value.v - 1;
          end;
        end;

        'Q': begin
          Erm.QuitTriggerFlag := true;
        end;
        
        'X': begin Success := SN_X(NumParams, @Params, Error); end;
        'L': begin Success := SN_L(NumParams, @Params, Error); end;
        'A': begin Success := SN_A(NumParams, @Params, Error); end;
        'E': begin Success := SN_E(NumParams, @Params, Error); end;
        'P': begin Success := SN_P(NumParams, @Params, Error); end;
        'S': begin Success := SN_S(NumParams, @Params, Error); end;
        'H': begin Success := SN_H(NumParams, @Params, Error); end;
        'T': begin Success := SN_T(NumParams, @Params, Error); end;
        'I': begin Success := SN_I(NumParams, @Params, Error); end;
        'R': begin Success := SN_R(NumParams, @Params, Error); end;
        'F': begin Success := SN_F(NumParams, @Params, Error); end;
        'V': begin Success := SN_V(NumParams, @Params, Error); end;
        
        'M', 'K', 'W', 'D', 'O': begin
          Success := ExtendedEraService(Cmd, NumParams, @Params, Error);
        end;
      end;
    end;

    result := GetCmdResult;
    Cleanup;
  end;
end; // .function SN_Receiver

procedure ResetMemory;
begin
  Slots.Clear;
  AssocMem.Clear;
end;

procedure ResetHints;
begin
  with DataLib.IterateDict(Hints) do begin
    while IterNext do begin
      TObjDict(IterValue).Clear;
    end;
  end;
end;

procedure SaveSlots;
var
{U} Slot:     TSlot;
    NumItems: integer;
    i:        integer;
  
begin
  Slot := nil;
  // * * * * * //
  with Stores.NewRider(SLOTS_SAVE_SECTION) do begin
    WriteInt(Slots.ItemCount);

    with DataLib.IterateObjDict(Slots) do begin
      while IterNext do begin
        Slot     := TSlot(IterValue);
        NumItems := GetSlotItemsCount(Slot);
        WriteInt(integer(IterKey));
        WriteByte(ord(Slot.ItemsType));
        WriteByte(ord(Slot.IsTemp));
        WriteInt(NumItems);
        
        if (NumItems > 0) and not Slot.IsTemp then begin
          if Slot.ItemsType = INT_VAR then begin
            Write(NumItems * sizeof(integer), @Slot.IntItems[0])
          end else begin
            for i := 0 to NumItems - 1 do begin
              WriteStr(Slot.StrItems[i]);
            end;
          end;
        end;
      end; // .while
    end; // .with
  end; // .with
end; // .procedure SaveSlots

procedure SaveAssocMem;
var
{U} AssocVarValue: TAssocVar;
    AssocVarName:  string;
  
begin
  AssocVarValue := nil;
  // * * * * * //
  with Stores.NewRider(ASSOC_SAVE_SECTION) do begin
    WriteInt(AssocMem.ItemCount);

    AssocMem.BeginIterate;

    while AssocMem.IterateNext(AssocVarName, pointer(AssocVarValue)) do begin
      WriteStr(AssocVarName);
      WriteInt(AssocVarValue.IntValue);
      WriteStr(AssocVarValue.StrValue);
      AssocVarValue := nil;
    end;

    AssocMem.EndIterate;
  end; // .with
end; // .procedure SaveAssocMem

procedure SaveHints;
var
{U} HintSection: TObjDict;

begin
  HintSection := nil;
  // * * * * * //
  with Stores.NewRider(HINTS_SAVE_SECTION) do begin
    // Write number of hint sections
    WriteInt(Hints.ItemCount);
    
    // Process each hint section in a loop
    with DataLib.IterateDict(Hints) do begin
      while IterNext do begin
        // Write hint section name and records count and get hint section object
        WriteStr(IterKey);
        HintSection := TObjDict(IterValue);
        WriteInt(HintSection.ItemCount);

        // Process hint section records
        with DataLib.IterateObjDict(HintSection) do begin
          while IterNext do begin
            // Write item code and hint string
            WriteInt(integer(IterKey));
            WriteStr(TString(IterValue).Value);
          end;
        end;
      end; // .while
    end; // .with
  end; // .with
end; // .procedure SaveHints

procedure OnSavegameWrite (Event: PEvent); stdcall;
begin
  SaveSlots;
  SaveAssocMem;
  SaveHints;
end;

procedure LoadSlots;
var
{U} Slot:       TSlot;
    SlotN:      integer;
    ItemsType:  TVarType;
    IsTempSlot: boolean;
    NumItems:   integer;
    i:          integer;
    j:          integer;

begin
  Slot := nil;
  // * * * * * //
  Slots.Clear;

  with Stores.NewRider(SLOTS_SAVE_SECTION) do begin
    for i := 0 to ReadInt - 1 do begin
      SlotN             := ReadInt;
      ItemsType         := TVarType(ReadByte);
      IsTempSlot        := ReadByte <> 0;
      NumItems          := ReadInt;
      Slot              := NewSlot(NumItems, ItemsType, IsTempSlot);
      Slots[Ptr(SlotN)] := Slot;

      if not IsTempSlot and (NumItems > 0) then begin
        if ItemsType = INT_VAR then begin
          Read(NumItems * sizeof(integer), @Slot.IntItems[0]);
        end else begin
          for j := 0 to NumItems - 1 do begin
            Slot.StrItems[j] := ReadStr;
          end;
        end;
      end;
    end; // .for
  end; // .with
end; // .procedure LoadSlots

procedure LoadAssocMem;
var
{O} AssocVarValue: TAssocVar;
    AssocVarName:  string;
    i:             integer;
  
begin
  AssocVarValue := nil;
  // * * * * * //
  AssocMem.Clear;

  with Stores.NewRider(ASSOC_SAVE_SECTION) do begin
    for i := 0 to ReadInt - 1 do begin
      AssocVarValue          := TAssocVar.Create;
      AssocVarName           := ReadStr;
      AssocVarValue.IntValue := ReadInt;
      AssocVarValue.StrValue := ReadStr;    

      if (AssocVarValue.IntValue <> 0) or (AssocVarValue.StrValue <> '') then begin
        AssocMem[AssocVarName] := AssocVarValue; AssocVarValue := nil;
      end else begin
        SysUtils.FreeAndNil(AssocVarValue);
      end;
    end; // .for
  end;  
end; // .procedure LoadAssocMem

procedure LoadHints;
var
{U} HintSection:     TObjDict;
    NumHintSections: integer;
    ItemCode:        integer;
    i, k:            integer;

{U} Name:     pchar;
    Hero:     integer;
    Skill:    integer;
    Monster:  integer absolute Skill;
    Art:      integer absolute Skill;
    NameType: integer;

begin
  HintSection := nil;
  Name        := nil;
  // * * * * * //
  ResetHints;
  
  with Stores.NewRider(HINTS_SAVE_SECTION) do begin
    // Read number of hint sections
    NumHintSections := ReadInt;

    // Read each hint section in a loop
    for i := 0 to NumHintSections - 1 do begin
      // Read hint section name and create hint section object
      HintSection    := DataLib.NewObjDict(Utils.OWNS_ITEMS);
      Hints[ReadStr] := HintSection;

      // Read hint section records
      for k := 0 to ReadInt - 1 do begin
        // Read item code and hint string
        ItemCode                   := ReadInt;
        HintSection[Ptr(ItemCode)] := TString.Create(ReadStr);
      end;
    end; // .for
  end; // .with

  (* Apply hero specialties hints *)
  HintSection := TObjDict(Hints['spec']);

  if HintSection <> nil then begin
    with DataLib.IterateObjDict(HintSection) do begin
      while IterNext do begin
        Hero                                                := integer(IterKey) and $FF;
        NameType                                            := integer(IterKey) shr 8;
        Erm.HeroSpecsTable[Hero].Descr[NameType]            := pchar(TString(IterValue).Value);
        Erm.HeroSpecSettingsTable[Hero].ZVarDescr[NameType] := 0;
      end;
    end;
  end;

  (* Apply secondary skill texts *)
  HintSection := TObjDict(Hints['secskill']);

  if HintSection <> nil then begin
    with DataLib.IterateObjDict(HintSection) do begin
      while IterNext do begin
        Skill    := integer(IterKey) and $FF;
        NameType := integer(IterKey) shr 8;
        Name     := pchar(TString(IterValue).Value);

        Erm.SecSkillSettingsTable[Skill].Texts[NameType] := 0;
        Heroes.SecSkillTexts[Skill].Texts[NameType]      := Name;

        if NameType = Heroes.SKILL_LEVEL_NONE then begin
          Heroes.SecSkillNames[Skill] := Name;
        end else begin
          Heroes.SecSkillDescs[Skill].Descs[NameType - 1] := Name;
        end;
      end; // .while
    end; // .with
  end; // .if

  (* Apply monster texts *)
  HintSection := TObjDict(Hints['monname']);

  if HintSection <> nil then begin
    with DataLib.IterateObjDict(HintSection) do begin
      while IterNext do begin
        Monster  := integer(IterKey) and $FFFF;
        NameType := integer(IterKey) shr 16;
        Name     := pchar(TString(IterValue).Value);

        Erm.MonNamesSettingsTable[Monster].Texts[NameType] := 0;
        Heroes.MonInfos[Monster].Names.Texts[NameType]     := Name;
        Erm.MonNamesTables[NameType][Monster]              := Name;
      end; // .while
    end; // .with
  end; // .if

  (* Apply artifacts texts *)
  HintSection := TObjDict(Hints['art']);

  if HintSection <> nil then begin
    with DataLib.IterateObjDict(HintSection) do begin
      while IterNext do begin
        Art      := integer(IterKey) and $FFFF;
        NameType := integer(IterKey) shr 16;
        Name     := pchar(TString(IterValue).Value);

        Erm.ArtNamesSettingsTable[Art].Texts[NameType] := 0;
        Heroes.ArtInfos[Art].GetTextField(NameType).pc := Name;
      end; // .while
    end; // .with
  end; // .if
end; // .procedure LoadHints

procedure OnSavegameRead (Event: PEvent); stdcall;
begin
  LoadSlots;
  LoadAssocMem;
  LoadHints;
end;

function Hook_PlaySound (OrigFunc: pointer; SoundName: pchar; Arg2, Arg3: integer): integer; stdcall;
var
  Buf:              TSoundNameBuffer;
  PrevSoundNameBuf: PSoundNameBuffer;

begin
  PrevSoundNameBuf := CurrentSoundNameBuf;
  // * * * * * //
  Utils.SetPcharValue(@Buf, SoundName, sizeof(Buf));
  CurrentSoundNameBuf := @Buf;
  Erm.FireErmEvent(Erm.TRIGGER_SN);
  result              := PatchApi.Call(FASTCALL_, OrigFunc, [Utils.IfThen(Buf[0] <> #0, @Buf, nil), Arg2, Arg3]);
  CurrentSoundNameBuf := PrevSoundNameBuf;
end;

function Hook_ZvsCheckObjHint (C: Core.PHookContext): longbool; stdcall;
const
  HINT_BUF = $697428;

var
{U} HintSection: TObjDict;
{U} StrValue:    TString;
    Code:        integer;
    x, y, z:     integer;
    ObjType:     integer;
    ObjSubtype:  integer;
    OldHint:     array of char;

begin
  HintSection := TObjDict(Hints['object']);
  x           := pinteger(C.EBP - 12)^;
  y           := pinteger(C.EBP - 8)^;
  z           := pinteger(C.EBP - 24)^;
  ObjType     := pword(pinteger(C.EBP + 8)^ + $1E)^;
  ObjSubtype  := pword(pinteger(C.EBP + 8)^ + $22)^;
  Code        := x or (y shl 8) or (z shl 16);
  StrValue    := HintSection[Ptr(Code)];
  
  if StrValue = nil then begin
    Code       := ObjType or (ObjSubtype shl 8) or CODE_TYPE_SUBTYPE;
    StrValue   := HintSection[Ptr(Code)];

    if StrValue = nil then begin
      Code     := ObjType or $FF00 or CODE_TYPE_SUBTYPE;
      StrValue := HintSection[Ptr(Code)];

      if StrValue = nil then begin
        Code     := (ObjSubtype shl 8) or $FF or CODE_TYPE_SUBTYPE;
        StrValue := HintSection[Ptr(Code)];

        if StrValue = nil then begin
          StrValue := HintSection[Ptr($FFFF or CODE_TYPE_SUBTYPE)];
        end;
      end;
    end; // .if
  end; // .if

  if StrValue <> nil then begin
    Utils.SetPcharValue(ppointer(C.EBP + 12)^, StrValue.Value, sizeof(Erm.z[1]));
    C.RetAddr := Ptr($74DFFB);
    result    := not Core.EXEC_DEF_CODE;
  end else begin
    result := Core.EXEC_DEF_CODE;
  end;

  SetLength(OldHint, Windows.LStrLen(pchar(HINT_BUF)) + 1);
  Utils.CopyMem(Length(OldHint), pchar(HINT_BUF), pointer(OldHint));
  Erm.FireErmEventEx(TRIGGER_ADVMAP_TILE_HINT, [x, y, z, ObjType, ObjSubtype]);

  if result and (Windows.LStrCmp(pchar(HINT_BUF), pchar(OldHint)) <> 0) then begin
    C.RetAddr := Ptr($74DFFB);
    result    := not Core.EXEC_DEF_CODE;
  end;
end; // .function Hook_ZvsCheckObjHint

function Hook_InterpolateErmString (Context: ApiJack.PHookContext): longbool; stdcall;
type
  PFrame = ^TFrame;
  TFrame = packed record
    j:      integer; // -28h
    _d1:    array [1..3] of byte;
    c:      char;    // -21h
    _d2:    array [1..16] of byte;
    i:      integer; // -10h
    _d3:    array [1..4] of byte;
    OutStr: pchar;   // -8h
    _d4:    array [1..12] of byte;
    InStr:  pchar;   // +8h
  end;

const
  OFS_INSTR  = +$8;
  OFS_OUTSTR = -$8;
  OFS_I      = -$10;
  OFS_C      = -$21;
  OFS_J      = -$28;

var
  f:             PFrame;
  Caret:         pchar;
  StartPos:      pchar;
  Ident:         string;
  AssocVarValue: TAssocVar;
  Str:           string;
  VarType:       char;

begin
  f       := PFrame(Context.EBP - $28);
  VarType := chr(byte(Context.EAX + $24));
  result  := not (VarType in ['I', 'S', 'T']) or (f.InStr[f.i + 1] <> '(');

  if not result then begin
    Inc(f.i, 2);
    Caret    := @f.InStr[f.i];
    StartPos := Caret;

    while not (Caret^ in [#0, ')']) do begin
      Inc(Caret);
    end;

    Ident := StrLib.ExtractFromPchar(StartPos, Caret - StartPos);
    
    if VarType <> 'T' then begin
      AssocVarValue := AssocMem[Ident];

      if VarType = 'S' then begin
        if (AssocVarValue <> nil) and (AssocVarValue.StrValue <> '') then begin
          Utils.CopyMem(Length(AssocVarValue.StrValue), pchar(AssocVarValue.StrValue), @f.OutStr[f.j]);
          Inc(f.j, Length(AssocVarValue.StrValue) - 1);
        end;
      end else begin
        if (AssocVarValue = nil) or (AssocVarValue.IntValue = 0) then begin
          f.OutStr[f.j] := '0';
        end else begin
          Str := IntToStr(AssocVarValue.IntValue);
          Utils.CopyMem(Length(Str), pchar(Str), @f.OutStr[f.j]);
          Inc(f.j, Length(Str) - 1);
        end;
      end;
    end else begin
      Str := Trans.tr(Ident, []);
      Utils.CopyMem(Length(Str), pchar(Str), @f.OutStr[f.j]);
      Inc(f.j, Length(Str) - 1);
    end; // .else

    Inc(f.i, Caret - StartPos);

    if Caret^ = #0 then begin
      Dec(f.i);
    end;

    Context.RetAddr := Ptr($73DD9F);
  end; // .if
end; // .function Hook_InterpolateErmString

procedure DumpErmMemory (const DumpFilePath: string);
const
  ERM_CONTEXT_LEN = 300;
  
type
  TVarType          = (INT_VAR, FLOAT_VAR, STR_VAR, BOOL_VAR);
  PEndlessErmStrArr = ^TEndlessErmStrArr;
  TEndlessErmStrArr = array [0..MAXLONGINT div sizeof(Erm.TErmZVar) - 1] of TErmZVar;

var
{O} Buf:              StrLib.TStrBuilder;
    PositionLocated:  boolean;
    ErmContextHeader: string;
    ErmContext:       string;
    ScriptName:       string;
    LineN, LinePos:   integer;
    ErmContextStart:  pchar;
    i:                integer;
    
  procedure WriteSectionHeader (const Header: string);
  begin
    if Buf.Size > 0 then begin
      Buf.Append(#13#10);
    end;
    
    Buf.Append('> ' + Header + #13#10);
  end;
  
  procedure Append (const Str: string);
  begin
    Buf.Append(Str);
  end;
  
  procedure LineEnd;
  begin
    Buf.Append(#13#10);
  end;
  
  procedure Line (const Str: string);
  begin
    Buf.Append(Str + #13#10);
  end;
  
  function ErmStrToWinStr (const Str: string): string;
  begin
    result := StringReplace
    (
      StringReplace(Str, #13, '', [rfReplaceAll]), #10, #13#10, [rfReplaceAll]
    );
  end;
  
  procedure DumpVars (const Caption, VarPrefix: string; VarType: TVarType; VarsPtr: pointer;
                      NumVars, StartInd: integer);
  var
    IntArr:        PEndlessIntArr;
    FloatArr:      PEndlessSingleArr;
    StrArr:        PEndlessErmStrArr;
    BoolArr:       PEndlessBoolArr;
    
    RangeStart:    integer;
    StartIntVal:   integer;
    StartFloatVal: single;
    StartStrVal:   string;
    StartBoolVal:  boolean;
    
    i:             integer;
    
    function GetVarName (RangeStart, RangeEnd: integer): string;
    begin
      result := VarPrefix + IntToStr(StartInd + RangeStart);
      
      if RangeEnd - RangeStart > 1 then begin
        result := result + '..' + VarPrefix + IntToStr(StartInd + RangeEnd - 1);
      end;
      
      result := result + ' = ';
    end;
     
  begin
    {!} Assert(VarsPtr <> nil);
    {!} Assert(NumVars >= 0);
    if Caption <> '' then begin
      WriteSectionHeader(Caption); LineEnd;
    end;

    case VarType of 
      INT_VAR:
        begin
          IntArr := VarsPtr;
          i      := 0;
          
          while i < NumVars do begin
            RangeStart  := i;
            StartIntVal := IntArr[i];
            Inc(i);
            
            while (i < NumVars) and (IntArr[i] = StartIntVal) do begin
              Inc(i);
            end;
            
            Line(GetVarName(RangeStart, i) + IntToStr(StartIntVal));
          end; // .while
        end; // .case INT_VAR
      FLOAT_VAR:
        begin
          FloatArr := VarsPtr;
          i        := 0;
          
          while i < NumVars do begin
            RangeStart    := i;
            StartFloatVal := FloatArr[i];
            Inc(i);
            
            while (i < NumVars) and (FloatArr[i] = StartFloatVal) do begin
              Inc(i);
            end;
            
            Line(GetVarName(RangeStart, i) + Format('%0.3f', [StartFloatVal]));
          end; // .while
        end; // .case FLOAT_VAR
      STR_VAR:
        begin
          StrArr := VarsPtr;
          i      := 0;
          
          while i < NumVars do begin
            RangeStart  := i;
            StartStrVal := pchar(@StrArr[i]);
            Inc(i);
            
            while (i < NumVars) and (pchar(@StrArr[i]) = StartStrVal) do begin
              Inc(i);
            end;
            
            Line(GetVarName(RangeStart, i) + '"' + ErmStrToWinStr(StartStrVal) + '"');
          end; // .while
        end; // .case STR_VAR
      BOOL_VAR:
        begin
          BoolArr := VarsPtr;
          i       := 0;
          
          while i < NumVars do begin
            RangeStart   := i;
            StartBoolVal := BoolArr[i];
            Inc(i);
            
            while (i < NumVars) and (BoolArr[i] = StartBoolVal) do begin
              Inc(i);
            end;
            
            Line(GetVarName(RangeStart, i) + IntToStr(byte(StartBoolVal)));
          end; // .while
        end; // .case BOOL_VAR
    else
      {!} Assert(FALSE);
    end; // .SWITCH 
  end; // .procedure DumpVars
  
  procedure DumpAssocVars;
  var
  {O} AssocList: {U} DataLib.TStrList {OF TAssocVar};
  {U} AssocVar:  TAssocVar;
      i:         integer;
  
  begin
    AssocList := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
    AssocVar  := nil;
    // * * * * * //
    WriteSectionHeader('Associative vars'); LineEnd;
  
    with DataLib.IterateDict(AssocMem) do begin
      while IterNext do begin
        AssocList.AddObj(IterKey, IterValue);
      end;
    end; 
    
    AssocList.Sort;
    
    for i := 0 to AssocList.Count - 1 do begin
      AssocVar := AssocList.Values[i];
        
      if (AssocVar.IntValue <> 0) or (AssocVar.StrValue <> '') then begin
        Append(AssocList[i] + ' = ');
        
        if AssocVar.IntValue <> 0 then begin
          Append(IntToStr(AssocVar.IntValue));
          
          if AssocVar.StrValue <> '' then begin
            Append(', ');
          end;
        end;
        
        if AssocVar.StrValue <> '' then begin
          Append('"' + ErmStrToWinStr(AssocVar.StrValue) + '"');
        end;
        
        LineEnd;
      end; // .if
    end; // .for
    // * * * * * //
    SysUtils.FreeAndNil(AssocList);
  end; // .procedure DumpAssocVars;
  
  procedure DumpSlots;
  var
  {O} SlotList:     {U} DataLib.TList {IF SlotInd: POINTER};
  {U} Slot:         TSlot;
      SlotInd:      integer;
      RangeStart:   integer;
      StartIntVal:  integer;
      StartStrVal:  string;
      i, k:         integer;
      
    function GetVarName (RangeStart, RangeEnd: integer): string;
    begin
      result := 'm' + IntToStr(SlotInd) + '[' + IntToStr(RangeStart);
      
      if RangeEnd - RangeStart > 1 then begin
        result := result + '..' + IntToStr(RangeEnd - 1);
      end;
      
      result := result + '] = ';
    end;
     
  begin
    SlotList := DataLib.NewList(not Utils.OWNS_ITEMS);
    // * * * * * //
    WriteSectionHeader('Memory slots (dynamical arrays)');
    
    with DataLib.IterateObjDict(Slots) do begin
      while IterNext do begin
        SlotList.Add(IterKey);
      end;
    end;
    
    SlotList.Sort;
    
    for i := 0 to SlotList.Count - 1 do begin
      SlotInd := integer(SlotList[i]);
      Slot    := Slots[Ptr(SlotInd)];
      LineEnd; Append('; ');

      if Slot.IsTemp then begin
        Append('Temporal array (#');
      end else begin
        Append('Permanent array (#');
      end;
      
      Append(IntToStr(SlotInd) + ') of ');
      
      if Slot.ItemsType = AdvErm.INT_VAR then begin
        Line(IntToStr(Length(Slot.IntItems)) + ' integers');
        k := 0;
        
        while k < Length(Slot.IntItems) do begin
          RangeStart  := k;
          StartIntVal := Slot.IntItems[k];
          Inc(k);
          
          while (k < Length(Slot.IntItems)) and (Slot.IntItems[k] = StartIntVal) do begin
            Inc(k);
          end;
          
          Line(GetVarName(RangeStart, k) + IntToStr(StartIntVal));
        end; // .while
      end else begin
        Line(IntToStr(Length(Slot.StrItems)) + ' strings');
        k := 0;
        
        while k < Length(Slot.StrItems) do begin
          RangeStart  := k;
          StartStrVal := Slot.StrItems[k];
          Inc(k);
          
          while (k < Length(Slot.StrItems)) and (Slot.StrItems[k] = StartStrVal) do begin
            Inc(k);
          end;
          
          Line(GetVarName(RangeStart, k) + '"' + ErmStrToWinStr(StartStrVal) + '"');
        end; // .while
      end; // .else
    end; // .for
    // * * * * * //
    SysUtils.FreeAndNil(SlotList);
  end; // .procedure DumpSlots

begin
  Buf := StrLib.TStrBuilder.Create;
  // * * * * * //
  WriteSectionHeader('ERA version: ' + GameExt.ERA_VERSION_STR);
  
  if ErmErrCmdPtr^ <> nil then begin
    ErmContextHeader := 'ERM context';
    PositionLocated  := Erm.AddrToScriptNameAndLine(Erm.ErmErrCmdPtr^, ScriptName, LineN, LinePos);
    
    if PositionLocated then begin
      ErmContextHeader := ErmContextHeader + ' in ' + ScriptName + ':' + IntToStr(LineN) + ':' + IntToStr(LinePos);
    end;
    
    WriteSectionHeader(ErmContextHeader); LineEnd;

    try
      ErmContextStart := Erm.FindErmCmdBeginning(Erm.ErmErrCmdPtr^);
      ErmContext      := StrLib.ExtractFromPchar(ErmContextStart, ERM_CONTEXT_LEN) + '...';

      if StrLib.IsBinaryStr(ErmContext) then begin
        ErmContext := '';
      end;
    except
      ErmContext := '';
    end;

    Line(ErmContext);
  end; // .if
  
  WriteSectionHeader('Quick vars (f..t)'); LineEnd;
  
  for i := Low(Erm.QuickVars^) to High(Erm.QuickVars^) do begin
    Line(CHR(ORD('f') + i - Low(Erm.QuickVars^)) + ' = ' + IntToStr(Erm.QuickVars[i]));
  end;
  
  DumpVars('Vars x1..x16', 'x', INT_VAR, @Erm.x[1], 16, 1);
  DumpVars('Vars y1..y100', 'y', INT_VAR, @Erm.y[1], 100, 1);
  DumpVars('Vars y-1..y-100', 'y-', INT_VAR, @Erm.ny[1], 100, 1);
  DumpVars('Vars z-1..z-10', 'z-', STR_VAR, @Erm.nz[1], 10, 1);
  DumpVars('Vars e1..e100', 'e', FLOAT_VAR, @Erm.e[1], 100, 1);
  DumpVars('Vars e-1..e-100', 'e-', FLOAT_VAR, @Erm.ne[1], 100, 1);
  DumpAssocVars;
  DumpSlots;
  DumpVars('Vars f1..f1000', 'f', BOOL_VAR, @Erm.f[1], 1000, 1);
  DumpVars('Vars v1..v10000', 'v', INT_VAR, @Erm.v[1], 10000, 1);
  WriteSectionHeader('Hero vars w1..w200');
  
  for i := 0 to High(Erm.w^) do begin
    LineEnd;
    Line('; Hero #' + IntToStr(i));
    DumpVars('', 'w', INT_VAR, @Erm.w[i, 1], 200, 1);
  end;
  
  DumpVars('Vars z1..z1000', 'z', STR_VAR, @Erm.z[1], 1000, 1);  
  Files.WriteFileContents(Buf.BuildStr, DumpFilePath);
  // * * * * * //
  SysUtils.FreeAndNil(Buf);
end; // .procedure DumpErmMemory

function Hook_DumpErmVars (Context: Core.PHookContext): LONGBOOL; stdcall;
begin
  DumpErmMemory(ERM_MEMORY_DUMP_FILE);
  Context.RetAddr := Core.Ret(0);
  result          := not Core.EXEC_DEF_CODE;
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  DumpErmMemory(ERM_MEMORY_DUMP_FILE);
end;

function New_ZvsSaveMP3 (OrigFunc: pointer): integer; stdcall;
begin
  Heroes.GzipWrite(4, pchar('-MP3'));
  result := 0;
end;

function New_ZvsLoadMP3 (OrigFunc: pointer): integer; stdcall;
var
  Header: array [0..3] of char;
  Buf:    array of byte;

begin
  Heroes.GzipRead(sizeof(Header), @Header);

  // Emulate original WoG Mp3 data loading
  if Header = 'LMP3' then begin
    SetLength(Buf, 200 * 256);
    Heroes.GzipRead(Length(Buf), pointer(Buf));
  end;

  result := 0;
end;

function MP_P (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams >= 2) and (NumParams <= 3);

  if result then begin
    // MP:P^track name^/[DontTrackPosition = 0 or 1]/[Loop = 0 or 1];
    if NumParams = 3 then begin
      result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR or ACTION_SET, TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET]);

      if result then begin
        Heroes.ChangeMp3Theme(Params[0].Value.pc, Params[1].Value.v <> 0, Params[2].Value.v <> 0);
      end;
    end
    // MP:P0/[pause = 0, resume = 1]
    else begin
      result := CheckCmdParamsEx(Params, NumParams, [TYPE_INT or ACTION_SET, TYPE_INT or ACTION_SET]) and Math.InRange(Params[1].Value.v, 0, 1);

      if result then begin
        if Params[1].Value.v = 0 then begin
          Heroes.PauseMp3Theme;
        end else begin
          Heroes.ResumeMp3Theme;
        end;
      end;
    end;
  end; // .if
end; // .function MP_P

function MP_C (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams = 1) and CheckCmdParamsEx(Params, NumParams, [ACTION_GET or TYPE_STR]);

  if result then begin
    Params[0].RetStr(CurrentMp3Track);
  end;
end;

function MP_S (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  // MP:S$trackName/$dontTrackPosition/$loop
  result := CheckCmdParamsEx(Params, NumParams, [TYPE_STR, TYPE_INT or PARAM_OPTIONAL, TYPE_INT or PARAM_OPTIONAL]);

  if result then begin
    // TrackName
    if Params[0].OperGet then begin
      Params[0].RetStr(Mp3TriggerContext.TrackName);
    end else begin
      Mp3TriggerContext.TrackName := Utils.GetPcharValue(Params[0].Value.pc, sizeof(Heroes.TCurrentMp3Track) - 1);
    end;

    // DontTrackPosition
    if NumParams >= 2 then begin
      ApplyIntParam(Params[1], Mp3TriggerContext.DontTrackPosition);
      Mp3TriggerContext.DontTrackPosition := ord(Mp3TriggerContext.DontTrackPosition <> 0);
    end;

    // Loop
    if NumParams >= 3 then begin
      ApplyIntParam(Params[2], Mp3TriggerContext.Loop);
      Mp3TriggerContext.Loop := ord(Mp3TriggerContext.Loop <> 0);
    end;
  end; // .if
end; // .function MP_S

function MP_R (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams = 1) and not Params[0].IsStr;

  if result then begin
    ApplyIntParam(Params[0], Mp3TriggerContext.DefaultReaction);
    Mp3TriggerContext.DefaultReaction := ord(Mp3TriggerContext.DefaultReaction <> 0);
  end;
end;

function New_Mp3_Receiver (Cmd: char; NumParams: integer; ErmCmd: PErmCmd; SubCmd: Erm.PErmSubCmd): integer; cdecl;
var
  CmdWrapper: TErmCmdWrapper;

begin
  with WrapErmCmd('MP', SubCmd, CmdWrapper)^ do begin
    while FindNextSubcmd(['P', 'C', 'S', 'R']) do begin
      case Cmd of
        'P': begin Success := MP_P(NumParams, @Params, Error); end;
        'C': begin Success := MP_C(NumParams, @Params, Error); end;
        'S': begin Success := MP_S(NumParams, @Params, Error); end;
        'R': begin Success := MP_R(NumParams, @Params, Error); end;
      end;
    end;

    result := GetCmdResult;
    Cleanup;
  end;
end;

function New_Mp3_Trigger (OrigFunc: pointer; Self: pointer; TrackName: pchar; DontTrackPosition, Loop: integer): integer; stdcall;
var
  GameState:           Heroes.TGameState;
  TriggerContext:      TMp3TriggerContext;
  PrevTriggerContext:  PMp3TriggerContext;
  RedirectedTrackName: string;

begin
  TriggerContext.TrackName         := SysUtils.AnsiLowerCase(Utils.GetPcharValue(TrackName, sizeof(Heroes.TCurrentMp3Track) - 1));
  TriggerContext.DontTrackPosition := DontTrackPosition;
  TriggerContext.Loop              := Loop;
  TriggerContext.DefaultReaction   := 1;
  PrevTriggerContext               := Mp3TriggerContext;
  Mp3TriggerContext                := @TriggerContext;

  Heroes.GetGameState(GameState);

  if GameState.RootDlgId = Heroes.ADVMAP_DLGID then begin
    Erm.FireErmEvent(Erm.TRIGGER_MP);
  end;

  if TriggerContext.DefaultReaction <> 0 then begin
    CurrentMp3Track     := TriggerContext.TrackName;
    RedirectedTrackName := CurrentMp3Track;

    if Lodman.FindRedirection(TriggerContext.TrackName + '.mp3', RedirectedTrackName) then begin
      RedirectedTrackName := SysUtils.ChangeFileExt(RedirectedTrackName, '');
    end;

    result := PatchApi.Call(THISCALL_, OrigFunc, [Self, pchar(RedirectedTrackName), TriggerContext.DontTrackPosition, TriggerContext.Loop]);
  end else begin
    result := 0;
  end;
  
  Mp3TriggerContext := PrevTriggerContext;
end; // .function New_Mp3_Trigger

procedure RegisterCommands;
begin
  RegisterErmReceiver('SN', @SN_Receiver, CMD_PARAMS_CONFIG_NONE);
  RegisterErmReceiver('MP', @New_Mp3_Receiver, CMD_PARAMS_CONFIG_NONE);
end;

procedure OnBeforeWoG (Event: PEvent); stdcall;
begin
  (* Custom ERM memory dump *)
  Core.ApiHook(@Hook_DumpErmVars, Core.HOOKTYPE_BRIDGE, @Erm.ZvsDumpErmVars);

  (* ERM direct call by hanlder instead of cmd linear scan implementation *)
  // Allocate additional local variable for FindErm. CmdHandler: TErmCmdHandler; absolute (EBP - $6C8)
  Core.p.WriteDataPatch(Ptr($74995A), ['%d', $6C4 + 4]);

  // ParSet := 0  =>  CmdHandler := nil
  Core.p.WriteDataPatch(Ptr($74B69D), ['%d', -$6C8]);
  
  // LogERMAnyReceiver => CmdHandler := ErmAdditions[i].Handler
  Core.p.WriteDataPatch(Ptr($74C1A5), ['8B8DCCFCFFFF6BC90A8B817E8D7900898538F9FFFF9090909090909090909090909090909090909090909090909090909090909090909090909090']);
  
  // ZeroMem (Cmd.Params[ParSet..14]); Cmd.Params[15] := CmdHandler
  Core.p.WriteDataPatch(Ptr($74C3A6), ['B80F0000002B859CFCFFFF6BC0086A00508B8D9CFCFFFF8B95C8FCFFFF8D84CA08020000508D82800200008B8D38F9FFFF8908E8454BFCFF83C40C90']);
  
  // Use direct handler address from Cmd.Params[15] instead of linear scanning
  Core.p.WriteDataPatch(Ptr($7493A3), ['8B4D088B898002000085C90F84310300008D8500FDFFFF508B4508508B45F0508A85E3FCFFFF50FFD183C41085C00F8498000000EB6290909090909090' +
                                       '90909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090']);

  (* Relocate ERM_Additions list *)
  Utils.CopyMem(NumAdditionalCmds * sizeof(TErmAdditionalCmd), Ptr($798AD8), @AdditionalCmds);
  AdditionalCmds[NumAdditionalCmds].Id.Id := 0;
  GameExt.RedirectMemoryBlock(Ptr($798AD8), (NumAdditionalCmds + 1) * sizeof(TErmAdditionalCmd), @AdditionalCmds);
  // [OFF] Core.p.WriteDataPatch(Ptr($7493C7 + 3), ['%d', @AdditionalCmds]); Overwritten by patch
  // [OFF] Core.p.WriteDataPatch(Ptr($7493DD + 3), ['%d', @AdditionalCmds]); Overwritten by patch
  Core.p.WriteDataPatch(Ptr($74BC8E + 3), ['%d', @AdditionalCmds]);
  Core.p.WriteDataPatch(Ptr($74BCA4 + 3), ['%d', @AdditionalCmds]);
  // [OFF] Core.p.WriteDataPatch(Ptr($749410 + 2), ['%d', @@AdditionalCmds[0].Handler]); Overwritten by patch
  // [OFF] Core.p.WriteDataPatch(Ptr($749410 + 2), ['%d', @@AdditionalCmds[0].Handler]); Overwritten by patch
  Core.p.WriteDataPatch(Ptr($74BCE9 + 2), ['%d', @AdditionalCmds[0].ParamsConfig]);
  Core.p.WriteDataPatch(Ptr($74C1AE + 2), ['%d', @@AdditionalCmds[0].Handler]); // Patched command

  (* Register/overwrite ERM receivers *)
  RegisterCommands;
end;

procedure OnAfterWoG (Event: PEvent); stdcall;
begin
  (* SN:H for adventure map object hints *)
  Core.ApiHook(@Hook_ZvsCheckObjHint, Core.HOOKTYPE_BRIDGE, Ptr($74DE9D));

  (* ERM MP3 trigger/receivers remade *)
  // Make WoG ResetMP3, SaveMP3, LoadMP3 doing nothing
  Core.p.WriteDataPatch(Ptr($7746E0), ['31C0C3']);
  ApiJack.StdSplice(Ptr($774756), @New_ZvsSaveMP3, CONV_CDECL, 0);
  ApiJack.StdSplice(Ptr($7747E7), @New_ZvsLoadMP3, CONV_CDECL, 0);

  // Disable MP3Start WoG hook
  Core.p.WriteDataPatch(Ptr($59AC51), ['BFF4336A00']);

  // Add new !?MP trigger
  ApiJack.StdSplice(Ptr($59AFB0), @New_Mp3_Trigger, CONV_THISCALL, 3);

  (* Make !?SN use always new unique buffer *)
  Core.p.WriteDataPatch(Ptr($59A893), ['A1E0926900']);
  ApiJack.StdSplice(Ptr($59A890), @Hook_PlaySound, ApiJack.CONV_FASTCALL, 3);

  (* Allow SN:W variables interpolation *)
  ApiJack.HookCode(Ptr($73DD82), @Hook_InterpolateErmString);
end; // .procedure OnAfterWoG

procedure OnBeforeErmInstructions (Event: PEvent); stdcall;
begin
  // NOTE! Erm module now manually calls ResetMemory
  ResetHints;
end;

procedure InitHints;
begin
  Hints['object']   := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  Hints['spec']     := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  Hints['secskill'] := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  Hints['monname']  := DataLib.NewObjDict(Utils.OWNS_ITEMS);
  Hints['art']      := DataLib.NewObjDict(Utils.OWNS_ITEMS);
end;

begin
  ServiceMemAllocator.Init;
  Erm.ErmCmdOptimizer := @OptimizeErmCmd;

  Kernel32Handle := Windows.LoadLibraryW('kernel32.dll');
  ApiCache       := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);

  New(Mp3TriggerContext);
  Slots    := AssocArrays.NewStrictObjArr(TSlot);
  AssocMem := AssocArrays.NewStrictAssocArr(TAssocVar);
  Hints    := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  InitHints;
  
  EventMan.GetInstance.On('OnBeforeWoG',             OnBeforeWoG);
  EventMan.GetInstance.On('OnAfterWoG',              OnAfterWoG);
  EventMan.GetInstance.On('OnBeforeErmInstructions', OnBeforeErmInstructions);
  EventMan.GetInstance.On('OnSavegameWrite',         OnSavegameWrite);
  EventMan.GetInstance.On('OnSavegameRead',          OnSavegameRead);
  EventMan.GetInstance.On('OnGenerateDebugInfo',     OnGenerateDebugInfo);
end.
