UNIT AdvErm;
{
DESCRIPTION:  Era custom Memory implementation
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Math, Utils, AssocArrays, DataLib,
  PatchApi, Core, GameExt, Erm, Stores, Heroes;

CONST
  SPEC_SLOT = -1;
  NO_SLOT   = -1;
  
  IS_TEMP   = 0;
  NOT_TEMP  = 1;
  
  IS_STR    = TRUE;
  OPER_GET  = TRUE;
  
  SLOTS_SAVE_SECTION  = 'EraSlots';
  ASSOC_SAVE_SECTION  = 'EraAssoc';
  
  (* TParamModifier *)
  NO_MODIFIER     = 0;
  MODIFIER_ADD    = 1;
  MODIFIER_SUB    = 2;
  MODIFIER_MUL    = 3;
  MODIFIER_DIV    = 4;
  MODIFIER_CONCAT = 5;


TYPE
  (* IMPORT *)
  TObjDict = DataLib.TObjDict;

  TErmCmdContext = PACKED RECORD
    
  END; // .RECORD TErmCmdContext

  TReceiverHandler = PROCEDURE;

  TVarType  = (INT_VAR, STR_VAR);
  
  TSlot = CLASS
    ItemsType:  TVarType;
    IsTemp:     BOOLEAN;
    IntItems:   ARRAY OF INTEGER;
    StrItems:   ARRAY OF STRING;
  END; // .CLASS TSlot
  
  TAssocVar = CLASS
    IntValue: INTEGER;
    StrValue: STRING;
  END; // .CLASS TAssocVar
  
  TServiceParam = PACKED RECORD
    IsStr:          BOOLEAN;
    OperGet:        BOOLEAN;
    Dummy:          WORD;
    Value:          INTEGER;
    StrValue:       PCHAR;
    ParamModifier:  INTEGER;
  END; // .RECORD TServiceParam

  PServiceParams  = ^TServiceParams;
  TServiceParams  = ARRAY [0..23] OF TServiceParam;


FUNCTION ExtendedEraService
(
      Cmd:        CHAR;
      NumParams:  INTEGER;
      Params:     PServiceParams;
  OUT Err:        PCHAR
): BOOLEAN; STDCALL;


EXPORTS
  ExtendedEraService;

  
(***) IMPLEMENTATION (***)


VAR
{O} NewReceivers: {O} TObjDict {OF TErmCmdHandler};

{O} Slots:      {O} AssocArrays.TObjArray {OF TSlot};
{O} AssocMem:   {O} AssocArrays.TAssocArray {OF TAssocVar};
    FreeSlotN:  INTEGER = SPEC_SLOT - 1;


PROCEDURE RegisterReceiver (ReceiverName: INTEGER; ReceiverHandler: TReceiverHandler);
VAR
  OldReceiverHandler: TReceiverHandler;
   
BEGIN
  OldReceiverHandler := NewReceivers[Ptr(ReceiverName)];

  IF @OldReceiverHandler = NIL THEN BEGIN
    NewReceivers[Ptr(ReceiverName)] := @ReceiverHandler;
  END // .IF
  ELSE BEGIN
    Erm.ShowMessage('Receiver "' + CHR(ReceiverName AND $FF) + CHR(ReceiverName SHR 8 AND $FF) + '" is already registered!');
  END; // .ELSE
END; // .PROCEDURE RegisterReceiver
    
PROCEDURE ModifyWithIntParam (VAR Dest: INTEGER; VAR Param: TServiceParam);
BEGIN
  CASE Param.ParamModifier OF 
    NO_MODIFIER:  Dest := Param.Value;
    MODIFIER_ADD: Dest := Dest + Param.Value;
    MODIFIER_SUB: Dest := Dest - Param.Value;
    MODIFIER_MUL: Dest := Dest * Param.Value;
    MODIFIER_DIV: Dest := Dest DIV Param.Value;
  END; // .SWITCH Paramo.ParamModifier
END; // .PROCEDURE ModifyWithParam
    
FUNCTION CheckCmdParams (Params: PServiceParams; CONST Checks: ARRAY OF BOOLEAN): BOOLEAN;
VAR
  i:  INTEGER;

BEGIN
  {!} ASSERT(Params <> NIL);
  {!} ASSERT(NOT ODD(LENGTH(Checks)));
  RESULT  :=  TRUE;
  i       :=  0;
  
  WHILE RESULT AND (i <= HIGH(Checks)) DO BEGIN
    RESULT  :=
      (Params[i SHR 1].IsStr  = Checks[i])  AND
      (Params[i SHR 1].OperGet = Checks[i + 1]);
    
    i :=  i + 2;
  END; // .WHILE
END; // .FUNCTION CheckCmdParams

FUNCTION GetSlotItemsCount (Slot: TSlot): INTEGER;
BEGIN
  {!} ASSERT(Slot <> NIL);
  IF Slot.ItemsType = INT_VAR THEN BEGIN
    RESULT  :=  LENGTH(Slot.IntItems);
  END // .IF
  ELSE BEGIN
    RESULT  :=  LENGTH(Slot.StrItems);
  END; // .ELSE
END; // .FUNCTION GetSlotItemsCount

PROCEDURE SetSlotItemsCount (NewNumItems: INTEGER; Slot: TSlot);
BEGIN
  {!} ASSERT(NewNumItems >= 0);
  {!} ASSERT(Slot <> NIL);
  IF Slot.ItemsType = INT_VAR THEN BEGIN
    SetLength(Slot.IntItems, NewNumItems);
  END // .IF
  ELSE BEGIN
    SetLength(Slot.StrItems, NewNumItems);
  END; // .ELSE
END; // .PROCEDURE SetSlotItemsCount

FUNCTION NewSlot (ItemsCount: INTEGER; ItemsType: TVarType; IsTemp: BOOLEAN): TSlot;
BEGIN
  {!} ASSERT(ItemsCount >= 0);
  RESULT            :=  TSlot.Create;
  RESULT.ItemsType  :=  ItemsType;
  RESULT.IsTemp     :=  IsTemp;
  
  SetSlotItemsCount(ItemsCount, RESULT);
END; // .FUNCTION NewSlot
  
FUNCTION GetSlot (SlotN: INTEGER; OUT {U} Slot: TSlot; OUT Error: STRING): BOOLEAN;
BEGIN
  {!} ASSERT(Slot = NIL);
  Slot    :=  Slots[Ptr(SlotN)];
  RESULT  :=  Slot <> NIL;
  
  IF NOT RESULT THEN BEGIN
    Error :=  'Slot #' + SysUtils.IntToStr(SlotN) + ' does not exist.';
  END; // .IF
END; // .FUNCTION GetSlot 

FUNCTION AllocSlot (ItemsCount: INTEGER; ItemsType: TVarType; IsTemp: BOOLEAN): INTEGER;
BEGIN
  WHILE Slots[Ptr(FreeSlotN)] <> NIL DO BEGIN
    DEC(FreeSlotN);
    
    IF FreeSlotN > 0 THEN BEGIN
      FreeSlotN :=  SPEC_SLOT - 1;
    END; // .IF
  END; // .WHILE
  
  Slots[Ptr(FreeSlotN)] :=  NewSlot(ItemsCount, ItemsType, IsTemp);
  RESULT                :=  FreeSlotN;
  DEC(FreeSlotN);
  
  IF FreeSlotN > 0 THEN BEGIN
    FreeSlotN :=  SPEC_SLOT - 1;
  END; // .IF
END; // .FUNCTION AllocSlot

FUNCTION ExtendedEraService
(
      Cmd:        CHAR;
      NumParams:  INTEGER;
      Params:     PServiceParams;
  OUT Err:        PCHAR
): BOOLEAN;

VAR
{U} Slot:               TSlot;
{U} AssocVarValue:      TAssocVar;
    AssocVarName:       STRING;
    Error:              STRING;
    StrLen:             INTEGER;
    NewSlotItemsCount:  INTEGER;
    GameState:          TGameState;

BEGIN
  Slot          :=  NIL;
  AssocVarValue :=  NIL;
  // * * * * * //
  RESULT  :=  TRUE;
  Error   :=  'Invalid command parameters.';
  
  CASE Cmd OF 
    'M':
      BEGIN
        CASE NumParams OF
          // M; delete all slots
          0:
            BEGIN
              Slots.Clear;
            END; // .CASE 0
          // M(Slot); delete specified slot
          1:
            BEGIN
              RESULT  :=
                CheckCmdParams(Params, [NOT IS_STR, NOT OPER_GET])  AND
                (Params[0].Value <> SPEC_SLOT);
              
              IF RESULT THEN BEGIN
                Slots.DeleteItem(Ptr(Params[0].Value));
              END; // .IF
            END; // .CASE 1
          // M(Slot)/[?]ItemsCount; analog of SetLength/LENGTH
          2:
            BEGIN
              RESULT  :=
                CheckCmdParams(Params, [NOT IS_STR, NOT OPER_GET])  AND
                (NOT Params[1].IsStr)                               AND
                (Params[1].OperGet OR (Params[1].Value >= 0));

              IF RESULT THEN BEGIN          
                IF Params[1].OperGet THEN BEGIN
                  Slot  :=  Slots[Ptr(Params[0].Value)];
                  
                  IF Slot <> NIL THEN BEGIN
                    PINTEGER(Params[1].Value)^  :=  GetSlotItemsCount(Slot);
                  END // .IF
                  ELSE BEGIN
                    PINTEGER(Params[1].Value)^  :=  NO_SLOT;
                  END; // .ELSE
                  END // .IF
                ELSE BEGIN
                  RESULT  :=  GetSlot(Params[0].Value, Slot, Error);
                  
                  IF RESULT THEN BEGIN
                    NewSlotItemsCount := GetSlotItemsCount(Slot);
                    ModifyWithIntParam(NewSlotItemsCount, Params[1]);
                    SetSlotItemsCount(NewSlotItemsCount, Slot);
                  END; // .IF
                END; // .ELSE
              END; // .IF
            END; // .CASE 2
          // M(Slot)/(VarN)/[?](Value) OR M(Slot)/?addr/(VarN)
          3:
            BEGIN
              RESULT  :=
                CheckCmdParams(Params, [NOT IS_STR, NOT OPER_GET])  AND
                GetSlot(Params[0].Value, Slot, Error)               AND
                (NOT Params[1].IsStr);
              
              IF RESULT THEN BEGIN
                IF Params[1].OperGet THEN BEGIN
                  RESULT  :=
                    (NOT Params[2].OperGet) AND
                    (NOT Params[2].IsStr)   AND
                    Math.InRange(Params[2].Value, 0, GetSlotItemsCount(Slot) - 1);
                  
                  IF RESULT THEN BEGIN
                    IF Slot.ItemsType = INT_VAR THEN BEGIN
                      PPOINTER(Params[1].Value)^  :=  @Slot.IntItems[Params[2].Value];
                    END // .IF
                    ELSE BEGIN
                      PPOINTER(Params[1].Value)^  :=  POINTER(Slot.StrItems[Params[2].Value]);
                    END; // .ELSE
                  END; // .IF
                END // .IF
                ELSE BEGIN
                  RESULT  :=
                    (NOT Params[1].OperGet) AND
                    (NOT Params[1].IsStr)   AND
                    Math.InRange(Params[1].Value, 0, GetSlotItemsCount(Slot) - 1);
                  
                  IF RESULT THEN BEGIN
                    IF Params[2].OperGet THEN BEGIN
                      IF Slot.ItemsType = INT_VAR THEN BEGIN
                        IF Params[2].IsStr THEN BEGIN
                          Windows.LStrCpy
                          (
                            Ptr(Params[2].Value),
                            Ptr(Slot.IntItems[Params[1].Value])
                          );
                        END // .IF
                        ELSE BEGIN
                          PINTEGER(Params[2].Value)^  :=  Slot.IntItems[Params[1].Value];
                        END; // .ELSE
                      END // .IF
                      ELSE BEGIN
                        Windows.LStrCpy
                        (
                          Ptr(Params[2].Value),
                          PCHAR(Slot.StrItems[Params[1].Value])
                        );
                      END; // .ELSE
                    END // .IF
                    ELSE BEGIN
                      IF Slot.ItemsType = INT_VAR THEN BEGIN
                        IF Params[2].IsStr THEN BEGIN
                          IF Params[2].ParamModifier = MODIFIER_CONCAT THEN BEGIN
                            StrLen := SysUtils.StrLen(PCHAR(Slot.IntItems[Params[1].Value]));
                            
                            Windows.LStrCpy
                            (
                              Utils.PtrOfs(Ptr(Slot.IntItems[Params[1].Value]), StrLen),
                              Ptr(Params[2].Value)
                            );
                          END // .IF
                          ELSE BEGIN
                            Windows.LStrCpy
                            (
                              Ptr(Slot.IntItems[Params[1].Value]),
                              Ptr(Params[2].Value)
                            );
                          END; // .ELSE
                        END // .IF
                        ELSE BEGIN
                          Slot.IntItems[Params[1].Value]  :=  Params[2].Value;
                        END; // .ELSE
                      END // .IF
                      ELSE BEGIN
                        IF Params[2].Value = 0 THEN BEGIN
                          Params[2].Value := INTEGER(PCHAR(''));
                        END; // .IF
                        
                        IF Params[2].ParamModifier = MODIFIER_CONCAT THEN BEGIN
                          Slot.StrItems[Params[1].Value] := Slot.StrItems[Params[1].Value] +
                                                            PCHAR(Params[2].Value);
                        END // .IF
                        ELSE BEGIN
                          Slot.StrItems[Params[1].Value] := PCHAR(Params[2].Value);
                        END; // .ELSE
                      END; // .ELSE
                    END; // .ELSE
                  END; // .IF
                END; // .ELSE
              END; // .IF
            END; // .CASE 3
          4:
            BEGIN
              RESULT  :=  CheckCmdParams
              (
                Params,
                [
                  NOT IS_STR,
                  NOT OPER_GET,
                  NOT IS_STR,
                  NOT OPER_GET,
                  NOT IS_STR,
                  NOT OPER_GET,
                  NOT IS_STR,
                  NOT OPER_GET
                ]
              ) AND
              (Params[0].Value >= SPEC_SLOT)                        AND
              (Params[1].Value >= 0)                                AND
              Math.InRange(Params[2].Value, 0, ORD(HIGH(TVarType))) AND
              ((Params[3].Value = IS_TEMP) OR (Params[3].Value = NOT_TEMP));
              
              IF RESULT THEN BEGIN
                IF Params[0].Value = SPEC_SLOT THEN BEGIN
                  Erm.v[1]  :=  AllocSlot
                  (
                    Params[1].Value, TVarType(Params[2].Value), Params[3].Value = IS_TEMP
                  );
                END // .IF
                ELSE BEGIN
                  Slots[Ptr(Params[0].Value)] :=  NewSlot
                  (
                    Params[1].Value, TVarType(Params[2].Value), Params[3].Value = IS_TEMP
                  );
                END; // .ELSE
              END; // .IF
            END; // .CASE 4
        ELSE
          RESULT  :=  FALSE;
          Error   :=  'Invalid number of parameters.';
        END; // .SWITCH NumParams
      END; // .CASE "M"
    'K':
      BEGIN
        CASE NumParams OF 
          // C(str)/?(len)
          2:
            BEGIN
              RESULT  :=  (NOT Params[0].OperGet) AND (NOT Params[1].IsStr) AND (Params[1].OperGet);
              
              IF RESULT THEN BEGIN
                PINTEGER(Params[1].Value)^  :=  SysUtils.StrLen(POINTER(Params[0].Value));
              END; // .IF
            END; // .CASE 2
          // C(str)/(ind)/[?](strchar)
          3:
            BEGIN
              RESULT  :=
                (NOT Params[0].OperGet) AND
                (NOT Params[1].IsStr)   AND
                (NOT Params[1].OperGet) AND
                (Params[1].Value >= 0)  AND
                (Params[2].IsStr);
              
              IF RESULT THEN BEGIN
                IF Params[2].OperGet THEN BEGIN
                  PCHAR(Params[2].Value)^     :=  PEndlessCharArr(Params[0].Value)[Params[1].Value];
                  PCHAR(Params[2].Value + 1)^ :=  #0;
                END // .IF
                ELSE BEGIN
                  PEndlessCharArr(Params[0].Value)[Params[1].Value] :=  PCHAR(Params[2].Value)^;
                END; // .ELSE
              END; // .IF
            END; // .CASE 3
          4:
            BEGIN
              RESULT  :=
                (NOT Params[0].IsStr)   AND
                (NOT Params[0].OperGet) AND
                (Params[0].Value >= 0);
              
              IF RESULT AND (Params[0].Value > 0) THEN BEGIN
                Utils.CopyMem(Params[0].Value, POINTER(Params[1].Value), POINTER(Params[2].Value));
              END; // .IF
            END; // .CASE 4
        ELSE
          RESULT  :=  FALSE;
          Error   :=  'Invalid number of parameters.';
        END; // .SWITCH NumParams
      END; // .CASE "K"
    'W':
      BEGIN
        CASE NumParams OF 
          // Clear all
          0:
            BEGIN
              AssocMem.Clear;
            END; // .CASE 0
          // Delete var
          1:
            BEGIN
              RESULT  :=  NOT Params[0].OperGet;
              
              IF RESULT THEN BEGIN
                IF Params[0].IsStr THEN BEGIN
                  AssocVarName  :=  PCHAR(Params[0].Value);
                END // .IF
                ELSE BEGIN
                  AssocVarName  :=  SysUtils.IntToStr(Params[0].Value);
                END; // .ELSE
                
                AssocMem.DeleteItem(AssocVarName);
              END; // .IF
            END; // .CASE 1
          // Get/Set var
          2:
            BEGIN
              RESULT  :=  NOT Params[0].OperGet;
              
              IF RESULT THEN BEGIN
                IF Params[0].IsStr THEN BEGIN
                  AssocVarName  :=  PCHAR(Params[0].Value);
                END // .IF
                ELSE BEGIN
                  AssocVarName  :=  SysUtils.IntToStr(Params[0].Value);
                END; // .ELSE
                
                AssocVarValue :=  AssocMem[AssocVarName];
                
                IF Params[1].OperGet THEN BEGIN
                  IF Params[1].IsStr THEN BEGIN
                    IF (AssocVarValue = NIL) OR (AssocVarValue.StrValue = '') THEN BEGIN
                      PCHAR(Params[1].Value)^ :=  #0;
                    END // .IF
                    ELSE BEGIN
                      Utils.CopyMem
                      (
                        LENGTH(AssocVarValue.StrValue) + 1,
                        POINTER(AssocVarValue.StrValue),
                        POINTER(Params[1].Value)
                      );
                    END; // .ELSE
                  END // .IF
                  ELSE BEGIN
                    IF AssocVarValue = NIL THEN BEGIN
                      PINTEGER(Params[1].Value)^  :=  0;
                    END // .IF
                    ELSE BEGIN
                      PINTEGER(Params[1].Value)^  :=  AssocVarValue.IntValue;
                    END; // .ELSE
                  END; // .ELSE
                END // .IF
                ELSE BEGIN
                  IF AssocVarValue = NIL THEN BEGIN
                    AssocVarValue           :=  TAssocVar.Create;
                    AssocMem[AssocVarName]  :=  AssocVarValue;
                  END; // .IF
                  
                  IF Params[1].IsStr THEN BEGIN
                    IF Params[1].ParamModifier <> MODIFIER_CONCAT THEN BEGIN
                      AssocVarValue.StrValue  :=  PCHAR(Params[1].Value);
                    END // .IF
                    ELSE BEGIN
                      AssocVarValue.StrValue := AssocVarValue.StrValue + PCHAR(Params[1].Value);
                    END; // .ELSE
                  END // .IF
                  ELSE BEGIN
                    ModifyWithIntParam(AssocVarValue.IntValue, Params[1]);
                  END; // .ELSE
                END; // .ELSE
              END; // .IF
            END; // .CASE 2
        ELSE
          RESULT  :=  FALSE;
          Error   :=  'Invalid number of parameters.';
        END; // .SWITCH
      END; // .CASE "W"
    'D':
      BEGIN
        GetGameState(GameState);
        
        IF GameState.CurrentDlgId = ADVMAP_DLGID THEN BEGIN
          Erm.ExecErmCmd('UN:R1;');
        END // .IF
        ELSE IF GameState.CurrentDlgId = TOWN_SCREEN_DLGID THEN BEGIN
          Erm.ExecErmCmd('UN:R4;');
        END // .ELSEIF
        ELSE IF GameState.CurrentDlgId = HERO_SCREEN_DLGID THEN BEGIN
          Erm.ExecErmCmd('UN:R3/-1;');
        END // .ELSEIF
        ELSE IF GameState.CurrentDlgId = HERO_MEETING_SCREEN_DLGID THEN BEGIN
          Heroes.RedrawHeroMeetingScreen;
        END; // .ELSEIF
      END; // .CASE "D"
  ELSE
    RESULT  :=  FALSE;
    Error   :=  'Unknown command "' + Cmd +'".';
  END; // .SWITCH Cmd
  
  IF NOT RESULT THEN BEGIN
    Error :=  'Error executing Era command SN:' + Cmd + ':'#13#10 + Error;
    Utils.CopyMem(LENGTH(Error) + 1, POINTER(Error), @Erm.z[1]);
    Err   :=  @Erm.z[1];
  END; // .IF
END; // .FUNCTION ExtendedEraService

PROCEDURE OnBeforeErmInstructions (Event: PEvent); STDCALL;
BEGIN
  Slots.Clear;
  AssocMem.Clear;
END; // .PROCEDURE OnBeforeErmInstructions

PROCEDURE SaveSlots;
VAR
{U} Slot:     TSlot;
    SlotN:    INTEGER;
    NumSlots: INTEGER;
    NumItems: INTEGER;
    StrLen:   INTEGER;
    i:        INTEGER;
  
BEGIN
  SlotN :=  0;
  Slot  :=  NIL;
  // * * * * * //
  NumSlots  :=  Slots.ItemCount;
  Stores.WriteSavegameSection(SIZEOF(NumSlots), @NumSlots, SLOTS_SAVE_SECTION);
  
  Slots.BeginIterate;
  
  WHILE Slots.IterateNext(POINTER(SlotN), POINTER(Slot)) DO BEGIN
    Stores.WriteSavegameSection(SIZEOF(SlotN), @SlotN, SLOTS_SAVE_SECTION);
    Stores.WriteSavegameSection(SIZEOF(Slot.ItemsType), @Slot.ItemsType, SLOTS_SAVE_SECTION);
    Stores.WriteSavegameSection(SIZEOF(Slot.IsTemp), @Slot.IsTemp, SLOTS_SAVE_SECTION);
    
    NumItems  :=  GetSlotItemsCount(Slot);
    Stores.WriteSavegameSection(SIZEOF(NumItems), @NumItems, SLOTS_SAVE_SECTION);
    
    IF (NumItems > 0) AND NOT Slot.IsTemp THEN BEGIN
      IF Slot.ItemsType = INT_VAR THEN BEGIN
        Stores.WriteSavegameSection
        (
          SIZEOF(INTEGER) * NumItems,
          @Slot.IntItems[0], SLOTS_SAVE_SECTION
        );
      END // .IF
      ELSE BEGIN
        FOR i:=0 TO NumItems - 1 DO BEGIN
          StrLen  :=  LENGTH(Slot.StrItems[i]);
          Stores.WriteSavegameSection(SIZEOF(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          
          IF StrLen > 0 THEN BEGIN
            Stores.WriteSavegameSection(StrLen, POINTER(Slot.StrItems[i]), SLOTS_SAVE_SECTION);
          END; // .IF
        END; // .FOR
      END; // .ELSE
    END; // .IF
    
    SlotN :=  0;
    Slot  :=  NIL;
  END; // .WHILE
  
  Slots.EndIterate;
END; // .PROCEDURE SaveSlots

PROCEDURE SaveAssocMem;
VAR
{U} AssocVarValue:  TAssocVar;
    AssocVarName:   STRING;
    NumVars:        INTEGER;
    StrLen:         INTEGER;
  
BEGIN
  AssocVarValue :=  NIL;
  // * * * * * //
  NumVars :=  AssocMem.ItemCount;
  Stores.WriteSavegameSection(SIZEOF(NumVars), @NumVars, ASSOC_SAVE_SECTION);
  
  AssocMem.BeginIterate;
  
  WHILE AssocMem.IterateNext(AssocVarName, POINTER(AssocVarValue)) DO BEGIN
    StrLen  :=  LENGTH(AssocVarName);
    Stores.WriteSavegameSection(SIZEOF(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    Stores.WriteSavegameSection(StrLen, POINTER(AssocVarName), ASSOC_SAVE_SECTION);
    
    Stores.WriteSavegameSection
    (
      SIZEOF(AssocVarValue.IntValue),
      @AssocVarValue.IntValue,
      ASSOC_SAVE_SECTION
    );
    
    StrLen  :=  LENGTH(AssocVarValue.StrValue);
    Stores.WriteSavegameSection(SIZEOF(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    Stores.WriteSavegameSection(StrLen, POINTER(AssocVarValue.StrValue), ASSOC_SAVE_SECTION);
    
    AssocVarValue :=  NIL;
  END; // .WHILE
  
  AssocMem.EndIterate;
END; // .PROCEDURE SaveAssocMem

PROCEDURE OnSavegameWrite (Event: PEvent); STDCALL;
BEGIN
  SaveSlots;
  SaveAssocMem;
END; // .PROCEDURE OnSavegameWrite

PROCEDURE LoadSlots;
VAR
{U} Slot:       TSlot;
    SlotN:      INTEGER;
    NumSlots:   INTEGER;
    ItemsType:  TVarType;
    IsTempSlot: BOOLEAN;
    NumItems:   INTEGER;
    StrLen:     INTEGER;
    i:          INTEGER;
    y:          INTEGER;

BEGIN
  Slot      :=  NIL;
  NumSlots  :=  0;
  // * * * * * //
  Slots.Clear;
  Stores.ReadSavegameSection(SIZEOF(NumSlots), @NumSlots, SLOTS_SAVE_SECTION);
  
  FOR i:=0 TO NumSlots - 1 DO BEGIN
    Stores.ReadSavegameSection(SIZEOF(SlotN), @SlotN, SLOTS_SAVE_SECTION);
    Stores.ReadSavegameSection(SIZEOF(ItemsType), @ItemsType, SLOTS_SAVE_SECTION);
    Stores.ReadSavegameSection(SIZEOF(IsTempSlot), @IsTempSlot, SLOTS_SAVE_SECTION);
    
    Stores.ReadSavegameSection(SIZEOF(NumItems), @NumItems, SLOTS_SAVE_SECTION);
    
    Slot              :=  NewSlot(NumItems, ItemsType, IsTempSlot);
    Slots[Ptr(SlotN)] :=  Slot;
    SetSlotItemsCount(NumItems, Slot);
    
    IF NOT IsTempSlot AND (NumItems > 0) THEN BEGIN
      IF ItemsType = INT_VAR THEN BEGIN
        Stores.ReadSavegameSection
        (
          SIZEOF(INTEGER) * NumItems,
          @Slot.IntItems[0],
          SLOTS_SAVE_SECTION
        );
      END // .IF
      ELSE BEGIN
        FOR y:=0 TO NumItems - 1 DO BEGIN
          Stores.ReadSavegameSection(SIZEOF(StrLen), @StrLen, SLOTS_SAVE_SECTION);
          SetLength(Slot.StrItems[y], StrLen);
          Stores.ReadSavegameSection(StrLen, POINTER(Slot.StrItems[y]), SLOTS_SAVE_SECTION);
        END; // .FOR
      END; // .ELSE
    END; // .IF
  END; // .FOR
END; // .PROCEDURE LoadSlots

PROCEDURE LoadAssocMem;
VAR
{O} AssocVarValue:  TAssocVar;
    AssocVarName:   STRING;
    NumVars:        INTEGER;
    StrLen:         INTEGER;
    i:              INTEGER;
  
BEGIN
  AssocVarValue :=  NIL;
  NumVars       :=  0;
  // * * * * * //
  AssocMem.Clear;
  Stores.ReadSavegameSection(SIZEOF(NumVars), @NumVars, ASSOC_SAVE_SECTION);
  
  FOR i:=0 TO NumVars - 1 DO BEGIN
    AssocVarValue :=  TAssocVar.Create;
    
    Stores.ReadSavegameSection(SIZEOF(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    SetLength(AssocVarName, StrLen);
    Stores.ReadSavegameSection(StrLen, POINTER(AssocVarName), ASSOC_SAVE_SECTION);
    
    Stores.ReadSavegameSection
    (
      SIZEOF(AssocVarValue.IntValue),
      @AssocVarValue.IntValue,
      ASSOC_SAVE_SECTION
    );
    
    Stores.ReadSavegameSection(SIZEOF(StrLen), @StrLen, ASSOC_SAVE_SECTION);
    SetLength(AssocVarValue.StrValue, StrLen);
    Stores.ReadSavegameSection(StrLen, POINTER(AssocVarValue.StrValue), ASSOC_SAVE_SECTION);
    
    IF (AssocVarValue.IntValue <> 0) OR (AssocVarValue.StrValue <> '') THEN BEGIN
      AssocMem[AssocVarName]  :=  AssocVarValue; AssocVarValue  :=  NIL;
    END // .IF
    ELSE BEGIN
      SysUtils.FreeAndNil(AssocVarValue);
    END; // .ELSE
  END; // .FOR
END; // .PROCEDURE LoadAssocMem

PROCEDURE OnSavegameRead (Event: PEvent); STDCALL;
BEGIN
  LoadSlots;
  LoadAssocMem;
END; // .PROCEDURE OnSavegameRead

(*FUNCTION HookFindErm_NewReceivers (Hook: TLoHook; Context: PHookContext): INTEGER; STDCALL;
CONST
  FuncParseParams = $73FDDC; // int cdecl f (Mes& M)
  
VAR
  NumParams: INTEGER;

BEGIN
  IF  THEN BEGIN
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
  END // .IF
  ELSE BEGIN
    
  END; // .ELSE
  // BREKA IS JUMP TO JMP SHORT 0074B8C5
  RESULT  :=  EXEC_DEFAULT;
END; // .FUNCTION HookFindErm_NewReceivers*)

PROCEDURE OnBeforeWoG (Event: PEvent); STDCALL;
BEGIN
  (*Core.p.WriteLoHook($74B6B2, @HookFindErm_NewReceivers);*)
END; // .PROCEDURE OnBeforeWoG

BEGIN
  (*NewReceivers  :=  DataLib.NewObjDict(Utils.OWNS_ITEMS);*)

  Slots     :=  AssocArrays.NewStrictObjArr(TSlot);
  AssocMem  :=  AssocArrays.NewStrictAssocArr(TAssocVar);
  
  (*GameExt.RegisterHandler(OnBeforeWoG, 'OnBeforeWoG');*)
  GameExt.RegisterHandler(OnBeforeErmInstructions, 'OnBeforeErmInstructions');
  GameExt.RegisterHandler(OnSavegameWrite, 'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead, 'OnSavegameRead');
END.
