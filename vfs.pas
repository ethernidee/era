UNIT VFS;
{
DESCRIPTION:  Virtual File System
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES
  Windows, SysUtils, Math, MMSystem,
  Utils, Crypto, Lists, DataLib, StrLib,  StrUtils, Files, Log, TypeWrappers, CmdApp,
  PatchApi, VfsApiDigger, Core, Ini;

(*
  Redirects calls to:
    CreateDirectoryA,
    CreateFileA,
    DeleteFileA,
    FindClose,
    FindFirstFileA,
    FindNextFileA,
    GetCurrentDirectoryA,
    GetFileAttributesA,
    GetFullPathNameA,
    GetPrivateProfileStringA,
    LoadCursorFromFileA,
    LoadLibraryA,
    PlaySoundA,
    RemoveDirectoryA,
    SetCurrentDirectoryA
*)

(* IMPORT *)
TYPE
  TDict     = DataLib.TDict;
  TObjDict  = DataLib.TObjDict;
  TString   = TypeWrappers.TString;


CONST
  MODS_DIR                  = 'Mods';
  CMDLINE_ARG_MODLIST       = 'modlist';
  DEFAULT_MODLIST_FILEPATH  = MODS_DIR + '\list.txt';

  GAME_SETTINGS_FILE  = 'heroes3.ini';
  ERA_SECTION_NAME    = 'Era';
  VFS_SECTION_NAME    = 'VFS';


TYPE
  TSearchList = CLASS
    {O} FileList: {O} Lists.TStringList {OF Windows.PWin32FindData};
        FileInd:  INTEGER;

    CONSTRUCTOR Create;
    DESTRUCTOR  Destroy; OVERRIDE;
  END; // .CLASS TSearchList


VAR
{O} ModList: Lists.TStringList;

(*
  CachedPaths, case RedirectedPath of
    '[Full path to file in Mods]' => file exists, no search is necessary
    ''                            => file does not exist in Mods, no search is necessary
    NIL                           => no information, search is necessary
*)
{O} CachedPaths: {O} TDict {OF RelPath: STRING => RedirectedPath: TString};
{O} SearchHandles: {O} TObjDict {OF hSearch: INTEGER => Value: TSearchList};

  // The value is used for finding free seacrh handle for FindFirstFileA function
  hSearch: INTEGER = 1;

  CachedPathsCritSection: Windows.TRTLCriticalSection;
  FileSearchCritSection:  Windows.TRTLCriticalSection;
  FileSearchInProgress:   BOOLEAN = FALSE;
  CurrDirCritSection:     Windows.TRTLCriticalSection;

  NativeGetFileAttributes: FUNCTION (FilePath: PCHAR): INTEGER; STDCALL;

  Kernel32Handle: INTEGER;
  User32Handle: INTEGER;

  GamePath: STRING;
  CurrentDir: STRING;

  DebugOpt: BOOLEAN;


(***) IMPLEMENTATION (***)


CONST
  MAX_SEARCH_HANDLE = 1000;
  VFS_EXTRA_DEBUG = FALSE;


VAR
  SetProcessDEPPolicyAddr: INTEGER;


FUNCTION ReadIniOpt (CONST OptionName, SectionOname: STRING): STRING;
BEGIN
  IF Ini.ReadStrFromIni(OptionName, SectionOname, GAME_SETTINGS_FILE, RESULT) THEN BEGIN
    RESULT := SysUtils.Trim(RESULT);
  END // .IF
  ELSE BEGIN
    RESULT := '';
  END; // .ELSE
END; // .FUNCTION ReadIniOpt

CONSTRUCTOR TSearchList.Create;
BEGIN
  Self.FileList := Lists.NewStrList
  (
    Utils.OWNS_ITEMS,
    NOT Utils.ITEMS_ARE_OBJECTS,
    Utils.NO_TYPEGUARD,
    Utils.ALLOW_NIL
  );

  Self.FileList.CaseInsensitive := TRUE;
  Self.FileList.ForbidDuplicates := TRUE;
END; // .CONSTRUCTOR TSearchList.Create

DESTRUCTOR TSearchList.Destroy;
BEGIN
  SysUtils.FreeAndNil(Self.FileList);
END; // .DESTRUCTOR TSearchList.Destroy

FUNCTION IsRelativePath (CONST Path: STRING): BOOLEAN;
VAR
  DesignatorPos: INTEGER;

BEGIN
  RESULT := NOT StrLib.FindChar(':', Path, DesignatorPos) AND
            NOT StrUtils.AnsiStartsStr('\\', Path);
END; // .FUNCTION IsRelativePath

PROCEDURE MakeModList;
VAR
{O} FileList:         Lists.TStringList;
    ModListFilePath:  STRING;
    ModListText:      STRING;
    ModName:          STRING;
    ModPath:          STRING;
    ModInd:           INTEGER;
    i:                INTEGER;

BEGIN
  FileList := Lists.NewSimpleStrList;
  // * * * * * //
  ModList.CaseInsensitive := TRUE;
  ModListFilePath := CmdApp.GetArg(CMDLINE_ARG_MODLIST);

  IF ModListFilePath = '' THEN BEGIN
    ModListFilePath := DEFAULT_MODLIST_FILEPATH;
  END; // .IF

  IF Files.ReadFileContents(ModListFilePath, ModListText) THEN BEGIN
    FileList.LoadFromText(ModListText, #13#10);

    FOR i := FileList.Count - 1 DOWNTO 0 DO BEGIN
      ModName := SysUtils.ExcludeTrailingBackslash(
                  SysUtils.ExtractFileName(
                   SysUtils.Trim(FileList[i])));

      IF ModName <> '' THEN BEGIN
        ModPath := SysUtils.ExpandFileName
        (
          StrLib.Concat([GamePath, '\' + MODS_DIR + '\', ModName])
        );

        IF NOT ModList.Find(ModPath, ModInd) AND Files.DirExists(ModPath) THEN BEGIN
          ModList.Add(ModPath);
        END; // .IF
      END; // .IF
    END; // .FOR
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'MakeModList', 'Mod list:'#13#10 + ModList.ToText(#13#10));
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(FileList);
END; // .PROCEDURE MakeModList

FUNCTION FileExists (CONST FilePath: STRING): BOOLEAN;
BEGIN
  RESULT := NativeGetFileAttributes(PCHAR(FilePath)) <> -1;
END; // .FUNCTION FileExists

FUNCTION DirExists (CONST FilePath: STRING): BOOLEAN;
VAR
  Attrs: INTEGER;

BEGIN
  Attrs := NativeGetFileAttributes(PCHAR(FilePath));
  RESULT := (Attrs <> - 1) AND ((Attrs AND Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0);
END; // .FUNCTION DirExists

FUNCTION FindVFSPath (CONST RelativePath: STRING; OUT RedirectedPath: STRING): BOOLEAN;
VAR
{U} RedirectedPathValue:  TString;
    NumMods:              INTEGER;
    i:                    INTEGER;

BEGIN
  RedirectedPathValue := NIL;
  // * * * * * //
  {!} Windows.EnterCriticalSection(CachedPathsCritSection);

  RESULT := FALSE;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'FindVFSPath', 'Original: ' + RelativePath);
  END; // .IF

  IF CachedPaths.GetExistingValue(RelativePath, POINTER(RedirectedPathValue)) THEN BEGIN
    RESULT := RedirectedPathValue.Value <> '';

    IF RESULT THEN BEGIN
      RedirectedPath := RedirectedPathValue.Value;
    END; // .IF
  END // .IF
  ELSE BEGIN
    NumMods := ModList.Count;
    i := 0;

    WHILE (i < NumMods) AND NOT RESULT DO BEGIN
      RedirectedPath := StrLib.Concat([ModList[i], '\', RelativePath]);
      RESULT := FileExists(RedirectedPath);

      INC(i);
    END; // .WHILE

    IF RESULT THEN BEGIN
      CachedPaths[RelativePath] := TString.Create(RedirectedPath);
    END // .IF
    ELSE BEGIN
      CachedPaths[RelativePath] := TString.Create('');
    END; // .ELSE
  END; // .ELSE

  IF DebugOpt THEN BEGIN
    IF RESULT THEN BEGIN
      Log.Write('VFS', 'FindVFSPath', 'Redirected: ' + RedirectedPath);
    END // .IF
    ELSE BEGIN
      Log.Write('VFS', 'FindVFSPath', 'Result: NOT_FOUND');
    END; // .ELSE
  END; // .IF

  {!} Windows.LeaveCriticalSection(CachedPathsCritSection);
END; // .FUNCTION FindVFSPath

FUNCTION IsInGameDir (CONST FullPath: STRING): BOOLEAN;
BEGIN
  RESULT := ((LENGTH(FullPath) - LENGTH(GamePath)) > 1) AND
            StrUtils.AnsiStartsText(GamePath, FullPath) AND
            (FullPath[LENGTH(GamePath) + 1] = '\');

  IF DebugOpt THEN BEGIN
    IF RESULT THEN BEGIN
      Log.Write('VFS', 'IsInGameDir', FullPath + '  =>  YES');
    END // .IF
    ELSE BEGIN
      Log.Write('VFS', 'IsInGameDir', FullPath + '  =>  NO');
    END; // .ELSE
  END; // .IF
END; // .FUNCTION IsInGameDir

FUNCTION GameRelativePath (CONST FullPath: STRING): STRING;
BEGIN
  // Copy rest of path right after "\" character
  RESULT := System.Copy(FullPath, LENGTH(GamePath) + SIZEOF('\') + 1);
END; // .FUNCTION GameRelativePath

PROCEDURE MyScanDir (CONST MaskedPath: STRING; SearchList: TSearchList);
VAR
{U} FoundData: Windows.PWin32FindData;

BEGIN
  {!} ASSERT(SearchList <> NIL);

  WITH Files.Locate(MaskedPath, Files.FILES_AND_DIRS) DO BEGIN
    WHILE FindNext DO BEGIN
      IF SearchList.FileList.Items[FoundName] = NIL THEN BEGIN
        NEW(FoundData);
        FoundData^ := FoundRec.FindData;
        SearchList.FileList.AddObj(FoundName, FoundData);
      END; // .IF
    END; // .WHILE
  END; // .WITH
END; // .PROCEDURE MyScanDir

FUNCTION MyFindFirstFile (CONST MaskedPath: STRING; IsInternalSearch: BOOLEAN;
                          OUT ResHandle: INTEGER): BOOLEAN;
VAR
{O} SearchList:   TSearchList;
    RelativePath: STRING;
    i:            INTEGER;

BEGIN
  SearchList := TSearchList.Create;
  // * * * * * //
  IF IsInternalSearch THEN BEGIN
    RelativePath := GameRelativePath(MaskedPath);

    IF VFS_EXTRA_DEBUG THEN BEGIN
      Log.Write('VFS', 'MyFindFirstFile', 'RelativePath: ' + RelativePath);
    END; // .IF

    FOR i := 0 TO ModList.Count - 1 DO BEGIN
      IF VFS_EXTRA_DEBUG THEN BEGIN
        Log.Write('VFS', 'MyFindFirstFile', 'TestPath: ' + ModList[i] + '\' + RelativePath);
      END; // .IF

      MyScanDir(ModList[i] + '\' + RelativePath, SearchList);
    END; // .FOR
  END; // .IF

  MyScanDir(MaskedPath, SearchList);
  RESULT := SearchList.FileList.Count > 0;

  IF RESULT THEN BEGIN
    hSearch := 1;

    WHILE (hSearch < MAX_SEARCH_HANDLE) AND (SearchHandles[Ptr(hSearch)] <> NIL) DO BEGIN
      INC(hSearch);
    END; // .WHILE

    {!} ASSERT(hSearch < MAX_SEARCH_HANDLE);
    ResHandle := hSearch;
    SearchHandles[Ptr(ResHandle)] := SearchList; SearchList :=  NIL;
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(SearchList);
END; // .FUNCTION MyFindFirstFile

FUNCTION MyFindNextFile (SearchHandle: INTEGER; OUT ResData: Windows.PWin32FindData): BOOLEAN;
VAR
{U} SearchList: TSearchList;

BEGIN
  {!} ASSERT(ResData = NIL);
  SearchList := SearchHandles[Ptr(SearchHandle)];
  // * * * * * //
  RESULT := (SearchList <> NIL) AND ((SearchList.FileInd + 1) < SearchList.FileList.Count);

  IF RESULT THEN BEGIN
    INC(SearchList.FileInd);
    ResData := SearchList.FileList.Values[SearchList.FileInd];
  END; // .IF
END; // .FUNCTION MyFindNextFile

FUNCTION Hook_GetFullPathNameA (Hook: PatchApi.THiHook; lpFileName: PCHAR;
                                nBufferLength: INTEGER; lpBuffer: PCHAR;
                                lpFilePart: POINTER): INTEGER; STDCALL;
VAR
  FilePath: STRING;
  ApiRes:   STRING;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'GetFullPathNameA', 'Original: ' + FilePath);
  END; // .IF

  IF IsRelativePath(FilePath) THEN BEGIN
    {!} Windows.EnterCriticalSection(CurrDirCritSection);
    FilePath := StrLib.Concat([CurrentDir, '\', FilePath]);
    {!} Windows.LeaveCriticalSection(CurrDirCritSection);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                          [PCHAR(FilePath), nBufferLength, lpBuffer, lpFilePart]);

  IF DebugOpt THEN BEGIN
    System.SetString(ApiRes, lpBuffer, RESULT);
    Log.Write('VFS', 'GetFullPathNameA', 'Result: ' + ApiRes);
  END; // .IF
END; // .FUNCTION Hook_GetFullPathNameA

FUNCTION Hook_CreateFileA (Hook: PatchApi.THiHook; lpFileName: PAnsiChar;
                           dwDesiredAccess, dwShareMode: DWORD;
                           lpSecurityAttributes: PSecurityAttributes;
                           dwCreationDisposition, dwFlagsAndAttributes: DWORD;
                           hTemplateFile: THandle): THandle; STDCALL;
VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;
  CreationFlags:      INTEGER;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'CreateFileA', 'Original: ' + FilePath);
  END; // .IF

  FilePath      :=  SysUtils.ExpandFileName(FilePath);
  CreationFlags :=  dwCreationDisposition;
  FinalFilePath :=  FilePath;

  IF
    IsInGameDir(FilePath) AND
    (
      ((CreationFlags AND Windows.OPEN_EXISTING)     = Windows.OPEN_EXISTING) OR
      ((CreationFlags AND Windows.TRUNCATE_EXISTING) = Windows.TRUNCATE_EXISTING)
    ) AND
    FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath)
  THEN BEGIN
    FinalFilePath := RedirectedFilePath;
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'CreateFileA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                          [PCHAR(FinalFilePath), dwDesiredAccess, dwShareMode,
                           lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes,
                           hTemplateFile]);
END; // .FUNCTION Hook_CreateFileA

FUNCTION Hook_GetFileAttributesA (Hook: PatchApi.THiHook; lpFileName: PCHAR): DWORD; STDCALL;
VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'GetFileAttributesA', 'Original: ' + FilePath);
  END; // .IF

  FilePath := SysUtils.ExpandFileName(FilePath);
  FinalFilePath := FilePath;

  IF IsInGameDir(FilePath) AND
     FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath)
  THEN BEGIN
    FinalFilePath := RedirectedFilePath;
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'GetFileAttributesA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [PCHAR(FinalFilePath)]);
END; // .FUNCTION Hook_GetFileAttributesA

FUNCTION Hook_LoadCursorFromFileA (Hook: PatchApi.THiHook; lpFileName: PAnsiChar): DWORD; STDCALL;
VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'LoadCursorFromFileA', 'Original: ' + FilePath);
  END; // .IF

  FilePath := SysUtils.ExpandFileName(FilePath);
  FinalFilePath := FilePath;

  IF IsInGameDir(FilePath) AND
     FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath)
  THEN BEGIN
    FinalFilePath := RedirectedFilePath;
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'LoadCursorFromFileA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [PCHAR(FinalFilePath)]);
END; // .FUNCTION Hook_LoadCursorFromFileA

FUNCTION Hook_LoadLibraryA (Hook: PatchApi.THiHook; lpLibFileName: PAnsiChar): HMODULE; STDCALL;
VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;

BEGIN
  FilePath := lpLibFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'LoadLibraryA', 'Original: ' + FilePath);
  END; // .IF

  // If dll is not found in current directory, we should preserve its original
  // unexpanded form in order kernel to search for dll in system directories
  FinalFilePath := FilePath;
  FilePath := SysUtils.ExpandFileName(FilePath);

  IF IsInGameDir(FilePath) THEN BEGIN
    IF FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath) THEN BEGIN
      FinalFilePath := RedirectedFilePath;
    END // .IF
    ELSE IF FileExists(FilePath) THEN BEGIN
      FinalFilePath := FilePath;
    END; // .ELSEIF
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'LoadLibraryA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [PCHAR(FinalFilePath)]);
END; // .FUNCTION Hook_LoadLibraryA

FUNCTION Hook_CreateDirectoryA (Hook: PatchApi.THiHook; lpPathName: PAnsiChar;
                                lpSecurityAttributes: PSecurityAttributes): BOOL; STDCALL;
VAR
  DirPath:         STRING;
  ExpandedDirPath: STRING;

BEGIN
  DirPath := lpPathName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'CreateDirectoryA', 'Original: ' + DirPath);
  END; // .IF

  ExpandedDirPath := SysUtils.ExpandFileName(DirPath);

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'CreateDirectoryA', 'Expanded: ' + ExpandedDirPath);
  END; // .IF

  RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                               [PCHAR(ExpandedDirPath), lpSecurityAttributes]));
END; // .FUNCTION Hook_CreateDirectoryA

FUNCTION Hook_RemoveDirectoryA (Hook: PatchApi.THiHook; lpPathName: PAnsiChar): BOOL; STDCALL;
VAR
  DirPath:         STRING;
  ExpandedDirPath: STRING;

BEGIN
  DirPath := lpPathName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'RemoveDirectoryA', 'Original: ' + DirPath);
  END; // .IF

  ExpandedDirPath := SysUtils.ExpandFileName(DirPath);

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'RemoveDirectoryA', 'Expanded: ' + ExpandedDirPath);
  END; // .IF

  RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,[PCHAR(ExpandedDirPath)]));
END; // .FUNCTION Hook_RemoveDirectoryA

FUNCTION Hook_DeleteFileA (Hook: PatchApi.THiHook; lpFileName: PAnsiChar): BOOL; STDCALL;
VAR
  FilePath:         STRING;
  ExpandedFilePath: STRING;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'DeleteFileA', 'Original: ' + FilePath);
  END; // .IF

  ExpandedFilePath := SysUtils.ExpandFileName(FilePath);

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'DeleteFileA', 'Expanded: ' + ExpandedFilePath);
  END; // .IF

  RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [PCHAR(ExpandedFilePath)]));
END; // .FUNCTION Hook_DeleteFileA

FUNCTION Hook_FindFirstFileA (Hook: PatchApi.THiHook; lpFileName: PAnsiChar;
                              VAR lpFindFileData: TWIN32FindDataA): THandle; STDCALL;
VAR
  FilePath:   STRING;
  FoundPath:  STRING;
  ResHandle:  INTEGER;

BEGIN
  {!} Windows.EnterCriticalSection(FileSearchCritSection);

  IF FileSearchInProgress THEN BEGIN
    RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [lpFileName, @lpFindFileData]);
  END // .IF
  ELSE BEGIN
    FileSearchInProgress := TRUE;
    FilePath := lpFileName;

    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'FindFirstFileA', 'Original: ' + FilePath);
    END; // .IF

    FilePath := SysUtils.ExpandFileName(FilePath);

    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'FindFirstFileA', 'MaskedPath: ' + FilePath);
    END; // .IF

    IF MyFindFirstFile(FilePath, IsInGameDir(FilePath), ResHandle) THEN BEGIN
      RESULT := ResHandle;
      lpFindFileData := Windows.PWin32FindData(TSearchList(SearchHandles[Ptr(ResHandle)])
                                               .FileList.Values[0])^;
      Windows.SetLastError(Windows.ERROR_SUCCESS);

      IF DebugOpt THEN BEGIN
        FoundPath := lpFindFileData.cFileName;
        Log.Write('VFS', 'FindFirstFileA', StrLib.Concat(['Handle: ', SysUtils.IntToStr(ResHandle),
                                                          #13#10, 'Result: ', FoundPath]));
      END; // .IF
    END // .IF
    ELSE BEGIN
      RESULT := Windows.INVALID_HANDLE_VALUE;
      Windows.SetLastError(Windows.ERROR_NO_MORE_FILES);

      IF DebugOpt THEN BEGIN
        Log.Write('VFS', 'FindFirstFileA', 'Error: ERROR_NO_MORE_FILES');
      END; // .IF
    END; // .ELSE

    FileSearchInProgress := FALSE;
  END; // .ELSE

  {!} Windows.LeaveCriticalSection(FileSearchCritSection);
END; // .FUNCTION Hook_FindFirstFileA

FUNCTION Hook_FindNextFileA (Hook: PatchApi.THiHook; hFindFile: THandle;
                             VAR lpFindFileData: TWIN32FindDataA): BOOL; STDCALL;
VAR
{U} FoundData: Windows.PWin32FindData;
    FoundPath: STRING;

BEGIN
  {!} Windows.EnterCriticalSection(FileSearchCritSection);

  IF FileSearchInProgress THEN BEGIN
    RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                   [hFindFile, @lpFindFileData]));
  END // .IF
  ELSE BEGIN
    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'FindNextFileA', 'Handle: ' + SysUtils.IntToStr(hFindFile))
    END; // .IF

    FoundData := NIL;
    RESULT := MyFindNextFile(hFindFile, FoundData);

    IF RESULT THEN BEGIN
      lpFindFileData := FoundData^;
      Windows.SetLastError(Windows.ERROR_SUCCESS);

      IF DebugOpt THEN BEGIN
        FoundPath := FoundData.cFileName;
        Log.Write('VFS', 'FindNextFileA', 'Result: ' + FoundPath)
      END; // .IF
    END // .IF
    ELSE BEGIN
      Windows.SetLastError(Windows.ERROR_NO_MORE_FILES);

      IF DebugOpt THEN BEGIN
        Log.Write('VFS', 'FindNextFileA', 'Error: ERROR_NO_MORE_FILES')
      END; // .IF
    END; // .ELSE
  END; // .ELSE

  {!} Windows.LeaveCriticalSection(FileSearchCritSection);
END; // .FUNCTION Hook_FindNextFileA

FUNCTION Hook_FindClose (Hook: PatchApi.THiHook; hFindFile: THandle): BOOL; STDCALL;
BEGIN
  {!} Windows.EnterCriticalSection(FileSearchCritSection);

  IF FileSearchInProgress OR (hFindFile < 1) OR (hFindFile >= MAX_SEARCH_HANDLE) THEN BEGIN
    {!} Windows.LeaveCriticalSection(FileSearchCritSection);

    RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc, [hFindFile]));
  END // .IF
  ELSE BEGIN
    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'FindClose', 'Handle: ' + SysUtils.IntToStr(hFindFile))
    END; // .IF

    RESULT := SearchHandles[Ptr(hFindFile)] <> NIL;

    IF RESULT THEN BEGIN
      SearchHandles.DeleteItem(Ptr(hFindFile));
      Windows.SetLastError(Windows.ERROR_SUCCESS);

      IF DebugOpt THEN BEGIN
        Log.Write('VFS', 'FindClose', 'Result: ERROR_SUCCESS');
      END; // .IF
    END // .IF
    ELSE BEGIN
      Windows.SetLastError(Windows.ERROR_INVALID_HANDLE);

      IF DebugOpt THEN BEGIN
        Log.Write('VFS', 'FindClose', 'Result: ERROR_INVALID_HANDLE');
      END; // .IF
    END; // .ELSE

    {!} Windows.LeaveCriticalSection(FileSearchCritSection);
  END; // .ELSE
END; // .FUNCTION Hook_FindClose

FUNCTION Hook_GetPrivateProfileStringA (Hook: PatchApi.THiHook;
                                        lpAppName, lpKeyName, lpDefault: PAnsiChar;
                                        lpReturnedString: PAnsiChar; nSize: DWORD;
                                        lpFileName: PAnsiChar): DWORD; STDCALL;
VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;

BEGIN
  FilePath := lpFileName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'GetPrivateProfileStringA', 'Original: ' + FilePath);
  END; // .IF

  // If ini is not found in current directory, we should preserve its original
  // unexpanded form in order kernel to search for ini in system directories
  FinalFilePath := FilePath;
  FilePath := SysUtils.ExpandFileName(FilePath);

  IF IsInGameDir(FilePath) THEN BEGIN
    IF FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath) THEN BEGIN
      FinalFilePath := RedirectedFilePath;
    END // .IF
    ELSE IF FileExists(FilePath) THEN BEGIN
      FinalFilePath := FilePath;
    END; // .ELSEIF
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'GetPrivateProfileStringA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                          [lpAppName, lpKeyName, lpDefault, lpReturnedString, nSize,
                           PCHAR(FinalFilePath)]);
END; // .FUNCTION Hook_GetPrivateProfileStringA

FUNCTION Hook_PlaySoundA (Hook: PatchApi.THiHook; pszSound: PAnsiChar; hmod: HMODULE;
                          fdwSound: DWORD): BOOL; STDCALL;

CONST
  SND_NOT_FILE = MMSystem.SND_ALIAS OR MMSystem.SND_RESOURCE;

VAR
  FilePath:           STRING;
  RedirectedFilePath: STRING;
  FinalFilePath:      STRING;

BEGIN
  FilePath := pszSound;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'PlaySoundA', 'Original: ' + FilePath);
  END; // .IF

  // If sound is not found in current directory, we should preserve its original
  // unexpanded form in order kernel to search for it in system directories
  FinalFilePath := FilePath;
  FilePath := SysUtils.ExpandFileName(FilePath);

  // NULL name means stop playing any sound
  IF (FinalFilePath <> '') AND ((fdwSound AND SND_NOT_FILE) = 0) AND IsInGameDir(FilePath)
  THEN BEGIN
    IF FindVFSPath(GameRelativePath(FilePath), RedirectedFilePath) THEN BEGIN
      FinalFilePath := RedirectedFilePath;
    END // .IF
    ELSE IF FileExists(FilePath) THEN BEGIN
      FinalFilePath := FilePath;
    END; // .ELSEIF
  END; // .IF

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'PlaySoundA', 'Redirected: ' + FinalFilePath);
  END; // .IF

  RESULT := BOOL(PatchApi.Call(PatchApi.STDCALL_, Hook.GetDefaultFunc,
                               [PCHAR(FinalFilePath), hmod, fdwSound]));
END; // .FUNCTION Hook_PlaySoundA

FUNCTION Hook_GetCurrentDirectoryA (Hook: PatchApi.THiHook; nBufferLength: DWORD;
                                    lpBuffer: PAnsiChar): DWORD; STDCALL;
VAR
  FixedCurrDir: STRING;

BEGIN
  {!} Windows.EnterCriticalSection(CurrDirCritSection);
  FixedCurrDir := CurrentDir;
  {!} Windows.LeaveCriticalSection(CurrDirCritSection);

  RESULT := ORD(Utils.IsValidBuf(lpBuffer, nBufferLength));

  IF RESULT <> 0 THEN BEGIN
    IF FixedCurrDir[LENGTH(FixedCurrDir)] = ':' THEN BEGIN
      FixedCurrDir := FixedCurrDir + '\';
    END; // .IF

    RESULT := LENGTH(FixedCurrDir) + 1;

    IF (INTEGER(nBufferLength) - 1) >= LENGTH(FixedCurrDir) THEN BEGIN
      Utils.CopyMem(LENGTH(FixedCurrDir) + 1, PCHAR(FixedCurrDir), lpBuffer);
    END; // .IF

    Windows.SetLastError(Windows.ERROR_SUCCESS);

    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'GetCurrentDirectoryA', 'Result: ' + FixedCurrDir);
    END; // .IF
  END // .IF
  ELSE BEGIN
    Windows.SetLastError(Windows.ERROR_NOT_ENOUGH_MEMORY);

    IF DebugOpt THEN BEGIN
      Log.Write('VFS', 'GetCurrentDirectoryA', 'Error: ERROR_NOT_ENOUGH_MEMORY');
    END; // .IF
  END; // .ELSE
END; // .FUNCTION Hook_GetCurrentDirectoryA

FUNCTION Hook_SetCurrentDirectoryA (Hook: PatchApi.THiHook; lpPathName: PAnsiChar): BOOL; STDCALL;
VAR
  DirPath:            STRING;
  RedirectedFilePath: STRING;
  DirPathLen:         INTEGER;

BEGIN
  DirPath := lpPathName;

  IF DebugOpt THEN BEGIN
    Log.Write('VFS', 'SetCurrentDirectoryA', 'Original: ' + DirPath);
  END; // .IF

  DirPath := SysUtils.ExpandFileName(DirPath);
  DirPathLen := LENGTH(DirPath);

  WHILE (DirPathLen > 0) AND (DirPath[DirPathLen] = '\') DO BEGIN
    DEC(DirPathLen);
  END; // .WHILE

  SetLength(DirPath, DirPathLen);
  RESULT := DirPath <> '';

  IF RESULT THEN BEGIN
    RESULT := DirExists(DirPath) OR (IsInGameDir(DirPath) AND
                                     FindVFSPath(GameRelativePath(DirPath),
                                                 RedirectedFilePath) AND
                                     DirExists(RedirectedFilePath));

    IF RESULT THEN BEGIN
      {!} Windows.EnterCriticalSection(CurrDirCritSection);
      CurrentDir := DirPath;
      {!} Windows.LeaveCriticalSection(CurrDirCritSection);

      Windows.SetLastError(Windows.ERROR_SUCCESS);
    END; // .IF
  END; // .IF

  IF NOT RESULT THEN BEGIN
    Windows.SetLastError(Windows.ERROR_FILE_NOT_FOUND);
  END; // .IF

  IF DebugOpt THEN BEGIN
    IF RESULT THEN BEGIN
      Log.Write('VFS', 'SetCurrentDirectoryA', 'Result: ' + DirPath);
    END // .IF
    ELSE BEGIN
      Log.Write('VFS', 'SetCurrentDirectoryA', 'Error: ERROR_FILE_NOT_FOUND');
    END; // .ELSE
  END; // .IF
END; // .FUNCTION Hook_SetCurrentDirectoryA

PROCEDURE AssertHandler (CONST Mes, FileName: STRING; LineNumber: INTEGER; Address: POINTER);
VAR
  CrashMes: STRING;

BEGIN
  CrashMes := StrLib.BuildStr
  (
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.',
    [
      'FileName', FileName,
      'Line',     SysUtils.IntToStr(LineNumber),
      'Address',  SysUtils.Format('%x', [INTEGER(Address)])
    ],
    '~'
  );
  Log.Write('Core', 'AssertHandler', CrashMes);
  Core.FatalError(CrashMes);
END; // .PROCEDURE AssertHandler


BEGIN
  DebugOpt := (ReadIniOpt('Debug', ERA_SECTION_NAME) = '1') AND
              (ReadIniOpt('Debug', VFS_SECTION_NAME) = '1');

  Windows.InitializeCriticalSection(CachedPathsCritSection);
  Windows.InitializeCriticalSection(FileSearchCritSection);
  Windows.InitializeCriticalSection(CurrDirCritSection);

  AssertErrorProc := AssertHandler;

  ModList       := Lists.NewSimpleStrList;
  CachedPaths   := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  SearchHandles := DataLib.NewObjDict(Utils.OWNS_ITEMS);

  GamePath := SysUtils.ExtractFileDir(ParamStr(0));
  CurrentDir := GamePath;
  Windows.SetCurrentDirectory(PCHAR(GamePath));

  MakeModList;

  Kernel32Handle := Windows.GetModuleHandle('kernel32.dll');
  User32Handle := Windows.GetModuleHandle('user32.dll');

  (* Trying to turn off DEP *)
  SetProcessDEPPolicyAddr := INTEGER(Windows.GetProcAddress(Kernel32Handle,
                                                            'SetProcessDEPPolicyAddr'));
  IF SetProcessDEPPolicyAddr <> 0 THEN BEGIN
    IF PatchApi.Call(PatchApi.STDCALL_, SetProcessDEPPolicyAddr, [0]) <> 0 THEN BEGIN
      Log.Write('VFS', 'Init', 'DEP was turned off');
    END // .IF
    ELSE BEGIN
      Log.Write('VFS', 'Init', 'Failed to turn DEP off');
    END; // .ELSE
  END; // .IF

  IF ReadIniOpt('GetFullPathNameA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing GetFullPathNameA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'GetFullPathNameA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetFullPathNameA,
    );
  END; // .IF

  IF ReadIniOpt('CreateFileA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing CreateFileA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'CreateFileA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_CreateFileA,
    );
  END; // .IF

  IF ReadIniOpt('GetFileAttributesA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing GetFileAttributesA hook');
    NativeGetFileAttributes := Ptr(Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'GetFileAttributesA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetFileAttributesA,
    ).GetDefaultFunc);
  END // .IF
  ELSE BEGIN
    NativeGetFileAttributes := @Windows.GetFileAttributesA;
  END; // .ELSE

  IF ReadIniOpt('LoadLibraryA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing LoadLibraryA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'LoadLibraryA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_LoadLibraryA,
    );
  END; // .IF

  IF ReadIniOpt('GetPrivateProfileStringA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing GetPrivateProfileStringA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'GetPrivateProfileStringA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetPrivateProfileStringA,
    );
  END; // .IF

  IF ReadIniOpt('CreateDirectoryA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing CreateDirectoryA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'CreateDirectoryA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_CreateDirectoryA,
    );
  END; // .IF

  IF ReadIniOpt('RemoveDirectoryA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing RemoveDirectoryA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'RemoveDirectoryA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_RemoveDirectoryA,
    );
  END; // .IF

  IF ReadIniOpt('DeleteFileA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing DeleteFileA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'DeleteFileA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_DeleteFileA,
    );
  END; // .IF

  IF ReadIniOpt('FindFirstFileA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing FindFirstFileA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'FindFirstFileA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_FindFirstFileA,
    );
  END; // .IF

  IF ReadIniOpt('FindNextFileA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing FindNextFileA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'FindNextFileA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_FindNextFileA,
    );
  END; // .IF

  IF ReadIniOpt('FindClose', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing FindClose hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'FindClose')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_FindClose,
    );
  END; // .IF

  IF ReadIniOpt('LoadCursorFromFileA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing LoadCursorFromFileA hook');
    Core.p.WriteHiHook
    (
      INTEGER(Windows.GetProcAddress(User32Handle, 'LoadCursorFromFileA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_LoadCursorFromFileA,
    );
  END; // .IF

  IF ReadIniOpt('PlaySoundA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing PlaySoundA hook');
    Core.p.WriteHiHook
    (
      INTEGER(Windows.GetProcAddress(Windows.LoadLibrary('winmm.dll'), 'PlaySoundA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_PlaySoundA,
    );
  END; // .IF

  IF ReadIniOpt('GetCurrentDirectoryA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing GetCurrentDirectoryA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'GetCurrentDirectoryA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_GetCurrentDirectoryA,
    );
  END; // .IF

  IF ReadIniOpt('SetCurrentDirectoryA', VFS_SECTION_NAME) = '1' THEN BEGIN
    Log.Write('VFS', 'InstallHook', 'Installing SetCurrentDirectoryA hook');
    Core.p.WriteHiHook
    (
      cardinal(VfsApiDigger.GetRealProcAddress(Kernel32Handle, 'SetCurrentDirectoryA')),
      PatchApi.SPLICE_,
      PatchApi.EXTENDED_,
      PatchApi.STDCALL_,
      @Hook_SetCurrentDirectoryA,
    );
  END; // .IF
END.
