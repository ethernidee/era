unit GameExt;
(*
  Game extension support.
  Author: Alexander Shostak aka Berserker.
*)

(***)  interface  (***)
uses
  Windows, Math, SysUtils, PatchApi,
  Utils, DataLib, CFiles, Files, FilesEx, Crypto, StrLib, Core,
  Lists, CmdApp, Log, WinUtils,
  VfsImport, BinPatching, EventMan, DlgMes;

type
  (* Import *)
  TList       = DataLib.TList;
  TStringList = DataLib.TStrList;
  TEvent      = EventMan.TEvent;
  PEvent      = EventMan.PEvent;

const
  (* Command line arguments *)
  CMDLINE_ARG_MODLIST = 'modlist';

  (* Paths *)
  MODS_DIR                  = 'Mods';
  DEFAULT_MOD_LIST_FILE     = MODS_DIR + '\list.txt';
  PLUGINS_PATH              = 'EraPlugins';
  PATCHES_PATH              = 'EraPlugins';
  DEBUG_DIR                 = 'Debug\Era';
  DEBUG_MAPS_DIR            = 'DebugMaps';
  RUNTIME_DIR               = 'Runtime';
  RANDOM_MAPS_DIR           = 'Random_Maps';
  SAVED_GAMES_DIR           = 'Games';
  DEBUG_EVENT_LIST_PATH     = DEBUG_DIR + '\event list.txt';
  DEBUG_PATCH_LIST_PATH     = DEBUG_DIR + '\patch list.txt';
  DEBUG_MOD_LIST_PATH       = DEBUG_DIR + '\mod list.txt';
  DEBUG_X86_PATCH_LIST_PATH = DEBUG_DIR + '\x86 patches.txt';

  CONST_STR = -1;

  NO_EVENT_DATA = nil;

  ERA_VERSION_STR = '3.9.4';
  ERA_VERSION_INT = 3904;

  FALLBACK_TO_ORIGINAL      = true;
  DONT_FALLBACK_TO_ORIGINAL = false;

type
  EAssertFailure = class (Exception) end;

  PEraEventParams = ^TEraEventParams;
  TEraEventParams = array [0..15] of integer;

  PMemRedirection = ^TMemRedirection;
  TMemRedirection = record
    OldAddr:    pointer;
    BlockSize:  integer;
    NewAddr:    pointer;
  end;


var
{O} PluginsList:      DataLib.TStrList {OF TDllHandle};
    hEra:             Windows.THandle;
    DumpVfsOpt:       boolean;
    ProcessStartTime: Windows.TSystemTime;

(* Means for exe structures relocation (enlarging). It's possible to find relocated address by old
   structure address in a speed of binary search (log2(N)) *)
{O} MemRedirections: {O} DataLib.TList {OF PMemRedirection};

  GameDir: string;
  ModsDir: string;
  MapDir:  string;


function  PatchExists (const PatchName: string): boolean; stdcall;
function  PluginExists (const PluginName: string): boolean; stdcall;
procedure RedirectMemoryBlock (OldAddr: pointer; BlockSize: integer; NewAddr: pointer); stdcall;
function  GetRealAddr (Addr: pointer): pointer; stdcall;
function  GetMapDir: string; stdcall;
function  GetMapDirName: string;
procedure SetMapDir (const NewMapDir: string);
function  GetMapResourcePath (const RelResourcePath: string): string;
function  LoadMapRscFile (const RelResourcePath: string; out FileContents: string): boolean;
procedure GenerateDebugInfo;
procedure ReportPluginVersion (const VersionLine: string);

procedure Init (hDll: integer);


(***) implementation (***)
uses Heroes;

const
  WoGVersionStrEng: ppchar = pointer($7066E2);
  WoGVersionStrRus: ppchar = pointer($7066CF);

var
{On} ReportedPluginVersions: TStrList;
     VersionsInfo:           string;


procedure InitWoG; ASSEMBLER;
asm
  MOV EAX, $70105A
  CALL EAX
  MOV EAX, $774483
  CALL EAX
  MOV ECX, $28AAFD0
  MOV EAX, $706CC0
  CALL EAX
  MOV EAX, $701215
  CALL EAX
end; // .procedure InitWoG

procedure LoadPlugins (const Ext: string);
const
  ERM_V_1 = $887668;

var
  DllName:             string;
  DllHandle:           integer;
  FileExt:             string;
  ForbiddenPluginPath: string;

begin
  with Files.Locate(GameDir + '\' + PLUGINS_PATH + '\*.' + Ext, Files.ONLY_FILES) do begin
    while FindNext do begin
      if (FoundRec.Rec.Size > 0) then begin
        DllName := SysUtils.AnsiLowerCase(FoundName);
        FileExt := StrLib.ExtractExt(FoundName);

        if (FileExt = 'dll') or (FileExt = 'era') then begin
          ForbiddenPluginPath := SysUtils.ChangeFileExt(FoundPath, Utils.IfThen(FileExt = 'dll', '.era', '.dll'));

          {!} Assert(
            not SysUtils.FileExists(ForbiddenPluginPath),
            Format('Failed to load plugin "%s", because "%s" is also present. Duplicate plugin files with different extensions detected.', [FoundPath, ForbiddenPluginPath])
          );

          // Providing Era handle in v1 for compatibility reasons
          PINTEGER(ERM_V_1)^ := hEra;

          DllHandle := Windows.LoadLibrary(pchar(FoundPath));
          {!} Assert(DllHandle <> 0, 'Failed to load DLL at "' + FoundPath + '"');
          PluginsList.AddObj(DllName, Ptr(DllHandle));
        end;
      end; // .if
    end; // .while
  end; // .with
end; // .procedure LoadPlugins

procedure ReportPluginVersion (const VersionLine: string);
begin
  if ReportedPluginVersions <> nil then begin
    ReportedPluginVersions.Add(VersionLine);
  end;
end;

function PatchExists (const PatchName: string): boolean;
var
  PatchInd: integer;

begin
  result := BinPatching.PatchList.Find(PatchName, PatchInd);
end;

function PluginExists (const PluginName: string): boolean;
var
  FileSize: integer;

begin
  result  :=
    (Files.GetFileSize(PLUGINS_PATH + '\' + PluginName + '.era', FileSize) and (FileSize > 0)) or
    (Files.GetFileSize(PLUGINS_PATH + '\' + PluginName + '.dll', FileSize) and (FileSize > 0));
end;

function CompareMemoryBlocks (Addr1: pointer; Size1: integer; Addr2: pointer; Size2: integer): integer;
begin
  {!} Assert(Size1 > 0);
  {!} Assert(Size2 > 0);

  if (Math.Max(cardinal(Addr1) + cardinal(Size1), cardinal(Addr2) + cardinal(Size2)) - Math.Min(cardinal(Addr1), cardinal(Addr2))) < (cardinal(Size1) + cardinal(Size2)) then begin
    result := 0;
  end else if cardinal(Addr1) < cardinal(Addr2) then begin
    result := -1;
  end else begin
    result := +1;
  end;
end; // .function CompareMemoryBlocks

function FindMemoryRedirection (Addr: pointer; Size: integer; out {i} BlockInd: integer): boolean;
var
{U} Redirection:    PMemRedirection;
    LeftInd:        integer;
    RightInd:       integer;
    ComparisonRes:  integer;

begin
  {!} Assert(Size >= 0);
  Redirection := nil;

  // * * * * * //
  result   := false;
  LeftInd  := 0;
  RightInd := MemRedirections.Count - 1;

  while (LeftInd <= RightInd) and not result do begin
    BlockInd      := LeftInd + (RightInd - LeftInd) div 2;
    Redirection   := MemRedirections[BlockInd];
    ComparisonRes := CompareMemoryBlocks(Addr, Size, Redirection.OldAddr, Redirection.BlockSize);
    result        := ComparisonRes = 0;

    if ComparisonRes < 0 then begin
      RightInd := BlockInd - 1;
    end else if ComparisonRes > 0 then begin
      LeftInd  := BlockInd + 1;
    end;
  end; // .while

  if not result then begin
    BlockInd := LeftInd;
  end;
end; // .function FindMemoryRedirection

procedure RedirectMemoryBlock (OldAddr: pointer; BlockSize: integer; NewAddr: pointer);
var
{U} OldRedirection: PMemRedirection;
{O} NewRedirection: PMemRedirection;
    BlockInd:       integer;

begin
  {!} Assert(OldAddr <> nil);
  {!} Assert(BlockSize > 0);
  {!} Assert(NewAddr <> nil);
  OldRedirection := nil;
  NewRedirection := nil;
  // * * * * * //
  if not FindMemoryRedirection(OldAddr, BlockSize, BlockInd) then begin
    New(NewRedirection);
    NewRedirection.OldAddr   := OldAddr;
    NewRedirection.BlockSize := BlockSize;
    NewRedirection.NewAddr   := NewAddr;
    MemRedirections.Insert(NewRedirection, BlockInd); NewRedirection := nil;
  end else begin
    OldRedirection := MemRedirections[BlockInd];
    Core.FatalError
    (
      'Cannot redirect block at address $' +
      SysUtils.Format('%x', [integer(OldAddr)]) +
      ' of size ' + SysUtils.IntToStr(BlockSize) +
      ' to address $' + SysUtils.Format('%x', [integer(NewAddr)]) +
      #13#10' because there already exists a redirection from address ' +
      SysUtils.Format('%x', [integer(OldRedirection.OldAddr)]) +
      ' of size ' + SysUtils.IntToStr(OldRedirection.BlockSize) +
      ' to address $' + SysUtils.Format('%x', [integer(OldRedirection.NewAddr)])
    );
  end; // .else
  // * * * * * //
  FreeMem(NewRedirection);
end; // .procedure RedirectMemoryBlock

function GetRealAddr (Addr: pointer): pointer;
var
{U} Redirection: PMemRedirection;
    BlockInd:    integer;

begin
  Redirection := nil;
  // * * * * * //
  result := Addr;

  if FindMemoryRedirection(Addr, sizeof(byte), BlockInd) then begin
    Redirection := MemRedirections[BlockInd];
    result      := Utils.PtrOfs(Redirection.NewAddr, integer(Addr) - integer(Redirection.OldAddr));
  end;
end; // .function GetRealAddr

function GetMapDir: string;
begin
  if MapDir = '' then begin
    if Heroes.IsCampaign then begin
      MapDir := GameDir + '\Maps\Resources\' + SysUtils.ChangeFileExt(Heroes.GetCampaignFileName, '') + '\' + SysUtils.IntToStr(Heroes.GetCampaignMapInd + 1);
    end else begin
      MapDir := GameDir + '\Maps\Resources\' + SysUtils.ChangeFileExt(Heroes.GetMapFileName, '');
    end;
  end;

  result := MapDir;
end;

function GetMapDirName: string;
begin
  if Heroes.IsCampaign then begin
    result := SysUtils.ChangeFileExt(Heroes.GetCampaignFileName, '') + '\' + SysUtils.IntToStr(Heroes.GetCampaignMapInd + 1);
  end else begin
    result := SysUtils.ChangeFileExt(Heroes.GetMapFileName, '');
  end;
end;

procedure SetMapDir (const NewMapDir: string);
begin
  MapDir := NewMapDir;
end;

function GetMapResourcePath (const RelResourcePath: string): string;
begin
  result := GetMapDir + '\' + RelResourcePath;
end;

function LoadMapRscFile (const RelResourcePath: string; out FileContents: string): boolean;
begin
  result := Files.ReadFileContents(GetMapResourcePath(RelResourcePath), FileContents);
end;

procedure GenerateDebugInfo;
begin
  EventMan.GetInstance.Fire('OnGenerateDebugInfo', nil, 0);
end;

procedure DumpEventList;
begin
  EventMan.GetInstance.DumpEventList(GameDir + '\' + DEBUG_EVENT_LIST_PATH);
end;

procedure DumpPatchList;
var
  i: integer;

begin
  BinPatching.PatchList.Sort;

  with FilesEx.WriteFormattedOutput(GameDir + '\' + DEBUG_PATCH_LIST_PATH) do begin
    Line('> Format: [Patch name] (Patch size)');
    EmptyLine;

    for i := 0 to BinPatching.PatchList.Count - 1 do begin
      Line(Format('%s (%d)', [BinPatching.PatchList[i], integer(BinPatching.PatchList.Values[i])]));
    end;
  end;
end; // .procedure DumpPatchList

procedure DumpModList;
var
{O} MappingsReport: pchar;

begin
  MappingsReport := VfsImport.GetMappingsReportA;
  Files.WriteFileContents(MappingsReport, GameDir + '\' + DEBUG_MOD_LIST_PATH);
  // * * * * * //
  VfsImport.MemFree(MappingsReport);
end;

procedure OnGenerateDebugInfo (Event: PEvent); stdcall;
begin
  DumpModList;
  DumpEventList;
  DumpPatchList;
  PatchApi.GetPatcher().SaveDump(pchar(GameDir + '\' + DEBUG_X86_PATCH_LIST_PATH));
end;

(*
  Loads and returns list of mods from the highest priority mod to the lowest one. Each mod is described
  by existing absolute path to some directory.
  Pass CMDLINE_ARG_MODLIST command line argument to set custom path to file with mods list.
*)
function LoadModsList: {O} Lists.TStringList;
var
{O} FileLines:       Lists.TStringList;
    ModListFilePath: string;
    ModListText:     string;
    ModName:         string;
    ModPath:         string;
    ModInd:          integer;
    i:               integer;

begin
  FileLines := Lists.NewSimpleStrList();;
  result    := Lists.NewSimpleStrList();
  // * * * * * //
  result.CaseInsensitive := true;
  ModListFilePath        := CmdApp.GetArg(CMDLINE_ARG_MODLIST);

  if ModListFilePath = '' then begin
    ModListFilePath := DEFAULT_MOD_LIST_FILE;
  end;

  if Files.ReadFileContents(ModListFilePath, ModListText) then begin
    FileLines.LoadFromText(ModListText, #13#10);

    for i := FileLines.Count - 1 downto 0 do begin
      ModName := SysUtils.ExcludeTrailingBackslash( SysUtils.ExtractFileName( SysUtils.Trim(FileLines[i]) ) );

      if ModName <> '' then begin
        ModPath := SysUtils.ExpandFileName(ModsDir + '\' + ModName);

        if not result.Find(ModPath, ModInd) and Files.DirExists(ModPath) then begin
          result.Add(ModPath);
        end;
      end;
    end; // .for
  end; // .if
  // * * * * * //
  SysUtils.FreeAndNil(FileLines);
end; // .function LoadModsList

procedure AssignVersionsInfoToCredits;
begin
  if ReportedPluginVersions <> nil then begin
    VersionsInfo := '{ERA ' + ERA_VERSION_STR + '}'#10'WoG 3.59 (TE 2005)'#10'--------------------------------'#10 + ReportedPluginVersions.ToText(#10);
    SysUtils.FreeAndNil(ReportedPluginVersions);
    WoGVersionStrEng^ := pchar(VersionsInfo);
    WoGVersionStrRus^ := pchar(VersionsInfo);
  end;
end;

procedure Init (hDll: integer);
var
  ModListFilePath: string;

begin
  hEra := hDll;

  // Ensure, that Memory manager is thread safe. Hooks and API can be called from multiple threads.
  System.IsMultiThread := true;

  ModsDir := GameDir + '\' + MODS_DIR;
  Files.ForcePath(GameDir + '\' + DEBUG_DIR);
  Files.ForcePath(GameDir + '\' + RUNTIME_DIR);
  Files.ForcePath(GameDir + '\' + RANDOM_MAPS_DIR);
  Files.ForcePath(GameDir + '\' + SAVED_GAMES_DIR);

  // Era started, load settings, initialize logging subsystem
  EventMan.GetInstance.Fire('OnEraStart', NO_EVENT_DATA, 0);

  // Run VFS
  ModListFilePath := CmdApp.GetArg(CMDLINE_ARG_MODLIST);

  if ModListFilePath = '' then begin
    ModListFilePath := GameDir + '\' + DEFAULT_MOD_LIST_FILE;
  end;

  VfsImport.MapModsFromListA(pchar(GameDir), pchar(ModsDir), pchar(ModListFilePath));
  Log.Write('Core', 'ReportModList', #13#10 + VfsImport.GetMappingsReportA);

  if DumpVfsOpt then begin
    Log.Write('Core', 'DumpVFS', #13#10 + VfsImport.GetDetailedMappingsReportA);
  end;

  VfsImport.RunVfs(VfsImport.SORT_FIFO);
  VfsImport.RunWatcherA(pchar(GameDir + '\Mods'), 250);

  EventMan.GetInstance.Fire('OnAfterVfsInit', NO_EVENT_DATA, 0);

  LoadPlugins('era');
  EventMan.GetInstance.Fire('$OnAfterLoadEraPlugins', NO_EVENT_DATA, 0);
  EventMan.GetInstance.Fire('OnBeforeWoG', NO_EVENT_DATA, 0);
  BinPatching.ApplyPatches(GameDir + '\' + PATCHES_PATH + '\BeforeWoG');

  InitWoG;

  LoadPlugins('dll');
  EventMan.GetInstance.Fire('OnAfterWoG', NO_EVENT_DATA, 0);
  BinPatching.ApplyPatches(GameDir + '\' + PATCHES_PATH + '\AfterWoG');

  EventMan.GetInstance.On('OnGenerateDebugInfo', OnGenerateDebugInfo);

  EventMan.GetInstance.Fire('OnReportVersion');
  AssignVersionsInfoToCredits;

  EventMan.GetInstance.Fire('OnAfterStructRelocations');
end; // .procedure Init

procedure AssertHandler (const Mes, FileName: string; LineNumber: integer; Address: pointer);
var
  CrashMes: string;

begin
  CrashMes := StrLib.BuildStr
  (
    'Assert violation in file "~FileName~" on line ~Line~.'#13#10'Error at address: $~Address~.'#13#10'Message: "~Message~"',
    [
      'FileName', FileName,
      'Line',     SysUtils.IntToStr(LineNumber),
      'Address',  SysUtils.Format('%x', [integer(Address)]),
      'Message',  Mes
    ],
    '~'
  );

  Log.Write('Core', 'AssertHandler', CrashMes);
  DlgMes.MsgError(CrashMes);

  // Better callstack
  pinteger(0)^ := 0;
  //raise EAssertFailure.Create(CrashMes) at Address;
end; // .procedure AssertHandler

begin
  AssertErrorProc        := AssertHandler;
  PluginsList            := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  MemRedirections        := DataLib.NewList(not Utils.OWNS_ITEMS);
  ReportedPluginVersions := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);

  // Find out path to game directory and force it as current directory
  GameDir := StrLib.ExtractDirPathW(WinUtils.GetExePath());
  {!} Assert(GameDir <> '', 'Failed to obtain game directory path');
  SysUtils.SetCurrentDir(GameDir);

  Core.SetDebugMapsDir(GameDir + '\' + DEBUG_MAPS_DIR);

  Windows.GetSystemTime(ProcessStartTime);
end.
