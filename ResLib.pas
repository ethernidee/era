unit ResLib;
(*
  Library for game resources management, particulary storing them in shared memory, reference counting,
  caching support.

  TODO: rescan resource time to time to alove live reloading?
  TODO: export flush cache function?
*)


(***)  interface  (***)

uses
  SysUtils,
  Utils,

  DataLib,
  StrLib;

type
  (* Import *)
  TDict = DataLib.TDict;

  TSharedResource = class;

  TResQueueItem = class
    {U}  Resource: TSharedResource;
    {OU} PrevItem: TResQueueItem;
    {OU} NextItem: TResQueueItem;

    public
     constructor Create (Resource: TSharedResource);
  end;

  TResourceManager = class
   protected
   {O}  fResourceMap:   TDict {of TResQueueItem}; // Used to track all loaded resources by relative path.
   {On} fResQueueStart: TResQueueItem;            // Resource queue is used to eliminate last recently used items without users.
   {On} fResQueueEnd:   TResQueueItem;
        fTotalSize:     integer;                  // Total size of all cached resources.
        fMaxTotalSize:  integer;                  // Maximum desired size of all cached resources. Real total size may exceed this value
                                                  // If each resource has RefCount > 1.

    procedure RemoveItemFromResQueue (ResQueueItem: TResQueueItem);
    procedure PrependItemToResQueue (ResQueueItem: TResQueueItem);
    procedure MoveResQueueItemToStart (ResQueueItem: TResQueueItem);
    procedure RemoveResource (const Source: string);
    procedure CollectGarbage;

   public
    constructor Create (MaxTotalSize: integer);
    destructor Destroy; override;

    function AddResource (Data: TObject; Size: integer; const Source: string): TSharedResource;
    function GetResource (const Source: string): {n} TSharedResource;

    property Resources[const ResourceSource: string]: {n} TSharedResource read GetResource;
  end; // .class TResourceManager

  (*
    Shared resource. Uses refcounting. Do not call destructor manually. Use IncRef/DecRef only.
    Do no use resource after calling DecRef;
  *)
  TSharedResource = class
   protected
    {U} fManager:  TResourceManager; // Resource manager.
    {O} fData:     TObject;          // Resource underlying data.
    fSize:         integer;          // Estimated resource size in memory in bytes.
    fRefCount:     integer;          // Number of resource users.
    fSource:       string;           // Always normalized and validated relative file path.

    constructor CreateAndBind (Manager: TResourceManager; Data: TObject; Size: integer; const Source: string);

   public
    constructor Create;
    destructor Destroy; override;

    procedure IncRef;
    procedure DecRef;

    property Data:     TObject read fData;
    property Size:     integer read fSize;
    property RefCount: integer read fRefCount;
    property Source:   string  read fSource;
  end; // .class TSharedResource


(***)  implementation  (***)


function IsValidResourceSource (const Source: string): boolean;
var
  FoundPos: integer;

begin
  result := (Source <> '') and (Source <> '.') and ((Length(Source) < 2) or ((Source[1] <> '/') and (Source[1] <> '\') and (Source[2] <> '/') and (Source[2] <> '\'))) and
            (System.Pos('..', Source) = 0) and not StrLib.FindCharset([#0, ':'], Source, FoundPos);
end;

constructor TSharedResource.CreateAndBind (Manager: TResourceManager; Data: TObject; Size: integer; const Source: string);
begin
  {!} Assert(Manager <> nil);
  {!} Assert(Data <> nil);
  {!} Assert(Size > 0, 'Resource size cannot be negative. Given: ' + SysUtils.IntToStr(Size));
  {!} Assert(IsValidResourceSource(Source));

  inherited Create;

  Self.fManager  := Manager;
  Self.fData     := Data;
  Self.fSize     := Size;
  Self.fRefCount := 1;
  Self.fSource   := Source;
end;

constructor TSharedResource.Create;
begin
  raise Exception.Create('TSharedResource cannot be called directly. Use TResourceManager.AddResource instead');
end;

destructor TSharedResource.Destroy;
begin
  {!} Assert(Self.fRefCount = 0, 'Cannot destroy resource with ' + SysUtils.IntToStr(Self.fRefCount) + ' references left');
end;

procedure TSharedResource.IncRef;
begin
  {!} Assert(Self.fRefCount > 0, 'TSharedResource cannot be used after free');
  Inc(Self.fRefCount);
end;

procedure TSharedResource.DecRef;
begin
  {!} Assert(Self.fRefCount > 0, 'TSharedResource cannot be used after free');
  Dec(Self.fRefCount);

  if Self.fRefCount = 0 then begin
    Self.fManager.RemoveResource(Self.Source);

    inherited Destroy;
  end;
end;

constructor TResQueueItem.Create (Resource: TSharedResource);
begin
  {!} Assert(Resource <> nil);
  Self.Resource := Resource;
end;

constructor TResourceManager.Create (MaxTotalSize: integer);
begin
  Self.fResourceMap   := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  Self.fResQueueStart := nil;
  Self.fResQueueEnd   := nil;
  Self.fTotalSize     := 0;
  Self.fMaxTotalSize  := MaxTotalSize;
end;

destructor TResourceManager.Destroy;
var
  CurrItem: TResQueueItem;

begin
  SysUtils.FreeAndNil(Self.fResourceMap);

  CurrItem := Self.fResQueueStart;

  while CurrItem <> nil do begin
    CurrItem.Resource.DecRef;
    CurrItem := CurrItem.NextItem;
  end;
end;

procedure TResourceManager.RemoveItemFromResQueue (ResQueueItem: TResQueueItem);
begin
  {!} Assert(ResQueueItem <> nil);

  if ResQueueItem.NextItem <> nil then begin
    ResQueueItem.NextItem.PrevItem := ResQueueItem.PrevItem;
  end else begin
    Self.fResQueueEnd := ResQueueItem.PrevItem;
  end;

  if ResQueueItem.PrevItem <> nil then begin
    ResQueueItem.PrevItem.PrevItem := ResQueueItem.NextItem;
  end else begin
    Self.fResQueueStart := ResQueueItem.NextItem;
  end;
end;

procedure TResourceManager.PrependItemToResQueue (ResQueueItem: TResQueueItem);
begin
  {!} Assert(ResQueueItem <> nil);

  if Self.fResQueueStart <> nil then begin
    ResQueueItem.PrevItem        := nil;
    ResQueueItem.NextItem        := Self.fResQueueStart;
    Self.fResQueueStart.PrevItem := ResQueueItem;
  end else begin
    Self.fResQueueStart := ResQueueItem;
    Self.fResQueueEnd   := ResQueueItem;
  end;
end;

procedure TResourceManager.MoveResQueueItemToStart (ResQueueItem: TResQueueItem);
begin
  {!} Assert(ResQueueItem <> nil);

  Self.RemoveItemFromResQueue(ResQueueItem);
  Self.PrependItemToResQueue(ResQueueItem);
end;

procedure TResourceManager.RemoveResource (const Source: string);
var
{Un} ResQueueItem: TResQueueItem;

begin
  ResQueueItem := Self.fResourceMap[Source];

  if ResQueueItem <> nil then begin
    Dec(Self.fTotalSize, ResQueueItem.Resource.Size);
    Self.fResourceMap.DeleteItem(Source);
    Self.RemoveItemFromResQueue(ResQueueItem);
    SysUtils.FreeAndNil(ResQueueItem);
  end;
end;

procedure TResourceManager.CollectGarbage;
var
{U} SavedQueueStart:   TResQueueItem;
{U} CurrItem:          TResQueueItem;
{U} PrevProcessedItem: TResQueueItem;
{U} NextItemToProcess: TResQueueItem;

begin
  if Self.fTotalSize > Self.fMaxTotalSize then begin
    {!} Assert(Self.fResQueueStart <> nil);

    SavedQueueStart   := Self.fResQueueStart;
    CurrItem          := Self.fResQueueEnd;
    PrevProcessedItem := nil;

    while (Self.fTotalSize > Self.fMaxTotalSize) and (PrevProcessedItem <> SavedQueueStart) do begin
      PrevProcessedItem := CurrItem;

      if CurrItem.Resource.RefCount = 1 then begin
        Dec(Self.fTotalSize, CurrItem.Resource.Size);
        CurrItem.Resource.DecRef;

        NextItemToProcess := CurrItem.PrevItem;
        Self.RemoveItemFromResQueue(CurrItem);
        SysUtils.FreeAndNil(CurrItem);
        CurrItem          := NextItemToProcess;
      end else begin
        NextItemToProcess := CurrItem.PrevItem;
        Self.MoveResQueueItemToStart(CurrItem);
        CurrItem          := NextItemToProcess;
      end; // .else
    end; // .while
  end; // .if
end; // .procedure CollectGarbage

function TResourceManager.AddResource (Data: TObject; Size: integer; const Source: string): TSharedResource;
var
{U} Resource:     TSharedResource;
{U} ResQueueItem: TResQueueItem;

begin
  {!} Assert(Self.fResourceMap[Source] = nil, 'Cannot register resource "' + Source + '" twice');

  Resource                  := TSharedResource.CreateAndBind(Self, Data, Size, Source);
  ResQueueItem              := TResQueueItem.Create(Resource);
  Self.fResourceMap[Source] := ResQueueItem;
  Self.PrependItemToResQueue(ResQueueItem);
  Inc(Self.fTotalSize, Size);

  if Self.fMaxTotalSize > 0 then begin
    Resource.IncRef;
    Self.CollectGarbage;
  end;

  result := Resource;
end;

function TResourceManager.GetResource (const Source: string): {n} TSharedResource;
var
{U} ResQueueItem: TResQueueItem;

begin
  result       := nil;
  ResQueueItem := Self.fResourceMap[Source];

  if ResQueueItem <> nil then begin
    Self.MoveResQueueItemToStart(ResQueueItem);
    result := ResQueueItem.Resource;
  end;
end;

// Img := LoadFileFromPac(FileName);
// Resource := TResource.Create(Img, Img.Size);
// Resource := TResource.Create(Img, Img.Width * Img.Height * RGBA_BYTES_PER_PIXEL);
// Resource := NewPngResource(Img, Img.Size);

// LoadPng => automatically

// Cache.AddItem(FileName, Resource); // if added to cache, IncRef called automatically
// ...
// Resource.DecRef;

// function LoadPng (FilePath: string): {O} TResource;
// var
//   FileData: string;
//   PngImage: TPngImage;

// begin
//   result := RawImageCache.GetItem(FilePath);

//   if result <> nil then begin
//     if result.Data instanceof TPngImage then begin
//       result.IncRef;

//       exit;
//     end else begin
//       result := MakeDefPngImage();

//       exit;
//     end;
//   end;

//   FileResource := FileCache.GetItem(FilePath);

//   if FileResource <> nil then begin
//     FileResource.IncRef;
//   end else if if not LoadFileFromZip(FilePath, FileData) then begin
//     result := MakeDefPngImage();

//     exit;
//   end else begin
//     FileResource := TResource.Create(TString.Create(FileData), Length(FileData));
//     FileCache.AddItem(FileResource);
//   end;

//   try
//     Stream   := TStringStream.Create(FileData);
//     PngImage := TPngImage.LoadFromStream(Stream);
//   except
//     FreeAndNil(PngImage);

//     result := MakeDefPngImage();

//     exit;
//   finally
//     if Stream then
//       FreeAndNil(Stream);
//   end;

//   FileResource.DecRef; // call later?

//   result := TResource.Create(PngImage, PngImage.Width * PngImage.Height * RGBA_BYTES_PER_PIXEL);
//   RawImageCache.AddItem(result);
// end;

// 1) Ситуация
// Клиент берёт ресурс, RefCount = 2
// ...
// Кэш переполняется, RefCount = 1, ресурс удалён из кэша
// Второй клиент загружает копию ресурса в кэш
// Нельзя удалять из кэша при RefCount > 0, объект принудительно сохраняется

// constructor TResourceCache.Create;
// begin

// end;

// destructor TResourceCahce.Destroy;
// begin

// end;

end.