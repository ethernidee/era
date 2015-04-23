UNIT GameExt;
{
DESCRIPTION:  Game extension support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Utils, Lists, CFiles, Files, Crypto, AssocArrays,
  Math, Core;

CONST
  (* Pathes *)
  ERA_DLL_NAME  = 'era.dll';
  PLUGINS_PATH  = 'EraPlugins';
  PATCHES_PATH  = 'EraPlugins';
  
  CONST_STR = -1;
  
  NO_EVENT_DATA = NIL;
  
  ERA_VERSION_STR = '2.461';
  ERA_VERSION_INT = 2461;


TYPE
  PPatchFile  = ^TPatchFile;
  TPatchFile  = PACKED RECORD (* FORMAT *)
    NumPatches: INTEGER;
    (*
    Patches:    ARRAY NumPatches OF TBinPatch;
    *)
    Patches:    Utils.TEmptyRec;
  END; // .RECORD TPatchFile

  PBinPatch = ^TBinPatch;
  TBinPatch = PACKED RECORD (* FORMAT *)
    Addr:     POINTER;
    NumBytes: INTEGER;
    (*
    Bytes:    ARRAY NumBytes OF BYTE;
    *)
    Bytes:    Utils.TEmptyRec;
  END; // .RECORD TBinPatch

  PEvent  = ^TEvent;
  TEvent  = PACKED RECORD
      Name:     STRING;
  {n} Data:     POINTER;
      DataSize: INTEGER;
  END; // .RECORD TEvent

  TEventHandler = PROCEDURE (Event: PEvent); STDCALL;
  
  PEraEventParams = ^TEraEventParams;
  TEraEventParams = ARRAY [0..15] OF INTEGER;
  
  PMemRedirection = ^TMemRedirection;
  TMemRedirection = RECORD
    OldAddr:    POINTER;
    BlockSize:  INTEGER;
    NewAddr:    POINTER;
  END; // .RECORD TMemRedirection


PROCEDURE RegisterHandler (Handler: TEventHandler; CONST EventName: STRING); STDCALL;
PROCEDURE FireEvent (CONST EventName: STRING; {n} EventData: POINTER; DataSize: INTEGER); STDCALL;
FUNCTION  PatchExists (CONST PatchName: STRING): BOOLEAN; STDCALL;
FUNCTION  PluginExists (CONST PluginName: STRING): BOOLEAN; STDCALL;
PROCEDURE RedirectMemoryBlock (OldAddr: POINTER; BlockSize: INTEGER; NewAddr: POINTER); STDCALL;
FUNCTION  GetRealAddr (Addr: POINTER): POINTER; STDCALL;


PROCEDURE Init (hDll: INTEGER);


VAR
{O} PluginsList:            Lists.TStringList {OF TDllHandle};
{O} Events:                 {O} AssocArrays.TAssocArray {OF Lists.TList};
    hAngel:                 INTEGER;  // Era 1.8x DLL
    hEra:                   INTEGER;  // Era 1.9+ DLL
    (* Compability with Era 1.8x *)
    EraInit:                Utils.TProcedure;
    EraSaveEventParams:     Utils.TProcedure;
    EraRestoreEventParams:  Utils.TProcedure;
{U} EraEventParams:         PEraEventParams;

{O} MemRedirections:        {O} Lists.TList {OF PMemRedirection};


(***) IMPLEMENTATION (***)


PROCEDURE LoadPlugins;
CONST
  ERM_V_1 = $887668;

VAR
{O} Locator:    Files.TFileLocator;
{O} ItemInfo:   Files.TFileItemInfo;
    DllName:    STRING;
    DllHandle:  INTEGER;
  
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  NIL;
  // * * * * * //
  Locator.DirPath :=  PLUGINS_PATH;
  Locator.InitSearch('*.era');
  
  WHILE Locator.NotEnd DO BEGIN
    // Providing Era Handle in v1
    PINTEGER(ERM_V_1)^  :=  hEra;
    DllName             :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(ItemInfo)));
    IF
      NOT ItemInfo.IsDir                          AND
      (SysUtils.ExtractFileExt(DllName) = '.era') AND
      ItemInfo.HasKnownSize                       AND
      (ItemInfo.FileSize > 0)
    THEN BEGIN
      DllHandle :=  Windows.LoadLibrary(PCHAR(PLUGINS_PATH + '\' + DllName));
      {!} ASSERT(DllHandle <> 0);
      Windows.DisableThreadLibraryCalls(DllHandle);
      PluginsList.AddObj(DllName, Ptr(DllHandle));
    END; // .IF
    
    SysUtils.FreeAndNil(ItemInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .PROCEDURE LoadPlugins

PROCEDURE ApplyBinPatch (CONST FilePath: STRING);
VAR
{U} Patch:      PBinPatch;
    FileData:   STRING;
    NumPatches: INTEGER;
    i:          INTEGER;  
  
BEGIN
  IF NOT Files.ReadFileContents(FilePath, FileData) THEN BEGIN
    Core.FatalError('Cannot open binary patch file "' + FilePath + '"');
  END // .IF
  ELSE BEGIN
    NumPatches  :=  PPatchFile(FileData).NumPatches;
    Patch       :=  @PPatchFile(FileData).Patches;
    TRY
      FOR i:=1 TO NumPatches DO BEGIN
        Core.WriteAtCode(Patch.NumBytes, @Patch.Bytes, Patch.Addr);
        Patch :=  Utils.PtrOfs(Patch, SIZEOF(Patch^) + Patch.NumBytes);
      END; // .FOR 
    EXCEPT
      Core.FatalError('Cannot apply binary patch file "' + FilePath + '"'#13#10'Access violation');
    END; // .TRY
  END; // .ELSE
END; // .PROCEDURE ApplyBinPatch

PROCEDURE ApplyPatches (CONST SubFolder: STRING);
CONST
  MIN_PATCH_SIZE  = 4;

VAR
{O} Locator:  Files.TFileLocator;
{O} ItemInfo: Files.TFileItemInfo;
    FileName: STRING;
  
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  NIL;
  // * * * * * //
  Locator.DirPath :=  PATCHES_PATH + '\' + SubFolder;
  Locator.InitSearch('*.bin');
  
  WHILE Locator.NotEnd DO BEGIN
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(ItemInfo)));
    IF
      NOT ItemInfo.IsDir                            AND
      (SysUtils.ExtractFileExt(FileName) = '.bin')  AND
      ItemInfo.HasKnownSize                         AND
      (ItemInfo.FileSize > MIN_PATCH_SIZE)
    THEN BEGIN
      ApplyBinPatch(Locator.DirPath + '\' + FileName);
    END; // .IF
    
    SysUtils.FreeAndNil(ItemInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .PROCEDURE ApplyPatches

PROCEDURE InitWoG; ASSEMBLER;
ASM
  MOV EAX, $70105A
  CALL EAX
  MOV EAX, $774483
  CALL EAX
  MOV ECX, $28AAFD0
  MOV EAX, $706CC0
  CALL EAX
  MOV EAX, $701215
  CALL EAX
END; // .PROCEDURE InitWoG

PROCEDURE RegisterHandler (Handler: TEventHandler; CONST EventName: STRING);
VAR
{U} Handlers: {U} Lists.TList {OF TEventHandler};
  
BEGIN
  {!} ASSERT(@Handler <> NIL);
  Handlers  :=  Events[EventName];
  // * * * * * //
  IF Handlers = NIL THEN BEGIN
    Handlers          :=  Lists.NewSimpleList;
    Events[EventName] :=  Handlers;
  END; // .IF
  
  Handlers.Add(@Handler);
END; // .PROCEDURE RegisterHandler

PROCEDURE FireEvent (CONST EventName: STRING; {n} EventData: POINTER; DataSize: INTEGER);
VAR
{O} Event:    PEvent;
{U} Handlers: {U} Lists.TList {OF TEventHandler};
    i:        INTEGER;

BEGIN
  {!} ASSERT(DataSize >= 0);
  {!} ASSERT((EventData <> NIL) OR (DataSize = 0));
  NEW(Event);
  Handlers  :=  Events[EventName];
  // * * * * * //
  Event.Name      :=  EventName;
  Event.Data      :=  EventData;
  Event.DataSize  :=  DataSize;
  
  IF Handlers <> NIL THEN BEGIN
    FOR i:=0 TO Handlers.Count - 1 DO BEGIN
      TEventHandler(Handlers[i])(Event);
    END; // .FOR
  END; // .IF
  // * * * * * //
  DISPOSE(Event);
END; // .PROCEDURE FireEvent

FUNCTION PatchExists (CONST PatchName: STRING): BOOLEAN;
CONST
  MIN_PATCH_SIZE  = 4;

VAR
  FileSize: INTEGER;

BEGIN
  RESULT  :=
  (
    Files.GetFileSize(PATCHES_PATH + '\' + PatchName + '.bin', FileSize)  AND
    (FileSize > MIN_PATCH_SIZE)
  ) OR
  (
    Files.GetFileSize(PATCHES_PATH + '\BeforeWoG\' + PatchName + '.bin', FileSize)  AND
    (FileSize > MIN_PATCH_SIZE)
  ) OR
  (
    Files.GetFileSize(PATCHES_PATH + '\AfterWoG\' + PatchName + '.bin', FileSize) AND
    (FileSize > MIN_PATCH_SIZE)
  );
END; // .FUNCTION PatchExists

FUNCTION PluginExists (CONST PluginName: STRING): BOOLEAN;
VAR
  FileSize: INTEGER;

BEGIN
  RESULT  :=
    (Files.GetFileSize(PLUGINS_PATH + '\' + PluginName + '.dll', FileSize) AND (FileSize > 0))  OR
    (Files.GetFileSize(PLUGINS_PATH + '\' + PluginName + '.era', FileSize) AND (FileSize > 0));
END; // .FUNCTION PluginExists

FUNCTION CompareMemoryBlocks
(
  Addr1:  POINTER;
  Size1:  INTEGER;
  Addr2:  POINTER;
  Size2:  INTEGER
): INTEGER;

BEGIN
  {!} ASSERT(Size1 > 0);
  {!} ASSERT(Size2 > 0);
  IF
    (
      Math.Max(CARDINAL(Addr1) + CARDINAL(Size1), CARDINAL(Addr2) + CARDINAL(Size2)) -
      Math.Min(CARDINAL(Addr1), CARDINAL(Addr2))
    ) < (CARDINAL(Size1) + CARDINAL(Size2))
  THEN BEGIN
    RESULT  :=  0;
  END // .IF
  ELSE IF CARDINAL(Addr1) < CARDINAL(Addr2) THEN BEGIN
    RESULT  :=  -1;
  END // .ELSEIF
  ELSE BEGIN
    RESULT  :=  +1;
  END; // .ELSE
END; // .FUNCTION CompareMemoryBlocks

FUNCTION FindMemoryRedirection (Addr: POINTER; Size: INTEGER; OUT {i} BlockInd: INTEGER): BOOLEAN;
VAR
{U} Redirection:    PMemRedirection;
    LeftInd:        INTEGER;
    RightInd:       INTEGER;
    ComparisonRes:  INTEGER; 
  
BEGIN
  {!} ASSERT(Size >= 0);
  Redirection :=  NIL;
  
  // * * * * * //
  RESULT    :=  FALSE;
  LeftInd   :=  0;
  RightInd  :=  MemRedirections.Count - 1;
  
  WHILE (LeftInd <= RightInd) AND NOT RESULT DO BEGIN
    BlockInd      :=  LeftInd + (RightInd - LeftInd) DIV 2;
    Redirection   :=  MemRedirections[BlockInd];
    ComparisonRes :=  CompareMemoryBlocks(Addr, Size, Redirection.OldAddr, Redirection.BlockSize);
    RESULT        :=  ComparisonRes = 0;
    
    IF ComparisonRes < 0 THEN BEGIN
      RightInd  :=  BlockInd - 1;
    END // .IF
    ELSE IF ComparisonRes > 0 THEN BEGIN
      LeftInd   :=  BlockInd + 1;
    END; // .ELSEIF
  END; // .WHILE

  IF NOT RESULT THEN BEGIN
    BlockInd :=  LeftInd;
  END; // .IF
END; // .FUNCTION FindMemoryRedirection

PROCEDURE RedirectMemoryBlock (OldAddr: POINTER; BlockSize: INTEGER; NewAddr: POINTER);
VAR
{U} OldRedirection: PMemRedirection;
{O} NewRedirection: PMemRedirection;
    BlockInd:       INTEGER;
   
BEGIN
  {!} ASSERT(OldAddr <> NIL);
  {!} ASSERT(BlockSize > 0);
  {!} ASSERT(NewAddr <> NIL);
  OldRedirection  :=  NIL;
  NewRedirection  :=  NIL;
  // * * * * * //
  IF NOT FindMemoryRedirection(OldAddr, BlockSize, BlockInd) THEN BEGIN
    NEW(NewRedirection);
    NewRedirection.OldAddr    :=  OldAddr;
    NewRedirection.BlockSize  :=  BlockSize;
    NewRedirection.NewAddr    :=  NewAddr;
    MemRedirections.Insert(NewRedirection, BlockInd); NewRedirection  :=  NIL;
  END // .IF
  ELSE BEGIN
    OldRedirection  :=  MemRedirections[BlockInd];
    Core.FatalError
    (
      'Cannot redirect block at address $' +
      SysUtils.Format('%x', [INTEGER(OldAddr)]) +
      ' of size ' + SysUtils.IntToStr(BlockSize) +
      ' to address $' + SysUtils.Format('%x', [INTEGER(NewAddr)]) +
      #13#10' because there already exists a redirection from address ' +
      SysUtils.Format('%x', [INTEGER(OldRedirection.OldAddr)]) +
      ' of size ' + SysUtils.IntToStr(OldRedirection.BlockSize) +
      ' to address $' + SysUtils.Format('%x', [INTEGER(OldRedirection.NewAddr)])
    );
  END; // .ELSE
  // * * * * * //
  FreeMem(NewRedirection);
END; // .PROCEDURE RedirectMemoryBlock

FUNCTION GetRealAddr (Addr: POINTER): POINTER;
VAR
{U} Redirection:  PMemRedirection;
    BlockInd:     INTEGER;

BEGIN
  Redirection :=  NIL;
  // * * * * * //
  RESULT  :=  Addr;
  
  IF FindMemoryRedirection(Addr, SIZEOF(BYTE), BlockInd) THEN BEGIN
    Redirection :=  MemRedirections[BlockInd];
    RESULT      :=  Utils.PtrOfs(Redirection.NewAddr, INTEGER(Addr) - INTEGER(Redirection.OldAddr));
  END; // .IF
END; // .FUNCTION GetRealAddr

PROCEDURE Init (hDll: INTEGER);
BEGIN
  hEra  :=  hDll;
  Windows.DisableThreadLibraryCalls(hEra);
  
  FireEvent('OnEraStart', NO_EVENT_DATA, 0);
  
  (* Era 1.8x integration *)
  hAngel                :=  Windows.LoadLibrary('angel.dll');
  {!} ASSERT(hAngel <> 0);
  EraInit               :=  Windows.GetProcAddress(hAngel, 'InitEra');
  {!} ASSERT(@EraInit <> NIL);
  EraSaveEventParams    :=  Windows.GetProcAddress(hAngel, 'SaveEventParams');
  {!} ASSERT(@EraSaveEventParams <> NIL);
  EraRestoreEventParams :=  Windows.GetProcAddress(hAngel, 'RestoreEventParams');
  {!} ASSERT(@EraRestoreEventParams <> NIL);
  EraEventParams        :=  Windows.GetProcAddress(hAngel, 'EventParams');
  {!} ASSERT(EraEventParams <> NIL);
  
  LoadPlugins;
  FireEvent('OnBeforeWoG', NO_EVENT_DATA, 0);
  ApplyPatches('BeforeWoG');
  
  InitWoG;
  EraInit;
  
  FireEvent('OnAfterWoG', NO_EVENT_DATA, 0);
  ApplyPatches('AfterWoG');
END; // .PROCEDURE Init

BEGIN
  PluginsList     :=  Lists.NewSimpleStrList;
  Events          :=  AssocArrays.NewStrictAssocArr(Lists.TList);
  MemRedirections :=  Lists.NewList
  (
    Utils.OWNS_ITEMS,
    NOT Utils.ITEMS_ARE_OBJECTS,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );
END.
