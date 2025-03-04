unit Memory;
(*
  Game memory tools and enhancements.
*)


(***)  interface  (***)

uses
  Math,
  SysUtils,
  Windows,

  FastMM4,

  ApiJack,
  AssocArrays,
  Concur,
  Crypto,
  DataLib,
  StrLib,
  Utils,

  EventMan;


type
  (* Import *)
  TDict = DataLib.TDict;

  TInt32Bool = integer;

  PUniqueStringsItemValue = ^TUniqueStringsItemValue;
  TUniqueStringsItemValue = record
  {O} Str:  pchar;
      Hash: integer;
  end;

  TUniqueStringsValueChain = array of TUniqueStringsItemValue;

  PUniqueStringsItem = ^TUniqueStringsItem;
  TUniqueStringsItem = record
    Value:      TUniqueStringsItemValue;
    ValueChain: TUniqueStringsValueChain;
  end;

  TUniqueStringsItems = array of TUniqueStringsItem;

  TUniqueStrings = class
   const
    MIN_CAPACITY                 = 100;
    CRITICAL_SIZE_CAPACITY_RATIO = 0.75;
    GROWTH_FACTOR                = 2;
    MIN_CAPACITY_GROWTH          = 16;

   protected
    fItems:    TUniqueStringsItems;
    fSize:     integer;
    fCapacity: integer;

    function Find ({n} Str: pchar; out StrLen: integer; out KeyHash: integer; out ItemInd: integer): {n} pchar;
    function GetItem ({n} Str: pchar): {n} pchar;
    procedure AddValue (var Value: TUniqueStringsItemValue);
    procedure Grow;

   public
    constructor Create;
    destructor Destroy; override;

    property Items[Str: pchar]: pchar read GetItem; default;
  end; // .class TUniqueStrings


var
{O} UniqueStrings: TUniqueStrings;

  GameAllocatedMemorySize: integer = 0;


(***)  implementation  (***)


constructor TUniqueStrings.Create;
begin
  SetLength(Self.fItems, MIN_CAPACITY);
  Self.fSize     := 0;
  Self.fCapacity := MIN_CAPACITY;
end;

destructor TUniqueStrings.Destroy;
var
  Item: PUniqueStringsItem;
  i, j: integer;

begin
  for i := 0 to Self.fSize - 1 do begin
    Item := @fItems[i];
    FreeMem(Item.Value.Str);

    for j := 0 to Length(Item.ValueChain) - 1 do begin
      FreeMem(Item.ValueChain[j].Str);
    end;
  end;
end;

function TUniqueStrings.Find ({n} Str: pchar; out StrLen: integer; out KeyHash: integer; out ItemInd: integer): {n} pchar;
var
  Item: PUniqueStringsItem;
  i:    integer;

begin
  result := nil;

  if Str <> nil then begin
    {!} Assert(integer(Str) > 100);
    StrLen  := SysUtils.StrLen(Str);
    KeyHash := Crypto.FastHash(Str, StrLen);

    ItemInd := integer(cardinal(KeyHash) mod cardinal(Self.fCapacity));
    Item    := @Self.fItems[ItemInd];

    if Item.Value.Str <> nil then begin
      if (KeyHash = Item.Value.Hash) and (StrLib.ComparePchars(Str, Item.Value.Str) = 0) then begin
        result := Item.Value.Str;
        exit;
      end;

      for i := 0 to Length(Item.ValueChain) - 1 do begin
        if (KeyHash = Item.ValueChain[i].Hash) and (StrLib.ComparePchars(Str, Item.ValueChain[i].Str) = 0) then begin
          result := Item.ValueChain[i].Str;
          exit;
        end;
      end;
    end; // .if
  end; // .if
end; // .function TUniqueStrings.Find

function TUniqueStrings.GetItem ({n} Str: pchar): {n} pchar;
var
  StrLen:    integer;
  KeyHash:   integer;
  ItemInd:   integer;
  Item:      PUniqueStringsItem;
  NumValues: integer;

begin
  result := nil;

  if Str <> nil then begin
    result := Self.Find(Str, StrLen, KeyHash, ItemInd);

    if result = nil then begin
      GetMem(result, StrLen + 1);
      Utils.CopyMem(StrLen + 1, Str, result);

      Item := @Self.fItems[ItemInd];

      if Item.Value.Str = nil then begin
        Item.Value.Str  := result;
        Item.Value.Hash := KeyHash;
      end else begin
        NumValues := Length(Item.ValueChain);

        SetLength(Item.ValueChain, NumValues + 1);
        Item.ValueChain[NumValues].Str  := result;
        Item.ValueChain[NumValues].Hash := KeyHash;
      end; // .else

      Inc(Self.fSize);

      if (Self.fSize / Self.fCapacity >= CRITICAL_SIZE_CAPACITY_RATIO) then begin
        Self.Grow;
      end;
    end; // .if
  end; // .if
end; // .function TUniqueStrings.GetItem

procedure TUniqueStrings.AddValue (var Value: TUniqueStringsItemValue);
var
  Item:      PUniqueStringsItem;
  NumValues: integer;

begin
  Item := @Self.fItems[integer(cardinal(Value.Hash) mod cardinal(Self.fCapacity))];

  if Item.Value.Str = nil then begin
    Item.Value := Value;
  end else begin
    NumValues := Length(Item.ValueChain);
    SetLength(Item.ValueChain, NumValues + 1);
    Item.ValueChain[NumValues] := Value;
  end;
end;

procedure TUniqueStrings.Grow;
var
  OldCapacity: integer;
  OldItems:    TUniqueStringsItems;
  Item:        PUniqueStringsItem;
  i, j:        integer;

begin
  OldItems       := Self.fItems;
  Self.fItems    := nil;
  OldCapacity    := Self.fCapacity;
  Self.fCapacity := Max(Self.fCapacity + MIN_CAPACITY_GROWTH, trunc(Self.fCapacity * GROWTH_FACTOR));
  SetLength(Self.fItems, Self.fCapacity);

  for i := 0 to OldCapacity - 1 do begin
    Item := @OldItems[i];

    if Item.Value.Str <> nil then begin
      Self.AddValue(Item.Value);

      for j := 0 to Length(Item.ValueChain) - 1 do begin
        Self.AddValue(Item.ValueChain[j]);
      end;
    end;
  end;
end; // .procedure TUniqueStrings.Grow

const
  WOG_STATIC_MEM_START = cardinal($77CAD5);
  WOG_STATIC_MEM_END   = cardinal($77CAD5);

function NewMemAlloc (Size: integer; UseNewHandler: TInt32Bool): {n} pointer; cdecl;
begin
  System.GetMem(result, Size);
  Concur.AtomicAdd(GameAllocatedMemorySize, Size);
end;

function NewCAlloc (NumItems: cardinal; ItemSize: cardinal): {n} pointer; cdecl;
var
  BufSize: integer;

begin
  BufSize := integer(NumItems * ItemSize);
  System.GetMem(result, BufSize);
  Concur.AtomicAdd(GameAllocatedMemorySize, BufSize);
  System.FillChar(result^, BufSize, #0);
end;

function NewMemRealloc ({n} Buf: pointer; NewSize: integer): {n} pointer; cdecl;
var
  BufSize: integer;

begin
  BufSize := 0;

  if Buf <> nil then begin
    BufSize := FastMM4.GetAvailableSpaceInBlock(Buf);
  end;

  result := Buf;

  System.ReallocMem(result, NewSize);
  Concur.AtomicAdd(GameAllocatedMemorySize, NewSize - BufSize);
end;

procedure NewMemFree ({n} Buf: pointer); cdecl;
var
  BufSize: integer;

begin
  // Special check was added, because WoG replaces pointers in game structures with static memory pointers,
  // which should never be attempted to be freed
  if (Buf <> nil) and ((cardinal(Buf) < WOG_STATIC_MEM_START) or (cardinal(Buf) > WOG_STATIC_MEM_END)) then begin
    BufSize := FastMM4.GetAvailableSpaceInBlock(Buf);
    System.FreeMem(Buf);
    Concur.AtomicSub(GameAllocatedMemorySize, BufSize);
  end;
end;

function NewMemSize ({n} Buf: pointer): integer; cdecl;
begin
  result := 0;

  if (Buf <> nil) and ((cardinal(Buf) < WOG_STATIC_MEM_START) or (cardinal(Buf) > WOG_STATIC_MEM_END)) then begin
    result := FastMM4.GetAvailableSpaceInBlock(Buf);
  end;
end;

const
  FUNC_NH_MALLOC = $61A9E7;
  FUNC_CALLOC    = $61AA61;
  FUNC_REALLOC   = $619890;
  FUNC_FREE      = $619BB0;
  FUNC_MSIZE     = $61E504;

begin
  UniqueStrings := TUniqueStrings.Create;

  // Prevent WoG from hooking 'free' function
  pinteger($789DE8)^ := $887668;
  pinteger($78C420)^ := $887668;

  // Force game to use Era memory manager with separate allocation size counting
  ApiJack.Hook(Ptr(FUNC_NH_MALLOC), @NewMemAlloc,   nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(Ptr(FUNC_CALLOC),    @NewCAlloc,     nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(Ptr(FUNC_REALLOC),   @NewMemRealloc, nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(Ptr(FUNC_FREE),      @NewMemFree,    nil, 0, ApiJack.HOOKTYPE_JUMP);
  ApiJack.Hook(Ptr(FUNC_MSIZE),     @NewMemSize,    nil, 0, ApiJack.HOOKTYPE_JUMP);
end.