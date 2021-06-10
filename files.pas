UNIT Files;
{
DESCRIPTION:  Implementations of virtual device with sequential access
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  INTERFACE  (***)
USES Windows, SysUtils, Math, WinWrappers, Utils, Log, CFiles;

CONST
  (* IMPORT *)
  MODE_OFF        = CFiles.MODE_OFF;
  MODE_READ       = CFiles.MODE_READ;
  MODE_WRITE      = CFiles.MODE_WRITE;
  MODE_READWRITE  = CFiles.MODE_READWRITE;
  
  (* Scan function settings *)
  faNotDirectory  = SysUtils.faAnyFile AND NOT SysUtils.faDirectory;
  ANY_EXT         = '';

TYPE
  (* IMPORT *)
  TDeviceMode = CFiles.TDeviceMode;
  TItemInfo   = CFiles.TItemInfo;
  
  TFixedBuf = CLASS (CFiles.TAbstractFile)
    (***) PROTECTED (***)
      {OUn} fBuf:     POINTER;
            fOwnsMem: BOOLEAN;
    
    (***) PUBLIC (***)
      DESTRUCTOR  Destroy; OVERRIDE;
      PROCEDURE Open ({n} Buf: POINTER; BufSize: INTEGER; DeviceMode: TDeviceMode);
      PROCEDURE Close;
      PROCEDURE CreateNew (BufSize: INTEGER);
      FUNCTION  ReadUpTo (Count: INTEGER; {n} Buf: POINTER; OUT BytesRead: INTEGER): BOOLEAN; OVERRIDE;
      FUNCTION  WriteUpTo (Count: INTEGER; {n} Buf: POINTER; OUT ByteWritten: INTEGER): BOOLEAN; OVERRIDE;
      FUNCTION  Seek (NewPos: INTEGER): BOOLEAN; OVERRIDE;
      
      PROPERTY  Buf:      POINTER READ fBuf;
      PROPERTY  OwnsMem:  BOOLEAN READ fOwnsMem;
  END; // .CLASS TFixedBuf
  
  TFile = CLASS (CFiles.TAbstractFile)
    (***) PROTECTED (***)
      fhFile:     INTEGER;
      fFilePath:  STRING;
      
    (***) PUBLIC (***)
      DESTRUCTOR  Destroy; OVERRIDE;
      FUNCTION  Open (CONST FilePath: STRING; DeviceMode: TDeviceMode): BOOLEAN;
      PROCEDURE Close;
      FUNCTION  CreateNew (CONST FilePath: STRING): BOOLEAN;
      FUNCTION  ReadUpTo (Count: INTEGER; {n} Buf: POINTER; OUT BytesRead: INTEGER): BOOLEAN; OVERRIDE;
      FUNCTION  WriteUpTo (Count: INTEGER; {n} Buf: POINTER; OUT ByteWritten: INTEGER): BOOLEAN; OVERRIDE;
      FUNCTION  Seek (NewPos: INTEGER): BOOLEAN; OVERRIDE;
      
      PROPERTY  hFile:    INTEGER READ fhFile;
      PROPERTY  FilePath: STRING READ fFilePath;
  END; // .CLASS TFile
  
  TFileItemInfo = CLASS (CFiles.TItemInfo)
    Data: Windows.TWin32FindData;
  END; // .CLASS TFileItemInfo
  
  TFileLocator  = CLASS (CFiles.TAbstractLocator)
    (***) PROTECTED (***)
      fOpened:        BOOLEAN;
      fSearchHandle:  INTEGER;
      fFindData:      Windows.TWin32FindData;
      fDirPath:       STRING;
      
    (***) PUBLIC (***)
      DESTRUCTOR  Destroy; OVERRIDE;
    
      PROCEDURE FinitSearch; OVERRIDE;
      PROCEDURE InitSearch (CONST Mask: STRING); OVERRIDE;
      FUNCTION  GetNextItem (OUT ItemInfo: TItemInfo): STRING; OVERRIDE;
      FUNCTION  GetItemInfo (CONST ItemName: STRING; OUT ItemInfo: TItemInfo): BOOLEAN; OVERRIDE;

      PROPERTY  DirPath:  STRING READ fDirPath WRITE fDirPath;
  END; // .CLASS TFileLocator
  
  TScanCallback = FUNCTION (VAR SearchRes: SysUtils.TSearchRec): BOOLEAN;


  (*  High level directory scanning
      Files are strictly matched against template with wildcards  *)
  
  PSearchRec  = ^SysUtils.TSearchRec;

  TSearchSubj = (ONLY_FILES, ONLY_DIRS, FILES_AND_DIRS);
  
  ILocator = INTERFACE
    PROCEDURE Locate (CONST MaskedPath: STRING; SearchSubj: TSearchSubj);
    FUNCTION  FindNext: BOOLEAN;
    PROCEDURE FindClose;
    FUNCTION  GetFoundName: STRING;
    FUNCTION  GetFoundRec:  {U} PSearchRec;
    
    PROPERTY FoundName: STRING READ GetFoundName;
    PROPERTY FoundRec:  PSearchRec READ GetFoundRec;
  END; // .INTERFACE ILocator


FUNCTION  ReadFileContents (CONST FilePath: STRING; OUT FileContents: STRING): BOOLEAN;
FUNCTION  WriteFileContents (CONST FileContents, FilePath: STRING): BOOLEAN;
FUNCTION  DeleteDir (CONST DirPath: STRING): BOOLEAN;
FUNCTION  GetFileSize (CONST FilePath: STRING; OUT Res: INTEGER): BOOLEAN;
FUNCTION  Scan
(
  CONST FileMask:         STRING;
        AdditionalAttrs:  INTEGER;
  CONST FileLowCaseExt:   STRING;
        Callback:         TScanCallback
): BOOLEAN;

FUNCTION  DirExists (CONST FilePath: STRING): BOOLEAN;
FUNCTION  Locate (CONST MaskedPath: STRING; SearchSubj: TSearchSubj): ILocator;
  

(***) IMPLEMENTATION (***)
USES StrLib;

CONST
  FILES_EXTRA_DEBUG = FALSE;


TYPE
  TLocator  = CLASS (TInterfacedObject, ILocator)
    PROTECTED
      fLastOperRes:   BOOLEAN;
      fSearchStarted: BOOLEAN;
      fDir:           STRING;
      fFileMask:      STRING;
      fSearchSubj:    TSearchSubj;
      fFoundRec:      SysUtils.TSearchRec;
      
      FUNCTION  MatchResult: BOOLEAN;
    
    PUBLIC
      CONSTRUCTOR Create;
      DESTRUCTOR  Destroy; OVERRIDE;
    
      PROCEDURE Locate (CONST MaskedPath: STRING; SearchSubj: TSearchSubj);
      FUNCTION  FindNext: BOOLEAN;
      PROCEDURE FindClose;
      FUNCTION  GetFoundName: STRING;
      FUNCTION  GetFoundRec:  {U} PSearchRec;
  END; // .CLASS TLocator


DESTRUCTOR TFixedBuf.Destroy;
BEGIN
  Self.Close;
END; // .DESTRUCTOR TFixedBuf.Destroy

PROCEDURE TFixedBuf.Open ({n} Buf: POINTER; BufSize: INTEGER; DeviceMode: TDeviceMode);
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Buf, BufSize));
  {!} ASSERT(DeviceMode <> MODE_OFF);
  Self.Close;
  Self.fMode          :=  DeviceMode;
  Self.fHasKnownSize  :=  TRUE;
  Self.fSizeIsConst   :=  TRUE;
  Self.fSize          :=  BufSize;
  Self.fPos           :=  0;
  Self.fEOF           :=  BufSize = 0;
  Self.fBuf           :=  Buf;
  Self.fOwnsMem       :=  FALSE;
END; // .PROCEDURE TFixedBuf.Open

PROCEDURE TFixedBuf.Close;
BEGIN
  IF (Self.fMode <> MODE_OFF) AND Self.OwnsMem THEN BEGIN
    FreeMem(Self.fBuf); Self.fBuf :=  NIL;
  END; // .IF
  Self.fMode  :=  MODE_OFF;
END; // .PROCEDURE TFixedBuf.Close

PROCEDURE TFixedBuf.CreateNew (BufSize: INTEGER);
VAR
(* On *)  NewBuf: POINTER;
  
BEGIN
  {!} ASSERT(BufSize >= 0);
  NewBuf  :=  NIL;
  // * * * * * //
  IF BufSize > 0 THEN BEGIN
    GetMem(NewBuf, BufSize);
  END; // .IF
  Self.Open(NewBuf, BufSize, MODE_READWRITE); NewBuf  :=  NIL;
  Self.fOwnsMem :=  TRUE;
END; // .PROCEDURE TFixedBuf.CreateNew

FUNCTION TFixedBuf.ReadUpTo (Count: INTEGER; {n} Buf: POINTER; OUT BytesRead: INTEGER): BOOLEAN;
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Buf, Count));
  RESULT  :=  ((Self.Mode = MODE_READ) OR (Self.Mode = MODE_READWRITE)) AND (NOT Self.EOF) AND (Count > 0);
  IF RESULT THEN BEGIN
    BytesRead :=  Math.Min(Count, Self.Size - Self.Pos);
    Utils.CopyMem(BytesRead, Utils.PtrOfs(Self.Buf, Self.Pos), Buf);
    Self.fPos :=  Self.Pos + BytesRead;
    Self.fEOF :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFixedBuf.ReadUpTo

FUNCTION TFixedBuf.WriteUpTo (Count: INTEGER; {n} Buf: POINTER; OUT ByteWritten: INTEGER): BOOLEAN;
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Buf, Count));
  RESULT  :=  ((Self.Mode = MODE_WRITE) OR (Self.Mode = MODE_READWRITE)) AND (NOT Self.EOF);
  IF RESULT THEN BEGIN
    ByteWritten :=  Math.Min(Count, Self.Size - Self.Pos);
    Utils.CopyMem(ByteWritten, Buf, Utils.PtrOfs(Self.Buf, Self.Pos));
    Self.fPos :=  Self.Pos + ByteWritten;
    Self.fEOF :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFixedBuf.WriteUpTo

FUNCTION TFixedBuf.Seek (NewPos: INTEGER): BOOLEAN;
BEGIN
  {!} ASSERT(NewPos >= 0);
  RESULT  :=  (Self.Mode <> MODE_OFF) AND (NewPos <= Self.Size);
  IF RESULT THEN BEGIN
    Self.fPos :=  NewPos;
    Self.fEOF :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFixedBuf.Seek

DESTRUCTOR TFile.Destroy;
BEGIN
  Self.Close;
END; // .DESTRUCTOR TFile.Destroy

FUNCTION TFile.Open (CONST FilePath: STRING; DeviceMode: TDeviceMode): BOOLEAN;
VAR
  OpeningMode:  INTEGER;
  FileSizeL:    INTEGER;
  FileSizeH:    INTEGER;

BEGIN
  {!} ASSERT(DeviceMode <> MODE_OFF);
  Self.Close;
  Self.fhFile :=  WinWrappers.INVALID_HANDLE;
  CASE DeviceMode OF 
    MODE_READ:      OpeningMode :=  SysUtils.fmOpenRead OR SysUtils.fmShareDenyWrite;
    MODE_WRITE:     OpeningMode :=  SysUtils.fmOpenWrite OR SysUtils.fmShareExclusive;
    MODE_READWRITE: OpeningMode :=  SysUtils.fmOpenReadWrite OR SysUtils.fmShareExclusive;
  ELSE
    OpeningMode :=  0;
  END; // .SWITCH
  RESULT  :=  WinWrappers.FileOpen(FilePath, OpeningMode, Self.fhFile);
  IF NOT RESULT THEN BEGIN
    Log.Write('FileSystem', 'OpenFile', 'Cannot open file "' + FilePath + '"');
  END // .IF
  ELSE BEGIN
    RESULT  :=  WinWrappers.GetFileSize(Self.hFile, FileSizeL, FileSizeH);
    IF NOT RESULT THEN BEGIN
      Log.Write('FileSystem', 'GetFileSize', 'Cannot get size of file "' + FilePath + '"');
    END; // .IF
  END; // .ELSE
  IF RESULT THEN BEGIN
    RESULT  :=  FileSizeH = 0;
    IF NOT RESULT THEN BEGIN
      Log.Write
      (
        'FileSystem',
        'OpenFile',
        'Size of file "' + FilePath +'" exceeds 2 GB = ' + SysUtils.IntToStr(INT64(FileSizeH) * $FFFFFFFF + FileSizeL)
      );
    END // .IF
    ELSE BEGIN
      Self.fMode          :=  DeviceMode;
      Self.fSize          :=  FileSizeL;
      Self.fPos           :=  0;
      Self.fEOF           :=  Self.Pos = Self.Size;
      Self.fFilePath      :=  FilePath;
      Self.fHasKnownSize  :=  TRUE;
      Self.fSizeIsConst   :=  FALSE;
    END; // .ELSE
  END; // .IF
  // * * * * * //
  IF (NOT RESULT) AND (Self.hFile <> WinWrappers.INVALID_HANDLE) THEN BEGIN
    Windows.CloseHandle(Self.hFile);
  END; // .IF
END; // .FUNCTION TFile.Open

PROCEDURE TFile.Close;
BEGIN
  IF (Self.Mode <> MODE_OFF) AND (NOT Windows.CloseHandle(Self.hFile)) THEN BEGIN
    Log.Write('FileSystem', 'CloseFile', 'Cannot close file "' + Self.FilePath + '"');
  END; // .IF;
  Self.fMode      :=  MODE_OFF;
  Self.fFilePath  :=  '';
END; // .PROCEDURE TFile.Close

FUNCTION TFile.CreateNew (CONST FilePath: STRING): BOOLEAN;
BEGIN
  Self.Close;
  RESULT  :=  WinWrappers.FileCreate(FilePath, Self.fhFile);
  IF NOT RESULT THEN BEGIN
    Log.Write('FileSystem', 'CloseFile', 'Cannot close file "' + Self.FilePath + '"');
  END // .IF
  ELSE BEGIN
    Self.fMode          :=  MODE_READWRITE;
    Self.fSize          :=  0;
    Self.fPos           :=  0;
    Self.fEOF           :=  TRUE;
    Self.fFilePath      :=  FilePath;
    Self.fHasKnownSize  :=  TRUE;
    Self.fSizeIsConst   :=  FALSE;
  END; // .ELSE
END; // .FUNCTION TFile.CreateNew

FUNCTION TFile.ReadUpTo (Count: INTEGER; {n} Buf: POINTER; OUT BytesRead: INTEGER): BOOLEAN;
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Buf, Count));
  RESULT  :=  ((Self.Mode = MODE_READ) OR (Self.Mode = MODE_READWRITE)) AND (NOT Self.EOF);
  IF RESULT THEN BEGIN
    BytesRead :=  SysUtils.FileRead(Self.hFile, Buf^, Count);
    RESULT    :=  BytesRead > 0;
    IF NOT RESULT THEN BEGIN
      Log.Write('FileSystem', 'ReadFile', 'Cannot read file "' + Self.FilePath + '" at offset ' + SysUtils.IntToStr(Self.Pos));
    END; // .IF
    Self.fPos :=  Self.Pos + BytesRead;
    Self.fEOF :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFile.ReadUpTo

FUNCTION TFile.WriteUpTo (Count: INTEGER; {n} Buf: POINTER; OUT ByteWritten: INTEGER): BOOLEAN;
BEGIN
  {!} ASSERT(Utils.IsValidBuf(Buf, Count));
  RESULT  :=  (Self.Mode = MODE_WRITE) OR (Self.Mode = MODE_READWRITE);
  IF RESULT THEN BEGIN
    ByteWritten :=  SysUtils.FileWrite(Self.hFile, Buf^, Count);
    RESULT      :=  ByteWritten > 0;
    IF NOT RESULT THEN BEGIN
      Log.Write('FileSystem', 'WriteFile', 'Cannot write file "' + Self.FilePath + '" at offset ' + SysUtils.IntToStr(Self.Pos));
    END; // .IF
    Self.fPos   :=  Self.Pos + ByteWritten;
    Self.fSize  :=  Self.Size + ByteWritten;
    Self.fEOF   :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFile.WriteUpTo

FUNCTION TFile.Seek (NewPos: INTEGER): BOOLEAN;
VAR
  SeekRes:  INTEGER;

BEGIN
  {!} ASSERT(NewPos >= 0);
  RESULT  :=  Self.Mode <> MODE_OFF;
  IF RESULT THEN BEGIN
    SeekRes :=  SysUtils.FileSeek(Self.hFile, NewPos, 0);
    RESULT  :=  SeekRes <> -1;
    IF RESULT THEN BEGIN
      Self.fPos :=  SeekRes;
      RESULT    :=  SeekRes = NewPos;
    END; // .IF
    IF NOT RESULT THEN BEGIN
      Log.Write('FileSystem', 'SeekFile', 'Cannot set file "' + Self.FilePath + '" pointer to ' + SysUtils.IntToStr(NewPos));
    END; // .IF
    Self.fEOF :=  Self.Pos = Self.Size;
  END; // .IF
END; // .FUNCTION TFile.Seek

PROCEDURE TFileLocator.FinitSearch;
BEGIN
  IF Self.fOpened THEN BEGIN
    Windows.FindClose(Self.fSearchHandle);
    Self.fOpened  :=  FALSE;
  END; // .IF
END; // .PROCEDURE TFileLocator.FinitSearch

PROCEDURE TFileLocator.InitSearch (CONST Mask: STRING);
BEGIN
  Self.FinitSearch;
  Self.fSearchMask  :=  Mask;
  Self.fOpened      :=  WinWrappers.FindFirstFile(Self.DirPath + '\' + Mask, Self.fSearchHandle, Self.fFindData);
  Self.fNotEnd      :=  Self.fOpened;
END; // .PROCEDURE TFileLocator.InitSearch

FUNCTION TFileLocator.GetNextItem (OUT ItemInfo: TItemInfo): STRING;
VAR
(* O *) FileInfo: TFileItemInfo;

BEGIN
  {!} ASSERT(Self.NotEnd);
  {!} ASSERT(ItemInfo = NIL);
  FileInfo  :=  TFileItemInfo.Create;
  // * * * * * //
  FileInfo.IsDir  :=  (Self.fFindData.dwFileAttributes AND Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0;
  IF NOT FileInfo.IsDir AND (Self.fFindData.nFileSizeHigh = 0) AND (Self.fFindData.nFileSizeLow < $7FFFFFFF) THEN BEGIN
    FileInfo.HasKnownSize :=  TRUE;
    FileInfo.FileSize     :=  Self.fFindData.nFileSizeLow;
  END; // .IF
  FileInfo.Data :=  Self.fFindData;
  ItemInfo      :=  FileInfo; FileInfo  :=  NIL;
  RESULT        :=  Self.fFindData.cFileName;
  Self.fNotEnd  :=  WinWrappers.FindNextFile(Self.fSearchHandle, Self.fFindData);
END; // .FUNCTION TFileLocator.GetNextItem

DESTRUCTOR TFileLocator.Destroy;
BEGIN
  Self.FinitSearch;
END; // .DESTRUCTOR Destroy

FUNCTION TFileLocator.GetItemInfo (CONST ItemName: STRING; OUT ItemInfo: TItemInfo): BOOLEAN;
VAR
(* O *) Locator:  TFileLocator;
        ItemPath: STRING;

BEGIN
  {!} ASSERT(ItemInfo = NIL);
  Locator :=  TFileLocator.Create;
  // * * * * * //
  ItemPath  :=  Self.DirPath + '\' + ItemName;
  RESULT    :=  SysUtils.FileExists(ItemPath);
  IF RESULT THEN BEGIN
    Locator.InitSearch(ItemPath);
    IF Locator.NotEnd THEN BEGIN
      Locator.GetNextItem(ItemInfo);
    END; // .IF
  END; // .IF
  SysUtils.FreeAndNil(Locator);
END; // .FUNCTION TFileLocator.GetItemInfo

FUNCTION ReadFileContents (CONST FilePath: STRING; OUT FileContents: STRING): BOOLEAN;
VAR
{O} MyFile: TFile;

BEGIN
  MyFile  :=  TFile.Create;
  // * * * * * //
  RESULT  :=
    MyFile.Open(FilePath, MODE_READ)  AND
    MyFile.ReadAllToStr(FileContents);
  // * * * * * //
  SysUtils.FreeAndNil(MyFile);
END; // .FUNCTION ReadFileContents

FUNCTION WriteFileContents (CONST FileContents, FilePath: STRING): BOOLEAN;
VAR
{O} MyFile: TFile;

BEGIN
  MyFile  :=  TFile.Create;
  // * * * * * //
  RESULT  :=
    MyFile.CreateNew(FilePath)  AND
    MyFile.WriteStr(FileContents);
  // * * * * * //
  SysUtils.FreeAndNil(MyFile);
END; // .FUNCTION WriteFileContents

FUNCTION DeleteDir (CONST DirPath: STRING): BOOLEAN;
VAR
{O} Locator:  TFileLocator;
{O} FileInfo: TFileItemInfo;
    FileName: STRING;
    FilePath: STRING;

BEGIN
  Locator   :=  TFileLocator.Create;
  FileInfo  :=  NIL;
  // * * * * * //
  RESULT          :=  TRUE;
  Locator.DirPath :=  DirPath;
  Locator.InitSearch('*');
  WHILE RESULT AND Locator.NotEnd DO BEGIN
    FileName  :=  Locator.GetNextItem(CFiles.TItemInfo(FileInfo));
    IF (FileName <> '.') AND (FileName <> '..') THEN BEGIN
      FilePath  :=  DirPath + '\' + FileName;
      IF (FileInfo.Data.dwFileAttributes AND Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0 THEN BEGIN
        RESULT  :=  DeleteDir(FilePath);
      END // .IF
      ELSE BEGIN
        RESULT  :=  SysUtils.DeleteFile(FilePath);
      END; // .ELSE
    END; // .IF
    SysUtils.FreeAndNil(FileInfo);
  END; // .WHILE
  Locator.FinitSearch;
  RESULT  :=  RESULT AND SysUtils.RemoveDir(DirPath);
  // * * * * * //
  SysUtils.FreeAndNil(Locator);
END; // .FUNCTION DeleteDir

FUNCTION GetFileSize (CONST FilePath: STRING; OUT Res: INTEGER): BOOLEAN;
VAR
{O} MyFile: TFile;

BEGIN
  MyFile  :=  TFile.Create;
  // * * * * * //
  RESULT  :=  MyFile.Open(FilePath, MODE_READ) AND MyFile.HasKnownSize;
  IF RESULT THEN BEGIN
    Res :=  MyFile.Size;
  END; // .IF
  // * * * * * //
  SysUtils.FreeAndNil(MyFile);
END; // .FUNCTION GetFileSize

FUNCTION Scan
(
  CONST FileMask:         STRING;
        AdditionalAttrs:  INTEGER;
  CONST FileLowCaseExt:   STRING;
        Callback:         TScanCallback
): BOOLEAN;

VAR
  SearchRec:  SysUtils.TSearchRec;

BEGIN
  RESULT  :=  TRUE;

  IF SysUtils.FindFirst(FileMask, AdditionalAttrs, SearchRec) = 0 THEN BEGIN
    REPEAT
      IF
        (FileLowCaseExt = ANY_EXT) OR
        (SysUtils.ExtractFileExt(SysUtils.AnsiLowerCase(SearchRec.Name)) = FileLowCaseExt)
      THEN BEGIN
        RESULT  :=  Callback(SearchRec);
      END; // .IF
    UNTIL SysUtils.FindNext(SearchRec) <> 0;
    
    SysUtils.FindClose(SearchRec);
  END; // .IF
END; // .FUNCTION Scan

FUNCTION DirExists (CONST FilePath: STRING): BOOLEAN;
VAR
  Attrs:  INTEGER;

BEGIN
  Attrs   :=  Windows.GetFileAttributes(PCHAR(FilePath));
  RESULT  :=  (Attrs <> - 1) AND ((Attrs AND Windows.FILE_ATTRIBUTE_DIRECTORY) <> 0);
END; // .FUNCTION DirExists

CONSTRUCTOR TLocator.Create;
BEGIN
  INHERITED;
  Self.fLastOperRes :=  TRUE;
END; // .CONSTRUCTOR TLocator.Create

DESTRUCTOR TLocator.Destroy;
BEGIN
  Self.FindClose;
  INHERITED;
END; // .DESTRUCTOR TLocator.Destroy

PROCEDURE TLocator.FindClose;
BEGIN
  IF Self.fSearchStarted THEN BEGIN
    SysUtils.FindClose(Self.fFoundRec);
    Self.fSearchStarted :=  FALSE;
  END; // .IF
END; // .PROCEDURE TLocator.FindClose

FUNCTION TLocator.MatchResult: BOOLEAN;
  FUNCTION CanonicMask (CONST Mask: STRING): STRING;
  VAR
    i: INTEGER;
  
  BEGIN
    RESULT := Mask;
    i := LENGTH(RESULT);
    
    WHILE ((i > 0) AND (RESULT[i] = '*')) DO BEGIN
      DEC(i);
    END; // .WHILE
  
    IF (i > 0) AND (RESULT[i] <> '.') THEN BEGIN
      RESULT := RESULT + '.';
    END; // .IF
  END; // .FUNCTION CanonicMask
  
  FUNCTION CanonicName (CONST Name: STRING): STRING;
  BEGIN
    RESULT := Name;
  
    IF (RESULT <> '') AND (RESULT[LENGTH(RESULT)] <> '.') THEN BEGIN
      RESULT := RESULT + '.';
    END; // .IF
  END; // .FUNCTION CanonicName

BEGIN
  {!} ASSERT(Self.fSearchStarted AND Self.fLastOperRes);
  RESULT  :=  FALSE;
  
  CASE Self.fSearchSubj OF 
    ONLY_FILES:     RESULT  :=  (Self.fFoundRec.Attr AND SysUtils.faDirectory) = 0;
    ONLY_DIRS:      RESULT  :=  (Self.fFoundRec.Attr AND SysUtils.faDirectory) <> 0;
    FILES_AND_DIRS: RESULT  :=  TRUE;
  ELSE
    {!} ASSERT(FALSE);
  END; // .SWITCH 
  
  RESULT  :=  RESULT AND StrLib.Match(CanonicName(SysUtils.AnsiLowercase(Self.fFoundRec.Name)),
                                      CanonicMask(SysUtils.AnsiLowerCase(Self.fFileMask)));
  
  IF FILES_EXTRA_DEBUG THEN BEGIN
    Log.Write('Files', 'TLocator.MatchResult', 'Match "' + Self.fFoundRec.Name + '" to "' +
                                               Self.fFileMask + '" is ' + IntToStr(ORD(RESULT)));
  END; // .IF
END; // .FUNCTION TLocator.MatchResult

FUNCTION TLocator.FindNext: BOOLEAN;
BEGIN
  {!} ASSERT(Self.fLastOperRes);
  RESULT  :=  FALSE;
  
  IF NOT Self.fSearchStarted THEN BEGIN
    Self.fLastOperRes :=
      SysUtils.FindFirst(Self.fDir + '\*', SysUtils.faAnyFile, Self.fFoundRec) = 0;
    
    Self.fSearchStarted :=  Self.fLastOperRes;
    RESULT              :=  Self.fSearchStarted AND Self.MatchResult;
  END; // .IF

  IF NOT RESULT AND Self.fSearchStarted THEN BEGIN
    WHILE NOT RESULT AND (SysUtils.FindNext(Self.fFoundRec) = 0) DO BEGIN
      RESULT  :=  Self.MatchResult;
    END; // .WHILE
    
    Self.fLastOperRes :=  RESULT;
  END; // .IF
END; // .FUNCTION TLocator.FindNext

PROCEDURE TLocator.Locate (CONST MaskedPath: STRING; SearchSubj: TSearchSubj);
BEGIN
  Self.fDir         :=  SysUtils.ExtractFileDir(MaskedPath);
  Self.fFileMask    :=  SysUtils.ExtractFileName(MaskedPath);
  Self.fSearchSubj  :=  SearchSubj;
END; // .PROCEDURE TLocator.Locate

FUNCTION TLocator.GetFoundName: STRING;
BEGIN
  {!} ASSERT(Self.fSearchStarted AND Self.fLastOperRes);
  RESULT  :=  Self.fFoundRec.Name;
END; // .FUNCTION TLocator.GetFoundName

FUNCTION TLocator.GetFoundRec: {U} PSearchRec;
BEGIN
  {!} ASSERT(Self.fSearchStarted AND Self.fLastOperRes);
  RESULT  :=  @Self.fFoundRec;
END; // .FUNCTION TLocator.GetFoundRec

FUNCTION Locate (CONST MaskedPath: STRING; SearchSubj: TSearchSubj): ILocator;
VAR
{O} Locator:  TLocator;

BEGIN
  Locator :=  TLocator.Create;
  // * * * * * //
  Locator.Locate(MaskedPath, SearchSubj);
  RESULT  :=  Locator; Locator  :=  NIL;
END; // .FUNCTION Locate

END.
