unit Lodman;
{
DESCRIPTION:  LOD archives manager
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
BASED ON:     "Lods" plugin by Sav, WoG Sources by ZVS
}

(***)  interface  (***)
uses
  SysUtils, Math, Utils, Files, Core, Lists, AssocArrays, TypeWrappers,
  GameExt, Heroes, Stores;

const
  MAX_NUM_LODS  = 100;
  DEF_NUM_LODS  = 8;
  
  LODREDIR_SAVE_SECTION = 'EraRedirs';


type
  (* IMPORT *)
  TString = TypeWrappers.TString;

  TGameVersion  = Heroes.ROE..Heroes.SOD_AND_AB;
  TLodType      = (LOD_SPRITE = 1, LOD_BITMAP = 2, LOD_WAV = 3);
  
  PLodTable = ^TLodTable;
  TLodTable = array [0..MAX_NUM_LODS - 1] of Heroes.TLod;

  TZvsAddLodToList  = function (LodInd: integer): integer; cdecl;
  
  PIndexes  = ^TIndexes;
  TIndexes  = array [0..MAX_NUM_LODS - 1] of integer;
  
  PLodIndexes = ^TLodIndexes;
  TLodIndexes = packed record
    NumLods:  integer;
    Indexes:  PIndexes;
  end; // .record TLodIndexes
  
  PLodTypes = ^TLodTypes;
  TLodTypes = packed record
    Table:    array [TLodType, TGameVersion] of TLodIndexes;
    Indexes:  array [TLodType, TGameVersion] of TIndexes;
  end; // .record TLodTypes


const
  ZvsAddLodToList:  TZvsAddLodToList  = Ptr($75605B);
  ZvsLodTable:      PLodTable         = Ptr($28077D0);
  ZvsLodTypes:      PLodTypes         = Ptr($79EFE0);


procedure RedirectFile (const OldFileName, NewFileName: string);
procedure GlobalRedirectFile (const OldFileName, NewFileName: string);
function  FindFileLod (const FileName: string; out LodPath: string): boolean;
function  FileIsInLod (const FileName: string; Lod: Heroes.PLod): boolean; 
  

(***) implementation (***)


var
{O} GlobalLodRedirs:  {O} AssocArrays.TAssocArray {OF TString};
{O} LodRedirs:        {O} AssocArrays.TAssocArray {OF TString};
{O} LodList:          Lists.TStringList;
    NumLods:          integer = DEF_NUM_LODS;


procedure UnregisterLod (LodInd: integer);
var
{U} Table:        PLodIndexes;
{U} Indexes:      PIndexes;
    LodType:      TLodType;
    GameVersion:  TGameVersion;
    LocalNumLods: integer;
    
    LeftInd:      integer;
    i:            integer;
   
begin
  {!} Assert(Math.InRange(LodInd, 0, NumLods - 1));
  Table   :=  nil;
  Indexes :=  nil;
  // * * * * * //
  for LodType := Low(TLodType) to High(TLodType) do begin
    for GameVersion := Low(TGameVersion) to High(TGameVersion) do begin
      Table         :=  @ZvsLodTypes.Table[LodType, GameVersion];
      Indexes       :=  Table.Indexes;
      LocalNumLods  :=  Table.NumLods;
      
      LeftInd :=  0;
      i       :=  0;
      
      while i < LocalNumLods do begin
        if Indexes[i] <> LodInd then begin
          Indexes[LeftInd]  :=  Indexes[i];
          Inc(LeftInd);
        end; // .if
        
        Inc(i);
      end; // .while
      
      Table.NumLods :=  LeftInd;
    end; // .for
  end; // .for
  
  Dec(NumLods);
end; // .procedure UnregisterLod

procedure UnregisterDeadLods;
begin
  if not SysUtils.FileExists('Data\h3abp_sp.lod') then begin
    UnregisterLod(7);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3abp_bm.lod') then begin
    UnregisterLod(6);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3psprit.lod') then begin
    UnregisterLod(5);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3pbitma.lod') then begin
    UnregisterLod(4);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3ab_spr.lod') then begin
    UnregisterLod(3);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3ab_bmp.lod') then begin
    UnregisterLod(2);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3sprite.lod') then begin
    UnregisterLod(1);
  end; // .if
  
  if not SysUtils.FileExists('Data\h3bitmap.lod') then begin
    UnregisterLod(0);
  end; // .if
end; // .procedure UnregisterDeadLods

function FileIsInLod (const FileName: string; Lod: Heroes.PLod): boolean; 
begin
  {!} Assert(Lod <> nil);
  result  :=  FALSE;
  
  if FileName <> '' then begin
    asm
      MOV ECX, Lod
      ADD ECX, 4
      PUSH FileName
      MOV EAX, $4FB100
      CALL EAX
      MOV result, AL
    end; // .asm
  end; // .if
end; // .function FileIsInLod 

function FindFileLod (const FileName: string; out LodPath: string): boolean;
var
  Lod:  Heroes.PLod;
  i:    integer;
  
begin
  Lod :=  Utils.PtrOfs(ZvsLodTable, sizeof(Heroes.TLod) * (NumLods - 1));
  // * * * * * //
  result  :=  FALSE;
  i       :=  NumLods - 1;
   
  while not result and (i >= 0) do begin
    result  :=  FileIsInLod(FileName, Lod);
    
    if not result then begin
      Lod :=  Utils.PtrOfs(Lod, -sizeof(Heroes.TLod));
      Dec(i);
    end; // .if
  end; // .while

  if result then begin
    LodPath :=  pchar(integer(Lod) + 8);
  end; // .if
end; // .function FindFileLod

function Hook_LoadLods (Context: Core.PHookContext): LONGBOOL; stdcall;
var
{O} Locator:  Files.TFileLocator;
{O} FileInfo: Files.TFileItemInfo;
    FileName: string;
    i:        integer;
  
begin
  Locator   :=  Files.TFileLocator.Create;
  FileInfo  :=  nil;
  // * * * * * //
  UnregisterDeadLods;
  
  Locator.DirPath :=  'Data';
  Locator.InitSearch('*.pac');
  
  while Locator.NotEnd and (LodList.Count <= (High(TLodTable) - NumLods)) do begin
    FileName  :=  SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(FileInfo)));
    
    if (SysUtils.ExtractFileExt(FileName) = '.pac') and not FileInfo.IsDir then begin
      LodList.Add(FileName);
    end; // .if
    
    SysUtils.FreeAndNil(FileInfo);
  end; // .while
  
  Locator.FinitSearch;
  
  for i := LodList.Count - 1 downto 0 do begin
    Heroes.LoadLod(LodList[i], @ZvsLodTable[NumLods]);
    ZvsAddLodToList(NumLods);
    Inc(NumLods);
  end; // .for
  
  result  :=  Core.EXEC_DEF_CODE;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .function Hook_LoadLods

function Hook_FindFileInLod (Context: Core.PHookContext): LONGBOOL; stdcall;
var
  FileName:     string;
  Redirection:  TString;

begin
  FileName    :=  PPCHAR(Context.EBP + $8)^;
  Redirection :=  LodRedirs[FileName];
  
  if Redirection = nil then begin
    Redirection :=  GlobalLodRedirs[FileName];
  end; // .if
  
  if Redirection <> nil then begin
    PPCHAR(Context.EBP + $8)^ :=  pointer(Redirection.Value);
  end; // .if
  
  result  :=  Core.EXEC_DEF_CODE;
end; // .function Hook_FindFileInLod

procedure RedirectFile (const OldFileName, NewFileName: string);
var
  Redirection:  TString;
   
begin
  if NewFileName = '' then begin
    if OldFileName = '' then begin
      LodRedirs.Clear;
    end // .if
    else begin
      LodRedirs.DeleteItem(OldFileName);
    end; // .else
  end // .if
  else begin
    Redirection :=  LodRedirs[OldFileName];
  
    if Redirection = nil then begin
      LodRedirs[OldFileName] :=  TString.Create(NewFileName);
    end // .if
    else begin
      Redirection.Value :=  NewFileName;
    end; // .else
  end; // .else
end; // .procedure RedirectFile

procedure GlobalRedirectFile (const OldFileName, NewFileName: string);
var
  Redirection:  TString;
   
begin
  if NewFileName = '' then begin
    if OldFileName = '' then begin
      GlobalLodRedirs.Clear;
    end // .if
    else begin
      GlobalLodRedirs.DeleteItem(OldFileName);
    end; // .else
  end // .if
  else begin
    Redirection :=  GlobalLodRedirs[OldFileName];
  
    if Redirection = nil then begin
      GlobalLodRedirs[OldFileName]  :=  TString.Create(NewFileName);
    end // .if
    else begin
      Redirection.Value :=  NewFileName;
    end; // .else
  end; // .else
end; // .procedure GlobalRedirectFile

procedure OnBeforeErmInstructions (Event: PEvent); stdcall;
begin
  LodRedirs.Clear;
end; // .procedure OnBeforeErmInstructions

procedure OnSavegameWrite (Event: PEvent); stdcall;
var
{U} Redirection:  TString;
    OldFileName:  string;
    NumRedirs:    integer;
    
  procedure WriteStr (const Str: string);
  var
    StrLen: integer;
     
  begin
    StrLen  :=  Length(Str);
    Stores.WriteSavegameSection(sizeof(StrLen), @StrLen, LODREDIR_SAVE_SECTION);
    
    if StrLen > 0 then begin
      Stores.WriteSavegameSection(StrLen, pointer(Str), LODREDIR_SAVE_SECTION);
    end; // .if
  end; // .procedure WriteStr

begin
  Redirection :=  nil;
  // * * * * * //
  NumRedirs :=  LodRedirs.ItemCount;
  Stores.WriteSavegameSection(sizeof(NumRedirs), @NumRedirs, LODREDIR_SAVE_SECTION);
  
  LodRedirs.BeginIterate;
  
  while LodRedirs.IterateNext(OldFileName, pointer(Redirection)) do begin
    WriteStr(OldFileName);
    WriteStr(Redirection.Value);
    Redirection :=  nil;
  end; // .while
  
  LodRedirs.EndIterate;
end; // .procedure OnSavegameWrite

procedure OnSavegameRead (Event: PEvent); stdcall;
var
  NumRedirs:    integer;
  OldFileName:  string;
  NewFileName:  string;
  i:            integer;
    
  function ReadStr: string;
  var
    StrLen: integer;
     
  begin
    Stores.ReadSavegameSection(sizeof(StrLen), @StrLen, LODREDIR_SAVE_SECTION);
    SetLength(result, StrLen);
    
    if StrLen > 0 then begin
      Stores.ReadSavegameSection(StrLen, pointer(result), LODREDIR_SAVE_SECTION);
    end; // .if
  end; // .function ReadStr

begin
  LodRedirs.Clear;
  Stores.ReadSavegameSection(sizeof(NumRedirs), @NumRedirs, LODREDIR_SAVE_SECTION);
  
  for i := 0 to NumRedirs - 1 do begin
    OldFileName             :=  ReadStr;
    NewFileName             :=  ReadStr;
    LodRedirs[OldFileName]  :=  TString.Create(NewFileName);
  end; // .for
end; // .procedure OnSavegameRead

procedure OnBeforeWoG (Event: PEvent); stdcall;
begin
  // Remove WoG h3custom and h3wog lods registration
  PWORD($7015E5)^ :=  $38EB;
  Core.Hook(@Hook_LoadLods, Core.HOOKTYPE_BRIDGE, 5, Ptr($559408));
  
  // Lods files redirection mechanism
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FB106));
  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FACA6));
end; // .procedure OnBeforeWoG

begin
  GlobalLodRedirs :=  AssocArrays.NewStrictAssocArr(TString);
  LodRedirs       :=  AssocArrays.NewStrictAssocArr(TString);
  LodList         :=  Lists.NewSimpleStrList;

  GameExt.RegisterHandler(OnBeforeWoG,              'OnBeforeWoG');
  GameExt.RegisterHandler(OnBeforeErmInstructions,  'OnBeforeErmInstructions');
  GameExt.RegisterHandler(OnSavegameWrite,          'OnSavegameWrite');
  GameExt.RegisterHandler(OnSavegameRead,           'OnSavegameRead');
end.
