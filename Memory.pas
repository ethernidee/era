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
    GROWTH_FACTOR                = 1.5;
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
  UniqueStrings: TUniqueStrings;


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
end; // .destructor TUniqueStrings.Destroy

function TUniqueStrings.Find ({n} Str: pchar; out StrLen: integer; out KeyHash: integer; out ItemInd: integer): {n} pchar;
var
  Item: PUniqueStringsItem;
  i:    integer;

begin
  result := nil;

  if Str <> nil then begin
    {!} Assert(integer(Str) > 100);
    StrLen  := SysUtils.StrLen(Str);
    KeyHash := Crypto.Crc32(Str, StrLen);
    
    ItemInd := integer(cardinal(KeyHash) mod cardinal(Self.fCapacity));
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

begin
  UniqueStrings := TUniqueStrings.Create;
end.