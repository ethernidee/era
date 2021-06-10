UNIT MapExt;
{
DESCRIPTION:  Editor extension support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Utils, Lists, Files,
  Core, AssocArrays, TypeWrappers, DlgMes, StrLib, Log;

CONST
  (* Pathes *)
  PLUGINS_PATH  = 'EraEditor';
  PATCHES_PATH  = 'EraEditor';
  
  MAX_NUM_LODS  = 100;
  
  AB_AND_SOD  = 3;
  
  GameVersion:  PINTEGER  = Ptr($596F58);
  
  LINE_END  = #13#10;
  
  ZEOBJTS_DIR = 'Data\Objects';


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
  
  PLod  = ^TLod;
  TLod  = PACKED RECORD
    Dummy:  ARRAY [0..399] OF BYTE;
  END; // .RECORD TLod
  
  PLodTable = ^TLodTable;
  TLodTable = ARRAY [0..99] OF TLod;
  
  TGameVersion  = 0..3;
  TLodType      = (LOD_SPRITE = 1, LOD_BITMAP = 2, LOD_WAV = 3);
  
  PIndexes  = ^TIndexes;
  TIndexes  = ARRAY [0..MAX_NUM_LODS - 1] OF INTEGER;
  
  TLodIndexes = PACKED RECORD
    NumLods:  INTEGER;
    Indexes:  ^TIndexes;
  END; // .RECORD TLodIndexes
  
  TLodTypes = PACKED RECORD
    Table:    ARRAY [LOD_SPRITE..LOD_WAV, TGameVersion] OF TLodIndexes;
    Indexes:  ARRAY [LOD_SPRITE..LOD_WAV, TGameVersion] OF TIndexes;
  END; // .RECORD TLodTypes
  
  TObjItem  = CLASS
    Pos:    INTEGER;
    Value:  STRING;
  END; // .CLASS TObjItem
  
  TMAlloc = FUNCTION (Size: INTEGER): POINTER; CDECL;
  TMFree  = PROCEDURE (Addr: POINTER); CDECL;


CONST
  MAlloc: TMAlloc = Ptr($504A8E);
  MFree:  TMFree  = Ptr($504AB7);


VAR
{O} LodList:  Lists.TStringList;
    hMe:      INTEGER;
    LodTable: TLodTable;
    LodTypes: TLodTypes;
    
{O} ZEObjList: Lists.TStringList;


PROCEDURE AsmInit; ASSEMBLER;


(***) IMPLEMENTATION (***)


PROCEDURE LoadPlugins;
VAR
{O} Locator:    Files.TFileLocator;
{O} ItemInfo:   Files.TItemInfo;
    DllName:    STRING;
    DllHandle:  INTEGER;
  
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  NIL;
  // * * * * * //
  Locator.DirPath :=  PLUGINS_PATH;
  Locator.InitSearch('*.dll');
  
  WHILE Locator.NotEnd DO BEGIN
    DllName   :=  Locator.GetNextItem(ItemInfo);
    DllHandle :=  Windows.LoadLibrary(PCHAR(PLUGINS_PATH + '\' + DllName));
    {!} ASSERT(DllHandle <> 0);
    Windows.DisableThreadLibraryCalls(DllHandle);
    
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

PROCEDURE ApplyPatches;
VAR
{O} Locator:  Files.TFileLocator;
{O} ItemInfo: Files.TItemInfo;
  
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  ItemInfo  :=  NIL;
  // * * * * * //
  Locator.DirPath :=  PATCHES_PATH;
  Locator.InitSearch('*.bin');
  
  WHILE Locator.NotEnd DO BEGIN
    ApplyBinPatch(Locator.DirPath + '\' + Locator.GetNextItem(ItemInfo));
    
    SysUtils.FreeAndNil(ItemInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .PROCEDURE ApplyPatches

PROCEDURE WriteInt (Value: INTEGER; Addr: POINTER); INLINE;
BEGIN
  Core.WriteAtCode(SIZEOF(Value), @Value, Addr);
END; // .PROCEDURE WriteInt

PROCEDURE RegisterDefaultLodTypes;
BEGIN
  (* LOD_SPRITE *)
  LodTypes.Table[LOD_SPRITE, 0].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 0].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 0];
  LodTypes.Table[LOD_SPRITE, 1].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 1].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 1];
  LodTypes.Table[LOD_SPRITE, 2].NumLods :=  2;
  LodTypes.Table[LOD_SPRITE, 2].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 2];
  LodTypes.Table[LOD_SPRITE, 3].NumLods :=  3;
  LodTypes.Table[LOD_SPRITE, 3].Indexes :=  @LodTypes.Indexes[LOD_SPRITE, 3];
  
  (* LOD_BITMAP *)
  LodTypes.Table[LOD_BITMAP, 0].NumLods :=  3;
  LodTypes.Table[LOD_BITMAP, 0].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 0];
  LodTypes.Table[LOD_BITMAP, 1].NumLods :=  3;
  LodTypes.Table[LOD_BITMAP, 1].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 1];
  LodTypes.Table[LOD_BITMAP, 2].NumLods :=  1;
  LodTypes.Table[LOD_BITMAP, 2].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 2];
  LodTypes.Table[LOD_BITMAP, 3].NumLods :=  1;
  LodTypes.Table[LOD_BITMAP, 3].Indexes :=  @LodTypes.Indexes[LOD_BITMAP, 3];
  
  (* LOD_WAV *)
  LodTypes.Table[LOD_WAV, 0].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 0].Indexes :=  @LodTypes.Indexes[LOD_WAV, 0];
  LodTypes.Table[LOD_WAV, 1].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 1].Indexes :=  @LodTypes.Indexes[LOD_WAV, 1];
  LodTypes.Table[LOD_WAV, 2].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 2].Indexes :=  @LodTypes.Indexes[LOD_WAV, 2];
  LodTypes.Table[LOD_WAV, 3].NumLods :=  2;
  LodTypes.Table[LOD_WAV, 3].Indexes :=  @LodTypes.Indexes[LOD_WAV, 3];
  
  (* LOD_SPRITE *)
  LodTypes.Indexes[LOD_SPRITE, 0][0]  :=  5;
  LodTypes.Indexes[LOD_SPRITE, 0][1]  :=  1;
  
  LodTypes.Indexes[LOD_SPRITE, 1][0]  :=  4;
  LodTypes.Indexes[LOD_SPRITE, 1][1]  :=  0;
  
  LodTypes.Indexes[LOD_SPRITE, 2][0]  :=  1;
  LodTypes.Indexes[LOD_SPRITE, 2][1]  :=  0;
  
  LodTypes.Indexes[LOD_SPRITE, 3][0]  :=  7;
  LodTypes.Indexes[LOD_SPRITE, 3][1]  :=  3;
  LodTypes.Indexes[LOD_SPRITE, 3][2]  :=  1;
  
  (* LOD_BITMAP *)
  LodTypes.Indexes[LOD_BITMAP, 0][0]  :=  6;
  LodTypes.Indexes[LOD_BITMAP, 0][1]  :=  2;
  LodTypes.Indexes[LOD_BITMAP, 0][2]  :=  0;
  
  LodTypes.Indexes[LOD_BITMAP, 1][0]  :=  2;
  LodTypes.Indexes[LOD_BITMAP, 1][1]  :=  1;
  LodTypes.Indexes[LOD_BITMAP, 1][2]  :=  0;
  
  LodTypes.Indexes[LOD_BITMAP, 2][0]  :=  1;
  
  LodTypes.Indexes[LOD_BITMAP, 3][0]  :=  0;
  
  (* LOD_WAV *)
  LodTypes.Indexes[LOD_WAV, 0][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 0][1]  :=  0;
  
  LodTypes.Indexes[LOD_WAV, 1][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 1][1]  :=  3;
  
  LodTypes.Indexes[LOD_WAV, 2][0]  :=  0;
  LodTypes.Indexes[LOD_WAV, 2][1]  :=  2;
  
  LodTypes.Indexes[LOD_WAV, 3][0]  :=  1;
  LodTypes.Indexes[LOD_WAV, 3][1]  :=  0;
END; // .PROCEDURE RegisterDefaultLodTypes

PROCEDURE LoadLod (CONST LodName: STRING; Res: PLod);
BEGIN
  {!} ASSERT(Res <> NIL);
  ASM
    MOV ECX, Res
    PUSH LodName
    MOV EAX, $4DAD60
    CALL EAX
  END; // .ASM
END; // .PROCEDURE LoadLod

PROCEDURE AddLodToList (LodInd: INTEGER);
VAR
{U} Indexes:      PIndexes;
    LodType:      TLodType;
    GameVersion:  TGameVersion;
    i:            INTEGER;
   
BEGIN
  FOR LodType := LOD_SPRITE TO LOD_WAV DO BEGIN
    FOR GameVersion := LOW(TGameVersion) TO HIGH(TGameVersion) DO BEGIN
      Indexes :=  @LodTypes.Indexes[LodType, GameVersion];
      
      FOR i := LodTypes.Table[LodType, GameVersion].NumLods - 1 DOWNTO 0 DO BEGIN
        Indexes[i + 1] :=  Indexes[i];
      END; // .FOR
      
      Indexes[0]  :=  LodInd;
      
      INC(LodTypes.Table[LodType, GameVersion].NumLods);
    END; // .FOR
  END; // .FOR
END; // .PROCEDURE AddLodToList

PROCEDURE LoadLods;
CONST
  NUM_OBLIG_LODS  = 8;
  MIN_LOD_SIZE    = 12;

VAR
{O} Locator:  Files.TFileLocator;
{O} FileInfo: Files.TFileItemInfo;
    FileName: STRING;
    NumLods:  INTEGER;
    i:        INTEGER;

BEGIN
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  NIL;
  // * * * * * //
  RegisterDefaultLodTypes;
  
  Locator.DirPath :=  'Data';
  Locator.InitSearch('*.pac');
  
  NumLods :=  NUM_OBLIG_LODS;
  
  WHILE Locator.NotEnd AND (LodList.Count < (LENGTH(LodTable) - NUM_OBLIG_LODS)) DO BEGIN
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(FileInfo)));
    
    IF
      (SysUtils.ExtractFileExt(FileName) = '.pac')  AND
      NOT FileInfo.IsDir                            AND
      FileInfo.HasKnownSize                         AND
      (FileInfo.FileSize > MIN_LOD_SIZE)
    THEN BEGIN
      LodList.Add(FileName);
    END; // .IF
    
    SysUtils.FreeAndNil(FileInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  
  FOR i := LodList.Count - 1 DOWNTO 0 DO BEGIN
    LoadLod(LodList[i], @LodTable[NumLods]);
    AddLodToList(NumLods);
    INC(NumLods);
  END; // .FOR

  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .PROCEDURE LoadLods

{$W-}
PROCEDURE Hook_SetLodTypes; ASSEMBLER;
ASM
  CALL LoadLods
  // RET
END; // .PROCEDURE Hook_SetLodTypes
{$W+}

PROCEDURE ExtendLods;
BEGIN
  (* Fix lod constructors args *)
  WriteInt(INTEGER(@LodTable[0]), Ptr($4DACE6 + 15 * 0));
  WriteInt(INTEGER(@LodTable[1]), Ptr($4DACE6 + 15 * 1));
  WriteInt(INTEGER(@LodTable[2]), Ptr($4DACE6 + 15 * 2));
  WriteInt(INTEGER(@LodTable[3]), Ptr($4DACE6 + 15 * 3));
  WriteInt(INTEGER(@LodTable[4]), Ptr($4DACE6 + 15 * 4));
  WriteInt(INTEGER(@LodTable[5]), Ptr($4DACE6 + 15 * 5));
  WriteInt(INTEGER(@LodTable[6]), Ptr($4DACE6 + 15 * 6));
  WriteInt(INTEGER(@LodTable[7]), Ptr($4DACE6 + 15 * 7));
  
  (* Fix refs to LodTable[0] *)
  WriteInt(INTEGER(@LodTable[0]), Ptr($4DAD9D));
  WriteInt(INTEGER(@LodTable[0]), Ptr($4DB1A9));
  
  (* Fix refs to LodTable[0].F4 *)
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DB1AF));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DB275));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DB298));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DB2F5));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DB318));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DC029));
  WriteInt(INTEGER(@LodTable[0]) + 4, Ptr($4DC087));
  
  (* Fix refs to LodTypes.Table *)
  WriteInt(INTEGER(@LodTypes.Table), Ptr($4DB25D));
  WriteInt(INTEGER(@LodTypes.Table), Ptr($4DB264));
  WriteInt(INTEGER(@LodTypes.Table), Ptr($4DB2E4));
  WriteInt(INTEGER(@LodTypes.Table), Ptr($4DBF0F));
  
  (* Fix refs to LodTypes.Table.f4 *)
  WriteInt(INTEGER(@LodTypes.Table) + 4, Ptr($4DB256));
  
  (* Fix refs to LodTypes.Table.f8 *)
  WriteInt(INTEGER(@LodTypes.Table) + 8, Ptr($4DB2DD));
  
  (* Fix refs to LodTypes.Table.f12 *)
  WriteInt(INTEGER(@LodTypes.Table) + 12, Ptr($4DB2D6));
  
  Core.Hook(@Hook_SetLodTypes, Core.HOOKTYPE_JUMP, 5, Ptr($4DAED0));
END; // .PROCEDURE ExtendLods

FUNCTION Hook_FixGameVersion (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
BEGIN
  GameVersion^  :=  AB_AND_SOD;
  RESULT        :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_FixGameVersion

FUNCTION LoadObjList (RawFileData: STRING; OUT ObjList: Lists.TStringList): BOOLEAN;
VAR
{U} ObjItem:      TObjItem;
    StrItems:     StrLib.TArrayOfString;
    StrItem:      StrLib.TArrayOfString;
    NumStrItems:  INTEGER;
    i:            INTEGER;

BEGIN
  {!} ASSERT(ObjList = NIL);
  ObjItem :=  NIL;
  // * * * * * //
  StrItems    :=  StrLib.Explode(RawFileData, LINE_END);
  NumStrItems :=  LENGTH(StrItems) - 2;
  RESULT      :=  (NumStrItems > 0) AND (StrItems[LENGTH(StrItems) - 1] = '');
  
  IF RESULT THEN BEGIN
    ObjList :=  Lists.NewStrictStrList(TObjItem);
    i       :=  1;
    
    WHILE RESULT AND (i <= NumStrItems) DO BEGIN
      StrItem :=  StrLib.ExplodeEx
      (
        StrItems[i],
        ' ',
        NOT StrLib.INCLUDE_DELIM,
        StrLib.LIMIT_TOKENS,
        2
      );
      
      RESULT  :=  (LENGTH(StrItem) = 2) AND (LENGTH(StrLib.Explode(StrItems[i], ' ')) >= 9);
      
      IF RESULT THEN BEGIN
        ObjItem       :=  TObjItem.Create;
        ObjItem.Pos   :=  i - 1;
        ObjItem.Value :=  StrItem[1];
        ObjList.AddObj(SysUtils.AnsiLowerCase(StrItem[0]), ObjItem);
      END // .IF
      ELSE BEGIN
        Log.Write
        (
          'zeobjt.txt',
          'LoadObjList',
          'Line should have at least 9 elements: "' + StrItems[i] + '"'
        );
      END; // .ELSE

      INC(i);
    END; // .WHILE
    
    ObjList.Sorted  :=  TRUE;
  END // .IF
  ELSE BEGIN
    Log.Write
    (
      'zeobjt.txt',
      'LoadObjList',
      'File has zero items or does not have terminating end of line'
    );
  END; // .ELSE
  
  IF NOT RESULT THEN BEGIN
    SysUtils.FreeAndNil(ObjList);
  END; // .IF
END; // .FUNCTION LoadObjList

FUNCTION ObjListToStr ({IN} VAR ObjList: Lists.TStringList): STRING;
VAR
{O} Res:      StrLib.TStrBuilder;
{U} ObjItem:  TObjItem;
    NumItems: INTEGER;
    i:        INTEGER;

BEGIN
  {!} ASSERT(ObjList <> NIL);
  Res     :=  StrLib.TStrBuilder.Create;
  ObjItem :=  NIL;
  // * * * * * //
  NumItems        :=  ObjList.Count;
  ObjList.Sorted  :=  FALSE;
  Res.Append(SysUtils.IntToStr(NumItems));
  Res.Append(LINE_END);
  i :=  0;
  
  WHILE i < NumItems DO BEGIN
    ObjItem :=  ObjList.Values[i];
    
    IF ObjItem.Pos <> i THEN BEGIN
      ObjList.Exchange(i, ObjItem.Pos);
    END // .IF
    ELSE BEGIN
      INC(i);
    END; // .ELSE
  END; // .WHILE

  FOR i := 0 TO NumItems - 1 DO BEGIN
    ObjItem :=  ObjList.Values[i];
    Res.Append(ObjList.Keys[i]);
    Res.Append(' ');
    Res.Append(ObjItem.Value);
    Res.Append(LINE_END);
  END; // .FOR

  RESULT  :=  Res.BuildStr();
  // * * * * * //
  SysUtils.FreeAndNil(Res);
  SysUtils.FreeAndNil(ObjList);
END; // .FUNCTION ObjListToStr

FUNCTION MergeObjLists
(
  ParentObjList:  Lists.TStringList;
  ChildObjList:   Lists.TStringList;
  SafeMode:       BOOLEAN
): BOOLEAN;

CONST
  CATEGORY_ID = 6;

VAR
{U} ObjItem:          TObjItem;
    OldAssertHandler: TAssertErrorProc;
    ExplodedSrc:      StrLib.TArrayOfString;
    ExplodedDst:      StrLib.TArrayOfString;
    ItemInd:          INTEGER;
    ContinueLoop:     BOOLEAN;
    i:                INTEGER;
  
BEGIN
  {!} ASSERT(ParentObjList <> NIL);
  {!} ASSERT(ChildObjList <> NIL);
  ParentObjList.Sorted    :=  TRUE;
  ChildObjList.Sorted     :=  TRUE;
  OldAssertHandler        :=  System.AssertErrorProc;
  System.AssertErrorProc  :=  NIL;
  
  TRY
    ChildObjList.ForbidDuplicates :=  TRUE;
    RESULT                        :=  TRUE;
  EXCEPT
    RESULT  :=  FALSE;
  END; // .TRY
  
  System.AssertErrorProc  :=  OldAssertHandler;
  
  IF RESULT THEN BEGIN
    i :=  0;
    
    WHILE RESULT AND (i < ChildObjList.Count) DO BEGIN
      ObjItem :=  ChildObjList.Values[i];
      
      IF ParentObjList.Find(ChildObjList.Keys[i], ItemInd) THEN BEGIN
        IF NOT SafeMode THEN BEGIN
          ContinueLoop  :=  TRUE;
          
          WHILE RESULT AND ContinueLoop DO BEGIN
            ExplodedDst :=  StrLib.Explode(TObjItem(ParentObjList.Values[ItemInd]).Value, ' ');
            ExplodedSrc :=  StrLib.Explode(ObjItem.Value, ' ');
            ExplodedSrc[CATEGORY_ID]  :=  ExplodedDst[CATEGORY_ID];
            TObjItem(ParentObjList.Values[ItemInd]).Value :=  StrLib.Join(ExplodedSrc, ' ');
            DEC(ItemInd);
            ContinueLoop  :=
              (ItemInd >= 0)  AND
              (ParentObjList.Keys[ItemInd] = ChildObjList.Keys[i]);
          END; // .WHILE
        END; // .IF
      END // .IF
      ELSE BEGIN
        ObjItem.Pos :=  ParentObjList.Count;
        ParentObjList.AddObj(ChildObjList.Keys[i], ObjItem); ChildObjList.TakeValue(i);
      END; // .ELSE
      
      INC(i);
    END; // .WHILE
  END; // .IF
END; // .FUNCTION MergeObjLists

FUNCTION LoadZeobjt (VAR FileInfo: SysUtils.TSearchRec): BOOLEAN;
VAR
{O} ChildObjList: Lists.TStringList;
    FileName:     STRING;
    FileContents: STRING;
   
BEGIN
  ChildObjList  :=  NIL;
  // * * * * * //
  FileName  :=  FileInfo.Name;
  
  IF
    (FileInfo.Size > 0) AND
    Files.ReadFileContents(ZEOBJTS_DIR + '\' + FileName, FileContents)
  THEN BEGIN
    IF
      NOT LoadObjList(FileContents, ChildObjList) OR
      NOT MergeObjLists(ZEObjList, ChildObjList, FALSE)
    THEN BEGIN     
      DlgMes.MsgError
      (
        'Editor objects file contains duplicates or has invalid format: "'
        + ZEOBJTS_DIR + '\' + FileName + '"'
      );
    END; // .IF
    
    SysUtils.FreeAndNil(ChildObjList);
  END; // .IF
  
  RESULT  :=  TRUE;
END; // .FUNCTION LoadZeobjt

PROCEDURE LoadZeobjts;
BEGIN
  {!} ASSERT(ZEObjList <> NIL);
  Files.Scan(ZEOBJTS_DIR + '\*.txt', Files.faNotDirectory, '.txt', LoadZeobjt);
END; // .PROCEDURE LoadZeobjts

FUNCTION Hook_ReadTxt (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  ZEOBJTS_NAME  = 'zeobjts.txt';

VAR
  TextName:     STRING;
  TextContents: STRING;
  TextBuffer:   POINTER;

BEGIN
  (*
  All ESP offsets were increased by 4 to compensate call to bridge 
  *)
  TextName  :=  SysUtils.AnsiLowerCase(PPCHAR(Context.ESP + $28)^);
  
  IF TextName = ZEOBJTS_NAME THEN BEGIN
    IF ZEObjList <> NIL THEN BEGIN
      SysUtils.FreeAndNil(ZEObjList);
    END; // .IF
    
    TextContents  :=  PPCHAR(Context.ESP + $14)^;
    
    IF LoadObjList(TextContents, ZEObjList) THEN BEGIN
      LoadZeobjts;
      TextContents                :=  ObjListToStr(ZEObjList);
      MFree(PPCHAR(Context.ESP + $14)^);
      TextBuffer                  :=  MAlloc(LENGTH(TextContents));
      PPCHAR(Context.ESP + $14)^  :=  TextBuffer;
      Context.EDI                 :=  LENGTH(TextContents);
      Context.ESI                 :=  INTEGER(TextBuffer);
      Utils.CopyMem(LENGTH(TextContents), POINTER(TextContents), TextBuffer);
    END // .IF
    ELSE BEGIN
      DlgMes.MsgError('Invalid editor objects file: "' + ZEOBJTS_NAME + '"');
    END; // .ELSE
  END; // .IF
  
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_ReadTxt

PROCEDURE AssertHandler (CONST Mes, FileName: STRING; LineNumber: INTEGER; Address: POINTER);
BEGIN
  Core.FatalError(StrLib.BuildStr(
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.',
    [
      'FileName', FileName,
      'Line',     SysUtils.IntToStr(LineNumber),
      'Address',  SysUtils.Format('%x', [INTEGER(Address)])
    ],
    '~'
  ));
END; // .PROCEDURE AssertHandler

PROCEDURE Init (hDll: INTEGER);
CONST
  RDATA_SECTION_ADDR  = Ptr($530000);
  RDATA_SECTION_SIZE  = $4B000;

VAR
  Buffer:         STRING;
  OldProtection:  INTEGER;

BEGIN
  hMe :=  hDll;
  Windows.DisableThreadLibraryCalls(hMe);
  System.AssertErrorProc :=  AssertHandler;
  
  (* Restore default editor constant overwritten by "eramap.dll" *)
  Buffer  :=  'GetSpreadsheet';
  Core.WriteAtCode(LENGTH(Buffer) + 1, POINTER(Buffer), Ptr($596ED4));
  
  (* GrayFace mapedpatch requires .rdata section to have WRITE flag *)
  Windows.VirtualProtect
  (
    RDATA_SECTION_ADDR,
    RDATA_SECTION_SIZE,
    Windows.PAGE_EXECUTE_READWRITE,
    @OldProtection
  );
  
  ExtendLods;
  
  LoadPlugins;
  ApplyPatches;

  (* Fix game version to allow generating random maps *)
  Core.Hook(@Hook_FixGameVersion, Core.HOOKTYPE_BRIDGE, 5, Ptr($45C5FD));
  
  (* Add support for extended zeobjts.txt *)
  Core.ApiHook(@Hook_ReadTxt, Core.HOOKTYPE_BRIDGE, Ptr($4DC8D4));
END; // .PROCEDURE Init

PROCEDURE AsmInit; ASSEMBLER;
ASM
  (* Remove ret addr *)
  POP ECX
  
  CALL Init
  
  (* Default code *)
  PUSH EBP
  MOV EBP, ESP
  PUSH -1
  PUSH $54CA58
  PUSH $4EA77C
  PUSH [FS:0]
  
  (* Place new ret addr *)
  PUSH $4E84EA
  // RET
END; // .PROCEDURE AsmInit

BEGIN
  LodList :=  Lists.NewSimpleStrList;
END.
