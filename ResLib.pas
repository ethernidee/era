unit ResLib;
(*
  Description: Library for game resources management, particulary storing them in shared memory, reference counting and caching support.
  Author:      Alexander Shostak aka Berserker
*)


(***)  interface  (***)

uses
  SysUtils,
  Utils,

  DataLib,
  StrLib,

  EraSettings,
  EventMan,
  GameExt;

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
   {On} fResQueueStart: TResQueueItem;            // Resource queue is used to eliminate least recently used items without users.
   {On} fResQueueEnd:   TResQueueItem;
        fTotalSize:     integer;                  // Total size of all cached resources.
        fMaxTotalSize:  integer;                  // Maximum desired size of all cached resources. Real total size may exceed this value
                                                  // If each resource has RefCount > 1.

    procedure RemoveItemFromResQueue (ResQueueItem: TResQueueItem);
    procedure PrependItemToResQueue (ResQueueItem: TResQueueItem);
    procedure MoveResQueueItemToStart (ResQueueItem: TResQueueItem);
    procedure OnResourceDestruction (const Source: string);

   public
    constructor Create (MaxTotalSize: integer);
    destructor Destroy; override;

    (* Frees any cached and unused resources *)
    procedure CollectGarbage;

    (* Returns number of all loaded resources *)
    function CountResources: integer;

    (* Creates TSharedResource and increases its reference counter by one, placing its in global cache. Client must call DecRef when resource is no longer needed *)
    function AddResource (Data: TObject; Size: integer; const Source: string): {O} TSharedResource;

    (* Returns existing resource from cache, if it's found. Client must call DecRef when resource is no longer needed *)
    function GetResource (const Source: string): {On} TSharedResource;

    (* Removes resource from cache if Resource Manager is its only owner. Returns true if resource is not in cache anymore or was not there before method call. *)
    function TryCollectResource (const Source: string): boolean;

    property TotalSize:    integer read fTotalSize;
    property MaxTotalSize: integer read fMaxTotalSize;
    property NumResources: integer read CountResources;
  end; // .class TResourceManager

  (*
    Shared resource. Not thread safe. Uses refcounting. Do not call destructor manually. Use IncRef/DecRef only.
    Do no use resource after calling DecRef;
  *)
  TSharedResource = class
   protected
    {U} fManager:  TResourceManager; // Resource manager.
    {O} fData:     TObject;          // Resource underlying data.
    fSize:         integer;          // Estimated resource size in memory in bytes.
    fRefCount:     integer;          // Number of resource users.
    fSource:       string;           // The source of resource. Usually relative file path.

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


var
(* Parsed/decoded resources manager. Provides possibility to share the same resource by multiple clients and automatical resource caching *)
{O} ResMan: TResourceManager;

  // This config parameter must be set before OnAfterWoG event
  ResManCacheSize: integer = 0;


(***)  implementation  (***)


constructor TSharedResource.CreateAndBind (Manager: TResourceManager; Data: TObject; Size: integer; const Source: string);
begin
  {!} Assert(Manager <> nil);
  {!} Assert(Data <> nil);
  {!} Assert(Size > 0, 'Resource size cannot be negative. Given: ' + SysUtils.IntToStr(Size));

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
  SysUtils.FreeAndNil(Self.fData);
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
    Self.fManager.OnResourceDestruction(Self.Source);

    Self.Destroy;
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
    ResQueueItem.PrevItem.NextItem := ResQueueItem.NextItem;
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
    ResQueueItem.PrevItem := nil;
    ResQueueItem.NextItem := nil;
    Self.fResQueueEnd     := ResQueueItem;
  end;

  Self.fResQueueStart := ResQueueItem;
end;

procedure TResourceManager.MoveResQueueItemToStart (ResQueueItem: TResQueueItem);
begin
  {!} Assert(ResQueueItem <> nil);

  Self.RemoveItemFromResQueue(ResQueueItem);
  Self.PrependItemToResQueue(ResQueueItem);
end;

procedure TResourceManager.OnResourceDestruction (const Source: string);
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

      // ResMan cache is the only only of resource. The resource can be deallocated safely.
      if CurrItem.Resource.RefCount = 1 then begin
        NextItemToProcess := CurrItem.PrevItem;

        // Here OnResourceDestruction will be called automatically, unregistering resource and freeing CurrItem
        CurrItem.Resource.DecRef;

        CurrItem := NextItemToProcess;
      // There are active resources users, move it to the queue start
      end else begin
        NextItemToProcess := CurrItem.PrevItem;
        Self.MoveResQueueItemToStart(CurrItem);
        CurrItem          := NextItemToProcess;
      end; // .else
    end; // .while
  end; // .if
end; // .procedure CollectGarbage

function TResourceManager.CountResources: integer;
begin
  result := Self.fResourceMap.ItemCount;
end;

function TResourceManager.AddResource (Data: TObject; Size: integer; const Source: string): {O} TSharedResource;
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

  // We own resource and collect garbage only if cache capacity is not zero. Otherwise ResMan works
  // as simple loaded resource locator.
  if Self.fMaxTotalSize > 0 then begin
    Resource.IncRef;
    Self.CollectGarbage;
  end;

  result := Resource;
end;

function TResourceManager.GetResource (const Source: string): {On} TSharedResource;
var
{U} ResQueueItem: TResQueueItem;

begin
  result       := nil;
  ResQueueItem := Self.fResourceMap[Source];

  if ResQueueItem <> nil then begin
    Self.MoveResQueueItemToStart(ResQueueItem);
    ResQueueItem.Resource.IncRef;
    result := ResQueueItem.Resource;
  end;
end;

function TResourceManager.TryCollectResource (const Source: string): boolean;
var
{U} ResQueueItem: TResQueueItem;

begin
  ResQueueItem := Self.fResourceMap[Source];
  result       := ResQueueItem = nil;

  if not result then begin
    result := (Self.fMaxTotalSize > 0) and (ResQueueItem.Resource.RefCount = 1);

    if result then begin
      ResQueueItem.Resource.DecRef;
    end;
  end;
end;

procedure OnLoadEraSettings (Event: GameExt.PEvent); stdcall;
const
  V_200_MB = 200000000;

begin
  ResManCacheSize := EraSettings.GetOpt('ResourceCacheSize').Int(V_200_MB);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  ResMan := TResourceManager.Create(ResManCacheSize);
end;

begin
  EventMan.GetInstance.On('$OnLoadEraSettings', OnLoadEraSettings);
  EventMan.GetInstance.On('OnAfterWoG', OnAfterWoG);
end.