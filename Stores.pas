unit Stores;
(*
  Description: Provides ability to store safely data in savegames using named sections
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  Math,
  SysUtils,
  Windows,

  AssocArrays,
  Core,
  Crypto,
  DataLib,
  Files,
  StrLib,
  Utils,

  EraSettings,
  EventMan,
  GameExt,
  Heroes;

const
  DUMP_SAVEGAME_SECTIONS_DIR = EraSettings.DEBUG_DIR + '\Savegame Sections';

type
  (* Import *)
  TAssocArray = AssocArrays.TAssocArray;
  TStrBuilder = StrLib.TStrBuilder;

  // Rider for some data source, for instance savegame section.
  IRider = interface
    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: string);
    procedure WritePchar ({n} Str: pchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: string;
    procedure Flush;
  end; // .interface IRider

  TMemWriter = class (TInterfacedObject, IRider)
   public
    constructor Create;
    destructor  Destroy; override;

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: string);
    procedure WritePchar ({n} Str: pchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: string;
    procedure Flush;

    function BuildBuf: Utils.TArrayOfByte;

   private
    {O} fDataBuilder: TStrBuilder;
  end; // .class TMemRider

  TMemReader = class (TInterfacedObject, IRider)
   public
    constructor Create (BufSize: integer; {Un} Buf: pointer);

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: string);
    procedure WritePchar ({n} Str: pchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;
    function  ReadByte: byte;
    function  ReadInt: integer;
    function  ReadStr: string;
    procedure Flush;

   private
    fReader: StrLib.IByteSource;
  end; // .class TMemRider


const
  ZvsErmTriggerBeforeSave: Utils.TProcedure = Ptr($750093);


procedure WriteSavegameSection(DataSize: integer; {n} Data: pointer; const SectionName: string);
function  ReadSavegameSection (DataSize: integer; {n} Dest: pointer; const SectionName: string): integer;
function  NewRider (const SectionName: string): IRider;


var
  DumpSavegameSectionsOpt: boolean;


(***) implementation (***)


uses Erm;


type
  TStoredData = class
    Data:       string;
    ReadingPos: integer;
  end;

  // Cached I/O for sections
  TRider = class (TInterfacedObject, IRider)
   public
    constructor Create (const aSectionName: string);
    destructor  Destroy; override;

    procedure Write (Size: integer; {n} Addr: pbyte);
    procedure WriteByte (Value: byte);
    procedure WriteInt (Value: integer);
    procedure WriteStr (const Str: string);
    procedure WritePchar ({n} Str: pchar);
    function  Read (Size: integer; {n} Addr: pbyte): integer;

    // if nothing to read, returns 0
    function  ReadByte: byte;

    // if nothing to read, returns 0
    function  ReadInt: integer;

    // if nothing to read, return ''
    function  ReadStr: string;

    procedure Flush;

   private
    fSectionName:   string;
    fReadingBuf:    array [0..8149] of byte;
    fWritingBuf:    array [0..8149] of byte;
    fReadingBufPos: integer; // Starts from zero
    fWritingBufPos: integer; // Starts from zero
    fNumBytesRead:  integer;
  end; // .class TRider


var
{O} WritingStorage: {O} TAssocArray {OF Data: StrLib.TStrBuilder};
{O} ReadingStorage: {O} TAssocArray {OF StoredData: TStoredData};
    ZeroBuf:        string;


procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; const SectionName: string);
var
{U} Section: StrLib.TStrBuilder;

begin
  {!} Assert(Utils.IsValidBuf(Data, DataSize));
  Section := nil;
  // * * * * * //
  if DataSize > 0 then begin
    Section := WritingStorage[SectionName];

    if Section = nil then begin
      Section                     := StrLib.TStrBuilder.Create;
      WritingStorage[SectionName] := Section;
    end;

    Section.AppendBuf(DataSize, Data);

    if DumpSavegameSectionsOpt then begin
      Files.AppendFileContents(StrLib.BufToStr(Data, DataSize), GameExt.GameDir + '\' + DUMP_SAVEGAME_SECTIONS_DIR + '\' + SectionName + '.chunks.txt');
    end;
  end; // .if
end; // .procedure WriteSavegameSection

function ReadSavegameSection (DataSize: integer; {n} Dest: pointer; const SectionName: string)
                              : integer;
var
{U} Section: TStoredData;

begin
  {!} Assert(Utils.IsValidBuf(Dest, DataSize));
  Section := nil;
  // * * * * * //
  result := 0;

  if DataSize > 0 then begin
    Section := ReadingStorage[SectionName];

    if Section <> nil then begin
      result := Math.Min(DataSize, Length(Section.Data) - Section.ReadingPos);
      Utils.CopyMem(result, pointer(@Section.Data[1 + Section.ReadingPos]), Dest);
      Inc(Section.ReadingPos, result);
    end;
  end;
end; // .function ReadSavegameSection

constructor TRider.Create (const aSectionName: string);
begin
  fSectionName   := aSectionName;
  fReadingBufPos := 0;
  fWritingBufPos := 0;
  fNumBytesRead  := 0;
end;

destructor TRider.Destroy;
begin
  Flush;
end;

procedure TRider.Write (Size: integer; {n} Addr: pbyte);
begin
  {!} Assert(Utils.IsValidBuf(Addr, Size));
  if Size > 0 then begin
    // if no more space in cache - flush the cache
    if sizeof(fWritingBuf) - fWritingBufPos < Size then begin
      Flush;
    end;

    // if it's enough space in cache to hold passed data then write data to cache
    if sizeof(fWritingBuf) - fWritingBufPos >= Size then begin
      Utils.CopyMem(Size, Addr, @fWritingBuf[fWritingBufPos]);
      Inc(fWritingBufPos, Size);
    end
    // else cache is too small, write directly to section
    else begin
      WriteSavegameSection(Size, Addr, fSectionName);
    end;
  end; // .if
end; // .procedure TRider.Write

procedure TRider.WriteByte (Value: byte);
begin
  Write(sizeof(Value), @Value);
end;

procedure TRider.WriteInt (Value: integer);
begin
  Write(sizeof(Value), @Value);
end;

procedure TRider.WriteStr (const Str: string);
var
  StrLen: integer;

begin
  StrLen := Length(Str);
  WriteInt(StrLen);

  if StrLen > 0 then begin
    Write(StrLen, pointer(Str));
  end;
end; // .procedure TRider.WriteStr

procedure TRider.WritePchar ({n} Str: pchar);
var
  StrLen: integer;

begin
  StrLen := 0;

  if Str <> nil then begin
    StrLen := Windows.LStrLen(Str);
  end;

  WriteInt(StrLen);

  if StrLen > 0 then begin
    Write(StrLen, pointer(Str));
  end;
end; // .procedure TRider.WritePchar

procedure TRider.Flush;
begin
  WriteSaveGameSection(fWritingBufPos, @fWritingBuf[0], fSectionName);
  fWritingBufPos := 0;
end;

function TRider.Read (Size: integer; {n} Addr: pbyte): integer;
var
  NumBytesToCopy: integer;

begin
  {!} Assert(Utils.IsValidBuf(Addr, Size));
  result := 0;

  if Size > 0 then begin
    // if there is some data in cache
    if fNumBytesRead > 0 then begin
      result := Math.Min(Size, fNumBytesRead);
      Utils.CopyMem(result, @fReadingBuf[fReadingBufPos], Addr);
      Dec(Size,           result);
      Dec(fNumBytesRead,  result);
      Inc(Addr,           result);
      Inc(fReadingBufPos, result);
    end;

    // if client expects more data to be read than it's in cache. Cache is empty
    if Size > 0 then begin
      // if requested data chunk is too big, no sense to cache it
      if Size >= sizeof(fReadingBuf) then begin
        Inc(result, ReadSavegameSection(Size, Addr, fSectionName));
      end // .if
      // try to fill cache with New data and pass its portion to the client
      else begin
        fNumBytesRead := ReadSavegameSection(sizeof(fReadingBuf), @fReadingBuf[0], fSectionName);

        if fNumBytesRead > 0 then begin
          NumBytesToCopy := Math.Min(Size, fNumBytesRead);
          Utils.CopyMem(NumBytesToCopy, @fReadingBuf[0], Addr);
          fReadingBufPos := NumBytesToCopy;
          Dec(fNumBytesRead, NumBytesToCopy);
          Inc(result, NumBytesToCopy);
        end;
      end; // .else
    end; // .if
  end; // .if
end; // .procedure TRider.Read

function TRider.ReadByte: byte;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TRider.ReadInt: integer;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TRider.ReadStr: string;
var
  StrLen:       integer;
  NumBytesRead: integer;

begin
  StrLen := ReadInt;
  {!} Assert(StrLen >= 0);
  SetLength(result, StrLen);

  if StrLen > 0 then begin
    NumBytesRead := Read(StrLen, pointer(result));
    {!} Assert(NumBytesRead = StrLen);
  end;
end; // .function TRider.ReadStr

function NewRider (const SectionName: string): IRider;
begin
  result := TRider.Create(SectionName);
end;

constructor TMemWriter.Create;
begin
  Self.fDataBuilder := TStrBuilder.Create;
end;

destructor TMemWriter.Destroy;
begin
  SysUtils.FreeAndNil(Self.fDataBuilder);
end;

procedure TMemWriter.Write (Size: integer; {n} Addr: pbyte);
begin
  Self.fDataBuilder.AppendBuf(Size, Addr);
end;

procedure TMemWriter.WriteByte (Value: byte);
begin
  Self.fDataBuilder.WriteByte(Value);
end;

procedure TMemWriter.WriteInt (Value: integer);
begin
  Self.fDataBuilder.WriteInt(Value);
end;

procedure TMemWriter.WriteStr (const Str: string);
begin
  Self.fDataBuilder.WriteInt(Length(Str));
  Self.fDataBuilder.Append(Str);
end;

procedure TMemWriter.WritePchar ({n} Str: pchar);
var
  StrLen: integer;

begin
  StrLen := 0;

  if Str <> nil then begin
    StrLen := Windows.LStrLen(Str);
  end;

  Self.fDataBuilder.WriteInt(StrLen);

  if StrLen > 0 then begin
    Self.fDataBuilder.AppendBuf(StrLen, pointer(Str));
  end;
end; // .procedure TMemWriter.WritePchar

procedure TMemWriter.Flush;
begin
  // Do nothing
end;

function TMemWriter.Read (Size: integer; {n} Addr: pbyte): integer;
begin
  {!} Assert(false, 'TMemWriter.Read is not implemented');
  result := 0;
end;

function TMemWriter.ReadByte: byte;
begin
  {!} Assert(false, 'TMemWriter.ReadByte is not implemented');
  result := 0;
end;

function TMemWriter.ReadInt: integer;
begin
  {!} Assert(false, 'TMemWriter.ReadInt is not implemented');
  result := 0;
end;

function TMemWriter.ReadStr: string;
begin
  {!} Assert(false, 'TMemWriter.ReadStr is not implemented');
  result := '';
end;

function TMemWriter.BuildBuf: Utils.TArrayOfByte;
begin
  result := Self.fDataBuilder.BuildBuf;
end;

constructor TMemReader.Create (BufSize: integer; {Un} Buf: pointer);
begin
  Self.fReader := StrLib.BufAsByteSource(Buf, BufSize);
end;

procedure TMemReader.Write (Size: integer; {n} Addr: pbyte);
begin
  {!} Assert(false, 'TMemReader.Write is not implemented');
end;

procedure TMemReader.WriteByte (Value: byte);
begin
  {!} Assert(false, 'TMemReader.WriteByte is not implemented');
end;

procedure TMemReader.WriteInt (Value: integer);
begin
  {!} Assert(false, 'TMemReader.WriteInt is not implemented');
end;

procedure TMemReader.WriteStr (const Str: string);
begin
  {!} Assert(false, 'TMemReader.WriteStr is not implemented');
end;

procedure TMemReader.WritePchar ({n} Str: pchar);
begin
  {!} Assert(false, 'TMemReader.WritePchar is not implemented');
end;

procedure TMemReader.Flush;
begin
  // Do nothing
end;

function TMemReader.Read (Size: integer; {n} Addr: pbyte): integer;
begin
  result := Self.fReader.Read(Size, Addr);
end;

function TMemReader.ReadByte: byte;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Self.fReader.Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TMemReader.ReadInt: integer;
var
  NumBytesRead: integer;

begin
  result       := 0;
  NumBytesRead := Self.fReader.Read(sizeof(result), @result);
  {!} Assert((NumBytesRead = sizeof(result)) or (NumBytesRead = 0));
end;

function TMemReader.ReadStr: string;
var
  StrLen:       integer;
  NumBytesRead: integer;

begin
  StrLen := Self.ReadInt;
  {!} Assert(StrLen >= 0);
  SetLength(result, StrLen);

  if StrLen > 0 then begin
    NumBytesRead := Self.fReader.Read(StrLen, pointer(result));
    {!} Assert(NumBytesRead = StrLen);
  end;
end; // .function TMemReader.ReadStr

function Hook_SaveGame (Context: Core.PHookContext): LONGBOOL; stdcall;
const
  PARAM_SAVEGAME_NAME = 1;

var
{U} OldSavegameName:  pchar;
{U} SavegameName:     pchar;
    SavegameNameLen:  integer;

begin
  OldSavegameName := PPOINTER(Context.EBP + 8)^;
  SavegameName    := nil;
  // * * * * * //
  Erm.ArgXVars[PARAM_SAVEGAME_NAME] := integer(OldSavegameName);
  ZvsErmTriggerBeforeSave;
  SavegameName    := Ptr(Erm.RetXVars[PARAM_SAVEGAME_NAME]);
  SavegameNameLen := SysUtils.StrLen(SavegameName);

  if SavegameName <> OldSavegameName then begin
    Utils.CopyMem(SavegameNameLen + 1, SavegameName, OldSavegameName);
    pinteger(Context.EBP + 12)^ := -1;
  end;

  result := true;
end; // .function Hook_SaveGame

function Hook_SaveGameWrite (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{U} StrBuilder:     StrLib.TStrBuilder;
    NumSections:    integer;
    SectionNameLen: integer;
    DataLen:        integer;
    BuiltData:      string;
    TotalWritten:   integer; // Trying to fix game diff algorithm in online games

  procedure GzipWrite (Count: integer; {n} Addr: pointer);
  begin
    Inc(TotalWritten, Count);
    Heroes.GzipWrite(Count, Addr);
  end;

begin
  StrBuilder := nil;
  // * * * * * //
  if DumpSavegameSectionsOpt then begin
    Files.DeleteDir(GameExt.GameDir + '\' + DUMP_SAVEGAME_SECTIONS_DIR);
    SysUtils.CreateDir(GameExt.GameDir + '\' + DUMP_SAVEGAME_SECTIONS_DIR);
  end;

  WritingStorage.Clear;
  Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_WRITE, []);
  EventMan.GetInstance.Fire('$OnEraSaveScripts', GameExt.NO_EVENT_DATA, 0);

  TotalWritten := 0;
  NumSections  := WritingStorage.ItemCount;
  GzipWrite(sizeof(NumSections), @NumSections);

  with DataLib.IterateDict(WritingStorage) do begin
    while IterNext do begin
      SectionNameLen := Length(IterKey);
      GzipWrite(sizeof(SectionNameLen), @SectionNameLen);
      GzipWrite(SectionNameLen, pointer(IterKey));

      BuiltData := (IterValue AS StrLib.TStrBuilder).BuildStr;
      DataLen   := Length(BuiltData);
      GzipWrite(sizeof(DataLen), @DataLen);
      GzipWrite(Length(BuiltData), pointer(BuiltData));

      if DumpSavegameSectionsOpt then begin
        Files.WriteFileContents(BuiltData, DUMP_SAVEGAME_SECTIONS_DIR
                                           + '\' + IterKey + '.data');
      end;
    end; // .while
  end; // .with

  // Default code
  if pinteger(Context.EBP - 4)^ = 0 then begin
    Context.RetAddr := Ptr($704EF2);
  end else begin
    Context.RetAddr := Ptr($704F10);
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_SaveGameWrite

function Hook_SaveGameRead (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{U} StoredData:     TStoredData;
    BytesRead:      integer;
    NumSections:    integer;
    SectionNameLen: integer;
    SectionName:    string;
    DataLen:        integer;
    SectionData:    string;
    i:              integer;

  procedure ForceGzipRead (Count: integer; {n} Addr: pointer);
  begin
    BytesRead := Heroes.GzipRead(Count, Addr);
    {!} Assert(BytesRead = Count);
  end;

begin
  StoredData := nil;
  // * * * * * //
  ReadingStorage.Clear;
  NumSections := 0;
  BytesRead   := Heroes.GzipRead(sizeof(NumSections), @NumSections);
  {!} Assert((BytesRead = sizeof(NumSections)) or (BytesRead = 0), 'Failed to read NumSections:integer from saved game');

  for i:=1 to NumSections do begin
    ForceGzipRead(sizeof(SectionNameLen), @SectionNameLen);
    {!} Assert(SectionNameLen >= 0);
    SetLength(SectionName, SectionNameLen);
    ForceGzipRead(SectionNameLen, pointer(SectionName));

    ForceGzipRead(sizeof(DataLen), @DataLen);
    {!} Assert(DataLen >= 0);
    SetLength(SectionData, DataLen);
    ForceGzipRead(DataLen, pointer(SectionData));

    StoredData                  := TStoredData.Create;
    StoredData.Data             := SectionData; SectionData := '';
    StoredData.ReadingPos       := 0;
    ReadingStorage[SectionName] := StoredData;
  end; // .for

  EventMan.GetInstance.Fire('$OnEraLoadScripts', GameExt.NO_EVENT_DATA, 0);
  Erm.FireErmEventEx(Erm.TRIGGER_SAVEGAME_READ, []);

  // default code
  if pinteger(Context.EBP - $14)^ = 0 then begin
    Context.RetAddr := Ptr($7051BE);
  end else begin
    Context.RetAddr := Ptr($7051DC);
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_SaveGameRead

procedure OnLoadEraSettings (Event: GameExt.PEvent); stdcall;
begin
  DumpSavegameSectionsOpt := EraSettings.GetDebugBoolOpt('Debug.DumpSavegameSections', false);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  Core.Hook(Ptr($4BEB65), Core.HOOKTYPE_BRIDGE, @Hook_SaveGame);
  Core.Hook(Ptr($704EEC), Core.HOOKTYPE_BRIDGE, @Hook_SaveGameWrite);
  Core.Hook(Ptr($7051B8), Core.HOOKTYPE_BRIDGE, @Hook_SaveGameRead);

  (* Remove Erm trigger "BeforeSaveGame" call *)
  Core.p.WriteDataPatch(Ptr($7051F5), ['9090909090']);
end;

begin
  WritingStorage := AssocArrays.NewStrictAssocArr(StrLib.TStrBuilder);
  ReadingStorage := AssocArrays.NewStrictAssocArr(TStoredData);
  EventMan.GetInstance.On('$OnLoadEraSettings', OnLoadEraSettings);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
