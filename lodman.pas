UNIT Lodman;
{
DESCRIPTION:  LOD archives manager
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
BASED ON:     "Lods" plugin by Sav, WoG Sources by ZVS
}

(***)  INTERFACE  (***)
USES
  SysUtils, Math, Utils, Files, Core, Lists, AssocArrays, TypeWrappers,
  GameExt, Heroes, Stores;

CONST
  MAX_NUM_LODS  = 100;
  DEF_NUM_LODS  = 8;
  
  LODREDIR_SAVE_SECTION = 'EraRedirs';


TYPE
  (* IMPORT *)
  TString = TypeWrappers.TString;

  TGameVersion  = Heroes.ROE..Heroes.SOD_AND_AB;
  TLodType      = (LOD_SPRITE = 1, LOD_BITMAP = 2, LOD_WAV = 3);
  
  PLodTable = ^TLodTable;
  TLodTable = ARRAY [0..MAX_NUM_LODS - 1] OF Heroes.TLod;

  TZvsAddLodToList  = FUNCTION (LodInd: INTEGER): INTEGER; CDECL;
  
  PIndexes  = ^TIndexes;
  TIndexes  = ARRAY [0..MAX_NUM_LODS - 1] OF INTEGER;
  
  PLodIndexes = ^TLodIndexes;
  TLodIndexes = PACKED RECORD
    NumLods:  INTEGER;
    Indexes:  PIndexes;
  END; // .RECORD TLodIndexes
  
  PLodTypes = ^TLodTypes;
  TLodTypes = PACKED RECORD
    Table:    ARRAY [TLodType, TGameVersion] OF TLodIndexes;
    Indexes:  ARRAY [TLodType, TGameVersion] OF TIndexes;
  END; // .RECORD TLodTypes


CONST
  ZvsAddLodToList:  TZvsAddLodToList  = Ptr($75605B);
  ZvsLodTable:      PLodTable         = Ptr($28077D0);
  ZvsLodTypes:      PLodTypes         = Ptr($79EFE0);


PROCEDURE RedirectFile (CONST OldFileName, NewFileName: STRING);
PROCEDURE GlobalRedirectFile (CONST OldFileName, NewFileName: STRING);
FUNCTION  FindFileLod (CONST FileName: STRING; OUT LodPath: STRING): BOOLEAN;
FUNCTION  FileIsInLod (CONST FileName: STRING; Lod: Heroes.PLod): BOOLEAN; 
  

(***) IMPLEMENTATION (***)


VAR
{O} GlobalLodRedirs:  {O} AssocArrays.TAssocArray {OF TString};
{O} LodRedirs:        {O} AssocArrays.TAssocArray {OF TString};
{O} LodList:          Lists.TStringList;
    NumLods:          INTEGER = DEF_NUM_LODS;


PROCEDURE UnregisterLod (LodInd: INTEGER);
VAR
{U} Table:        PLodIndexes;
{U} Indexes:      PIndexes;
    LodType:      TLodType;
    GameVersion:  TGameVersion;
    LocalNumLods: INTEGER;
    
    LeftInd:      INTEGER;
    i:            INTEGER;
   
BEGIN
  {!} ASSERT(Math.InRange(LodInd, 0, NumLods - 1));
  Table   :=  NIL;
  Indexes :=  NIL;
  // * * * * * //
  FOR LodType := LOW(TLodType) TO HIGH(TLodType) DO BEGIN
    FOR GameVersion := LOW(TGameVersion) TO HIGH(TGameVersion) DO BEGIN
      Table         :=  @ZvsLodTypes.Table[LodType, GameVersion];
      Indexes       :=  Table.Indexes;
      LocalNumLods  :=  Table.NumLods;
      
      LeftInd :=  0;
      i       :=  0;
      
      WHILE i < LocalNumLods DO BEGIN
        IF Indexes[i] <> LodInd THEN BEGIN
          Indexes[LeftInd]  :=  Indexes[i];
          INC(LeftInd);
        END; // .IF
        
        INC(i);
      END; // .WHILE
      
      Table.NumLods :=  LeftInd;
    END; // .FOR
  END; // .FOR
  
  DEC(NumLods);
END; // .PROCEDURE UnregisterLod

PROCEDURE UnregisterDeadLods;
BEGIN
  IF NOT SysUtils.FileExists('Data\h3abp_sp.lod') THEN BEGIN
    UnregisterLod(7);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3abp_bm.lod') THEN BEGIN
    UnregisterLod(6);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3psprit.lod') THEN BEGIN
    UnregisterLod(5);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3pbitma.lod') THEN BEGIN
    UnregisterLod(4);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3ab_spr.lod') THEN BEGIN
    UnregisterLod(3);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3ab_bmp.lod') THEN BEGIN
    UnregisterLod(2);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3sprite.lod') THEN BEGIN
    UnregisterLod(1);
  END; // .IF
  
  IF NOT SysUtils.FileExists('Data\h3bitmap.lod') THEN BEGIN
    UnregisterLod(0);
  END; // .IF
END; // .PROCEDURE UnregisterDeadLods

FUNCTION FileIsInLod (CONST FileName: STRING; Lod: Heroes.PLod): BOOLEAN; 
BEGIN
  {!} ASSERT(Lod <> NIL);
  RESULT  :=  FALSE;
  
  IF FileName <> '' THEN BEGIN
    ASM
      MOV ECX, Lod
      ADD ECX, 4
      PUSH FileName
      MOV EAX, $4FB100
      CALL EAX
      MOV RESULT, AL
    END; // .ASM
  END; // .IF
END; // .FUNCTION FileIsInLod 

FUNCTION FindFileLod (CONST FileName: STRING; OUT LodPath: STRING): BOOLEAN;
VAR
  Lod:  Heroes.PLod;
  i:    INTEGER;
  
BEGIN
  Lod :=  Utils.PtrOfs(ZvsLodTable, SIZEOF(Heroes.TLod) * (NumLods - 1));
  // * * * * * //
  RESULT  :=  FALSE;
  i       :=  NumLods - 1;
   
  WHILE NOT RESULT AND (i >= 0) DO BEGIN
    RESULT  :=  FileIsInLod(FileName, Lod);
    
    IF NOT RESULT THEN BEGIN
      Lod :=  Utils.PtrOfs(Lod, -SIZEOF(Heroes.TLod));
      DEC(i);
    END; // .IF
  END; // .WHILE

  IF RESULT THEN BEGIN
    LodPath :=  PCHAR(INTEGER(Lod) + 8);
  END; // .IF
END; // .FUNCTION FindFileLod

FUNCTION Hook_LoadLods (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
{O} Locator:  Files.TFileLocator;
{O} FileInfo: Files.TFileItemInfo;
    FileName: STRING;
    i:        INTEGER;
  
BEGIN
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  NIL;
  // * * * * * //
  UnregisterDeadLods;
  
  Locator.DirPath :=  'Data';
  Locator.InitSearch('*.pac');
  
  WHILE Locator.NotEnd AND (LodList.Count <= (HIGH(TLodTable) - NumLods)) DO BEGIN
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(FileInfo)));
    
    IF (SysUtils.ExtractFileExt(FileName) = '.pac') AND NOT FileInfo.IsDir THEN BEGIN
      LodList.Add(FileName);
    END; // .IF
    
    SysUtils.FreeAndNil(FileInfo);
  END; // .WHILE
  
  Locator.FinitSearch;
  
  FOR i := LodList.Count - 1 DOWNTO 0 DO BEGIN
    Heroes.LoadLod(LodList[i], @ZvsLodTable[NumLods]);
    ZvsAddLodToList(NumLods);
    INC(NumLods);
  END; // .FOR
  
  RESULT  :=  Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .FUNCTION Hook_LoadLods

FUNCTION Hook_FindFileInLod (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
  FileName:     STRING;
  Redirection:  TString;

BEGIN
  FileName    :=  PPCHAR(Context.EBP + $8)^;
  Redirection :=  LodRedirs[FileName];
  
  IF Redirection = NIL THEN BEGIN
    Redirection :=  GlobalLodRedirs[FileName];
  END; // .IF
  
  IF Redirection <> NIL THEN BEGIN
    PPCHAR(Context.EBP + $8)^ :=  POINTER(Redirection.Value);
  END; // .IF
  
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_FindFileInLod

PROCEDURE RedirectFile (CONST OldFileName, NewFileName: STRING);
VAR
  Redirection:  TString;
   
BEGIN
  IF NewFileName = '' THEN BEGIN
    IF OldFileName = '' THEN BEGIN
      LodRedirs.Clear;
    END // .IF
    ELSE BEGIN
      LodRedirs.DeleteItem(OldFileName);
    END; // .ELSE
  END // .IF
  ELSE BEGIN
    Redirection :=  LodRedirs[OldFileName];
  
    IF Redirection = NIL THEN BEGIN
      LodRedirs[OldFileName] :=  TString.Create(NewFileName);
    END // .IF
    ELSE BEGIN
      Redirection.Value :=  NewFileName;
    END; // .ELSE
  END; // .ELSE
END; // .PROCEDURE RedirectFile

PROCEDURE GlobalRedirectFile (CONST OldFileName, NewFileName: STRING);
VAR
  Redirection:  TString;
   
BEGIN
  IF NewFileName = '' THEN BEGIN
    IF OldFileName = '' THEN BEGIN
      GlobalLodRedirs.Clear;
    END // .IF
    ELSE BEGIN
      GlobalLodRedirs.DeleteItem(OldFileName);
    END; // .ELSE
  END // .IF
  ELSE BEGIN
    Redirection :=  GlobalLodRedirs[OldFileName];
  
    IF Redirection = NIL THEN BEGIN
      GlobalLodRedirs[OldFileName]  :=  TString.Create(NewFileName);
    END // .IF
    ELSE BEGIN
      Redirection.Value :=  NewFileName;
    END; // .ELSE
  END; // .ELSE
END; // .PROCEDURE GlobalRedirectFile

PROCEDURE OnBeforeErmInstructions (Event: PEvent); STDCALL;
BEGIN
  LodRedirs.Clear;
END; // .PROCEDURE OnBeforeErmInstructions

PROCEDURE OnSavegameWrite (Event: PEvent); STDCALL;
VAR
{U} Redirection:  TString;
    OldFileName:  STRING;
    NumRedirs:    INTEGER;
    
  PROCEDURE WriteStr (CONST Str: STRING);
  VAR
    StrLen: INTEGER;
     
  BEGIN
    StrLen  :=  LENGTH(Str);
    Stores.WriteSavegameSection(SIZEOF(StrLen), @StrLen, LODREDIR_SAVE_SECTION);
    
    IF StrLen > 0 THEN BEGIN
      Stores.WriteSavegameSection(StrLen, POINTER(Str), LODREDIR_SAVE_SECTION);
    END; // .IF
  END; // .PROCEDURE WriteStr

BEGIN
  Redirection :=  NIL;
  // * * * * * //
  NumRedirs :=  LodRedirs.ItemCount;
  Stores.WriteSavegameSection(SIZEOF(NumRedirs), @NumRedirs, LODREDIR_SAVE_SECTION);
  
  LodRedirs.BeginIterate;
  
  WHILE LodRedirs.IterateNext(OldFileName, POINTER(Redirection)) DO BEGIN
    WriteStr(OldFileName);
    WriteStr(Redirection.Value);
    Redirection :=  NIL;
  END; // .WHILE
  
  LodRedirs.EndIterate;
END; // .PROCEDURE OnSavegameWrite

PROCEDURE OnSavegameRead (Event: PEvent); STDCALL;
VAR
  NumRedirs:    INTEGER;
  OldFileName:  STRING;
  NewFileName:  STRING;
  i:            INTEGER;
    
  FUNCTION ReadStr: STRING;
  VAR
    StrLen: INTEGER;
     
  BEGIN
    Stores.ReadSavegameSection(SIZEOF(StrLen), @StrLen, LODREDIR_SAVE_SECTION);
    SetLength(RESULT, StrLen);
    
    IF StrLen > 0 THEN BEGIN
      Stores.ReadSavegameSection(StrLen, POINTER(RESULT), LODREDIR_SAVE_SECTION);
    END; // .IF
  END; // .FUNCTION ReadStr

BEGIN
  LodRedirs.Clear;
  Stores.ReadSavegameSection(SIZEOF(NumRedirs), @NumRedirs, LODREDIR_SAVE_SECTION);
  
  FOR i := 0 TO NumRedirs - 1 DO BEGIN
    OldFileName             :=  ReadStr;
    NewFileName             :=  ReadStr;
    LodRedirs[OldFileName]  :=  TString.Create(NewFileName);
  END; // .FOR
END; // .PROCEDURE OnSavegameRead

PROCEDURE OnBeforeWoG (Event: PEvent); STDCALL;
BEGIN
  // Remove WoG h3custom and h3wog lods registration
  PWORD($7015E5)^ :=  $38EB;
  Core.Hook(@Hook_LoadLods, Core.HOOKTYPE_BRIDGE, 5, Ptr($559408));
  
  // Lods files redirection mechanism
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FB106));
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FACA6));
END; // .PROCEDURE OnBeforeWoG

BEGIN
  GlobalLodRedirs :=  AssocArrays.NewStrictAssocArr(TString);
  LodRedirs       :=  AssocArrays.NewStrictAssocArr(TString);
  LodList         :=  Lists.NewSimpleStrList;

  GameExt.RegisterHandler(OnBeforeWoG,              'OnBeforeWoG');
  GameExt.RegisterHandler(OnBeforeErmInstructions,  'OnBeforeErmInstructions');
  GameExt.RegisterHandler(OnSavegameWrite,          'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead,           'OnSavegameRead');
END.
