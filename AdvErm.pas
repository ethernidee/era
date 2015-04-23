unit AdvErm;
{
DESCRIPTION:  Era custom Memory implementation
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Windows, SysUtils, Math, Utils, AssocArrays, DataLib,
  PatchApi, Core, GameExt, Erm, Stores, Heroes;

const
  SPEC_SLOT = -1;
  NO_SLOT   = -1;
  
  IS_TEMP   = 0;
  NOT_TEMP  = 1;
  
  IS_STR    = TRUE;
  OPER_GET  = TRUE;
  
  SLOTS_SAVE_SECTION  = 'Era.DynArrays_SN_M';
  ASSOC_SAVE_SECTION  = 'Era.AssocArray_SN_W';
  
  (* TParamModifier *)
  NO_MODIFIER     = 0;
  MODIFIER_ADD    = 1;
  MODIFIER_SUB    = 2;
  MODIFIER_MUL    = 3;
  MODIFIER_DIV    = 4;
  MODIFIER_CONCAT = 5;


type
  (* IMPORT *)
  TObjDict = DataLib.TObjDict;

  TErmCmdContext = packed record
    
  end; // .record TErmCmdContext

  TReceiverHandler = procedure;

  TVarType  = (INT_VAR, STR_VAR);
  
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
  
  TServiceParam = packed record
    IsStr:          boolean;
    OperGet:        boolean;
    Dummy:          word;
    Value:          integer;
    StrValue:       pchar;
    ParamModifier:  integer;
  end; // .record TServiceParam

  PServiceParams  = ^TServiceParams;
  TServiceParams  = array [0..23] of TServiceParam;


function ExtendedEraService
(
      Cmd:        char;
      NumParams:  integer;
      Params:     PServiceParams;
  out Err:        pchar
): boolean; stdcall;


exports
  ExtendedEraService;

  
(***) implementation (***)


var
{O} NewReceivers: {O} TObjDict {OF TErmCmdHandler};

{O} Slots:      {O} AssocArrays.TObjArray {OF TSlot};
{O} AssocMem:   {O} AssocArrays.TAssocArray {OF TAssocVar};
    FreeSlotN:  integer = SPEC_SLOT - 1;
    ErrBuf:     array [0..255] of char;


procedure RegisterReceiver (ReceiverName: integer; ReceiverHandler: TReceiverHandler);
var
  OldReceiverHandler: TReceiverHandler;
   
begin
  OldReceiverHandler := NewReceivers[Ptr(ReceiverName)];

  if @OldReceiverHandler = nil then begin
    NewReceivers[Ptr(ReceiverName)] := @ReceiverHandler;
  end // .if
  else begin
    Erm.ShowMessage('Receiver "' + CHR(ReceiverName and $FF) + CHR(ReceiverName shr 8 and $FF) + '" is already registered!');
  end; // .else
end; // .procedure RegisterReceiver
    
procedure ModifyWithIntParam (var Dest: integer; var Param: TServiceParam);
begin
  case Param.ParamModifier of 
    NO_MODIFIER:  Dest := Param.Value;
    MODIFIER_ADD: Dest := Dest + Param.Value;
    MODIFIER_SUB: Dest := Dest - Param.Value;
    MODIFIER_MUL: Dest := Dest * Param.Value;
    MODIFIER_DIV: Dest := Dest div Param.Value;
  end; // .switch Paramo.ParamModifier
end; // .procedure ModifyWithParam
    
function CheckCmdParams (Params: PServiceParams; const Checks: array of boolean): boolean;
var
  i:  integer;

begin
  {!} Assert(Params <> nil);
  {!} Assert(not ODD(Length(Checks)));
  result  :=  TRUE;
  i       :=  0;
  
  while result and (i <= High(Checks)) do begin
    result  :=
      (Params[i shr 1].IsStr  = Checks[i])  and
      (Params[i shr 1].OperGet = Checks[i + 1]);
    
    i :=  i + 2;
  end; // .while
end; // .function CheckCmdParams

function GetSlotItemsCount (Slot: TSlot): integer;
begin
  {!} Assert(Slot <> nil);
  if Slot.ItemsType = INT_VAR then begin
    result  :=  Length(Slot.IntItems);
  end // .if
  else begin
    result  :=  Length(Slot.StrItems);
  end; // .else
end; // .function GetSlotItemsCount

procedure SetSlotItemsCount (NewNumItems: integer; Slot: TSlot);
begin
  {!} Assert(NewNumItems >= 0);
  {!} Assert(Slot <> nil);
  if Slot.ItemsType = INT_VAR then begin
    SetLength(Slot.IntItems, NewNumItems);
  end // .if
  else begin
    SetLength(Slot.StrItems, NewNumItems);
  end; // .else
end; // .procedure SetSlotItemsCount

function NewSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): TSlot;
begin
  {!} Assert(ItemsCount >= 0);
  result            :=  TSlot.Create;
  result.ItemsType  :=  ItemsType;
  result.IsTemp     :=  IsTemp;
  
  SetSlotItemsCount(ItemsCount, result);
end; // .function NewSlot
  
function GetSlot (SlotN: integer; out {U} Slot: TSlot; out Error: string): boolean;
begin
  {!} Assert(Slot = nil);
  Slot    :=  Slots[Ptr(SlotN)];
  result  :=  Slot <> nil;
  
  if not result then begin
    Error :=  'Slot #' + SysUtils.IntToStr(SlotN) + ' does not exist.';
  end; // .if
end; // .function GetSlot 

function AllocSlot (ItemsCount: integer; ItemsType: TVarType; IsTemp: boolean): integer;
begin
  while Slots[Ptr(FreeSlotN)] <> nil do begin
    Dec(FreeSlotN);
    
    if FreeSlotN > 0 then begin
      FreeSlotN :=  SPEC_SLOT - 1;
    end; // .if
  end; // .while
  
  Slots[Ptr(FreeSlotN)] :=  NewSlot(ItemsCount, ItemsType, IsTemp);
  result                :=  FreeSlotN;
  Dec(FreeSlotN);
  
  if FreeSlotN > 0 then begin
    FreeSlotN :=  SPEC_SLOT - 1;
  end; // .if
end; // .function AllocSlot

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

begin
  Slot          :=  nil;
  AssocVarValue :=  nil;
  // * * * * * //
  result  :=  TRUE;
  Error   :=  'Invalid command parameters';
  
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
              result  :=
                CheckCmdParams(Params, [not IS_STR, not OPER_GET])  and
                (Params[0].Value <> SPEC_SLOT);
              
              if result then begin
                Slots.DeleteItem(Ptr(Params[0].Value));
              end; // .if
            end; // .case 1
          // M(Slot)/[?]ItemsCount; analog of SetLength/Length
          2:
            begin
              result  :=
                CheckCmdParams(Params, [not IS_STR, not OPER_GET])  and
                (not Params[1].IsStr)                               and
                (Params[1].OperGet or (Params[1].Value >= 0));

              if result then begin          
                if Params[1].OperGet then begin
                  Slot  :=  Slots[Ptr(Params[0].Value)];
                  
                  if Slot <> nil then begin
                    PINTEGER(Params[1].Value)^  :=  GetSlotItemsCount(Slot);
                  end // .if
                  else begin
                    PINTEGER(Params[1].Value)^  :=  NO_SLOT;
                  end; // .else
                  end // .if
                else begin
                  result  :=  GetSlot(Params[0].Value, Slot, Error);
                  
                  if result then begin
                    NewSlotItemsCount := GetSlotItemsCount(Slot);
                    ModifyWithIntParam(NewSlotItemsCount, Params[1]);
                    SetSlotItemsCount(NewSlotItemsCount, Slot);
                  end; // .if
                end; // .else
              end; // .if
            end; // .case 2
          // M(Slot)/(VarN)/[?](Value) or M(Slot)/?addr/(VarN)
          3:
            begin
              result  :=
                CheckCmdParams(Params, [not IS_STR, not OPER_GET])  and
                GetSlot(Params[0].Value, Slot, Error)               and
                (not Params[1].IsStr);
              
              if result then begin
                if Params[1].OperGet then begin
                  result  :=
                    (not Params[2].OperGet) and
                    (not Params[2].IsStr)   and
                    Math.InRange(Params[2].Value, 0, GetSlotItemsCount(Slot) - 1);
                  
                  if result then begin
                    if Slot.ItemsType = INT_VAR then begin
                      PPOINTER(Params[1].Value)^  :=  @Slot.IntItems[Params[2].Value];
                    end // .if
                    else begin
                      PPOINTER(Params[1].Value)^  :=  pointer(Slot.StrItems[Params[2].Value]);
                    end; // .else
                  end; // .if
                end // .if
                else begin
                  result  :=
                    (not Params[1].OperGet) and
                    (not Params[1].IsStr)   and
                    Math.InRange(Params[1].Value, 0, GetSlotItemsCount(Slot) - 1);
                  
                  if result then begin
                    if Params[2].OperGet then begin
                      if Slot.ItemsType = INT_VAR then begin
                        if Params[2].IsStr then begin
                          Windows.LStrCpy
                          (
                            Ptr(Params[2].Value),
                            Ptr(Slot.IntItems[Params[1].Value])
                          );
                        end // .if
                        else begin
                          PINTEGER(Params[2].Value)^  :=  Slot.IntItems[Params[1].Value];
                        end; // .else
                      end // .if
                      else begin
                        Windows.LStrCpy
                        (
                          Ptr(Params[2].Value),
                          pchar(Slot.StrItems[Params[1].Value])
                        );
                      end; // .else
                    end // .if
                    else begin
                      if Slot.ItemsType = INT_VAR then begin
                        if Params[2].IsStr then begin
                          if Params[2].ParamModifier = MODIFIER_CONCAT then begin
                            StrLen := SysUtils.StrLen(pchar(Slot.IntItems[Params[1].Value]));
                            
                            Windows.LStrCpy
                            (
                              Utils.PtrOfs(Ptr(Slot.IntItems[Params[1].Value]), StrLen),
                              Ptr(Params[2].Value)
                            );
                          end // .if
                          else begin
                            Windows.LStrCpy
                            (
                              Ptr(Slot.IntItems[Params[1].Value]),
                              Ptr(Params[2].Value)
                            );
                          end; // .else
                        end // .if
                        else begin
                          Slot.IntItems[Params[1].Value]  :=  Params[2].Value;
                        end; // .else
                      end // .if
                      else begin
                        if Params[2].Value = 0 then begin
                          Params[2].Value := integer(pchar(''));
                        end; // .if
                        
                        if Params[2].ParamModifier = MODIFIER_CONCAT then begin
                          Slot.StrItems[Params[1].Value] := Slot.StrItems[Params[1].Value] +
                                                            pchar(Params[2].Value);
                        end // .if
                        else begin
                          Slot.StrItems[Params[1].Value] := pchar(Params[2].Value);
                        end; // .else
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
              (Params[0].Value >= SPEC_SLOT)                        and
              (Params[1].Value >= 0)                                and
              Math.InRange(Params[2].Value, 0, ORD(High(TVarType))) and
              ((Params[3].Value = IS_TEMP) or (Params[3].Value = NOT_TEMP));
              
              if result then begin
                if Params[0].Value = SPEC_SLOT then begin
                  Erm.v[1]  :=  AllocSlot
                  (
                    Params[1].Value, TVarType(Params[2].Value), Params[3].Value = IS_TEMP
                  );
                end // .if
                else begin
                  Slots[Ptr(Params[0].Value)] :=  NewSlot
                  (
                    Params[1].Value, TVarType(Params[2].Value), Params[3].Value = IS_TEMP
                  );
                end; // .else
              end; // .if
            end; // .case 4
        else
          result  :=  FALSE;
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
                PINTEGER(Params[1].Value)^  :=  SysUtils.StrLen(pointer(Params[0].Value));
              end; // .if
            end; // .case 2
          // C(str)/(ind)/[?](strchar)
          3:
            begin
              result  :=
                (not Params[0].OperGet) and
                (not Params[1].IsStr)   and
                (not Params[1].OperGet) and
                (Params[1].Value >= 0)  and
                (Params[2].IsStr);
              
              if result then begin
                if Params[2].OperGet then begin
                  pchar(Params[2].Value)^     :=  PEndlessCharArr(Params[0].Value)[Params[1].Value];
                  pchar(Params[2].Value + 1)^ :=  #0;
                end // .if
                else begin
                  PEndlessCharArr(Params[0].Value)[Params[1].Value] :=  pchar(Params[2].Value)^;
                end; // .else
              end; // .if
            end; // .case 3
          4:
            begin
              result  :=
                (not Params[0].IsStr)   and
                (not Params[0].OperGet) and
                (Params[0].Value >= 0);
              
              if result and (Params[0].Value > 0) then begin
                Utils.CopyMem(Params[0].Value, pointer(Params[1].Value), pointer(Params[2].Value));
              end; // .if
            end; // .case 4
        else
          result  :=  FALSE;
          Error   :=  'Invalid number of command parameters';
        end; // .switch NumParams
      end; // .case "K"
    'W':
      begin
        case NumParams of 
          // Clear all
          0:
            begin
              AssocMem.Clear;
            end; // .case 0
          // Delete var
          1:
            begin
              result  :=  not Params[0].OperGet;
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName  :=  pchar(Params[0].Value);
                end // .if
                else begin
                  AssocVarName  :=  SysUtils.IntToStr(Params[0].Value);
                end; // .else
                
                AssocMem.DeleteItem(AssocVarName);
              end; // .if
            end; // .case 1
          // Get/set var
          2:
            begin
              result  :=  not Params[0].OperGet;
              
              if result then begin
                if Params[0].IsStr then begin
                  AssocVarName  :=  pchar(Params[0].Value);
                end // .if
                else begin
                  AssocVarName  :=  SysUtils.IntToStr(Params[0].Value);
                end; // .else
                
                AssocVarValue :=  AssocMem[AssocVarName];
                
                if Params[1].OperGet then begin
                  if Params[1].IsStr then begin
                    if (AssocVarValue = nil) or (AssocVarValue.StrValue = '') then begin
                      pchar(Params[1].Value)^ :=  #0;
                    end // .if
                    else begin
                      Utils.CopyMem
                      (
                        Length(AssocVarValue.StrValue) + 1,
                        pointer(AssocVarValue.StrValue),
                        pointer(Params[1].Value)
                      );
                    end; // .else
                  end // .if
                  else begin
                    if AssocVarValue = nil then begin
                      PINTEGER(Params[1].Value)^  :=  0;
                    end // .if
                    else begin
                      PINTEGER(Params[1].Value)^  :=  AssocVarValue.IntValue;
                    end; // .else
                  end; // .else
                end // .if
                else begin
                  if AssocVarValue = nil then begin
                    AssocVarValue           :=  TAssocVar.Create;
                    AssocMem[AssocVarName]  :=  AssocVarValue;
                  end; // .if
                  
                  if Params[1].IsStr then begin
                    if Params[1].ParamModifier <> MODIFIER_CONCAT then begin
                      AssocVarValue.StrValue  :=  pchar(Params[1].Value);
                    end // .if
                    else begin
                      AssocVarValue.StrValue := AssocVarValue.StrValue + pchar(Params[1].Value);
                    end; // .else
                  end // .if
                  else begin
                    ModifyWithIntParam(AssocVarValue.IntValue, Params[1]);
                  end; // .else
                end; // .else
              end; // .if
            end; // .case 2
        else
          result  :=  FALSE;
          Error   :=  'Invalid number of command parameters';
        end; // .switch
      end; // .case "W"
    'D':
      begin
        GetGameState(GameState);
        
        if GameState.CurrentDlgId = ADVMAP_DLGID then begin
          Erm.ExecErmCmd('UN:R1;');
        end // .if
        else if GameState.CurrentDlgId = TOWN_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R4;');
        end // .ELSEIF
        else if GameState.CurrentDlgId = HERO_SCREEN_DLGID then begin
          Erm.ExecErmCmd('UN:R3/-1;');
        end // .ELSEIF
        else if GameState.CurrentDlgId = HERO_MEETING_SCREEN_DLGID then begin
          Heroes.RedrawHeroMeetingScreen;
        end; // .ELSEIF
      end; // .case "D"
  else
    result  :=  FALSE;
    Error   :=  'Unknown command "' + Cmd +'".';
  end; // .switch Cmd
  
  if not result then begin
    Error :=  'Error executing Era command SN:' + Cmd + ':'#13#10 + Error;
    Utils.CopyMem(Length(Error) + 1, pointer(Error), @ErrBuf);
    Err := @ErrBuf;
  end; // .if
end; // .function ExtendedEraService

procedure OnBeforeErmInstructions (Event: PEvent); stdcall;
begin
  Slots.Clear;
  AssocMem.Clear;
end; // .procedure OnBeforeErmInstructions

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
      end // .if
      else begin
        for i:=0 to NumItems - 1 do begin
          StrLen  :=  Length(Slot.StrItems[i]);
          Stores.WriteSavegameSection(sizeof(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          
          if StrLen > 0 then begin
            Stores.WriteSavegameSection(StrLen, pointer(Slot.StrItems[i]), SLOTS_SAVE_SECTION);
          end; // .if
        end; // .for
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

procedure OnSavegameWrite (Event: PEvent); stdcall;
begin
  SaveSlots;
  SaveAssocMem;
end; // .procedure OnSavegameWrite

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
      end // .if
      else begin
        for y:=0 to NumItems - 1 do begin
          Stores.ReadSavegameSection(sizeof(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          SetLength(Slot.StrItems[y], StrLen);
          Stores.ReadSavegameSection(StrLen, pointer(Slot.StrItems[y]), SLOTS_SAVE_SECTION);
        end; // .for
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
    end // .if
    else begin
      SysUtils.FreeAndNil(AssocVarValue);
    end; // .else
  end; // .for
end; // .procedure LoadAssocMem

procedure OnSavegameRead (Event: PEvent); stdcall;
begin
  LoadSlots;
  LoadAssocMem;
end; // .procedure OnSavegameRead

(*function HookFindErm_NewReceivers (Hook: TLoHook; Context: PHookContext): integer; stdcall;
const
  FuncParseParams = $73FDDC; // int cdecl f (Mes& M)
  
var
  NumParams: integer;

begin
  if  then begin
    // M.c[0]=':';
    PCharByte(Context.EBP - $8C])^ := ':';
    // Ind=M.i;
    PINTEGER(Context.EBP - $35C)^ := PINTEGER(Context.EBP - $318)^;
    // Num=GetNumAutoFl(&M);
    NumParams := PatchApi.Call(PatchApi.CDECL_, FuncParseParams, [Context.EBP - $35C]);
    // ToDoPo = 0
    PINTEGER(Context.EBP - $358)^ := 0;
    // ParSet = Num
    PINTEGER(Context.EBP - $3F8)^ := NumParams;
  end // .if
  else begin
    
  end; // .else
  // BREKA IS JUMP to JMP SHORT 0074B8C5
  result  :=  EXEC_DEFAULT;
end; // .function HookFindErm_NewReceivers*)

procedure OnBeforeWoG (Event: PEvent); stdcall;
begin
  (*Core.p.WriteLoHook($74B6B2, @HookFindErm_NewReceivers);*)
end; // .procedure OnBeforeWoG

begin
  (*NewReceivers  :=  DataLib.NewObjDict(Utils.OWNS_ITEMS);*)

  Slots     :=  AssocArrays.NewStrictObjArr(TSlot);
  AssocMem  :=  AssocArrays.NewStrictAssocArr(TAssocVar);
  
  (*GameExt.RegisterHandler(OnBeforeWoG, 'OnBeforeWoG');*)
  GameExt.RegisterHandler(OnBeforeErmInstructions, 'OnBeforeErmInstructions');
  GameExt.RegisterHandler(OnSavegameWrite,         'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead,          'OnSavegameRead');
end.
