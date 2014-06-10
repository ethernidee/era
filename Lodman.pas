UNIT Lodman;
{
DESCRIPTION:  LOD archives manager. Includes resource redirection support
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
BASED ON:     "Lods" plugin by Sav, WoG Sources by ZVS
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Math, Utils, Files, Core, Lists, AssocArrays, TypeWrappers, DataLib,
  GameExt, Heroes, Stores;

CONST
  MAX_NUM_LODS  = 100;
  DEF_NUM_LODS  = 8;
  
  LODREDIR_SAVE_SECTION = 'Era.ResourceRedirections';


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
    RedirCritSection: Windows.TRTLCriticalSection;


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
  
  with Files.Locate('Data\*.pac', Files.ONLY_FILES) do begin
    while FindNext do begin
      LodList.Add(FoundName);
    end; // .while
  end; // .with
  
  FOR i := LodList.Count - 1 DOWNTO 0 DO BEGIN
    Heroes.LoadLod(LodList[i], @ZvsLodTable[NumLods]);
    ZvsAddLodToList(NumLods);
    INC(NumLods);
  END; // .FOR
  
  RESULT  :=  Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .FUNCTION Hook_LoadLods

FUNCTION FindRedirection (CONST FileName: STRING; OUT Redirected: STRING): BOOLEAN;
VAR
{U} Redirection: TString;

BEGIN
  Redirection := LodRedirs[FileName];
  // * * * * * //
  RESULT := FALSE;

  IF Redirection = NIL THEN BEGIN
    Redirection :=  GlobalLodRedirs[FileName];
  END; // .IF

  IF Redirection <> NIL THEN BEGIN
    Redirected := Redirection.Value;
    RESULT     := TRUE;
  END; // .IF
END; // .FUNCTION FindRedirection

FUNCTION Hook_FindFileInLod (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
VAR
  Redirected: STRING;

BEGIN 
  IF FindRedirection(PPCHAR(Context.EBP + $8)^, Redirected) THEN BEGIN
    PPCHAR(Context.EBP + $8)^ :=  PCHAR(Redirected);
  END; // .IF
  
  RESULT  :=  Core.EXEC_DEF_CODE;
END; // .FUNCTION Hook_FindFileInLod

FUNCTION Hook_OnMp3Start (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;
CONST
  DEFAULT_BUFFER_SIZE = 128;

VAR
  FileName:   STRING;
  Redirected: STRING;

BEGIN
  (* Carefully copy redirected value to persistent storage and don't change anything in LodRedirs *)
  {!} Windows.EnterCriticalSection(RedirCritSection);
  FileName := Heroes.Mp3Name + '.mp3';
  
  IF FindRedirection('*.mp3', Redirected) OR FindRedirection(FileName, Redirected) THEN BEGIN
    Utils.SetPcharValue(Heroes.Mp3Name, SysUtils.ChangeFileExt(Redirected, ''),
                        DEFAULT_BUFFER_SIZE);
  END; // .IF

  RESULT := Core.EXEC_DEF_CODE;
  {!} Windows.LeaveCriticalSection(RedirCritSection);
END; // .FUNCTION Hook_OnMp3Start

PROCEDURE RedirectFile (CONST OldFileName, NewFileName: STRING);
VAR
  Redirection:  TString;
   
BEGIN
  {!} Windows.EnterCriticalSection(RedirCritSection);

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
  
  {!} Windows.LeaveCriticalSection(RedirCritSection);
END; // .PROCEDURE RedirectFile

PROCEDURE GlobalRedirectFile (CONST OldFileName, NewFileName: STRING);
VAR
  Redirection:  TString;
   
BEGIN
  {!} Windows.EnterCriticalSection(RedirCritSection);

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
  
  {!} Windows.LeaveCriticalSection(RedirCritSection);
END; // .PROCEDURE GlobalRedirectFile

PROCEDURE OnBeforeErmInstructions (Event: PEvent); STDCALL;
BEGIN
  LodRedirs.Clear;
END; // .PROCEDURE OnBeforeErmInstructions

PROCEDURE OnSavegameWrite (Event: PEvent); STDCALL;
BEGIN
  with Stores.NewRider(LODREDIR_SAVE_SECTION) do begin
    WriteInt(LodRedirs.ItemCount);

    with DataLib.IterateDict(LodRedirs) do begin
      while IterNext do begin
        WriteStr(IterKey);
        WriteStr(TString(IterValue).Value);
      end; // .while
    end; // .with
  end; // .with
END; // .PROCEDURE OnSavegameWrite

PROCEDURE OnSavegameRead (Event: PEvent); STDCALL;
VAR
  NumRedirs:    INTEGER;
  OldFileName:  STRING;
  NewFileName:  STRING;
  i:            INTEGER;

BEGIN
  {!} Windows.EnterCriticalSection(RedirCritSection);
  LodRedirs.Clear;

  with Stores.NewRider(LODREDIR_SAVE_SECTION) do begin
    NumRedirs := ReadInt;

    for i := 0 to NumRedirs - 1 do begin
      OldFileName            := ReadStr;
      NewFileName            := ReadStr;
      LodRedirs[OldFileName] := TString.Create(NewFileName);
    end; // .for
  end; // .with 

  {!} Windows.LeaveCriticalSection(RedirCritSection);
END; // .PROCEDURE OnSavegameRead

PROCEDURE OnBeforeWoG (Event: PEvent); STDCALL;
BEGIN
  (* Remove WoG h3custom and h3wog lods registration *)
  PWORD($7015E5)^ :=  $38EB;
  Core.Hook(@Hook_LoadLods, Core.HOOKTYPE_BRIDGE, 5, Ptr($559408));
  
  (* Lods files redirection mechanism *)
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FB106));
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FACA6));
END; // .PROCEDURE OnBeforeWoG

PROCEDURE OnAfterWoG (Event: PEvent); STDCALL;
BEGIN
  (* Mp3 redirection mechanism *)
  Core.ApiHook(@Hook_OnMp3Start, Core.HOOKTYPE_BRIDGE, Ptr($59AC51));
END; // .PROCEDURE OnAfterWoG

BEGIN
  Windows.InitializeCriticalSection(RedirCritSection);
  GlobalLodRedirs := AssocArrays.NewStrictAssocArr(TString);
  LodRedirs       := AssocArrays.NewStrictAssocArr(TString);
  LodList         := Lists.NewSimpleStrList;

  GameExt.RegisterHandler(OnBeforeWoG,              'OnBeforeWoG');
  GameExt.RegisterHandler(OnAfterWoG,               'OnAfterWoG');
  GameExt.RegisterHandler(OnBeforeErmInstructions,  'OnBeforeErmInstructions');
  GameExt.RegisterHandler(OnSavegameWrite,          'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead,           'OnSavegameRead');
END.
