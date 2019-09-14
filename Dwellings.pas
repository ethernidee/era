unit Dwellings;
(*
  Integration and reworking of MoP Battery plugin.
*)


(***)  interface  (***)

uses
  SysUtils, Math, Utils, Alg, DataLib,
  PatchApi, Core, ApiJack, EventMan, GameExt, Erm,
  Heroes, AdvErm, DlgMes {FIXME};


(***)  implementation  (***)


type
  (* Import *)
  TDict = DataLib.TDict;

const
  MAX_NUM_TOWNS          = 200;
  NUM_DWELLINGS_PER_TOWN = 14;

  SOURCE_DWELLING_FIRST = 0;
  SOURCE_DWELLING_LAST  = MAX_NUM_TOWNS * NUM_DWELLINGS_PER_TOWN - 1;
  SOURCE_EXTERNAL_0     = 9000;
  SOURCE_EXTERNAL_1     = SOURCE_EXTERNAL_0 + 1;
  SOURCE_EXTERNAL_2     = SOURCE_EXTERNAL_0 + 2;
  SOURCE_EXTERNAL_3     = SOURCE_EXTERNAL_0 + 3;
  SOURCE_FIRST_CUSTOM   = 10000;

  RECRUIT_TARGET_TOWN     = 0;
  RECRUIT_TARGET_HERO     = 1;
  RECRUIT_TARGET_CUSTOM   = 2;
  RECRUIT_TARGET_EXTERNAL = 3;

  DLG_FLAG_CLOSE_ON_BUY       = 1;
  DLG_FLAG_AUTO_UPDATE_ADVMAP = 2;
  DLG_FLAGS_ALL               = DLG_FLAG_CLOSE_ON_BUY or DLG_FLAG_AUTO_UPDATE_ADVMAP;

  IS_DISPOSABLE     = true;
  IS_NON_DISPOSABLE = not IS_DISPOSABLE;

type
  PRecruitMonsDlgTarget = ^TRecruitMonsDlgTarget;
  TRecruitMonsDlgTarget = packed record
    MonTypes: array [0..6] of integer;
    MonNums:  array [0..6] of integer;
  end;

  PRecruitMonsDlgSetup = ^TRecruitMonsDlgSetup;
  TRecruitMonsDlgSetup = packed record
    VirtTable:       pointer;
    _Zero1:          integer;
    _Zero2:          integer;
    _MinOne1:        integer;
    _MinOne2:        integer;
    ClassName:       array [0..31] of char;
    PlayAnimation:   integer; // +52, 0 or 1. 0 means some controls inactive and def animation frozen. Can be changed any time
    _Unk1:           array [0..3] of integer;
    ObjType:         integer; // +72 OBJTYPE_TOWN for Town (CloseOnBuy=true, no advmap update), -1 for any other (CloseOnBuy=false, advmap update). Converted to DLG_FLAG_XXX set
    _Unk4:           integer;
    SelectedMonType: integer;
    SelectedMonNum:  pword;
    SelectedMonSlot: integer;
    MonTypes:        array [0..3] of integer; // +92
    MonNums:         array [0..3] of pword;
    _Unk2:           array [0..7] of byte;
    Cost:            integer;                 // +132
    Resource:        integer;                 // +136
    ResourceCost:    integer;                 // +140
    IsTownScreen:    integer;                 // +144, 0 for kingdom overview
    _Unk3:           integer;
    Target:          PRecruitMonsDlgTarget;
    _One1:           integer;
    _Unk5:           array [0..2] of integer;
    MaxQuantity:     integer;
    TotalPrice:      integer;
    MonQuantityDup:  integer;
    MonQuantity:     integer;
  end; // .orecord TRecruitMonsDlgSetup

  PRecruitMonsSlot = ^TRecruitMonsSlot;
  TRecruitMonsSlot = record
    MonType:    integer;
    OrigMonNum: integer;
    SourceId:   integer;
    SourceNum:  pword;
  end;

  TRecruitMonsSlots = array [0..3] of TRecruitMonsSlot;

  TSourceAllocationCell = record
        SourceId:   integer;
    {n} SourceAddr: pword;    // nil means empty cell
        Disposable: LONGBOOL;
  end;

  TRecruitMonsDlgOpenEvent = record
    {O} Mem:          {O} TDict {of AdvErm.TAssocVar};
    DlgSetup:         PRecruitMonsDlgSetup;
    Slots:            TRecruitMonsSlots;
    SelectedSlot:     integer;
    TownId:           integer; // -1 for undetected town
    DwellingId:       integer; // 0..6 for non-upgraded, 7..13 for upgraded, or any other custom ID, -1 for none
    DlgSlotToSlotMap: array [0..3] of integer; // map of dialog slot index => event slot index
    TargetType:       integer; // one of RECRUIT_TARGET_XXX constants
    TargetId:         integer; // id of hero or town, -1 in other cases
    Target:           PRecruitMonsDlgTarget;
    CustomTarget:     TRecruitMonsDlgTarget;
    ReadOnly:         boolean;
    Inited:           boolean;
    Id:               integer; // unique autoincrementing ID

    (* Mapper of SourceId => SourceAddr. Can store up to 4 unique external sources and 4 slot sources *)
    SourceAllocationTable: array [0..7] of TSourceAllocationCell;

    (* Storage of MonNum to use for custom sourceIds *)
    SourceLocalStorage: array [0..3] of integer;

    procedure Reset;
    procedure InitTargetFromDlg (DlgSetup: PRecruitMonsDlgSetup);
    procedure InitSlotsFromDlgSetup (DlgSetup: PRecruitMonsDlgSetup);
    procedure InitSlotFromDlgSetup (DlgSetup: PRecruitMonsDlgSetup; SlotInd: integer);
    procedure ResetSlot (SlotInd: integer);
    procedure ShiftSlots (Offset: integer);
    function  GcSources: boolean;
    procedure AllocSource (SourceId: integer; SourceAddr: pword; Disposable: boolean);
    function  FindSourceIdByAddr ({n} SourceAddr: pword; var {out} SourceId: integer): boolean;
    procedure RememberOrigMonParams;
    function  HasNonEmptySlot: boolean;
    procedure ApplySlotsToDlg (DlgSetup: PRecruitMonsDlgSetup);
    procedure ApplySlotToDlg (DlgSetup: PRecruitMonsDlgSetup; SlotInd, DlgSlotInd: integer);
    procedure UpdateSlotSourceAddr (SlotInd: integer);
  end; // .record TRecruitMonsDlgOpenEvent

  POneBasedCmdParams  = ^TOneBasedCmdParams;
  TOneBasedCmdParams  = array [1..24] of GameExt.TServiceParam;

var
  ZvsRecruitMonsDlgSetupPtr: ^PRecruitMonsDlgSetup = Ptr($836A18);
  ZvsTownManagerPtr:      ppointer           = Ptr($83A86C);
  
  RecruitMonsDlgOpenEvent:               TRecruitMonsDlgOpenEvent;
  RecruitMonsDlgOpenEventAutoId:         integer = 0;
  NextRecruitMonsDlgOpenEventTownId:     integer = -1;
  NextRecruitMonsDlgOpenEventDwellingId: integer = -1;

type
  PCastleDwellingsMons = ^TCastleDwellingsMons;
  TCastleDwellingsMons = array [0..1, 0..6] of word;

function IsAddrFromStructArr (Addr, FirstStruct, EndAddr: pointer): boolean;
begin
  result := (cardinal(Addr) >= cardinal(FirstStruct)) and (cardinal(Addr) < cardinal(EndAddr));
end;

function GetCurrentCastleDwellingsMons: {n} PCastleDwellingsMons;
begin
  result := ppointer(pinteger(Heroes.TOWN_MANAGER)^ + $38)^;
  {!} Assert(result <> nil, 'Cannot get current castle structure address');
  Inc(integer(result), $16);
end;

function IsValidTownId (Id: integer): boolean;
begin
  result := Math.InRange(Id, 0, Heroes.ZvsCountTowns() - 1);
end;

function IsValidEraSourceId (SourceId: integer): boolean;
begin
  result := Math.InRange(SourceId, SOURCE_EXTERNAL_0, SOURCE_EXTERNAL_3) or Math.InRange(SourceId, SOURCE_DWELLING_FIRST, Heroes.ZvsCountTowns() * NUM_DWELLINGS_PER_TOWN - 1);
end;

function DetectKnownSourceIdByAddr (SourceId: integer; {n} SourceNum: pword): integer;
var
{n} Towns:  Heroes.PTowns;
    TownId: integer;

begin
  Towns := Heroes.ZvsGetTowns;
  // * * * * * //
  result := SourceId;

  if (cardinal(SourceNum) >= cardinal(Towns)) and (cardinal(SourceNum) < cardinal(@Towns[Heroes.ZvsCountTowns()])) then begin
    TownId := (cardinal(SourceNum) - cardinal(Towns)) div sizeof(Heroes.TTown);
    result := TownId * NUM_DWELLINGS_PER_TOWN + integer((cardinal(SourceNum) - cardinal(@Towns[TownId].DwellingMons)) div sizeof(word));
  end;
end;

function GetMonCost (MonType: integer; out ResType, ResCost: integer): integer;
var
  i: integer;

begin
  result  := Heroes.MonInfos[MonType].CostRes[Heroes.RES_GOLD];
  ResType := -1;
  ResCost := 0;

  for i := Heroes.RES_FIRST to Heroes.RES_LAST - 1 do begin
    if Heroes.MonInfos[MonType].CostRes[i] <> 0 then begin
      ResType := i;
      ResCost := Heroes.MonInfos[MonType].CostRes[i];
      exit;
    end;
  end;
end;

procedure SelectDlgSlot (DlgSetup: PRecruitMonsDlgSetup; SlotInd: integer);
begin
  {!} Assert(DlgSetup <> nil);
  DlgSetup.SelectedMonSlot := SlotInd;
  DlgSetup.SelectedMonType := DlgSetup.MonTypes[SlotInd];
  DlgSetup.SelectedMonNum  := DlgSetup.MonNums[SlotInd];
  DlgSetup.Cost            := GetMonCost(DlgSetup.MonTypes[SlotInd], DlgSetup.Resource, DlgSetup.ResourceCost);
end;

(* Returns true if at least single free cell is found/got *)
function TRecruitMonsDlgOpenEvent.GcSources: boolean;
var
  SourceId:  integer;
  IsGarbage: boolean;
  i, j:      integer;

begin
  result := false;

  for i := 0 to High(Self.SourceAllocationTable) do begin
    if Self.SourceAllocationTable[i].SourceAddr <> nil then begin
      if Self.SourceAllocationTable[i].Disposable then begin
        SourceId  := Self.SourceAllocationTable[i].SourceId;
        IsGarbage := true;

        for j := 0 to High(Self.Slots) do begin
          if Self.Slots[j].SourceId = SourceId then begin
            IsGarbage := false;
            break;
          end;
        end;

        if IsGarbage then begin
          result := true;

          with Self.SourceAllocationTable[i] do begin
            SourceId   := 0;
            SourceAddr := nil;
          end;
        end;
      end; // .if
    end else begin
      result := true;
    end; // .else
  end; // .for
end; // .function TRecruitMonsDlgOpenEvent.GcSources

procedure TRecruitMonsDlgOpenEvent.AllocSource (SourceId: integer; SourceAddr: pword; Disposable: boolean);
var
  i: integer;

begin
  for i := 0 to High(Self.SourceAllocationTable) do begin
    if Self.SourceAllocationTable[i].SourceAddr = nil then begin
      Self.SourceAllocationTable[i].SourceId   := SourceId;
      Self.SourceAllocationTable[i].SourceAddr := SourceAddr;
      Self.SourceAllocationTable[i].Disposable := Disposable;
      exit;
    end;
  end;

  {!} Assert(Self.GcSources(), '[IMPOSSIBLE] TRecruitMonsDlgOpenEvent.GcSources failed for source ID = ' + SysUtils.IntToStr(SourceId));
  Self.AllocSource(SourceId, SourceAddr, Disposable);
end;

procedure TRecruitMonsDlgOpenEvent.UpdateSlotSourceAddr (SlotInd: integer);
var
  SourceId:     integer;
  SourceNum:    pword;
  DwellingId:   integer;
  NewChainAddr: pword;
  i:            integer;

begin
  {!} Assert(Math.InRange(SlotInd, 0, High(Self.Slots)));
  SourceNum    := @Self.SourceLocalStorage[SlotInd];
  NewChainAddr := nil;
  // * * * * * //
  SourceId := Self.Slots[SlotInd].SourceId;

  if Math.InRange(SourceId, SOURCE_DWELLING_FIRST, SOURCE_DWELLING_LAST) then begin
    DwellingId               := SourceId mod NUM_DWELLINGS_PER_TOWN;
    Slots[SlotInd].SourceNum := @Heroes.ZvsGetTowns()[SourceId div NUM_DWELLINGS_PER_TOWN].DwellingMons[DwellingId div 7][DwellingId mod 7];
  end else begin
    i := 0;

    while (i < High(Self.SourceAllocationTable)) and (Self.SourceAllocationTable[i].SourceId <> SourceId) do begin
      Inc(i);
    end;

    if i < High(Self.SourceAllocationTable) then begin
      Slots[SlotInd].SourceNum := Self.SourceAllocationTable[i].SourceAddr;
    end else begin
      Slots[SlotInd].SourceNum := SourceNum;
      Self.AllocSource(SourceId, SourceNum, IS_DISPOSABLE);
    end;    
  end; // .else

  for i := 0 to High(Self.Slots) do begin
    // Found another slot, pointing to the current one, split chain
    if (i <> SlotInd) and (Self.Slots[i].SourceNum = SourceNum) then begin
      if NewChainAddr = nil then begin
        NewChainAddr := @Self.SourceLocalStorage[i];
      end;

      Self.Slots[i].SourceNum := NewChainAddr;
    end;
  end;
end; // .procedure TRecruitMonsDlgOpenEvent.UpdateSlotSourceAddr

procedure TRecruitMonsDlgOpenEvent.ResetSlot (SlotInd: integer);
begin
  {!} Assert(Math.InRange(SlotInd, 0, High(Self.Slots)));

  with Self.Slots[SlotInd] do begin
    MonType    := -1;
    OrigMonNum := 0;
    SourceId   := SOURCE_FIRST_CUSTOM;
    SourceNum  := nil;
  end;

  Self.UpdateSlotSourceAddr(SlotInd);
  Self.Slots[SlotInd].SourceNum^ := 0;
end;

procedure TRecruitMonsDlgOpenEvent.ShiftSlots (Offset: integer);
var
  i: integer;

begin
  if Offset = 0 then begin
    exit;
  end;

  if Offset > 0 then begin
    for i := High(Self.Slots) - Offset downto 0 do begin
      Self.Slots[i + Offset] := Self.Slots[i];
    end;

    for i := 0 to Math.Min(Offset, High(Self.Slots) + 1) - 1 do begin
      Self.ResetSlot(i);
    end;
  end else begin
    for i := -Offset to High(Self.Slots) do begin
      Self.Slots[i + Offset] := Self.Slots[i];
    end;

    for i := High(Self.Slots) + 1 + Offset to High(Self.Slots) do begin
      Self.ResetSlot(i);
    end;
  end;
end; // .procedure TRecruitMonsDlgOpenEvent.ShiftSlots

procedure TRecruitMonsDlgOpenEvent.Reset;
var
  i: integer;

begin
  for i := 0 to High(Self.SourceAllocationTable) do begin
    with Self.SourceAllocationTable[i] do begin
      SourceId   := 0;
      SourceAddr := nil;
      Disposable := true;
    end;
  end;

  Self.TownId       := -1;
  Self.DwellingId   := -1;
  Self.SelectedSlot := 0;

  for i := 0 to High(Self.Slots) do begin
    Self.ResetSlot(i);
  end;

  Self.ReadOnly := false;
  Self.Inited   := false;
end;

function TRecruitMonsDlgOpenEvent.FindSourceIdByAddr ({n} SourceAddr: pword; var {out} SourceId: integer): boolean;
var
  i: integer;

begin
  result := false;

  for i := 0 to High(Self.SourceAllocationTable) do begin
    if Self.SourceAllocationTable[i].SourceAddr = SourceAddr then begin
      SourceId := Self.SourceAllocationTable[i].SourceId;
      result   := true;
      exit;
    end;
  end;
end;

procedure TRecruitMonsDlgOpenEvent.InitTargetFromDlg (DlgSetup: PRecruitMonsDlgSetup);
var
{n} Towns:     Heroes.PTowns;
{n} HeroList:  Heroes.PHeroes;
    NumTowns:  integer;
    NumHeroes: integer;

begin
  {!} Assert(DlgSetup <> nil);
  Towns    := Heroes.ZvsGetTowns();
  HeroList := Heroes.PHeroes(Heroes.ZvsGetHero(0));
  // * * * * * //
  if DlgSetup.Target = nil then begin
    DlgSetup.Target := @Self.CustomTarget;
    Self.TargetType := RECRUIT_TARGET_CUSTOM;
    Self.Target     := @Self.CustomTarget;
    Self.TargetId   := -1;
    exit;
  end;

  Self.Target     := DlgSetup.Target;
  Self.TargetType := RECRUIT_TARGET_EXTERNAL;
  Self.TargetId   := -1;
  NumTowns        := Heroes.ZvsCountTowns();
  NumHeroes       := Heroes.NumHeroes^;

  if IsAddrFromStructArr(DlgSetup.Target, Towns, @Towns[NumTowns]) then begin
    Self.TargetType := RECRUIT_TARGET_TOWN;
    Self.TargetId   := (cardinal(DlgSetup.Target) - cardinal(Towns)) div sizeof(Heroes.TTown);
  end else if IsAddrFromStructArr(DlgSetup.Target, HeroList, @HeroList[NumHeroes]) then begin
    Self.TargetType := RECRUIT_TARGET_HERO;
    Self.TargetId   := (cardinal(DlgSetup.Target) - cardinal(HeroList)) div sizeof(Heroes.THero);
  end;
end; // .procedure TRecruitMonsDlgOpenEvent.InitTargetFromDlg

procedure TRecruitMonsDlgOpenEvent.InitSlotsFromDlgSetup (DlgSetup: PRecruitMonsDlgSetup);
var
  i: integer;

begin
  {!} Assert(DlgSetup <> nil);
  
  for i := 0 to High(Self.Slots) do begin
    Self.InitSlotFromDlgSetup(DlgSetup, i);
  end;

  Self.SelectedSlot := Alg.ToRange(DlgSetup.SelectedMonSlot, 0, High(Self.Slots));
end;

procedure TRecruitMonsDlgOpenEvent.InitSlotFromDlgSetup (DlgSetup: PRecruitMonsDlgSetup; SlotInd: integer);
var
{n} SourceAddr: pword;

begin
  {!} Assert(DlgSetup <> nil);
  {!} Assert(Math.InRange(SlotInd, 0, High(Self.Slots)));
  SourceAddr := nil;
  // * * * * * //
  Self.DlgSlotToSlotMap[SlotInd] := -1;

  if (DlgSetup.MonTypes[SlotInd] < 0) or (DlgSetup.MonNums[SlotInd] = nil) then begin
    Self.ResetSlot(SlotInd);
  end else begin
    SourceAddr := DlgSetup.MonNums[SlotInd];

    with Self.Slots[SlotInd] do begin
      MonType    := DlgSetup.MonTypes[SlotInd];
      OrigMonNum := SourceAddr^;
      SourceNum  := SourceAddr;
    end;

    if not Self.FindSourceIdByAddr(SourceAddr, Self.Slots[SlotInd].SourceId) then begin
      Self.Slots[SlotInd].SourceId := DetectKnownSourceIdByAddr(SOURCE_EXTERNAL_0 + SlotInd, SourceAddr);

      if not Math.InRange(Self.Slots[SlotInd].SourceId, SOURCE_DWELLING_FIRST, SOURCE_DWELLING_LAST) then begin
        Self.AllocSource(SOURCE_EXTERNAL_0 + SlotInd, SourceAddr, IS_NON_DISPOSABLE);
      end;
    end;
  end; // .else
end; // .procedure TRecruitMonsDlgOpenEvent.InitSlotFromDlgSetup

function TRecruitMonsDlgOpenEvent.HasNonEmptySlot: boolean;
var
  i: integer;

begin
  result := false;

  for i := 0 to High(Self.Slots) do begin
    if Self.Slots[i].MonType <> -1 then begin
      result := true;
      exit;
    end;
  end;
end;

procedure TRecruitMonsDlgOpenEvent.ApplySlotsToDlg (DlgSetup: PRecruitMonsDlgSetup);
var
  i, j: integer;

begin
  {!} Assert(DlgSetup <> nil);
  j := 0;
  
  for i := 0 to High(Self.Slots) do begin
    DlgSetup.MonTypes[i] := -1;
    
    if Self.Slots[i].MonType <> -1 then begin
      Self.ApplySlotToDlg(DlgSetup, i, j);

      if i = Self.SelectedSlot then begin
        SelectDlgSlot(DlgSetup, j);
      end;

      Inc(j);
    end;
  end;

  if (Self.Slots[Self.SelectedSlot].MonType = -1) and (DlgSetup.MonTypes[0] <> -1) then begin
    SelectDlgSlot(DlgSetup, 0);
  end;
end; // .procedure TRecruitMonsDlgOpenEvent.ApplySlotsToDlg

procedure TRecruitMonsDlgOpenEvent.ApplySlotToDlg (DlgSetup: PRecruitMonsDlgSetup; SlotInd, DlgSlotInd: integer);
begin
  Self.DlgSlotToSlotMap[DlgSlotInd] := SlotInd;
  DlgSetup.MonTypes[DlgSlotInd]     := Self.Slots[SlotInd].MonType;
  DlgSetup.MonNums[DlgSlotInd]      := Self.Slots[SlotInd].SourceNum;
end;

procedure TRecruitMonsDlgOpenEvent.RememberOrigMonParams;
var
  i: integer;

begin
  for i := 0 to High(Self.Slots) do begin
    Self.Slots[i].OrigMonNum := Self.Slots[i].SourceNum^;
  end;
end;

procedure Hook_OpenRecruitMonsDlg (OrigFunc: pointer; Obj: pointer; RecruitMonsDlgSetup: PRecruitMonsDlgSetup); stdcall;
const
  EVENT_PARAM_SELECTED_SLOT = 0;
  EVENT_PARAM_DLG_FLAGS     = 1;
  EVENT_PARAM_SHOW_DIALOG   = 2;

var
  ShowDlg:   integer;
  PrevEvent: TRecruitMonsDlgOpenEvent;

begin
  PrevEvent := RecruitMonsDlgOpenEvent;
  
  Inc(RecruitMonsDlgOpenEventAutoId);
  RecruitMonsDlgOpenEvent.Reset;
  RecruitMonsDlgOpenEvent.Mem           := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  RecruitMonsDlgOpenEvent.DlgSetup      := RecruitMonsDlgSetup;
  RecruitMonsDlgOpenEvent.TownId        := NextRecruitMonsDlgOpenEventTownId;
  RecruitMonsDlgOpenEvent.DwellingId    := NextRecruitMonsDlgOpenEventDwellingId;
  NextRecruitMonsDlgOpenEventTownId     := -1;
  NextRecruitMonsDlgOpenEventDwellingId := -1;
  RecruitMonsDlgOpenEvent.Id            := RecruitMonsDlgOpenEventAutoId;
  RecruitMonsDlgOpenEvent.ReadOnly      := false;
  RecruitMonsDlgOpenEvent.Inited        := true;
  RecruitMonsDlgOpenEvent.InitTargetFromDlg(RecruitMonsDlgSetup);
  RecruitMonsDlgOpenEvent.InitSlotsFromDlgSetup(RecruitMonsDlgSetup);

  if RecruitMonsDlgSetup.ObjType = -1 then begin
    // External dwelling default behavior
    RecruitMonsDlgSetup.ObjType := DLG_FLAG_AUTO_UPDATE_ADVMAP;
  end else if RecruitMonsDlgSetup.ObjType = Heroes.OBJTYPE_TOWN then begin
    // Town default behavior
    RecruitMonsDlgSetup.ObjType := DLG_FLAG_CLOSE_ON_BUY;
  end;

  {!} GameExt.EraSaveEventParams;
  Erm.AssignEventParams([RecruitMonsDlgSetup.SelectedMonSlot, RecruitMonsDlgSetup.ObjType, 1]);
  Erm.FireErmEvent(Erm.TRIGGER_OPEN_RECRUIT_DLG);

  RecruitMonsDlgOpenEvent.SelectedSlot := RecruitMonsDlgOpenEvent.DlgSlotToSlotMap[Alg.ToRange(GameExt.EraEventParams[EVENT_PARAM_SELECTED_SLOT], 0, High(RecruitMonsDlgOpenEvent.Slots))];
  RecruitMonsDlgSetup.ObjType          := GameExt.EraEventParams[EVENT_PARAM_DLG_FLAGS] and DLG_FLAGS_ALL;
  ShowDlg                              := GameExt.EraEventParams[EVENT_PARAM_SHOW_DIALOG];
  {!} GameExt.EraRestoreEventParams;

  if ShowDlg <> 0 then begin
    RecruitMonsDlgOpenEvent.RememberOrigMonParams;
    RecruitMonsDlgOpenEvent.ApplySlotsToDlg(RecruitMonsDlgSetup);
    RecruitMonsDlgOpenEvent.ReadOnly := true;

    if RecruitMonsDlgOpenEvent.HasNonEmptySlot then begin
      PatchApi.Call(PatchApi.THISCALL_, OrigFunc, [Obj, RecruitMonsDlgSetup]);
    end;

    Erm.FireErmEvent(Erm.TRIGGER_CLOSE_RECRUIT_DLG);
  end; // .if

  SysUtils.FreeAndNil(RecruitMonsDlgOpenEvent.Mem);
  RecruitMonsDlgOpenEvent := PrevEvent;
end; // .procedure Hook_OpenRecruitMonsDlg

function Hook_OpenTownDwelling (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  NextRecruitMonsDlgOpenEventTownId     := (pcardinal(Context.EBX + $38)^ - cardinal(@Heroes.ZvsGetTowns()[0])) div sizeof(Heroes.TTown);
  NextRecruitMonsDlgOpenEventDwellingId := Context.EDI;
  result                                := Core.EXEC_DEF_CODE;
end;

function Hook_OpenTownHallDwelling (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  NextRecruitMonsDlgOpenEventTownId     := (pcardinal(pcardinal(Heroes.TOWN_MANAGER)^ + $38)^ - cardinal(@Heroes.ZvsGetTowns()[0])) div sizeof(Heroes.TTown);
  NextRecruitMonsDlgOpenEventDwellingId := Context.ESI;
  result                                := Core.EXEC_DEF_CODE;
end;

function Hook_OpenTownHordeDwelling (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  NextRecruitMonsDlgOpenEventTownId     := (pcardinal(Context.EBX + $38)^ - cardinal(@Heroes.ZvsGetTowns()[0])) div sizeof(Heroes.TTown);
  NextRecruitMonsDlgOpenEventDwellingId := pbyte(pbyte(pinteger(pinteger(Heroes.TOWN_MANAGER)^ + $38)^ + 4)^ * 2 + Context.EDI + integer(GameExt.GetRealAddr(Ptr($68A3A2))))^;
  result                                := Core.EXEC_DEF_CODE;
end;

function Hook_OpenTownDwellingFromKingdomOverview (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  NextRecruitMonsDlgOpenEventTownId     := (cardinal(Context.EAX) - cardinal(@Heroes.ZvsGetTowns()[0])) div sizeof(Heroes.TTown);
  NextRecruitMonsDlgOpenEventDwellingId := Context.EDI;
  Context.EAX                           := Context.ESI;
  result                                := Core.EXEC_DEF_CODE;
end;

function Hook_UpdateAdvMapInRecruitMonsDlg (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  // Update advmap if corresponding flag is set
  result := Utils.Flags(PRecruitMonsDlgSetup(Context.ESI).ObjType).Have(DLG_FLAG_AUTO_UPDATE_ADVMAP);

  if not result then begin
    Context.RetAddr := Ptr($5510E3);
  end;
end;

function Hook_RecruitMonsDlgMouseClick (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  result := Erm.FireMouseEvent(Erm.TRIGGER_RECRUIT_DLG_MOUSE_CLICK, Ptr(Context.EBX));

  if not result then begin
    Context.RetAddr := Ptr($551707);
  end;
end;

function Hook_TownHallMouseClick (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  result := Erm.FireMouseEvent(Erm.TRIGGER_TOWN_HALL_MOUSE_CLICK, Ptr(Context.EBX));

  if not result then begin
    Context.RetAddr := Ptr($5DD64A);
  end;
end;

function Hook_RecruitDlgRecalc (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
const
  EVENT_PARAM_COST          = 0;
  EVENT_PARAM_RESOURCE      = 1;
  EVENT_PARAM_RESOURCE_COST = 2;

var
  DlgSetup: PRecruitMonsDlgSetup;

begin
  DlgSetup := Ptr(Context.EBX);
  // * * * * * //
  result := true;

  {!} GameExt.EraSaveEventParams;
  Erm.AssignEventParams([DlgSetup.Cost, DlgSetup.Resource, DlgSetup.ResourceCost]);
  Erm.FireErmEvent(Erm.TRIGGER_RECRUIT_DLG_RECALC);
  DlgSetup.Cost         := GameExt.EraEventParams[EVENT_PARAM_COST];
  DlgSetup.Resource     := Alg.ToRange(GameExt.EraEventParams[EVENT_PARAM_RESOURCE], 0, Heroes.RES_LAST);
  DlgSetup.ResourceCost := GameExt.EraEventParams[EVENT_PARAM_RESOURCE_COST];
  {!} GameExt.EraRestoreEventParams;
end; // .function Hook_RecruitDlgRecalc

function Hook_RecruitDlgAction (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
const
  EVENT_PARAM_NUM_RECRUITED_MONS = 0;

begin
  result := true;
  Erm.FireErmEventEx(Erm.TRIGGER_RECRUIT_DLG_ACTION, [Context.ECX and $FFFF]);
end;

function Hook_AllowZeroCost (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  result := PRecruitMonsDlgSetup(Context.EBX).Cost <> 0;

  if not result then begin
    Context.EAX := High(integer);
  end;
end;

function Hook_AllowZeroResourceCost (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
begin
  result := PRecruitMonsDlgSetup(Context.EBX).ResourceCost <> 0;

  if not result then begin
    Context.EAX := High(integer);
  end;
end;

function Hook_RecruitDlgCloseOnBuy (Context: ApiJack.PHookContext): LONGBOOL; stdcall;
var
  Dlg: PRecruitMonsDlgSetup;

begin
  Dlg    := PRecruitMonsDlgSetup(Context.ESI);
  result := Utils.Flags(Dlg.ObjType).DontHave(DLG_FLAG_CLOSE_ON_BUY) and (Dlg.MonTypes[1] <> -1);

  if not result then begin
    Context.RetAddr := Ptr($55121B);
  end;
end;

function Command_RecruitDlg (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
var
  SlotInd:        integer;
  SourceId:       integer;
  UseOriginalNum: boolean;
  MonNum:         integer;

begin
  result  := false;
  SlotInd := Low(integer);

  if not RecruitMonsDlgOpenEvent.Inited then begin
    Error := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  UseOriginalNum := false;

  // #0 = use original number
  if NumParams >= 5 then begin
    if Params[5].OperGet or Params[5].IsStr then begin
      exit;
    end else begin
      UseOriginalNum := Params[5].Value.v = 0;
    end;
  end;

  // #slot/$type[/$num/$sourceId/#0 = use original number]
  if NumParams in [2..5] then begin
    result := not Params[1].OperGet and not Params[1].IsStr;

    // #slot
    if result then begin
      SlotInd := Params[1].Value.v;
      result  := SlotInd in [0..3];

      if not result then begin
        Error := Format('Invalid slot index: %d. Valid value is 0..3', [SlotInd]);
      end;
    end;

    // $type
    if result and not Params[2].OperGet and RecruitMonsDlgOpenEvent.ReadOnly then begin
      result := false;
      Error  := 'Cannot change slot $type after initial setup';
    end;

    if result then begin
      result := not Params[2].IsStr and (Params[2].OperGet or ((Params[2].Value.v >= -1) and (Params[2].Value.v < Heroes.NumMonstersPtr^)));

      if not result then begin
        Error := Format('Invalid monsters type: %d. Valid value is -1..%d', [Params[2].Value.v, Heroes.NumMonstersPtr^ - 1]);
      end else begin
        AdvErm.ApplyParam(Params[2], @RecruitMonsDlgOpenEvent.Slots[SlotInd].MonType);
      end;
    end;

    // $sourceId
    if result and (NumParams >= 4) and not Params[4].OperGet and RecruitMonsDlgOpenEvent.ReadOnly then begin
      result := false;
      Error  := 'Cannot change slot $sourceId after initial setup';
    end;

    if result and (NumParams >= 4) and not Params[4].IsStr then begin
      SourceId := Params[4].Value.v;
      result   := Params[4].OperGet or ((SourceId >= 0) and (Math.InRange(SourceId, SOURCE_FIRST_CUSTOM, High(integer)) or IsValidEraSourceId(SourceId)));

      if not result then begin
        Error := Format('Invalid source ID: %d', [SourceId]);
      end else begin
        AdvErm.ApplyParam(Params[4], @RecruitMonsDlgOpenEvent.Slots[SlotInd].SourceId);

        if not Params[4].OperGet then begin
          RecruitMonsDlgOpenEvent.UpdateSlotSourceAddr(SlotInd);
        end;
      end;
    end;

    // $num, allowed to change event in readonly mode
    if result and (NumParams >= 3) and not Params[3].IsStr then begin
      result := Params[3].OperGet or (not UseOriginalNum and (Params[3].Value.v >= 0) and (Params[3].Value.v <= Heroes.MAX_MONS_IN_STACK));

      if not result then begin
        Error := Format('Invalid monsters number: %d. Valid value is 0..%d', [Params[3].Value.v, Heroes.MAX_MONS_IN_STACK]);
      end else if UseOriginalNum then begin
        if RecruitMonsDlgOpenEvent.ReadOnly then begin
          AdvErm.ApplyParam(Params[3], @RecruitMonsDlgOpenEvent.Slots[SlotInd].OrigMonNum);
        end else begin
          MonNum := RecruitMonsDlgOpenEvent.Slots[SlotInd].SourceNum^;
          AdvErm.ApplyParam(Params[3], @MonNum);
        end;
      end else begin
        MonNum := RecruitMonsDlgOpenEvent.Slots[SlotInd].SourceNum^;
        AdvErm.ApplyParam(Params[3], @MonNum);
        
        if not Params[3].OperGet then begin
          RecruitMonsDlgOpenEvent.Slots[SlotInd].SourceNum^ := MonNum;
        end;
      end;
    end;
  end; //.if
end; // .function Command_RecruitDlg

function Command_RecruitDlg_ShiftSlots (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
begin
  if not RecruitMonsDlgOpenEvent.Inited then begin
    result := false;
    Error  := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  result := (NumParams = 1) and not Params[1].OperGet and not Params[1].IsStr;

  if not result then begin
    exit;
  end;

  if not RecruitMonsDlgOpenEvent.Inited then begin
    result := false;
    Error  := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  if RecruitMonsDlgOpenEvent.ReadOnly then begin
    result := false;
    Error  := 'Cannot shift slots after initial setup';
    exit;
  end;

  RecruitMonsDlgOpenEvent.ShiftSlots(Params[1].Value.v);
end; // .function Command_RecruitDlg_ShiftSlots

function Command_RecruitDlg_SlotIndex (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
var
  DlgSlotInd: integer;

begin
  if not RecruitMonsDlgOpenEvent.Inited then begin
    result := false;
    Error  := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  result := (NumParams = 2) and not Params[1].OperGet and Params[2].OperGet and not Params[1].IsStr and not Params[2].IsStr;

  if not result then begin
    exit;
  end;

  DlgSlotInd := Params[1].Value.v;

  if not (DlgSlotInd in [0..3]) then begin
    result := false;
    Error  := Format('Invalid dialog slot index: %d. Expected 0..3', [DlgSlotInd]);
    exit;
  end;
  
  AdvErm.ApplyParam(Params[2], @RecruitMonsDlgOpenEvent.DlgSlotToSlotMap[DlgSlotInd]);
end; // .function Command_RecruitDlg_SlotIndex

function Command_RecruitDlg_Info (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
begin
  if not RecruitMonsDlgOpenEvent.Inited then begin
    result := false;
    Error  := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  result := (NumParams >= 1) and AdvErm.CheckCmdParamsEx(@Params^, NumParams, [
    AdvErm.TYPE_INT or AdvErm.ACTION_GET,
    AdvErm.TYPE_INT or AdvErm.ACTION_GET or AdvErm.PARAM_OPTIONAL,
    AdvErm.TYPE_INT or AdvErm.ACTION_GET or AdvErm.PARAM_OPTIONAL,
    AdvErm.TYPE_INT or AdvErm.ACTION_GET or AdvErm.PARAM_OPTIONAL
  ]);

  if not result then begin
    exit;
  end;

  AdvErm.ApplyParam(Params[1], @RecruitMonsDlgOpenEvent.Id);

  if NumParams >= 2 then begin
    AdvErm.ApplyParam(Params[2], @RecruitMonsDlgOpenEvent.TownId);
  end;

  if NumParams >= 3 then begin
    AdvErm.ApplyParam(Params[3], @RecruitMonsDlgOpenEvent.DwellingId);
  end;

  if NumParams >= 4 then begin
    AdvErm.ApplyParam(Params[4], @RecruitMonsDlgOpenEvent.DlgSlotToSlotMap[RecruitMonsDlgOpenEvent.DlgSetup.SelectedMonSlot]);
  end;
end; // .function Command_RecruitDlg_Info

function Command_RecruitDlg_Mem (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
var
{U} AssocVarValue: AdvErm.TAssocVar;
    AssocVarName:  string;

begin
  AssocVarValue := nil;
  // * * * * * //
  if not RecruitMonsDlgOpenEvent.Inited then begin
    result := false;
    Error  := 'Dialog structure is not initialized and cannot be accessed outside of appropriate event handlers';
    exit;
  end;

  result := (NumParams = 2) and AdvErm.CheckCmdParamsEx(@Params^, NumParams, [
    AdvErm.TYPE_ANY or AdvErm.ACTION_SET,
    AdvErm.TYPE_ANY
  ]);

  if not result then begin
    exit;
  end;

  if Params[1].IsStr then begin
    AssocVarName := Params[1].Value.pc;
  end else begin
    AssocVarName := SysUtils.IntToStr(Params[1].Value.v);
  end;
  
  AssocVarValue := RecruitMonsDlgOpenEvent.Mem[AssocVarName];
  
  if Params[2].OperGet then begin
    if Params[2].IsStr then begin
      if (AssocVarValue = nil) or (AssocVarValue.StrValue = '') then begin
        Params[2].Value.pc^ := #0;
      end else begin
        Erm.SetZVar(Params[2].Value.pc, AssocVarValue.StrValue);
      end;
    end else begin
      pinteger(Params[2].Value.v)^ := Utils.IfThen(AssocVarValue <> nil, AssocVarValue.IntValue, 0);
    end;
  end else begin
    if AssocVarValue = nil then begin
      AssocVarValue                             := TAssocVar.Create;
      RecruitMonsDlgOpenEvent.Mem[AssocVarName] := AssocVarValue;
    end;
    
    if Params[2].IsStr then begin
      AssocVarValue.StrValue := Utils.IfThen(Params[2].ParamModifier <> AdvErm.MODIFIER_CONCAT, Params[2].Value.pc, AssocVarValue.StrValue + Params[2].Value.pc);
    end else begin
      AdvErm.ModifyWithIntParam(AssocVarValue.IntValue, Params[2]);
    end;
  end; // .else
end; // .function Command_RecruitDlg_Mem

procedure InitRecruitMonsDlgSetup (DlgSetup: PRecruitMonsDlgSetup; TownId, DwellingId, TargetType, TargetId: integer);
var
  GameState:    Heroes.TGameState;
  IsTownScreen: boolean;

begin
  {!} Assert(DlgSetup <> nil);
  Heroes.GetGameState(GameState);
  IsTownScreen := GameState.CurrentDlgId = Heroes.TOWN_SCREEN_DLGID;

  if (TownId <> -1) and Math.InRange(DwellingId, 0, NUM_DWELLINGS_PER_TOWN - 1) then begin
    PatchApi.Call(PatchApi.THISCALL_, Ptr($551960), [DlgSetup, @Heroes.ZvsGetTowns()[TownId], DwellingId, ord(IsTownScreen)]);
  end else begin
    FillChar(DlgSetup^, sizeof(DlgSetup^), 0);
    DlgSetup.VirtTable       := Ptr($63B9BC);
    DlgSetup._MinOne1        := -1;
    DlgSetup._MinOne2        := -1;
    DlgSetup.ClassName       := 'Unknown'#0;
    DlgSetup.IsTownScreen    := ord(IsTownScreen);
    //DlgSetup.ObjType         := Utils.IfThen(TownId <> -1, Heroes.OBJTYPE_TOWN, -1);
    DlgSetup._One1           := 1;
    DlgSetup.MonTypes[0]     := -1;
    DlgSetup.MonTypes[1]     := -1;
    DlgSetup.MonTypes[2]     := -1;
    DlgSetup.MonTypes[3]     := -1;
    DlgSetup.SelectedMonType := -1;

    // Init timer
    pinteger($6989E8)^ := PatchApi.Call(PatchApi.STDCALL_, Ptr($4F8970), []) + $64;
  end; // .else

  case TargetType of
    RECRUIT_TARGET_TOWN:   DlgSetup.Target := @Heroes.ZvsGetTowns()[TargetId].GuardTypes;
    RECRUIT_TARGET_HERO:   DlgSetup.Target := @Heroes.ZvsGetHero(TargetId).MonTypes;
    RECRUIT_TARGET_CUSTOM: DlgSetup.Target := nil;
  end;
end; // .procedure InitRecruitMonsDlgSetup

function Command_RecruitDlg_Open (NumParams: integer; Params: POneBasedCmdParams; var Error: string): boolean;
var
{On} DlgSetup:   PRecruitMonsDlgSetup;
     TownId:     integer;
     DwellingId: integer;
     TargetType: integer;
     TargetId:   integer;
     DlgFlags:   integer;
     NumTowns:   integer;

begin
  DlgSetup := nil;
  // * * * * * //
  result := Math.InRange(NumParams, 4, 5) and AdvErm.CheckCmdParamsEx(@Params^, NumParams, [
    AdvErm.TYPE_INT or AdvErm.ACTION_SET,
    AdvErm.TYPE_INT or AdvErm.ACTION_SET,
    AdvErm.TYPE_INT or AdvErm.ACTION_SET,
    AdvErm.TYPE_INT or AdvErm.ACTION_SET,
    AdvErm.TYPE_INT or AdvErm.ACTION_SET or AdvErm.PARAM_OPTIONAL
  ]);

  if not result then begin
    exit;
  end;

  NumTowns := Heroes.ZvsCountTowns();
  AdvErm.ApplyParam(Params[1], @TownId);

  if (TownId <> -1) and not Math.InRange(TownId, 0, NumTowns - 1) then begin
    result := false;
    Error  := Format('Invalid town ID: %d. Expected 0..NUM_TOWNS - 1 or -1', [TownId]);
    exit;
  end;

  AdvErm.ApplyParam(Params[2], @DwellingId);

  if (DwellingId <> -1) and not Math.InRange(DwellingId, 0, NUM_DWELLINGS_PER_TOWN - 1) then begin
    result := false;
    Error  := Format('Invalid dwelling ID: %d. Expected 0..13 or -1', [DwellingId]);
    exit;
  end;

  AdvErm.ApplyParam(Params[3], @TargetType);

  if (TargetType <> -1) and not Math.InRange(TargetType, RECRUIT_TARGET_TOWN, RECRUIT_TARGET_CUSTOM) then begin
    result := false;
    Error  := Format('Invalid target type: %d. Expected 0..2', [TargetType]);
    exit;
  end;

  AdvErm.ApplyParam(Params[4], @TargetId);

  if
    (TargetId <> -1) and
    (((TargetType = RECRUIT_TARGET_TOWN) and not Math.InRange(TargetId, 0, NumTowns - 1)) or ((TargetType = RECRUIT_TARGET_HERO) and not Math.InRange(TargetId, 0, Heroes.NumHeroes^ - 1)))
  then begin
    result := false;
    Error  := Format('Invalid target ID: %d. Expected valid town/hero ID or -1', [TargetId]);
    exit;
  end;

  if NumParams >= 5 then begin
    AdvErm.ApplyParam(Params[5], @DlgFlags);
  end else begin
    DlgFlags := 0;
  end;

  DlgSetup                              := Heroes.MAlloc($BC);
  NextRecruitMonsDlgOpenEventTownId     := TownId;
  NextRecruitMonsDlgOpenEventDwellingId := DwellingId;
  InitRecruitMonsDlgSetup(DlgSetup, TownId, DwellingId, TargetType, TargetId);
  DlgSetup.ObjType := DlgFlags and DLG_FLAGS_ALL;

  PatchApi.Call(THISCALL_, Ptr($4B0770), [pinteger($699550)^, DlgSetup]);
  // * * * * * //
  Heroes.MFree(DlgSetup);
end; // .function Command_RecruitDlg_Open

function Receiver_RD (Cmd: char; NumParams: integer; Dummy: integer; CmdInfo: Erm.PErmSubCmd): integer; cdecl;
begin
  with AdvErm.WrapErmCmd('RD', CmdInfo) do begin
    while FindNextSubcmd(['C', 'S', 'F', 'I', 'M', 'O']) do begin
      case Cmd of
        'C': Success := Command_RecruitDlg(NumParams, @Params, Error);
        'S': Success := Command_RecruitDlg_ShiftSlots(NumParams, @Params, Error);
        'F': Success := Command_RecruitDlg_SlotIndex(NumParams, @Params, Error);
        'I': Success := Command_RecruitDlg_Info(NumParams, @Params, Error);
        'M': Success := Command_RecruitDlg_Mem(NumParams, @Params, Error);
        'O': Success := Command_RecruitDlg_Open(NumParams, @Params, Error);
      end;
    end;

    result := GetCmdResult;
    Cleanup;
  end;
end;

procedure OnAfterWoG (Event: EventMan.PEvent); stdcall;
begin
  ApiJack.StdSplice(Ptr($4B0770), @Hook_OpenRecruitMonsDlg, ApiJack.CONV_THISCALL, 1);
  ApiJack.HookCode(Ptr($70DD4A), @Hook_OpenTownDwelling);
  
  // Prevent ESI (PTown) := EAX override. Exchange ESI, EAX instead
  Core.p.WriteDataPatch(Ptr($51FB9F), ['9690']);
  ApiJack.HookCode(Ptr($51FBB5), @Hook_OpenTownDwellingFromKingdomOverview);
  
  ApiJack.HookCode(Ptr($5DD2FC), @Hook_OpenTownHallDwelling);
  ApiJack.HookCode(Ptr($5D4271), @Hook_OpenTownHordeDwelling);
  ApiJack.HookCode(Ptr($5510D2), @Hook_UpdateAdvMapInRecruitMonsDlg);
  ApiJack.HookCode(Ptr($550EB7), @Hook_RecruitMonsDlgMouseClick);
  ApiJack.HookCode(Ptr($5DD3C8), @Hook_TownHallMouseClick);
  ApiJack.HookCode(Ptr($550860), @Hook_RecruitDlgRecalc);
  ApiJack.HookCode(Ptr($551089), @Hook_RecruitDlgAction);
  ApiJack.HookCode(Ptr($550989), @Hook_AllowZeroCost);
  ApiJack.HookCode(Ptr($5509A4), @Hook_AllowZeroResourceCost);
  
  // Move close on buy logics down the code after update adv map logics
  Core.p.WriteDataPatch(Ptr($5510B1), ['9090909090909090909090909090909090909090']);
  ApiJack.HookCode(Ptr($5510FA), @Hook_RecruitDlgCloseOnBuy);
  
  AdvErm.RegisterErmReceiver('RD', @Receiver_RD, AdvErm.CMD_PARAMS_CONFIG_NONE);
end; // .procedure OnAfterWoG

begin
  RecruitMonsDlgOpenEvent.Inited := false;
  
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.