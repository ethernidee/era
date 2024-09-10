unit SndVid;
(*
  Description: Adds snd/vid archives autoloading support
  Author:      Alexander Shostak aka Berserker
*)

(***)  interface  (***)

uses
  SysUtils,
  Windows,

  ApiJack,
  AssocArrays,
  Crypto,
  DataLib,
  DlgMes,
  Files,
  StrLib,
  Utils,
  WinWrappers,

  EraSettings,
  EventMan,
  GameExt,
  Heroes;

const
  CD_GAME_FOLDER = 'Heroes3';
  CD_VIDEO_PATH  = CD_GAME_FOLDER + '\Data\Heroes3.vid';
  CD_AUDIO_PATH  = CD_GAME_FOLDER + '\Data\Heroes3.snd';


type
  (* Import *)
  TAssocArray = DataLib.TAssocArray;

  TArcType  = (ARC_SND, ARC_VID);

  PArcItem  = ^TArcItem;
  TArcItem  = packed record
    Name:   array[0..39] of char; // for ARC_SND name is separated from extension with #0
    Offset: integer;
  end;

  PVidArcItem = PArcItem;
  TVidArcItem = TArcItem;

  PSndArcItem = ^TSndArcItem;
  TSndArcItem = packed record
    Item: TArcItem;
    Size: integer;
  end;

  PItemInfo = ^TItemInfo;
  TItemInfo = record
    hFile:  integer;
    Offset: integer;
    Size:   integer;
  end;

  PResourceBuf  = ^TResourceBuf;
  TResourceBuf  = packed record
    IsLoaded: boolean;
    _0:       array [0..2] of byte;
    Addr:     pointer;
  end;


var
  LoadCDOpt: boolean;

  GameCDFound:  boolean;
  GameCDPath:   string;


(* Returns true if non-redirected sound resource exists *)
function HasSoundReal (const FileName: string): boolean;

(* Returns true if non-redirected video resource exists *)
function HasVideoReal (const FileName: string): boolean;


(***) implementation (***)
uses Lodman;


var
{O} SndFiles: {O} TAssocArray {of PItemInfo};
{O} VidFiles: {O} TAssocArray {of PItemInfo};


function HasSoundReal (const FileName: string): boolean;
begin
  result := SndFiles[SysUtils.ChangeFileExt(FileName, '')] <> nil;
end;

function HasVideoReal (const FileName: string): boolean;
begin
  result := VidFiles[FileName] <> nil;
end;

procedure FindGameCD;
const
  MAX_NUM_DRIVES = 26;

var
  Drives:     integer;
  OldErrMode: integer;
  i:          integer;

begin
  OldErrMode  := Windows.SetErrorMode(Windows.SEM_FAILCRITICALERRORS);
  Drives      := Windows.GetLogicalDrives;
  GameCDPath  := 'A:\';
  GameCDFound := false;
  {!} Assert(Drives <> 0);

  i :=  0;

  while (i < MAX_NUM_DRIVES) and not GameCDFound do begin
    if (Drives and (1 shl i)) <> 0 then begin
      if Windows.GetDriveType(pchar(GameCDPath)) = Windows.DRIVE_CDROM then begin
        GameCDFound := SysUtils.DirectoryExists(GameCDPath + CD_GAME_FOLDER);
      end;
    end;

    if not GameCDFound then begin
      GameCDPath[1] :=  CHR(ORD(GameCDPath[1]) + 1);
    end;
    Inc(i);
  end; // .while

  Windows.SetErrorMode(OldErrMode);
end; // .procedure FindGameCD

procedure LoadArc (const ArcPath: string; ArcType: TArcType);
var
{U} ItemInfo: PItemInfo;
{U} ArcFiles: AssocArrays.TAssocArray {OF PItemInfo};
{U} CurrItem: PArcItem;
    hFile:    integer;

    NumItems: integer;
    ItemSize: integer;
    ItemName: string;

    BufSize:  integer;
    BufStr:   string;

    i:        integer;

begin
  ItemInfo := nil;
  ArcFiles := nil;
  CurrItem := nil;
  // * * * * * //
  if
    WinWrappers.FileOpen(ArcPath, SysUtils.fmOpenRead or SysUtils.fmShareDenyWrite, hFile)
  then begin
    case ArcType of
      ARC_VID: begin
        ItemSize := sizeof(TVidArcItem);
        ArcFiles := VidFiles;
      end;

      ARC_SND: begin
        ItemSize := sizeof(TSndArcItem);
        ArcFiles := SndFiles;
      end;
    else
      ItemSize := 0;
      {!} Assert(false);
    end;

    if (WinWrappers.FileRead(hFile, NumItems, sizeof(NumItems))) and (NumItems > 0) then begin
      BufSize := NumItems * ItemSize;
      SetLength(BufStr, BufSize);
      {!} Assert(WinWrappers.FileRead(hFile, BufStr[1], BufSize));
      CurrItem := pointer(BufStr);

      for i := 0 to NumItems - 1 do begin
        ItemName := pchar(@CurrItem.Name);

        if ArcFiles[ItemName] = nil then begin
          New(ItemInfo);
          ItemInfo.hFile  := hFile;
          ItemInfo.Offset := CurrItem.Offset;

          if ArcType = ARC_SND then begin
            ItemInfo.Size := PSndArcItem(CurrItem).Size;
          end;

          ArcFiles[ItemName] := ItemInfo; ItemInfo :=  nil;
        end; // .if

        CurrItem := Utils.PtrOfs(CurrItem, ItemSize);
      end; // .for
    end; // .if
  end; // .if
end; // .procedure LoadArc

function IsOrigArc (const FileName: string; ArcType: TArcType): boolean;
begin
  if ArcType = ARC_SND then begin
    result := (FileName = 'h3ab_ahd.snd') or (FileName = 'heroes3.snd');
  end else begin
    result := (FileName = 'h3ab_ahd.vid') or (FileName = 'video.vid') or (FileName = 'heroes3.vid');
  end;
end;

procedure LoadArcs (ArcType: TArcType);
var
{O} Locator:  Files.TFileLocator;
{O} FileInfo: Files.TFileItemInfo;
    ArcExt:   string;
    FileName: string;

begin
  Locator  := Files.TFileLocator.Create;
  FileInfo := nil;
  // * * * * * //
  if ArcType = ARC_VID then begin
    ArcExt := '.vid';
  end else if ArcType = ARC_SND then begin
    ArcExt := '.snd';
  end else begin
    ArcExt := '';
    {!} Assert(false);
  end;

  Locator.DirPath := 'Data';
  Locator.InitSearch('*' + ArcExt);

  while Locator.NotEnd do begin
    FileName := SysUtils.AnsiLowerCase(Locator.GetNextItem(Files.TItemInfo(FileInfo)));

    if
      (SysUtils.ExtractFileExt(FileName) = ArcExt)  and
      not FileInfo.IsDir                            and
      FileInfo.HasKnownSize                         and
      (FileInfo.FileSize > sizeof(integer))
    then begin
      if not IsOrigArc(FileName, ArcType) then begin
        LoadArc('Data\' + FileName, ArcType);
      end;
    end;

    SysUtils.FreeAndNil(FileInfo);
  end; // .while

  Locator.FinitSearch;
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
end; // .function Hook_LoadArcs

function Splice_LoadVideoHeaders (OrigFunc: pointer): boolean; stdcall;
begin
  (* Load New resources *)
  LoadArcs(ARC_VID);

  (* Load CD resources *)
  if SysUtils.FileExists(CD_VIDEO_PATH) then begin
    LoadArc(CD_VIDEO_PATH, ARC_VID);
  end else if LoadCDOpt and GameCDFound then begin
    LoadArc(GameCDPath + CD_VIDEO_PATH, ARC_VID);
  end;

  (* Load original rsources *)
  LoadArc('Data\video.vid', ARC_VID);
  LoadArc('Data\h3ab_ahd.vid', ARC_VID);

  result := true;
end;

function Splice_OpenSmack (OrigFunc: pointer; SmackFileName: pchar; BufSize, BufSizeMask: integer): {n} pointer; stdcall;
const
  SET_POSITION = 0;

var
{U} ItemInfo: PItemInfo;
    FileName: string;

begin
  ItemInfo := nil;
  // * * * * * //
  FileName := SmackFileName + '.smk';
  BufSize  := BufSize or BufSizeMask or $1140;

  Lodman.FindRedirection(FileName, FileName);
  ItemInfo := VidFiles[FileName];

  if ItemInfo <> nil then begin
    SysUtils.FileSeek(ItemInfo.hFile, ItemInfo.Offset, SET_POSITION);
    result := Heroes.Video.OpenSmack^(ItemInfo.hFile, BufSize, -1);
  end else begin
    result := nil;
  end;
end;

function Splice_OpenBik (OrigFunc: pointer; BinkFileName: pchar; BufSizeMask: integer): {n} pointer; stdcall;
const
  SET_POSITION = 0;

var
{U} ItemInfo: PItemInfo;
    FileName: string;

begin
  ItemInfo := nil;
  // * * * * * //
  FileName := BinkFileName + '.bik';

  Lodman.FindRedirection(FileName, FileName);
  ItemInfo := VidFiles[FileName];

  if ItemInfo <> nil then begin
    SysUtils.FileSeek(ItemInfo.hFile, ItemInfo.Offset, SET_POSITION);
    result := Heroes.Video.OpenBink^(ItemInfo.hFile, BufSizeMask or $8000000);
  end else begin
    result := nil;
  end;
end;

function Splice_LoadSndHeaders (OrigFunc: pointer): boolean; stdcall;
begin
  (* Load New resources *)
  LoadArcs(ARC_SND);

  (* Load CD resources *)
  if SysUtils.FileExists(CD_AUDIO_PATH) then begin
    LoadArc(CD_AUDIO_PATH, ARC_SND);
  end else if LoadCDOpt and GameCDFound then begin
    LoadArc(GameCDPath + CD_AUDIO_PATH, ARC_SND);
  end;

  (* Load original rsources *)
  LoadArc('Data\heroes3.snd', ARC_SND);
  LoadArc('Data\h3ab_ahd.snd', ARC_SND);

  result := true;
end;

function Splice_LoadWav (OrigFunc: pointer; WavFileName: pchar; ResourceBuf: PResourceBuf; out FileSize: integer): boolean; stdcall;
const
  SET_POSITION = 0;

var
{U} ItemInfo:     PItemInfo;
    BaseFileName: string;

begin
  ItemInfo := nil;
  // * * * * * //
  BaseFileName := StrLib.ExtractBaseFileName(WavFileName);

  if Lodman.FindRedirection(BaseFileName + '.wav', BaseFileName) then begin
    BaseFileName := SysUtils.ChangeFileExt(BaseFileName, '');
  end;

  ItemInfo := SndFiles[BaseFileName];

  if (ItemInfo <> nil) and (ItemInfo.Size > 0) then begin
    if ResourceBuf.IsLoaded then begin
      Heroes.MFree(ResourceBuf.Addr);
    end;

    ResourceBuf.Addr := Heroes.MAlloc(ItemInfo.Size);
    FileSize         := ItemInfo.Size;

    SysUtils.FileSeek(ItemInfo.hFile, ItemInfo.Offset, SET_POSITION);
    SysUtils.FileRead(ItemInfo.hFile, ResourceBuf.Addr^, ItemInfo.Size);

    result := true;
  end else begin
    result := false;
  end;
end;

procedure Splice_SavePointersToSndHandles (OrigFunc: pointer); stdcall;
begin
  // Dummy
end;

procedure OnLoadEraSettings (Event: PEvent); stdcall;
begin
  LoadCDOpt := EraSettings.GetOpt('LoadCD').Bool(false);
end;

procedure OnAfterWoG (Event: PEvent); stdcall;
begin
  (* Setup snd/vid hooks *)
  ApiJack.StdSplice(Ptr($598510), @Splice_LoadVideoHeaders, CONV_CDECL, 0);
  ApiJack.StdSplice(Ptr($598A90), @Splice_OpenSmack, CONV_FASTCALL, 3);
  ApiJack.StdSplice(Ptr($44D270), @Splice_OpenBik, CONV_FASTCALL, 2);
  ApiJack.StdSplice(Ptr($5987A0), @Splice_LoadSndHeaders, CONV_CDECL, 0);
  ApiJack.StdSplice(Ptr($55C340), @Splice_LoadWav, CONV_FASTCALL, 3);

  (* Disable CloseSndHandles function *)
  pbyte($4F3DFD)^    := $90;
  pinteger($4F3DFE)^ := integer($90909090);

  (* Disable SavePointersToSndHandles function *)
  ApiJack.StdSplice(Ptr($5594F0), @Splice_SavePointersToSndHandles, CONV_STDCALL, 0);

  (* Find game CD *)
  if LoadCDOpt then begin
    FindGameCD;
  end;

  (* Disable default CD scanning *)
  pinteger($50C409)^ := $0000B4E9;
  pword($50C40D)^    := $9000;
end; // .procedure OnAfterWoG

begin
  SndFiles := DataLib.NewAssocArray(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  VidFiles := DataLib.NewAssocArray(Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);

  EventMan.GetInstance.On('$OnLoadEraSettings', OnLoadEraSettings);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.
