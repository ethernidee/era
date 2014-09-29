unit BinPatching;
{
DESCRIPTION:  Unit allows to load and apply binary patches in Era *.bin and *.json formats
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

interface
uses SysUtils, Utils, PatchApi, Core, DataLib, Files;

type
  (* Import *)
  TStrList = DataLib.TStrList;

  PBinPatchFile = ^TBinPatchFile;
  TBinPatchFile = packed record (* format *)
    NumPatches: integer;
    (*
    Patches:    array NumPatches of TBinPatch;
    *)
    Patches:    Utils.TEmptyRec;
  end; // .record TBinPatchFile

  PBinPatch = ^TBinPatch;
  TBinPatch = packed record (* format *)
    Addr:     pointer;
    NumBytes: integer;
    (*
    Bytes:    array NumBytes of byte;
    *)
    Bytes:    Utils.TEmptyRec;
  end; // .record TBinPatch

var
{O} PatchList:   {U} TStrList {of PatchSize: integer};
    PatchAutoId: integer = 1;

procedure ApplyPatches (const DirPath: string);


implementation


function GetUniquePatchName (const BasePatchName: string): string;
begin
  result := IntToStr(PatchAutoId) + ':' + BasePatchName;
  Inc(PatchAutoId);
end; // .function GetUniquePatchName

procedure ApplyBinPatch (const BinPatchSource: string; BinPatchFile: PBinPatchFile);
const
  CODE_PATCH = true;

var
{U} Patcher:    PatchApi.TPatcherInstance;
{U} Patch:      PBinPatch;
    NumPatches: integer;
    i:          integer;  
  
begin
  {!} Assert(BinPatchFile <> nil);
  Patcher := Core.GlobalPatcher.CreateInstance(pchar(GetUniquePatchName(BinPatchSource)));
  Patch   := @BinPatchFile.Patches;
  // * * * * * //
  NumPatches := BinPatchFile.NumPatches;

  try
    for i := 1 to NumPatches do begin
      Patcher.Write(cardinal(Patch.Addr), cardinal(@Patch.Bytes), Patch.NumBytes, CODE_PATCH);
      Patch := Utils.PtrOfs(Patch, sizeof(Patch^) + Patch.NumBytes);
    end; // .for
  except
    Core.FatalError('Failed to apply binary patch "' + BinPatchSource + '"');
  end; // .try
end; // .procedure ApplyBinPatch

function LoadBinPatch (const FilePath: string; out PatchContents: string): boolean;
var
  FileContents: string;

begin
  result := Files.ReadFileContents(FilePath, FileContents) and
            (length(FileContents) >= sizeof(TBinPatchFile));

  if result then begin
    PatchContents := FileContents;
  end; // .if
end; // .function LoadBinPatch

procedure ApplyPatches (const DirPath: string);
var
  FileContents: string;
  
begin
  with Files.Locate(DirPath + '\*.bin', Files.ONLY_FILES) do begin
    while FindNext do begin
      if LoadBinPatch(DirPath + '\' + FoundName, FileContents) then begin
        PatchList.AddObj(FoundName, Ptr(length(FileContents)));
        ApplyBinPatch(FoundName, pointer(FileContents));
      end; // .if
    end; // .while
  end; // .with
end; // .procedure ApplyPatches

begin
  PatchList := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end.