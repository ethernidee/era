[1mdiff --git a/Lodman.pas b/Lodman.pas[m
[1mindex 4d1a927..7bf7570 100644[m
[1m--- a/Lodman.pas[m
[1m+++ b/Lodman.pas[m
[36m@@ -1,23 +1,22 @@[m
[31m-UNIT Lodman;[m
[32m+[m[32munit Lodman;[m[41m[m
 {[m
 DESCRIPTION:  LOD archives manager. Includes resource redirection support[m
 AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)[m
 BASED ON:     "Lods" plugin by Sav, WoG Sources by ZVS[m
 }[m
 [m
[31m-(***)  INTERFACE  (***)[m
[31m-USES[m
[31m-  Windows, SysUtils, Math, Utils, Files, Core, Lists, AssocArrays, TypeWrappers, DataLib,[m
[31m-  GameExt, Heroes, Stores;[m
[32m+[m[32m(***)  interface  (***)[m[41m[m
[32m+[m[32muses[m[41m[m
[32m+[m[32m  Windows, SysUtils, Math, Utils, Files, Core, Lists, AssocArrays, TypeWrappers, DataLib, Log, Json,[m[41m[m
[32m+[m[32m  StrUtils, GameExt, Heroes, Stores, EventMan;[m[41m[m
 [m
[31m-CONST[m
[32m+[m[32mconst[m[41m[m
   MAX_NUM_LODS  = 100;[m
   DEF_NUM_LODS  = 8;[m
   [m
[31m-  LODREDIR_SAVE_SECTION = 'EraRedirs';[m
[32m+[m[32m  LODREDIR_SAVE_SECTION = 'Era.ResourceRedirections';[m[41m[m
 [m
[31m-[m
[31m-TYPE[m
[32m+[m[32mtype[m[41m[m
   (* IMPORT *)[m
   TString = TypeWrappers.TString;[m
 [m
[36m@@ -25,67 +24,76 @@[m [mTYPE[m
   TLodType      = (LOD_SPRITE = 1, LOD_BITMAP = 2, LOD_WAV = 3);[m
   [m
   PLodTable = ^TLodTable;[m
[31m-  TLodTable = ARRAY [0..MAX_NUM_LODS - 1] OF Heroes.TLod;[m
[32m+[m[32m  TLodTable = array [0..MAX_NUM_LODS - 1] of Heroes.TLod;[m[41m[m
 [m
[31m-  TZvsAddLodToList  = FUNCTION (LodInd: INTEGER): INTEGER; CDECL;[m
[32m+[m[32m  TZvsAddLodToList  = function (LodInd: integer): integer; cdecl;[m[41m[m
   [m
   PIndexes  = ^TIndexes;[m
[31m-  TIndexes  = ARRAY [0..MAX_NUM_LODS - 1] OF INTEGER;[m
[32m+[m[32m  TIndexes  = array [0..MAX_NUM_LODS - 1] of integer;[m[41m[m
   [m
   PLodIndexes = ^TLodIndexes;[m
[31m-  TLodIndexes = PACKED RECORD[m
[31m-    NumLods:  INTEGER;[m
[32m+[m[32m  TLodIndexes = packed record[m[41m[m
[32m+[m[32m    NumLods:  integer;[m[41m[m
     Indexes:  PIndexes;[m
[31m-  END; // .RECORD TLodIndexes[m
[32m+[m[32m  end; // .record TLodIndexes[m[41m[m
   [m
   PLodTypes = ^TLodTypes;[m
[31m-  TLodTypes = PACKED RECORD[m
[31m-    Table:    ARRAY [TLodType, TGameVersion] OF TLodIndexes;[m
[31m-    Indexes:  ARRAY [TLodType, TGameVersion] OF TIndexes;[m
[31m-  END; // .RECORD TLodTypes[m
[32m+[m[32m  TLodTypes = packed record[m[41m[m
[32m+[m[32m    Table:    array [TLodType, TGameVersion] of TLodIndexes;[m[41m[m
[32m+[m[32m    Indexes:  array [TLodType, TGameVersion] of TIndexes;[m[41m[m
[32m+[m[32m  end; // .record TLodTypes[m[41m[m
 [m
 [m
[31m-CONST[m
[32m+[m[32mconst[m[41m[m
   ZvsAddLodToList:  TZvsAddLodToList  = Ptr($75605B);[m
   ZvsLodTable:      PLodTable         = Ptr($28077D0);[m
   ZvsLodTypes:      PLodTypes         = Ptr($79EFE0);[m
 [m
 [m
[31m-PROCEDURE RedirectFile (CONST OldFileName, NewFileName: STRING);[m
[31m-PROCEDURE GlobalRedirectFile (CONST OldFileName, NewFileName: STRING);[m
[31m-FUNCTION  FindFileLod (CONST FileName: STRING; OUT LodPath: STRING): BOOLEAN;[m
[31m-FUNCTION  FileIsInLod (CONST FileName: STRING; Lod: Heroes.PLod): BOOLEAN; [m
[32m+[m[32mprocedure RedirectFile (const OldFileName, NewFileName: string);[m[41m[m
[32m+[m[32mprocedure GlobalRedirectFile (const OldFileName, NewFileName: string);[m[41m[m
[32m+[m[32mfunction  FindFileLod (const FileName: string; out LodPath: string): boolean;[m[41m[m
[32m+[m[32mfunction  FileIsInLod (const FileName: string; Lod: Heroes.PLod): boolean;[m[41m[m
[32m+[m[32mfunction  FindRedirection (const FileName: string; var {out} Redirected: string): boolean;[m[41m[m
   [m
 [m
[31m-(***) IMPLEMENTATION (***)[m
[32m+[m[32m(***) implementation (***)[m[41m[m
[32m+[m[41m[m
[32m+[m[41m[m
[32m+[m[32mconst[m[41m[m
[32m+[m[32m  GLOBAL_REDIRECTIONS_CONFIG_DIR         = 'Data\Redirections';[m[41m[m
[32m+[m[32m  GLOBAL_MISSING_REDIRECTIONS_CONFIG_DIR = GLOBAL_REDIRECTIONS_CONFIG_DIR + '\Missing';[m[41m[m
[32m+[m[32m  MUSIC_DIR                              = 'Mp3';[m[41m[m
 [m
[32m+[m[32m  REDIRECT_ONLY_MISSING         = true;[m[41m[m
[32m+[m[32m  REDIRECT_MISSING_AND_EXISTING = not REDIRECT_ONLY_MISSING;[m[41m[m
 [m
[31m-VAR[m
[32m+[m[32mvar[m[41m[m
 {O} GlobalLodRedirs:  {O} AssocArrays.TAssocArray {OF TString};[m
 {O} LodRedirs:        {O} AssocArrays.TAssocArray {OF TString};[m
 {O} LodList:          Lists.TStringList;[m
[31m-    NumLods:          INTEGER = DEF_NUM_LODS;[m
[32m+[m[32m    NumLods:          integer = DEF_NUM_LODS;[m[41m[m
     RedirCritSection: Windows.TRTLCriticalSection;[m
 [m
 [m
[31m-PROCEDURE UnregisterLod (LodInd: INTEGER);[m
[31m-VAR[m
[32m+[m[32mprocedure UnregisterLod (LodInd: integer);[m[41m[m
[32m+[m[32mvar[m[41m[m
 {U} Table:        PLodIndexes;[m
 {U} Indexes:      PIndexes;[m
     LodType:      TLodType;[m
     GameVersion:  TGameVersion;[m
[31m-    LocalNumLods: INTEGER;[m
[32m+[m[32m    LocalNumLods: integer;[m[41m[m
     [m
[31m-    LeftInd:      INTEGER;[m
[31m-    i:            INTEGER;[m
[32m+[m[32m    LeftInd:      integer;[m[41m[m
[32m+[m[32m    i:            integer;[m[41m[m
    [m
[31m-BEGIN[m
[31m-  {!} ASSERT(Math.InRange(LodInd, 0, NumLods - 1));[m
[31m-  Table   :=  NIL;[m
[31m-  Indexes :=  NIL;[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  {!} Assert(Math.InRange(LodInd, 0, NumLods - 1), 'Lod index is out of allowed range: ' + IntToStr(LodInd));[m[41m[m
[32m+[m[32m  Table   :=  nil;[m[41m[m
[32m+[m[32m  Indexes :=  nil;[m[41m[m
   // * * * * * //[m
[31m-  FOR LodType := LOW(TLodType) TO HIGH(TLodType) DO BEGIN[m
[31m-    FOR GameVersion := LOW(TGameVersion) TO HIGH(TGameVersion) DO BEGIN[m
[32m+[m[32m  for LodType := Low(TLodType) to High(TLodType) do begin[m[41m[m
[32m+[m[32m    for GameVersion := Low(TGameVersion) to High(TGameVersion) do begin[m[41m[m
       Table         :=  @ZvsLodTypes.Table[LodType, GameVersion];[m
       Indexes       :=  Table.Indexes;[m
       LocalNumLods  :=  Table.NumLods;[m
[36m@@ -93,247 +101,273 @@[m [mBEGIN[m
       LeftInd :=  0;[m
       i       :=  0;[m
       [m
[31m-      WHILE i < LocalNumLods DO BEGIN[m
[31m-        IF Indexes[i] <> LodInd THEN BEGIN[m
[32m+[m[32m      while i < LocalNumLods do begin[m[41m[m
[32m+[m[32m        if Indexes[i] <> LodInd then begin[m[41m[m
           Indexes[LeftInd]  :=  Indexes[i];[m
[31m-          INC(LeftInd);[m
[31m-        END; // .IF[m
[32m+[m[32m          Inc(LeftInd);[m[41m[m
[32m+[m[32m        end;[m[41m[m
         [m
[31m-        INC(i);[m
[31m-      END; // .WHILE[m
[32m+[m[32m        Inc(i);[m[41m[m
[32m+[m[32m      end;[m[41m[m
       [m
       Table.NumLods :=  LeftInd;[m
[31m-    END; // .FOR[m
[31m-  END; // .FOR[m
[32m+[m[32m    end; // .for[m[41m[m
[32m+[m[32m  end; // .for[m[41m[m
   [m
[31m-  DEC(NumLods);[m
[31m-END; // .PROCEDURE UnregisterLod[m
[32m+[m[32m  Dec(NumLods);[m[41m[m
[32m+[m[32mend; // .procedure UnregisterLod[m[41m[m
 [m
[31m-PROCEDURE UnregisterDeadLods;[m
[31m-BEGIN[m
[31m-  IF NOT SysUtils.FileExists('Data\h3abp_sp.lod') THEN BEGIN[m
[32m+[m[32mprocedure UnregisterDeadLods;[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3abp_sp.lod') then begin[m[41m[m
     UnregisterLod(7);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3abp_bm.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3abp_bm.lod') then begin[m[41m[m
     UnregisterLod(6);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3psprit.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3psprit.lod') then begin[m[41m[m
     UnregisterLod(5);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3pbitma.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3pbitma.lod') then begin[m[41m[m
     UnregisterLod(4);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3ab_spr.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3ab_spr.lod') then begin[m[41m[m
     UnregisterLod(3);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3ab_bmp.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3ab_bmp.lod') then begin[m[41m[m
     UnregisterLod(2);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3sprite.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3sprite.lod') then begin[m[41m[m
     UnregisterLod(1);[m
[31m-  END; // .IF[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF NOT SysUtils.FileExists('Data\h3bitmap.lod') THEN BEGIN[m
[32m+[m[32m  if not SysUtils.FileExists('Data\h3bitmap.lod') then begin[m[41m[m
     UnregisterLod(0);[m
[31m-  END; // .IF[m
[31m-END; // .PROCEDURE UnregisterDeadLods[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[32mend; // .procedure UnregisterDeadLods[m[41m[m
 [m
[31m-FUNCTION FileIsInLod (CONST FileName: STRING; Lod: Heroes.PLod): BOOLEAN; [m
[31m-BEGIN[m
[31m-  {!} ASSERT(Lod <> NIL);[m
[31m-  RESULT  :=  FALSE;[m
[32m+[m[32mfunction FileIsInLod (const FileName: string; Lod: Heroes.PLod): boolean;[m[41m [m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  {!} Assert(Lod <> nil);[m[41m[m
[32m+[m[32m  result  :=  false;[m[41m[m
   [m
[31m-  IF FileName <> '' THEN BEGIN[m
[31m-    ASM[m
[32m+[m[32m  if FileName <> '' then begin[m[41m[m
[32m+[m[32m    asm[m[41m[m
       MOV ECX, Lod[m
       ADD ECX, 4[m
       PUSH FileName[m
       MOV EAX, $4FB100[m
       CALL EAX[m
[31m-      MOV RESULT, AL[m
[31m-    END; // .ASM[m
[31m-  END; // .IF[m
[31m-END; // .FUNCTION FileIsInLod [m
[32m+[m[32m      MOV result, AL[m[41m[m
[32m+[m[32m    end; // .asm[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[32mend; // .function FileIsInLod[m[41m [m
 [m
[31m-FUNCTION FindFileLod (CONST FileName: STRING; OUT LodPath: STRING): BOOLEAN;[m
[31m-VAR[m
[32m+[m[32mfunction FindFileLod (const FileName: string; out LodPath: string): boolean;[m[41m[m
[32m+[m[32mvar[m[41m[m
   Lod:  Heroes.PLod;[m
[31m-  i:    INTEGER;[m
[32m+[m[32m  i:    integer;[m[41m[m
   [m
[31m-BEGIN[m
[31m-  Lod :=  Utils.PtrOfs(ZvsLodTable, SIZEOF(Heroes.TLod) * (NumLods - 1));[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  Lod :=  Utils.PtrOfs(ZvsLodTable, sizeof(Heroes.TLod) * (NumLods - 1));[m[41m[m
   // * * * * * //[m
[31m-  RESULT  :=  FALSE;[m
[32m+[m[32m  result  :=  false;[m[41m[m
   i       :=  NumLods - 1;[m
    [m
[31m-  WHILE NOT RESULT AND (i >= 0) DO BEGIN[m
[31m-    RESULT  :=  FileIsInLod(FileName, Lod);[m
[32m+[m[32m  while not result and (i >= 0) do begin[m[41m[m
[32m+[m[32m    result  :=  FileIsInLod(FileName, Lod);[m[41m[m
     [m
[31m-    IF NOT RESULT THEN BEGIN[m
[31m-      Lod :=  Utils.PtrOfs(Lod, -SIZEOF(Heroes.TLod));[m
[31m-      DEC(i);[m
[31m-    END; // .IF[m
[31m-  END; // .WHILE[m
[31m-[m
[31m-  IF RESULT THEN BEGIN[m
[31m-    LodPath :=  PCHAR(INTEGER(Lod) + 8);[m
[31m-  END; // .IF[m
[31m-END; // .FUNCTION FindFileLod[m
[31m-[m
[31m-FUNCTION Hook_LoadLods (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;[m
[31m-VAR[m
[31m-{O} Locator:  Files.TFileLocator;[m
[31m-{O} FileInfo: Files.TFileItemInfo;[m
[31m-    FileName: STRING;[m
[31m-    i:        INTEGER;[m
[31m-  [m
[31m-BEGIN[m
[31m-  Locator   :=  Files.TFileLocator.Create;[m
[31m-  FileInfo  :=  NIL;[m
[32m+[m[32m    if not result then begin[m[41m[m
[32m+[m[32m      Lod :=  Utils.PtrOfs(Lod, -sizeof(Heroes.TLod));[m[41m[m
[32m+[m[32m      Dec(i);[m[41m[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m  if result then begin[m[41m[m
[32m+[m[32m    LodPath :=  pchar(integer(Lod) + 8);[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[32mend; // .function FindFileLod[m[41m[m
[32m+[m[41m[m
[32m+[m[32mfunction FileIsInLods (const FileName: string): boolean;[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m  FoundLod: string;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  result := FindFileLod(FileName, FoundLod);[m[41m[m
[32m+[m[32mend;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mfunction FindRedirection (const FileName: string; var {out} Redirected: string): boolean;[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m{U} Redirection: TString;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  Redirection := LodRedirs[FileName];[m[41m[m
   // * * * * * //[m
[32m+[m[32m  result := false;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m  if Redirection = nil then begin[m[41m[m
[32m+[m[32m    Redirection := GlobalLodRedirs[FileName];[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m  if Redirection <> nil then begin[m[41m[m
[32m+[m[32m    Redirected := Redirection.Value;[m[41m[m
[32m+[m[32m    result     := true;[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[32mend; // .function FindRedirection[m[41m[m
[32m+[m[41m[m
[32m+[m[32m(* Loads global redirection rules from json configs *)[m[41m[m
[32m+[m[32mprocedure LoadGlobalRedirectionConfig (const ConfigDir: string; RedirectOnlyMissing: boolean);[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m{O} Config:             TlkJsonObject;[m[41m[m
[32m+[m[32m    ResourceName:       string;[m[41m[m
[32m+[m[32m    WillBeRedirected:   boolean;[m[41m[m
[32m+[m[32m    ConfigFileContents: string;[m[41m[m
[32m+[m[32m    i:                  integer;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  Config := nil;[m[41m[m
[32m+[m[32m  // * * * * * //[m[41m[m
[32m+[m[32m  with Files.Locate(ConfigDir + '\*.json', Files.ONLY_FILES) do begin[m[41m[m
[32m+[m[32m    while FindNext do begin[m[41m[m
[32m+[m[32m      if Files.ReadFileContents(ConfigDir + '\' + FoundName, ConfigFileContents) then begin[m[41m[m
[32m+[m[32m        Utils.CastOrFree(TlkJson.ParseText(ConfigFileContents), TlkJsonObject, Config);[m[41m[m
[32m+[m[41m        [m
[32m+[m[32m        if Config <> nil then begin[m[41m[m
[32m+[m[32m          for i := 0 to Config.Count - 1 do begin[m[41m[m
[32m+[m[32m            ResourceName := Config.NameOf[i];[m[41m[m
[32m+[m[41m[m
[32m+[m[32m            if GlobalLodRedirs[ResourceName] = nil then begin[m[41m[m
[32m+[m[32m              WillBeRedirected := not RedirectOnlyMissing;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m              if RedirectOnlyMissing then begin[m[41m[m
[32m+[m[32m                if AnsiEndsText(ResourceName, '.mp3') then begin[m[41m[m
[32m+[m[32m                  WillBeRedirected := not FileExists(MUSIC_DIR + '\' + ResourceName);[m[41m[m
[32m+[m[32m                end else begin[m[41m[m
[32m+[m[32m                  WillBeRedirected := not FileIsInLods(ResourceName);[m[41m[m
[32m+[m[32m                end;[m[41m[m
[32m+[m[32m              end;[m[41m[m
[32m+[m[41m              [m
[32m+[m[32m              if WillBeRedirected then begin[m[41m[m
[32m+[m[32m                GlobalLodRedirs[ResourceName] := TString.Create(Config.getString(i));[m[41m[m
[32m+[m[32m              end;[m[41m[m
[32m+[m[32m            end; // .if[m[41m[m
[32m+[m[32m          end; // .for[m[41m[m
[32m+[m[32m        end else begin[m[41m[m
[32m+[m[32m          Core.NotifyError('Invalid json config: "' + ConfigDir + '\' + FoundName + '"');[m[41m[m
[32m+[m[32m        end; // .else[m[41m[m
[32m+[m[32m      end; // .if[m[41m[m
[32m+[m[32m    end; // .while[m[41m[m
[32m+[m[32m  end; // .with[m[41m[m
[32m+[m[32m  // * * * * * //[m[41m[m
[32m+[m[32m  FreeAndNil(Config);[m[41m[m
[32m+[m[32mend; // .procedure LoadGlobalRedirectionConfig[m[41m[m
[32m+[m[41m[m
[32m+[m[32mfunction Hook_LoadLods (Context: Core.PHookContext): LONGBOOL; stdcall;[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m  i: integer;[m[41m[m
[32m+[m[41m  [m
[32m+[m[32mbegin[m[41m[m
   UnregisterDeadLods;[m
   [m
   with Files.Locate('Data\*.pac', Files.ONLY_FILES) do begin[m
     while FindNext do begin[m
       LodList.Add(FoundName);[m
[31m-    end; // .while[m
[31m-  end; // .with[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  FOR i := LodList.Count - 1 DOWNTO 0 DO BEGIN[m
[32m+[m[32m  for i := LodList.Count - 1 downto 0 do begin[m[41m[m
     Heroes.LoadLod(LodList[i], @ZvsLodTable[NumLods]);[m
     ZvsAddLodToList(NumLods);[m
[31m-    INC(NumLods);[m
[31m-  END; // .FOR[m
[31m-  [m
[31m-  RESULT  :=  Core.EXEC_DEF_CODE;[m
[31m-  // * * * * * //[m
[31m-  SysUtils.FreeAndNil(Locator);[m
[31m-END; // .FUNCTION Hook_LoadLods[m
[31m-[m
[31m-FUNCTION FindRedirection (CONST FileName: STRING; OUT Redirected: STRING): BOOLEAN;[m
[31m-VAR[m
[31m-{U} Redirection: TString;[m
[31m-[m
[31m-BEGIN[m
[31m-  Redirection := LodRedirs[FileName];[m
[31m-  // * * * * * //[m
[31m-  RESULT := FALSE;[m
[31m-[m
[31m-  IF Redirection = NIL THEN BEGIN[m
[31m-    Redirection :=  GlobalLodRedirs[FileName];[m
[31m-  END; // .IF[m
[31m-[m
[31m-  IF Redirection <> NIL THEN BEGIN[m
[31m-    Redirected := Redirection.Value;[m
[31m-    RESULT     := TRUE;[m
[31m-  END; // .IF[m
[31m-END; // .FUNCTION FindRedirection[m
[31m-[m
[31m-FUNCTION Hook_FindFileInLod (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;[m
[31m-VAR[m
[31m-  Redirected: STRING;[m
[31m-[m
[31m-BEGIN [m
[31m-  IF FindRedirection(PPCHAR(Context.EBP + $8)^, Redirected) THEN BEGIN[m
[31m-    PPCHAR(Context.EBP + $8)^ :=  PCHAR(Redirected);[m
[31m-  END; // .IF[m
[31m-  [m
[31m-  RESULT  :=  Core.EXEC_DEF_CODE;[m
[31m-END; // .FUNCTION Hook_FindFileInLod[m
[32m+[m[32m    Inc(NumLods);[m[41m[m
[32m+[m[32m  end;[m[41m[m
 [m
[31m-FUNCTION Hook_OnMp3Start (Context: Core.PHookHandlerArgs): LONGBOOL; STDCALL;[m
[31m-CONST[m
[31m-  DEFAULT_BUFFER_SIZE = 128;[m
[32m+[m[32m  result  :=  Core.EXEC_DEF_CODE;[m[41m[m
[32m+[m[32mend; // .function Hook_LoadLods[m[41m[m
 [m
[31m-VAR[m
[31m-  FileName:   STRING;[m
[31m-  Redirected: STRING;[m
[32m+[m[32mfunction Hook_FindFileInLod (Context: Core.PHookContext): LONGBOOL; stdcall;[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m  Redirected: string;[m[41m[m
 [m
[31m-BEGIN[m
[31m-  (* Carefully copy redirected value to persistent storage and don't change anything in LodRedirs *)[m
[31m-  {!} Windows.EnterCriticalSection(RedirCritSection);[m
[31m-  FileName := Heroes.Mp3Name + '.mp3';[m
[32m+[m[32mbegin[m[41m [m
[32m+[m[32m  if FindRedirection(ppchar(Context.EBP + $8)^, Redirected) then begin[m[41m[m
[32m+[m[32m    ppchar(Context.EBP + $8)^ := pchar(Redirected);[m[41m[m
[32m+[m[32m  end;[m[41m[m
   [m
[31m-  IF FindRedirection('*.mp3', Redirected) OR FindRedirection(FileName, Redirected) THEN BEGIN[m
[31m-    Utils.SetPcharValue(Heroes.Mp3Name, SysUtils.ChangeFileExt(Redirected, ''),[m
[31m-                        DEFAULT_BUFFER_SIZE);[m
[31m-  END; // .IF[m
[31m-[m
[31m-  RESULT := Core.EXEC_DEF_CODE;[m
[31m-  {!} Windows.LeaveCriticalSection(RedirCritSection);[m
[31m-END; // .FUNCTION Hook_OnMp3Start[m
[31m-[m
[31m-PROCEDURE RedirectFile (CONST OldFileName, NewFileName: STRING);[m
[31m-VAR[m
[32m+[m[32m  result := Core.EXEC_DEF_CODE;[m[41m[m
[32m+[m[32mend;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mfunction Hook_AfterLoadLods (Context: Core.PHookContext): LONGBOOL; stdcall;[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  LoadGlobalRedirectionConfig(GLOBAL_MISSING_REDIRECTIONS_CONFIG_DIR, REDIRECT_ONLY_MISSING);[m[41m[m
[32m+[m[32m  GameExt.FireEvent('OnAfterLoadLods', nil, 0);[m[41m[m
[32m+[m[32m  result := Core.EXEC_DEF_CODE;[m[41m[m
[32m+[m[32mend;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mprocedure RedirectFile (const OldFileName, NewFileName: string);[m[41m[m
[32m+[m[32mvar[m[41m[m
   Redirection:  TString;[m
    [m
[31m-BEGIN[m
[32m+[m[32mbegin[m[41m[m
   {!} Windows.EnterCriticalSection(RedirCritSection);[m
 [m
[31m-  IF NewFileName = '' THEN BEGIN[m
[31m-    IF OldFileName = '' THEN BEGIN[m
[32m+[m[32m  if NewFileName = '' then begin[m[41m[m
[32m+[m[32m    if OldFileName = '' then begin[m[41m[m
       LodRedirs.Clear;[m
[31m-    END // .IF[m
[31m-    ELSE BEGIN[m
[32m+[m[32m    end else begin[m[41m[m
       LodRedirs.DeleteItem(OldFileName);[m
[31m-    END; // .ELSE[m
[31m-  END // .IF[m
[31m-  ELSE BEGIN[m
[31m-    Redirection :=  LodRedirs[OldFileName];[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end else begin[m[41m[m
[32m+[m[32m    Redirection := LodRedirs[OldFileName];[m[41m[m
   [m
[31m-    IF Redirection = NIL THEN BEGIN[m
[31m-      LodRedirs[OldFileName] :=  TString.Create(NewFileName);[m
[31m-    END // .IF[m
[31m-    ELSE BEGIN[m
[31m-      Redirection.Value :=  NewFileName;[m
[31m-    END; // .ELSE[m
[31m-  END; // .ELSE[m
[32m+[m[32m    if Redirection = nil then begin[m[41m[m
[32m+[m[32m      LodRedirs[OldFileName] := TString.Create(NewFileName);[m[41m[m
[32m+[m[32m    end else begin[m[41m[m
[32m+[m[32m      Redirection.Value := NewFileName;[m[41m[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end; // .else[m[41m[m
   [m
   {!} Windows.LeaveCriticalSection(RedirCritSection);[m
[31m-END; // .PROCEDURE RedirectFile[m
[32m+[m[32mend; // .procedure RedirectFile[m[41m[m
 [m
[31m-PROCEDURE GlobalRedirectFile (CONST OldFileName, NewFileName: STRING);[m
[31m-VAR[m
[32m+[m[32mprocedure GlobalRedirectFile (const OldFileName, NewFileName: string);[m[41m[m
[32m+[m[32mvar[m[41m[m
   Redirection:  TString;[m
    [m
[31m-BEGIN[m
[32m+[m[32mbegin[m[41m[m
   {!} Windows.EnterCriticalSection(RedirCritSection);[m
 [m
[31m-  IF NewFileName = '' THEN BEGIN[m
[31m-    IF OldFileName = '' THEN BEGIN[m
[32m+[m[32m  if NewFileName = '' then begin[m[41m[m
[32m+[m[32m    if OldFileName = '' then begin[m[41m[m
       GlobalLodRedirs.Clear;[m
[31m-    END // .IF[m
[31m-    ELSE BEGIN[m
[32m+[m[32m    end else begin[m[41m[m
       GlobalLodRedirs.DeleteItem(OldFileName);[m
[31m-    END; // .ELSE[m
[31m-  END // .IF[m
[31m-  ELSE BEGIN[m
[31m-    Redirection :=  GlobalLodRedirs[OldFileName];[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end else begin[m[41m[m
[32m+[m[32m    Redirection := GlobalLodRedirs[OldFileName];[m[41m[m
   [m
[31m-    IF Redirection = NIL THEN BEGIN[m
[31m-      GlobalLodRedirs[OldFileName]  :=  TString.Create(NewFileName);[m
[31m-    END // .IF[m
[31m-    ELSE BEGIN[m
[31m-      Redirection.Value :=  NewFileName;[m
[31m-    END; // .ELSE[m
[31m-  END; // .ELSE[m
[32m+[m[32m    if Redirection = nil then begin[m[41m[m
[32m+[m[32m      GlobalLodRedirs[OldFileName] := TString.Create(NewFileName);[m[41m[m
[32m+[m[32m    end else begin[m[41m[m
[32m+[m[32m      Redirection.Value := NewFileName;[m[41m[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end; // .else[m[41m[m
   [m
   {!} Windows.LeaveCriticalSection(RedirCritSection);[m
[31m-END; // .PROCEDURE GlobalRedirectFile[m
[32m+[m[32mend; // .procedure GlobalRedirectFile[m[41m[m
 [m
[31m-PROCEDURE OnBeforeErmInstructions (Event: PEvent); STDCALL;[m
[31m-BEGIN[m
[32m+[m[32mprocedure OnBeforeErmInstructions (Event: PEvent); stdcall;[m[41m[m
[32m+[m[32mbegin[m[41m[m
   LodRedirs.Clear;[m
[31m-END; // .PROCEDURE OnBeforeErmInstructions[m
[32m+[m[32mend;[m[41m[m
 [m
[31m-PROCEDURE OnSavegameWrite (Event: PEvent); STDCALL;[m
[31m-BEGIN[m
[32m+[m[32mprocedure OnSavegameWrite (Event: PEvent); stdcall;[m[41m[m
[32m+[m[32mbegin[m[41m[m
   with Stores.NewRider(LODREDIR_SAVE_SECTION) do begin[m
     WriteInt(LodRedirs.ItemCount);[m
 [m
[36m@@ -341,19 +375,19 @@[m [mBEGIN[m
       while IterNext do begin[m
         WriteStr(IterKey);[m
         WriteStr(TString(IterValue).Value);[m
[31m-      end; // .while[m
[31m-    end; // .with[m
[31m-  end; // .with[m
[31m-END; // .PROCEDURE OnSavegameWrite[m
[31m-[m
[31m-PROCEDURE OnSavegameRead (Event: PEvent); STDCALL;[m
[31m-VAR[m
[31m-  NumRedirs:    INTEGER;[m
[31m-  OldFileName:  STRING;[m
[31m-  NewFileName:  STRING;[m
[31m-  i:            INTEGER;[m
[31m-[m
[31m-BEGIN[m
[32m+[m[32m      end;[m[41m[m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end;[m[41m[m
[32m+[m[32mend; // .procedure OnSavegameWrite[m[41m[m
[32m+[m[41m[m
[32m+[m[32mprocedure OnSavegameRead (Event: PEvent); stdcall;[m[41m[m
[32m+[m[32mvar[m[41m[m
[32m+[m[32m  NumRedirs:    integer;[m[41m[m
[32m+[m[32m  OldFileName:  string;[m[41m[m
[32m+[m[32m  NewFileName:  string;[m[41m[m
[32m+[m[32m  i:            integer;[m[41m[m
[32m+[m[41m[m
[32m+[m[32mbegin[m[41m[m
   {!} Windows.EnterCriticalSection(RedirCritSection);[m
   LodRedirs.Clear;[m
 [m
[36m@@ -364,38 +398,37 @@[m [mBEGIN[m
       OldFileName            := ReadStr;[m
       NewFileName            := ReadStr;[m
       LodRedirs[OldFileName] := TString.Create(NewFileName);[m
[31m-    end; // .for[m
[31m-  end; // .with [m
[32m+[m[32m    end;[m[41m[m
[32m+[m[32m  end;[m[41m [m
 [m
   {!} Windows.LeaveCriticalSection(RedirCritSection);[m
[31m-END; // .PROCEDURE OnSavegameRead[m
[32m+[m[32mend; // .procedure OnSavegameRead[m[41m[m
 [m
[31m-PROCEDURE OnBeforeWoG (Event: PEvent); STDCALL;[m
[31m-BEGIN[m
[32m+[m[32mprocedure OnBeforeWoG (Event: PEvent); stdcall;[m[41m[m
[32m+[m[32mbegin[m[41m[m
   (* Remove WoG h3custom and h3wog lods registration *)[m
   PWORD($7015E5)^ :=  $38EB;[m
   Core.Hook(@Hook_LoadLods, Core.HOOKTYPE_BRIDGE, 5, Ptr($559408));[m
   [m
   (* Lods files redirection mechanism *)[m
   Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FB106));[m
[31m-  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FACA6));[m
[31m-END; // .PROCEDURE OnBeforeWoG[m
[32m+[m[32m  Core.ApiHook(@Hook_FindFileInLod, Core.HOOKTYPE_BRIDGE, Ptr($4FACA6)); // A0_Lod_FindResource_sub_4FACA0[m[41m[m
[32m+[m[32mend;[m[41m[m
 [m
[31m-PROCEDURE OnAfterWoG (Event: PEvent); STDCALL;[m
[31m-BEGIN[m
[31m-  (* Mp3 redirection mechanism *)[m
[31m-  Core.ApiHook(@Hook_OnMp3Start, Core.HOOKTYPE_BRIDGE, Ptr($59AC51));[m
[31m-END; // .PROCEDURE OnAfterWoG[m
[32m+[m[32mprocedure OnAfterWoG (Event: PEvent); stdcall;[m[41m[m
[32m+[m[32mbegin[m[41m[m
[32m+[m[32m  LoadGlobalRedirectionConfig(GLOBAL_REDIRECTIONS_CONFIG_DIR, REDIRECT_MISSING_AND_EXISTING);[m[41m[m
[32m+[m[32mend;[m[41m[m
 [m
[31m-BEGIN[m
[32m+[m[32mbegin[m[41m[m
   Windows.InitializeCriticalSection(RedirCritSection);[m
   GlobalLodRedirs := AssocArrays.NewStrictAssocArr(TString);[m
   LodRedirs       := AssocArrays.NewStrictAssocArr(TString);[m
   LodList         := Lists.NewSimpleStrList;[m
 [m
[31m-  GameExt.RegisterHandler(OnBeforeWoG,              'OnBeforeWoG');[m
[31m-  GameExt.RegisterHandler(OnAfterWoG,               'OnAfterWoG');[m
[31m-  GameExt.RegisterHandler(OnBeforeErmInstructions,  'OnBeforeErmInstructions');[m
[31m-  GameExt.RegisterHandler(OnSavegameWrite,          'OnSavegameWrite');[m
[31m-  GameExt.RegisterHandler(OnSavegameRead,           'OnSavegameRead');[m
[31m-END.[m
[32m+[m[32m  EventMan.GetInstance.On('OnBeforeWoG',             OnBeforeWoG);[m[41m[m
[32m+[m[32m  EventMan.GetInstance.On('OnAfterWoG',              OnAfterWoG);[m[41m[m
[32m+[m[32m  EventMan.GetInstance.On('OnBeforeErmInstructions', OnBeforeErmInstructions);[m[41m[m
[32m+[m[32m  EventMan.GetInstance.On('OnSavegameWrite',         OnSavegameWrite);[m[41m[m
[32m+[m[32m  EventMan.GetInstance.On('OnSavegameRead',          OnSavegameRead);[m[41m[m
[32m+[m[32mend.[m[41m[m
