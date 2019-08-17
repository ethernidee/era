unit RscLists;
(*
  Description: Implements support for loaded resources (crc32 and name tracked) and resource lists.
               Resources can be stored in savegames, compared to each other by size and hash and
               smartly reloaded.
*)


(***)  interface  (***)

uses
  SysUtils, Math,
  Utils, Crypto, DataLib, Files,
  Stores;

type
  TResource = class
   private
     fName:     string;
     fContents: string;
     fCrc32:    integer;

    procedure Init (const Name, Contents: string; Crc32: integer);

   public
    constructor Create (const Name, Contents: string; Crc32: integer); overload;
    constructor Create (const Name, Contents: string); overload;
    
    function  Assign (OtherResource: TResource): TResource;
    function  UpdateContentsAndHash (const Contents: string): TResource;
    function  FastCompare (OtherResource: TResource): boolean;
    function  OwnsAddr ({n} Addr: pchar): boolean;
    function  GetPtr: pchar;
    
    property Name:     string  read fName     write fName;
    property Contents: string  read fContents write fContents;
    property Crc32:    integer read fCrc32    write fCrc32;
  end; // .class TResource

  TResourceList = class
   private
    {O} fItems:        {O} TList {OF TResource};
    {O} fItemIsLoaded: {U} TDict {OF ItemName => Ptr(boolean)};
    
    function GetItemsCount: integer;
    function GetItem (Ind: integer): TResource;
   
   public
    constructor Create;
    destructor  Destroy; override;
   
    procedure Clear;
    function  ItemExists (const ItemName: string): boolean;
    function  Add ({O} Item: TResource): boolean;
    procedure Truncate (NewCount: integer);
    procedure Save (const SectionName: string);
    procedure LoadFromSavedGame (const SectionName: string);
    function  FastCompare (OtherResourceList: TResourceList): boolean;
    
    (* Returns error string *)
    function Export (const DestDir: string): string;

    property Count: integer read GetItemsCount;
    property Items[Ind: integer]: TResource read GetItem; default;
  end; // .class TResourceList


(***)  implementation  (***)


procedure TResource.Init (const Name, Contents: string; Crc32: integer);
begin
  Self.fName     := Name;
  Self.fContents := Contents;
  Self.fCrc32    := Crc32;
end;

constructor TResource.Create (const Name, Contents: string; Crc32: integer);
begin
  Self.Init(Name, Contents, Crc32);
end;

constructor TResource.Create (const Name, Contents: string);
begin
  Init(Name, Contents, Crypto.AnsiCrc32(Contents));
end;

function TResource.Assign (OtherResource: TResource): TResource;
begin
  {!} Assert(OtherResource <> nil);
  Self.fName     := OtherResource.fName;
  Self.fContents := OtherResource.fContents;
  Self.fCrc32    := OtherResource.fCrc32;
  result         := Self;
end;

function TResource.UpdateContentsAndHash (const Contents: string): TResource;
begin
  Self.fContents := Contents;
  Self.fCrc32    := Crypto.AnsiCrc32(Contents);
  result         := Self;
end;

function TResource.FastCompare (OtherResource: TResource): boolean;
begin
  {!} Assert(OtherResource <> nil);
  result := (Self.fCrc32 = OtherResource.fCrc32) and (Length(Self.fContents) = Length(OtherResource.fContents));
end;

function TResource.OwnsAddr ({n} Addr: pchar): boolean;
begin
  result := (cardinal(Addr) >= cardinal(Self.fContents)) and (cardinal(Addr) < cardinal(Self.fContents) + cardinal(Length(Self.fContents)));
end;

function TResource.GetPtr: pchar;
begin
  result := pchar(Self.fContents);
end;

constructor TResourceList.Create;
begin
  Self.fItems        := DataLib.NewList(Utils.OWNS_ITEMS);
  Self.fItemIsLoaded := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
end;
  
destructor TResourceList.Destroy;
begin
  SysUtils.FreeAndNil(Self.fItems);
  SysUtils.FreeAndNil(Self.fItemIsLoaded);
  inherited;
end;

procedure TResourceList.Clear;
begin
  Self.fItems.Clear;
  Self.fItemIsLoaded.Clear;
end;

function TResourceList.ItemExists (const ItemName: string): boolean;
begin
  result := Self.fItemIsLoaded[ItemName] <> nil;
end;

function TResourceList.Add ({O} Item: TResource): boolean;
begin
  result := Self.fItemIsLoaded[Item.Name] = nil;

  if result then begin
    Self.fItemIsLoaded[Item.Name] := Ptr(1);
    Self.fItems.Add(Item);
  end;
end;

procedure TResourceList.Truncate (NewCount: integer);
var
  i: integer;

begin
  {!} Assert(NewCount >= 0);
  // * * * * * //
  for i := NewCount + 1 to Self.fItems.Count - 1 do begin
    Self.fItemIsLoaded.DeleteItem(TResource(Self.fItems[i]).Name);
  end;

  Self.fItems.SetCount(NewCount);
end;

procedure TResourceList.Save (const SectionName: string);
var
{Un} Item: TResource;
     i:    integer;
  
begin
  Item := nil;
  // * * * * * //
  with Stores.NewRider(SectionName) do begin
    WriteInt(Self.fItems.Count);

    for i := 0 to Self.fItems.Count - 1 do begin
      Item := TResource(Self.fItems[i]);
      WriteStr(Item.Name);
      WriteInt(Item.Crc32);
      WriteStr(Item.Contents);
    end;
  end;
end; // .procedure TResourceList.SaveItems

procedure TResourceList.LoadFromSavedGame (const SectionName: string);
var
  NumItems:     integer;
  ItemContents: string;
  ItemName:     string;
  ItemCrc32:    integer;
  i:            integer;
  
begin
  with Stores.NewRider(SectionName) do begin
    NumItems := ReadInt;

    for i := 1 to NumItems do begin
      ItemName     := ReadStr;
      ItemCrc32    := ReadInt;
      ItemContents := ReadStr;
      Self.Add(TResource.Create(ItemName, ItemContents, ItemCrc32));
    end;
  end;
end; // .procedure TResourceList.LoadFromSavedGame

function TResourceList.Export (const DestDir: string): string;
var
  Res:      boolean;
  ItemName: string;
  ItemPath: string;
  i:        integer;
  
begin
  result := '';
  Res    := SysUtils.DirectoryExists(DestDir) or SysUtils.CreateDir(DestDir);
  
  if not Res then begin
    result := 'Cannot recreate directory "' + DestDir + '"';
  end else begin
    i := 0;
    
    while Res and (i < Self.fItems.Count) do begin
      ItemName := TResource(Self.fItems[i]).Name;
      ItemPath := DestDir + '\' + ItemName;

      if System.Pos('\', ItemName) <> 0 then begin
        Res := ForcePath(SysUtils.ExtractFilePath(ItemPath));

        if not Res then begin
          result := 'Cannot create directory "' + SysUtils.ExtractFilePath(ItemPath) + '"';
        end;
      end;

      if Res then begin
        Res := Files.WriteFileContents(TResource(Self.fItems[i]).Contents, ItemPath);

        if not Res then begin
          result := 'Error writing to file "' + ItemPath + '"';
        end;
      end;
    
      Inc(i);
    end;
  end; // .else
end; // .function TResourceList.ExtractItems

function TResourceList.GetItemsCount: integer;
begin
  result := Self.fItems.Count;
end;

function TResourceList.GetItem (Ind: integer): TResource;
begin
  {!} Assert(Math.InRange(Ind, 0, Self.fItems.Count - 1), Format('Cannot get item with index %d for resource list. Item is out of bounds', [Ind]));
  result := Self.fItems[Ind];
end;

function TResourceList.FastCompare (OtherResourceList: TResourceList): boolean;
var
  i: integer;

begin
  result := Self.fItems.Count = OtherResourceList.fItems.Count;

  if result then begin
    for i := 0 to Self.fItems.Count - 1 do begin
      if not TResource(Self.fItems[i]).FastCompare(TResource(OtherResourceList.fItems[i])) then begin
        result := false;
        exit;
      end;
    end;
  end;
end;

end.