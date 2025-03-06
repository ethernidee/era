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


const
  GAME_MEM_CONSUMER_INDEX = 0;


type
  (* Import *)
  TStrList = DataLib.TStrList;
  TDict    = DataLib.TDict;

  TInt32Bool = integer;
  pbyte      = ^byte;

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


(* Registers memory consumer (plugin with custom memory manager) and returns address of allocated memory counter, which
   consumer should atomically increase and decrease in malloc/calloc/realloc/free operations. *)
function RegisterMemoryConsumer (ConsumerName: string): pinteger;

(* Returns list with memory consumer names and corresponding allocation size *)
function GetMemoryConsumers: TStrList {of Ptr(AllocatedSize: integer)};

// The following functions may be used to replace third-party memory manager and to count allocated size separately
function  ClientMemAlloc (var AllocatedSize: integer; BufSize: integer): {n} pointer; stdcall;
procedure ClientMemFree (var AllocatedSize: integer; {On} Buf: pointer); stdcall;
function  ClientMemRealloc (var AllocatedSize: integer; {On} Buf: pointer; NewBufSize: integer): {n} pointer; stdcall;


var
{O} UniqueStrings: TUniqueStrings;


(***)  implementation  (***)


const
  MAX_MEMORY_CONSUMERS                = 400;
  GAME_MEM_CONSUMER_NAME              = '<Heroes 3>';
  TICKETLESS_MEM_CONSUMERS_GROUP_NAME = '<Others>';

var
  AllocatedMemoryByConsumer: array [0..MAX_MEMORY_CONSUMERS - 1] of integer;
  MemoryConsumers:           TStrList;


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
  Concur.AtomicAdd(AllocatedMemoryByConsumer[GAME_MEM_CONSUMER_INDEX], Size);
end;

function NewCAlloc (NumItems: cardinal; ItemSize: cardinal): {n} pointer; cdecl;
var
  BufSize: integer;

begin
  BufSize := integer(NumItems * ItemSize);
  System.GetMem(result, BufSize);
  Concur.AtomicAdd(AllocatedMemoryByConsumer[GAME_MEM_CONSUMER_INDEX], BufSize);
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
  Concur.AtomicAdd(AllocatedMemoryByConsumer[GAME_MEM_CONSUMER_INDEX], NewSize - BufSize);
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
    Concur.AtomicSub(AllocatedMemoryByConsumer[GAME_MEM_CONSUMER_INDEX], BufSize);
  end;
end;

function NewMemSize ({n} Buf: pointer): integer; cdecl;
begin
  result := 0;

  if (Buf <> nil) and ((cardinal(Buf) < WOG_STATIC_MEM_START) or (cardinal(Buf) > WOG_STATIC_MEM_END)) then begin
    result := FastMM4.GetAvailableSpaceInBlock(Buf);
  end;
end;

function ClientMemAlloc (var AllocatedSize: integer; BufSize: integer): {n} pointer; stdcall;
begin
  GetMem(result, BufSize);
  Concur.AtomicAdd(AllocatedSize, FastMM4.GetAvailableSpaceInBlock(result));
end;

procedure ClientMemFree (var AllocatedSize: integer; {On} Buf: pointer); stdcall;
var
  BufSize: integer;

begin
  if Buf <> nil then begin
    BufSize := FastMM4.GetAvailableSpaceInBlock(Buf);
    FreeMem(Buf);
    Concur.AtomicSub(AllocatedSize, BufSize);
  end;
end;

function ClientMemRealloc (var AllocatedSize: integer; {On} Buf: pointer; NewBufSize: integer): {n} pointer; stdcall;
var
  BufSize: integer;

begin
  BufSize := FastMM4.GetAvailableSpaceInBlock(Buf);
  result  := Buf;
  ReallocMem(result, NewBufSize);
  Concur.AtomicAdd(AllocatedSize, NewBufSize - BufSize);
end;

function RegisterMemoryConsumer (ConsumerName: string): pinteger;
var
  ConsumerIndex: integer;

begin
  ConsumerIndex := MemoryConsumers.Count;

  if ConsumerIndex > High(AllocatedMemoryByConsumer) then begin
    result := @AllocatedMemoryByConsumer[High(AllocatedMemoryByConsumer)];
    exit;
  end else if ConsumerIndex = High(AllocatedMemoryByConsumer) then begin
    ConsumerName := TICKETLESS_MEM_CONSUMERS_GROUP_NAME;
  end;

  MemoryConsumers.Add(ConsumerName);
  result := @AllocatedMemoryByConsumer[ConsumerIndex];
end;

function GetMemoryConsumers: TStrList {of Ptr(AllocatedSize: integer)};
var
  i: integer;

begin
  for i := 0 to MemoryConsumers.Count - 1 do begin
    MemoryConsumers.Values[i] := Ptr(AllocatedMemoryByConsumer[i]);
  end;

  result := MemoryConsumers;
end;

const
  FUNC_NH_MALLOC = $61A9E7;
  FUNC_CALLOC    = $61AA61;
  FUNC_REALLOC   = $619890;
  FUNC_FREE      = $619BB0;
  FUNC_MSIZE     = $61E504;

begin
  UniqueStrings   := TUniqueStrings.Create;
  MemoryConsumers := DataLib.NewStrList(not Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  MemoryConsumers.Add(GAME_MEM_CONSUMER_NAME);

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