unit Memory;
(*
  Game memory tools and enhancements.
*)


(***)  interface  (***)

uses
  SysUtils, Math,
  Utils, Crypto, AssocArrays, StrLib, DataLib;


type
  (* Import *)
  TDict = DataLib.TDict;


(***)  implementation  (***)


type
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
    MIN_CAPACITY                 = 16;
    CRITICAL_SIZE_CAPACITY_RATIO = 0.75;
    GROWTH_FACTOR                = 1.5;
    MIN_CAPACITY_GROWTH          = 16;

   protected
    fItems:    TUniqueStringsItems;
    fSize:     integer;
    fCapacity: integer;

    function Find ({n} Str: pchar; out StrLen: integer; out KeyHash: integer; out ItemInd: integer): {n} pchar;
    function GetItem ({n} Str: pchar): {n} pchar;
    procedure Grow;

   public
    constructor Create;
    destructor Destroy; override;

    property Items[Str: pchar]: pchar read GetItem; default;
  end;

var
  UniqueStrings: TUniqueStrings;


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
end; // .destructor TUniqueStrings.Destroy

function TUniqueStrings.Find ({n} Str: pchar; out StrLen: integer; out KeyHash: integer; out ItemInd: integer): {n} pchar;
var
  Item: PUniqueStringsItem;
  i:    integer;

begin
  result := nil;

  if Str <> nil then begin
    StrLen  := SysUtils.StrLen(Str);
    KeyHash := Crypto.Crc32(Str, StrLen);
    ItemInd := KeyHash mod Self.fCapacity;
    Item    := @Self.fItems[ItemInd];

    if Item.Value.Str <> nil then begin
      if StrLib.ComparePchars(Str, Item.Value.Str) = 0 then begin
        result := Item.Value.Str;
        exit;
      end;

      for i := 0 to Length(Item.ValueChain) - 1 do begin
        if StrLib.ComparePchars(Str, Item.ValueChain[i].Str) = 0 then begin
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
    result := Find(Str, StrLen, KeyHash, ItemInd);

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
        Grow;
      end;
    end; // .if
  end; // .if
end; // .function TUniqueStrings.GetItem

procedure TUniqueStrings.Grow;
var
  NewCapacity: integer;
  OldItems:    TUniqueStringsItems;
  Item:        PUniqueStringsItem;
  NewItem:     PUniqueStringsItem;
  NumValues:   integer;
  i:           integer;

begin
  NewCapacity := Max(Self.fCapacity + MIN_CAPACITY_GROWTH, trunc(Self.fCapacity * GROWTH_FACTOR));
  OldItems    := Self.fItems;
  Self.fItems := nil;
  SetLength(Self.fItems, NewCapacity);

  for i := 0 to Self.fCapacity - 1 do begin
    Item := @OldItems[i];

    if Item.Value.Str <> nil then begin
      NewItem := @Self.fItems[Item.Value.Hash mod NewCapacity];

      if NewItem.Value.Str = nil then begin
        NewItem.Value := Item.Value;
      end else begin
        NumValues := Length(NewItem.ValueChain);
        SetLength(NewItem.ValueChain, NumValues + 1);
        NewItem.ValueChain[NumValues] := Item.Value;
      end;
    end;
  end;

  Self.fCapacity := NewCapacity;
end; // .procedure TUniqueStrings.Grow

(* For string literal S returns the same static readonly string, thus saving memory and allowing to compare such strings by addresses *)
function ToStaticStr (const Str: string): string; overload;
begin
  
end;

function ToStaticStr (Str: pchar): pchar; overload;
var
  Key: string;

begin
  // result := nil;

  // if Str <> nil then begin
  //   Key    := Str;
  //   result := UniqueStrings[Key];

  //   if result = nil then begin
  //     GetMem(result, Length(Key) + 1);
  //     Utils.CopyMem(Length(Str) + 1, pchar(Key), result);
  //     UniqueStrings[Key] := 
  //   end;
  // end;
end;

var
s: string;
p1, p2: pchar;

begin
  // UniqueStrings := TUniqueStrings.Create;
  // UniqueStrings['do it right now'];
  // UniqueStrings['hope you are alive'];
  // p1 := UniqueStrings['take it, Bers'];
  // p2 := UniqueStrings['take it, Bers'];
  // {!} Assert(UniqueStrings['take it, Bers'] = p1);
  // {!} Assert(p1 = p2);
  // s := 'take it';
  // s := s + ', Bers';
  // {!} Assert(UniqueStrings[pchar(s)] = p1);
  // s := 'alive';
  // {!} Assert(UniqueStrings['hope you are alive'] = UniqueStrings[pchar('hope you are ' + s)]);
end.