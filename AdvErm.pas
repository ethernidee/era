unit AdvErm;
{
DESCRIPTION: Era custom Memory implementation
AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Math, Crypto, Utils, AssocArrays, DataLib, StrLib, TypeWrappers, Files, ApiJack,
  PatchApi, Core, GameExt, Erm, Stores, Triggers, Heroes, Lodman, Trans, EventMan;

const
  SPEC_SLOT = -1;
  NO_SLOT   = -1;
  
  IS_TEMP   = 0;
  NOT_TEMP  = 1;
  
  (* DEPRECATED *)
  IS_STR    = true;
  IS_INT    = false;
  OPER_GET  = true;
  OPER_SET  = false;

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
  NO_MODIFIER     = 0;
  MODIFIER_ADD    = 1;
  MODIFIER_SUB    = 2;
  MODIFIER_MUL    = 3;
  MODIFIER_DIV    = 4;
  MODIFIER_CONCAT = 5;

  (* Hint code flags *)
  CODE_TYPE_SUBTYPE = $01000000;

  ERM_MEMORY_DUMP_FILE = GameExt.DEBUG_DIR + '\erm memory dump.txt';

type
  (* IMPORT *)
  TDict    = DataLib.TDict;
  TObjDict = DataLib.TObjDict;
  TString  = TypeWrappers.TString;

  TErmCmdContext = packed record
    
  end; // .record TErmCmdContext

  (* Params index starts from 1 *)
  TCommandHandler  = function (const CommandName: string; NumParams: integer; Params: PServiceParams; var Error: string): boolean;

  TVarType = (INT_VAR, STR_VAR);
  
  TSlot = class
    ItemsType:  TVarType;
    IsTemp:     boolean;
    IntItems:   array of integer;
    StrItems:   array of string;
  end; // .class TSlot
  
  TAssocVar = class
    IntValue: integer;
    StrValue: string;
  end; // .class TAssocVar


procedure ResetMemory;
function  GetOrCreateAssocVar (const VarName: string): {U} TAssocVar;
procedure RegisterCommand (const CommandName: string; CommandHandler: TCommandHandler);
procedure ApplyParam (var Param: TServiceParam; Value: pointer; MaxParamLen: integer = sizeof(Erm.TErmZVar));
procedure ModifyWithIntParam (var Dest: integer; var Param: TServiceParam);
function  CheckCmdParamsEx (Params: PServiceParams; NumParams: integer; const ParamConstraints: array of integer): boolean;

function ExtendedEraService
(
      Cmd:        char;
      NumParams:  integer;
      Params:     PServiceParams;
  out Err:        pchar
): boolean; stdcall;

var
{O} AssocMem: {O} AssocArrays.TAssocArray {OF TAssocVar};

exports
  ExtendedEraService;

  
(***) implementation (***)


type
  PMp3TriggerContext = ^TMp3TriggerContext;
  TMp3TriggerContext = record
    TrackName:         string;
    DontTrackPosition: integer;
    Loop:              integer;
    DefaultReaction:   integer;
  end;

var
(* The last extensible API for ERM. No more extensions. Use Lua *)
{O} NewCommands: {U} TObjDict {OF command crc32 => TCommandHandler};

{O} Hints:      {O} TDict {of [O] TObjDict of TString};
{O} Slots:      {O} AssocArrays.TObjArray {OF TSlot};
    FreeSlotN:  integer = SPEC_SLOT - 1;
    ErrBuf:     array [0..255] of char;

    Mp3TriggerContext: PMp3TriggerContext = nil;
    CurrentMp3Track:   string;


function GetCommandHandler (const CommandName: string): {n} TCommandHandler;
begin
  result := TCommandHandler(NewCommands[Ptr(Crypto.AnsiCrc32(CommandName))]);
end;

procedure RegisterCommand (const CommandName: string; CommandHandler: TCommandHandler);  
begin
  if @GetCommandHandler(CommandName) <> nil then begin
    Heroes.ShowMessage('Era command "' + CommandName + '" has hash collision and needs to be renamed');
  end else begin
    NewCommands[Ptr(Crypto.AnsiCrc32(CommandName))] := @CommandHandler;
  end;
end;

procedure ModifyWithIntParam (var Dest: integer; var Param: TServiceParam);
begin
  case Param.ParamModifier of 
    NO_MODIFIER:  Dest := Param.Value.v;
    MODIFIER_ADD: Dest := Dest + Param.Value.v;
    MODIFIER_SUB: Dest := Dest - Param.Value.v;
    MODIFIER_MUL: Dest := Dest * Param.Value.v;
    MODIFIER_DIV: Dest := Dest div Param.Value.v;
  end;
end;

procedure ApplyParam (var Param: TServiceParam; Value: pointer; MaxParamLen: integer = sizeof(Erm.TErmZVar));
begin
  if Param.OperGet then begin
    if Param.IsStr then begin
      Utils.SetPcharValue(Param.Value.pc, Value, sizeof(Erm.TErmZVar));
    end else begin
      pinteger(Param.Value.v)^ := pinteger(Value)^;
    end;
  end else begin
    if Param.IsStr then begin
      Utils.SetPcharValue(Value, Utils.IfThen(Param.ParamModifier <> MODIFIER_CONCAT, Param.Value.pc, AnsiString(pchar(Value)) + Param.Value.pc), MaxParamLen);
    end else begin
      ModifyWithIntParam(pinteger(Value)^, Param);
    end;
  end; // .else
end;

(* Parameters must be either reused or filled with zeroes before function call *)
function GetServiceParams (Cmd: pchar; var NumParams: integer; var {O} Params: TServiceParams): integer;
begin
  result := GameExt.EraGetServiceParams(Cmd, NumParams, Params);
end;

procedure ReleaseServiceParams ({O} var Params: TServiceParams); stdcall;
begin
  GameExt.EraReleaseServiceParams(Params);
end;

(* DEPRECATED. Use CheckCmdParamsEx instead *)
function CheckCmdParams (Params: PServiceParams; const Checks: array of boolean): boolean;
var
  i:  integer;

begin
  {!} Assert(Params <> nil);
  {!} Assert(not ODD(Length(Checks)));
  result  :=  true;
  i       :=  0;
  
  while result and (i <= High(Checks)) do begin
    result  :=
      (Params[i shr 1].IsStr  = Checks[i])  and
      (Params[i shr 1].OperGet = Checks[i + 1]);
    
    i :=  i + 2;
  end;
end; // .function CheckCmdParams

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
  if Slot.ItemsType = INT_VAR then begin
    result  :=  Length(Slot.IntItems);
  end else begin
    result  :=  Length(Slot.StrItems);
  end;
end;

procedure SetSlotItemsCount (NewNumItems: integer; Slot: TSlot);
begin
  {!} Assert(NewNumItems >= 0);
  {!} Assert(Slot <> nil);
  if Slot.ItemsType = INT_VAR then begin
    SetLength(Slot.IntItems, NewNumItems);
  end else begin
    SetLength(Slot.StrItems, NewNumItems);
  end;
end;

function NewSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): TSlot;
begin
  {!} Assert(ItemsCount >= 0);
  result            :=  TSlot.Create;
  result.ItemsType  :=  ItemsType;
  result.IsTemp     :=  IsTemp;
  
  SetSlotItemsCount(ItemsCount, result);
end;
  
function GetSlot (SlotN: integer; out {U} Slot: TSlot; out Error: string): boolean;
begin
  {!} Assert(Slot = nil);
  Slot    :=  Slots[Ptr(SlotN)];
  result  :=  Slot <> nil;
  
  if not result then begin
    Error :=  'Slot #' + SysUtils.IntToStr(SlotN) + ' does not exist.';
  end;
end;

function AllocSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): integer;
begin
  while Slots[Ptr(FreeSlotN)] <> nil do begin
    Dec(FreeSlotN);
    
    if FreeSlotN > 0 then begin
      FreeSlotN :=  SPEC_SLOT - 1;
    end;
  end;
  
  Slots[Ptr(FreeSlotN)] :=  NewSlot(ItemsCount, ItemsType, IsTemp);
  result                :=  FreeSlotN;
  Dec(FreeSlotN);
  
  if FreeSlotN > 0 then begin
    FreeSlotN :=  SPEC_SLOT - 1;
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
    Hint:        string;
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
    Monster:  integer;

  (* Returns new hint address or nil if hint was deleted *)
  function UpdateHint (HintParamN: integer): {n} pchar;
  begin
    if DeleteHint then begin
      Section.DeleteItem(Ptr(Code));
      result := nil;
    end else begin
      Hint     := Params[HintParamN].Value.pc;
      StrValue := TString(Section[Ptr(Code)]);

      if StrValue = nil then begin
        StrValue           := TString.Create(Hint);
        Section[Ptr(Code)] := StrValue;
      end else begin
        StrValue.Value := Hint;
      end;

      result := pchar(StrValue.Value);
    end; // .else
  end; // .function UpdateHint

begin
  Section  := nil;
  StrValue := nil;
  result   := true;
  // * * * * * //
  if NumParams >= 3 then begin
    result := not Params[0].OperGet and Params[0].IsStr;

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
          // SN:H^object^/type/subtype or -1/hint
          if NumParams = 4 then begin
            result := not Params[1].OperGet and not Params[2].OperGet and
                      not Params[1].IsStr   and not Params[2].IsStr   and (Params[3].OperGet or Params[3].IsStr);
            
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
                  StrValue := Section[Ptr(Code)];                 
                  Erm.SetZVar(Ptr(Params[3].Value.v), Utils.IfThen(StrValue <> nil, StrValue.Value, ''));
                end else begin
                  UpdateHint(3);
                end;
              end; // .if
            end; // .if
          // SN:H^object^/x/y/z/hint
          end else if NumParams = 5 then begin
            result := not Params[1].OperGet and not Params[2].OperGet and not Params[3].OperGet and
                      not Params[1].IsStr   and not Params[2].IsStr
                      and not Params[3].IsStr and (Params[4].OperGet or Params[4].IsStr);

            if result then begin
              x      := Params[1].Value.v;
              y      := Params[2].Value.v;
              z      := Params[3].Value.v;
              result := Math.InRange(x, 0, 255) and Math.InRange(y, 0, 255) and Math.InRange(z, 0, 255);

              if result then begin
                Code := x or (y shl 8) or (z shl 16);

                if Params[4].OperGet then begin
                  StrValue := Section[Ptr(Code)];                 
                  Erm.SetZVar(Ptr(Params[4].Value.v), Utils.IfThen(StrValue <> nil, StrValue.Value, ''));
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
            result := not Params[1].OperGet and not Params[2].OperGet and
                      not Params[1].IsStr   and not Params[2].IsStr   and (Params[3].OperGet or Params[3].IsStr);

            if result then begin
              Hero     := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Hero, 0, Erm.NUM_WOG_HEROES - 1) and Math.InRange(NameType, 0, 2);
              
              if result then begin
                if Params[3].OperGet then begin
                  Erm.SetZVar(Params[3].Value.pc, Erm.HeroSpecsTable[Hero].Descr[NameType]);
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
            result := not Params[1].OperGet and not Params[2].OperGet and
                      not Params[1].IsStr   and not Params[2].IsStr   and (Params[3].OperGet or Params[3].IsStr);

            if result then begin
              Skill    := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Skill, 0, Heroes.MAX_SECONDARY_SKILLS - 1) and Math.InRange(NameType, 0, Heroes.SKILL_LEVEL_EXPERT);
              
              if result then begin
                if Params[3].OperGet then begin
                  Erm.SetZVar(Params[3].Value.pc, Heroes.SecSkillTexts[Skill].Texts[NameType]);
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
            result := not Params[1].OperGet and not Params[2].OperGet and
                      not Params[1].IsStr   and not Params[2].IsStr   and (Params[3].OperGet or Params[3].IsStr);

            if result then begin
              Monster  := Params[1].Value.v;
              NameType := Params[2].Value.v;
              result   := Math.InRange(Monster, 0, Heroes.NumMonstersPtr^ - 1) and Math.InRange(NameType, 0, 2);
              
              if result then begin
                if Params[3].OperGet then begin
                  Erm.SetZVar(Params[3].Value.pc, Heroes.MonInfos[Monster].Names.Texts[NameType]);
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

  if Params[0].OperGet or not Params[0].IsStr or not Params[1].OperGet then begin
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
  Erm.SetZVar(pchar(Params[1].Value.v), Translation);

  result := true;
end; // .function SN_T

function SN_R (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams = 2) and CheckCmdParams(Params, [IS_STR, OPER_SET, IS_STR, OPER_SET]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:R^original resource name^/^new resource name^';
  end else begin
    Lodman.RedirectFile(Params[0].Value.pc, Params[1].Value.pc);
  end;
end;

function SN_I (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams = 2) and CheckCmdParams(Params, [IS_STR, OPER_SET, IS_STR, OPER_GET]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:Iz#/?z#';
  end else begin
    Erm.SetZVar(Params[1].Value.pc, Erm.ZvsInterpolateStr(Params[0].Value.pc));
  end;
end;

function SN_F (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
var
    CommandName:    string;
{n} CommandHandler: TCommandHandler;

begin
  result := (NumParams > 0) and CheckCmdParams(Params, [IS_STR, OPER_SET]);

  if not result then begin
    Error := 'Invalid command syntax. Valid syntax is !!SN:F^command^/parameters...';
  end else begin
    CommandName    := Params[0].Value.pc;
    CommandHandler := GetCommandHandler(CommandName);
    result         := @CommandHandler <> nil;

    if not result then begin
      Error := 'Unknown Era command "' + Params[0].Value.pc + '"';
    end else begin
      result := CommandHandler(CommandName, NumParams - 1, Params, Error);
    end;
  end; // .else
end; // .function SN_F

function ExtendedEraService
(
      Cmd:        char;
      NumParams:  integer;
      Params:     PServiceParams;
  out Err:        pchar
): boolean;

var
{U} Slot:               TSlot;
{U} AssocVarValue:      TAssocVar;
    AssocVarName:       string;
    Error:              string;
    StrLen:             integer;
    NewSlotItemsCount:  integer;
    GameState:          TGameState;

{U} Tile:    Heroes.PMapTile;
    Coords:  Heroes.TMapCoords;
    MapSize: integer;

begin
  Slot          :=  nil;
  AssocVarValue :=  nil;
  // * * * * * //
  result := true;
  Error  := 'Invalid command parameters';
  
  case Cmd of
    'F': result := SN_F(NumParams, Params, Error);
    
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
              result := CheckCmdParams(Params, [not IS_STR, not OPER_GET]) and (Params[0].Value.v <> SPEC_SLOT);
              
              if result then begin
                Slots.DeleteItem(Ptr(Params[0].Value.v));
              end;
            end; // .case 1
          // M(Slot)/[?]ItemsCount; analog of SetLength/Length
          2:
            begin
              result  :=
                CheckCmdParams(Params, [not IS_STR, not OPER_GET])  and
                (not Params[1].IsStr)                               and
                (Params[1].OperGet or (Params[1].Value.v >= 0));

              if result then begin          
                if Params[1].OperGet then begin
                  Slot := Slots[Ptr(Params[0].Value.v)];
                  
                  if Slot <> nil then begin
                    pinteger(Params[1].Value.v)^ := GetSlotItemsCount(Slot);
                  end else begin
                    pinteger(Params[1].Value.v)^ := NO_SLOT;
                  end;
                  end // .if
                else begin
                  result := GetSlot(Params[0].Value.v, Slot, Error);
                  
                  if result then begin
                    NewSlotItemsCount := GetSlotItemsCount(Slot);
                    ModifyWithIntParam(NewSlotItemsCount, Params[1]);
                    SetSlotItemsCount(NewSlotItemsCount, Slot);
                  end;
                end; // .else
              end; // .if
            end; // .case 2
          // M(Slot)/(VarN)/[?](Value) or M(Slot)/?addr/(VarN)
          3:
            begin
              result  :=
                CheckCmdParams(Params, [not IS_STR, not OPER_GET])  and
                GetSlot(Params[0].Value.v, Slot, Error)               and
                (not Params[1].IsStr);
              
              if result then begin
                if Params[1].OperGet then begin
                  result  :=
                    (not Params[2].OperGet) and
                    (not Params[2].IsStr)   and
                    Math.InRange(Params[2].Value.v, 0, GetSlotItemsCount(Slot) - 1);
                  
                  if result then begin
                    if Slot.ItemsType = INT_VAR then begin
                      PPOINTER(Params[1].Value.v)^  :=  @Slot.IntItems[Params[2].Value.v];
                    end else begin
                      PPOINTER(Params[1].Value.v)^  :=  pointer(Slot.StrItems[Params[2].Value.v]);
                    end;
                  end;
                end else begin
                  result  :=
                    (not Params[1].OperGet) and
                    (not Params[1].IsStr)   and
                    Math.InRange(Params[1].Value.v, 0, GetSlotItemsCount(Slot) - 1);
                  
                  if result then begin
                    if Params[2].OperGet then begin
                      if Slot.ItemsType = INT_VAR then begin
                        if Params[2].IsStr then begin
                          Windows.LStrCpy
                          (
                            Ptr(Params[2].Value.v),
                            Ptr(Slot.IntItems[Params[1].Value.v])
                          );
                        end else begin
                          pinteger(Params[2].Value.v)^  :=  Slot.IntItems[Params[1].Value.v];
                        end;
                      end else begin
                        Windows.LStrCpy
                        (
                          Ptr(Params[2].Value.v),
                          pchar(Slot.StrItems[Params[1].Value.v])
                        );
                      end; // .else
                    end else begin
                      if Slot.ItemsType = INT_VAR then begin
                        if Params[2].IsStr then begin
                          if Params[2].ParamModifier = MODIFIER_CONCAT then begin
                            StrLen := SysUtils.StrLen(pchar(Slot.IntItems[Params[1].Value.v]));
                            
                            Windows.LStrCpy
                            (
                              Utils.PtrOfs(Ptr(Slot.IntItems[Params[1].Value.v]), StrLen),
                              Ptr(Params[2].Value.v)
                            );
                          end else begin
                            Windows.LStrCpy
                            (
                              Ptr(Slot.IntItems[Params[1].Value.v]),
                              Ptr(Params[2].Value.v)
                            );
                          end; // .else
                        end else begin
                          Slot.IntItems[Params[1].Value.v]  :=  Params[2].Value.v;
                        end; // .else
                      end else begin
                        if Params[2].Value.v = 0 then begin
                          Params[2].Value.v := integer(pchar(''));
                        end;
                        
                        if Params[2].ParamModifier = MODIFIER_CONCAT then begin
                          Slot.StrItems[Params[1].Value.v] := Slot.StrItems[Params[1].Value.v] +
                                                            pchar(Params[2].Value.v);
                        end else begin
                          Slot.StrItems[Params[1].Value.v] := pchar(Params[2].Value.v);
                        end;
                      end; // .else
                    end; // .else
                  end; // .if
                end; // .else
              end; // .if
            end; // .case 3
          4:
            begin
              result  :=  CheckCmdParams
              (
                Params,
                [
                  not IS_STR,
                  not OPER_GET,
                  not IS_STR,
                  not OPER_GET,
                  not IS_STR,
                  not OPER_GET,
                  not IS_STR,
                  not OPER_GET
                ]
              ) and
              (Params[0].Value.v >= SPEC_SLOT)                        and
              (Params[1].Value.v >= 0)                                and
              Math.InRange(Params[2].Value.v, 0, ORD(High(TVarType))) and
              ((Params[3].Value.v = IS_TEMP) or (Params[3].Value.v = NOT_TEMP));
              
              if result then begin
                if Params[0].Value.v = SPEC_SLOT then begin
                  Erm.v[1]  :=  AllocSlot
                  (
                    Params[1].Value.v, TVarType(Params[2].Value.v), Params[3].Value.v = IS_TEMP
                  );
                end else begin
                  Slots[Ptr(Params[0].Value.v)] :=  NewSlot
                  (
                    Params[1].Value.v, TVarType(Params[2].Value.v), Params[3].Value.v = IS_TEMP
                  );
                end; // .else
              end; // .if
            end; // .case 4
        else
          result  :=  false;
          Error   :=  'Invalid number of command parameters';
        end; // .switch NumParams
      end; // .case "M"
    'K':
      begin
        case NumParams of 
          // C(str)/?(len)
          2:
            begin
              result  :=  (not Params[0].OperGet) and (not Params[1].IsStr) and (Params[1].OperGet);
              
              if result then begin
                pinteger(Params[1].Value.v)^  :=  SysUtils.StrLen(pointer(Params[0].Value.v));
              end;
            end; // .case 2
          // C(str)/(ind)/[?](strchar)
          3:
            begin
              result  :=
                (not Params[0].OperGet) and
                (not Params[1].IsStr)   and
                (not Params[1].OperGet) and
                (Params[1].Value.v >= 0)  and
                (Params[2].IsStr);
              
              if result then begin
                if Params[2].OperGet then begin
                  pchar(Params[2].Value.v)^     :=  PEndlessCharArr(Params[0].Value.v)[Params[1].Value.v];
                  pchar(Params[2].Value.v + 1)^ :=  #0;
                end else begin
                  PEndlessCharArr(Params[0].Value.v)[Params[1].Value.v] :=  pchar(Params[2].Value.v)^;
                end;
              end;
            end; // .case 3
          4:
            begin
              result  :=
                (not Params[0].IsStr)   and
                (not Params[0].OperGet) and
                (Params[0].Value.v >= 0);
              
              if result and (Params[0].Value.v > 0) then begin
                Utils.CopyMem(Params[0].Value.v, pointer(Params[1].Value.v), pointer(Params[2].Value.v));
              end;
            end; // .case 4
        else
          result  :=  false;
          Error   :=  'Invalid number of command parameters';
        end; // .switch NumParams
      end; // .case "K"
    'W':
      begin
        case NumParams of 
          // Clear all
          0: AssocMem.Clear;
          
          // Delete var
          1:
            begin
              result := not Params[0].OperGet;
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName := pchar(Params[0].Value.v);
                end else begin
                  AssocVarName := SysUtils.IntToStr(Params[0].Value.v);
                end;
                
                AssocMem.DeleteItem(AssocVarName);
              end;
            end; // .case 1
          // Get/set var
          2:
            begin
              result := not Params[0].OperGet;
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName := pchar(Params[0].Value.v);
                end else begin
                  AssocVarName := SysUtils.IntToStr(Params[0].Value.v);
                end;
                
                AssocVarValue := AssocMem[AssocVarName];
                
                if Params[1].OperGet then begin
                  if Params[1].IsStr then begin
                    if (AssocVarValue = nil) or (AssocVarValue.StrValue = '') then begin
                      pchar(Params[1].Value.v)^ :=  #0;
                    end else begin
                      Erm.SetZVar(Params[1].Value.pc, AssocVarValue.StrValue);
                    end;
                  end else begin
                    if AssocVarValue = nil then begin
                      pinteger(Params[1].Value.v)^ := 0;
                    end else begin
                      pinteger(Params[1].Value.v)^ := AssocVarValue.IntValue;
                    end;
                  end; // .else
                end else begin
                  if AssocVarValue = nil then begin
                    AssocVarValue          := TAssocVar.Create;
                    AssocMem[AssocVarName] := AssocVarValue;
                  end;
                  
                  if Params[1].IsStr then begin
                    if Params[1].ParamModifier <> MODIFIER_CONCAT then begin
                      AssocVarValue.StrValue := pchar(Params[1].Value.v);
                    end else begin
                      AssocVarValue.StrValue := AssocVarValue.StrValue + pchar(Params[1].Value.v);
                    end;
                  end else begin
                    ModifyWithIntParam(AssocVarValue.IntValue, Params[1]);
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
        
        if GameState.CurrentDlgId = ADVMAP_DLGID then begin
          Erm.ExecErmCmd('UN:R1;');
        end else if GameState.CurrentDlgId = TOWN_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R4;');
        end else if GameState.CurrentDlgId = HERO_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R3/-1;');
        end else if GameState.CurrentDlgId = HERO_MEETING_SCREEN_DLGID then begin
          Heroes.RedrawHeroMeetingScreen;
        end;
      end; // .case "D"
    'O':
      begin
        // O?$/?$/?$
        if NumParams = 3 then begin
          result := Params[0].OperGet and Params[1].OperGet and Params[2].OperGet and
                    not Params[0].IsStr and not Params[1].IsStr and not Params[2].IsStr;

          if result then begin
            Coords[0] := pinteger(Params[0].Value.v)^;
            Coords[1] := pinteger(Params[1].Value.v)^;
            Coords[2] := pinteger(Params[2].Value.v)^;
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
              pinteger(Params[0].Value.v)^ := Coords[0];
              pinteger(Params[1].Value.v)^ := Coords[1];
              pinteger(Params[2].Value.v)^ := Coords[2];
            end; // .else
          end; // .if
        end else begin
          result := false;
          Error  := 'Invalid number of command parameters';
        end; // .else
      end; // .case "O"

    'T': result := SN_T(NumParams, Params, Error);
    'H': result := SN_H(NumParams, Params, Error);
    'R': result := SN_R(NumParams, Params, Error);
    'I': result := SN_I(NumParams, Params, Error);
  else
    result := false;
    Error  := 'Unknown command "' + Cmd +'".';
  end; // .switch Cmd
  
  if not result then begin
    Error :=  'Error executing Era command SN:' + Cmd + ':'#13#10 + Error;
    Utils.CopyMem(Length(Error) + 1, pointer(Error), @ErrBuf);
    Err := @ErrBuf;
  end;
end; // .function ExtendedEraService

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
    SlotN:    integer;
    NumSlots: integer;
    NumItems: integer;
    StrLen:   integer;
    i:        integer;
  
begin
  SlotN :=  0;
  Slot  :=  nil;
  // * * * * * //
  NumSlots  :=  Slots.ItemCount;
  Stores.WriteSavegameSection(sizeof(NumSlots), @NumSlots, SLOTS_SAVE_SECTION);
  
  Slots.BeginIterate;
  
  while Slots.IterateNext(pointer(SlotN), pointer(Slot)) do begin
    Stores.WriteSavegameSection(sizeof(SlotN), @SlotN, SLOTS_SAVE_SECTION);
    Stores.WriteSavegameSection(sizeof(Slot.ItemsType), @Slot.ItemsType, SLOTS_SAVE_SECTION);
    Stores.WriteSavegameSection(sizeof(Slot.IsTemp), @Slot.IsTemp, SLOTS_SAVE_SECTION);
    
    NumItems  :=  GetSlotItemsCount(Slot);
    Stores.WriteSavegameSection(sizeof(NumItems), @NumItems, SLOTS_SAVE_SECTION);
    
    if (NumItems > 0) and not Slot.IsTemp then begin
      if Slot.ItemsType = INT_VAR then begin
        Stores.WriteSavegameSection
        (
          sizeof(integer) * NumItems,
          @Slot.IntItems[0], SLOTS_SAVE_SECTION
        );
      end else begin
        for i:=0 to NumItems - 1 do begin
          StrLen  :=  Length(Slot.StrItems[i]);
          Stores.WriteSavegameSection(sizeof(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          
          if StrLen > 0 then begin
            Stores.WriteSavegameSection(StrLen, pointer(Slot.StrItems[i]), SLOTS_SAVE_SECTION);
          end;
        end;
      end; // .else
    end; // .if
    
    SlotN :=  0;
    Slot  :=  nil;
  end; // .while
  
  Slots.EndIterate;
end; // .procedure SaveSlots

procedure SaveAssocMem;
var
{U} AssocVarValue:  TAssocVar;
    AssocVarName:   string;
    NumVars:        integer;
    StrLen:         integer;
  
begin
  AssocVarValue :=  nil;
  // * * * * * //
  NumVars :=  AssocMem.ItemCount;
  Stores.WriteSavegameSection(sizeof(NumVars), @NumVars, ASSOC_SAVE_SECTION);
  
  AssocMem.BeginIterate;
  
  while AssocMem.IterateNext(AssocVarName, pointer(AssocVarValue)) do begin
    StrLen  :=  Length(AssocVarName);
    Stores.WriteSavegameSection(sizeof(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    Stores.WriteSavegameSection(StrLen, pointer(AssocVarName), ASSOC_SAVE_SECTION);
    
    Stores.WriteSavegameSection
    (
      sizeof(AssocVarValue.IntValue),
      @AssocVarValue.IntValue,
      ASSOC_SAVE_SECTION
    );
    
    StrLen  :=  Length(AssocVarValue.StrValue);
    Stores.WriteSavegameSection(sizeof(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    Stores.WriteSavegameSection(StrLen, pointer(AssocVarValue.StrValue), ASSOC_SAVE_SECTION);
    
    AssocVarValue :=  nil;
  end; // .while
  
  AssocMem.EndIterate;
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
    NumSlots:   integer;
    ItemsType:  TVarType;
    IsTempSlot: boolean;
    NumItems:   integer;
    StrLen:     integer;
    i:          integer;
    y:          integer;

begin
  Slot      :=  nil;
  NumSlots  :=  0;
  // * * * * * //
  Slots.Clear;
  Stores.ReadSavegameSection(sizeof(NumSlots), @NumSlots, SLOTS_SAVE_SECTION);
  
  for i:=0 to NumSlots - 1 do begin
    Stores.ReadSavegameSection(sizeof(SlotN), @SlotN, SLOTS_SAVE_SECTION);
    Stores.ReadSavegameSection(sizeof(ItemsType), @ItemsType, SLOTS_SAVE_SECTION);
    Stores.ReadSavegameSection(sizeof(IsTempSlot), @IsTempSlot, SLOTS_SAVE_SECTION);
    
    Stores.ReadSavegameSection(sizeof(NumItems), @NumItems, SLOTS_SAVE_SECTION);
    
    Slot              :=  NewSlot(NumItems, ItemsType, IsTempSlot);
    Slots[Ptr(SlotN)] :=  Slot;
    SetSlotItemsCount(NumItems, Slot);
    
    if not IsTempSlot and (NumItems > 0) then begin
      if ItemsType = INT_VAR then begin
        Stores.ReadSavegameSection
        (
          sizeof(integer) * NumItems,
          @Slot.IntItems[0],
          SLOTS_SAVE_SECTION
        );
      end else begin
        for y:=0 to NumItems - 1 do begin
          Stores.ReadSavegameSection(sizeof(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          SetLength(Slot.StrItems[y], StrLen);
          Stores.ReadSavegameSection(StrLen, pointer(Slot.StrItems[y]), SLOTS_SAVE_SECTION);
        end;
      end; // .else
    end; // .if
  end; // .for
end; // .procedure LoadSlots

procedure LoadAssocMem;
var
{O} AssocVarValue:  TAssocVar;
    AssocVarName:   string;
    NumVars:        integer;
    StrLen:         integer;
    i:              integer;
  
begin
  AssocVarValue :=  nil;
  NumVars       :=  0;
  // * * * * * //
  AssocMem.Clear;
  Stores.ReadSavegameSection(sizeof(NumVars), @NumVars, ASSOC_SAVE_SECTION);
  
  for i:=0 to NumVars - 1 do begin
    AssocVarValue :=  TAssocVar.Create;
    
    Stores.ReadSavegameSection(sizeof(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    SetLength(AssocVarName, StrLen);
    Stores.ReadSavegameSection(StrLen, pointer(AssocVarName), ASSOC_SAVE_SECTION);
    
    Stores.ReadSavegameSection
    (
      sizeof(AssocVarValue.IntValue),
      @AssocVarValue.IntValue,
      ASSOC_SAVE_SECTION
    );
    
    Stores.ReadSavegameSection(sizeof(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    SetLength(AssocVarValue.StrValue, StrLen);
    Stores.ReadSavegameSection(StrLen, pointer(AssocVarValue.StrValue), ASSOC_SAVE_SECTION);
    
    if (AssocVarValue.IntValue <> 0) or (AssocVarValue.StrValue <> '') then begin
      AssocMem[AssocVarName]  :=  AssocVarValue; AssocVarValue  :=  nil;
    end else begin
      SysUtils.FreeAndNil(AssocVarValue);
    end;
  end; // .for
end; // .procedure LoadAssocMem

procedure LoadHints;
var
{U} HintSection:     TObjDict;
    NumHintSections: integer;
    NumRecords:      integer;
    ItemCode:        integer;
    i, k:            integer;

{U} Name:     pchar;
    Hero:     integer;
    Skill:    integer;
    Monster:  integer;
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
    for i := 1 to NumHintSections do begin
      // Read hint section name and create hint section object
      HintSection    := DataLib.NewObjDict(Utils.OWNS_ITEMS);
      Hints[ReadStr] := HintSection;
      NumRecords     := ReadInt;

      // Read hint section records
      for k := 1 to NumRecords do begin
        // Read item code and hint string
        ItemCode := ReadInt;
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
end; // .procedure LoadHints

procedure OnSavegameRead (Event: PEvent); stdcall;
begin
  LoadSlots;
  LoadAssocMem;
  LoadHints;
end;

function Hook_ZvsCheckObjHint (C: Core.PHookContext): longbool; stdcall;
var
{U} HintSection: TObjDict;
{U} StrValue:    TString;
    Code:        integer;
    ObjType:     integer;
    ObjSubtype:  integer;

begin
  HintSection := TObjDict(Hints['object']);
  Code        := pinteger(C.EBP - 12)^ or (pinteger(C.EBP - 8)^ shl 8)
                 or (pinteger(C.EBP - 24)^ shl 16);
  StrValue    := HintSection[Ptr(Code)];
  
  if StrValue = nil then begin
    ObjType    := pword(pinteger(C.EBP + 8)^ + $1E)^;
    ObjSubtype := pword(pinteger(C.EBP + 8)^ + $22)^;
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
end; // .function Hook_ZvsCheckObjHint

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
  
  for i := 0 to High(Erm.QuickVars^) do begin
    Line(CHR(ORD('f') + i) + ' = ' + IntToStr(Erm.QuickVars[i]));
  end;
  
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

procedure OnBeforeWoG (Event: PEvent); stdcall;
begin
  (*Core.p.WriteLoHook($74B6B2, @HookFindErm_NewReceivers);*)
  (* Custom ERM memory dump *)
  Core.ApiHook(@Hook_DumpErmVars, Core.HOOKTYPE_BRIDGE, @Erm.ZvsDumpErmVars);
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
      result := CheckCmdParams(Params, [IS_STR, OPER_SET, IS_INT, OPER_SET, IS_INT, OPER_SET]);

      if result then begin
        Heroes.ChangeMp3Theme(Params[0].Value.pc, Params[1].Value.v <> 0, Params[2].Value.v <> 0);
      end;
    end
    // MP:P0/[pause = 0, resume = 1]
    else begin
      result := CheckCmdParams(Params, [IS_INT, OPER_SET, IS_INT, OPER_SET]) and Math.InRange(Params[1].Value.v, 0, 1);

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
  result := (NumParams = 1) and CheckCmdParams(Params, [IS_STR, OPER_GET]);

  if result then begin
    Windows.LStrCpy(Params[0].Value.pc, pchar(CurrentMp3Track));
  end;
end;

function MP_S (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := Math.InRange(NumParams, 1, 3);
  result := result and Params[0].IsStr;
  result := result and ((NumParams < 2) or not Params[1].IsStr);
  result := result and ((NumParams < 3) or not Params[2].IsStr);

  if result then begin
    // TrackName
    if Params[0].OperGet then begin
      ApplyParam(Params[0], pchar(Mp3TriggerContext.TrackName));
    end else begin
      Mp3TriggerContext.TrackName := Utils.GetPcharValue(Params[0].Value.pc, sizeof(Heroes.TCurrentMp3Track) - 1);
    end;

    // DontTrackPosition
    if NumParams >= 2 then begin
      ApplyParam(Params[1], @Mp3TriggerContext.DontTrackPosition);
      Mp3TriggerContext.DontTrackPosition := ord(Mp3TriggerContext.DontTrackPosition <> 0);
    end;

    // Loop
    if NumParams >= 3 then begin
      ApplyParam(Params[2], @Mp3TriggerContext.Loop);
      Mp3TriggerContext.Loop := ord(Mp3TriggerContext.Loop <> 0);
    end;
  end; // .if
end; // .function MP_S

function MP_R (NumParams: integer; Params: PServiceParams; var Error: string): boolean;
begin
  result := (NumParams = 1) and not Params[0].IsStr;

  if result then begin
    ApplyParam(Params[0], @Mp3TriggerContext.DefaultReaction);
    Mp3TriggerContext.DefaultReaction := ord(Mp3TriggerContext.DefaultReaction <> 0);
  end;
end;

function New_Mp3_Receiver (OrigFunc: pointer; Cmd: char; NumParams: integer; Dummy: integer; CmdInfo: PErmSubCmd): integer; stdcall;
var
  Params:    GameExt.TServiceParams;
  ParamsLen: integer;
  CmdPtr:    pchar;
  Success:   boolean;
  Error:     string;

begin
  FillChar(Params, sizeof(Params), 0);
  CmdPtr := @CmdInfo.Code.Value[0];
  // * * * * * //
  CmdInfo.Pos := 0;
  Success     := true;

  while (CmdPtr^ <> ';') and Success do begin
    Cmd       := CmdPtr^;
    ParamsLen := GetServiceParams(CmdPtr, NumParams, Params);
    Success   := ParamsLen <> -1;

    if Success then begin
      case Cmd of
        'P': begin Success := MP_P(NumParams, @Params, Error); end;
        'C': begin Success := MP_C(NumParams, @Params, Error); end;
        'S': begin Success := MP_S(NumParams, @Params, Error); end;
        'R': begin Success := MP_R(NumParams, @Params, Error); end;
      else
        Error   := 'Unknown command "!!MP:' + Cmd + '"';
        Success := false;
      end;

      if not Success then begin
        if Error = '' then begin
          Error := 'Invalid command arguments';
        end;

        Erm.ErmErrCmdPtr^ := @CmdInfo.Code.Value[0];
        Erm.ShowErmError(Error);
      end;
    end; // .if

    if Success then begin
      Inc(CmdPtr, ParamsLen);
      Inc(CmdInfo.Pos, ParamsLen);
    end;
  end; // .while

  result := ord(Success);
  // * * * * * //
  ReleaseServiceParams(Params);
end; // .function New_Mp3_Receiver

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
  // ...
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

  // Replace MP3 receiver
  ApiJack.StdSplice(Ptr($774A8C), @New_Mp3_Receiver, CONV_CDECL, 4);

  // Add new !?MP trigger
  ApiJack.StdSplice(Ptr($59AFB0), @New_Mp3_Trigger, CONV_THISCALL, 3);
end;

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
end;

begin
  NewCommands := DataLib.NewObjDict(not Utils.OWNS_ITEMS);
  RegisterCommands;

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
