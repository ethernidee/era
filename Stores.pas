unit Stores;
{
DESCRIPTION:  Provides ability to store safely data in savegames
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  SysUtils, Math, Utils, Crypto, AssocArrays, StrLib, DlgMes,
  Core, GameExt, Heroes, Erm;

type
  (* IMPORT *)
  TAssocArray = AssocArrays.TAssocArray;

  TStoredData = class
    Data:       string;
    ReadingPos: integer;
  end; // .class TStoredData


const
  ZvsErmTriggerBeforeSave:  Utils.TProcedure  = Ptr($750093);


procedure WriteSavegameSection
(
            DataSize:     integer;
        {n} Data:         pointer;
  const     SectionName:  string
);

function  ReadSavegameSection
(
            DataSize:     integer;
        {n} Dest:         pointer;
  const     SectionName:  string
): integer;


var
  EraSectionsSize:  integer = 0; // 0 to turn off padding
  ZeroBuf:  string;


(***) implementation (***)


var
{O} WritingStorage:   {O} TAssocArray {OF Data: StrLib.TStrBuilder};
{O} ReadingStorage:   {O} TAssocArray {OF StoredData: TStoredData};


procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; const SectionName: string);
var
{U} Section:  StrLib.TStrBuilder;
    DataStr:  string;
  
begin
  {!} Assert(Utils.IsValidBuf(Data, DataSize));
  Section :=  nil;
  // * * * * * //
  if DataSize > 0 then begin
    Section :=  WritingStorage[SectionName];
    
    if Section = nil then begin
      Section                     :=  StrLib.TStrBuilder.Create;
      WritingStorage[SectionName] :=  Section;
    end; // .if
    
    SetLength(DataStr, DataSize);
    Utils.CopyMem(DataSize, Data, pointer(DataStr));
    Section.Append(DataStr);
  end; // .if
end; // .procedure WriteSavegameSection

function ReadSavegameSection
(
            DataSize:     integer;
        {n} Dest:         pointer;
  const     SectionName:  string
): integer;

var
{U} Section:  TStoredData;
  
begin
  {!} Assert(Utils.IsValidBuf(Dest, DataSize));
  Section :=  nil;
  // * * * * * //
  result  :=  0;
  
  if DataSize > 0 then begin
    Section :=  ReadingStorage[SectionName];
    
    if Section <> nil then begin
      result  :=  Math.Min(DataSize, Length(Section.Data) - Section.ReadingPos);
      Utils.CopyMem(result, pointer(@Section.Data[Section.ReadingPos + 1]), Dest);
      Section.ReadingPos  :=  Section.ReadingPos + result;
    end; // .if
  end; // .if
end; // .function ReadSavegameSection

function Hook_SaveGame (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  PARAM_SAVEGAME_NAME = 0;

var
{U} OldSavegameName:  pchar;
{U} SavegameName:     pchar;
    SavegameNameLen:  integer;
  
begin
  OldSavegameName :=  PPOINTER(Context.EBP + 8)^;
  SavegameName    :=  nil;
  // * * * * * //
  GameExt.EraSaveEventParams;
  
  GameExt.EraEventParams[PARAM_SAVEGAME_NAME] :=  integer(OldSavegameName);
  ZvsErmTriggerBeforeSave;
  SavegameName    :=  Ptr(GameExt.EraEventParams[PARAM_SAVEGAME_NAME]);
  SavegameNameLen :=  SysUtils.StrLen(SavegameName);
  
  if SavegameName <> OldSavegameName then begin
    Utils.CopyMem(SavegameNameLen + 1, SavegameName, OldSavegameName);
    PINTEGER(Context.EBP + 12)^ :=  -1;
  end; // .if
  
  GameExt.EraRestoreEventParams;
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_SaveGame

function Hook_SaveGameWrite (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{U} StrBuilder:     StrLib.TStrBuilder;
    NumSections:    integer;
    SectionNameLen: integer;
    SectionName:    string;
    DataLen:        integer;
    BuiltData:      string;
    TotalWritten:   integer; // Trying to fix game diff algorythm in online games
    PaddingSize:    integer;
    
  procedure GzipWrite (Addr: pointer; Count: integer);
  begin
    Inc(TotalWritten, Count);
    Heroes.GzipWrite(Addr, Count);
  end; // .procedure GzipWrite

begin
  StrBuilder  :=  nil;
  // * * * * * //
  WritingStorage.Clear;
  
  GameExt.EraSaveEventParams;
  Erm.FireErmEvent(Erm.TRIGGER_SAVEGAME_WRITE);
  GameExt.EraRestoreEventParams;
  
  NumSections :=  WritingStorage.ItemCount;
  GzipWrite(@NumSections, sizeof(NumSections));
  TotalWritten  :=  0;
  
  WritingStorage.BeginIterate;
  
  while WritingStorage.IterateNext(SectionName, pointer(StrBuilder)) do begin
    SectionNameLen  :=  Length(SectionName);
    GzipWrite(@SectionNameLen, sizeof(SectionNameLen));
    GzipWrite(pointer(SectionName), SectionNameLen);
    
    BuiltData :=  StrBuilder.BuildStr;
    DataLen   :=  Length(BuiltData);
    GzipWrite(@DataLen, sizeof(DataLen));
    GzipWrite(pointer(BuiltData), Length(BuiltData));
    
    StrBuilder  :=  nil;
  end; // .while
  
  WritingStorage.EndIterate;
  
  (*
  Trying to fix Heroes 3 diff problem: both images should have equal size
  Pad the data to specified size
  *)
  if EraSectionsSize <> 0 then begin
    if TotalWritten > EraSectionsSize then begin
      Core.FatalError('Too small SavedGameExtraBlockSize: ' + IntToStr(EraSectionsSize) + #13#10 + 'Size required is at least: ' + IntToStr(TotalWritten));
    end // .if
    else if TotalWritten < EraSectionsSize then begin
      PaddingSize :=  EraSectionsSize - TotalWritten;
      
      if Length(ZeroBuf) < PaddingSize then begin
        SetLength(ZeroBuf, PaddingSize);
        FillChar(ZeroBuf[1], PaddingSize, 0);
      end; // .if
      
      GzipWrite(pointer(ZeroBuf), PaddingSize);
    end; // .ELSEIF
  end; // .if
  
  // default code
  if PINTEGER(Context.EBP - 4)^ = 0 then begin
    Context.RetAddr :=  Ptr($704EF2);
  end // .if
  else begin
    Context.RetAddr :=  Ptr($704F10);
  end; // .else
  
  result  :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_SaveGameWrite

function Hook_SaveGameRead (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{U} StoredData:     TStoredData;
    NumSections:    integer;
    SectionNameLen: integer;
    SectionName:    string;
    DataLen:        integer;
    SectionData:    string;
    i:              integer;

begin
  StoredData  :=  nil;
  // * * * * * //
  ReadingStorage.Clear;
  Heroes.GzipRead(@NumSections, sizeof(NumSections));
  
  for i:=1 to NumSections do begin
    Heroes.GzipRead(@SectionNameLen, sizeof(SectionNameLen));
    SetLength(SectionName, SectionNameLen);
    Heroes.GzipRead(pointer(SectionName), SectionNameLen);
    
    Heroes.GzipRead(@DataLen, sizeof(DataLen));
    SetLength(SectionData, DataLen);
    Heroes.GzipRead(pointer(SectionData), DataLen);
    
    StoredData                  :=  TStoredData.Create;
    StoredData.Data             :=  SectionData; SectionData  :=  '';
    StoredData.ReadingPos       :=  0;
    ReadingStorage[SectionName] :=  StoredData;
  end; // .for
  
  GameExt.EraSaveEventParams;
  Erm.FireErmEvent(Erm.TRIGGER_SAVEGAME_READ);
  GameExt.EraRestoreEventParams;
  
  // default code
  if PINTEGER(Context.EBP - $14)^ = 0 then begin
    Context.RetAddr :=  Ptr($7051BE);
  end // .if
  else begin
    Context.RetAddr :=  Ptr($7051DC);
  end; // .else
  
  result  :=  not Core.EXEC_DEF_CODE;
end; // .function Hook_SaveGameRead

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  Core.Hook(@Hook_SaveGame, Core.HOOKTYPE_BRIDGE, 5, Ptr($4BEB65));
  Core.Hook(@Hook_SaveGameWrite, Core.HOOKTYPE_BRIDGE, 6, Ptr($704EEC));
  Core.Hook(@Hook_SaveGameRead, Core.HOOKTYPE_BRIDGE, 6, Ptr($7051B8));
  
  // Remove Erm Trigger "BeforeSaveGame" Call
  FillChar(pointer($7051F5)^, 5, $90);
end; // .procedure OnAfterWoG

begin
  WritingStorage  :=  AssocArrays.NewStrictAssocArr(StrLib.TStrBuilder);
  ReadingStorage  :=  AssocArrays.NewStrictAssocArr(TStoredData);
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
end.
