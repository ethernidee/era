UNIT Stores;
{
DESCRIPTION:  Provides ability to store safely data in savegames
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  SysUtils, Math, Utils, Crypto, AssocArrays, DataLib, StrLib, DlgMes,
  Core, GameExt, Heroes, Erm;

TYPE
  (* IMPORT *)
  TAssocArray = AssocArrays.TAssocArray;
  
  // Cached I/O for sections
  IRider = INTERFACE
    PROCEDURE Write (Size: INTEGER; {n} Addr: PBYTE);
    PROCEDURE WriteInt (Value: INTEGER);
    PROCEDURE WriteStr (CONST Str: STRING);
    FUNCTION  Read (Size: INTEGER; {n} Addr: PBYTE): INTEGER;
    FUNCTION  ReadInt: INTEGER;
    FUNCTION  ReadStr: STRING;
    PROCEDURE Flush;
  END; // .INTERFACE IRider


CONST
  ZvsErmTriggerBeforeSave:  Utils.TProcedure  = Ptr($750093);


PROCEDURE WriteSavegameSection (DataSize: INTEGER; {n} Data: POINTER; CONST SectionName: STRING);
FUNCTION  ReadSavegameSection  (DataSize: INTEGER; {n} Dest: POINTER; CONST SectionName: STRING)
                               :INTEGER;
FUNCTION  NewRider (CONST SectionName: STRING): IRider;


VAR
  EraSectionsSize: INTEGER = 0; // 0 to turn off padding to fixed size


(***) IMPLEMENTATION (***)


TYPE
  TStoredData = CLASS
    Data:       STRING;
    ReadingPos: INTEGER;
  END; // .CLASS TStoredData
  
  TRider = CLASS (TInterfacedObject, IRider)
   PUBLIC 
    CONSTRUCTOR Create (CONST aSectionName: STRING);
    DESTRUCTOR  Destroy; OVERRIDE;

    PROCEDURE Write (Size: INTEGER; {n} Addr: PBYTE);
    PROCEDURE WriteInt (Value: INTEGER);
    PROCEDURE WriteStr (CONST Str: STRING);
    FUNCTION  Read (Size: INTEGER; {n} Addr: PBYTE): INTEGER;
    // If nothing to read, returns 0
    FUNCTION  ReadInt: INTEGER;
    // If nothing to read, return ''
    FUNCTION  ReadStr: STRING;
    PROCEDURE Flush;
    
   PRIVATE
    fSectionName:   STRING;
    fReadingBuf:    ARRAY [0..8149] OF BYTE;
    fWritingBuf:    ARRAY [0..8149] OF BYTE;
    fReadingBufPos: INTEGER; // Starts from zero
    fWritingBufPos: INTEGER; // Starts from zero
    fNumBytesRead:  INTEGER;
  END; // .CLASS TRider


VAR
{O} WritingStorage: {O} TAssocArray {OF Data: StrLib.TStrBuilder};
{O} ReadingStorage: {O} TAssocArray {OF StoredData: TStoredData};
    ZeroBuf:        STRING;


PROCEDURE WriteSavegameSection (DataSize: INTEGER; {n} Data: POINTER; CONST SectionName: STRING);
VAR
{U} Section: StrLib.TStrBuilder;
  
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Data, DataSize));
  Section := NIL;
  // * * * * * //
  IF DataSize > 0 THEN BEGIN
    Section := WritingStorage[SectionName];
    
    IF Section = NIL THEN BEGIN
      Section                     := StrLib.TStrBuilder.Create;
      WritingStorage[SectionName] := Section;
    END; // .IF
    
    Section.AppendBuf(DataSize, Data);
  END; // .IF
END; // .PROCEDURE WriteSavegameSection

FUNCTION ReadSavegameSection (DataSize: INTEGER; {n} Dest: POINTER; CONST SectionName: STRING)
                              : INTEGER; 
VAR
{U} Section: TStoredData;
  
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Dest, DataSize));
  Section := NIL;
  // * * * * * //
  RESULT := 0;
  
  IF DataSize > 0 THEN BEGIN
    Section := ReadingStorage[SectionName];
    
    IF Section <> NIL THEN BEGIN
      RESULT := Math.Min(DataSize, LENGTH(Section.Data) - Section.ReadingPos);
      Utils.CopyMem(RESULT, POINTER(@Section.Data[1 + Section.ReadingPos]), Dest);
      INC(Section.ReadingPos, RESULT);
    END; // .IF
  END; // .IF
END; // .FUNCTION ReadSavegameSection

CONSTRUCTOR TRider.Create (CONST aSectionName: STRING);
BEGIN
  fSectionName    := aSectionName;
  fReadingBufPos  := 0;
  fWritingBufPos  := 0;
  fNumBytesRead   := 0;
END; // .CONSTRUCTOR TRider.Create

DESTRUCTOR TRider.Destroy;
BEGIN
  Flush;
END; // .DESTRUCTOR TRider.Destroy

PROCEDURE TRider.Write (Size: INTEGER; {n} Addr: PBYTE);
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Addr, Size));
  IF Size > 0 THEN BEGIN
    // If no more space in cache - flush the cache
    IF SIZEOF(fWritingBuf) - fWritingBufPos < Size THEN BEGIN
      Flush;
    END; // .IF
    
    // If it's enough space in cache to hold passed data then write data to cache
    IF SIZEOF(fWritingBuf) - fWritingBufPos > Size THEN BEGIN
      Utils.CopyMem(Size, Addr, @fWritingBuf[fWritingBufPos]);
      INC(fWritingBufPos, Size);
    END // .IF
    // Else cache is too small, write directly to section
    ELSE BEGIN
      WriteSavegameSection(Size, Addr, fSectionName);
    END; // .ELSE
  END; // .IF
END; // .PROCEDURE TRider.Write

PROCEDURE TRider.WriteInt (Value: INTEGER);
BEGIN
  Write(SIZEOF(Value), @Value);
END; // .PROCEDURE TRider.WriteInt

PROCEDURE TRider.WriteStr (CONST Str: STRING);
VAR
  StrLen: INTEGER;

BEGIN
  StrLen := LENGTH(Str);
  WriteInt(StrLen);
  
  IF StrLen > 0 THEN BEGIN
    Write(StrLen, POINTER(Str));
  END; // .IF
END; // .PROCEDURE TRider.WriteStr

PROCEDURE TRider.Flush;
BEGIN
  WriteSaveGameSection(fWritingBufPos, @fWritingBuf[0], fSectionName);
  fWritingBufPos := 0;
END; // .PROCEDURE TRider.Flush

FUNCTION TRider.Read (Size: INTEGER; {n} Addr: PBYTE): INTEGER;
VAR
  NumBytesToCopy: INTEGER;

BEGIN
  {!} ASSERT(Utils.IsValidBuf(Addr, Size));
  RESULT := 0;
  
  IF Size > 0 THEN BEGIN
    // If there is some data in cache
    IF fNumBytesRead > 0 THEN BEGIN
      RESULT := Math.Min(Size, fNumBytesRead);
      Utils.CopyMem(RESULT, @fReadingBuf[fReadingBufPos], Addr);
      DEC(Size,           RESULT);
      DEC(fNumBytesRead,  RESULT);
      INC(Addr,           RESULT);
      INC(fReadingBufPos, RESULT);
    END; // .IF

    // If client expects more data to be read than it's in cache. Cache is empty
    IF Size > 0 THEN BEGIN
      // If requested data chunk is too big, no sense to cache it
      IF Size >= SIZEOF(fReadingBuf) THEN BEGIN
        INC(RESULT, ReadSavegameSection(Size, Addr, fSectionName));
      END // .IF
      // Try to fill cache with new data and pass its portion to the client
      ELSE BEGIN
        fNumBytesRead := ReadSavegameSection(SIZEOF(fReadingBuf), @fReadingBuf[0], fSectionName);
        
        IF fNumBytesRead > 0 THEN BEGIN
          NumBytesToCopy := Math.Min(Size, fNumBytesRead);
          Utils.CopyMem(NumBytesToCopy, @fReadingBuf[0], Addr);
          fReadingBufPos := NumBytesToCopy;
          DEC(fNumBytesRead, NumBytesToCopy);
          INC(RESULT, NumBytesToCopy);
        END; // .IF
      END; // .ELSE
    END; // .IF
  END; // .IF
END; // .PROCEDURE TRider.Read

FUNCTION TRider.ReadInt: INTEGER;
VAR
  NumBytesRead: INTEGER;

BEGIN
  RESULT       := 0;
  NumBytesRead := Read(SIZEOF(RESULT), @RESULT);
  {!} ASSERT((NumBytesRead = SIZEOF(RESULT)) OR (NumBytesRead = 0));
END; // .FUNCTION TRider.ReadInt

FUNCTION TRider.ReadStr: STRING;
VAR
  StrLen:       INTEGER;
  NumBytesRead: INTEGER;

BEGIN
  StrLen := ReadInt;
  {!} ASSERT(StrLen >= 0);
  SetLength(RESULT, StrLen);
  
  IF StrLen > 0 THEN BEGIN
    NumBytesRead := Read(StrLen, POINTER(RESULT));
    {!} ASSERT(NumBytesRead = StrLen);
  END; // .IF
END; // .FUNCTION TRider.ReadStr

FUNCTION NewRider (CONST SectionName: STRING): IRider;
BEGIN
  RESULT := TRider.Create(SectionName);
END; // .FUNCTION NewRider

FUNCTION Hook_SaveGame (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  PARAM_SAVEGAME_NAME = 0;

VAR
{U} OldSavegameName:  PCHAR;
{U} SavegameName:     PCHAR;
    SavegameNameLen:  INTEGER;
  
BEGIN
  OldSavegameName := PPOINTER(Context.EBP + 8)^;
  SavegameName    := NIL;
  // * * * * * //
  GameExt.EraSaveEventParams;
  
  GameExt.EraEventParams[PARAM_SAVEGAME_NAME] := INTEGER(OldSavegameName);
  ZvsErmTriggerBeforeSave;
  SavegameName    := Ptr(GameExt.EraEventParams[PARAM_SAVEGAME_NAME]);
  SavegameNameLen := SysUtils.StrLen(SavegameName);
  
  IF SavegameName <> OldSavegameName THEN BEGIN
    Utils.CopyMem(SavegameNameLen + 1, SavegameName, OldSavegameName);
    PINTEGER(Context.EBP + 12)^ := -1;
  END; // .IF
  
  GameExt.EraRestoreEventParams;
  
  RESULT := Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_SaveGame

FUNCTION Hook_SaveGameWrite (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
{U} StrBuilder:     StrLib.TStrBuilder;
    NumSections:    INTEGER;
    SectionNameLen: INTEGER;
    SectionName:    STRING;
    DataLen:        INTEGER;
    BuiltData:      STRING;
    TotalWritten:   INTEGER; // Trying to fix game diff algorithm in online games
    PaddingSize:    INTEGER;
    
  PROCEDURE GzipWrite (Count: INTEGER; {n} Addr: POINTER);
  BEGIN
    INC(TotalWritten, Count);
    Heroes.GzipWrite(Count, Addr);
  END; // .PROCEDURE GzipWrite

BEGIN
  StrBuilder := NIL;
  // * * * * * //
  WritingStorage.Clear;
  Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_WRITE, []);
  GameExt.FireEvent('$OnEraSaveScripts', GameExt.NO_EVENT_DATA, 0);
  
  TotalWritten := 0;
  NumSections  := WritingStorage.ItemCount;
  GzipWrite(SIZEOF(NumSections), @NumSections);
  
  WITH DataLib.IterateDict(WritingStorage) DO BEGIN
    WHILE IterNext DO BEGIN
      SectionNameLen := LENGTH(IterKey);
      GzipWrite(SIZEOF(SectionNameLen), @SectionNameLen);
      GzipWrite(SectionNameLen, POINTER(IterKey));

      BuiltData := (IterValue AS StrLib.TStrBuilder).BuildStr;
      DataLen   := LENGTH(BuiltData);
      GzipWrite(SIZEOF(DataLen), @DataLen);
      GzipWrite(LENGTH(BuiltData), POINTER(BuiltData));
    END; // .WHILE
  END; // .WITH 
  
  (* Trying to fix Heroes 3 diff problem: both images should have equal size
     Pad the data to specified size *)
  IF EraSectionsSize <> 0 THEN BEGIN
    IF TotalWritten > EraSectionsSize THEN BEGIN
      Core.FatalError('Too small SavedGameExtraBlockSize: ' + IntToStr(EraSectionsSize) + #13#10
                      + 'Size required is at least: ' + IntToStr(TotalWritten));
    END // .IF
    ELSE IF TotalWritten < EraSectionsSize THEN BEGIN
      PaddingSize := EraSectionsSize - TotalWritten;
      
      IF LENGTH(ZeroBuf) < PaddingSize THEN BEGIN
        ZeroBuf := '';
        SetLength(ZeroBuf, PaddingSize);
        FillChar(ZeroBuf[1], PaddingSize, 0);
      END; // .IF
      
      GzipWrite(PaddingSize, POINTER(ZeroBuf));
    END; // .ELSEIF
  END; // .IF
  
  // Default code
  IF PINTEGER(Context.EBP - 4)^ = 0 THEN BEGIN
    Context.RetAddr := Ptr($704EF2);
  END // .IF
  ELSE BEGIN
    Context.RetAddr := Ptr($704F10);
  END; // .ELSE
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_SaveGameWrite

FUNCTION Hook_SaveGameRead (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
{U} StoredData:     TStoredData;
    BytesRead:      INTEGER;
    NumSections:    INTEGER;
    SectionNameLen: INTEGER;
    SectionName:    STRING;
    DataLen:        INTEGER;
    SectionData:    STRING;
    i:              INTEGER;
    
  PROCEDURE ForceGzipRead (Count: INTEGER; {n} Addr: POINTER);
  BEGIN
    BytesRead := Heroes.GzipRead(Count, Addr);
    {!} ASSERT(BytesRead = Count);
  END; // .PROCEDURE ForceGzipRead

BEGIN
  StoredData := NIL;
  // * * * * * //
  ReadingStorage.Clear;
  NumSections := 0;
  BytesRead   := Heroes.GzipRead(SIZEOF(NumSections), @NumSections);
  {!} ASSERT((BytesRead = SIZEOF(NumSections)) OR (BytesRead = 0));
  
  FOR i:=1 TO NumSections DO BEGIN
    ForceGzipRead(SIZEOF(SectionNameLen), @SectionNameLen);
    {!} ASSERT(SectionNameLen >= 0);
    SetLength(SectionName, SectionNameLen);
    ForceGzipRead(SectionNameLen, POINTER(SectionName));

    ForceGzipRead(SIZEOF(DataLen), @DataLen);
    {!} ASSERT(DataLen >= 0);
    SetLength(SectionData, DataLen);
    ForceGzipRead(DataLen, POINTER(SectionData));
    
    StoredData                  := TStoredData.Create;
    StoredData.Data             := SectionData; SectionData := '';
    StoredData.ReadingPos       := 0;
    ReadingStorage[SectionName] := StoredData;
  END; // .FOR
  
  GameExt.FireEvent('$OnEraLoadScripts', GameExt.NO_EVENT_DATA, 0);
  Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_READ, []);
  
  // Default code
  IF PINTEGER(Context.EBP - $14)^ = 0 THEN BEGIN
    Context.RetAddr := Ptr($7051BE);
  END // .IF
  ELSE BEGIN
    Context.RetAddr := Ptr($7051DC);
  END; // .ELSE
  
  RESULT := NOT Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_SaveGameRead

PROCEDURE OnAfterWoG (Event: GameExt.PEvent); STDCALL;
BEGIN
  Core.Hook(@Hook_SaveGame, Core.HOOKTYPE_BRIDGE, 5, Ptr($4BEB65));
  Core.Hook(@Hook_SaveGameWrite, Core.HOOKTYPE_BRIDGE, 6, Ptr($704EEC));
  Core.Hook(@Hook_SaveGameRead, Core.HOOKTYPE_BRIDGE, 6, Ptr($7051B8));
  
  (* Remove Erm trigger "BeforeSaveGame" call *)
  Core.p.WriteDataPatch($7051F5, ['9090909090']);
END; // .PROCEDURE OnAfterWoG

BEGIN
  WritingStorage := AssocArrays.NewStrictAssocArr(StrLib.TStrBuilder);
  ReadingStorage := AssocArrays.NewStrictAssocArr(TStoredData);
  GameExt.RegisterHandler(OnAfterWoG, 'OnAfterWoG');
END.
